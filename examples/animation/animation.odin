package animation

// retro_cat.png https://toffeecraft.itch.io/cat-retro

import "bento:engine"
import "bento:execute"

// -- Globals -- //


// Game state that will hold relevant global data
// for the life of the game
state: ^engine.GameState

screen_width: int // width of the screen in pixels
screen_height: int // height of the screen in pixels

texture_handle: int // handle to the retro_cat.png texture
animation: ^engine.Animation // holds animation state

// -- Main Loop -- //

main :: proc() {
	// main proc, set game function pointers
	platform_config := engine.PlatformConfig {
		title         = "retro cat",
		window_width  = 800,
		window_height = 600,
		fullscreen    = false,
		scale_mode    = .NEAREST,
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
	texture_handle, err = engine.texture_load("examples/animation/retro_cats.png", state)
	if err != nil {
		panic("failed to load retro_cats")
	}

	// init animation state
	animation = engine.animation_new(64, 64)
	engine.animation_add(animation, "idle", 0, 0, 4, 0.1, true)
	engine.animation_switch(animation, "idle")
}

update :: proc(input: ^engine.GameInput, dt: f64) -> bool {
	engine.animation_update(animation, dt)
	return true
}

render :: proc() -> ^engine.RenderCommandBuffer {
	// reset command buffer, it is being allocated in the hot loop
	// resetting here makes sure that memory doesnt build up
	engine.cmd_reset(state.cmdbuf)


	// flush screen with a blank color
	engine.cmd_clear_screen(state.cmdbuf, engine.WHITE)

	// postion centering the sprite based on scale
	scale: f64 = 4
	pos := engine.vector2(
		f64(screen_width) / 2 - 0.5 * 64 * scale,
		f64(screen_height) / 2 - 0.5 * 64 * scale,
	)

	// draw red rectangle in the center of the screen
	engine.cmd_draw_sprite(
		state.cmdbuf,
		pos,
		scale,
		0,
		engine.vector2(0, 0),
		texture_handle,
		engine.rect(f64(animation.animations[animation.current].current_frame * 64), 0, 64, 64),
		engine.WHITE,
		false,
		false,
	)
	return state.cmdbuf
}

shutdown :: proc() {

	// free animation
	engine.animation_destroy(animation)

	// free state
	engine.game_state_destroy(state)
}
