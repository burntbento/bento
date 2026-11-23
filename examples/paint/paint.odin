package paint

import "base:runtime"
import "bento:engine"
import clay "bento:engine/vendor/clay-odin"
import "bento:execute"
import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"

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
selected_color: engine.Color
canvas_color: engine.Color
font_32: int

palette :: [3]engine.Color{{123, 123, 123, 255}, {233, 21, 12, 255}, {100, 24, 255, 255}}

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

	// init scratch arena
	err2 := vmem.arena_init_growing(&state.scratch_arena, mem.Gigabyte)
	ensure(err2 == nil)
	state.scratch_allocator = vmem.arena_allocator(&state.scratch_arena)
	context.temp_allocator = state.scratch_allocator

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
	clay.SetMeasureTextFunction(measure_text, nil)

	font_32 = engine.load_font("examples/paint/monogram.ttf", 32, state)

	frame = new(engine.ClayNineSliceFrame)
	frame.texture = ui_texture
	frame.origin = engine.vector2(0, 0)
	frame.tile_size = 16
	frame.scale = 4
}

update :: proc(input: ^engine.GameInput, dt: f64) -> bool {
	vmem.arena_free_all(&state.scratch_arena)

	is_mouse_down := engine.input_pressed(input, .INPUT_MOUSE_BUTTON_RIGHT)
	clay.SetPointerState({f32(input.mouse_x), f32(input.mouse_y)}, is_mouse_down)

	sidebar_id := clay.ID("SideBar")
	// sidebar_data := clay.GetElementData(sidebar_id)

	clay.BeginLayout()

	if clay.UI(clay.ID("outercontainter"))(
	{
		layout = {
			layoutDirection = clay.LayoutDirection.TopToBottom,
			sizing = {clay.SizingGrow({}), clay.SizingGrow({})},
			padding = clay.PaddingAll(10),
			childGap = 5,
		},
		backgroundColor = engine.clay_engine_color_to_clay(engine.color(40, 40, 46, 255)),
	},
	) {

		if clay.UI(clay.ID("header"))(
		{
			layout = {
				layoutDirection = clay.LayoutDirection.LeftToRight,
				sizing = {clay.SizingPercent(1), clay.SizingPercent(0.1)},
				padding = clay.PaddingAll(5),
				childGap = 16,
			},
			backgroundColor = engine.clay_engine_color_to_clay(engine.color(40, 40, 46, 255)),
		},
		) {
			clay.Text(
				"Paint Something! :)",
				{
					fontId = u16(font_32),
					textColor = engine.clay_engine_color_to_clay(engine.color(254, 170, 228, 255)),
				},
			)


			color_text := fmt.aprintf(
				"Color: (%d, %d, %d)",
				selected_color.r,
				selected_color.g,
				selected_color.b,
				allocator = state.scratch_allocator,
			)
			clay.Text(
				color_text,
				{
					fontId = u16(font_32),
					textColor = engine.clay_engine_color_to_clay(engine.color(254, 170, 228, 255)),
				},
			)

			mouse_position_text := fmt.aprintf(
				"Mouse: (%.2f, %.2f)",
				input.mouse_x,
				input.mouse_y,
				allocator = state.scratch_allocator,
			)
			clay.Text(
				mouse_position_text,
				{
					fontId = u16(font_32),
					textColor = engine.clay_engine_color_to_clay(engine.color(254, 170, 228, 255)),
				},
			)

			canvas_data := clay.GetElementData(clay.ID("canvas"))
			canvas_text := fmt.aprintf(
				"Canvas: (%.2f, %.2f)",
				canvas_data.boundingBox.width,
				canvas_data.boundingBox.height,
				allocator = state.scratch_allocator,
			)
			clay.Text(
				canvas_text,
				{
					fontId = u16(font_32),
					textColor = engine.clay_engine_color_to_clay(engine.color(254, 170, 228, 255)),
				},
			)
		}


		if clay.UI(clay.ID("body"))(
		{
			layout = {
				layoutDirection = clay.LayoutDirection.LeftToRight,
				sizing = {clay.SizingGrow({}), clay.SizingGrow({})},
				padding = clay.PaddingAll(10),
				childGap = 16,
			},
			backgroundColor = engine.clay_engine_color_to_clay(engine.color(40, 40, 46, 255)),
		},
		) {
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
			) {

				pressed := engine.input_pressed(input, .INPUT_MOUSE_BUTTON_LEFT)
				if clay.Hovered() && pressed {
					canvas_color = selected_color
				}
			}

			if clay.UI(sidebar_id)(
			{
				layout = {
					layoutDirection = clay.LayoutDirection.TopToBottom,
					sizing = {clay.SizingFixed(300), clay.SizingGrow({})},
					padding = clay.PaddingAll(16),
					childAlignment = {
						y = clay.LayoutAlignmentY.Top,
						x = clay.LayoutAlignmentX.Left,
					},
				},
				custom = {customData = frame},
			},
			) {
				clay.Text(
					"Palette",
					{
						fontId = u16(font_32),
						textColor = engine.clay_engine_color_to_clay(
							engine.color(254, 170, 228, 255),
						),
					},
				)
				if clay.UI(clay.ID("Palette"))(
				{
					layout = {
						layoutDirection = clay.LayoutDirection.LeftToRight,
						sizing = {clay.SizingGrow({}), clay.SizingGrow({})},
						padding = clay.PaddingAll(5),
						childGap = 5,
					},
					backgroundColor = engine.clay_engine_color_to_clay(
						engine.color(40, 40, 46, 255),
					),
				},
				) {
					for c, i in palette {
						cell_component(i, c, input)
					}
				}
			}
		}

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

	canvas := clay.GetElementData(clay.ID("canvas"))
	engine.cmd_draw_rect(
		state.cmdbuf,
		engine.rect(
			f64(canvas.boundingBox.x),
			f64(canvas.boundingBox.y),
			f64(canvas.boundingBox.width),
			f64(canvas.boundingBox.height),
		),
		canvas_color,
	)

	return state.cmdbuf
}

shutdown :: proc() {
	free(frame)
	free(clay_memory)

	vmem.arena_free_all(&state.scratch_arena)
	// free state
	engine.game_state_destroy(state)
}


cell_component :: proc(id: int, color: engine.Color, input: ^engine.GameInput) {
	key := clay.ID(fmt.aprintf("cell-%d", id, allocator = state.scratch_allocator))
	if clay.UI(key)(
	{
		layout = {
			sizing = {clay.SizingFixed(30), clay.SizingFixed(30)},
			padding = clay.PaddingAll(5),
		},
		backgroundColor = engine.clay_engine_color_to_clay(color),
	},
	) {

		pressed := engine.input_pressed(input, .INPUT_MOUSE_BUTTON_LEFT)
		if clay.PointerOver(key) && pressed {
			selected_color = color
		}
	}
}
