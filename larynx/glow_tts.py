"""Code for GlowTTS text to speech model"""
import logging
import typing

import numpy as np
import onnxruntime

from larynx.constants import SettingsType, TextToSpeechModel, TextToSpeechModelConfig

_LOGGER = logging.getLogger("glow_tts")

# -----------------------------------------------------------------------------


class GlowTextToSpeech(TextToSpeechModel):
    def __init__(self, config: TextToSpeechModelConfig):
        super().__init__(config)

        self.onnx_model: typing.Optional[onnxruntime.InferenceSession] = None

        # Load model
        generator_path = config.model_path / "generator.onnx"

        _LOGGER.debug("Loading GlowTTS Onnx from %s", generator_path)
        self.onnx_model = onnxruntime.InferenceSession(
            str(generator_path), sess_options=config.session_options
        )

        self.noise_scale = 0.667
        self.length_scale = 1.0

    # -------------------------------------------------------------------------

    def phonemes_to_mels(
        self, phoneme_ids: np.ndarray, settings: typing.Optional[SettingsType] = None
    ) -> np.ndarray:
        """Convert phoneme ids to mel spectrograms"""
        # Convert to tensors
        noise_scale = self.noise_scale
        length_scale = self.length_scale

        if settings:
            noise_scale = float(settings.get("noise_scale", noise_scale))
            length_scale = float(settings.get("length_scale", length_scale))

        # Inference with Onnx
        assert self.onnx_model is not None

        text_array = np.expand_dims(np.array(phoneme_ids, dtype=np.int64), 0)
        text_lengths_array = np.array([text_array.shape[1]], dtype=np.int64)
        scales_array = np.array([noise_scale, length_scale], dtype=np.float32)

        # Infer mel spectrograms
        mel = self.onnx_model.run(
            None,
            {
                "input": text_array,
                "input_lengths": text_lengths_array,
                "scales": scales_array,
            },
        )[0]

        return mel
