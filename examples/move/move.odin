package move

import "bento:engine"
import "bento:execute"
import "core:math/rand"

// -- Globals -- //

// Game state that will hold relevant global data
// for the life of the game
state: ^engine.GameState

screen_width: int // width of the screen in pixels
screen_height: int // height of the screen in pixels

rect: engine.Rect // rectangle i.e. player
speed :: 300 // movement speed

max_rectangles :: 100

MoveRect :: struct {
	rect:  engine.Rect,
	color: engine.Color,
}

rectangles: [max_rectangles]MoveRect

// -- Main Loop -- //

main :: proc() {
	// main proc, set game function pointers
	platform_config := engine.PlatformConfig {
		title         = "move rectangle",
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

	// set rect width
	rect_width := f64(screen_width) * 0.25

	// initialise rectangle
	rect = engine.rect(
		f64(screen_width) / 2 - 0.5 * rect_width,
		f64(screen_height) / 2 - 0.5 * rect_width,
		rect_width,
		rect_width,
	)

	for i in 0 ..< max_rectangles {
		x := rand.int_max(screen_width)
		y := rand.int_max(screen_height)
		width := rand.int_max(100)

		r := rand.int_max(255)
		g := rand.int_max(255)
		b := rand.int_max(255)

		rectangles[i] = MoveRect {
			rect  = engine.rect(f64(x), f64(y), f64(width), f64(width)),
			color = engine.color(u8(r), u8(g), u8(b), 255),
		}
	}
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

	for i in 0 ..< max_rectangles {
		engine.cmd_draw_rect(state.cmdbuf, rectangles[i].rect, rectangles[i].color)
	}
	// draw red rectangle
	engine.cmd_draw_rect(state.cmdbuf, rect, engine.RED)
	return state.cmdbuf
}

shutdown :: proc() {

	// free state
	engine.game_state_destroy(state)
}
