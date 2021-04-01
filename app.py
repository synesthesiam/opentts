#!/usr/bin/env python3
"""OpenTTS web server"""
import argparse
import dataclasses
import logging
import typing
from pathlib import Path
from uuid import uuid4
from hashlib import sha256
from os import path

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

from tts import EspeakTTS, FestivalTTS, FliteTTS, MaryTTS, MozillaTTS, NanoTTS, TTSBase

_DIR = Path(__file__).parent
_VOICES_DIR = _DIR / "voices"

_LOGGER = logging.getLogger("opentts")

# -----------------------------------------------------------------------------

parser = argparse.ArgumentParser(prog="opentts")
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
parser.add_argument(
    "--debug", action="store_true", help="Print DEBUG messages to console"
)
args = parser.parse_args()

if args.debug:
    logging.basicConfig(level=logging.DEBUG)
else:
    logging.basicConfig(level=logging.INFO)

_LOGGER.debug(args)

# Load text to speech systems
_TTS: typing.Dict[str, TTSBase] = {}

if not args.no_espeak:
    _TTS["espeak"] = EspeakTTS()

if not args.no_flite:
    flite_voices_dir = _VOICES_DIR / "flite"
    if args.flite_voices_dir:
        flite_voices_dir = Path(args.flite_voices_dir)

    _TTS["flite"] = FliteTTS(voice_dir=flite_voices_dir)

if not args.no_festival:
    _TTS["festival"] = FestivalTTS()

if not args.no_nanotts:
    _TTS["nanotts"] = NanoTTS()

if args.marytts_url:
    if not args.marytts_url.endswith("/"):
        args.marytts_url += "/"

    _TTS["marytts"] = MaryTTS(url=args.marytts_url)

if args.mozillatts_url:
    if not args.mozillatts_url.endswith("/"):
        args.mozillatts_url += "/"

    _TTS["mozillatts"] = MozillaTTS(url=args.mozillatts_url)

if args.marytts_like:
    for tts_name_, tts_url_ in args.marytts_like:
        if not tts_url_.endswith("/"):
            tts_url_ += "/"

        _TTS[tts_name_] = MaryTTS(url=tts_url_)

_LOGGER.debug("Loaded TTS systems: %s", ", ".join(_TTS.keys()))

# -----------------------------------------------------------------------------

app = Quart("opentts")
app.secret_key = str(uuid4())

app = quart_cors.cors(app)

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


@app.route("/api/tts")
async def app_say() -> Response:
    """Speak text to WAV."""
    voice = request.args.get("voice", "")
    assert voice, "No voice provided"

    assert ":" in voice, "Voice format is tts:voice"
    tts_name, voice_id = voice.split(":")
    tts = _TTS.get(tts_name.lower())
    assert tts, f"No TTS named {tts_name}"

    text = request.args.get("text", "").strip()
    assert text, "No text provided"

    to_hash = text + tts_name + voice_id
    cache_file_name = "/data/" + sha256(to_hash.encode('utf-8')).hexdigest()

    wav_bytes = b''
    if path.exists(cache_file_name):
        with open(cache_file_name, 'rb') as f:
            wav_bytes = f.read()
    if not wav_bytes:
        wav_bytes = await tts.say(text, voice_id)
        if wav_bytes:
            with open(cache_file_name, 'wb') as f:
                f.write(wav_bytes)
    return Response(wav_bytes, mimetype="audio/wav")


# -----------------------------------------------------------------------------


@app.route("/")
async def app_index():
    """Test page."""
    return await render_template("index.html")


@app.route("/css/<path:filename>", methods=["GET"])
async def css(filename) -> Response:
    """CSS static endpoint."""
    return await send_from_directory("css", filename)


@app.route("/img/<path:filename>", methods=["GET"])
async def img(filename) -> Response:
    """Image static endpoint."""
    return await send_from_directory("img", filename)


# Swagger UI
quart_api_doc(app, config_path="swagger.yaml", url_prefix="/api", title="OpenTTS")


@app.errorhandler(Exception)
async def handle_error(err) -> typing.Tuple[str, int]:
    """Return error as text."""
    _LOGGER.exception(err)
    return (f"{err.__class__.__name__}: {err}", 500)


# -----------------------------------------------------------------------------

app.run(host="0.0.0.0", port=5500)
