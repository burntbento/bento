package engine

import clay "./vendor/clay-odin"

clay_color_to_engine :: #force_inline proc(clay_color: clay.Color) -> Color {
	return color(u8(clay_color.r), u8(clay_color.g), u8(clay_color.b), u8(clay_color.a))
}

clay_engine_color_to_clay :: #force_inline proc(color: Color) -> clay.Color {
	return clay.Color{f32(color.r), f32(color.g), f32(color.b), f32(color.a)}
}

// helps with exiting a layout e.g. text block
// use with a on exit hook or another similar thing, clay needs one
// frame without the persistent id so trigger a exit hook
clay_render_dummy :: proc() -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()
	return clay.EndLayout(0)
}

error_handler :: proc "c" (errorData: clay.ErrorData) {}
