package platform_opengl
import "bento:engine"

// text
destroy_all_fonts :: proc() {}

load_font :: proc(path: string, size: f32) -> int {
	return -1
}

measure_text :: proc(font_handle: int, text: string) -> (width: int, height: int) {
	return 0, 0
}

draw_text :: proc(position: engine.Vector2, text: string, font_handle: int, color: engine.Color) {}

draw_debug_text :: proc(position: engine.Vector2, text: string, scale: f32, color: engine.Color) {}

start_text_input :: proc() {}

stop_text_input :: proc() {}

get_text_input_buffer :: proc() -> ([64]u8, int) {
	return {}, 0
}
