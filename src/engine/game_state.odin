package engine

import "base:runtime"
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

game_state_new :: proc(loc := #caller_location) -> (^GameState, Error) {
	state, err := new(GameState)
	if err != nil {
		return nil, RUNTIME_ERROR{message = "allocation error", code = int(err), location = loc}
	}
	return state, nil
}

game_state_destroy :: proc(game_state: ^GameState) {
	free(game_state)
}
