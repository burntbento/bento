package platform_opengl

import "bento:engine"
import sdl "vendor:sdl3"

platform_storage: ^sdl.Storage

// storage
platform_storage_init :: proc() {

	platform_storage = sdl.OpenTitleStorage(nil, 0)
	if (platform_storage == nil) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"Title storage could not be opened: %s",
			sdl.GetError(),
		)
		panic("initialisation error: failed to open title storage")
	}
	for !sdl.StorageReady(platform_storage) do sdl.Delay(1)
}

platform_storage_destroy :: proc() {
	ok := sdl.CloseStorage(platform_storage)
	if (!ok) {
		sdl.LogError(cast(i32)sdl.LogCategory.CUSTOM, "failed to close storage %s", sdl.GetError())
	}
}

platform_storage_init_writer :: proc(storage: engine.Storage) -> bool {
	return false
}

platform_storage_destroy_writer :: proc() {}
