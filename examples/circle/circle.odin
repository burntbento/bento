package circle

import "bento:engine"
import "bento:execute"

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
		title         = "circle",
		window_width  = 800,
		window_height = 600,
		fullscreen    = false,
		scale_mode    = .LINEAR,
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

	// fill in screen_width and height
	screen_width, screen_height = state.platform.get_window_size()
}

update :: proc(input: ^engine.GameInput, dt: f64) -> bool {
	return true
}

render :: proc() -> ^engine.RenderCommandBuffer {
	// reset command buffer, it is being allocated in the hot loop
	// resetting here makes sure that memory doesnt build up
	engine.cmd_reset(state.cmdbuf)


	// set radius
	radius := f64(screen_width) * 0.25 * 0.5

	// flush screen with a blank color
	engine.cmd_clear_screen(state.cmdbuf, engine.WHITE)

	// draw red circle in the center of the screen
	engine.cmd_draw_circle(
		state.cmdbuf,
		engine.circle(f64(screen_width / 2) - radius, f64(screen_height / 2) - radius, radius),
		engine.RED,
	)
	return state.cmdbuf
}

shutdown :: proc() {
	// free state
	engine.game_state_destroy(state)
}
