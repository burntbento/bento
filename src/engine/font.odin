package engine

import "core:fmt"

@(private)
font_make_key :: proc(path: string, size: f32) -> string {
	return fmt.aprintf("%s-%d", path, int(size))
}

// only ttf fonts
load_font :: proc(path: string, size: f32, state: ^GameState) -> int {
	key := font_make_key(path, size)
	if handle, ok := state.asset_cache.font_cache[key]; ok {
		return handle
	}
	font := state.platform.load_font(path, size)
	state.asset_cache.font_cache[key] = font
	return font
}
