package platform_opengl

import "bento:engine"
import "core:c"
import "core:mem"
import "core:strings"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

// -- OPENGL Version -- //
MAJOR :: 4
MINOR :: 6

// -- Globals -- //
window: ^sdl.Window
platform_config: ^PlatformConfig
gl_context: sdl.GLContext


// main
init :: proc(config: engine.PlatformConfig) {

	platform_config = platform_config_new(config)

	// INFO: set log verbosiity, turn off in production, should we write somewhere?
	sdl.SetLogPriorities(.VERBOSE)

	// init glfw
	if !sdl.Init(sdl.INIT_VIDEO) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not be initialised: %s",
			sdl.GetError(),
		)
	}

	// set window hints
	sdl.GL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, MAJOR)
	sdl.GL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, MINOR)
	sdl.GL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, i32(sdl.GL_CONTEXT_PROFILE_CORE))
	sdl.GL_SetAttribute(sdl.GL_DOUBLEBUFFER, 1)

	// set window
	window = sdl.CreateWindow(
		platform_config.title,
		platform_config.window_width,
		platform_config.window_height,
		{.OPENGL},
	)
	if window == nil {
		panic("Failed to open GLFW window")
	}

	// create context
	gl_context = sdl.GL_CreateContext(window)
	sdl.GL_MakeCurrent(window, gl_context)

	// load function pointers
	gl.load_up_to(MAJOR, MINOR, sdl.gl_set_proc_address)

}

begin_frame :: proc() {}

end_frame :: proc() {
	sdl.GL_SwapWindow(window)
}

shutdown :: proc() {

	// destroy platform stuff
	platform_config_destroy(platform_config)

	// destroy glfw
	sdl.DestroyWindow(window)

	// destroy gl context
	sdl.GL_DestroyContext(gl_context)

	// final termation
	sdl.Quit()
}

// files io
get_file_size :: proc(path: cstring) -> int {
	return 0
}

load_file :: proc(path: cstring, buffer: rawptr, size: int) -> bool {
	return false
}

write_file :: proc(path: string, buffer: rawptr, size: int, storage: engine.Storage) -> bool {
	return false
}

// storage
platform_storage_init :: proc() {}

platform_storage_destroy :: proc() {}

platform_storage_init_writer :: proc(storage: engine.Storage) -> bool {
	return false
}

platform_storage_destroy_writer :: proc() {}

// textures / canvas
create_texture :: proc(width, height, channels, bpp: int, data: ^u32) -> int {
	return -1
}

create_placeholder_texture :: proc() {}

set_renderer_draw_color :: proc(r, g, b, a: u8) -> bool {
	return false
}

create_canvas :: proc(width, height: int) -> int {
	return -1
}

push_canvas :: proc(canvas: int) {}

pop_canvas :: proc() {}

destroy_all_textures :: proc() {}

get_window_size :: proc() -> (int, int) {
	return 0, 0
}

get_render_size :: proc() -> (int, int) {
	return 0, 0
}

// drawing
clear_screen :: proc(color: engine.Color) {
	gl_color := engine_color_to_gl_color(color)
	gl.ClearColor(gl_color.r, gl_color.g, gl_color.b, gl_color.a)
	gl.Clear(gl.COLOR_BUFFER_BIT)
}

draw_rect :: proc(rect: engine.Rect, color: engine.Color) {}

draw_rect_line :: proc(rect: engine.Rect, color: engine.Color) {}

draw_circle :: proc(circle: engine.Circle, color: engine.Color) {}

draw_arc :: proc(
	center: engine.Vector2,
	radius, start_angle, end_angle, thickness: f32,
	color: engine.Color,
) {}

draw_sprite :: proc(
	position: engine.Vector2,
	scale, rotation: f64,
	pivot: engine.Vector2,
	texture_handle: int,
	texture_rect: engine.Rect,
	color: engine.Color,
	flip_x, flip_y: bool,
	stretch_x, stretch_y: int,
) {}

set_clip_rect :: proc(rect: engine.Rect) {}

end_clip_rect :: proc() {}

attach_camera :: proc(cam: ^engine.Camera2D) {}

detach_camera :: proc() {}

// text
destroy_all_fonts :: proc() {}

