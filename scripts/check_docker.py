#!/usr/bin/env python3
"""
Runs docker image for each language and checks each available voice once.

Assumes curl is installed.
"""
import argparse
import json
import logging
import subprocess
import time
from urllib.parse import urlencode

# -----------------------------------------------------------------------------

_TEST_SENTENCES = {
    "ar": "بالهناء والشفاء / بالهنا والشفا",
    "bn": "অনেক দিন দেখা হয়না।",
    "ca": "Parli més a poc a poc, si us plau",
    "cs": "Těší mě, že Tě poznávám",
    "de": "Können Sie bitte langsamer sprechen?",
    "en": "It took me quite a long time to develop a voice, and now that I have it I'm not going to be silent.",
    "el": "Καιρό έχουμε να τα πούμε!",
    "es": "Una cerveza, por favor.",
    "fi": "Mikä sinun nimesi on?",
    "fr": "Pourriez-vous parler un peu moins vite?",
    "gu": "ઘણા વખતે દેખના",
    "hi": "मैं ठीक हूँ, धन्यवाद। और तुम?",
    "hu": "Hyvää kiitos, entä sinulle?",
    "it": "Da dove vieni?",
    "ja": "はい、元気です。あなたは？",
    "kn": "ನಾ ಚಲೋ ಅದೀನಿ, ನೀವು ಹ್ಯಾಂಗದೀರ್’ರಿ?",
    "ko": "제 호버크래프트가 장어로 가득해요",
    "mr": "तुम्हाला भेटून आनंद झाला",
    "nl": "Hoe laat is het?",
    "pa": "ਬੜੀ ਦੇਰ ਤੋਂ ਤੁਸੀਂ ਨਜ਼ਰ ਨਹੀਂ ਆਏ !",
    "ru": "Вы не могли бы говорить помедленнее?",
    "sv": "Det var länge sedan vi sågs sist!",
    "sw": "Nakutakia siku njema!",
    "ta": "உங்கள் பெயர் என்ன?",
    "te": "నేను బాగున్నాను. మీరు ఏలా ఉన్నారు ?",
    "tr": "İyiyim sağol, sen nasılsın",
    "vi": "Một thứ tiếng thì không bao giờ đủ",
    "zh": "一種語言永遠不夠",
}

_LOGGER = logging.getLogger("check_docker")

# -----------------------------------------------------------------------------


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(prog="check_docker.py")
    parser.add_argument("languages", nargs="+", help="Languages to check")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)

    container_id = ""
    for language in args.languages:
        try:
            container_id = subprocess.check_output(
                [
                    "docker",
                    "run",
                    "--rm",
                    "-d",
                    "-p",
                    "5500:5500",
                    f"synesthesiam/opentts:{language}",
                ],
                universal_newlines=True,
            ).strip()
            _LOGGER.info("%s: started container (%s)", language, container_id)
            time.sleep(2)

            voices = json.loads(
                subprocess.check_output(
                    [
                        "curl",
                        "--silent",
                        "-o",
                        "-",
                        "localhost:5500/api/voices?"
                        + urlencode({"language": language}),
                    ],
                    universal_newlines=True,
                )
            )

            # -------------------------------------------------------------------------
            # Generate keywords
            # -------------------------------------------------------------------------

            espeak = False
            for voice_id, voice_info in voices.items():
                language = voice_info["language"]
                text = _TEST_SENTENCES.get(language)
                if not text:
                    _LOGGER.warning("No sentence for %s", language)
                    continue

                tts_system, _voice_name = voice_id.split(":", maxsplit=1)
                if tts_system == "espeak":
                    if espeak:
                        # Only do one espeak voice
                        continue

                    espeak = True

                _LOGGER.info("%s: %s", language, voice_id)
                subprocess.check_call(
                    [
                        "curl",
                        "--silent",
                        "-o",
                        "/dev/null",
                        "localhost:5500/api/tts?"
                        + urlencode(
                            {
                                "voice": voice_id,
                                "denoiserStrength": "0.01",
                                "text": text,
                            }
                        ),
                    ]
                )
        finally:
            if container_id:
                subprocess.check_call(["docker", "stop", "--time", "1", container_id])
                _LOGGER.info("%s: stopped container", language)


# -----------------------------------------------------------------------------

if __name__ == "__main__":
    main()
