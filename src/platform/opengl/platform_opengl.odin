package platform_opengl

import "bento:engine"
import "core:c"
import "core:math"

import glm "core:math/linalg/glsl"
import "core:mem"
import "core:strings"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

// -- OPENGL Version -- //
MAJOR :: 4
MINOR :: 1

// -- Globals -- //
window: ^sdl.Window
platform_config: ^PlatformConfig
gl_context: sdl.GLContext

platform_storage: ^sdl.Storage

w: int
h: int

// audio
audio_device: sdl.AudioDeviceID
MAX_CONCURRENT_AUDIO_STREAMS :: 32
streams: [MAX_CONCURRENT_AUDIO_STREAMS]^sdl.AudioStream // array of audio streams
stream_count := 0 // current stream count, could also migrate to dynamic array

// -- Input -- //
gamepad: ^sdl.Gamepad
DEADZONE: f64

// -- Camera -- //
camera_2d: ^engine.Camera2D

// -- Shaders -- //
triangle_vert_src := #load("../../../shaders/triangle.vert.glsl")
triangle_frag_src := #load("../../../shaders/triangle.frag.glsl")

// main
init :: proc(config: engine.PlatformConfig) {

	platform_config = platform_config_new(config)

	// INFO: set log verbosiity, turn off in production, should we write somewhere?
	init_logger(.VERBOSE)

	// init glfw
	if !sdl.Init(sdl.INIT_VIDEO | sdl.INIT_AUDIO | sdl.INIT_GAMEPAD) {
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
		{.OPENGL, .HIGH_PIXEL_DENSITY},
	)
	if window == nil {
		panic("Failed to open GLFW window")
	}


	// blocks until window is set
	if !sdl.SyncWindow(window) {
		logger(.ERROR, "SDL failed to sync window: %s", sdl.GetError())
	}

	// create context
	gl_context = sdl.GL_CreateContext(window)
	sdl.GL_MakeCurrent(window, gl_context)

	// load function pointers
	gl.load_up_to(MAJOR, MINOR, sdl.gl_set_proc_address)

	// vsync, should allow to customise later
	sdl.GL_SetSwapInterval(1)

	// init shaders
	init_shaders()

	// storage
	platform_storage_init()

	// audio
	audio_device = sdl.OpenAudioDevice(sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK, nil)
	if (audio_device == 0) {
		logger(.ERROR, "Title storage could not be opened: %s", sdl.GetError())
		panic("initialisation error: failed to open audio device")
	}

	// textures
	init_textures()

	w, h = get_window_size()
	logger(.DEBUG, "window size w: %d h:%d", w, h)
	logger(.DEBUG, "platform opengl init complete...")
}

begin_frame :: proc() {}

end_frame :: proc() {
	sdl.GL_SwapWindow(window)
	gl.Flush()
}

shutdown :: proc() {


	// destroy platform stuff
	platform_config_destroy(platform_config)

	// storage
	platform_storage_destroy()

	// sound
	destroy_all_sounds()

	// shader
	destroy_all_shaders()

	// textures
	destroy_all_textures()

	// destroy sdl window
	sdl.DestroyWindow(window)

	// audio
	sdl.CloseAudioDevice(audio_device)

	// destroy gl context
	sdl.GL_DestroyContext(gl_context)

	// final termation
	sdl.Quit()
}

// files io
get_file_size :: proc(path: cstring) -> int {
	outSize: u64
	if (!sdl.GetStorageFileSize(platform_storage, path, &outSize)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"failed to get file size: %s",
			sdl.GetError(),
		)
		return 0
	}
	return cast(int)outSize
}

load_file :: proc(path: cstring, buffer: rawptr, size: int) -> bool {
	if (!sdl.ReadStorageFile(platform_storage, path, buffer, cast(u64)size)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"failed to read file at %s: %s",
			path,
			sdl.GetError(),
		)
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

	if !sdl.WriteStorageFile(platform_storage, cpath, buffer, cast(u64)size) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"failed to write file at %s: %s",
			cpath,
			sdl.GetError(),
		)
		return false
	}
	return true
}

// storage
platform_storage_init :: proc() {

	platform_storage = sdl.OpenTitleStorage(nil, 0)
	if (platform_storage == nil) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"Title storage could not be opened: %s",
			sdl.GetError(),
		)
		panic("initialisation error: failed to open title storage")
	}
	for !sdl.StorageReady(platform_storage) do sdl.Delay(1)
}

