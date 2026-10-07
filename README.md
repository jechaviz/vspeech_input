# vspeech_input

Reusable V-native speech-input primitives.

The package intentionally stops before model/backend choice. It provides:

- PCM16 audio level and silence endpointing;
- transcript events;
- conservative speech-recognition repair;
- bilingual deterministic browser-style intent parsing;
- command-chain splitting;
- explicit payload extraction and spoken-number parsing.

STT engines can feed transcript events into this package without forcing Whisper, Python, a cloud provider, or a specific product runtime.
