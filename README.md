# vspeech_input

Reusable, product-neutral speech input for V.

The module provides two layers:

- portable PCM16 level/VAD endpointing, transcript events, speech repair, bilingual deterministic intent parsing, command chains, payload extraction, and spoken-number parsing;
- an **optional Windows system STT backend** implemented directly with SAPI/COM. It listens to the default microphone and emits the same `TranscriptEvent` contract used by every other backend.

No Python, Node.js, Whisper runtime, cloud provider, or product-specific browser dependency is required. Consumers may ignore `SystemRecognizer` entirely and feed transcripts from another STT engine.

## Windows system recognizer

```v
mut recognizer := vspeech_input.open_system_recognizer()!
defer {
    recognizer.close()
}

for event in recognizer.poll(4) {
    if event.final {
        println(event.text)
    }
}
```

Opening the system recognizer is fallible by design: machines without a usable Windows speech recognizer or language configuration can continue with another backend. A zero-value `SystemRecognizer{}` is inert and safe to poll or close.
