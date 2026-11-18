package engine

import "core:strings"

load_texture :: proc {
	load_texture_cstring,
	load_texture_string,
}

load_texture_string :: proc(path: string, state: ^GameState) -> (handle: int, error: Error) {
	cstr, err := strings.clone_to_cstring(path, context.temp_allocator)
	if err != nil {
		state.platform.logger(.ERROR, "Failed to convert string to cstring")
		return -1, error.(RUNTIME_ERROR)
	}

	return load_texture_cstring(cstr, state)
}

load_texture_cstring :: proc(path: cstring, state: ^GameState) -> (handle: int, error: Error) {
	assert(len(path) > 0)

	key := string(path)
	if asset, ok := state.asset_cache.texture_cache[key]; ok {
		return asset.handle, nil
	}

	// TODO: detect extension and load based on that
	img := load_png_image(path, state) or_return

	img_id := state.platform.create_texture(img.width, img.height, img.channels, img.bpp, img.data)
	state.asset_cache.texture_cache[strings.clone(key)] = TextureAsset {
		handle = img_id,
		width  = img.width,
		height = img.height,
	}

	return img_id, nil
}

// dimensions of an already loaded texture, ok is false if it was never loaded
texture_size :: proc(path: cstring, state: ^GameState) -> (w, h: int, ok: bool) {
	asset, found := state.asset_cache.texture_cache[string(path)]
	if !found {
		return 0, 0, false
	}
	return asset.width, asset.height, true
}
