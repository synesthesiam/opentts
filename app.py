#!/usr/bin/env python3
"""OpenTTS web server"""
import argparse
import asyncio
import dataclasses
import hashlib
import io
import itertools
import logging
import math
import re
import shutil
import signal
import tempfile
import time
import typing
import wave
from collections import defaultdict
from pathlib import Path
from urllib.parse import parse_qs
from uuid import uuid4

import hypercorn
import quart_cors
from quart import (
    Quart,
    Response,
    jsonify,
    render_template,
    request,
    send_from_directory,
)
from swagger_ui import api_doc

import gruut
from tts import (
    CoquiTTS,
    EspeakTTS,
    FestivalTTS,
    FliteTTS,
    GlowSpeakTTS,
    LarynxTTS,
    MaryTTS,
    NanoTTS,
    TTSBase,
)

_DIR = Path(__file__).parent
_VOICES_DIR = _DIR / "voices"
_VERSION = (_DIR / "VERSION").read_text().strip()

_LOGGER = logging.getLogger("opentts")
_LOOP = asyncio.get_event_loop()

WAV_AND_SAMPLE_RATE = typing.Tuple[bytes, int]


# Language to default to in dropdown list
_DEFAULT_LANGUAGE = "en"
lang_path = _DIR / "LANGUAGE"
if lang_path.is_file():
    _DEFAULT_LANGUAGE = lang_path.read_text().strip()

_VOICE_ALIASES: typing.Dict[str, typing.List[str]] = defaultdict(list)

# Add default aliases
_VOICE_ALIASES["en"] = ["glow-speak:en-us_mary_ann", "nanotts:en-GB"]
_VOICE_ALIASES["en-gb"] = ["larynx:ek-glow_tts", "nanotts:en-GB"]

_VOICE_ALIASES["de"] = ["glow-speak:de_thorsten", "nanotts:de-DE"]
_VOICE_ALIASES["es"] = ["glow-speak:es_tux", "nanotts:es-ES"]
_VOICE_ALIASES["fr"] = ["glow-speak:fr_siwis", "nanotts:fr-FR"]
_VOICE_ALIASES["it"] = ["glow-speak:it_riccardo_fasol", "nanotts:it-IT"]

_VOICE_ALIASES["el"] = ["glow-speak:el_rapunzelina"]
_VOICE_ALIASES["fi"] = ["glow-speak:fi_harri_tapani_ylilammi"]
_VOICE_ALIASES["hu"] = ["glow-speak:hu_diana_majlinger"]
_VOICE_ALIASES["ko"] = ["glow-speak:ko_kss"]
_VOICE_ALIASES["nl"] = ["glow-speak:nl_rdh"]
_VOICE_ALIASES["ru"] = ["glow-speak:ru_nikolaev"]
_VOICE_ALIASES["sv"] = ["glow-speak:sv_talesyntese"]
_VOICE_ALIASES["sw"] = ["glow-speak:sw_biblia_takatifu"]

_VOICE_ALIASES["ar"] = ["festival:ara_norm_ziad_hts"]
_VOICE_ALIASES["bn"] = ["flite:cmu_indic_ben_rm"]
_VOICE_ALIASES["ca"] = ["festival:upc_ca_ona_hts"]
_VOICE_ALIASES["cs"] = ["festival:czech_dita"]
_VOICE_ALIASES["gu"] = ["flite:cmu_indic_guj_ad"]
_VOICE_ALIASES["hi"] = ["flite:cmu_indic_hin_ab"]
_VOICE_ALIASES["kn"] = ["flite:cmu_indic_kan_plv"]
_VOICE_ALIASES["mr"] = ["flite:cmu_indic_mar_aup"]
_VOICE_ALIASES["pa"] = ["flite:cmu_indic_pan_amp"]
_VOICE_ALIASES["ta"] = ["flite:cmu_indic_tam_sdr"]
_VOICE_ALIASES["te"] = ["marytts:cmu-nk-hsmm"]
_VOICE_ALIASES["tr"] = ["marytts:dfki-ot-hsmm"]

_VOICE_ALIASES["ja"] = ["coqui-tts:ja_kokoro"]
_VOICE_ALIASES["zh"] = ["coqui-tts:zh_baker"]

