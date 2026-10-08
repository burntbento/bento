package platform_opengl

import "bento:engine"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

// -- OPENGL Version -- //
MAJOR :: 4
MINOR :: 1

// -- Globals -- //
window: ^sdl.Window
gl_context: sdl.GLContext

w: int
h: int


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

	// shaders
	basic_shader_handle = load_shader_program(triangle_vert_src, triangle_frag_src)

	w, h = get_window_size()
	logger(.DEBUG, "window size w: %d h:%d", w, h)
	logger(.DEBUG, "platform opengl init complete...")
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


// -- DEPRECATED AREA -- //
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