platform_storage_destroy :: proc() {
	ok := sdl.CloseStorage(platform_storage)
	if (!ok) {
		sdl.LogError(cast(i32)sdl.LogCategory.CUSTOM, "failed to close storage %s", sdl.GetError())
	}
}

platform_storage_init_writer :: proc(storage: engine.Storage) -> bool {
	return false
}

platform_storage_destroy_writer :: proc() {}

// textures / canvas
create_texture :: proc(width, height, channels, bpp: int, data: ^u32) -> int {

	tex: u32
	gl.GenTextures(1, &tex)
	gl.BindTexture(gl.TEXTURE_2D, tex)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RGBA,
		i32(width),
		i32(height),
		0,
		gl.RGBA,
		gl.UNSIGNED_BYTE,
		data,
	)
	gl.GenerateMipmap(gl.TEXTURE_2D)

	append(&Textures, tex)
	return len(Textures) - 1
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


get_window_size :: proc() -> (int, int) {
	w, h: i32
	sdl.GetWindowSizeInPixels(window, &w, &h)
	return int(w), int(h)
}

// get_render_size returns the pixels size of the renderer context
// note: should be the same as sdl.GetWindowSizeInPixels
get_render_size :: proc() -> (int, int) {
	w, h: i32
	if !sdl.GetWindowSizeInPixels(window, &w, &h) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"failed to get renderer size %s",
			sdl.GetError(),
		)
	}
	return int(w), int(h)
}

// drawing
clear_screen :: proc(color: engine.Color) {
	gl_color := engine_color_to_gl_color(color)
	gl.ClearColor(gl_color.r, gl_color.g, gl_color.b, gl_color.a)
	gl.Clear(gl.COLOR_BUFFER_BIT)
}

@(private)
camera_translation_position :: proc(x, y, scale: f64) -> (f64, f64, f64) {
	if camera_2d == nil do return x, y, scale
	pos := engine.camera_world_to_screen(camera_2d, engine.vector2(x, y))
	// NOTE: position needs to be rounded to nearest int otherwise
	// we have sub pixel rendering of textures -> little gaps/flashing
	return math.round(pos.x), math.round(pos.y), camera_2d.zoom * scale
}

draw_rect :: proc(rect: engine.Rect, color: engine.Color) {
	// just in case, i had w, h = 0 and i thought i was going crazy
	engine.assert_rect(rect)

	t_x, t_y, t_s := camera_translation_position(rect.x, rect.y, 1)

	vertices = {1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0}
	indicies = {0, 1, 3, 1, 2, 3}
	shader_bind_verticies(VBO, EBO, 3, 3)

	gl_color := engine_color_to_gl_color(color)
	v_color := gl.GetUniformLocation(shader_program, "vColor")
	if v_color == -1 {
		// log
		return
	}

	v_proj := gl.GetUniformLocation(shader_program, "v_proj")
	v_translation := gl.GetUniformLocation(shader_program, "v_translation")
	v_scale := gl.GetUniformLocation(shader_program, "v_scale")

	projection := glm.mat4Ortho3d(0, f32(w), f32(h), 0, -1, 1)
	translate := glm.mat4Translate({f32(t_x), f32(t_y), 0})
	scale := glm.mat4Scale({f32(rect.width * t_s), f32(rect.height * t_s), 1})

	gl.UseProgram(shader_program)

	gl.Uniform4f(v_color, gl_color.r, gl_color.g, gl_color.b, gl_color.a)

	gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)

	gl.UniformMatrix4fv(v_proj, 1, gl.FALSE, &projection[0][0])
	gl.UniformMatrix4fv(v_translation, 1, gl.FALSE, &translate[0][0])
	gl.UniformMatrix4fv(v_scale, 1, gl.FALSE, &scale[0][0])

	gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)
}