# -----------------------------------------------------------------------------

parser = argparse.ArgumentParser(prog="opentts")
parser.add_argument(
    "--host", default="0.0.0.0", help="Host of HTTP server (default: 0.0.0.0)"
)
parser.add_argument(
    "--port", type=int, default=5500, help="Port of HTTP server (default: 5500)"
)
parser.add_argument("--language", help="Override default language")

parser.add_argument("--no-espeak", action="store_true", help="Don't use espeak")
parser.add_argument("--no-flite", action="store_true", help="Don't use flite")
parser.add_argument(
    "--flite-voices-dir",
    help="Directory where flite voices are stored (default: bundled)",
)
parser.add_argument("--no-festival", action="store_true", help="Don't use festival")
parser.add_argument("--no-nanotts", action="store_true", help="Don't use nanotts")
parser.add_argument("--no-marytts", action="store_true", help="Don't use MaryTTS")
parser.add_argument("--no-larynx", action="store_true", help="Don't use Larynx")
parser.add_argument("--no-glow-speak", action="store_true", help="Don't use Glow-Speak")
parser.add_argument("--no-coqui", action="store_true", help="Don't use CoquiTTS")
parser.add_argument(
    "--cache",
    nargs="?",
    const="",
    help="Cache WAV files in a provided or temporary directory",
)
parser.add_argument(
    "--preferred-voice",
    nargs=2,
    metavar=("lang", "voice"),
    action="append",
    help="Preferred voice for a language with SSML",
)
parser.add_argument(
    "--debug", action="store_true", help="Print DEBUG messages to console"
)

# Larynx-specific settings
parser.add_argument(
    "--larynx-quality",
    choices=["high", "medium", "low"],
    default="high",
    help="Larynx vocoder quality to use if not specified in API call (default: high)",
)
parser.add_argument(
    "--larynx-denoiser-strength",
    type=float,
    default=0.005,
    help="Larynx denoiser strength to use if not specified in API call (default: 0.005)",
)
parser.add_argument(
    "--larynx-noise-scale",
    type=float,
    default=0.667,
    help="Larynx noise scale (voice volatility) to use if not specified in API call (default: 0.667)",
)
parser.add_argument(
    "--larynx-length-scale",
    type=float,
    default=1.0,
    help="Larynx length scale (< 1 is faster) to use if not specified in API call (default: 1.0)",
)

args = parser.parse_args()

if args.debug:
    logging.basicConfig(level=logging.DEBUG)
else:
    logging.basicConfig(level=logging.INFO)

_LOGGER.debug(args)

if args.language:
    _DEFAULT_LANGUAGE = args.language

_LOGGER.debug("Default language: %s", _DEFAULT_LANGUAGE)

if args.preferred_voice:
    for pref_lang, pref_voice in args.preferred_voice:
        _VOICE_ALIASES[pref_lang].insert(0, pref_voice)

# -----------------------------------------------------------------------------

# Set up WAV cache
_CACHE_DIR: typing.Optional[Path] = None
_CACHE_TEMP_DIR: typing.Optional[tempfile.TemporaryDirectory] = None

if args.cache is not None:
    if args.cache:
        # User-specified cache directory
        _CACHE_DIR = Path(args.cache)
    else:
        # Temporary directory
        # pylint: disable=consider-using-with
        _CACHE_TEMP_DIR = tempfile.TemporaryDirectory(prefix="opentts_")
        _CACHE_DIR = Path(_CACHE_TEMP_DIR.name)

    _LOGGER.debug("Caching WAV files in %s", _CACHE_DIR)


def get_cache_key(text: str, voice: str, settings: str = "") -> str:
    """Get hashed WAV name for cache"""
    cache_key_str = f"{text}-{voice}-{settings}"
    return hashlib.sha256(cache_key_str.encode("utf-8")).hexdigest()


# -----------------------------------------------------------------------------

# Load text to speech systems
_TTS: typing.Dict[str, TTSBase] = {}

# espeak
if (not args.no_espeak) and shutil.which("espeak-ng"):
    _TTS["espeak"] = EspeakTTS()

# flite
if (not args.no_flite) and shutil.which("flite"):
    flite_voices_dir = _VOICES_DIR / "flite"
    if args.flite_voices_dir:
        flite_voices_dir = Path(args.flite_voices_dir)

    _TTS["flite"] = FliteTTS(voice_dir=flite_voices_dir)

