module vspeech_input

pub enum IntentKind {
	unknown
	navigate
	search
	command
	goal
}

pub struct Intent {
pub:
	kind    IntentKind
	command string
	raw     string
	payload string
}

pub fn (intent Intent) complete() bool {
	if intent.kind == .unknown {
		return false
	}
	if intent.kind in [.navigate, .search] {
		return intent.payload.trim_space() != ''
	}
	if intent.command in ['click', 'type'] {
		return intent.payload.trim_space() != ''
	}
	return true
}

pub fn repair_speech(input string) string {
	mut text := collapse_spaces(input)
	for pair in [
		['get hub', 'github'],
		['git hub', 'github'],
		['get up dot com', 'github.com'],
		['you tube', 'youtube'],
		['duck duck go', 'duckduckgo'],
	] {
		text = replace_ci(text, pair[0], pair[1])
	}
	return text
}

pub fn command_text(input string) string {
	return strip_openers(repair_speech(input))
}

pub fn normalize_spoken_url(input string) string {
	mut value := repair_speech(input)
	for pair in [
		[' dot ', '.'],
		[' punto ', '.'],
		[' slash ', '/'],
		[' diagonal ', '/'],
	] {
		value = replace_ci(value, pair[0], pair[1])
	}
	return value.trim_space()
}

pub fn command_chain(input string) []string {
	text := strip_openers(repair_speech(input))
	if text == '' {
		return []string{}
	}
	mut result := []string{}
	mut current := []string{}
	words := text.split(' ')
	for i, word in words {
		low := word.to_lower().trim(' ,.;:')
		if low in ['then', 'luego', 'despues', 'después'] {
			if current.len > 0 {
				result << current.join(' ').trim(' ,.;:')
				current = []string{}
			}
			continue
		}
		if low == 'and' || low == 'y' {
			rest := if i + 1 < words.len { words[i + 1..].join(' ') } else { '' }
			if strong_command_prefix(rest) {
				if current.len > 0 {
					result << current.join(' ').trim(' ,.;:')
					current = []string{}
				}
				continue
			}
		}
		current << word
	}
	if current.len > 0 {
		result << current.join(' ').trim(' ,.;:')
	}
	return result.filter(it != '')
}

pub fn explicit_payload(input string) ?string {
	text := strip_openers(repair_speech(input))
	if quoted := quoted_payload(text) {
		return quoted
	}
	lower := text.to_lower()
	for prefix in [
		'search for ', 'search ', 'look up ', 'google ', 'find ',
		'buscar ', 'busca ', 'buscar por ', 'escribe ', 'escribir ', 'type ', 'enter ', 'write ',
	] {
		if lower.starts_with(prefix) {
			mut tail := text[prefix.len..].trim_space()
			for marker in [' on github', ' on youtube', ' en github', ' en youtube',
				' in the search box', ' en el buscador', ' en la caja de busqueda',
				' en la caja de búsqueda'] {
				idx := tail.to_lower().last_index(marker) or { continue }
				if idx > 0 {
					tail = tail[..idx].trim_space()
				}
			}
			if tail != '' {
				return tail
			}
		}
	}
	return none
}

pub fn classify(input string) Intent {
	text := strip_openers(repair_speech(input))
	low := text.to_lower()
	if low == '' {
		return Intent{}
	}
	if low in ['go back', 'back', 'regresa', 'atras', 'atrás'] {
		return Intent{kind: .command, command: 'back', raw: text}
	}
	if low in ['go forward', 'forward', 'adelante'] {
		return Intent{kind: .command, command: 'forward', raw: text}
	}
	if low in ['reload', 'refresh', 'recarga', 'actualiza', 'recargar', 'actualizar'] {
		return Intent{kind: .command, command: 'reload', raw: text}
	}
	if low.contains('new tab') || low.contains('nueva pestaña') || low.contains('nueva pestana') {
		return Intent{kind: .command, command: 'new_tab', raw: text}
	}
	if low.starts_with('close tab') || low.starts_with('cierra la pesta') {
		return Intent{kind: .command, command: 'close_tab', raw: text}
	}
	if low.starts_with('scroll down') || low == 'baja' || low.starts_with('baja ')
		|| low.starts_with('desplaza abajo') {
		return Intent{kind: .command, command: 'scroll_down', raw: text}
	}
	if low.starts_with('scroll up') || low == 'sube' || low.starts_with('sube ')
		|| low.starts_with('desplaza arriba') {
		return Intent{kind: .command, command: 'scroll_up', raw: text}
	}
	if low.starts_with('click ') || low.starts_with('click on ') || low.starts_with('haz clic ')
		|| low.starts_with('pulsa ') {
		return Intent{kind: .command, command: 'click', raw: text, payload: after_first_verb(text)}
	}
	if low.starts_with('type ') || low.starts_with('write ') || low.starts_with('enter ')
		|| low.starts_with('escribe ') {
		payload := explicit_payload(text) or { after_first_verb(text) }
		return Intent{kind: .command, command: 'type', raw: text, payload: payload}
	}
	if low.starts_with('search ') || low.starts_with('look up ') || low.starts_with('google ')
		|| low.starts_with('find ') || low.starts_with('busca ') || low.starts_with('buscar ') {
		payload := explicit_payload(text) or { after_first_verb(text) }
		return Intent{kind: .search, command: 'search', raw: text, payload: payload}
	}
	if low.starts_with('open ') || low.starts_with('go to ') || low.starts_with('visit ')
		|| low.starts_with('abre ') || low.starts_with('ve a ') || low.starts_with('visita ') {
		return Intent{kind: .navigate, command: 'open', raw: text, payload: navigation_payload(text)}
	}
	spoken_url := normalize_spoken_url(text)
	if looks_like_url(spoken_url) {
		return Intent{kind: .navigate, command: 'open', raw: text, payload: spoken_url}
	}
	return Intent{kind: .goal, command: 'goal', raw: text, payload: text}
}