load_font :: proc(path: string, size: f32) -> int {
	return -1
}

measure_text :: proc(font_handle: int, text: string) -> (width: int, height: int) {
	return 0, 0
}

draw_text :: proc(position: engine.Vector2, text: string, font_handle: int, color: engine.Color) {}

draw_debug_text :: proc(position: engine.Vector2, text: string, scale: f32, color: engine.Color) {}

start_text_input :: proc() {}

stop_text_input :: proc() {}

get_text_input_buffer :: proc() -> ([64]u8, int) {
	return {}, 0
}

// shaders
shader_create_info :: proc(shader_create_info: engine.ShaderCreateInfo) -> int {
	return -1
}

destroy_all_shaders :: proc() {}

set_gpu_fragment_shader_uniforms :: proc(
	shader: int,
	slot: u32,
	uniform: rawptr,
	uniform_length: u32,
) {}

push_shader_state :: proc(shader: int) {}

pop_shader_state :: proc() {}

// audio
destroy_all_sounds :: proc() {}

load_sound :: proc(
	data: ^u8,
	length: int,
	format, channels, freq: ^int,
	out_buffer: ^[^]u8,
	out_length: ^u32,
) -> bool {
	return false
}

play_sound :: proc(format, channels, freq: int, data: ^u8, length: int, volume: f64) -> int {
	return -1
}

resume_sound :: proc(handle: int) -> bool {
	return false
}

pause_sound :: proc(handle: int) -> bool {
	return false
}

set_sound_volume :: proc(handle: int, volume: f64) -> bool {
	return false
}

is_sound_playing :: proc(handle: int) -> bool {
	return false
}

// input
update_input :: proc(input: ^engine.GameInput) {

	evt: sdl.Event
	for sdl.PollEvent(&evt) {
		if evt.type == sdl.EventType.QUIT {
			input.app_exit_requested = true
			break
		}
	}

}

input_set_state :: proc(input: ^engine.GameInput, type: engine.InputType, state: f64) {}

input_reset :: proc(input: ^engine.GameInput) {}

in_between_deadzone :: proc(state: f64) -> bool {
	return false
}

set_gamepad_axis_half :: proc(input: ^engine.GameInput, type: engine.InputType, state: f64) {}

set_half_axis_state :: proc(
	input: ^engine.GameInput,
	state: f64,
	type_pos: engine.InputType,
	type_neg: engine.InputType,
) {}

gamepad_rumble :: proc(low_frequency_rumble: u16, high_frequency_rumble: u16, duration_ms: u32) {}

set_deadzone :: proc(dz: f64) {}

get_deadzone :: proc() -> f64 {
	return 0.0
}

get_performance_frequency :: proc() -> u64 {
	return sdl.GetPerformanceFrequency()
}


get_performance_counter :: proc() -> u64 {
	return sdl.GetPerformanceCounter()
}

logger :: proc(msg: string, args: ..any) {}

get_page_size :: proc() -> i32 {
	return 0
}

free_mem :: proc(mem: rawptr) {}


@(private)
PlatformConfig :: struct {
	title:         cstring,
	window_width:  c.int,
	window_height: c.int,
	// allocator
	_allocator:    mem.Allocator,
}

@(private)
platform_config_new :: proc(
	config: engine.PlatformConfig,
	allocator := context.allocator,
) -> ^PlatformConfig {

	p_config := new(PlatformConfig, allocator)


	title, err := strings.clone_to_cstring(config.title, allocator)
	if err != nil {
		panic("Failed to load config, cstring clone allocation failed")
	}

	p_config.title = title

	// window
	p_config.window_width = c.int(config.window_width)
	p_config.window_height = c.int(config.window_height)

	// set allocator
	p_config._allocator = allocator

	return p_config
}

platform_config_destroy :: proc(platform_config: ^PlatformConfig) {
	allocator := platform_config._allocator
	delete(platform_config.title)
	free(platform_config, allocator)
}


// helpers

@(private)
GLColor :: struct {
	r, g, b, a: f32,
}

@(private)
engine_color_to_gl_color :: #force_inline proc(color: engine.Color) -> GLColor {
	return GLColor{r = f32(color.r), g = f32(color.g), b = f32(color.b), a = f32(color.a)}
}