# festival
if (not args.no_festival) and shutil.which("festival"):
    _TTS["festival"] = FestivalTTS()

# nanotts
if (not args.no_nanotts) and shutil.which("nanotts"):
    _TTS["nanotts"] = NanoTTS()

# MaryTTS
if (not args.no_marytts) and shutil.which("java"):
    _TTS["marytts"] = MaryTTS(base_dir=(_VOICES_DIR / "marytts"))

# Larynx
if not args.no_larynx:
    try:
        import larynx  # noqa: F401

        larynx_available = True
    except Exception:
        larynx_available = False

        if args.debug:
            _LOGGER.exception("larynx")

    if larynx_available:
        _TTS["larynx"] = LarynxTTS(models_dir=(_VOICES_DIR / "larynx"))

# Glow-Speak
if not args.no_glow_speak:
    try:
        import glow_speak  # noqa: F401

        glow_speak_available = True
    except Exception:
        glow_speak_available = False

        if args.debug:
            _LOGGER.exception("glow-speak")

    if glow_speak_available:
        _TTS["glow-speak"] = GlowSpeakTTS(models_dir=(_VOICES_DIR / "glow-speak"))

# Coqui-TTS
if not args.no_coqui:
    try:
        import TTS  # noqa: F401

        coqui_available = True
    except Exception:
        coqui_available = False

        if args.debug:
            _LOGGER.exception("coqui-tts")

    if coqui_available:
        _TTS["coqui-tts"] = CoquiTTS(models_dir=(_VOICES_DIR / "coqui-tts"))

_LOGGER.debug("Loaded TTS systems: %s", ", ".join(_TTS.keys()))

# -----------------------------------------------------------------------------

app = Quart("opentts")
app.secret_key = str(uuid4())

if args.debug:
    app.config["TEMPLATES_AUTO_RELOAD"] = True

app = quart_cors.cors(app)

# -----------------------------------------------------------------------------


