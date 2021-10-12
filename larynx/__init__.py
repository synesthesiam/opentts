import json
import logging
import time
import typing
from concurrent.futures import Executor, Future, ThreadPoolExecutor
from pathlib import Path

import numpy as np
import onnxruntime
import phonemes2ids

import gruut
from larynx.audio import AudioSettings
from larynx.constants import (
    TextToSpeechModel,
    TextToSpeechModelConfig,
    TextToSpeechResult,
    TextToSpeechType,
    VocoderModel,
    VocoderModelConfig,
    VocoderQuality,
    VocoderType,
)
from larynx.utils import (
    DEFAULT_VOICE_URL_FORMAT,
    VOCODER_QUALITY,
    download_voice,
    get_voice_download_name,
    get_voices_dirs,
    resolve_voice_name,
    split_voice_name,
    valid_voice_dir,
)

_LOGGER = logging.getLogger("larynx")

_DIR = Path(__file__).parent

__version__ = (_DIR / "VERSION").read_text().strip()

_DEFAULT_AUDIO_SETTINGS = AudioSettings()

# -----------------------------------------------------------------------------


def text_to_speech(
    text: str,
    voice_or_lang: str = "en-us",
    vocoder_or_quality: typing.Union[str, VocoderQuality] = VocoderQuality.HIGH,
    ssml: bool = False,
    tts_settings: typing.Optional[typing.Dict[str, typing.Any]] = None,
    vocoder_settings: typing.Optional[typing.Dict[str, typing.Any]] = None,
    denoiser_strength: float = 0.0,
    executor: typing.Optional[Executor] = None,
    custom_voices_dir: typing.Optional[typing.Union[str, Path]] = None,
    url_format: str = DEFAULT_VOICE_URL_FORMAT,
) -> typing.Iterable[TextToSpeechResult]:
    resolved_name = resolve_voice_name(voice_or_lang)
    voice_lang, _voice_name, _voice_model_type = split_voice_name(resolved_name)
    voice_lang = gruut.resolve_lang(voice_lang)

    if executor is None:
        executor = ThreadPoolExecutor()

    futures: typing.Dict[Future, TextToSpeechResult] = {}

    for sentence in gruut.sentences(
        text, lang=voice_lang, ssml=ssml, explicit_lang=False
    ):
        tts_model = None
        tts_model_names = []

        if sentence.voice:
            tts_model_names.append(sentence.voice)

        if sentence.lang:
            if gruut.resolve_lang(sentence.lang) == voice_lang:
                # Use provided voice as default for its language
                tts_model_names.append(resolved_name)
            else:
                tts_model_names.append(sentence.lang)

        tts_model_names.append(resolved_name)
        tts_model_names.append(voice_or_lang)

        # Try to load a TTS model for this sentence
        for tts_voice_name in filter(None, tts_model_names):
            tts_model = get_tts_model(
                tts_voice_name,
                custom_voices_dir=custom_voices_dir,
                url_format=url_format,
            )
            if tts_model is not None:
                break

        assert tts_model is not None, "Failed to load voice"

        vocoder_model = get_vocoder_model(
            vocoder_or_quality,
            denoiser_strength=denoiser_strength,
            custom_voices_dir=custom_voices_dir,
            url_format=url_format,
        )
        assert vocoder_model is not None, "Failed to load vocoder"

        # Convert text to phonemes
        phoneme_to_id = getattr(tts_model, "phoneme_to_id", {})
        audio_settings = getattr(tts_model, "audio_settings", None)
        if audio_settings is None:
            audio_settings = _DEFAULT_AUDIO_SETTINGS

        sent_phonemes = [w.phonemes for w in sentence if w.phonemes]
        sent_phoneme_ids = phonemes2ids.phonemes2ids(
            sent_phonemes,
            phoneme_to_id,
            pad="_",
            blank="#",
            separate={"ˈ", "ˌ", "²"},
            simple_punctuation=True,
        )

        _LOGGER.debug("%s %s %s", sentence.text, sent_phonemes, sent_phoneme_ids)

        # Convert phonemes to audio
        future = executor.submit(
            _sentence_task,
            sentence.text,
            np.array(sent_phoneme_ids, dtype=np.int64),
            audio_settings,
            tts_model,
            tts_settings,
            vocoder_model,
            vocoder_settings,
            pause_before_ms=sentence.pause_before_ms,
            pause_after_ms=sentence.pause_after_ms,
        )

        futures[future] = TextToSpeechResult(
            text=sentence.text_with_ws,
            audio=None,
            sample_rate=audio_settings.sample_rate,
        )

    for future, result in futures.items():
        result.audio = future.result()

        yield result


