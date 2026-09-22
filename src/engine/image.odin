package engine

import "core:mem"
import "vendor:stb/image"

Image :: struct {
	x, y:          int,
	width, height: int,
	channels:      int, // channels normally 4 for r g b a
	bpp:           int, // bytes per pixel
	data:          ^u32, // the actual pixel data
	ok:            bool,
}

load_png_image :: proc(
	path: cstring,
	state: ^GameState,
	loc := #caller_location,
) -> (
	Image,
	Error,
) {

	img: Image

	size := state.platform.get_file_size(path)
	assert(size > 0)

	buffer := make([]u8, size, context.temp_allocator)
	state.platform.load_file(path, raw_data(buffer), size)

	width, height, channels: i32
	decoded := image.load_from_memory(
		raw_data(buffer),
		cast(i32)size,
		&width,
		&height,
		&channels,
		4,
	)
	if (decoded == nil) {
		return img, IO_ERROR{message = "Failed to decode file", location = loc}
	}
	defer image.image_free(decoded)

	data_size := int(width) * int(height) * 4
	data := make([]u8, data_size, context.temp_allocator)
	mem.copy(raw_data(data), decoded, data_size)

	img.width = int(width)
	img.height = int(height)
	img.channels = int(channels)
	img.bpp = 4
	img.data = cast(^u32)raw_data(data)
	img.ok = true
	return img, nil
}
