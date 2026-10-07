module vspeech_input

import math
import time

pub struct TranscriptEvent {
pub:
	text         string
	final        bool
	utterance_id string
	at_unix_ms   i64
}

pub struct EndpointConfig {
pub:
	sample_rate      int = 16000
	energy_threshold f64 = 400.0
	silence_ms       int = 750
	min_speech_ms    int = 120
}

pub struct EndpointEvent {
pub:
	speaking   bool
	ended      bool
	level      f64
	speech_ms  int
	silence_ms int
}

pub struct Endpointer {
pub:
	config EndpointConfig
pub mut:
	speaking   bool
	speech_ms  int
	silence_ms int
}

pub fn new_endpointer(config EndpointConfig) Endpointer {
	return Endpointer{config: config}
}

pub fn (mut endpoint Endpointer) ingest_pcm16(samples []i16) EndpointEvent {
	if samples.len == 0 {
		return EndpointEvent{
			speaking: endpoint.speaking
			speech_ms: endpoint.speech_ms
			silence_ms: endpoint.silence_ms
		}
	}
	mut energy := f64(0)
	for sample in samples {
		value := f64(sample)
		energy += value * value
	}
	rms := math.sqrt(energy / f64(samples.len))
	level := clamp_f64(rms / 32768.0, 0.0, 1.0)
	frame_ms := max_int(1, int(f64(samples.len) * 1000.0 / f64(endpoint.config.sample_rate)))
	mut ended := false
	if rms >= endpoint.config.energy_threshold {
		endpoint.speaking = true
		endpoint.speech_ms += frame_ms
		endpoint.silence_ms = 0
	} else if endpoint.speaking {
		endpoint.silence_ms += frame_ms
		if endpoint.speech_ms >= endpoint.config.min_speech_ms
			&& endpoint.silence_ms >= endpoint.config.silence_ms {
			ended = true
			endpoint.speaking = false
			endpoint.speech_ms = 0
			endpoint.silence_ms = 0
		}
	}
	return EndpointEvent{
		speaking: endpoint.speaking
		ended: ended
		level: level
		speech_ms: endpoint.speech_ms
		silence_ms: endpoint.silence_ms
	}
}

pub fn transcript_event(text string, final bool, utterance_id string) TranscriptEvent {
	return TranscriptEvent{
		text: text.trim_space()
		final: final
		utterance_id: utterance_id
		at_unix_ms: time.now().unix_milli()
	}
}

fn clamp_f64(value f64, low f64, high f64) f64 {
	if value < low {
		return low
	}
	if value > high {
		return high
	}
	return value
}

fn max_int(a int, b int) int {
	return if a > b { a } else { b }
}
