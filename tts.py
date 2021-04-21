"""Text to speech wrappers for OpenTTS"""
import asyncio
import functools
import io
import json
import logging
import platform
import shlex
import shutil
import ssl
import tempfile
import typing
from abc import ABCMeta
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urljoin
from zipfile import ZipFile

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
    tag: typing.Optional[typing.Dict[str, typing.Any]] = None


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
            voice_path = self.voice_dir / f"{voice.id}.flitevox"
            if voice_path.is_file():
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
        "fi": "iso-8859-15",  # Differs from linked article
        "ar": "utf-8",
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
            locale="cs-cz",
            language="cs",
        ),
        Voice(
            id="czech_machac",
            name="czech_machac",
            gender="M",
            locale="cs-cz",
            language="cs",
        ),
        Voice(
            id="czech_ph", name="czech_ph", gender="M", locale="cs-cz", language="cs"
        ),
        Voice(
            id="czech_krb", name="czech_krb", gender="F", locale="cs-cz", language="cs"
        ),
        # Finnish
        Voice(
            id="suo_fi_lj_diphone",
            name="suo_fi_lj_diphone",
            gender="F",
            locale="fi-fi",
            language="fi",
        ),
        Voice(
            id="hy_fi_mv_diphone",
            name="hy_fi_mv_diphone",
            gender="M",
            locale="fi-fi",
            language="fi",
        ),
        # Telugu
        Voice(
            id="telugu_NSK_diphone",
            name="telugu_NSK_diphone",
            gender="M",
            locale="te-in",
            language="te",
        ),
        # Marathi
        Voice(
            id="marathi_NSK_diphone",
            name="marathi_NSK_diphone",
            gender="M",
            locale="mr-in",
            language="mr",
        ),
        # Hindi
        Voice(
            id="hindi_NSK_diphone",
            name="hindi_NSK_diphone",
            gender="M",
            locale="hi-in",
            language="hi",
        ),
        # Italian
        Voice(
            id="lp_diphone",
            name="lp_diphone",
            gender="F",
            locale="it-it",
            language="it",
        ),
        Voice(
            id="pc_diphone",
            name="pc_diphone",
            gender="M",
            locale="it-it",
            language="it",
        ),
        # Araabic
        Voice(
            id="ara_norm_ziad_hts",
            name="ara_norm_ziad_hts",
            gender="M",
            locale="ar",
            language="ar",
        ),
    ]

    def __init__(self):
        self._voice_by_id = {v.id: v for v in FestivalTTS.FESTIVAL_VOICES}

    async def voices(self) -> VoicesIterable:
        """Get list of available voices."""
        available_voices: typing.Set[str] = set()

        if shutil.which("festival"):
            try:
                proc = await asyncio.create_subprocess_exec(
                    "festival",
                    stdin=asyncio.subprocess.PIPE,
                    stdout=asyncio.subprocess.PIPE,
                )

                list_command = "(print (voice.list))"
                proc_stdout, _ = await proc.communicate(input=list_command.encode())
                list_result = proc_stdout.decode()

                # (voice1 voice2 ...)
                available_voices = set(list_result[1:-2].split())
                _LOGGER.debug("Festival voices: %s", available_voices)
            except Exception:
                _LOGGER.exception("Failed to get festival voices")

        for voice in FestivalTTS.FESTIVAL_VOICES:
            if (not available_voices) or (voice.id in available_voices):
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

            if voice.language == "ar":
                try:
                    # Add diacritics
                    import mishkal.tashkeel

                    vocalizer = getattr(self, "mishkal_vocalizer", None)
                    if vocalizer is None:
                        vocalizer = mishkal.tashkeel.TashkeelClass()
                        setattr(self, "mishkal_vocalizer", vocalizer)

                    text = vocalizer.tashkeel(text)
                    _LOGGER.debug("Added diacritics: %s", text)
                except ImportError:
                    _LOGGER.warning("Missing mishkal package, cannot do diacritizion.")
            elif voice.language == "ru":
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


class MaryTTSRemote(TTSBase):
    """Wraps a remote MaryTTS server (http://mary.dfki.de)"""

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


