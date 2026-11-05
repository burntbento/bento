package textinput

import "bento:engine"
import "bento:execute"
import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"

// -- Globals -- //


// Game state that will hold relevant global data
// for the life of the game
state: ^engine.GameState

screen_width: int // width of the screen in pixels
screen_height: int // height of the screen in pixels

// -- Main Loop -- //

main :: proc() {
	// main proc, set game function pointers
	platform_config := engine.PlatformConfig {
		title         = "text input",
		window_width  = 800,
		window_height = 600,
		fullscreen    = false,
		scale_mode    = .NEAREST,
		logging_level = .VERBOSE,
	}

	game_data := execute.Game {
		platform_config = platform_config,
		game_init       = init,
		game_update     = update,
		game_render     = render,
		game_shutdown   = shutdown,
	}

	// start main loop
	execute.engine_run(&game_data)
}


// -- Game Functions -- //

init :: proc(platform: ^engine.Platform) {

	// create new instance of gamestate
	err: engine.Error
	state, err = engine.game_state_new(platform)
	if err != nil {
		panic(engine.fmt_error(err, context.temp_allocator))
	}


	// init scratch arena
	err_vmem := vmem.arena_init_growing(&state.scratch_arena, mem.Gigabyte)
	ensure(err_vmem == nil)
	state.scratch_allocator = vmem.arena_allocator(&state.scratch_arena)


	// fill in screen_width and height
	screen_width, screen_height = state.platform.get_window_size()
}

update :: proc(input: ^engine.GameInput, dt: f64) -> bool {
	state.platform.start_text_input()
	return true
}

render :: proc() -> ^engine.RenderCommandBuffer {
	// reset command buffer, it is being allocated in the hot loop
	// resetting here makes sure that memory doesnt build up
	engine.cmd_reset(state.cmdbuf)


	// flush screen with a blank color
	engine.cmd_clear_screen(state.cmdbuf, engine.WHITE)

	text_buffer, text_len := state.platform.get_text_input_buffer()

	text := fmt.aprintf("%s", text_buffer[:text_len], allocator = state.scratch_allocator)
	if text_len != 0 {
		engine.cmd_draw_debug_text(
			state.cmdbuf,
			engine.vector2(f64(screen_width) / 2, f64(screen_height) / 2),
			text,
			2,
			engine.BLACK,
		)
	}
	return state.cmdbuf
}

shutdown :: proc() {
	// free state
	engine.game_state_destroy(state)
}
