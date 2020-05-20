#!/usr/bin/env python3
import dataclasses
import logging
import typing
from pathlib import Path
from uuid import uuid4

import quart_cors
from quart import (
    Quart,
    Response,
    jsonify,
    request,
    send_file,
    redirect,
    render_template,
)
from swagger_ui import quart_api_doc

from tts import Voice, EspeakTTS, FliteTTS, FestivalTTS, NanoTTS, MaryTTS

_DIR = Path(__file__).parent
_VOICES_DIR = _DIR / "voices"

_LOGGER = logging.getLogger("opentts")
_TTS = {
    "espeak": EspeakTTS(),
    "flite": FliteTTS(_VOICES_DIR / "flite"),
    "festival": FestivalTTS(),
    "nanotts": NanoTTS(),
    "marytts": MaryTTS(),
}

logging.basicConfig(level=logging.DEBUG)

# -----------------------------------------------------------------------------

app = Quart("opentts")
app.secret_key = str(uuid4())

app = quart_cors.cors(app)

# -----------------------------------------------------------------------------


@app.route("/api/voices")
async def app_voices() -> Response:
    """Get available voices."""
    voices: typing.Dict[str, typing.Any] = {}
    for tts_name, tts in _TTS.items():
        print(tts_name)
        async for voice in tts.voices():
            # Prepend TTS system name to voice ID
            full_id = f"{tts_name}:{voice.id}"
            voices[full_id] = dataclasses.asdict(voice)

            # Add TTS name
            voices[full_id]["tts_name"] = tts_name

    return jsonify(voices)


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

    wav_bytes = await tts.say(text, voice_id)
    return Response(wav_bytes, mimetype="audio/wav")


# -----------------------------------------------------------------------------


@app.route("/")
async def app_index():
    """Test page."""
    return await render_template("index.html")


# Swagger UI
quart_api_doc(app, config_path="swagger.yaml", url_prefix="/api", title="OpenTTS")


@app.errorhandler(Exception)
async def handle_error(err) -> typing.Tuple[str, int]:
    """Return error as text."""
    _LOGGER.exception(err)
    return (f"{err.__class__.__name__}: {err}", 500)


# -----------------------------------------------------------------------------

app.run(host="0.0.0.0", port=5500)
