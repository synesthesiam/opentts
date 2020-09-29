"""Text to speech wrappers for OpenTTS"""
import asyncio
import logging
import shlex
import shutil
import ssl
import tempfile
import typing
from abc import ABCMeta
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urljoin

import aiohttp

_LOGGER = logging.getLogger("opentts")

# -----------------------------------------------------------------------------


@dataclass
class Voice:
    """Single TTS voice."""

    id: str
    name: str
    gender: str
    language: str
    locale: str


VoicesIterable = typing.AsyncGenerator[Voice, None]


class TTSBase(metaclass=ABCMeta):
    """Base class of TTS systems."""

    async def voices(self) -> VoicesIterable:
        """Get list of available voices."""
        yield Voice("", "", "", "", "")

    async def say(self, text: str, voice_id: str, **kwargs) -> bytes:
        """Speak text as WAV."""
        return bytes()


# -----------------------------------------------------------------------------


class EspeakTTS(TTSBase):
    """Wraps eSpeak (http://espeak.sourceforge.net)"""

    def __init__(self):
        self.espeak_prog = "espeak-ng"
        if not shutil.which(self.espeak_prog):
            self.espeak_prog = "espeak"

    async def voices(self) -> VoicesIterable:
        """Get list of available voices."""
        espeak_cmd = [self.espeak_prog, "--voices"]
        _LOGGER.debug(espeak_cmd)

        proc = await asyncio.create_subprocess_exec(
            *espeak_cmd, stdout=asyncio.subprocess.PIPE
        )
        stdout, _ = await proc.communicate()

        voices_lines = stdout.decode().splitlines()
        first_line = True
        for line in voices_lines:
            if first_line:
                first_line = False
                continue

            parts = line.split()
            locale = parts[1]
            language = locale.split("-", maxsplit=1)[0]

            yield Voice(
                id=parts[1],
                gender=parts[2][-1],
                name=parts[3],
                locale=locale,
                language=language,
            )

    async def say(self, text: str, voice_id: str, **kwargs) -> bytes:
        """Speak text as WAV."""
        espeak_cmd = [
            self.espeak_prog,
            "-v",
            shlex.quote(str(voice_id)),
            "--stdout",
            shlex.quote(text),
        ]
        _LOGGER.debug(espeak_cmd)

        proc = await asyncio.create_subprocess_exec(
            *espeak_cmd, stdout=asyncio.subprocess.PIPE
        )
        stdout, _ = await proc.communicate()
        return stdout


# -----------------------------------------------------------------------------


