#!/usr/bin/env python3
import sys
from collections import defaultdict
from pathlib import Path


def main():
    if len(sys.argv) < 2:
        print("Usage: make_sample_html.py <SAMPLES_DIR>", file=sys.stderr)
        sys.exit(1)

    print('<html lang="en">')
    print('<head><meta charset="utf-8"><title>OpenTTS Voice Samples</title></head>')
    print("<body>")
    print("<h1>OpenTTS Voice Samples</h1>")
    print(
        '<p>Voices samples for <a href="https://github.com/synesthesiam/opentts">OpenTTS.</a></p>'
    )

    samples_dir = Path(sys.argv[1])

    # tts -> language -> voice name -> samples dir
    voices = defaultdict(lambda: defaultdict(dict))

    # samples/<TTS_SYSTEM>/<LANGUAGE>/<VOICE>
    for tts_dir in sorted(Path(samples_dir).iterdir()):
        if not tts_dir.is_dir():
            continue

        tts = tts_dir.name

        for lang_dir in sorted(tts_dir.iterdir()):
            if not lang_dir.is_dir():
                continue

            language = lang_dir.name

            for voice_dir in sorted(lang_dir.iterdir()):
                if not voice_dir.is_dir():
                    continue

                voice = voice_dir.name

                key_path = voice_dir / "samples.txt"
                if not key_path.is_file():
                    print("Missing", key_path, file=sys.stderr)
                    continue

                voices[tts][language][voice] = voice_dir

    # Print table of contents
    print("<ul>")
    for tts, languages in voices.items():
        print("<li>", f'<a href="#{tts}">', tts, "</a>")

        print("<ul>")
        for language, lang_voices in languages.items():
            print("<li>", f'<a href="#{tts}_{language}">', language, "</a>")

            print("<ul>")
            for voice_name in lang_voices:
                print(
                    "<li>",
                    f'<a href="#{tts}_{language}_{voice_name}">',
                    voice_name,
                    "</a>",
                    "</li>",
                )

            # /language
            print("</ul>")
            print("</li>")

        # /tts
        print("</ul>")
        print("</li>")

    # /toc
    print("</ul>")
    print("<hr>")

    # -------------------------------------------------------------------------

    # Print samples
    for tts, languages in voices.items():
        print(f'<h2 id="{tts}">', tts, "</h2>")

        for language, lang_voices in languages.items():
            print(f'<h3 id="{tts}_{language}">', f"{tts} &gt; {language}", "</h3>")

            for voice_name, samples_dir in lang_voices.items():
                key_path = samples_dir / "samples.txt"
                print(
                    f'<h4 id="{tts}_{language}_{voice_name}">',
                    f"{tts} &gt; {language} &gt; {voice_name}",
                    "</h4>",
                )

                with open(key_path, "r") as key_file:
                    for line in sorted(key_file):
                        line = line.strip()
                        if not line:
                            continue

                        if "|" in line:
                            utt_id, text = line.split("|", maxsplit=1)
                        else:
                            utt_id, text = line, line

                        wav_path = samples_dir / f"{utt_id}.wav"

                        if not wav_path.is_file():
                            print("Missing", wav_path, file=sys.stderr)
                            continue

                        print("<p>", text, "</p>")
                        print(
                            f'<audio controls preload="none" src="{wav_path}"></audio>'
                        )

                        # /sample
                        print("<br>")

                # /voice
                print("<br>")

            # ---------------------------------------------------------------------

            # /language
            print("<br>")

        # /tts
        print("<br>")
        print("<hr>")

    # /page
    print("</body>")
    print("</html>")


if __name__ == "__main__":
    main()
