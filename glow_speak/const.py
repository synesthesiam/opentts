"""Constants and enums"""
from enum import Enum

PAD = "_"


class VocoderQuality(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
