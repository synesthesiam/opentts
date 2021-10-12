"""Code for HiFi-GAN vocoder"""
import concurrent.futures
import json
import logging
import typing
from concurrent.futures import Executor, Future

import numpy as np
import onnxruntime

from larynx.audio import audio_float_to_int16, inverse, transform
from larynx.constants import SettingsType, VocoderModel, VocoderModelConfig

_LOGGER = logging.getLogger("hifi_gan")

# -----------------------------------------------------------------------------


class HiFiGanVocoder(VocoderModel):
    def __init__(self, config: VocoderModelConfig, executor: typing.Optional[Executor]):
        super().__init__(config)

        self.use_cuda = config.use_cuda
        self.half = config.half

        self.onnx_model: typing.Optional[onnxruntime.InferenceSession] = None

        # Load model
        generator_path = config.model_path / "generator.onnx"
        config_path = generator_path.parent / "config.json"

        _LOGGER.debug("Loading config from %s", config_path)
        with open(config_path, "r", encoding="utf-8") as config_file:
            self.config = json.load(config_file)
            self.mel_channels = int(self.config.get("num_mels", 80))

        _LOGGER.debug("Loading HiFi-GAN Onnx from %s", generator_path)
        self.onnx_model = onnxruntime.InferenceSession(
            str(generator_path), sess_options=config.session_options
        )

        # Initialize denoiser
        self.denoiser_strength = config.denoiser_strength
        self.bias_spec: typing.Optional[np.ndarray] = None

        self.denoiser_future: typing.Optional[Future] = None

        if self.denoiser_strength > 0:
            if executor is not None:
                # Run in executor
                self.denoiser_future = executor.submit(self.maybe_init_denoiser)
            else:
                # Run here
                self.maybe_init_denoiser()

    def mels_to_audio(
        self, mels: np.ndarray, settings: typing.Optional[SettingsType] = None,
    ) -> np.ndarray:
        """Convert mel spectrograms to WAV audio"""
        assert self.onnx_model is not None

        # Inference with Onnx
        audio = self.onnx_model.run(None, {"mel": mels})[0].squeeze(0)

        denoiser_strength = self.denoiser_strength
        if settings:
            denoiser_strength = float(
                settings.get("denoiser_strength", denoiser_strength)
            )

        if denoiser_strength > 0:
            if self.denoiser_future is not None:
                # Denoiser init is already in progress
                concurrent.futures.wait([self.denoiser_future])
                self.denoiser_future = None

            self.maybe_init_denoiser()
            _LOGGER.debug("Running denoiser (strength=%s)", denoiser_strength)
            audio = self.denoise(audio, denoiser_strength)

        audio_norm = audio_float_to_int16(audio)
        return audio_norm.squeeze()

    def denoise(self, audio: np.ndarray, denoiser_strength: float) -> np.ndarray:
        assert self.bias_spec is not None

        audio_spec, audio_angles = transform(audio)
        audio_spec_denoised = audio_spec - (self.bias_spec * denoiser_strength)
        audio_spec_denoised = np.clip(audio_spec_denoised, a_min=0.0, a_max=None)
        audio_denoised = inverse(audio_spec_denoised, audio_angles)

        return audio_denoised

    def maybe_init_denoiser(self):
        if self.bias_spec is None:
            _LOGGER.debug("Initializing denoiser")
            # Inference with Onnx
            mel_zeros = np.zeros(shape=(1, self.mel_channels, 88), dtype=np.float32)
            bias_audio = self.onnx_model.run(None, {"mel": mel_zeros})[0].squeeze(0)

            bias_spec, _ = transform(bias_audio)

            self.bias_spec = bias_spec[:, :, 0][:, :, None]
