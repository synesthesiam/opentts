#!/usr/bin/env python3
import io
import logging
import typing
import wave
from pathlib import Path

import numpy as np
from espeak_phonemizer import Phonemizer
from phonemes2ids import STRESS, phonemes2ids

from glow_speak.audio import (
    audio_float_to_int16,
    db_to_amp,
    denormalize,
    dynamic_range_compression,
    inverse,
    transform,
)

_DIR = Path(__file__).parent
_LOGGER = logging.getLogger("glow-speak")

_VOCODER_DIR = _DIR / "vocoders"

PAD = "_"


# -----------------------------------------------------------------------------


STRESS_AND_PUNCTUATION = set.union(STRESS, {".", ","})


def text_to_ids(
    text: str,
    phonemizer: Phonemizer,
    phoneme_to_id: typing.Mapping[str, int],
    phoneme_map: typing.Optional[typing.Mapping[str, typing.Sequence[str]]] = None,
    phoneme_separator: str = "_",
    missing_func: typing.Optional[
        typing.Callable[[str], typing.Optional[typing.List[int]]]
    ] = None,
) -> np.ndarray:
    ipa_str = phonemizer.phonemize(
        text, keep_clause_breakers=True, phoneme_separator=phoneme_separator
    )

    # Ensure full stop at the end
    if ipa_str[-1] != ".":
        ipa_str += " ."

    _LOGGER.debug(ipa_str)

    word_phonemes = [word.split(phoneme_separator) for word in ipa_str.split()]
    text_ids = phonemes2ids(
        word_phonemes,
        phoneme_to_id,
        pad=PAD,
        bos="^",
        eos="$",
        blank="#",
        simple_punctuation=True,
        separate=STRESS_AND_PUNCTUATION,
        phoneme_map=phoneme_map,
        missing_func=missing_func,
    )

    _LOGGER.debug(text_ids)

    return np.array(text_ids, dtype=np.int64)


def ids_to_mels(
    ids: np.ndarray, tts_model, noise_scale: float = 0.667, length_scale: float = 1.0
) -> np.ndarray:
    text_array = np.expand_dims(np.array(ids, dtype=np.int64), 0)
    text_lengths = np.array([text_array.shape[1]], dtype=np.int64)
    scales = np.array([noise_scale, length_scale], dtype=np.float32)

    return tts_model.run(
        None, {"input": text_array, "input_lengths": text_lengths, "scales": scales}
    )[0]


def mels_to_audio(
    mels: np.ndarray,
    vocoder_model,
    denoiser_strength: float = 0.0,
    bias_spec=typing.Optional[np.ndarray],
) -> np.ndarray:
    mels = denormalize(mels)
    mels = db_to_amp(mels)
    mels = dynamic_range_compression(mels)

    audio = vocoder_model.run(None, {"mel": mels})[0].squeeze(0)

    if denoiser_strength > 0:
        assert bias_spec is not None
        audio_spec, audio_angles = transform(audio)
        audio_spec_denoised = audio_spec - (bias_spec * denoiser_strength)
        audio_spec_denoised = np.clip(audio_spec_denoised, a_min=0.0, a_max=None)
        audio_denoised = inverse(audio_spec_denoised, audio_angles)
    else:
        audio_denoised = audio

    audio_norm = audio_float_to_int16(audio_denoised)
    audio_norm = audio_norm.squeeze(0)

    return audio_norm


def audio_to_wav(
    audio: np.ndarray,
    sample_rate: int = 22050,
    channels: int = 1,
    sample_bytes: int = 2,
) -> bytes:
    with io.BytesIO() as wav_io:
        wav_out: wave.Wave_write = wave.open(wav_io, "wb")
        with wav_out:
            wav_out.setframerate(sample_rate)
            wav_out.setnchannels(channels)
            wav_out.setsampwidth(sample_bytes)
            wav_out.writeframes(audio.tobytes())

        return wav_io.getvalue()


# -----------------------------------------------------------------------------


def init_denoiser(vocoder_model, mel_channels: int = 80) -> np.ndarray:
    mel_zeros = np.zeros(shape=(1, mel_channels, 88), dtype=np.float32)
    bias_audio = vocoder_model.run(None, {"mel": mel_zeros})[0].squeeze(0)
    bias_spec, _ = transform(bias_audio)
    bias_spec = bias_spec[:, :, 0][:, :, None]

    return bias_spec
