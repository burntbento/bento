// credit journey.wav https://chajamakesmusic.itch.io/cute-and-silly-rpg-music-pack

package audio

import "bento:engine"
import "bento:execute"
import "core:mem"
import vmem "core:mem/virtual"

// -- Globals -- //


// Game state that will hold relevant global data
// for the life of the game
state: ^engine.GameState

screen_width: int // width of the screen in pixels
screen_height: int // height of the screen in pixels

// audio settings
music: engine.AudioClip
music_state: bool
music_handle: int
music_settings: ^engine.AudioSettings

// -- Main Loop -- //

main :: proc() {
	// main proc, set game function pointers
	platform_config := engine.PlatformConfig {
		title         = "audio",
		window_width  = 800,
		window_height = 600,
		fullscreen    = false,
		scale_mode    = .LINEAR,
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

	// init memory
	state.global_allocator = context.allocator

	// init scratch arena
	allocation_err := vmem.arena_init_growing(&state.scratch_arena, mem.Gigabyte)
	ensure(allocation_err == nil)
	state.scratch_allocator = vmem.arena_allocator(&state.scratch_arena)

	// fill in screen_width and height
	screen_width, screen_height = state.platform.get_window_size()

	// audio init
	engine.audio_init()

	// music
	music = engine.audio_load(state, "examples/audio/journey.wav")

	music_settings = new(engine.AudioSettings)
	music_settings.loop = true
	music_settings.volume = 0.8

	music_handle = engine.audio_play(state, music, music_settings)
	music_state = true
}

update :: proc(input: ^engine.GameInput, dt: f64) -> bool {

	// update audio state
	engine.audio_update(state)

	if engine.input_pressed(input, engine.InputType.INPUT_KEY_SPACE) {
		if music_state {
			engine.audio_pause(state, music_handle)
		} else {
			engine.audio_resume(state, music_handle)
		}
		music_state = !music_state
	}

	if engine.input_pressed(input, engine.InputType.INPUT_KEY_UP) {
		music_settings.volume += 0.1
		engine.audio_set_volume(state, music_handle, music_settings.volume)
	}

	if engine.input_pressed(input, engine.InputType.INPUT_KEY_DOWN) {
		music_settings.volume -= 0.1
		engine.audio_set_volume(state, music_handle, music_settings.volume)
	}

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
	// free music settings
	free(music_settings)

	// free sounds
	state.platform.destroy_all_sounds()

	// free audio
	engine.audio_shutdown(state)

	// free state
	engine.game_state_destroy(state)
}
