package engine

import "base:intrinsics"
import "core:mem"

/*
	 NOTE: custom commands in clay must have something in them so that clay doesnt think its nil.
	 Very annoying to debug when you think everything should be working.
*/

// custom commands for clay renderer
ClayNineSliceFrame :: struct {
	texture:   int,
	origin:    Vector2,
	tile_size: int,
	scale:     int,
}

// add custom commands to the tagged union
ClayCustom :: union {
	ClayNineSliceFrame,
}

// create a union of pointers for rendering switch statement
ClayCustomPtr :: intrinsics.type_convert_variants_to_pointers(ClayCustom)


// create a new nine slice struct
clay_new_nine_slice_frame :: proc(
	origin: Vector2,
	texture: int,
	scale: int,
	tile_size: int,
	arena_allocator: mem.Allocator,
) -> ^ClayNineSliceFrame {
	data := new(ClayNineSliceFrame, arena_allocator)
	data.texture = texture
	data.scale = scale
	data.tile_size = tile_size
	data.origin = origin
	return data
}