class FliteTTS(TTSBase):
    """Wraps flite (http://www.festvox.org/flite)"""

    def __init__(self, voice_dir: typing.Union[str, Path]):
        self.voice_dir = Path(voice_dir)

    async def voices(self) -> VoicesIterable:
        """Get list of available voices."""
        flite_voices = [
            # English
            Voice(
                id="cmu_us_aew",
                name="cmu_us_aew",
                gender="M",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_ahw",
                name="cmu_us_ahw",
                gender="M",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_aup",
                name="cmu_us_aup",
                gender="M",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_awb",
                name="cmu_us_awb",
                gender="M",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_axb",
                name="cmu_us_axb",
                gender="F",
                locale="en-in",
                language="en",
            ),
            Voice(
                id="cmu_us_bdl",
                name="cmu_us_bdl",
                gender="M",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_clb",
                name="cmu_us_clb",
                gender="F",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_eey",
                name="cmu_us_eey",
                gender="F",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_fem",
                name="cmu_us_fem",
                gender="M",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_gka",
                name="cmu_us_gka",
                gender="M",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_jmk",
                name="cmu_us_jmk",
                gender="M",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_ksp",
                name="cmu_us_ksp",
                gender="M",
                locale="en-in",
                language="en",
            ),
            Voice(
                id="cmu_us_ljm",
                name="cmu_us_ljm",
                gender="F",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_lnh",
                name="cmu_us_lnh",
                gender="F",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_rms",
                name="cmu_us_rms",
                gender="M",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_rxr",
                name="cmu_us_rxr",
                gender="M",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="cmu_us_slp",
                name="cmu_us_slp",
                gender="F",
                locale="en-in",
                language="en",
            ),
            Voice(
                id="cmu_us_slt",
                name="cmu_us_slt",
                gender="F",
                locale="en-us",
                language="en",
            ),
            Voice(
                id="mycroft_voice_4.0",
                name="mycroft_voice_4.0",
                gender="M",
                locale="en-us",
                language="en",
            ),
            # Indic
            Voice(
                id="cmu_indic_hin_ab",
                name="cmu_indic_hin_ab",
                gender="F",
                locale="hi-in",
                language="hi",
            ),
            Voice(
                id="cmu_indic_ben_rm",
                name="cmu_indic_ben_rm",
                gender="F",
                locale="bn-in",
                language="bn",
            ),
            Voice(
                id="cmu_indic_guj_ad",
                name="cmu_indic_guj_ad",
                gender="F",
                locale="gu-in",
                language="gu",
            ),
            Voice(
                id="cmu_indic_guj_dp",
                name="cmu_indic_guj_dp",
                gender="F",
                locale="gu-in",
                language="gu",
            ),
            Voice(
                id="cmu_indic_guj_kt",
                name="cmu_indic_guj_kt",
                gender="F",
                locale="gu-in",
                language="gu",
            ),
            Voice(
                id="cmu_indic_kan_plv",
                name="cmu_indic_kan_plv",
                gender="F",
                locale="kn-in",
                language="kn",
            ),
            Voice(
                id="cmu_indic_mar_aup",
                name="cmu_indic_mar_aup",
                gender="F",
                locale="mr-in",
                language="mr",
            ),
            Voice(
                id="cmu_indic_mar_slp",
                name="cmu_indic_mar_slp",
                gender="F",
                locale="mr-in",
                language="mr",
            ),
            Voice(
                id="cmu_indic_pan_amp",
                name="cmu_indic_pan_amp",
                gender="F",
                locale="pa-in",
                language="pa",
            ),
            Voice(
                id="cmu_indic_tam_sdr",
                name="cmu_indic_tam_sdr",
                gender="F",
                locale="ta-in",
                language="ta",
            ),
            Voice(
                id="cmu_indic_tel_kpn",
                name="cmu_indic_tel_kpn",
                gender="F",
                locale="te-in",
                language="te",
            ),
            Voice(
                id="cmu_indic_tel_sk",
                name="cmu_indic_tel_sk",
                gender="F",
                locale="te-in",
                language="te",
            ),
            Voice(
                id="cmu_indic_tel_ss",
                name="cmu_indic_tel_ss",
                gender="F",
                locale="te-in",
                language="te",
            ),
        ]

        for voice in flite_voices:
            yield voice

    async def say(self, text: str, voice_id: str, **kwargs) -> bytes:
        """Speak text as WAV."""
        flite_cmd = [
            "flite",
            "-voice",
            shlex.quote(str(self.voice_dir / f"{voice_id}.flitevox")),
            "-o",
            "/dev/stdout",
            "-t",
            shlex.quote(text),
        ]
        _LOGGER.debug(flite_cmd)

        proc = await asyncio.create_subprocess_exec(
            *flite_cmd, stdout=asyncio.subprocess.PIPE
        )
        stdout, _ = await proc.communicate()
        return stdout


# -----------------------------------------------------------------------------