# lang -> phoneme -> id
_PHONEME_TO_ID: typing.Dict[str, typing.Dict[str, int]] = {}

# True if stress is included in phonemes

# -----------------------------------------------------------------------------


def _sentence_task(
    text: str,
    phoneme_ids,
    audio_settings,
    tts_model,
    tts_settings,
    vocoder_model,
    vocoder_settings,
    pause_before_ms: int = 0,
    pause_after_ms: int = 0,
):
    # Run text to speech
    _LOGGER.debug(
        "Running text to speech model (%s) for '%s'", tts_model.__class__.__name__, text
    )
    tts_start_time = time.perf_counter()

    mels = tts_model.phonemes_to_mels(phoneme_ids, settings=tts_settings)
    tts_end_time = time.perf_counter()

    _LOGGER.debug(
        "Got mels in %s second(s) (shape=%s, text='%s')",
        tts_end_time - tts_start_time,
        mels.shape,
        text,
    )

    # Do denormalization, etc.
    if audio_settings.signal_norm:
        mels = audio_settings.denormalize(mels)

    if audio_settings.convert_db_to_amp:
        mels = audio_settings.db_to_amp(mels)

    if audio_settings.do_dynamic_range_compression:
        mels = audio_settings.dynamic_range_compression(mels)

    # Run vocoder
    _LOGGER.debug(
        "Running vocoder model (%s) for '%s'", vocoder_model.__class__.__name__, text
    )
    vocoder_start_time = time.perf_counter()
    audio = vocoder_model.mels_to_audio(mels, settings=vocoder_settings)
    vocoder_end_time = time.perf_counter()

    _LOGGER.debug(
        "Got audio in %s second(s) (shape=%s, text='%s')",
        vocoder_end_time - vocoder_start_time,
        audio.shape,
        text,
    )

    audio_duration_sec = audio.shape[-1] / audio_settings.sample_rate
    infer_sec = vocoder_end_time - tts_start_time
    real_time_factor = infer_sec / audio_duration_sec if audio_duration_sec > 0 else 0.0

    _LOGGER.debug(
        "Real-time factor: %0.2f (infer=%0.2f sec, audio=%0.2f sec)",
        real_time_factor,
        infer_sec,
        audio_duration_sec,
    )

    # Add pauses from SSML <break> tags
    before_samples = max(0, (pause_before_ms * audio_settings.sample_rate) // 1000)
    after_samples = max(0, (pause_after_ms * audio_settings.sample_rate) // 1000)
    if (before_samples > 0) or (after_samples > 0):
        audio = np.pad(
            audio, pad_width=(before_samples, after_samples), constant_values=0
        )

    return audio


# -----------------------------------------------------------------------------

_TTS_MODEL_CACHE: typing.Dict[str, TextToSpeechModel] = {}


def get_tts_model(
    name: str = "",
    lang: str = "en-us",
    url_format: str = DEFAULT_VOICE_URL_FORMAT,
    custom_voices_dir: typing.Optional[typing.Union[str, Path]] = None,
) -> typing.Optional[TextToSpeechModel]:
    resolved_name = resolve_voice_name(name or gruut.resolve_lang(lang))

    # Try to load model from cache first
    maybe_model = _TTS_MODEL_CACHE.get(resolved_name)

    if maybe_model is None:
        # Search for the voice
        model_dir: typing.Optional[Path] = None

        voice_lang, voice_name, voice_model_type = split_voice_name(resolved_name)
        voice_dir_name = f"{voice_name}-{voice_model_type}"

        # Directories to search for voices/vocoders
        voices_dirs = get_voices_dirs(custom_voices_dir)

        # Use directory under language first
        for voices_dir in voices_dirs:
            maybe_model_dir = voices_dir / voice_lang / voice_dir_name
            _LOGGER.debug("Checking %s for voice %s", maybe_model_dir, resolved_name)
            if valid_voice_dir(maybe_model_dir):
                model_dir = maybe_model_dir
                break

        if model_dir is None:
            # Search for voice in all directories
            for voices_dir in voices_dirs:
                for maybe_model_dir in voices_dir.rglob(resolved_name):
                    _LOGGER.debug(
                        "Checking %s for voice %s", maybe_model_dir, resolved_name
                    )
                    if valid_voice_dir(maybe_model_dir):
                        model_dir = maybe_model_dir
                        break

        if model_dir is None:
            # Download the voice
            url_voice = get_voice_download_name(resolved_name)
            assert url_voice is not None, f"No download name for voice {resolved_name}"

            url = url_format.format(voice=url_voice)
            model_dir = download_voice(resolved_name, voices_dirs[0], url)

        assert model_dir is not None, f"Voice not found: {resolved_name}"
        _LOGGER.debug("Using voice at %s", model_dir)

        # Load phonemes
        with open(model_dir / "phonemes.txt", "r", encoding="utf-8") as phonemes_file:
            phoneme_to_id = phonemes2ids.load_phoneme_ids(phonemes_file)

        # Load audio config
        config_path = model_dir / "config.json"
        _LOGGER.debug("Loading audio settings from %s", config_path)
        with open(config_path, "r", encoding="utf-8") as config_file:
            config = json.load(config_file)
            audio_settings = AudioSettings(**config["audio"])

        # Load checkpoint
        model = load_tts_model(voice_model_type, model_dir,)
        setattr(model, "phoneme_to_id", phoneme_to_id)
        setattr(model, "audio_settings", audio_settings)

        # Cache
        _TTS_MODEL_CACHE[resolved_name] = model

        if name:
            _TTS_MODEL_CACHE[name] = model

        if lang:
            _TTS_MODEL_CACHE[lang] = model

        return model

    return maybe_model


def load_tts_model(
    model_type: typing.Union[str, TextToSpeechType],
    model_path: typing.Union[str, Path],
    no_optimizations: bool = False,
) -> TextToSpeechModel:
    """Load the appropriate text to speech model"""
    sess_options = onnxruntime.SessionOptions()
    if no_optimizations:
        sess_options.graph_optimization_level = (
            onnxruntime.GraphOptimizationLevel.ORT_DISABLE_ALL
        )

    config = TextToSpeechModelConfig(
        model_path=Path(model_path), session_options=sess_options,
    )

    if model_type == TextToSpeechType.GLOW_TTS:
        from larynx.glow_tts import GlowTextToSpeech

        return GlowTextToSpeech(config)

    raise ValueError(f"Unknown text to speech model type: {model_type}")


# -----------------------------------------------------------------------------

_VOCODER_MODEL_CACHE: typing.Dict[str, VocoderModel] = {}


def get_vocoder_model(
    name_or_quality: typing.Union[str, VocoderQuality] = VocoderQuality.HIGH,
    denoiser_strength: float = 0.0,
    url_format: str = DEFAULT_VOICE_URL_FORMAT,
    custom_voices_dir: typing.Optional[typing.Union[str, Path]] = None,
) -> typing.Optional[VocoderModel]:
    # Try to load model from cache first
    maybe_model = _VOCODER_MODEL_CACHE.get(name_or_quality)

    if maybe_model is None:
        # Search for the vocoder
        model_dir: typing.Optional[Path] = None
        model_type, model_name = VOCODER_QUALITY.get(
            name_or_quality, name_or_quality
        ).split("/", maxsplit=1)

        # Directories to search for voices/vocoders
        voices_dirs = get_voices_dirs(custom_voices_dir)

        # Use directory under language first
        for voices_dir in voices_dirs:
            maybe_model_dir = voices_dir / model_type / model_name
            _LOGGER.debug(
                "Checking %s for vocoder %s", maybe_model_dir, name_or_quality
            )
            if valid_voice_dir(maybe_model_dir):
                model_dir = maybe_model_dir
                break

        if model_dir is None:
            # Download the vocoder
            url = url_format.format(voice=f"{model_type}_{model_name}")
            model_dir = download_voice(model_name, voices_dirs[0], url)

        assert model_dir is not None, f"Vocoder not found: {model_name}"
        _LOGGER.debug("Using vocoder at %s", model_dir)

        model = load_vocoder_model(
            VocoderType.HIFI_GAN, model_dir, denoiser_strength=denoiser_strength,
        )

        # Cache
        _VOCODER_MODEL_CACHE[name_or_quality] = model

        return model

    return maybe_model


def load_vocoder_model(
    model_type: typing.Union[str, VocoderType],
    model_path: typing.Union[str, Path],
    no_optimizations: bool = False,
    denoiser_strength: float = 0.0,
    executor: typing.Optional[Executor] = None,
) -> VocoderModel:
    """Load the appropriate vocoder model"""
    sess_options = onnxruntime.SessionOptions()
    if no_optimizations:
        sess_options.graph_optimization_level = (
            onnxruntime.GraphOptimizationLevel.ORT_DISABLE_ALL
        )

    config = VocoderModelConfig(
        model_path=Path(model_path),
        session_options=sess_options,
        denoiser_strength=denoiser_strength,
    )

    if model_type == VocoderType.HIFI_GAN:
        from larynx.hifi_gan import HiFiGanVocoder

        return HiFiGanVocoder(config, executor=executor)

    raise ValueError(f"Unknown vocoder model type: {model_type}")
