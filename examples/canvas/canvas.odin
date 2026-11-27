package canvas

import "bento:engine"
import "bento:execute"

// -- Globals -- //


// Game state that will hold relevant global data
// for the life of the game
state: ^engine.GameState

screen_width: int // width of the screen in pixels
screen_height: int // height of the screen in pixels

texture_handle: int // handle to the cauldron.png texture
animation: ^engine.Animation // holds animation state
flip: bool

canvas_handle: int
canvas_width, canvas_height: int

texture_w :: 16
texture_h :: 16

// -- Main Loop -- //

main :: proc() {
	// main proc, set game function pointers
	platform_config := engine.PlatformConfig {
		title         = "canvas",
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

	// fill in screen_width and height
	screen_width, screen_height = state.platform.get_window_size()

	// get texture handle
	texture_handle, err = engine.load_texture("examples/canvas/sprite.png", state)
	if err != nil {
		panic("failed to load retro_cats")
	}

	// init animation state
	animation = engine.animation_new(texture_w, texture_h)
	engine.animation_add(animation, "idle", 0, 0, 1, 0.2, true)
	engine.animation_add(animation, "down", 0, 0, 2, 0.2, true)
	engine.animation_add(animation, "up", 0, 2, 2, 0.2, true)
	engine.animation_add(animation, "right", 0, 4, 2, 0.2, true)

	engine.animation_switch(animation, "idle")

	canvas_handle = state.platform.create_canvas()
	canvas_width, canvas_height = state.platform.get_canvas_dimensions(canvas_handle)
}

update :: proc(input: ^engine.GameInput, dt: f64) -> bool {

	if engine.input_state(input, .INPUT_KEY_RIGHT) > 0 {
		engine.animation_update(animation, dt)
		engine.animation_switch(animation, "right")
		flip = false
		return true
	}

	if engine.input_state(input, .INPUT_KEY_LEFT) > 0 {
		engine.animation_update(animation, dt)
		engine.animation_switch(animation, "right")
		flip = true
		return true
	}

	if engine.input_state(input, .INPUT_KEY_DOWN) > 0 {
		engine.animation_update(animation, dt)
		engine.animation_switch(animation, "down")
		return true
	}

	if engine.input_state(input, .INPUT_KEY_UP) > 0 {
		engine.animation_update(animation, dt)
		engine.animation_switch(animation, "up")
		return true
	}

	return true
}

render :: proc() -> ^engine.RenderCommandBuffer {
	// reset command buffer, it is being allocated in the hot loop
	// resetting here makes sure that memory doesnt build up
	engine.cmd_reset(state.cmdbuf)


	// flush screen with a blank color
	engine.cmd_clear_screen(state.cmdbuf, engine.WHITE)

	engine.cmd_attach_canvas(state.cmdbuf, canvas_handle)
	engine.cmd_clear_screen(state.cmdbuf, engine.WHITE)

	// postion centering the sprite based on scale
	scale: f64 = 8
	pos := engine.vector2(
		f64(screen_width) / 2 - 0.5 * texture_w * scale,
		f64(screen_height) / 2 - 0.5 * texture_h * scale,
	)

	current_frame := engine.animation_get_current_frame_dimensions(animation)

	engine.cmd_draw_sprite(
		state.cmdbuf,
		pos,
		scale,
		0,
		engine.vector2(0, 0),
		texture_handle,
		current_frame,
		engine.WHITE,
		flip,
		false,
	)
	engine.cmd_detach_canvas(state.cmdbuf)

	engine.cmd_present_canvas(
		state.cmdbuf,
		engine.vector2(0, 0),
		1,
		0,
		engine.vector2(0, 0),
		canvas_handle,
		engine.WHITE,
		false,
		true,
		0,
		0,
	)

	engine.cmd_present_canvas(
		state.cmdbuf,
		engine.vector2(0, 0),
		0.2,
		0,
		engine.vector2(0, 0),
		canvas_handle,
		engine.WHITE,
		false,
		true,
		0,
		0,
	)

	engine.cmd_present_canvas(
		state.cmdbuf,
		engine.vector2(f64(screen_width) - f64(canvas_width) * 0.2, 0),
		0.2,
		0,
		engine.vector2(0, 0),
		canvas_handle,
		engine.WHITE,
		false,
		true,
		0,
		0,
	)

	engine.cmd_present_canvas(
		state.cmdbuf,
		engine.vector2(0, f64(screen_height) - f64(canvas_height) * 0.2),
		0.2,
		0,
		engine.vector2(0, 0),
		canvas_handle,
		engine.WHITE,
		false,
		true,
		0,
		0,
	)

	engine.cmd_present_canvas(
		state.cmdbuf,
		engine.vector2(
			f64(screen_width) - f64(canvas_width) * 0.2,
			f64(screen_height) - f64(canvas_height) * 0.2,
		),
		0.2,
		0,
		engine.vector2(0, 0),
		canvas_handle,
		engine.WHITE,
		false,
		true,
		0,
		0,
	)


	return state.cmdbuf
}

shutdown :: proc() {

	// free animation
	engine.animation_destroy(animation)

	// free state
	engine.game_state_destroy(state)
}
