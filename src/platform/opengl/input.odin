package platform_opengl

import "bento:engine"
import "core:math"
import "core:mem"
import sdl "vendor:sdl3"

// -- Input -- //
gamepad: ^sdl.Gamepad
DEADZONE: f64

// input
sdl_mouse_mapping :: [?]int {
	sdl.BUTTON_LEFT   = int(engine.InputType.INPUT_MOUSE_BUTTON_LEFT),
	sdl.BUTTON_MIDDLE = int(engine.InputType.INPUT_MOUSE_BUTTON_MIDDLE),
	sdl.BUTTON_RIGHT  = int(engine.InputType.INPUT_MOUSE_BUTTON_RIGHT),
	sdl.BUTTON_X1     = int(engine.InputType.INPUT_MOUSE_BUTTON_X1),
	sdl.BUTTON_X2     = int(engine.InputType.INPUT_MOUSE_BUTTON_X2),
}
sdl_gamepad_mapping :: [?]int {
	sdl.GamepadButton.SOUTH          = int(engine.InputType.INPUT_GAMEPAD_BUTTON_A),
	sdl.GamepadButton.EAST           = int(engine.InputType.INPUT_GAMEPAD_BUTTON_B),
	sdl.GamepadButton.WEST           = int(engine.InputType.INPUT_GAMEPAD_BUTTON_X),
	sdl.GamepadButton.NORTH          = int(engine.InputType.INPUT_GAMEPAD_BUTTON_Y),
	sdl.GamepadButton.BACK           = int(engine.InputType.INPUT_GAMEPAD_BUTTON_SELECT),
	sdl.GamepadButton.GUIDE          = int(engine.InputType.INPUT_GAMEPAD_BUTTON_HOME),
	sdl.GamepadButton.START          = int(engine.InputType.INPUT_GAMEPAD_BUTTON_START),
	sdl.GamepadButton.LEFT_STICK     = int(engine.InputType.INPUT_GAMEPAD_BUTTON_LEFT_STICK),
	sdl.GamepadButton.RIGHT_STICK    = int(engine.InputType.INPUT_GAMEPAD_BUTTON_RIGHT_STICK),
	sdl.GamepadButton.LEFT_SHOULDER  = int(engine.InputType.INPUT_GAMEPAD_BUTTON_LEFT_SHOULDER),
	sdl.GamepadButton.RIGHT_SHOULDER = int(engine.InputType.INPUT_GAMEPAD_BUTTON_RIGHT_SHOULDER),
	sdl.GamepadButton.DPAD_UP        = int(engine.InputType.INPUT_GAMEPAD_BUTTON_DPAD_UP),
	sdl.GamepadButton.DPAD_DOWN      = int(engine.InputType.INPUT_GAMEPAD_BUTTON_DPAD_DOWN),
	sdl.GamepadButton.DPAD_LEFT      = int(engine.InputType.INPUT_GAMEPAD_BUTTON_DPAD_LEFT),
	sdl.GamepadButton.DPAD_RIGHT     = int(engine.InputType.INPUT_GAMEPAD_BUTTON_DPAD_RIGHT),
	sdl.GamepadButton.MISC1          = int(engine.InputType.INPUT_GAMEPAD_BUTTON_MISC1),
	sdl.GamepadButton.RIGHT_PADDLE1  = int(engine.InputType.INPUT_GAMEPAD_BUTTON_PADDLE1_RIGHT),
	sdl.GamepadButton.LEFT_PADDLE1   = int(engine.InputType.INPUT_GAMEPAD_BUTTON_PADDLE1_LEFT),
	sdl.GamepadButton.RIGHT_PADDLE2  = int(engine.InputType.INPUT_GAMEPAD_BUTTON_PADDLE2_RIGHT),
	sdl.GamepadButton.LEFT_PADDLE2   = int(engine.InputType.INPUT_GAMEPAD_BUTTON_PADDLE2_LEFT),
	sdl.GamepadButton.TOUCHPAD       = int(engine.InputType.INPUT_GAMEPAD_BUTTON_TOUCHPAD),
	sdl.GamepadButton.MISC2          = int(engine.InputType.INPUT_GAMEPAD_BUTTON_MISC2),
	sdl.GamepadButton.MISC3          = int(engine.InputType.INPUT_GAMEPAD_BUTTON_MISC3),
	sdl.GamepadButton.MISC4          = int(engine.InputType.INPUT_GAMEPAD_BUTTON_MISC4),
	sdl.GamepadButton.MISC5          = int(engine.InputType.INPUT_GAMEPAD_BUTTON_MISC5),
	sdl.GamepadButton.MISC6          = int(engine.InputType.INPUT_GAMEPAD_BUTTON_MISC6),
}
sdl_gamepad_axis_mapping :: [?]int {
	sdl.GamepadAxis.LEFTX         = int(engine.InputType.INPUT_GAMEPAD_AXIS_LEFTX),
	sdl.GamepadAxis.LEFTY         = int(engine.InputType.INPUT_GAMEPAD_AXIS_LEFTY),
	sdl.GamepadAxis.RIGHTX        = int(engine.InputType.INPUT_GAMEPAD_AXIS_RIGHTX),
	sdl.GamepadAxis.RIGHTY        = int(engine.InputType.INPUT_GAMEPAD_AXIS_RIGHTY),
	sdl.GamepadAxis.LEFT_TRIGGER  = int(engine.InputType.INPUT_GAMEPAD_AXIS_LEFT_TRIGGER),
	sdl.GamepadAxis.RIGHT_TRIGGER = int(engine.InputType.INPUT_GAMEPAD_AXIS_RIGHT_TRIGGER),
}

