# Open Text to Speech Server

Unifies access to multiple open source text to speech systems and voices for many languages, including:

* [eSpeak](http://espeak.sourceforge.net)
    * Supports huge number of languages/locales, but sounds robotic
* [flite](http://www.festvox.org/flite)
    * English (19)
    * Hindi (1)
    * Bengali (1)
    * Gujarati (3)
    * Kannada (1)
    * Marathi (2)
    * Punjabi (1)
    * Tamil (1)
    * Telugu (3)
* [Festival](http://www.cstr.ed.ac.uk/projects/festival/)
    * English (9), Spanish (1), Catalan (1), Czech (4), Russian (1)
    * Spanish/Catalan use [ISO-8859-15 encoding](https://en.wikipedia.org/wiki/ISO/IEC_8859-15)
    * Czech uses [ISO-8859-2 encoding](https://en.wikipedia.org/wiki/ISO/IEC_8859-2)
    * Russian is [transliterated](https://pypi.org/project/transliterate/) from Cyrillic to Latin script automatically
* [nanoTTS](https://github.com/gmn/nanotts)
    * English (2), German (1), French (1), Italian (1), Spanish (1)
* [MaryTTS](http://mary.dfki.de)
    * English (7), German (3), French (4), Italian (1), Russian (1), Swedish (1), Telugu (1), Turkish (1)
    * External server required ([Docker image](https://hub.docker.com/r/synesthesiam/marytts))
    * Add `--marytts-url` command-line argument
* [Mozilla TTS](https://github.com/mozilla/TTS)
    * English (1)
    * External server required ([Docker image](https://hub.docker.com/r/synesthesiam/mozilla-tts), `amd64` only)
    * Add `--mozillatts-url` command-line argument
    
![Web interface screenshot](img/screenshot.png "Screenshot")

## Running

Basic OpenTTS server:

```bash
$ docker run -it -p 5500:5500 synesthesiam/opentts
```

Visit http://localhost:5500

For HTTP API test page, visit http://localhost:5500/api/

Exclude eSpeak (robotic voices):

```bash
$ docker run -it -p 5500:5500 synesthesiam/opentts --no-espeak
```

### Adding MaryTTS and Mozilla TTS

Run using docker compose with [MaryTTS](https://hub.docker.com/r/synesthesiam/marytts) and [Mozilla TTS](https://hub.docker.com/r/synesthesiam/mozilla-tts):

```yaml
version: '2'
services:
  opentts:
    image: synesthesiam/opentts
    ports:
      - 5500:5500
    command: --marytts-url http://marytts:59125 --mozillatts-url http://mozillatts:5002
    tty: true
  marytts:
    image: synesthesiam/marytts:5.2
    tty: true
  mozillatts:
    image: synesthesiam/mozilla-tts
    tty: true
```

Visit http://localhost:5500 and choose language `en` then voices starting with `marytts:` or `mozillatts:

**NOTE**: Mozilla TTS docker image only runs on `amd64` platforms (no Raspberry Pi).
    
## HTTP Endpoints

See [swagger.yaml](swagger.yaml)

* `GET /api/tts`
    * `?voice` - voice in the form `tts:voice` (e.g., `espeak:en`)
    * `?text` - text to speak
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
    
## Voice Samples

See [samples directory](samples/). eSpeak samples are not included since there are a lot of languages (and they all sound robotic).
