package platform_opengl
import "core:strings"

import "bento:engine"
import sdl "vendor:sdl3"

get_file_size :: proc(path: cstring) -> int {
	outSize: u64
	if (!sdl.GetStorageFileSize(platform_storage, path, &outSize)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"failed to get file size: %s",
			sdl.GetError(),
		)
		return 0
	}
	return cast(int)outSize
}

load_file :: proc(path: cstring, buffer: rawptr, size: int) -> bool {
	if (!sdl.ReadStorageFile(platform_storage, path, buffer, cast(u64)size)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"failed to read file at %s: %s",
			path,
			sdl.GetError(),
		)
		return false
	}
	return true
}

write_file :: proc(path: string, buffer: rawptr, size: int, storage: engine.Storage) -> bool {
	cpath := strings.clone_to_cstring(path, context.temp_allocator)

	// open and close writer
	ok := platform_storage_init_writer(storage)
	if !ok do return false
	defer platform_storage_destroy_writer()

	if !sdl.WriteStorageFile(platform_storage, cpath, buffer, cast(u64)size) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"failed to write file at %s: %s",
			cpath,
			sdl.GetError(),
		)
		return false
	}
	return true
}