update_input :: proc(input: ^engine.GameInput) {
	input_reset(input)

	evt: sdl.Event
	for (sdl.PollEvent(&evt)) {
		if (evt.type == sdl.EventType.QUIT) {
			input.app_exit_requested = true
			break
		} else if (evt.type == sdl.EventType.KEY_DOWN || evt.type == sdl.EventType.KEY_UP) {

			code := int(evt.key.scancode) - 4
			state := (evt.type == sdl.EventType.KEY_DOWN) ? 1.0 : 0.0
			input_set_state(input, cast(engine.InputType)code, f64(state))
		} else if (evt.type == sdl.EventType.MOUSE_BUTTON_DOWN ||
			   evt.type == sdl.EventType.MOUSE_BUTTON_UP) {
			temp_mapping := sdl_mouse_mapping
			type := engine.InputType(temp_mapping[evt.button.button])
			state: f64 = (evt.type == sdl.EventType.MOUSE_BUTTON_DOWN) ? 1.0 : 0.0
			input_set_state(input, type, state)
		} else if (evt.type == sdl.EventType.MOUSE_MOTION) {
			density := f64(sdl.GetWindowPixelDensity(window)) // NOTE: added this for hpdi windows and mouse position
			input.mouse_x = f64(evt.motion.x) * density
			input.mouse_y = f64(evt.motion.y) * density
		} else if (evt.type == sdl.EventType.GAMEPAD_ADDED) {
			if (gamepad == nil) {
				gamepad = sdl.OpenGamepad(evt.gdevice.which)
				if (gamepad == nil) {
					sdl.LogError(
						cast(i32)sdl.LogCategory.CUSTOM,
						"SDL could not open gamepad: %s",
						sdl.GetError(),
					)

				}
			}
		} else if (evt.type == sdl.EventType.GAMEPAD_REMOVED) {
			if (gamepad != nil && sdl.GetGamepadID(gamepad) == evt.gdevice.which) {
				sdl.CloseGamepad(gamepad)
				gamepad = nil

			}

		} else if (evt.type == sdl.EventType.GAMEPAD_BUTTON_DOWN ||
			   evt.type == sdl.EventType.GAMEPAD_BUTTON_UP) {
			if (evt.gbutton.button < len(sdl_gamepad_mapping)) {
				temp_mapping := sdl_gamepad_mapping
				type := engine.InputType(temp_mapping[evt.gbutton.button])
				state: f64 = evt.type == sdl.EventType.GAMEPAD_BUTTON_DOWN ? 1.0 : 0.0
				input_set_state(input, type, state)
			}
		} else if (evt.type == sdl.EventType.GAMEPAD_AXIS_MOTION) {
			state: f64 = f64(evt.gaxis.value) / 32767.0
			temp_mapping := sdl_gamepad_axis_mapping
			code: int = temp_mapping[evt.gaxis.axis]
			input_set_state(input, engine.InputType(code), state)
			set_gamepad_axis_half(input, engine.InputType(code), state)
		} else if (evt.type == sdl.EventType.TEXT_INPUT) {
			// fill buffer

			// NOTE: not implemented
		}
	}
}

