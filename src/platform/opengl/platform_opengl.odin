package platform_opengl

import "bento:engine"
import "core:c"
import "core:log"
import "core:mem"
import "core:strings"
import gl "vendor:OpenGL"
import "vendor:glfw"

// -- Globals -- //
window: glfw.WindowHandle
platform_config: ^PlatformConfig

platform_logger: log.Logger

// main
init :: proc(config: engine.PlatformConfig) {

	// set logging
	init_logger()
	context.logger = platform_logger

	platform_config = platform_config_new(config)
	log.info("Engine starting, chose OpenGL backend")

	// init glfw
	glfw.Init()
	log.info("GLFW initialising...")

	// set window hints
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 1)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, gl.TRUE)

	// set window
	window = glfw.CreateWindow(
		platform_config.window_width,
		platform_config.window_height,
		platform_config.title,
		nil,
		nil,
	)
	if window == nil {
		log.error("GLFW window is nil, exiting")
		panic("Failed to open GLFW window")
	}
	log.info("GLFW set window")

	glfw.MakeContextCurrent(window)

	gl.load_up_to(4, 1, glfw.gl_set_proc_address)
	major, minor: i32
	gl.GetIntegerv(gl.MAJOR_VERSION, &major)
	gl.GetIntegerv(gl.MINOR_VERSION, &minor)
	log.infof("OpenGL Version: %d.%d", major, minor)


	// set framesize callback
	glfw.SetFramebufferSizeCallback(window, framesize_buffer_callback)
	log.info("GLFW set framebuffer callback")

	w, h := glfw.GetFramebufferSize(window)
	gl.Viewport(0, 0, w, h)
}

begin_frame :: proc() {}

end_frame :: proc() {
	glfw.SwapBuffers(window)
}

shutdown :: proc() {
	context.logger = platform_logger

	// last log then destroy
	log.info("Engine shutting down")
	defer log.destroy_console_logger(context.logger)

	// destroy platform stuff
	platform_config_destroy(platform_config)

	// destroy glfw
	glfw.DestroyWindow(window)


	// final termation
	glfw.Terminate()
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

	if glfw.WindowShouldClose(window) {
		input.app_exit_requested = true
	}

	glfw.PollEvents()
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
	return glfw.GetTimerFrequency()
}


get_performance_counter :: proc() -> u64 {
	return glfw.GetTimerValue()
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

// callbacks
@(private)
framesize_buffer_callback :: proc "c" (window: glfw.WindowHandle, width: c.int, height: c.int) {
	gl.Viewport(0, 0, width, height)
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

@(private)
init_logger :: proc() {
	platform_logger = log.create_console_logger(
		lowest = .Debug,
		opt = {.Level, .Date, .Time, .Short_File_Path, .Terminal_Color},
	)
}
