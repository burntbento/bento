package engine

import "core:mem"
import vmem "core:mem/virtual"

GameState :: struct {
	platform:          ^Platform,
	global_allocator:  mem.Allocator,
	scratch_allocator: mem.Allocator,
	level_allocator:   mem.Allocator,
	scratch_arena:     vmem.Arena,
	level_arena:       vmem.Arena,
	cmdbuf:            ^RenderCommandBuffer,
	asset_cache:       ^AssetCache,
	storage:           Storage,
	ctx:               rawptr, // just to hold game layer globals
}

// Storage
Storage :: enum {
	FILE,
	USER,
}