input_set_state :: proc(input: ^engine.GameInput, type: engine.InputType, state: f64) {
	if (state > 0.0 + DEADZONE && in_between_deadzone(input.state[type])) {
		input.pressed[type] = true
	} else if (in_between_deadzone(state) && input.state[type] > 0.0) {
		input.released[type] = true
	}
	input.state[type] = state
}

input_reset :: proc(input: ^engine.GameInput) {
	mem.set(&input.released, 0, size_of(input.released))
	mem.set(&input.pressed, 0, size_of(input.released))
}

in_between_deadzone :: proc(state: f64) -> bool {
	return state <= DEADZONE && state >= -DEADZONE
}

set_gamepad_axis_half :: proc(input: ^engine.GameInput, type: engine.InputType, state: f64) {
	#partial switch type {
	case engine.InputType.INPUT_GAMEPAD_AXIS_LEFTX:
		set_half_axis_state(
			input,
			state,
			engine.InputType.INPUT_GAMEPAD_AXIS_LEFTX_POS,
			engine.InputType.INPUT_GAMEPAD_AXIS_LEFTX_NEG,
		)
	case engine.InputType.INPUT_GAMEPAD_AXIS_LEFTY:
		set_half_axis_state(
			input,
			state,
			engine.InputType.INPUT_GAMEPAD_AXIS_LEFTY_POS,
			engine.InputType.INPUT_GAMEPAD_AXIS_LEFTY_NEG,
		)
	case engine.InputType.INPUT_GAMEPAD_AXIS_RIGHTX:
		set_half_axis_state(
			input,
			state,
			engine.InputType.INPUT_GAMEPAD_AXIS_RIGHTX_POS,
			engine.InputType.INPUT_GAMEPAD_AXIS_RIGHTX_NEG,
		)
	case engine.InputType.INPUT_GAMEPAD_AXIS_RIGHTY:
		set_half_axis_state(
			input,
			state,
			engine.InputType.INPUT_GAMEPAD_AXIS_RIGHTY_POS,
			engine.InputType.INPUT_GAMEPAD_AXIS_RIGHTY_NEG,
		)
	}
}

set_half_axis_state :: proc(
	input: ^engine.GameInput,
	state: f64,
	type_pos: engine.InputType,
	type_neg: engine.InputType,
) {
	if state > 0.0 {
		input_set_state(input, type_pos, state)
	}
	if state < 0.0 {
		input_set_state(input, type_neg, math.abs(state))
	}
}

gamepad_rumble :: proc(low_frequency_rumble: u16, high_frequency_rumble: u16, duration_ms: u32) {
	if gamepad == nil do return
	if !sdl.RumbleGamepad(gamepad, low_frequency_rumble, high_frequency_rumble, duration_ms) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL failed to rumble gamepad: %s",
			sdl.GetError(),
		)
	}
}


set_deadzone :: proc(dz: f64) {
	ensure(dz >= 0, "Deadzone must be positive")
	DEADZONE = dz
}

get_deadzone :: proc() -> f64 {
	return DEADZONE
}
