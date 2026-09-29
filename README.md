# bento

2D Game Engine written in Odin with SDL3.

# Architecture

The engine is split into 3 layers, engine, platform and execute.

The engine layer is responsible for general data structures and logic that will be general across most games e.g. camera struct and transitions. It also provides a the api interface for the platform layer.

The platform layer is what interacts with the operating system and provides platform specific code to, for example, draw a rectangle or play some audio. Currently the only platform layer is a sdl3 implementation. This layer provides common apis that can be hooked up to other graphics backends including OpenGL, Raylib, Vulkan and DX12.

The execute layer is a small layer that takes in a game vtable and runs the main game loop. You can also implement your own main loop which can be a bit tedious.

# Examples

For convinience, there is a examples folder that holds some simple examples to get started with. It also shows how to idiomatically use this library.

Run examples from the root of the directory with,

```odin
odin run ./examples/{example_name}/{example_name}.odin -file -collection:bento=src
```
or if using the Makefile,

```odin
make run-example example={examplename} // make run-example example=rectangle
```
A full example of rectangle.odin,

```odin
// examples/rectangle/rectangle.odin

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

	// fill vtable
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
	state, err = engine.game_state_new()
	if err != nil {
		panic(engine.fmt_error(err, context.temp_allocator))
	}

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
	engine.rendercommandbuffer_destroy(state.cmdbuf)

	// free state
	engine.game_state_destroy(state)
}
```