async def text_to_wav(
    text: str,
    voice: str,
    lang: str = "en",
    vocoder: typing.Optional[str] = None,
    denoiser_strength: typing.Optional[float] = None,
    noise_scale: typing.Optional[float] = None,
    length_scale: typing.Optional[float] = None,
    use_cache: bool = True,
    ssml: bool = False,
    ssml_args: typing.Optional[typing.Dict[str, typing.Any]] = None,
) -> bytes:
    """Runs TTS for each line and accumulates all audio into a single WAV."""
    assert voice, "No voice provided"

    # Look up in cache
    wav_bytes = bytes()
    cache_path: typing.Optional[Path] = None

    if use_cache and (_CACHE_DIR is not None):
        # Ensure unique cache id for different denoiser values
        settings_str = f"denoiser_strength={denoiser_strength};noise_scale={noise_scale};length_scale={length_scale};ssml={ssml}"
        cache_key = get_cache_key(text=text, voice=voice, settings=settings_str)
        cache_path = _CACHE_DIR / f"{cache_key}.wav"
        if cache_path.is_file():
            try:
                _LOGGER.debug("Loading from cache: %s", cache_path)
                wav_bytes = cache_path.read_bytes()
                return wav_bytes
            except Exception:
                # Allow synthesis to proceed if cache fails
                _LOGGER.exception("cache load")

    # -------------------------------------------------------------------------
    # Synthesis
    # -------------------------------------------------------------------------

    # Synthesize text and accumulate into a single WAV file.
    _LOGGER.info("Synthesizing with %s (%s char(s))...", voice, len(text))
    start_time = time.time()

    if ssml:
        wavs_gen = ssml_to_wavs(
            ssml_text=text,
            default_voice=voice,
            default_lang=lang,
            ssml_args=ssml_args,
            # Larynx settings
            vocoder=vocoder,
            denoiser_strength=denoiser_strength,
            noise_scale=noise_scale,
            length_scale=length_scale,
        )
    else:
        wavs_gen = text_to_wavs(
            text=text,
            voice=voice,
            # Larynx settings
            vocoder=vocoder,
            denoiser_strength=denoiser_strength,
            noise_scale=noise_scale,
            length_scale=length_scale,
        )

    wavs = [result async for result in wavs_gen]
    assert wavs, "No audio returned from synthesis"

    # Final output WAV will use the maximum sample rate
    sample_rates = set(sample_rate for (_wav, sample_rate) in wavs)
    final_sample_rate = max(sample_rates)
    final_sample_width = 2  # bytes (16-bit)
    final_n_channels = 1  # mono

    with io.BytesIO() as final_wav_io:
        final_wav_file: wave.Wave_write = wave.open(final_wav_io, "wb")
        with final_wav_file:
            final_wav_file.setframerate(final_sample_rate)
            final_wav_file.setsampwidth(final_sample_width)
            final_wav_file.setnchannels(final_n_channels)

            # Copy audio from each syntheiszed WAV to the final output.
            # If rate/width/channels do not match, resample with sox.
            for synth_wav_bytes, _synth_sample_rate in wavs:
                with io.BytesIO(synth_wav_bytes) as synth_wav_io:
                    synth_wav_file: wave.Wave_read = wave.open(synth_wav_io, "rb")

                    # Check settings
                    if (
                        (synth_wav_file.getframerate() != final_sample_rate)
                        or (synth_wav_file.getsampwidth() != final_sample_width)
                        or (synth_wav_file.getnchannels() != final_n_channels)
                    ):
                        # Upsample with sox
                        sox_cmd = [
                            "sox",
                            "-t",
                            "wav",
                            "-",
                            "-t",
                            "raw",
                            "-r",
                            str(final_sample_rate),
                            "-b",
                            str(final_sample_width * 8),  # bits
                            "-c",
                            str(final_n_channels),
                            "-",
                        ]
                        _LOGGER.debug(sox_cmd)
                        proc = await asyncio.create_subprocess_exec(
                            *sox_cmd,
                            stdin=asyncio.subprocess.PIPE,
                            stdout=asyncio.subprocess.PIPE,
                        )
                        resampled_raw_bytes, _ = await proc.communicate(
                            input=synth_wav_bytes
                        )
                        final_wav_file.writeframes(resampled_raw_bytes)
                    else:
                        # Settings match, can write frames directly
                        final_wav_file.writeframes(
                            synth_wav_file.readframes(synth_wav_file.getnframes())
                        )

        final_wav_bytes = final_wav_io.getvalue()

    end_time = time.time()
    _LOGGER.debug(
        "Synthesized %s byte(s) in %s second(s)",
        len(final_wav_bytes),
        end_time - start_time,
    )

    if final_wav_bytes and (cache_path is not None):
        try:
            _LOGGER.debug("Writing to cache: %s", cache_path)
            cache_path.write_bytes(final_wav_bytes)
        except Exception:
            # Continue if a cache write fails
            _LOGGER.exception("cache save")

    return final_wav_bytes


async def text_to_wavs(
    text: str, voice: str, **say_args
) -> typing.AsyncIterable[WAV_AND_SAMPLE_RATE]:
    voice = resolve_voice(voice)

    assert ":" in voice, f"Invalid voice: {voice}"
    tts_name, voice_id = voice.split(":", maxsplit=1)
    tts = _TTS.get(tts_name.lower())
    assert tts, f"No TTS named {tts_name}"

    if "#" in voice_id:
        voice_id, speaker_id = voice_id.split("#", maxsplit=1)
        say_args["speaker_id"] = speaker_id

    # Process by line with single TTS
    for line_index, line in enumerate(text.strip().splitlines()):
        line = line.strip()
        if not line:
            continue

        _LOGGER.debug("Synthesizing line %s: %s", line_index + 1, line)
        line_wav_bytes = await tts.say(line, voice_id, **say_args)

        assert line_wav_bytes, f"No WAV audio from line: {line_index+1}"
        _LOGGER.debug(
            "Got %s WAV byte(s) for line %s", len(line_wav_bytes), line_index + 1,
        )

        with io.BytesIO(line_wav_bytes) as line_wav_io:
            line_wav_file: wave.Wave_read = wave.open(line_wav_io, "rb")
            with line_wav_file:
                yield (line_wav_bytes, line_wav_file.getframerate())


