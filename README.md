# Open Text to Speech Server

Unifies access to multiple open source text to speech systems and voices for many languages.

[Listen to voice samples](https://synesthesiam.github.io/opentts/)

![Web interface screenshot](img/screenshot.png "Screenshot")

## Voices

* [Larynx](https://github.com/rhasspy/larynx-runtime)
    * English (27), German (7), French (3), Spanish (2), Dutch (4), Russian (3), Swedish (1), Italian (2), Swahili (1)
    * Model types available: [GlowTTS](https://github.com/rhasspy/glow-tts-train)
    * Vocoders available: [HiFi-Gan](https://github.com/rhasspy/hifi-gan-train) (3 levels of quality)
* [Glow-Speak](https://github.com/rhasspy/glow-speak)
    * English (2), German (1), French (1), Spanish (1), Dutch (1), Russian (1), Swedish (1), Italian (1), Swahili (1), Greek (1), Finnish (1), Hungarian (1), Korean (1)
    * Model types available: [GlowTTS](https://github.com/rhasspy/glow-tts-train)
    * Vocoders available: [HiFi-Gan](https://github.com/rhasspy/hifi-gan-train) (3 levels of quality)
* [Coqui-TTS](https://github.com/coqui-ai/TTS)
    * English (110), Japanese (1), Chinese (1)
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
    
## Running

Basic OpenTTS server:

```bash
$ docker run -it -p 5500:5500 synesthesiam/opentts:<LANGUAGE>
```

where `<LANGUAGE>` is one of:

* ar (Arabic)
* bn (Bengali)
* ca (Catalan)
* cs (Czech)
* de (German)
* el (Greek)
* en (English)
* es (Spanish)
* fi (Finnish)
* fr (French)
* gu (Gujarati)
* hi (Hindi)
* hu (Hungarian)
* it (Italian)
* ja (Japanese)
* kn (Kannada)
* ko (Korean)
* mr (Marathi)
* nl (Dutch)
* pa (Punjabi)
* ru (Russian)
* sv (Swedish)
* sw (Swahili)
* ta (Tamil)
* te (Telugu)
* tr (Turkish)
* zh (Chinese)

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

## HTTP API Endpoints

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

## MaryTTS Compatible Endpoint

Use OpenTTS as a drop-in replacement for [MaryTTS](http://mary.dfki.de/).

The voice format is `<TTS_SYSTEM>:<VOICE_NAME>`. Visit the OpenTTS web UI and copy/paste the "voice id" of your favorite voice here.

You may need to change the port in your `docker run` command to `-p 59125:5500` for compatibility with existing software.

### Larynx Voice Quality

On the Raspberry Pi, you may need to lower the quality of [Larynx](https://github.com/rhasspy/larynx) voices to get reasonable response times.

This is done by appending the quality level to the end of your voice:

```yaml
tts:
  - platform: marytts
    voice:larynx:harvard-glow_tts;low
```

Available quality levels are `high` (the default), `medium`, and `low`.

Note that this only applies to Larynx and Glow-Speak voices.

### Speaker ID

For multi-speaker models (currently just `coqui-tts:en_vctk`), you can append a speaker name or id to your voice:

```yaml
tts:
  - platform: marytts
    voice:coqui-tts:en_vctk#p228
```

You can get the available speaker names from `/api/voices` or provide a 0-based index instead:

```yaml
tts:
  - platform: marytts
    voice:coqui-tts:en_vctk#42
```

## Default Larynx Settings

Default settings for [Larynx](https://github.com/rhasspy/larynx) can be provided on the command-line:

* `--larynx-quality` - vocoder quality ("high", "medium", or "low", default: "high")
* `--larynx-noise-scale` - voice volatility (0-1, default: 0.333)
* `--larynx-length-scale` - voice speed (< 1 is faster, default: 1.0)
