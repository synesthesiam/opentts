# Open Text to Speech Server

Unifies access to multiple open source text to speech systems, including:

* [eSpeak](http://espeak.sourceforge.net)
* [flite](http://www.festvox.org/flite)
* [Festival](http://www.cstr.ed.ac.uk/projects/festival/)
* [nanoTTS](https://github.com/gmn/nanotts)
* [MaryTTS](http://mary.dfki.de)
    * External server required ([like this](https://github.com/synesthesiam/docker-marytts))
    
![Web interface screenshot](img/screenshot.png "Screenshot")
    
## API Endpoints

Server defaults to `http://localhost:5500`

* `GET /api/tts`
    * `?voice` - voice in the form `tts:voice` (e.g., `espeak:en`)
    * `?text` - text to speak
    * Returns `audio/wav`
* `GET /api/voices`
    * Returns JSON

## Voice Samples

See [samples directory](samples/). eSpeak samples are not included since there are a lot of languages (and they all sound robotic).