class FestivalTTS(TTSBase):
    """Wraps festival (http://www.cstr.ed.ac.uk/projects/festival/)"""

    # Single byte text encodings for specific languages.
    # See https://en.wikipedia.org/wiki/ISO/IEC_8859
    #
    # Some encodings differ from linked article (part 1 is missing relevant
    # symbols).
    LANGUAGE_ENCODINGS = {
        "en": "iso-8859-1",
        "ru": "iso-8859-1",  # Russian is transliterated below
        "es": "iso-8859-15",  # Differs from linked article
        "ca": "iso-8859-15",  # Differs from linked article
        "cs": "iso-8859-2",
    }

    FESTIVAL_VOICES = [
        # English
        Voice(
            id="us1_mbrola",
            name="us1_mbrola",
            gender="F",
            locale="en-us",
            language="en",
        ),
        Voice(
            id="us2_mbrola",
            name="us2_mbrola",
            gender="M",
            locale="en-us",
            language="en",
        ),
        Voice(
            id="us3_mbrola",
            name="us3_mbrola",
            gender="M",
            locale="en-us",
            language="en",
        ),
        Voice(
            id="rab_diphone",
            name="rab_diphone",
            gender="M",
            locale="en-gb",
            language="en",
        ),
        Voice(
            id="en1_mbrola",
            name="en1_mbrola",
            gender="M",
            locale="en-us",
            language="en",
        ),
        Voice(
            id="ked_diphone",
            name="ked_diphone",
            gender="M",
            locale="en-us",
            language="en",
        ),
        Voice(
            id="kal_diphone",
            name="kal_diphone",
            gender="M",
            locale="en-us",
            language="en",
        ),
        Voice(
            id="cmu_us_slt_arctic_hts",
            name="cmu_us_slt_arctic_hts",
            gender="F",
            locale="en-us",
            language="en",
        ),
        # Russian
        Voice(
            id="msu_ru_nsh_clunits",
            name="msu_ru_nsh_clunits",
            gender="M",
            locale="ru-ru",
            language="ru",
        ),
        # Spanish
        Voice(
            id="el_diphone",
            name="el_diphone",
            gender="M",
            locale="es-es",
            language="es",
        ),
        # Catalan
        Voice(
            id="upc_ca_ona_hts",
            name="upc_ca_ona_hts",
            gender="F",
            locale="ca-es",
            language="ca",
        ),
        # Czech
        Voice(
            id="czech_dita",
            name="czech_dita",
            gender="F",
            locale="cs-cs",
            language="cs",
        ),
        Voice(
            id="czech_machac",
            name="czech_machac",
            gender="M",
            locale="cs-cs",
            language="cs",
        ),
        Voice(
            id="czech_ph", name="czech_ph", gender="M", locale="cs-cs", language="cs"
        ),
        Voice(
            id="czech_krb", name="czech_krb", gender="F", locale="cs-cs", language="cs"
        ),
    ]

    def __init__(self):
        self._voice_by_id = {v.id: v for v in FestivalTTS.FESTIVAL_VOICES}

    async def voices(self) -> VoicesIterable:
        """Get list of available voices."""
        for voice in FestivalTTS.FESTIVAL_VOICES:
            yield voice

    async def say(self, text: str, voice_id: str, **kwargs) -> bytes:
        """Speak text as WAV."""
        # Default to part 15 encoding to handle "special" characters.
        # See https://www.web3.lu/character-encoding-for-festival-tts-files/
        encoding = "iso-8859-15"

        # Look up encoding by language
        voice = self._voice_by_id.get(voice_id)
        if voice:
            encoding = FestivalTTS.LANGUAGE_ENCODINGS.get(voice.language, encoding)

            if voice.language == "ru":
                from transliterate import translit

                # Transliterate to Latin script
                text = translit(text, "ru", reversed=True)

        with tempfile.NamedTemporaryFile(suffix=".wav") as wav_file:
            festival_cmd = [
                "text2wave",
                "-o",
                wav_file.name,
                "-eval",
                f"(voice_{voice_id})",
            ]
            _LOGGER.debug(festival_cmd)

            proc = await asyncio.create_subprocess_exec(
                *festival_cmd,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
            )
            await proc.communicate(input=text.encode(encoding=encoding))

            wav_file.seek(0)
            return wav_file.read()


# -----------------------------------------------------------------------------


