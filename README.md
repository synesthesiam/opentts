# Open Text to Speech Server

Unifies access to multiple open source text to speech systems and voices for many languages, including:

[Listen to voice samples](https://synesthesiam.github.io/opentts/)

* [Larynx](https://github.com/rhasspy/larynx-runtime)
    * English (20), German (1), French (3), Spanish (2), Dutch (3), Russian (3), Swedish (1), Italian (2)
    * Model types available: [GlowTTS](https://github.com/rhasspy/glow-tts-train)
    * Vocoders available: [HiFi-Gan](https://github.com/rhasspy/hifi-gan-train) (3 levels of quality), [WaveGlow](https://github.com/rhasspy/waveglow)
* [nanoTTS](https://github.com/gmn/nanotts)
    * English (2), German (1), French (1), Italian (1), Spanish (1)
* [MaryTTS](http://mary.dfki.de)
    * English (7), German (3), French (4), Italian (1), Russian (1), Swedish (1), Telugu (1), Turkish (1)
    * Includes [embedded MaryTTS](https://github.com/synesthesiam/marytts-txt2wav)
* [flite](http://www.festvox.org/flite)
    * English (19), Hindi (1), Bengali (1), Gujarati (3), Kannada (1), Marathi (2), Punjabi (1), Tamil (1), Telugu (3)
* [Festival](http://www.cstr.ed.ac.uk/projects/festival/)
    * English (9), Spanish (1), Catalan (1), Czech (4), Russian (1), Finnish (2), Marathi (1), Telugu (1), Hindi (1), Italian (2), Arabic (2)
    * Spanish/Catalan/Finnish use [ISO-8859-15 encoding](https://en.wikipedia.org/wiki/ISO/IEC_8859-15)
    * Czech uses [ISO-8859-2 encoding](https://en.wikipedia.org/wiki/ISO/IEC_8859-2)
    * Russian is [transliterated](https://pypi.org/project/transliterate/) from Cyrillic to Latin script automatically
    * Arabic uses UTF-8 and is diacritized with [mishkal](https://github.com/linuxscout/mishkal)
* [eSpeak](http://espeak.sourceforge.net)
    * Supports huge number of languages/locales, but sounds robotic
    
![Web interface screenshot](img/screenshot.png "Screenshot")

## Running

Basic OpenTTS server:

```bash
$ docker run -it -p 5500:5500 synesthesiam/opentts:<LANGUAGE>
```

where `<LANGUAGE>` is one of:

* `ar` (Arabic)
* `bn` (Bengali)
* `ca` (Catalan)
* `cs` (Czech)
* `de` (German)
* `en` (English)
* `es` (Spanish)
* `fi` (Finnish)
* `fr` (French)
* `gu` (Gujarati)
* `hi` (Hindi)
* `it` (Italian)
* `kn` (Kannada)
* `mr` (Marathi)
* `nl` (Dutch)
* `pa` (Punjabi)
* `ru` (Russian)
* `sv` (Swedish)
* `ta` (Tamil)
* `te` (Telugu)
* `tr` (Turkish)

Visit http://localhost:5500

For HTTP API test page, visit http://localhost:5500/openapi/

Exclude eSpeak (robotic voices):

```bash
$ docker run -it -p 5500:5500 synesthesiam/opentts:<LANGUAGE> --no-espeak
```

### WAV Cache

You can have the OpenTTS server cache WAV files with `--cache`:

```bash
$ docker run -it -p 5500:5500 synesthesiam/opentts:<LANGUAGE> --cache
```

This will store WAV files in a temporary directory (inside the Docker container). A specific directory can also be used:

```bash
$ docker run -it -v /path/to/cache:/cache -p 5500:5500 synesthesiam/opentts:<LANGUAGE> --cache /cache
```

## HTTP Endpoints

See [swagger.yaml](swagger.yaml)

* `GET /api/tts`
    * `?voice` - voice in the form `tts:voice` (e.g., `espeak:en`)
    * `?text` - text to speak
    * `?cache` - disable WAV cache with `false`
    * Returns `audio/wav` bytes
* `GET /api/voices`
    * Returns JSON object
    * Keys are voice ids in the form `tts:voice`
    * Values are objects with:
        * `id` - voice identifier for TTS system (string)
        * `name` - friendly name of voice (string)
        * `gender` - M or F (string)
        * `language` - 2-character language code (e.g., "en")
        * `locale` - lower-case locale code (e.g., "en-gb")
        * `tts_name` - name of text to speech system
    * Filter voices using query parameters:
        * `?tts_name` - only text to speech system(s)
        * `?language` - only language(s)
        * `?locale` - only locale(s)
        * `?gender` - only gender(s)
* `GET /api/languages`
    * Returns JSON list of supported languages
    * Filter languages using query parameters:
        * `?tts_name` - only text to speech system(s)
