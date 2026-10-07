module vspeech_input

fn test_command_chain_keeps_query_and_splits_strong_followup() {
	assert command_chain('search for guitar tabs and backing tracks').len == 1
	chain := command_chain('open github and then open issues')
	assert chain.len == 2
	assert chain[0] == 'open github'
	assert chain[1] == 'open issues'
}

fn test_voice_intent_and_repair() {
	assert repair_speech('open git hub') == 'open github'
	intent := classify('abre github')
	assert intent.kind == .navigate
	assert intent.payload == 'github'
	search := classify('busca V language memory model')
	assert search.kind == .search
	assert search.payload == 'V language memory model'
}

fn test_endpointer_detects_silence_after_speech() {
	mut endpoint := new_endpointer(EndpointConfig{
		sample_rate: 16000
		energy_threshold: 100.0
		silence_ms: 20
		min_speech_ms: 10
	})
	voice := []i16{len: 160, init: i16(1000)}
	silence := []i16{len: 160, init: i16(0)}
	assert endpoint.ingest_pcm16(voice).speaking
	assert !endpoint.ingest_pcm16(silence).ended
	assert endpoint.ingest_pcm16(silence).ended
}


fn test_zero_system_recognizer_is_safe_without_backend() {
	mut recognizer := SystemRecognizer{}
	assert !recognizer.active()
	assert recognizer.poll(4).len == 0
	recognizer.close()
	assert !recognizer.active()
}

fn test_system_recognizer_poll_default_limit_is_safe() {
	mut recognizer := SystemRecognizer{}
	assert recognizer.poll(0).len == 0
}