draw_rect_line :: proc(rect: engine.Rect, color: engine.Color) {
	// just in case, i had w, h = 0 and i thought i was going crazy
	engine.assert_rect(rect)

	t_x, t_y, t_s := camera_translation_position(rect.x, rect.y, 1)

	vertices = {1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0}
	indicies = {0, 1, 2, 3, 0, 0}
	shader_bind_verticies(VBO, EBO, 3, 3)

	gl_color := engine_color_to_gl_color(color)
	v_color := gl.GetUniformLocation(shader_program, "vColor")
	if v_color == -1 {
		// log
		return
	}
	v_proj := gl.GetUniformLocation(shader_program, "v_proj")
	v_translation := gl.GetUniformLocation(shader_program, "v_translation")
	v_scale := gl.GetUniformLocation(shader_program, "v_scale")

	projection := glm.mat4Ortho3d(0, f32(w), f32(h), 0, -1, 1)
	translate := glm.mat4Translate({f32(t_x), f32(t_y), 0})
	scale := glm.mat4Scale({f32(rect.width * t_s), f32(rect.height * t_s), 1})

	gl.UseProgram(shader_program)

	gl.Uniform4f(v_color, gl_color.r, gl_color.g, gl_color.b, gl_color.a)

	gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)

	gl.UniformMatrix4fv(v_proj, 1, gl.FALSE, &projection[0][0])
	gl.UniformMatrix4fv(v_translation, 1, gl.FALSE, &translate[0][0])
	gl.UniformMatrix4fv(v_scale, 1, gl.FALSE, &scale[0][0])

	gl.DrawElements(gl.LINE_LOOP, 4, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)
}

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
) {
	handle := Textures[texture_handle]

	t_x, t_y, t_s := camera_translation_position(position.x, position.y, 1)

	vertices = {1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0}
	indicies = {0, 1, 3, 1, 2, 3}
	shader_bind_verticies(VBO, EBO, 3, 3)

	gl_color := engine_color_to_gl_color(color)
	v_color := gl.GetUniformLocation(shader_program, "vColor")
	if v_color == -1 {
		// log
		return
	}

	v_proj := gl.GetUniformLocation(shader_program, "v_proj")
	v_translation := gl.GetUniformLocation(shader_program, "v_translation")
	v_scale := gl.GetUniformLocation(shader_program, "v_scale")

	projection := glm.mat4Ortho3d(0, f32(w), f32(h), 0, -1, 1)
	translate := glm.mat4Translate({f32(t_x), f32(t_y), 0})
	scale := glm.mat4Scale({f32(texture_rect.width * t_s), f32(texture_rect.height * t_s), 1})

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, handle)

	gl.UseProgram(shader_program)

	gl.Uniform4f(v_color, gl_color.r, gl_color.g, gl_color.b, gl_color.a)

	gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)

	gl.UniformMatrix4fv(v_proj, 1, gl.FALSE, &projection[0][0])
	gl.UniformMatrix4fv(v_translation, 1, gl.FALSE, &translate[0][0])
	gl.UniformMatrix4fv(v_scale, 1, gl.FALSE, &scale[0][0])

	gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)


}

set_clip_rect :: proc(rect: engine.Rect) {}

end_clip_rect :: proc() {}

attach_camera :: proc(cam: ^engine.Camera2D) {
	camera_2d = cam
}

detach_camera :: proc() {
	camera_2d = nil
}


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
// deprecated
shader_create_info :: proc(shader_create_info: engine.ShaderCreateInfo) -> int {
	return -1
}

// deprecated
set_gpu_fragment_shader_uniforms :: proc(
	shader: int,
	slot: u32,
	uniform: rawptr,
	uniform_length: u32,
) {}

// deprecated
push_shader_state :: proc(shader: int) {}

// deprecated
pop_shader_state :: proc() {}

// audio
destroy_all_sounds :: proc() {
	for s in 0 ..< stream_count {
		sdl.DestroyAudioStream(streams[s])
	}
	stream_count = 0
}

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
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not load wav data: %s",
			sdl.GetError(),
		)
		return false
	}

	format^ = int(spec.format)
	channels^ = int(spec.channels)
	freq^ = int(spec.freq)

	return true
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

@(private)
set_audio_stream :: proc(stream: ^sdl.AudioStream, data: rawptr, length: int, volume: f64) {
	if !sdl.SetAudioStreamGain(stream, f32(volume)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not set audio stream grain: %s",
			sdl.GetError(),
		)
	}
	if !sdl.PutAudioStreamData(stream, data, i32(length)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not put audio stream data: %s",
			sdl.GetError(),
		)
	}
}


@(private)
create_and_bind_stream :: proc(spec: ^sdl.AudioSpec) -> ^sdl.AudioStream {
	if (stream_count >= MAX_CONCURRENT_AUDIO_STREAMS) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not play sound: all audio streams in use",
		)
		return nil
	}

	new_stream := sdl.CreateAudioStream(spec, nil)
	if new_stream == nil {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not create new stream: %s",
			sdl.GetError(),
		)
		return nil
	}

	if !sdl.BindAudioStream(audio_device, new_stream) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not create new stream: %s",
			sdl.GetError(),
		)
		return nil
	}
	return new_stream
}


