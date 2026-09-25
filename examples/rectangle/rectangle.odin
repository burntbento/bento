package rectangle

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
		title         = "rectangle",
		window_width  = 800,
		window_height = 600,
		fullscreen    = false,
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
	state = new(engine.GameState)

	// create new command buffer
	state.cmdbuf = engine.rendercommandbuffer_new()

	// point state to platform
	state.platform = platform

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


	// set rect width
	rect_width := f64(screen_width) * 0.25

	// flush screen with a blank color
	engine.cmd_clear_screen(state.cmdbuf, engine.WHITE)

	// draw red rectangle in the center of the screen
	engine.cmd_draw_rect(
		state.cmdbuf,
		engine.rect(
			f64(screen_width) / 2 - 0.5 * rect_width,
			f64(screen_height) / 2 - 0.5 * rect_width,
			rect_width,
			rect_width,
		),
		engine.RED,
	)
	return state.cmdbuf
}

shutdown :: proc() {

	// free cmd_buffer
	free(state.cmdbuf)

	// free state
	free(state)
}
