#!/usr/bin/env python3
"""OpenTTS web server"""
import argparse
import asyncio
import dataclasses
import hashlib
import io
import logging
import signal
import tempfile
import time
import typing
import wave
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
from swagger_ui import quart_api_doc

from tts import (
    EspeakTTS,
    FestivalTTS,
    FliteTTS,
    LarynxTTS,
    MaryTTSLocal,
    MaryTTSRemote,
    MozillaTTS,
    NanoTTS,
    TTSBase,
)

_DIR = Path(__file__).parent
_VOICES_DIR = _DIR / "voices"

_LOGGER = logging.getLogger("opentts")
_LOOP = asyncio.get_event_loop()

# Language to default to in dropdown list
_DEFAULT_LANGUAGE = "en"
lang_path = _DIR / "LANGUAGE"
if lang_path.is_file():
    _DEFAULT_LANGUAGE = lang_path.read_text().strip()

# -----------------------------------------------------------------------------

parser = argparse.ArgumentParser(prog="opentts")
parser.add_argument(
    "--host", default="0.0.0.0", help="Host of HTTP server (default: 0.0.0.0)"
)
parser.add_argument(
    "--port", type=int, default=5500, help="Port of HTTP server (default: 5500)"
)

parser.add_argument("--no-espeak", action="store_true", help="Don't use espeak")
parser.add_argument("--no-flite", action="store_true", help="Don't use flite")
parser.add_argument(
    "--flite-voices-dir",
    help="Directory where flite voices are stored (default: bundled)",
)
parser.add_argument("--no-festival", action="store_true", help="Don't use festival")
parser.add_argument("--no-nanotts", action="store_true", help="Don't use nanotts")
parser.add_argument(
    "--marytts-url", help="URL of MaryTTS server (e.g., http://localhost:59125)"
)
parser.add_argument(
    "--mozillatts-url", help="URL of MozillaTTS server (e.g., http://localhost:5002)"
)
parser.add_argument(
    "--marytts-like",
    nargs=2,
    action="append",
    help="Name and URL of MaryTTS-like server",
)
parser.add_argument("--no-larynx", action="store_true", help="Don't use Larynx")
parser.add_argument(
    "--cache",
    nargs="?",
    const="",
    help="Cache WAV files in a provided or temporary directory",
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
    default=0.001,
    help="Larynx denoiser strength to use if not specified in API call (default: 0.001)",
)
parser.add_argument(
    "--larynx-noise-scale",
    type=float,
    default=0.333,
    help="Larynx noise scale (voice volatility) to use if not specified in API call (default: 0.333)",
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
        _CACHE_TEMP_DIR = tempfile.TemporaryDirectory(prefix="larynx_")
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
if not args.no_espeak:
    _TTS["espeak"] = EspeakTTS()

# flite
if not args.no_flite:
    flite_voices_dir = _VOICES_DIR / "flite"
    if args.flite_voices_dir:
        flite_voices_dir = Path(args.flite_voices_dir)

    _TTS["flite"] = FliteTTS(voice_dir=flite_voices_dir)

# festival
if not args.no_festival:
    _TTS["festival"] = FestivalTTS()

# nanotts
if not args.no_nanotts:
    _TTS["nanotts"] = NanoTTS()

# MaryTTS
if args.marytts_url:
    if not args.marytts_url.endswith("/"):
        args.marytts_url += "/"

    _TTS["marytts"] = MaryTTSRemote(url=args.marytts_url)
else:
    _TTS["marytts"] = MaryTTSLocal(base_dir=(_VOICES_DIR / "marytts"))

# MozillaTTS
if args.mozillatts_url:
    if not args.mozillatts_url.endswith("/"):
        args.mozillatts_url += "/"

    _TTS["mozillatts"] = MozillaTTS(url=args.mozillatts_url)

if args.marytts_like:
    for tts_name_, tts_url_ in args.marytts_like:
        if not tts_url_.endswith("/"):
            tts_url_ += "/"

        _TTS[tts_name_] = MaryTTSRemote(url=tts_url_)

# Larynx
if not args.no_larynx:
    _TTS["larynx"] = LarynxTTS(models_dir=(_VOICES_DIR / "larynx"))

_LOGGER.debug("Loaded TTS systems: %s", ", ".join(_TTS.keys()))

# -----------------------------------------------------------------------------

app = Quart("opentts")
app.secret_key = str(uuid4())

if args.debug:
    app.config["TEMPLATES_AUTO_RELOAD"] = True

app = quart_cors.cors(app)

# -----------------------------------------------------------------------------

# quality level -> vocoder name
_LARYNX_QUALITY = {
    "high": "hifi_gan:universal_large",
    "medium": "hifi_gan:vctk_medium",
    "low": "hifi_gan:vctk_low",
}


async def text_to_wav(
    text: str,
    voice: str,
    vocoder: typing.Optional[str] = None,
    denoiser_strength: typing.Optional[float] = None,
    use_cache: bool = True,
) -> bytes:
    """Runs TTS for each line and accumulates all audio into a single WAV."""
    assert voice, "No voice provided"
    assert ":" in voice, "Voice format is tts:voice"

    # Look up in cache
    wav_bytes = bytes()
    cache_path: typing.Optional[Path] = None

    if use_cache and (_CACHE_DIR is not None):
        # Ensure unique cache id for different denoiser values
        settings_str = f"denoiser_strength={denoiser_strength}"
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

    tts_name, voice_id = voice.split(":")
    tts = _TTS.get(tts_name.lower())
    assert tts, f"No TTS named {tts_name}"

    # Synthesize each line separately.
    # Accumulate into a single WAV file.
    _LOGGER.info("Synthesizing with %s (%s char(s))...", voice, len(text))
    start_time = time.time()
    wav_settings_set = False

    with io.BytesIO() as wav_io:
        wav_file: wave.Wave_write = wave.open(wav_io, "wb")
        for line_index, line in enumerate(text.strip().splitlines()):
            _LOGGER.debug(
                "Synthesizing line %s (%s char(s))", line_index + 1, len(line)
            )
            line_wav_bytes = await tts.say(
                line, voice_id, vocoder=vocoder, denoiser_strength=denoiser_strength
            )
            assert line_wav_bytes, f"No WAV audio from line: {line}"
            _LOGGER.debug(
                "Got %s WAV byte(s) for line %s", len(line_wav_bytes), line_index + 1
            )

            # Open up and add to main WAV
            with io.BytesIO(line_wav_bytes) as line_wav_io:
                with wave.open(line_wav_io, "rb") as line_wav_file:
                    if not wav_settings_set:
                        # Copy settings from first WAV
                        wav_file.setframerate(line_wav_file.getframerate())
                        wav_file.setsampwidth(line_wav_file.getsampwidth())
                        wav_file.setnchannels(line_wav_file.getnchannels())
                        wav_settings_set = True

                    wav_file.writeframes(
                        line_wav_file.readframes(line_wav_file.getnframes())
                    )

        # All lines combined
        wav_file.close()
        wav_bytes = wav_io.getvalue()

    end_time = time.time()
    _LOGGER.debug(
        "Synthesized %s byte(s) in %s second(s)", len(wav_bytes), end_time - start_time
    )

    if wav_bytes and (cache_path is not None):
        try:
            _LOGGER.debug("Writing to cache: %s", cache_path)
            cache_path.write_bytes(wav_bytes)
        except Exception:
            # Continue if a cache write fails
            _LOGGER.exception("cache save")

    return wav_bytes


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


@app.route("/api/tts", methods=["GET", "POST"])
async def app_say() -> Response:
    """Speak text to WAV."""
    voice = request.args.get("voice", "")
    assert voice, "No voice provided"

    # cache=false or cache=0 disables WAV cache
    use_cache = request.args.get("cache", "").strip().lower() not in {"false", "0"}

    # Text can come from POST body or GET ?text arg
    if request.method == "POST":
        text = (await request.data).decode()
    else:
        text = request.args.get("text")

    assert text, "No text provided"

    vocoder = request.args.get("vocoder", _LARYNX_QUALITY.get(args.larynx_quality))
    denoiser_strength = request.args.get(
        "denoiserStrength", args.larynx_denoiser_strength
    )
    if denoiser_strength is not None:
        denoiser_strength = float(denoiser_strength)

    wav_bytes = await text_to_wav(
        text,
        voice,
        vocoder=vocoder,
        denoiser_strength=denoiser_strength,
        use_cache=use_cache,
    )

    return Response(wav_bytes, mimetype="audio/wav")


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
    voice, vocoder = voice.split(";", maxsplit=1)

    wav_bytes = await text_to_wav(text, voice, vocoder=vocoder)

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


# -----------------------------------------------------------------------------


@app.route("/")
async def app_index():
    """Test page."""
    return await render_template("index.html", default_language=_DEFAULT_LANGUAGE)


@app.route("/css/<path:filename>", methods=["GET"])
async def css(filename) -> Response:
    """CSS static endpoint."""
    return await send_from_directory("css", filename)


@app.route("/img/<path:filename>", methods=["GET"])
async def img(filename) -> Response:
    """Image static endpoint."""
    return await send_from_directory("img", filename)


# Swagger UI
quart_api_doc(app, config_path="swagger.yaml", url_prefix="/openapi", title="OpenTTS")


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
