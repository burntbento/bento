package paint

import "base:runtime"
import "bento:engine"
import clay "bento:engine/vendor/clay-odin"
import "bento:execute"

// -- Globals -- //

// Game state that will hold relevant global data
// for the life of the game
state: ^engine.GameState

screen_width: int // width of the screen in pixels
screen_height: int // height of the screen in pixels

total_memory_size: u32
clay_memory: [^]u8
clay_render_commands: clay.ClayArray(clay.RenderCommand)
arena: clay.Arena

ui_texture: int
frame: ^engine.ClayNineSliceFrame

measure_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	userData: rawptr,
) -> clay.Dimensions {
	context = runtime.default_context()
	w, h := state.platform.measure_text(int(config.fontId), string(text.chars[:text.length]))
	return {width = f32(w), height = f32(h)}
}


// -- Main Loop -- //

main :: proc() {
	// main proc, set game function pointers
	platform_config := engine.PlatformConfig {
		title         = "paint",
		window_width  = 1920 / 2,
		window_height = 1080 / 2,
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

	ui_texture, _ = engine.load_texture("examples/paint/editor.png", state)

	// fill in screen_width and height
	screen_width, screen_height = state.platform.get_window_size()

	total_memory_size = clay.MinMemorySize()
	clay_memory = make([^]u8, total_memory_size)

	arena = clay.CreateArenaWithCapacityAndMemory(uint(total_memory_size), clay_memory)
	clay.Initialize(
		arena,
		clay.Dimensions{width = f32(screen_width), height = f32(screen_height)},
		{handler = engine.error_handler},
	)

	frame = new(engine.ClayNineSliceFrame)
	frame.texture = ui_texture
	frame.origin = engine.vector2(0, 0)
	frame.tile_size = 16
	frame.scale = 10
}

update :: proc(input: ^engine.GameInput, dt: f64) -> bool {

	clay.BeginLayout()

	if clay.UI(clay.ID("outercontainer"))(
	{
		layout = {
			sizing = {clay.SizingGrow({}), clay.SizingGrow({})},
			padding = clay.PaddingAll(0),
			childGap = 16,
		},
		backgroundColor = engine.clay_engine_color_to_clay(engine.WHITE),
	},
	) {

		if clay.UI(clay.ID("SideBar"))(
		{
			layout = {
				layoutDirection = clay.LayoutDirection.TopToBottom,
				sizing = {clay.SizingFixed(300), clay.SizingGrow({})},
				padding = clay.PaddingAll(16),
				childAlignment = {y = clay.LayoutAlignmentY.Center},
			},
			custom = {customData = frame},
		},
		) {}

		if clay.UI(clay.ID("canvas"))(
		{
			layout = {
				layoutDirection = clay.LayoutDirection.TopToBottom,
				sizing = {clay.SizingGrow({}), clay.SizingGrow({})},
				padding = clay.PaddingAll(16),
				childAlignment = {y = clay.LayoutAlignmentY.Center},
			},
			backgroundColor = engine.clay_engine_color_to_clay(engine.WHITE),
		},
		) {}


		if clay.UI(clay.ID("SideBar2"))(
		{
			layout = {
				layoutDirection = clay.LayoutDirection.TopToBottom,
				sizing = {clay.SizingFixed(300), clay.SizingGrow({})},
				padding = clay.PaddingAll(16),
				childAlignment = {y = clay.LayoutAlignmentY.Center},
			},
			custom = {customData = frame},
		},
		) {}
	}

	clay_render_commands = clay.EndLayout(f32(dt))

	return true
}

render :: proc() -> ^engine.RenderCommandBuffer {
	// reset command buffer, it is being allocated in the hot loop
	// resetting here makes sure that memory doesnt build up
	engine.cmd_reset(state.cmdbuf)


	// flush screen with a blank color
	engine.cmd_clear_screen(state.cmdbuf, engine.WHITE)

	engine.platform_clay_render_commands(state.cmdbuf, &clay_render_commands, state)

	return state.cmdbuf
}

shutdown :: proc() {
	free(frame)
	free(clay_memory)
	// free state
	engine.game_state_destroy(state)
}
