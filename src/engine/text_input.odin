package engine

import "base:runtime"
import "core:mem"
import "core:strings"

TextInput :: struct($Cap: int) {
	text_buffer: [Cap]u8,
	len:         int,
	cap:         int,
	allocator:   mem.Allocator,
}

text_input_new :: proc($Cap: int, allocator := context.allocator) -> ^TextInput(Cap) {
	t := new(TextInput(Cap), allocator)
	t.cap = Cap
	t.len = 0

	t.allocator = allocator
	return t
}

text_input_push :: proc(text_input: ^TextInput($Cap), text_delta: rawptr, len: int) -> bool {
	if text_input.len > text_input.cap - 1 {
		return false
	}

	mem.copy(&text_input.text_buffer[text_input.len], text_delta, len)
	text_input.len += len
	return true
}

text_input_get_string :: proc(
	text_input: ^TextInput($Cap),
	allocator := context.allocator,
) -> (
	string,
	runtime.Allocator_Error,
) {
	text, err := strings.clone_from_ptr(&text_input.text_buffer[0], text_input.len, allocator)
	if err != nil {
		return "", err
	}
	return text, nil
}


text_input_destroy :: proc(text_input: ^TextInput($Cap)) {
	allocator := text_input.allocator
	free(text_input, allocator)
}
