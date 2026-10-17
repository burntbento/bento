package platform_opengl

import "bento:engine"
import "core:c"
import "core:fmt"
import "core:math"
import "core:math/linalg/glsl"
import "core:mem"
import "core:strings"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

PlatformStorage :: struct {
	title:    ^sdl.Storage,
	writable: ^sdl.Storage,
}

/*
   Globals

   All global variables for platform layer should live in this block with a short description of what it is.
*/


// -- OPENGL Version -- //
MAJOR :: 4
MINOR :: 6

gl_context: sdl.GLContext

window: ^sdl.Window // sdl window

renderer: ^Renderer // opengl renderer

platform_config: ^PlatformConfig // config

gamepad: ^sdl.Gamepad // for gamepad
platform_storage: ^PlatformStorage // sdl platform_storage interface
audio_device: sdl.AudioDeviceID // sdl audio device
render_cam: ^engine.Camera2D // sdl renderer


text_buffer: [64]u8 // text buffer for text input not key input
text_buffer_len: int // text buffer length

MAX_CONCURRENT_AUDIO_STREAMS :: 32
PLACEHOLDER_TEXTURE_HANDLE :: -1

placeholder_texture: RendererTexture // pointer for placeholder texture
textures: [dynamic]RendererTexture // dynamic array of textures
streams: [MAX_CONCURRENT_AUDIO_STREAMS]^sdl.AudioStream // array of audio streams
stream_count := 0 // current stream count, could also migrate to dynamic array

// fonts
fonts: [dynamic]^ttf.Font // dynamic array of ttf fonts
text_engine: ^ttf.TextEngine // pointer to sdl text engine

DEADZONE: f64

NUM_CIRCLE_SEGMENTS :: 48


@(private)
PlatformConfig :: struct {
	title:         cstring,
	window_width:  c.int,
	window_height: c.int,
	flags:         sdl.WindowFlags,
	org:           cstring, // for storage api
	app:           cstring, // for storage api
	scale_mode:    sdl.ScaleMode,
	logging_level: engine.LoggerLevels,
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

	org, org_err := strings.clone_to_cstring(config.org, allocator)
	if org_err != nil {
		panic("Failed to load config, cstring clone allocation failed")
	}

	app, app_err := strings.clone_to_cstring(config.app, allocator)
	if app_err != nil {
		panic("Failed to load config, cstring clone allocation failed")
	}

	flags: sdl.WindowFlags = {.HIGH_PIXEL_DENSITY, .OPENGL}
	if config.fullscreen {
		flags += {.FULLSCREEN}
	}

	p_config.title = title

	// window
	p_config.window_width = c.int(config.window_width)
	p_config.window_height = c.int(config.window_height)

	// storage
	p_config.org = org
	p_config.app = app

	// sdl flags
	p_config.flags = flags

	// logging level
	p_config.logging_level = config.logging_level

	// set scale mode
	switch config.scale_mode {
	case .LINEAR:
		p_config.scale_mode = .LINEAR
	case .NEAREST:
		p_config.scale_mode = .NEAREST
	case .PIXELART:
		p_config.scale_mode = .PIXELART
	case:
		p_config.scale_mode = .LINEAR

	}

	// set allocator
	p_config._allocator = allocator

	return p_config
}

platform_config_destroy :: proc(platform_config: ^PlatformConfig) {
	allocator := platform_config._allocator
	delete(platform_config.title)
	delete(platform_config.org)
	delete(platform_config.app)
	free(platform_config, allocator)
}


