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
	_allocator:        mem.Allocator, // private alloctor for object in the gamestate
}

// Storage
Storage :: enum {
	FILE,
	USER,
}


// game_state creates a new pointer to GameState using the
// given allocator. It also creates the render command buffer and asset cache.
//
// Must be freed with game_state_destroy, this also destroys the
// memory of render command buffer and asset cache.
game_state_new :: proc(
	platform: ^Platform,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	^GameState,
	Error,
) {
	state, err := new(GameState, allocator)
	if err != nil {
		return nil, RUNTIME_ERROR{message = "allocation error", code = int(err), location = loc}
	}

	// set allocator
	state._allocator = allocator

	// set platform
	state.platform = platform

	// create cmdbuf
	state.cmdbuf = rendercommandbuffer_new(allocator)

	// create asset_cache
	state.asset_cache = asset_cache_new(allocator)

	return state, nil
}

game_state_destroy :: proc(game_state: ^GameState) {
	allocator := game_state._allocator

	// destroy cmbuf
	rendercommandbuffer_destroy(game_state.cmdbuf, allocator)
	game_state.platform.logger(.DEBUG, "Destroyed render command buffer")

	// destory asset cache
	asset_cache_destroy(game_state.asset_cache)
	game_state.platform.logger(.DEBUG, "Destroyed asset cache")

	game_state.platform.logger(.DEBUG, "Shutdown...")
	free(game_state)
}
