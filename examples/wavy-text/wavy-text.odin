// credit font.ttf https://managore.itch.io/m5x7

package wavytext

import "bento:engine"
import "bento:execute"
import "core:mem"
import vmem "core:mem/virtual"
import "core:unicode/utf8"

// -- Globals -- //

// Game state that will hold relevant global data
// for the life of the game
state: ^engine.GameState

screen_width: int // width of the screen in pixels
screen_height: int // height of the screen in pixels

// font handle
font_handle: int
font_w: int
font_h: int
heading :: "Wavy Text"

g_wavy_text: ^WavyText

// -- Main Loop -- //

main :: proc() {
	// main proc, set game function pointers
	platform_config := engine.PlatformConfig {
		title         = "wavy text",
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

	// init memory
	state.global_allocator = context.allocator

	// init scratch arena
	allocation_err := vmem.arena_init_growing(&state.scratch_arena, mem.Gigabyte)
	ensure(allocation_err == nil)
	state.scratch_allocator = vmem.arena_allocator(&state.scratch_arena)

	// fill in screen_width and height
	screen_width, screen_height = state.platform.get_window_size()

	// font
	font_handle = engine.load_font("examples/wavy-text/font.ttf", 64, state)
	font_w, font_h = state.platform.measure_text(font_handle, heading)

	g_wavy_text = wavy_text_new(heading, font_handle)
}

update :: proc(input: ^engine.GameInput, dt: f64) -> bool {
	free_all(context.temp_allocator)

	wavy_text_update(g_wavy_text, input, dt)
	return true
}

render :: proc() -> ^engine.RenderCommandBuffer {
	// reset command buffer, it is being allocated in the hot loop
	// resetting here makes sure that memory doesnt build up
	engine.cmd_reset(state.cmdbuf)

	// flush screen with a blank color
	engine.cmd_clear_screen(state.cmdbuf, engine.WHITE)

	wavy_text_render(g_wavy_text)

	return state.cmdbuf
}

shutdown :: proc() {
	wavy_text_destroy(g_wavy_text)

	// free state
	engine.game_state_destroy(state)
}


// -- Wavy Text -- //
Letters :: struct {
	letter: rune,
}


WavyText :: struct {
	text:        string,
	font_handle: int,
	text_array:  [dynamic]Letters,
	width:       int,
}


wavy_text_new :: proc(text: string, font_handle: int) -> ^WavyText {
	wavy_text := new(WavyText)
	wavy_text.text = text
	wavy_text.font_handle = font_handle
	wavy_text.text_array = make([dynamic]Letters)

	for letter in text {
		append(&wavy_text.text_array, Letters{letter = letter})
	}

	wavy_text.width, _ = state.platform.measure_text(font_handle, "W")

	return wavy_text
}

wavy_text_update :: proc(wavy_text: ^WavyText, input: ^engine.GameInput, dt: f64) {

}

wavy_text_render :: proc(wavy_text: ^WavyText) {

	acc_offset := 0
	for letter in wavy_text.text_array {
		string_letter, _ := utf8.runes_to_string([]rune{letter.letter}, context.temp_allocator)
		engine.cmd_draw_text(
			state.cmdbuf,
			engine.vector2(
				f64(screen_width - font_w) / 2 + f64(acc_offset),
				f64(screen_height - font_h) / 2,
			),
			string_letter,
			font_handle, // use default font
			engine.BLACK,
		)

		acc_offset += wavy_text.width
	}
}

wavy_text_destroy :: proc(wavy_text: ^WavyText) {
	delete(wavy_text.text_array)
	free(wavy_text)
}