init :: proc(config: engine.PlatformConfig) {
	// parse config
	platform_config = platform_config_new(config)

	init_logger(platform_config.logging_level)

	if (!sdl.Init(sdl.INIT_VIDEO | sdl.INIT_AUDIO | sdl.INIT_GAMEPAD)) {
		logger(.ERROR, "SDL could not be initialised: %s", sdl.GetError())
		panic("initialisation error: failed to initialise SDL")
	}

	// set window hints
	sdl.GL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, MAJOR)
	sdl.GL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, MINOR)
	sdl.GL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, i32(sdl.GL_CONTEXT_PROFILE_CORE))
	sdl.GL_SetAttribute(sdl.GL_DOUBLEBUFFER, 1)

	window = sdl.CreateWindow(
		platform_config.title,
		platform_config.window_width,
		platform_config.window_height,
		platform_config.flags,
	)
	if (window == nil) {
		logger(.ERROR, "SDL could not be initialised: %s", sdl.GetError())
		panic("initialisation error: failed to create window")
	}

	// blocks until window is set
	if !sdl.SyncWindow(window) {
		logger(.ERROR, "SDL failed to sync window: %s", sdl.GetError())
	}

	gl_context = sdl.GL_CreateContext(window)
	if gl_context == nil {
		logger(.ERROR, "SDL failed to create OpenGL Context")
		panic("SDL failed to create OpenGL Context")
	}
	logger(.DEBUG, "SDL Created OpenGL Context")

	if !sdl.GL_MakeCurrent(window, gl_context) {
		logger(.ERROR, "SDL failed to bind OpenGL Context to window: %s", sdl.GetError())
		panic("SDL failed to bind OpenGL Context to window")
	}

	// load function pointers
	gl.load_up_to(MAJOR, MINOR, sdl.gl_set_proc_address)
	if err := gl.GetError(); err != 0 {
		logger(.ERROR, "Failed to load function pointers, code: %d", err)
	}

	// vsync, should allow to customise later
	sdl.GL_SetSwapInterval(1)

	version := gl.GetString(gl.VERSION)
	logger(.DEBUG, "OpenGL Version: %s", version)

	// renderer
	renderer = renderer_init()

	// create placeholder texture
	create_placeholder_texture()

	// storage
	platform_storage_init()

	// audio
	audio_device = sdl.OpenAudioDevice(sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK, nil)
	if audio_device == 0 {
		logger(.ERROR, "Title storage could not be opened: %s", sdl.GetError())
		panic("initialisation error: failed to open audio device")
	}

	// fonts
	if !ttf.Init() {
		logger(.ERROR, "ttf failed to initialise: %s", sdl.GetError())
	}
	text_engine = ttf.CreateSurfaceTextEngine()

}

begin_frame :: proc() {}

end_frame :: proc() {
	if !sdl.GL_SwapWindow(window) {
		logger(.ERROR, "Failed to swap buffers")
	}
}

get_page_size :: proc() -> i32 {
	return sdl.GetSystemPageSize()
}


// deprecated
shader_create_info :: proc(shader_create_info: engine.ShaderCreateInfo) -> int {return -1}

// deprecated
set_gpu_fragment_shader_uniforms :: proc(
	shader: int,
	slot: u32,
	uniform: rawptr,
	uniform_length: u32,
) {
}

destroy_all_shaders :: proc() {}


push_shader_state :: proc(shader: int) {}

pop_shader_state :: proc() {}

clear_screen :: proc(color: engine.Color) {
	gl_color := engine_color_to_gl_color(color)
	gl.ClearColor(gl_color.r, gl_color.g, gl_color.b, gl_color.a)
	gl.Clear(gl.COLOR_BUFFER_BIT)
}

draw_circle :: proc(circle: engine.Circle, color: engine.Color) {}