class MaryTTSLocal(TTSBase):
    """Wraps a local MaryTTS installation (http://mary.dfki.de)"""

    def __init__(self, base_dir: typing.Union[str, Path]):
        self.base_dir = Path(base_dir)
        self.voices_dict: typing.Dict[str, Voice] = {}
        self.voice_jars: typing.Dict[str, Path] = {}
        self.voice_proc: typing.Optional["asyncio.subprocess.Process"] = None
        self.proc_voice_id: typing.Optional[str] = None

    async def voices(self) -> VoicesIterable:
        """Get list of available voices."""
        self.maybe_load_voices()

        for voice in self.voices_dict.values():
            yield voice

    async def say(self, text: str, voice_id: str, **kwargs) -> bytes:
        """Speak text as WAV."""
        self.maybe_load_voices()

        if (not self.voice_proc) or (self.proc_voice_id != voice_id):
            if self.voice_proc:
                _LOGGER.debug("Stopping MaryTTS proc (voice=%s)", self.proc_voice_id)

                try:
                    self.voice_proc.terminate()
                    await self.voice_proc.wait()
                    self.voice_proc = None
                except Exception:
                    _LOGGER.exception("marytts")

            # Start new MaryTTS process
            voice = self.voices_dict.get(voice_id)
            assert voice is not None, f"No voice for id {voice_id}"

            voice_jar = self.voice_jars.get(voice_id)
            assert voice_jar is not None, f"No voice jar path for id {voice_id}"

            lang_jar = self.base_dir / "lib" / f"marytts-lang-{voice.language}-5.2.jar"
            assert lang_jar.is_file(), f"Missing language jar at {lang_jar}"

            # Add jars for voice, language, and txt2wav utility
            classpath_jars = [
                voice_jar,
                lang_jar,
                self.base_dir / "lib" / "txt2wav-1.0-SNAPSHOT.jar",
            ]

            # Add MaryTTS and dependencies
            marytts_jars = (self.base_dir / "lib" / "marytts").glob("*.jar")
            classpath_jars.extend(marytts_jars)

            marytts_cmd = [
                "java",
                "-cp",
                ":".join(str(p) for p in classpath_jars),
                "de.dfki.mary.Txt2Wav",
                "-v",
                voice.id,
            ]

            _LOGGER.debug(marytts_cmd)

            self.voice_proc = await asyncio.create_subprocess_exec(
                *marytts_cmd,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
            )

            self.proc_voice_id = voice_id

        # ---------------------------------------------------------------------

        assert self.voice_proc is not None

        # Write text
        text_line = text.strip() + "\n"

        assert self.voice_proc.stdin is not None
        self.voice_proc.stdin.write(text_line.encode())
        await self.voice_proc.stdin.drain()

        # Get back size of WAV audio in bytes on first line
        assert self.voice_proc.stdout is not None
        size_line = await self.voice_proc.stdout.readline()
        num_bytes = int(size_line.decode())

        _LOGGER.debug("Reading %s byte(s) of WAV audio...", num_bytes)
        wav_bytes = await self.voice_proc.stdout.readexactly(num_bytes)

        return wav_bytes

    def maybe_load_voices(self):
        """Load MaryTTS voices by opening the jars and finding voice.config"""
        if self.voices_dict:
            # Voices already loaded
            return

        _LOGGER.debug("Loading voices from %s", self.base_dir)
        for voice_jar in self.base_dir.rglob("*.jar"):
            if (not voice_jar.name.startswith("voice-")) or (not voice_jar.is_file()):
                continue

            # Open jar as a zip file
            with ZipFile(voice_jar, "r") as jar_file:
                for jar_entry in jar_file.namelist():
                    if not jar_entry.endswith("/voice.config"):
                        continue

                    # Parse voice.config file for voice info
                    voice_name = ""
                    voice_locale = ""
                    voice_gender = ""

                    with jar_file.open(jar_entry, "r") as config_file:
                        for line_bytes in config_file:
                            try:
                                line = line_bytes.decode().strip()
                                if (not line) or (line.startswith("#")):
                                    continue

                                key, value = line.split("=", maxsplit=1)
                                key = key.strip()
                                value = value.strip()

                                if key == "name":
                                    voice_name = value
                                elif key == "locale":
                                    voice_locale = value
                                elif key.endswith(".gender"):
                                    voice_gender = value
                            except Exception:
                                # Ignore parsing errors
                                pass

                    if voice_name and voice_locale:
                        # Successful parsing
                        voice_lang = voice_locale.split("_", maxsplit=1)[0]

                        self.voice_jars[voice_name] = voice_jar
                        self.voices_dict[voice_name] = Voice(
                            id=voice_name,
                            name=voice_name,
                            locale=voice_locale.lower().replace("-", "_"),
                            language=voice_lang,
                            gender=voice_gender,
                        )

                        _LOGGER.debug(self.voices_dict[voice_name])


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