class NanoTTS(TTSBase):
    """Wraps nanoTTS (https://github.com/gmn/nanotts)"""

    async def voices(self) -> VoicesIterable:
        """Get list of available voices."""
        nanotts_voices = [
            # English
            Voice(id="en-GB", name="en-GB", gender="F", locale="en-gb", language="en"),
            Voice(id="en-US", name="en-US", gender="F", locale="en-us", language="en"),
            # German
            Voice(id="de-DE", name="de-DE", gender="F", locale="de-de", language="de"),
            # French
            Voice(id="fr-FR", name="fr-FR", gender="F", locale="fr-fr", language="fr"),
            # Spanish
            Voice(id="es-ES", name="es-ES", gender="F", locale="es-es", language="es"),
            # Italian
            Voice(id="it-IT", name="it-IT", gender="F", locale="it-it", language="it"),
        ]

        for voice in nanotts_voices:
            yield voice

    async def say(self, text: str, voice_id: str, **kwargs) -> bytes:
        """Speak text as WAV."""
        with tempfile.NamedTemporaryFile(suffix=".wav") as wav_file:
            nanotts_cmd = ["nanotts", "-v", voice_id, "-o", shlex.quote(wav_file.name)]
            _LOGGER.debug(nanotts_cmd)

            proc = await asyncio.create_subprocess_exec(
                *nanotts_cmd, stdin=asyncio.subprocess.PIPE
            )

            await proc.communicate(input=text.encode())

            wav_file.seek(0)
            return wav_file.read()


# -----------------------------------------------------------------------------


class MaryTTS(TTSBase):
    """Wraps MaryTTS (http://mary.dfki.de)"""

    def __init__(self, url="http://localhost:59125/"):
        self.url = url
        self.ssl_context = ssl.SSLContext()
        self.session = None
        self.voice_locales = {}

    async def voices(self) -> VoicesIterable:
        """Get list of available voices."""
        if not self.session:
            self.session = aiohttp.ClientSession()

        voices_url = urljoin(self.url, "voices")
        _LOGGER.debug(voices_url)

        try:
            async with self.session.get(voices_url, ssl=self.ssl_context) as response:
                response.raise_for_status()
                text = (await response.read()).decode()
                for line in text.splitlines():
                    line = line.strip()
                    if line:
                        parts = line.split()
                        locale = parts[1].replace("_", "-")
                        language = locale.split("-", maxsplit=1)[0]

                        # Cache locale
                        self.voice_locales[parts[0]] = locale

                        yield Voice(
                            id=parts[0],
                            name=parts[0],
                            gender=parts[2][0].upper(),
                            locale=locale,
                            language=language,
                        )
        except Exception:
            _LOGGER.exception("marytts")

    async def say(self, text: str, voice_id: str, **kwargs) -> bytes:
        """Speak text as WAV."""
        if not self.session:
            self.session = aiohttp.ClientSession()

        locale = self.voice_locales.get(voice_id)
        if not locale:
            async for voice in self.voices():
                if voice.id == voice_id:
                    locale = voice.locale.replace("-", "_")
                    self.voice_locales[voice.id] = locale
                    break

        params = {
            "INPUT_TYPE": "TEXT",
            "OUTPUT_TYPE": "AUDIO",
            "AUDIO": "WAVE",
            "VOICE": voice_id,
            "INPUT_TEXT": text,
            "LOCALE": locale,
        }

        process_url = urljoin(self.url, "process")
        _LOGGER.debug("%s %s", process_url, params)
        async with self.session.get(
            process_url, ssl=self.ssl_context, params=params
        ) as response:
            response.raise_for_status()
            wav_bytes = await response.read()
            return wav_bytes


# -----------------------------------------------------------------------------


class MozillaTTS(TTSBase):
    """Wraps Mozilla TTS (https://github.com/mozilla/TTS)"""

    def __init__(self, url="http://localhost:5002/"):
        self.url = url
        self.ssl_context = ssl.SSLContext()
        self.session = None
        self.voice_locales = {}

    async def voices(self) -> VoicesIterable:
        """Get list of available voices."""
        mozilla_voices = [
            Voice(id="en-us", name="en-us", locale="en-us", language="en", gender="F")
        ]

        for voice in mozilla_voices:
            yield voice

    async def say(self, text: str, voice_id: str, **kwargs) -> bytes:
        """Speak text as WAV."""
        if not self.session:
            self.session = aiohttp.ClientSession()

        params = {"text": text}

        tts_url = urljoin(self.url, "api/tts")
        async with self.session.get(
            tts_url, ssl=self.ssl_context, params=params
        ) as response:
            response.raise_for_status()
            wav_bytes = await response.read()
            return wav_bytes
