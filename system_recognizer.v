module vspeech_input

#flag windows -lole32
#flag windows -lsapi
#flag windows @VMODROOT/system_recognizer_windows.c

$if windows {
	fn C.vspeech_input_system_open() voidptr
	fn C.vspeech_input_system_poll(handle voidptr, text &u8, capacity int, final &int) int
	fn C.vspeech_input_system_close(handle voidptr)
}

pub struct SystemRecognizer {
pub mut:
	handle   voidptr
	sequence u64
}

pub fn open_system_recognizer() !SystemRecognizer {
	$if windows {
		handle := C.vspeech_input_system_open()
		if isnil(handle) {
			return error('Windows system speech recognizer is unavailable')
		}
		return SystemRecognizer{
			handle: handle
		}
	} $else {
		return error('system speech recognizer is currently available on Windows only')
	}
}

pub fn (recognizer SystemRecognizer) active() bool {
	$if windows {
		return !isnil(recognizer.handle)
	} $else {
		return false
	}
}

pub fn (mut recognizer SystemRecognizer) poll(max_events int) []TranscriptEvent {
	mut out := []TranscriptEvent{}
	$if windows {
		if isnil(recognizer.handle) {
			return out
		}
		limit := if max_events > 0 { max_events } else { 4 }
		for _ in 0 .. limit {
			mut buffer := []u8{len: 4096}
			mut final := 0
			if C.vspeech_input_system_poll(recognizer.handle, unsafe { &buffer[0] }, buffer.len, &final) == 0 {
				break
			}
			text := nul_text(buffer).trim_space()
			if text == '' {
				continue
			}
			recognizer.sequence++
			out << transcript_event(text, final != 0, 'system-${recognizer.sequence}')
		}
	}
	return out
}

pub fn (mut recognizer SystemRecognizer) close() {
	$if windows {
		if !isnil(recognizer.handle) {
			C.vspeech_input_system_close(recognizer.handle)
			recognizer.handle = voidptr(0)
		}
	}
}

fn nul_text(buffer []u8) string {
	mut end := 0
	for end < buffer.len && buffer[end] != 0 {
		end++
	}
	if end == 0 {
		return ''
	}
	return buffer[..end].bytestr()
}
