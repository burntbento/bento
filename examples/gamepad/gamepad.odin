package gamepad

import "bento:engine"
import "bento:execute"
import "core:math"

// -- Globals -- //


// Game state that will hold relevant global data
// for the life of the game
state: ^engine.GameState

screen_width: int // width of the screen in pixels
screen_height: int // height of the screen in pixels

texture_handle: int // handle to the gamepad.png texture
texture_width :: 16 // 16 x 16 cell

scale_constant: f64

// -- Gamepad -- //

// position and scale
parent_position: engine.Vector2
parent_width: f64
parent_height: f64
parent_scale: f64

// joysticks
game_joystick_left: ^Joystick
game_joystick_right: ^Joystick

// buttons
game_button_y: ^Button
game_button_b: ^Button
game_button_a: ^Button
game_button_x: ^Button

// dpad
game_dpad: ^DPAD

// -- Main Loop -- //

main :: proc() {
	// main proc, set game function pointers
	platform_config := engine.PlatformConfig {
		title         = "Gamepad",
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
	scale_constant = f64(screen_width) / f64(screen_height)


	// get texture handle
	texture_handle, err = engine.texture_load("examples/gamepad/gamepad.png", state)
	if err != nil {
		panic("failed to load gamepad.png")
	}

	parent_position = engine.vector2(f64(screen_width) * 0.05, f64(screen_height) * 0.2)
	parent_scale = scale_constant * 6.5
	parent_width = parent_scale * texture_width * 5
	parent_height = parent_scale * texture_width * 3


	// init joystick
	game_joystick_left = joystick_new(
		engine.vector2(
			parent_position.x + parent_width * 0.22,
			parent_position.y + parent_height * 0.15,
		),
		parent_scale * 0.7,
		texture_handle,
	)

	game_joystick_right = joystick_new(
		engine.vector2(
			parent_position.x + parent_width * 0.5,
			parent_position.y + parent_height * 0.35,
		),
		parent_scale * 0.7,
		texture_handle,
		false,
	)

	// init buttons
	scale := parent_scale * 0.3
	button_postions := engine.vector2(
		parent_position.x + parent_width * 0.6,
		parent_position.y + parent_height * 0.1,
	)
	game_button_y = button_new(
		engine.vector2(button_postions.x + texture_width * scale, button_postions.y),
		parent_scale * 0.3,
		engine.InputType.INPUT_GAMEPAD_BUTTON_Y,
		engine.rect(3 * texture_width, 0, texture_width, texture_width),
		engine.rect(2 * texture_width, 0, texture_width, texture_width),
		texture_handle,
	)
	game_button_b = button_new(
		engine.vector2(
			button_postions.x + 2 * texture_width * scale,
			button_postions.y + texture_width * scale,
		),
		parent_scale * 0.3,
		engine.InputType.INPUT_GAMEPAD_BUTTON_B,
		engine.rect(5 * texture_width, 0, texture_width, texture_width),
		engine.rect(4 * texture_width, 0, texture_width, texture_width),
		texture_handle,
	)
	game_button_a = button_new(
		engine.vector2(
			button_postions.x + texture_width * scale,
			button_postions.y + texture_width * 2 * scale,
		),
		parent_scale * 0.3,
		engine.InputType.INPUT_GAMEPAD_BUTTON_A,
		engine.rect(7 * texture_width, 0, texture_width, texture_width),
		engine.rect(6 * texture_width, 0, texture_width, texture_width),
		texture_handle,
	)
	game_button_x = button_new(
		engine.vector2(button_postions.x, button_postions.y + texture_width * scale),
		parent_scale * 0.3,
		engine.InputType.INPUT_GAMEPAD_BUTTON_X,
		engine.rect(9 * texture_width, 0, texture_width, texture_width),
		engine.rect(8 * texture_width, 0, texture_width, texture_width),
		texture_handle,
	)


	game_dpad = dpad_new(
		engine.vector2(
			parent_position.x + parent_width * 0.3,
			parent_position.y + parent_height * 0.35,
		),
		parent_scale * 0.8,
		texture_handle,
	)
}

update :: proc(input: ^engine.GameInput, dt: f64) -> bool {

	// joystick
	joystick_update(game_joystick_left, input, dt)
	joystick_update(game_joystick_right, input, dt)

	// buttons
	button_update(game_button_y, input, dt)
	button_update(game_button_b, input, dt)
	button_update(game_button_a, input, dt)
	button_update(game_button_x, input, dt)

	// dpad
	dpad_update(game_dpad, input, dt)

	return true
}

render :: proc() -> ^engine.RenderCommandBuffer {
	// reset command buffer, it is being allocated in the hot loop
	// resetting here makes sure that memory doesnt build up
	engine.cmd_reset(state.cmdbuf)


	// flush screen with a blank color
	engine.cmd_clear_screen(state.cmdbuf, engine.color(199, 220, 208, 255))


	engine.cmd_draw_sprite(
		state.cmdbuf,
		parent_position,
		scale_constant * 6.5,
		0,
		engine.vector2(0, 0),
		texture_handle,
		engine.rect(0, texture_width, texture_width * 5, texture_width * 3),
		engine.WHITE,
		false,
		false,
	)

	// dpad render
	dpad_render(state.cmdbuf, game_dpad)

	// joystick render
	joystick_render(state.cmdbuf, game_joystick_left)
	joystick_render(state.cmdbuf, game_joystick_right)

	// buttons
	button_render(state.cmdbuf, game_button_y)
	button_render(state.cmdbuf, game_button_b)
	button_render(state.cmdbuf, game_button_a)
	button_render(state.cmdbuf, game_button_x)

	return state.cmdbuf
}


shutdown :: proc() {
	// free dpad
	dpad_destroy(game_dpad)

	// free joystick
	joystick_destroy(game_joystick_left)
	joystick_destroy(game_joystick_right)

	// free button
	button_destroy(game_button_y)
	button_destroy(game_button_b)
	button_destroy(game_button_a)
	button_destroy(game_button_x)

	// free state
	engine.game_state_destroy(state)
}

// -- Joystick -- //
Joystick :: struct {
	position:       engine.Vector2,
	scale:          f64,
	texture_handle: int,
	texture_base:   engine.Rect,
	texture_stick:  engine.Rect,
	input_x:        engine.InputType,
	input_y:        engine.InputType,
	stick_position: engine.Vector2,
}


joystick_new :: proc(
	position: engine.Vector2,
	scale: f64,
	texture_handle: int,
	left := true,
) -> ^Joystick {
	j := new(Joystick)
	j.position = position
	j.stick_position = position
	j.scale = scale
	j.texture_handle = texture_handle
	j.texture_base = engine.rect(0, 0, texture_width, texture_width)
	j.texture_stick = engine.rect(texture_width, 0, texture_width, texture_width)

	j.input_x =
		left ? engine.InputType.INPUT_GAMEPAD_AXIS_LEFTX : engine.InputType.INPUT_GAMEPAD_AXIS_RIGHTX
	j.input_y =
		left ? engine.InputType.INPUT_GAMEPAD_AXIS_LEFTY : engine.InputType.INPUT_GAMEPAD_AXIS_RIGHTY
	return j
}

joystick_update :: proc(joystick: ^Joystick, input: ^engine.GameInput, dt: f64) {
	joystick.stick_position = joystick.position

	left_y := engine.input_state(input, joystick.input_y)
	if math.abs(left_y) > 0.01 {
		joystick.stick_position.y += left_y * joystick.scale * 5
	}

	left_x := engine.input_state(input, joystick.input_x)
	if math.abs(left_y) > 0.01 {
		joystick.stick_position.x += left_x * joystick.scale * 5
	}
}

joystick_render :: proc(cmdbuf: ^engine.RenderCommandBuffer, joystick: ^Joystick) {
	// draw red rectangle in the center of the screen
	engine.cmd_draw_sprite(
		cmdbuf,
		joystick.position,
		joystick.scale,
		0,
		engine.vector2(0, 0),
		joystick.texture_handle,
		joystick.texture_base,
		engine.WHITE,
		false,
		false,
	)

	engine.cmd_draw_sprite(
		cmdbuf,
		joystick.stick_position,
		joystick.scale,
		0,
		engine.vector2(0, 0),
		joystick.texture_handle,
		joystick.texture_stick,
		engine.WHITE,
		false,
		false,
	)
}

joystick_destroy :: proc(joystick: ^Joystick) {
	free(joystick)
}

// -- Button -- //

Button :: struct {
	position:         engine.Vector2,
	scale:            f64,
	texture_handle:   int,
	input:            engine.InputType,
	pressed_texture:  engine.Rect,
	released_texture: engine.Rect,
	pressed:          bool,
}

button_new :: proc(
	position: engine.Vector2,
	scale: f64,
	input: engine.InputType,
	pressed_texture: engine.Rect,
	released_texture: engine.Rect,
	texture_handle: int,
) -> ^Button {
	b := new(Button)
	b.position = position
	b.input = input
	b.scale = scale
	b.texture_handle = texture_handle
	b.pressed_texture = pressed_texture
	b.released_texture = released_texture
	return b
}

button_update :: proc(button: ^Button, input: ^engine.GameInput, dt: f64) {
	button.pressed = false
	if engine.input_state(input, button.input) > 0 {
		button.pressed = true
	}
}

button_render :: proc(cmdbuf: ^engine.RenderCommandBuffer, button: ^Button) {

	dst_rect := button.pressed ? button.pressed_texture : button.released_texture
	engine.cmd_draw_sprite(
		cmdbuf,
		button.position,
		button.scale,
		0,
		engine.vector2(0, 0),
		button.texture_handle,
		dst_rect,
		engine.WHITE,
		false,
		false,
	)
}

button_destroy :: proc(button: ^Button) {
	free(button)
}

// -- DPAD -- //

DPAD :: struct {
	position:       engine.Vector2,
	texture_rect:   engine.Rect,
	texture_handle: int,
	scale:          f64,
}

dpad_new :: proc(position: engine.Vector2, scale: f64, texture_handle: int) -> ^DPAD {
	dpad := new(DPAD)
	dpad.position = position
	dpad.scale = scale
	dpad.texture_handle = texture_handle
	return dpad
}

dpad_update :: proc(dpad: ^DPAD, input: ^engine.GameInput, dt: f64) {
	dpad.texture_rect = engine.rect(texture_width * 5, texture_width, texture_width, texture_width)


	if engine.input_state(input, engine.InputType.INPUT_GAMEPAD_BUTTON_DPAD_UP) > 0 {
		dpad.texture_rect = engine.rect(
			texture_width * 6,
			texture_width,
			texture_width,
			texture_width,
		)
	}

	if engine.input_state(input, engine.InputType.INPUT_GAMEPAD_BUTTON_DPAD_DOWN) > 0 {
		dpad.texture_rect = engine.rect(
			texture_width * 6,
			texture_width * 2,
			texture_width,
			texture_width,
		)
	}

	if engine.input_state(input, engine.InputType.INPUT_GAMEPAD_BUTTON_DPAD_RIGHT) > 0 {
		dpad.texture_rect = engine.rect(
			texture_width * 7,
			texture_width,
			texture_width,
			texture_width,
		)
	}

	if engine.input_state(input, engine.InputType.INPUT_GAMEPAD_BUTTON_DPAD_LEFT) > 0 {
		dpad.texture_rect = engine.rect(
			texture_width * 7,
			texture_width * 2,
			texture_width,
			texture_width,
		)
	}

}

dpad_render :: proc(cmdbuf: ^engine.RenderCommandBuffer, dpad: ^DPAD) {
	engine.cmd_draw_sprite(
		state.cmdbuf,
		dpad.position,
		dpad.scale,
		0,
		engine.vector2(0, 0),
		dpad.texture_handle,
		dpad.texture_rect,
		engine.WHITE,
		false,
		false,
	)
}

dpad_destroy :: proc(dpad: ^DPAD) {
	free(dpad)
}
