package platform_opengl

import "bento:engine"
import sdl "vendor:sdl3"


@(private)
GLColor :: struct {
	r, g, b, a: f32,
}

@(private)
engine_color_to_gl_color :: #force_inline proc(color: engine.Color) -> GLColor {
	return GLColor {
		r = f32(color.r / 255),
		g = f32(color.g / 255),
		b = f32(color.b / 255),
		a = f32(color.a / 255),
	}
}

get_performance_frequency :: proc() -> u64 {
	return sdl.GetPerformanceFrequency()
}


get_performance_counter :: proc() -> u64 {
	return sdl.GetPerformanceCounter()
}


get_page_size :: proc() -> i32 {
	return sdl.GetSystemPageSize()
}

free_mem :: proc(mem: rawptr) {
	sdl.free(mem)
}

get_window_size :: proc() -> (int, int) {
	w, h: i32
	sdl.GetWindowSizeInPixels(window, &w, &h)
	return int(w), int(h)
}

// get_render_size returns the pixels size of the renderer context
// note: should be the same as sdl.GetWindowSizeInPixels
get_render_size :: proc() -> (int, int) {
	w, h: i32
	if !sdl.GetWindowSizeInPixels(window, &w, &h) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"failed to get renderer size %s",
			sdl.GetError(),
		)
	}
	return int(w), int(h)
}