async def ssml_to_wavs(
    ssml_text: str,
    default_lang: str,
    default_voice: str,
    ssml_args: typing.Optional[typing.Dict[str, typing.Any]] = None,
    **say_args,
) -> typing.AsyncIterable[WAV_AND_SAMPLE_RATE]:
    if ssml_args is None:
        ssml_args = {}

    for sent_index, sentence in enumerate(
        gruut.sentences(
            ssml_text,
            lang=default_lang,
            ssml=True,
            explicit_lang=False,
            phonemes=False,
            pos=False,
            **ssml_args,
        )
    ):
        sent_text = sentence.text_with_ws
        if not sent_text.strip():
            # Skip empty sentences
            continue

        sent_voice = default_voice
        if sentence.voice:
            sent_voice = sentence.voice
        elif sentence.lang and (sentence.lang != default_lang):
            sent_voice = sentence.lang

        sent_voice = resolve_voice(sent_voice)

        assert ":" in sent_voice, f"Invalid voice format: {sent_voice}"
        tts_name, voice_id = sent_voice.split(":")
        tts = _TTS.get(tts_name.lower())
        assert tts, f"No TTS named {tts_name}"

        if "#" in voice_id:
            voice_id, speaker_id = voice_id.split("#", maxsplit=1)
            say_args["speaker_id"] = speaker_id
        else:
            # Need to remove speaker id for single speaker voices
            say_args.pop("speaker_id", None)

        _LOGGER.debug(
            "Synthesizing sentence %s with voice %s: %s",
            sent_index + 1,
            sent_voice,
            sent_text.strip(),
        )

        sent_wav_bytes = await tts.say(sent_text, voice_id, **say_args)
        assert sent_wav_bytes, f"No WAV audio from sentence: {sent_text}"
        _LOGGER.debug(
            "Got %s WAV byte(s) for line %s", len(sent_wav_bytes), sent_index + 1,
        )

        # Add WAV bytes and sample rate to list.
        # We will resample everything and append audio at the end.
        with io.BytesIO(sent_wav_bytes) as sent_wav_io:
            sent_wav_file: wave.Wave_read = wave.open(sent_wav_io, "rb")
            with sent_wav_file:
                sample_rate = sent_wav_file.getframerate()
                sample_width = sent_wav_file.getsampwidth()
                n_channels = sent_wav_file.getnchannels()

                # Add pauses from SSML <break> tags
                pause_before_ms = sentence.pause_before_ms
                if sentence.words:
                    # Add pause from first word
                    pause_before_ms += sentence.words[0].pause_before_ms

                if pause_before_ms > 0:
                    pause_before_sec = pause_before_ms / 1000
                    yield (
                        make_silence_wav(
                            pause_before_sec, sample_rate, sample_width, n_channels,
                        ),
                        sample_rate,
                    )

                yield (sent_wav_bytes, sample_rate)

                pause_after_ms = sentence.pause_after_ms
                if sentence.words:
                    # Add pause from last word
                    pause_after_ms += sentence.words[-1].pause_after_ms

                if pause_after_ms > 0:
                    pause_after_sec = pause_after_ms / 1000
                    yield (
                        make_silence_wav(
                            pause_after_sec, sample_rate, sample_width, n_channels,
                        ),
                        sample_rate,
                    )


def make_silence_wav(
    seconds: float, sample_rate: int, sample_width: int, num_channels: int
) -> bytes:
    """Create a WAV file with silence"""
    with io.BytesIO() as wav_io:
        wav_file: wave.Wave_write = wave.open(wav_io, "wb")
        with wav_file:
            wav_file.setframerate(sample_rate)
            wav_file.setsampwidth(sample_width)
            wav_file.setnchannels(num_channels)

            num_zeros = int(
                math.ceil(seconds * sample_rate * sample_width * num_channels)
            )
            wav_file.writeframes(bytes(num_zeros))

        return wav_io.getvalue()


# -----------------------------------------------------------------------------
# HTTP Endpoints
# -----------------------------------------------------------------------------


