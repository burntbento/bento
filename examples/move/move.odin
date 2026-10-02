package move

import "bento:engine"
import "bento:execute"

// -- Globals -- //

// Game state that will hold relevant global data
// for the life of the game
state: ^engine.GameState

screen_width: int // width of the screen in pixels
screen_height: int // height of the screen in pixels

rect: engine.Rect // rectangle i.e. player
speed :: 300 // movement speed

// -- Main Loop -- //

main :: proc() {
	// main proc, set game function pointers
	platform_config := engine.PlatformConfig {
		title         = "move rectangle",
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
	err: engine.Error
	state, err = engine.game_state_new(platform)
	if err != nil {
		panic(engine.fmt_error(err, context.temp_allocator))
	}

	// fill in screen_width and height
	screen_width, screen_height = state.platform.get_window_size()

	// set rect width
	rect_width := f64(screen_width) * 0.25

	// initialise rectangle
	rect = engine.rect(
		f64(screen_width) / 2 - 0.5 * rect_width,
		f64(screen_height) / 2 - 0.5 * rect_width,
		rect_width,
		rect_width,
	)
}

update :: proc(input: ^engine.GameInput, dt: f64) -> bool {

	if engine.input_state(input, engine.InputType.INPUT_KEY_RIGHT) > 0 {
		rect.x += speed * dt
	}

	if engine.input_state(input, engine.InputType.INPUT_KEY_LEFT) > 0 {
		rect.x -= speed * dt
	}

	if engine.input_state(input, engine.InputType.INPUT_KEY_DOWN) > 0 {
		rect.y += speed * dt
	}

	if engine.input_state(input, engine.InputType.INPUT_KEY_UP) > 0 {
		rect.y -= speed * dt
	}

	return true
}

render :: proc() -> ^engine.RenderCommandBuffer {
	// reset command buffer, it is being allocated in the hot loop
	// resetting here makes sure that memory doesnt build up
	engine.cmd_reset(state.cmdbuf)

	// flush screen with a blank color
	engine.cmd_clear_screen(state.cmdbuf, engine.WHITE)

	// draw red rectangle
	engine.cmd_draw_rect(state.cmdbuf, rect, engine.RED)
	return state.cmdbuf
}

shutdown :: proc() {

	// free state
	engine.game_state_destroy(state)
}