# -----------------------------------------------------------------------------


class LarynxTTS(TTSBase):
    """Wraps Larynx TTS (https://github.com/rhasspy/larynx)"""

    def __init__(self, models_dir: typing.Union[str, Path], sample_rate: int = 22050):
        import gruut
        import larynx

        self.models_dir = Path(models_dir)
        self.sample_rate = sample_rate

        # Onnx optimizations crash on armv7l for some reason
        self.no_optimizations = platform.machine() == "armv7l"

        self.gruut_langs: typing.Dict[str, gruut.Language] = {}
        self.models: typing.Dict[str, larynx.constants.TextToSpeechModel] = {}
        self.vocoders: typing.Dict[str, larynx.constants.VocoderModel] = {}
        self.audio_settings: typing.Dict[str, larynx.audio.AudioSettings] = {}

        self.larynx_voices = {
            # de-de
            "thorsten-glow_tts": Voice(
                id="thorsten-glow_tts",
                name="thorsten-glow_tts",
                locale="de-de",
                language="de",
                gender="M",
            ),
            "eva_k-glow_tts": Voice(
                id="eva_k-glow_tts",
                name="eva_k-glow_tts",
                locale="de-de",
                language="de",
                gender="F",
            ),
            "karlsson-glow_tts": Voice(
                id="karlsson-glow_tts",
                name="karlsson-glow_tts",
                locale="de-de",
                language="de",
                gender="M",
            ),
            "pavoque-glow_tts": Voice(
                id="pavoque-glow_tts",
                name="pavoque-glow_tts",
                locale="de-de",
                language="de",
                gender="M",
            ),
            "rebecca_braunert_plunkett-glow_tts": Voice(
                id="rebecca_braunert_plunkett-glow_tts",
                name="rebecca_braunert_plunkett-glow_tts",
                locale="de-de",
                language="de",
                gender="F",
            ),
            # en-us
            "blizzard_fls-glow_tts": Voice(
                id="blizzard_fls-glow_tts",
                name="blizzard_fls-glow_tts",
                locale="en-us",
                language="en",
                gender="F",
            ),
            "cmu_aew-glow_tts": Voice(
                id="cmu_aew-glow_tts",
                name="cmu_aew-glow_tts",
                locale="en-us",
                language="en",
                gender="M",
            ),
            "cmu_ahw-glow_tts": Voice(
                id="cmu_ahw-glow_tts",
                name="cmu_ahw-glow_tts",
                locale="en-us",
                language="en",
                gender="M",
            ),
            "cmu_aup-glow_tts": Voice(
                id="cmu_aup-glow_tts",
                name="cmu_aup-glow_tts",
                locale="en-us",
                language="en",
                gender="M",
            ),
            "cmu_bdl-glow_tts": Voice(
                id="cmu_bdl-glow_tts",
                name="cmu_bdl-glow_tts",
                locale="en-us",
                language="en",
                gender="M",
            ),
            "cmu_clb-glow_tts": Voice(
                id="cmu_clb-glow_tts",
                name="cmu_clb-glow_tts",
                locale="en-us",
                language="en",
                gender="F",
            ),
            "cmu_eey-glow_tts": Voice(
                id="cmu_eey-glow_tts",
                name="cmu_eey-glow_tts",
                locale="en-us",
                language="en",
                gender="F",
            ),
            "cmu_fem-glow_tts": Voice(
                id="cmu_fem-glow_tts",
                name="cmu_fem-glow_tts",
                locale="en-us",
                language="en",
                gender="M",
            ),
            "cmu_jmk-glow_tts": Voice(
                id="cmu_jmk-glow_tts",
                name="cmu_jmk-glow_tts",
                locale="en-us",
                language="en",
                gender="M",
            ),
            "cmu_ksp-glow_tts": Voice(
                id="cmu_ksp-glow_tts",
                name="cmu_ksp-glow_tts",
                locale="en-us",
                language="en",
                gender="F",
            ),
            "cmu_ljm-glow_tts": Voice(
                id="cmu_ljm-glow_tts",
                name="cmu_ljm-glow_tts",
                locale="en-us",
                language="en",
                gender="F",
            ),
            "cmu_lnh-glow_tts": Voice(
                id="cmu_lnh-glow_tts",
                name="cmu_lnh-glow_tts",
                locale="en-us",
                language="en",
                gender="F",
            ),
            "cmu_rms-glow_tts": Voice(
                id="cmu_rms-glow_tts",
                name="cmu_rms-glow_tts",
                locale="en-us",
                language="en",
                gender="M",
            ),
            "cmu_rxr-glow_tts": Voice(
                id="cmu_rxr-glow_tts",
                name="cmu_rxr-glow_tts",
                locale="en-us",
                language="en",
                gender="M",
            ),
            "cmu_slp-glow_tts": Voice(
                id="cmu_slp-glow_tts",
                name="cmu_slp-glow_tts",
                locale="en-us",
                language="en",
                gender="F",
            ),
            "cmu_slt-glow_tts": Voice(
                id="cmu_slt-glow_tts",
                name="cmu_slt-glow_tts",
                locale="en-us",
                language="en",
                gender="F",
            ),
            "ek-glow_tts": Voice(
                id="ek-glow_tts",
                name="ek-glow_tts",
                locale="en-us",
                language="en",
                gender="F",
            ),
            "harvard-glow_tts": Voice(
                id="harvard-glow_tts",
                name="harvard-glow_tts",
                locale="en-us",
                language="en",
                gender="F",
            ),
            "kathleen-glow_tts": Voice(
                id="kathleen-glow_tts",
                name="kathleen-glow_tts",
                locale="en-us",
                language="en",
                gender="F",
                tag={"tts": {"noise_scale": 0.2, "length_scale": 0.8}},
            ),
            "ljspeech-glow_tts": Voice(
                id="ljspeech-glow_tts",
                name="ljspeech-glow_tts",
                locale="en-us",
                language="en",
                gender="F",
                tag={"tts": {"noise_scale": 0.2, "length_scale": 0.8}},
            ),
            "mary_ann-glow_tts": Voice(
                id="mary_ann-glow_tts",
                name="mary_ann-glow_tts",
                locale="en-us",
                language="en",
                gender="F",
            ),
            # es-es
            "carlfm-glow_tts": Voice(
                id="carlfm-glow_tts",
                name="carlfm-glow_tts",
                locale="es-es",
                language="es",
                gender="M",
            ),
            "karen_savage-glow_tts": Voice(
                id="karen_savage-glow_tts",
                name="karen_savage-glow_tts",
                locale="es-es",
                language="es",
                gender="F",
            ),
            # fr-fr
            "siwis-glow_tts": Voice(
                id="siwis-glow_tts",
                name="siwis-glow_tts",
                locale="fr-fr",
                language="fr",
                gender="F",
            ),
            "gilles_le_blanc-glow_tts": Voice(
                id="gilles_le_blanc-glow_tts",
                name="gilles_le_blanc-glow_tts",
                locale="fr-fr",
                language="fr",
                gender="M",
            ),
            "tom-glow_tts": Voice(
                id="tom-glow_tts",
                name="tom-glow_tts",
                locale="fr-fr",
                language="fr",
                gender="M",
            ),
            # it-it
            "lisa-glow_tts": Voice(
                id="lisa-glow_tts",
                name="lisa-glow_tts",
                locale="it-it",
                language="it",
                gender="M",
            ),
            "riccardo_fasol-glow_tts": Voice(
                id="riccardo_fasol-glow_tts",
                name="riccardo_fasol-glow_tts",
                locale="it-it",
                language="it",
                gender="M",
            ),
            # nl
            "rdh-glow_tts": Voice(
                id="rdh-glow_tts",
                name="rdh-glow_tts",
                locale="nl",
                language="nl",
                gender="M",
                tag={"tts": {"noise_scale": 0.2}},
            ),
            "flemishguy-glow_tts": Voice(
                id="flemishguy-glow_tts",
                name="flemishguy-glow_tts",
                locale="nl",
                language="nl",
                gender="M",
                tag={"tts": {"length_scale": 0.8}},
            ),
            "bart_de_leeuw-glow_tts": Voice(
                id="bart_de_leeuw-glow_tts",
                name="bart_de_leeuw-glow_tts",
                locale="nl",
                language="nl",
                gender="M",
            ),
            # ru-ru
            "nikolaev-glow_tts": Voice(
                id="nikolaev-glow_tts",
                name="nikolaev-glow_tts",
                locale="ru-ru",
                language="ru",
                gender="M",
                tag={"tts": {"noise_scale": 0.2}},
            ),
            "hajdurova-glow_tts": Voice(
                id="hajdurova-glow_tts",
                name="hajdurova-glow_tts",
                locale="ru-ru",
                language="ru",
                gender="F",
            ),
            "minaev-glow_tts": Voice(
                id="minaev-glow_tts",
                name="minaev-glow_tts",
                locale="ru-ru",
                language="ru",
                gender="F",
            ),
            # sv-se
            "talesyntese-glow_tts": Voice(
                id="talesyntese-glow_tts",
                name="talesyntese-glow_tts",
                locale="sv-se",
                language="sv",
                gender="M",
                tag={"tts": {"noise_scale": 0.2, "length_scale": 0.8}},
            ),
        }

    async def voices(self) -> VoicesIterable:
        """Get list of available voices."""
        for voice in self.larynx_voices.values():
            model_path = self.models_dir / voice.locale / voice.id
            if model_path.exists():
                yield voice

    async def say(self, text: str, voice_id: str, **kwargs) -> bytes:
        """Speak text as WAV."""
        vocoder: typing.Optional[str] = kwargs.get("vocoder")
        denoiser_strength: typing.Optional[float] = kwargs.get("denoiser_strength")

        voice = self.larynx_voices[voice_id]

        # Load lexicon, etc. for voice language (cache)
        import gruut

        gruut_lang = self.gruut_langs.get(voice.locale)
        if not gruut_lang:
            data_dirs = gruut.Language.get_data_dirs() + [self.models_dir / "gruut"]
            gruut_lang = gruut.Language.load(language=voice.locale, data_dirs=data_dirs)

            assert gruut_lang, f"No support for language {voice.locale} in gruut"
            self.gruut_langs[voice.locale] = gruut_lang

        # ---------------------------------------------------------------------

        from larynx import (
            AudioSettings,
            load_tts_model,
            load_vocoder_model,
            text_to_speech,
        )

        # Load TTS model
        tts_model = self.models.get(voice_id)
        audio_settings: typing.Optional[AudioSettings] = None
        if not tts_model:
            model_path = self.models_dir / voice.locale / voice_id
            model_type = voice_id.split("-")[-1]  # <name>-<model_type>""
            tts_model = load_tts_model(
                model_type,
                model_path=model_path,
                no_optimizations=self.no_optimizations,
            )
            self.models[voice_id] = tts_model

            # Load audio settings
            config_path = self.models_dir / voice.locale / voice_id / "config.json"
            if config_path.is_file():
                with open(config_path, "r") as config_file:
                    tts_config = json.load(config_file)
                    audio_settings = AudioSettings(**tts_config["audio"])
                    self.audio_settings[voice_id] = audio_settings

        audio_settings = self.audio_settings.get(voice_id)
        if audio_settings is None:
            # Use default settings
            audio_settings = AudioSettings()
            self.audio_settings[voice_id] = audio_settings

        assert audio_settings is not None

        # Load vocoder model
        vocoder = vocoder or "hifi_gan:universal_large"
        vocoder_model = self.vocoders.get(vocoder)
        if not vocoder_model:
            vocoder_type, vocoder_name = vocoder.split(":")
            vocoder_path = self.models_dir / vocoder_type / vocoder_name
            vocoder_model = load_vocoder_model(
                vocoder_type,
                model_path=vocoder_path,
                no_optimizations=self.no_optimizations,
            )
            self.vocoders[vocoder] = vocoder_model

        # ---------------------------------------------------------------------

        # Run text to speech
        from larynx.wavfile import write as wav_write

        tts_settings = voice.tag.get("tts") if voice.tag else None
        vocoder_settings = voice.tag.get("vocoder") if voice.tag else None

        if denoiser_strength is not None:
            # Override denoiser strength
            vocoder_settings = vocoder_settings or {}
            vocoder_settings["denoiser_strength"] = denoiser_strength

        # Run asynchronously in executor
        loop = asyncio.get_running_loop()
        text_and_audios = await loop.run_in_executor(
            None,
            functools.partial(
                text_to_speech,
                text=text,
                gruut_lang=gruut_lang,
                tts_model=tts_model,
                vocoder_model=vocoder_model,
                tts_settings=tts_settings,
                vocoder_settings=vocoder_settings,
                audio_settings=audio_settings,
            ),
        )

        for _, audio in text_and_audios:
            with io.BytesIO() as wav_io:
                wav_write(wav_io, self.sample_rate, audio)
                wav_data = wav_io.getvalue()

            # Should be single output since we're not splitting sentences
            break

        return wav_data