draw_rect :: proc(rect: engine.Rect, color: engine.Color) {
	gl_color := engine_color_to_gl_color(color)

	renderer_push_vertex(
		renderer,
		{0, 0, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{0, 0},
	)
	renderer_push_vertex(
		renderer,
		{0, -1, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{0, 0},
	)
	renderer_push_vertex(
		renderer,
		{1, 0, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{0, 0},
	)
	renderer_push_vertex(
		renderer,
		{1, 0, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{0, 0},
	)
	renderer_push_vertex(
		renderer,
		{1, -1, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{0, 0},
	)
	renderer_push_vertex(
		renderer,
		{0, -1, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{0, 0},
	)
	defer renderer_clear_vertices(renderer)

	projection_location := gl.GetUniformLocation(
		renderer.shader_pipeline.vertex_shader,
		"vProjection",
	)
	if projection_location < 0 {
		logger(.ERROR, "Failed to find location")
		return
	}

	gl.BindTextureUnit(0, placeholder_texture.target)

	transformation := renderer_get_transformation_matrix(
		renderer^,
		rect.x,
		rect.y,
		rect.width,
		rect.height,
		1,
	)
	gl.ProgramUniformMatrix4fv(
		renderer.shader_pipeline.vertex_shader,
		projection_location,
		1,
		gl.FALSE,
		&transformation[0][0],
	)

	gl.BindVertexArray(renderer.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo)
	gl.BufferSubData(
		gl.ARRAY_BUFFER,
		0,
		renderer.vertices_count * size_of(RendererVertex),
		&renderer.vertices_data,
	)
	gl.DrawArrays(gl.TRIANGLES, 0, i32(renderer.vertices_count))
}

draw_rect_line :: proc(rect: engine.Rect, color: engine.Color) {

	gl_color := engine_color_to_gl_color(color)

	renderer_push_vertex(
		renderer,
		{0, 0, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{0, 0},
	)
	renderer_push_vertex(
		renderer,
		{0, -1, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{0, 0},
	)
	renderer_push_vertex(
		renderer,
		{1, -1, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{0, 0},
	)
	renderer_push_vertex(
		renderer,
		{1, 0, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{0, 0},
	)
	defer renderer_clear_vertices(renderer)

	projection_location := gl.GetUniformLocation(
		renderer.shader_pipeline.vertex_shader,
		"vProjection",
	)
	if projection_location < 0 {
		logger(.ERROR, "Failed to find location")
		return
	}
	gl.BindTextureUnit(0, placeholder_texture.target)

	transformation := renderer_get_transformation_matrix(
		renderer^,
		rect.x,
		rect.y,
		rect.width,
		rect.height,
		1,
	)
	gl.ProgramUniformMatrix4fv(
		renderer.shader_pipeline.vertex_shader,
		projection_location,
		1,
		gl.FALSE,
		&transformation[0][0],
	)

	gl.BindVertexArray(renderer.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo)
	gl.BufferSubData(
		gl.ARRAY_BUFFER,
		0,
		renderer.vertices_count * size_of(RendererVertex),
		&renderer.vertices_data,
	)

	// set to line mode then reset back to fill
	gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	defer gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)

	gl.DrawArrays(gl.LINE_LOOP, 0, i32(renderer.vertices_count))
}

draw_arc :: proc(
	center: engine.Vector2,
	radius, start_angle, end_angle, thickness: f32,
	color: engine.Color,
) {}

set_clip_rect :: proc(rect: engine.Rect) {}

end_clip_rect :: proc() {}

// NOTE: i added stretch_x and stretch_y so that you can flex and fit tiles together
// i.e. 9 slice fitting in the clay renderer. im not too sure if i like the
// interface of adding stretch as params vs something like sdl.RenderTextureRotated
// where you just provide src and dest rect. Lets see how annoying this is. STRETCH IS
// ALSO PRE SCALE STRETCH IN PIXELS.
draw_sprite :: proc(
	position: engine.Vector2,
	scale, rotation: f64,
	pivot: engine.Vector2,
	texture_handle: int,
	texture_rect: engine.Rect,
	color: engine.Color,
	flip_x, flip_y: bool,
	stretch_x, stretch_y: int,
) {
	gl_color := engine_color_to_gl_color(color)
	texture := textures[texture_handle]

	u0 := f32(texture_rect.x / f64(texture.width))
	v0 := f32(texture_rect.y / f64(texture.height))
	u1 := f32((texture_rect.x + texture_rect.width) / f64(texture.width))
	v1 := f32((texture_rect.y + texture_rect.height) / f64(texture.height))

	renderer_push_vertex(
		renderer,
		{0, 0, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{u0, v0},
	)
	renderer_push_vertex(
		renderer,
		{0, -1, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{u0, v1},
	)
	renderer_push_vertex(
		renderer,
		{1, 0, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{u1, v0},
	)
	renderer_push_vertex(
		renderer,
		{1, 0, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{u1, v0},
	)
	renderer_push_vertex(
		renderer,
		{1, -1, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{u1, v1},
	)
	renderer_push_vertex(
		renderer,
		{0, -1, 0, 1},
		{gl_color.r, gl_color.g, gl_color.b, gl_color.a},
		{u0, v1},
	)
	defer renderer_clear_vertices(renderer)

	projection_location := gl.GetUniformLocation(
		renderer.shader_pipeline.vertex_shader,
		"vProjection",
	)
	if projection_location < 0 {
		logger(.ERROR, "Failed to find location")
		return
	}

	gl.BindTextureUnit(0, texture.target)

	transformation := renderer_get_transformation_matrix(
		renderer^,
		position.x,
		position.y,
		texture_rect.width * scale,
		texture_rect.height * scale,
		1,
	)
	gl.ProgramUniformMatrix4fv(
		renderer.shader_pipeline.vertex_shader,
		projection_location,
		1,
		gl.FALSE,
		&transformation[0][0],
	)

	gl.BindVertexArray(renderer.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo)
	gl.BufferSubData(
		gl.ARRAY_BUFFER,
		0,
		renderer.vertices_count * size_of(RendererVertex),
		&renderer.vertices_data,
	)
	gl.DrawArrays(gl.TRIANGLES, 0, i32(renderer.vertices_count))

}

measure_text :: proc(font_handle: int, text: string) -> (width: int, height: int) {
	if font_handle < 0 || font_handle >= len(fonts) do return 0, 0
	w, h: c.int
	if !ttf.GetStringSize(fonts[font_handle], raw_data(text), len(text), &w, &h) {
		return 0, 0
	}
	return int(w), int(h)
}

draw_text :: proc(position: engine.Vector2, text: string, font_handle: int, color: engine.Color) {}


draw_debug_text :: proc(position: engine.Vector2, text: string, scale: f32, color: engine.Color) {}

attach_camera :: proc(cam: ^engine.Camera2D) {}

detach_camera :: proc() {}

get_performance_frequency :: proc() -> u64 {
	return sdl.GetPerformanceFrequency()
}

get_performance_counter :: proc() -> u64 {
	return sdl.GetPerformanceCounter()
}


// gets the file size in bytes of the file located at the specific path
// returns 0 when it cannot be retrived
get_file_size :: proc(path: cstring) -> int {
	outSize: u64
	if (!sdl.GetStorageFileSize(platform_storage.title, path, &outSize)) {
		logger(.ERROR, "failed to get file size: %s", sdl.GetError())
		return 0
	}
	return cast(int)outSize
}

// loads contents of the file into the user provided buffer
load_file :: proc(path: cstring, buffer: rawptr, size: int) -> bool {
	if (!sdl.ReadStorageFile(platform_storage.title, path, buffer, cast(u64)size)) {
		logger(.ERROR, "failed to read file at %s: %s", path, sdl.GetError())
		return false
	}
	return true
}

write_file :: proc(path: string, buffer: rawptr, size: int, storage: engine.Storage) -> bool {
	cpath := strings.clone_to_cstring(path, context.temp_allocator)

	// open and close writer
	ok := platform_storage_init_writer(storage)
	if !ok do return false
	defer platform_storage_destroy_writer()

	if !sdl.WriteStorageFile(platform_storage.writable, cpath, buffer, cast(u64)size) {
		logger(.ERROR, "failed to write file at %s: %s", cpath, sdl.GetError())
		return false
	}
	return true
}

// create_canvas creates a blank texture onto which you can render onto
// it will be destoryed at shutdown with destory_all_textures
create_canvas :: proc(width: int, height: int) -> int {return -1}


push_canvas :: proc(canvas: int) {}

pop_canvas :: proc() {}


create_placeholder_texture :: proc() {
	target: u32
	width: i32 = 1
	height: i32 = 1
	image := []u8{255, 255, 255, 255}
	gl.CreateTextures(gl.TEXTURE_2D, 1, &target)

	gl.TextureParameteri(target, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TextureParameteri(target, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	gl.TextureParameteri(target, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TextureParameteri(target, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	gl.TextureStorage2D(target, 1, gl.RGB8, i32(width), i32(height))
	gl.TextureSubImage2D(
		target,
		0,
		0,
		0,
		i32(width),
		i32(height),
		gl.RGBA,
		gl.UNSIGNED_BYTE,
		&image[0],
	)
	placeholder_texture = RendererTexture {
		target   = target,
		width    = int(width),
		height   = int(height),
		channels = 4,
		bpp      = 0,
	}
	logger(.DEBUG, "Created placeholder texture")
}


create_texture :: proc(width, height, channels, bpp: int, data: ^u32) -> int {
	target: u32
	gl.CreateTextures(gl.TEXTURE_2D, 1, &target)

	gl.TextureParameteri(target, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TextureParameteri(target, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	gl.TextureParameteri(target, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TextureParameteri(target, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	internal_format := (channels == 4 ? gl.RGBA8 : gl.RGB8)
	gl.TextureStorage2D(target, 1, u32(internal_format), i32(width), i32(height))
	gl.TextureSubImage2D(target, 0, 0, 0, i32(width), i32(height), gl.RGBA, gl.UNSIGNED_BYTE, data)
	logger(.DEBUG, "Texture created")
	gl.GenerateTextureMipmap(target)

	append(
		&textures,
		RendererTexture {
			target = target,
			channels = channels,
			bpp = bpp,
			width = width,
			height = height,
		},
	)
	return len(textures) - 1
}


/*
	 Destroys all textures, should always be called as a placeholder is created in the init procedure.
*/
destroy_all_textures :: proc() {
	gl.DeleteTextures(1, &placeholder_texture.target)
	for &texture in textures {
		gl.DeleteTextures(1, &texture.target)
	}
	delete(textures)
}

destroy_all_fonts :: proc() {}


shutdown :: proc() {

	logger(.DEBUG, "Shutting down...")
	if (gamepad != nil) {
		sdl.CloseGamepad(gamepad)
		gamepad = nil
	}

	// destory textures
	destroy_all_textures()

	// destory fonts
	destroy_all_fonts()


	// shutdown audio
	sdl.CloseAudioDevice(audio_device)

	// shutdown fonts
	ttf.DestroySurfaceTextEngine(text_engine)
	ttf.Quit()

	// platform
	platform_storage_destroy()
	platform_config_destroy(platform_config)

	// renderer
	renderer_destroy(renderer)

	// gl context
	sdl.GL_DestroyContext(gl_context)

	sdl.DestroyWindow(window)
	sdl.Quit()
}

// get_window_size returns the window size in pixles
get_window_size :: #force_inline proc() -> (int, int) {
	w, h: i32
	if (!sdl.GetWindowSizeInPixels(window, &w, &h)) {
		logger(.ERROR, "failed to get window size %s", sdl.GetError())
		return 0, 0
	}
	return int(w), int(h)
}

// get_render_size returns the pixels size of the renderer context
// note: should be the same as sdl.GetWindowSizeInPixels
get_render_size :: proc() -> (int, int) {
	return get_window_size()
}

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

// in between deadzone used to be == 0
input_set_state :: proc(input: ^engine.GameInput, type: engine.InputType, state: f64) {
	if (state > 0.0 + DEADZONE && in_between_deadzone(input.state[type])) {
		input.pressed[type] = true
	} else if (in_between_deadzone(state) && input.state[type] > 0.0) {
		input.released[type] = true
	}
	input.state[type] = state
}

set_deadzone :: proc(dz: f64) {
	assert(dz >= 0, "Deadzone must be positive")
	DEADZONE = dz
}

get_deadzone :: proc() -> f64 {
	return DEADZONE
}

in_between_deadzone :: proc(state: f64) -> bool {
	return state <= DEADZONE && state >= -DEADZONE
}

input_reset :: proc(input: ^engine.GameInput) {
	mem.set(&input.released, 0, size_of(input.released))
	mem.set(&input.pressed, 0, size_of(input.released))
	text_buffer_len = 0
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
					logger(.ERROR, "SDL could not open gamepad: %s", sdl.GetError())
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
			n := len(evt.text.text)
			if text_buffer_len + n <= len(text_buffer) {
				fmt.bprint(text_buffer[text_buffer_len:], evt.text.text)
				text_buffer_len += n
			}}

	}
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
		logger(.ERROR, "SDL failed to rumble gamepad: %s", sdl.GetError())
	}
}

// audio
load_sound :: proc(
	data: ^u8,
	length: int,
	format, channels, freq: ^int,
	out_buffer: ^[^]u8,
	out_length: ^u32,
) -> bool {

	spec: sdl.AudioSpec
	io: ^sdl.IOStream = sdl.IOFromMem(data, uint(length))
	if (!sdl.LoadWAV_IO(io, true, &spec, out_buffer, out_length)) {
		logger(.ERROR, "SDL could not load wav data: %s", sdl.GetError())
		return false
	}

	format^ = int(spec.format)
	channels^ = int(spec.channels)
	freq^ = int(spec.freq)

	return true
}

free_mem :: proc(mem: rawptr) {
	sdl.free(mem)
}

destroy_all_sounds :: proc() {
	for s in 0 ..< stream_count {
		sdl.DestroyAudioStream(streams[s])
	}
	stream_count = 0
}

@(private)
get_stream_handle :: proc(handle: int) -> ^sdl.AudioStream {
	if handle < 0 || handle > MAX_CONCURRENT_AUDIO_STREAMS - 1 do return nil
	return streams[handle]
}

pause_sound :: proc(handle: int) -> bool {
	stream := get_stream_handle(handle)
	if stream == nil {
		return false
	}
	return sdl.PauseAudioStreamDevice(stream)
}

resume_sound :: proc(handle: int) -> bool {
	stream := get_stream_handle(handle)
	if stream == nil {
		return false
	}
	return sdl.ResumeAudioStreamDevice(stream)
}

set_sound_volume :: proc(handle: int, volume: f64) -> bool {
	stream := get_stream_handle(handle)
	if stream == nil {
		return false
	}
	return sdl.SetAudioStreamGain(stream, f32(volume))
}

@(private)
create_and_bind_stream :: proc(spec: ^sdl.AudioSpec) -> ^sdl.AudioStream {
	if (stream_count >= MAX_CONCURRENT_AUDIO_STREAMS) {
		logger(.ERROR, "SDL could not play sound: all audio streams in use")
		return nil
	}

	new_stream := sdl.CreateAudioStream(spec, nil)
	if new_stream == nil {
		logger(.ERROR, "SDL could not create new stream: %s", sdl.GetError())
		return nil
	}

	if !sdl.BindAudioStream(audio_device, new_stream) {
		logger(.ERROR, "SDL could not create new stream: %s", sdl.GetError())
		return nil
	}
	return new_stream
}

// set existing audio stream
set_audio_stream :: proc(stream: ^sdl.AudioStream, data: rawptr, length: int, volume: f64) {
	if !sdl.SetAudioStreamGain(stream, f32(volume)) {
		logger(.ERROR, "SDL could not set audio stream grain: %s", sdl.GetError())
	}
	if !sdl.PutAudioStreamData(stream, data, i32(length)) {
		logger(.ERROR, "SDL could not put audio stream data: %s", sdl.GetError())
	}
}


play_sound :: proc(format, channels, freq: int, data: ^u8, length: int, volume: f64) -> int {
	spec: sdl.AudioSpec = {
		format   = sdl.AudioFormat(format),
		channels = i32(channels),
		freq     = i32(freq),
	}

	free_stream: ^sdl.AudioStream
	handle := -1

	for i in 0 ..< stream_count {
		stream := streams[i]
		if (stream != nil && sdl.GetAudioStreamAvailable(stream) == 0) {
			stream_spec: sdl.AudioSpec
			sdl.GetAudioStreamFormat(stream, &stream_spec, nil)
			if stream_spec == spec {
				free_stream = stream
				handle = i
				break
			}
		}
	}

	new_stream: ^sdl.AudioStream
	if free_stream != nil {
		new_stream = free_stream
	} else {
		new_stream = create_and_bind_stream(&spec)
		if new_stream == nil {
			return -1
		}

		streams[stream_count] = new_stream
		handle = stream_count
		stream_count += 1
	}
	set_audio_stream(new_stream, data, length, volume)
	return handle
}

is_sound_playing :: proc(handle: int) -> bool {
	if (handle < 0) {
		return false
	}

	stream: ^sdl.AudioStream = streams[handle]
	if (stream == nil) {
		return false
	}

	return sdl.GetAudioStreamAvailable(stream) != 0
}

// fonts
load_font :: proc(path: string, size: f32) -> int {
	cpath := strings.clone_to_cstring(path)
	defer delete(cpath)
	font := ttf.OpenFont(cpath, size)
	if font == nil {
		logger(.ERROR, "SDL could not load font: %s", sdl.GetError())
		return -1
	}
	append(&fonts, font)
	return len(fonts) - 1
}

@(private)
camera_translation_position :: proc(x, y, scale: f64) -> (f64, f64, f64) {
	if render_cam == nil do return x, y, scale
	pos := engine.camera_world_to_screen(render_cam, engine.vector2(x, y))
	// NOTE: position needs to be rounded to nearest int otherwise
	// we have sub pixel rendering of textures -> little gaps/flashing
	return math.round(pos.x), math.round(pos.y), render_cam.zoom * scale
}


// TODO: platform logger wrapper
// should wrap the sdl logger so that all logging is
// consistent

/*
   Platform Logger
*/


// text input
start_text_input :: proc() {}

stop_text_input :: proc() {}

get_text_input_buffer :: proc() -> ([64]u8, int) {
	return text_buffer, text_buffer_len
}

// Platform Storage
platform_storage_init :: proc() {
	platform_storage = new(PlatformStorage, context.allocator)
	platform_storage.title = sdl.OpenTitleStorage(nil, 0)
	if (platform_storage.title == nil) {
		logger(.ERROR, "Title storage could not be opened: %s", sdl.GetError())
		panic("initialisation error: failed to open title storage")
	}
	for !sdl.StorageReady(platform_storage.title) do sdl.Delay(1)
}


platform_storage_destroy :: proc() {
	ok := sdl.CloseStorage(platform_storage.title)
	if !ok {
		logger(.ERROR, "failed to close storage %s", sdl.GetError())
	}
	platform_storage_destroy_writer()
	free(platform_storage)
}


platform_storage_init_writer :: proc(storage: engine.Storage) -> bool {
	ensure(platform_config.org != nil)
	ensure(platform_config.app != nil)

	switch storage {
	case .FILE:
		platform_storage.writable = sdl.OpenFileStorage(".")
	case .USER:
		platform_storage.writable = sdl.OpenUserStorage(
			platform_config.org,
			platform_config.app,
			0,
		)
	}
	if (platform_storage.writable == nil) {
		logger(.ERROR, "Writing storage could not be opened: %s", sdl.GetError())
		return false
	}
	for !sdl.StorageReady(platform_storage.writable) do sdl.Delay(1)
	return true
}

platform_storage_destroy_writer :: proc() {
	if platform_storage.writable == nil do return
	ok2 := sdl.CloseStorage(platform_storage.writable)
	if (!ok2) {
		logger(.ERROR, "failed to close storage %s", sdl.GetError())
	}
	platform_storage.writable = nil
}

@(private)
priorities_to_sdl :: proc(level: engine.LoggerLevels) -> sdl.LogPriority {
	#partial switch level {
	case .TRACE:
		return sdl.LogPriority.TRACE
	case .VERBOSE:
		return sdl.LogPriority.VERBOSE
	case .DEBUG:
		return sdl.LogPriority.DEBUG
	case .INFO:
		return sdl.LogPriority.INFO
	case .WARN:
		return sdl.LogPriority.WARN
	case .ERROR:
		return sdl.LogPriority.ERROR
	case .CRITICAL:
		return sdl.LogPriority.CRITICAL
	case:
		return sdl.LogPriority.INVALID
	}
}

// -- Logger -- //

// load shaders
basic_vert_src := #load("../../../shaders/basic.vert.glsl")
basic_frag_src := #load("../../../shaders/basic.frag.glsl")

init_logger :: proc(level: engine.LoggerLevels) {
	sdl.SetLogPriorities(priorities_to_sdl(level))
}

logger :: proc(level: engine.LoggerLevels, msg: string, args: ..any) {
	cmessage := fmt.ctprintf(msg, ..args)
	sdl.LogMessage(cast(i32)sdl.LogCategory.CUSTOM, priorities_to_sdl(level), cmessage)
}

@(private)
GLColor :: struct {
	r, g, b, a: f32,
}

@(private)
engine_color_to_gl_color :: #force_inline proc(color: engine.Color) -> GLColor {
	return GLColor {
		r = f32(color.r) / f32(255),
		g = f32(color.g) / f32(255),
		b = f32(color.b) / f32(255),
		a = f32(color.a) / f32(255),
	}
}

// -- Renderer -- //

MAX_TRIANGLES :: 1048
MAX_VERTICES :: MAX_TRIANGLES * 3

RendererTexture :: struct {
	target:   u32,
	width:    int,
	height:   int,
	channels: int,
	bpp:      int,
}

RendererVertex :: struct {
	position: glsl.vec4,
	color:    glsl.vec4,
	uv:       glsl.vec2,
}

ShaderPipeline :: struct {
	pipeline:        u32,
	vertex_shader:   u32,
	fragment_shader: u32,
}

Renderer :: struct {
	vao:             u32,
	vbo:             u32,
	shader_pipeline: ShaderPipeline,
	projection:      glsl.mat4,
	vertices_data:   [MAX_VERTICES]RendererVertex,
	vertices_count:  int,
}

renderer_init :: proc() -> ^Renderer {

	// create renderer
	r := new(Renderer)

	// create vertex array buffer
	gl.CreateVertexArrays(1, &r.vao)

	// create vertex buffer object
	gl.CreateBuffers(1, &r.vbo)
	gl.NamedBufferStorage(
		r.vbo,
		size_of(RendererVertex) * MAX_VERTICES,
		nil,
		gl.DYNAMIC_STORAGE_BIT,
	)

	// bind vertex buffer object to vertex array
	gl.VertexArrayVertexBuffer(r.vao, 0, r.vbo, 0, size_of(RendererVertex))


	// enable vertex
	gl.EnableVertexArrayAttrib(r.vao, 0)
	gl.EnableVertexArrayAttrib(r.vao, 1)
	gl.EnableVertexArrayAttrib(r.vao, 2)


	// position attribute
	gl.VertexArrayAttribFormat(
		r.vao,
		0,
		4,
		gl.FLOAT,
		gl.FALSE,
		cast(u32)offset_of(RendererVertex, position),
	)

	// color attribute
	gl.VertexArrayAttribFormat(
		r.vao,
		1,
		4,
		gl.FLOAT,
		gl.FALSE,
		cast(u32)offset_of(RendererVertex, color),
	)

	// uv attribute
	gl.VertexArrayAttribFormat(
		r.vao,
		2,
		2,
		gl.FLOAT,
		gl.FALSE,
		cast(u32)offset_of(RendererVertex, uv),
	)

	// bind vertex attributes
	gl.VertexArrayAttribBinding(r.vao, 0, 0)
	gl.VertexArrayAttribBinding(r.vao, 1, 0)
	gl.VertexArrayAttribBinding(r.vao, 2, 0)

	// NOTE: this might bite me
	w, h := get_window_size()
	r.projection = glsl.mat4Ortho3d(0, f32(w), f32(h), 0, -1, 1)

	// create shader program
	vert_src := cstring(&basic_vert_src[0])
	r.shader_pipeline.vertex_shader = gl.CreateShaderProgramv(gl.VERTEX_SHADER, 1, &vert_src)

	frag_src := cstring(&basic_frag_src[0])
	r.shader_pipeline.fragment_shader = gl.CreateShaderProgramv(gl.FRAGMENT_SHADER, 1, &frag_src)

	gl.CreateProgramPipelines(1, &r.shader_pipeline.pipeline)

	gl.UseProgramStages(
		r.shader_pipeline.pipeline,
		gl.VERTEX_SHADER_BIT,
		r.shader_pipeline.vertex_shader,
	)
	gl.UseProgramStages(
		r.shader_pipeline.pipeline,
		gl.FRAGMENT_SHADER_BIT,
		r.shader_pipeline.fragment_shader,
	)

	gl.BindProgramPipeline(r.shader_pipeline.pipeline)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	return r
}

renderer_push_vertex :: proc(r: ^Renderer, position: glsl.vec4, color: glsl.vec4, uv: glsl.vec2) {
	count := r.vertices_count
	renderer.vertices_data[count].position = position
	renderer.vertices_data[count].color = color
	renderer.vertices_data[count].uv = uv
	r.vertices_count += 1
}

renderer_get_transformation_matrix :: proc(
	r: Renderer,
	x, y, width, height, scale: f64,
) -> glsl.mat4 {
	translate := glsl.mat4Translate({f32(x), f32(y), 0})
	scale := glsl.mat4Scale({f32(width), f32(height), 1})
	return r.projection * translate * scale
}

renderer_clear_vertices :: proc(r: ^Renderer) {
	r.vertices_count = 0
}

renderer_destroy :: proc(renderer: ^Renderer) {
	gl.DeleteProgram(renderer.shader_pipeline.vertex_shader)
	gl.DeleteProgram(renderer.shader_pipeline.fragment_shader)
	gl.DeleteProgramPipelines(1, &renderer.shader_pipeline.pipeline)
	gl.DeleteVertexArrays(1, &renderer.vao)
	gl.DeleteBuffers(1, &renderer.vbo)
	free(renderer)
}
