from __future__ import annotations

import typing
from abc import ABC
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

if typing.TYPE_CHECKING:
    # Only import here if type checking
    import numpy as np
    import onnxruntime

# -----------------------------------------------------------------------------


class TextToSpeechType(str, Enum):
    """Available text to speech model types"""

    GLOW_TTS = "glow_tts"


class VocoderType(str, Enum):
    """Available vocoder model types"""

    HIFI_GAN = "hifi_gan"


SettingsType = typing.Dict[str, typing.Any]


class VocoderQuality(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


# -----------------------------------------------------------------------------


@dataclass
class TextToSpeechModelConfig:
    """Configuration base class for text to speech models"""

    model_path: Path
    session_options: onnxruntime.SessionOptions
    use_cuda: bool = True
    half: bool = True


class TextToSpeechModel(ABC):
    """Base class of text to speech models"""

    def __init__(self, config: TextToSpeechModelConfig):
        pass

    def phonemes_to_mels(
        self, phoneme_ids: np.ndarray, settings: typing.Optional[SettingsType] = None
    ) -> np.ndarray:
        """Convert phoneme ids to mel spectrograms"""
        pass


# -----------------------------------------------------------------------------


@dataclass
class VocoderModelConfig:
    """Configuration base class for vocoder models"""

    model_path: Path
    session_options: onnxruntime.SessionOptions
    use_cuda: bool = True
    half: bool = True
    denoiser_strength: float = 0.0


class VocoderModel(ABC):
    """Base class of vocoders"""

    def __init__(self, config: VocoderModelConfig):
        pass

    def mels_to_audio(
        self, mels: np.ndarray, settings: typing.Optional[SettingsType] = None,
    ) -> np.ndarray:
        """Convert mel spectrograms to WAV audio"""
        pass


# -----------------------------------------------------------------------------


@dataclass
class TextToSpeechResult:
    """Result from larynx.text_to_speech"""

    text: str
    audio: typing.Optional[np.ndarray]
    sample_rate: int