@app.route("/api/voices")
async def app_voices() -> Response:
    """Get available voices."""
    languages = set(request.args.getlist("language"))
    locales = set(request.args.getlist("locale"))
    genders = set(request.args.getlist("gender"))
    tts_names = set(request.args.getlist("tts_name"))

    voices: typing.Dict[str, typing.Any] = {}
    for tts_name, tts in _TTS.items():
        if tts_names and (tts_name not in tts_names):
            # Skip TTS
            continue

        async for voice in tts.voices():
            if languages and (voice.language not in languages):
                # Skip language
                continue

            if locales and (voice.locale not in locales):
                # Skip locale
                continue

            if genders and (voice.gender not in genders):
                # Skip gender
                continue

            # Prepend TTS system name to voice ID
            full_id = f"{tts_name}:{voice.id}"
            voices[full_id] = dataclasses.asdict(voice)

            # Add TTS name
            voices[full_id]["tts_name"] = tts_name

    return jsonify(voices)


@app.route("/api/languages")
async def app_languages() -> Response:
    """Get available languages."""
    tts_names = set(request.args.getlist("tts_name"))
    languages: typing.Set[str] = set()

    for tts_name, tts in _TTS.items():
        if tts_names and (tts_name not in tts_names):
            # Skip TTS
            continue

        async for voice in tts.voices():
            languages.add(voice.language)

    return jsonify(list(languages))


def convert_bool(bool_str: str) -> bool:
    """Convert HTML input string to boolean"""
    return bool_str.strip().lower() in {"true", "yes", "on", "1", "enable"}


@app.route("/api/tts", methods=["GET", "POST"])
async def app_say() -> Response:
    """Speak text to WAV."""
    lang = request.args.get("lang", "en")

    voice = request.args.get("voice", "")
    assert voice, "No voice provided"

    # cache=false or cache=0 disables WAV cache
    use_cache = convert_bool(request.args.get("cache", "false"))

    # Text can come from POST body or GET ?text arg
    if request.method == "POST":
        text = (await request.data).decode()
    else:
        text = request.args.get("text", "")

    assert text, "No text provided"

    vocoder = request.args.get("vocoder", args.larynx_quality)

    # Denoiser strength
    denoiser_strength = request.args.get(
        "denoiserStrength", args.larynx_denoiser_strength
    )
    if denoiser_strength is not None:
        denoiser_strength = float(denoiser_strength)

    # Noise and length scales
    noise_scale = request.args.get("noiseScale", args.larynx_noise_scale)
    if noise_scale is not None:
        noise_scale = float(noise_scale)

    length_scale = request.args.get("lengthScale", args.larynx_length_scale)
    if length_scale is not None:
        length_scale = float(length_scale)

    speaker_id = str(request.args.get("speakerId", ""))
    if speaker_id and ("#" not in voice):
        voice = f"{voice}#{speaker_id}"

    # SSML settings
    ssml = convert_bool(request.args.get("ssml", "false"))
    ssml_numbers = convert_bool(request.args.get("ssmlNumbers", "true"))
    ssml_dates = convert_bool(request.args.get("ssmlDates", "true"))
    ssml_currency = convert_bool(request.args.get("ssmlCurrency", "true"))

    ssml_args = {
        "verbalize_numbers": ssml_numbers,
        "verbalize_dates": ssml_dates,
        "verbalize_currency": ssml_currency,
    }

    wav_bytes = await text_to_wav(
        text=text,
        voice=voice,
        lang=lang,
        vocoder=vocoder,
        denoiser_strength=denoiser_strength,
        noise_scale=noise_scale,
        length_scale=length_scale,
        use_cache=use_cache,
        ssml=ssml,
        ssml_args=ssml_args,
    )

    return Response(wav_bytes, mimetype="audio/wav")


def resolve_voice(voice: str, fallback_voice: typing.Optional[str] = None) -> str:
    """Resolve a voice or language based on aliases"""
    original_voice = voice
    if "#" in voice:
        # Remove speaker id
        # tts:voice#speaker_id
        voice, _speaker_id = voice.split("#", maxsplit=1)

    # Resolve voices in order:
    # 1. Aliases in order of preference
    # 2. fallback voice provided
    # 3. Original voice
    # 4. espeak voice

    fallback_voices = []
    if fallback_voice is not None:
        fallback_voices.append(fallback_voice)

    fallback_voices.append(original_voice)

    alias_key = voice.lower()
    if alias_key not in _VOICE_ALIASES:
        # en-US -> en
        alias_key = re.split(r"[-_]", alias_key, maxsplit=1)[0]

    if ":" not in voice:
        fallback_voices.append(f"espeak:{voice}")

    for preferred_voice in itertools.chain(_VOICE_ALIASES[alias_key], fallback_voices):
        tts, _voice_id = preferred_voice.split(":", maxsplit=1)
        if tts in _TTS:
            # If TTS system is loaded, assume voice will be present
            return preferred_voice

    raise ValueError(f"Cannot resolve voice: {voice}")


