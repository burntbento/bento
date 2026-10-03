package engine


ScaleMode :: enum {
	NEAREST,
	LINEAR,
	PIXELART,
}

// PlatformConfig is used to set settings of platform layer
PlatformConfig :: struct {
	title:         string,
	window_width:  int,
	window_height: int,
	fullscreen:    bool,

	// scale mode
	scale_mode:    ScaleMode,

	// storage
	org:           string,
	app:           string,
}

// Platform is a v table that is filled in the execute logic
Platform :: struct {
	// memory
	allocate_memory:                  proc(size: int) -> rawptr, // NOTE: not sure if ill use these
	free_memory:                      proc(p: rawptr),

	// files
	get_file_size:                    proc(path: cstring) -> int,
	load_file:                        proc(path: cstring, buffer: rawptr, size: int) -> bool,
	write_file:                       proc(
		path: string,
		buffer: rawptr,
		size: int,
		storage: Storage,
	) -> bool,

	// graphics
	create_texture:                   proc(width, height, channels, bpp: int, data: ^u32) -> int,
	create_canvas:                    proc(width, height: int) -> int,
	push_canvas:                      proc(canvas: int),
	pop_canvas:                       proc(),
	destroy_all_textures:             proc(),
	get_window_size:                  proc() -> (int, int),
	get_render_size:                  proc() -> (int, int),

	// audio
	is_sound_playing:                 proc(handle: int) -> bool,
	pause_sound:                      proc(handle: int) -> bool,
	resume_sound:                     proc(handle: int) -> bool,
	play_sound:                       proc(
		format, channels, freq: int,
		data: ^u8,
		length: int,
		volume: f64,
	) -> int,
	destroy_all_sounds:               proc(),
	load_sound:                       proc(
		data: ^u8,
		length: int,
		format, channels, freq: ^int,
		out_buffer: ^[^]u8,
		out_length: ^u32,
	) -> bool,

	// fonts
	destroy_all_fonts:                proc(),
	load_font:                        proc(path: string, size: f32) -> int,
	measure_text:                     proc(
		font_handle: int,
		text: string,
	) -> (
		width: int,
		height: int,
	),

	// text input
	start_text_input:                 proc(),
	stop_text_input:                  proc(),
	get_text_input_buffer:            proc() -> ([64]u8, int),

	// gamepad
	gamepad_rumble:                   proc(
		low_frequency_rumble: u16,
		high_frequency_rumble: u16,
		duration_ms: u32,
	),
	set_deadzone:                     proc(dz: f64),
	get_deadzone:                     proc() -> f64,

	// shaders
	shader_create_info:               proc(shader: ShaderCreateInfo) -> int,
	destroy_all_shaders:              proc(),
	set_gpu_fragment_shader_uniforms: proc(
		shader: int,
		slot: u32,
		uniform: rawptr,
		uniform_length: u32,
	),

	// logger
	logger:                           proc(msg: string, args: ..any),

	// memory
	free_mem:                         proc(mem: rawptr),
}