pub fn spoken_number(input string, limit int) int {
	for raw in collapse_spaces(input).to_lower().trim(' ,.;:-').split(' ') {
		word := raw.trim(' ,.;:-')
		value := match word {
			'1', 'one', 'first', 'uno', 'primero' { 1 }
			'2', 'two', 'to', 'too', 'second', 'dos', 'segundo' { 2 }
			'3', 'three', 'third', 'tres', 'tercero' { 3 }
			'4', 'four', 'for', 'fourth', 'cuatro', 'cuarto' { 4 }
			'5', 'five', 'fifth', 'cinco', 'quinto' { 5 }
			'6', 'six', 'sixth', 'seis', 'sexto' { 6 }
			'7', 'seven', 'seventh', 'siete', 'septimo', 'séptimo' { 7 }
			'8', 'eight', 'eighth', 'ocho', 'octavo' { 8 }
			'9', 'nine', 'ninth', 'nueve', 'noveno' { 9 }
			else { 0 }
		}
		if value > 0 && value <= limit {
			return value
		}
	}
	return 0
}

fn navigation_payload(text string) string {
	low := text.to_lower()
	for prefix in ['go to ', 'open ', 'visit ', 've a ', 'abre ', 'visita '] {
		if low.starts_with(prefix) {
			return normalize_spoken_url(text[prefix.len..])
		}
	}
	return normalize_spoken_url(text)
}

fn looks_like_url(value string) bool {
	low := value.to_lower()
	return !low.contains(' ') && (low.starts_with('http://') || low.starts_with('https://')
		|| low.starts_with('www.') || low.contains('.com') || low.contains('.org')
		|| low.contains('.net') || low.contains('.io') || low.contains('.dev') || low.contains('.ai'))
}

fn strip_openers(input string) string {
	mut text := collapse_spaces(input).trim(' ,.;:')
	mut changed := true
	for changed {
		changed = false
		low := text.to_lower()
		for prefix in ['please ', 'can you ', 'could you ', 'would you ', 'ok ', 'okay ',
			'now ', 'por favor ', 'puedes ', 'podrias ', 'podrías ', 'ahora ',
			'and then ', 'then ', 'y luego ', 'luego ', 'entonces '] {
			if low.starts_with(prefix) {
				text = text[prefix.len..].trim_space()
				changed = true
				break
			}
		}
	}
	return text
}

fn strong_command_prefix(input string) bool {
	low := strip_openers(input).to_lower()
	for prefix in ['click ', 'scroll ', 'go back', 'go forward', 'reload', 'refresh', 'open ',
		'close ', 'switch ', 'press ', 'haz clic ', 'regresa', 'recarga', 'abre ', 'cierra ',
		'desplaza ', 'pulsa '] {
		if low.starts_with(prefix) {
			return true
		}
	}
	return false
}

fn quoted_payload(text string) ?string {
	for quote in ['"', "'"] {
		start := text.index(quote) or { continue }
		end_rel := text[start + quote.len..].index(quote) or { continue }
		end := start + quote.len + end_rel
		if end > start + quote.len {
			value := text[start + quote.len..end].trim_space()
			if value != '' {
				return value
			}
		}
	}
	return none
}

fn after_first_verb(text string) string {
	idx := text.index(' ') or { return '' }
	return text[idx + 1..].trim_space()
}

fn collapse_spaces(input string) string {
	return input.split_any(' \t\r\n').filter(it != '').join(' ')
}

fn replace_ci(input string, needle string, replacement string) string {
	mut out := input
	mut low := out.to_lower()
	needle_low := needle.to_lower()
	for {
		idx := low.index(needle_low) or { break }
		out = out[..idx] + replacement + out[idx + needle.len..]
		low = out.to_lower()
	}
	return out
}