# -----------------------------------------------------------------------------

# MaryTTS compatibility layer
@app.route("/process", methods=["GET", "POST"])
async def api_process():
    """MaryTTS-compatible /process endpoint"""
    if request.method == "POST":
        data = parse_qs((await request.data).decode())
        text = data.get("INPUT_TEXT", [""])[0]
        voice = data.get("VOICE", [""])[0]
    else:
        text = request.args.get("INPUT_TEXT", "")
        voice = request.args.get("VOICE", "")

    # <VOICE>;<VOCODER>
    vocoder: typing.Optional[str] = args.larynx_quality
    if ";" in voice:
        voice, vocoder = voice.split(";", maxsplit=1)

    wav_bytes = await text_to_wav(
        text,
        voice,
        vocoder=vocoder,
        denoiser_strength=args.larynx_denoiser_strength,
        noise_scale=args.larynx_noise_scale,
        length_scale=args.larynx_length_scale,
    )

    return Response(wav_bytes, mimetype="audio/wav")


@app.route("/voices", methods=["GET"])
async def api_voices():
    """MaryTTS-compatible /voices endpoint"""
    voices = []
    for tts_name, tts in _TTS.items():
        async for voice in tts.voices():
            # Prepend TTS system name to voice ID
            full_id = f"{tts_name}:{voice.id}"
            voices.append(full_id)

    return "\n".join(voices)


@app.route("/version", methods=["GET"])
async def api_version():
    """MaryTTS-compatible /version endpoint"""
    return _VERSION


# -----------------------------------------------------------------------------


@app.route("/")
async def app_index():
    """Test page."""
    return await render_template(
        "index.html",
        default_language=_DEFAULT_LANGUAGE,
        cache=args.cache,
        preferred_voices=_VOICE_ALIASES.get(_DEFAULT_LANGUAGE, []),
    )


@app.route("/css/<path:filename>", methods=["GET"])
async def css(filename) -> Response:
    """CSS static endpoint."""
    return await send_from_directory("css", filename)


@app.route("/js/<path:filename>", methods=["GET"])
async def js(filename) -> Response:
    """Javascript static endpoint."""
    return await send_from_directory("js", filename)


@app.route("/img/<path:filename>", methods=["GET"])
async def img(filename) -> Response:
    """Image static endpoint."""
    return await send_from_directory("img", filename)


# Swagger UI
api_doc(app, config_path="swagger.yaml", url_prefix="/openapi", title="OpenTTS")


@app.errorhandler(Exception)
async def handle_error(err) -> typing.Tuple[str, int]:
    """Return error as text."""
    _LOGGER.exception(err)
    return (f"{err.__class__.__name__}: {err}", 500)


# -----------------------------------------------------------------------------
# Run Web Server
# -----------------------------------------------------------------------------

hyp_config = hypercorn.config.Config()
hyp_config.bind = [f"{args.host}:{args.port}"]

# Create shutdown event for Hypercorn
shutdown_event = asyncio.Event()


def _signal_handler(*_: typing.Any) -> None:
    """Signal shutdown to Hypercorn"""
    shutdown_event.set()


_LOOP.add_signal_handler(signal.SIGTERM, _signal_handler)

try:
    # Need to type cast to satisfy mypy
    shutdown_trigger = typing.cast(
        typing.Callable[..., typing.Awaitable[None]], shutdown_event.wait
    )

    _LOOP.run_until_complete(
        hypercorn.asyncio.serve(app, hyp_config, shutdown_trigger=shutdown_trigger)
    )
except KeyboardInterrupt:
    _LOOP.call_soon(shutdown_event.set)
finally:
    # Clean up WAV cache
    if _CACHE_TEMP_DIR is not None:
        _CACHE_TEMP_DIR.cleanup()