@(private)
get_stream_handle :: proc(handle: int) -> ^sdl.AudioStream {
	if handle < 0 || handle > MAX_CONCURRENT_AUDIO_STREAMS - 1 do return nil
	return streams[handle]
}

resume_sound :: proc(handle: int) -> bool {
	stream := get_stream_handle(handle)
	if stream == nil {
		return false
	}
	return sdl.ResumeAudioStreamDevice(stream)
}

pause_sound :: proc(handle: int) -> bool {
	stream := get_stream_handle(handle)
	if stream == nil {
		return false
	}
	return sdl.PauseAudioStreamDevice(stream)
}

set_sound_volume :: proc(handle: int, volume: f64) -> bool {
	stream := get_stream_handle(handle)
	if stream == nil {
		return false
	}
	return sdl.SetAudioStreamGain(stream, f32(volume))
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
					sdl.LogError(
						cast(i32)sdl.LogCategory.CUSTOM,
						"SDL could not open gamepad: %s",
						sdl.GetError(),
					)

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

			// NOTE: not implemented
		}
	}
}

input_set_state :: proc(input: ^engine.GameInput, type: engine.InputType, state: f64) {
	if (state > 0.0 + DEADZONE && in_between_deadzone(input.state[type])) {
		input.pressed[type] = true
	} else if (in_between_deadzone(state) && input.state[type] > 0.0) {
		input.released[type] = true
	}
	input.state[type] = state
}

input_reset :: proc(input: ^engine.GameInput) {
	mem.set(&input.released, 0, size_of(input.released))
	mem.set(&input.pressed, 0, size_of(input.released))
}

in_between_deadzone :: proc(state: f64) -> bool {
	return state <= DEADZONE && state >= -DEADZONE
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
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL failed to rumble gamepad: %s",
			sdl.GetError(),
		)
	}
}

set_deadzone :: proc(dz: f64) {
	ensure(dz >= 0, "Deadzone must be positive")
	DEADZONE = dz
}

get_deadzone :: proc() -> f64 {
	return DEADZONE
}

get_performance_frequency :: proc() -> u64 {
	return sdl.GetPerformanceFrequency()
}


get_performance_counter :: proc() -> u64 {
	return sdl.GetPerformanceCounter()
}


get_page_size :: proc() -> i32 {
	return sdl.GetSystemPageSize()
}

free_mem :: proc(mem: rawptr) {
	sdl.free(mem)
}


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
	return GLColor {
		r = f32(color.r / 255),
		g = f32(color.g / 255),
		b = f32(color.b / 255),
		a = f32(color.a / 255),
	}
}


// -- OpenGL -- //

shader_program: u32
vertex_shader: u32
frag_shader: u32

vertices: [12]f32
indicies: [6]u32

gl_texture: u32

VAO, VBO, EBO: u32

@(private)
init_shaders :: proc() {

	// NOTE: Should error check
	vex_src := cstring(&triangle_vert_src[0])
	vertex_shader = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, &vex_src, nil)
	gl.CompileShader(vertex_shader)

	frag_src := cstring(&triangle_frag_src[0])
	frag_shader = gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(frag_shader, 1, &frag_src, nil)
	gl.CompileShader(frag_shader)

	shader_program = gl.CreateProgram()

	gl.AttachShader(shader_program, vertex_shader)
	gl.AttachShader(shader_program, frag_shader)
	gl.LinkProgram(shader_program)


	// vertex array
	gl.GenVertexArrays(1, &VAO)

	// vertex buffer
	gl.GenBuffers(1, &VBO)

	// element buffer
	gl.GenBuffers(1, &EBO)

	// texture
	gl.GenTextures(1, &gl_texture)
}

shader_bind_verticies :: proc(vbo: u32, ebo: u32, size: int, stride: int) {

	// bind
	gl.BindVertexArray(VAO)

	// copy vertices for opengl to use
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), rawptr(&vertices), gl.STATIC_DRAW)

	// bind elements
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indicies), rawptr(&indicies), gl.STATIC_DRAW)

	// vertex attributes

	// position
	gl.VertexAttribPointer(0, i32(size), gl.FLOAT, gl.FALSE, i32(stride) * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)
}

destroy_all_shaders :: proc() {

	gl.DeleteBuffers(1, &VBO)
	gl.DeleteBuffers(1, &EBO)
	gl.DeleteVertexArrays(1, &VAO)
	gl.DeleteTextures(1, &gl_texture)

	gl.DeleteProgram(shader_program)
	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(frag_shader)
}
