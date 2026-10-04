package platform

import "bento:engine"
import "core:c"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

// TODO:
// - clean and organise this file

// WARNING: the u8 color APIs (SetRenderDrawColor, SetTextureColorMod) render
// incorrectly on SDL3 here, use the f32 variants.
// sdl.ScaleMode.NEAREST has been set to PIXELART, might want to switch back after


/*
   NOTE:
   The issue with platform storage is that i want a file storage for editing and saving game artifacts e.g. levels
   but we also need a user storage for all user data at some point. This is a abstraction over storage containers
   for os's and steam cloud storage. The game layer should be able to choose which storage to use. But write file
   will be shared between user and file storage.
*/


/*
   **Platform Storage**

   see: https://wiki.libsdl.org/SDL3/CategoryStorage

   Many platforms like game platforms do not have a monolithic file storage. They are more strict with what type of filesystem is being accessed; for example, game content and user data are two different storage devices with different characteristics. They also may not all be writeable or accessable directly.

   note: https://partner.steamgames.com/doc/features/cloud
*/
PlatformStorage :: struct {
	title:    ^sdl.Storage,
	writable: ^sdl.Storage,
}

/*
   Globals

   All global variables for platform layer should live in this block with a short description of what it is.
*/

window: ^sdl.Window // sdl window
renderer: ^sdl.Renderer // sdl renderer

platform_config: ^PlatformConfig // config

// gpu
device: ^sdl.GPUDevice
formats: sdl.GPUShaderFormat

ShaderData :: struct {
	shader: ^sdl.GPUShader,
	state:  ^sdl.GPURenderState,
}

MAX_SHADER_INFO :: 32
shader_info: [MAX_SHADER_INFO]^ShaderData
shader_info_count: int


gamepad: ^sdl.Gamepad // for gamepad
platform_storage: ^PlatformStorage // sdl platform_storage interface
audio_device: sdl.AudioDeviceID // sdl audio device
render_cam: ^engine.Camera2D // sdl renderer
world_texture: int // sdl world texture for scaling and transforming world

current_canvas: ^sdl.Texture

text_buffer: [64]u8 // text buffer for text input not key input
text_buffer_len: int // text buffer length

MAX_CONCURRENT_AUDIO_STREAMS :: 32
PLACEHOLDER_TEXTURE_HANDLE :: -1

placeholder_texture: ^sdl.Texture // pointer for placeholder texture
textures: [dynamic]^sdl.Texture // dynamic array of textures
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

	flags: sdl.WindowFlags = {.HIGH_PIXEL_DENSITY}
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


/*
   Platform initialisation procedure. It should initialise anything platorm related at startup. This includes window, renderer, audio and input etc. Anything initialised here should be paired with a equivalent destroy proc in `destory`.
*/
init :: proc(config: engine.PlatformConfig) {
	// parse config
	platform_config = platform_config_new(config)

	// INFO: set log verbosiity, turn off in production, should we write somewhere?
	sdl.SetLogPriorities(.VERBOSE)

	if (!sdl.Init(sdl.INIT_VIDEO | sdl.INIT_AUDIO | sdl.INIT_GAMEPAD)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not be initialised: %s",
			sdl.GetError(),
		)
		panic("initialisation error: failed to initialise SDL")
	}

	window = sdl.CreateWindow(
		platform_config.title,
		platform_config.window_width,
		platform_config.window_height,
		platform_config.flags,
	)
	if (window == nil) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not be initialised: %s",
			sdl.GetError(),
		)
		panic("initialisation error: failed to create window")
	}

	// blocks until window is set
	if !sdl.SyncWindow(window) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL failed to sync window: %s",
			sdl.GetError(),
		)
	}

	// changed render backend to gpu, might want to change back to nil for default choosing
	renderer = sdl.CreateRenderer(window, "gpu")
	if (renderer == nil) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not be initialised: %s",
			sdl.GetError(),
		)
		panic("initialisation error: failed to create renderer")

	}

	sdl.SetRenderVSync(renderer, 1)

	// set gpu driver formats - vulkan, metal and dx11
	// basically linux/other, mac and windows
	formats = {.SPIRV, .MSL, .DXIL}
	device = sdl.CreateGPUDevice(formats, true, nil)
	if device == nil {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not be initialised: %s",
			sdl.GetError(),
		)
		panic("initialisation error: failed to create gpu device")
	}

	formats = sdl.GetGPUShaderFormats(device)

	sdl.LogDebug(
		cast(i32)sdl.LogCategory.CUSTOM,
		"Setting scale mode to %d",
		platform_config.scale_mode,
	)
	if !sdl.SetDefaultTextureScaleMode(renderer, platform_config.scale_mode) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL failed to set texture mode to nearest: %s",
			sdl.GetError(),
		)
	}


	// storage
	platform_storage_init()

	// textures
	create_placeholder_texture()
	textures = make([dynamic]^sdl.Texture, 0, 64)

	w, h := get_window_size()
	world_texture = create_canvas(w, h)

	// audio
	audio_device = sdl.OpenAudioDevice(sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK, nil)
	if (audio_device == 0) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"Title storage could not be opened: %s",
			sdl.GetError(),
		)
		panic("initialisation error: failed to open audio device")
	}

	// fonts
	if !ttf.Init() {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"ttf failed to initialise: %s",
			sdl.GetError(),
		)
	}
	fonts = make([dynamic]^ttf.Font, 0, 64)
	text_engine = ttf.CreateRendererTextEngine(renderer)

}

begin_frame :: proc() {}

end_frame :: proc() {
	if (!sdl.RenderPresent(renderer)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL render present failed: %s",
			sdl.GetError(),
		)
	}
}

get_page_size :: proc() -> i32 {
	return sdl.GetSystemPageSize()
}

@(private)
shader_select_format :: proc(formats: sdl.GPUShaderFormat) -> sdl.GPUShaderFormat {
	if .SPIRV in formats {
		return {.SPIRV}
	}
	if .DXIL in formats {
		return {.DXIL}
	}
	if .MSL in formats {
		return {.MSL}
	}
	return {}
}


shader_create_info :: proc(shader_create_info: engine.ShaderCreateInfo) -> int {
	if shader_info_count > MAX_SHADER_INFO {
		return -1
	}

	stage: sdl.GPUShaderStage
	switch shader_create_info.stage {
	case .VERTEX:
		stage = sdl.GPUShaderStage.VERTEX
	case .FRAGMENT:
		stage = sdl.GPUShaderStage.FRAGMENT
	}

	info_format := shader_select_format(formats)

	code_size: uint
	code: [^]u8
	c_entry_point: cstring
	switch info_format {
	case {.SPIRV}:
		code_size = shader_create_info.data.spirv.code_size
		code = shader_create_info.data.spirv.code
		c_entry_point = strings.clone_to_cstring(shader_create_info.data.spirv.entry_point)
	case {.DXIL}:
		code_size = shader_create_info.data.dxil.code_size
		code = shader_create_info.data.dxil.code
		c_entry_point = strings.clone_to_cstring(shader_create_info.data.dxil.entry_point)
	case {.MSL}:
		code_size = shader_create_info.data.msl.code_size
		code = shader_create_info.data.msl.code
		c_entry_point = strings.clone_to_cstring(shader_create_info.data.msl.entry_point)
	case {}:
		return -1
	}
	defer delete(c_entry_point)

	info := sdl.GPUShaderCreateInfo {
		code_size           = code_size,
		code                = code,
		entrypoint          = c_entry_point,
		format              = info_format,
		stage               = stage,
		num_samplers        = shader_create_info.num_samplers,
		num_storage_buffers = shader_create_info.num_storage_buffers,
		num_uniform_buffers = shader_create_info.num_uniform_buffers,
		props               = 0,
	}

	shader := sdl.CreateGPUShader(device, info)

	render_state_create: sdl.GPURenderStateCreateInfo
	render_state_create.fragment_shader = shader

	state := sdl.CreateGPURenderState(renderer, render_state_create)

	shader_data := new(ShaderData, context.allocator)
	shader_data.shader = shader
	shader_data.state = state

	shader_info[shader_info_count] = shader_data
	shader_info_count += 1
	return shader_info_count
}

set_gpu_fragment_shader_uniforms :: proc(
	shader: int,
	slot: u32,
	uniform: rawptr,
	uniform_length: u32,
) {
	if shader > shader_info_count {
		return
	}
	data := shader_info[shader - 1]
	if !sdl.SetGPURenderStateFragmentUniforms(data.state, slot, uniform, uniform_length) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL render failed to set fragment uniform: %s",
			sdl.GetError(),
		)
	}
}

destroy_all_shaders :: proc() {
	for s in shader_info {
		if s == nil do continue
		sdl.DestroyGPURenderState(s.state)
		sdl.ReleaseGPUShader(device, s.shader)
		free(s)
	}
}


// i want to be able to push and pop multiple shaders at once
// i was thinking of a stack data structure and the top shader is
// the current and when you pop you get the next one below it. Allowing the
// shader state to continue. The issue is now that if you push a shader in the
// middle it will wipe shader state going ahead.
push_shader_state :: proc(shader: int) {
	if shader > shader_info_count {
		return
	}
	handle := shader_info[shader - 1]
	if !sdl.SetGPURenderState(renderer, handle.state) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL push render shader state failed: %s",
			sdl.GetError(),
		)
	}
}

pop_shader_state :: proc() {
	if !sdl.SetGPURenderState(renderer, nil) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL pop render shader state failed: %s",
			sdl.GetError(),
		)
	}
}

clear_screen :: proc(color: engine.Color) {
	if (!sdl.SetRenderDrawColorFloat(
			   renderer,
			   f32(color.r) / 255.0,
			   f32(color.g) / 255.0,
			   f32(color.b) / 255.0,
			   f32(color.a) / 255.0,
		   )) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL set render draw color failed: %s",
			sdl.GetError(),
		)
		return
	}
	if (!sdl.RenderClear(renderer)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL render clear failed: %s",
			sdl.GetError(),
		)
	}
}

draw_circle :: proc(circle: engine.Circle, color: engine.Color) {
	center_x, center_y, trans_scale := camera_translation_position(
		circle.position.x,
		circle.position.y,
		1.0,
	)

	cx := f32(center_x)
	cy := f32(center_y)
	radius := circle.radius * trans_scale

	verts: [NUM_CIRCLE_SEGMENTS + 1]sdl.Vertex
	indices: [NUM_CIRCLE_SEGMENTS * 3]i32

	fcolor := sdl.FColor {
		f32(color.r) / 255.0,
		f32(color.g) / 255.0,
		f32(color.b) / 255.0,
		f32(color.a) / 255.0,
	}

	verts[0].position = sdl.FPoint{cx, cy}
	verts[0].color = fcolor

	for i in 0 ..< NUM_CIRCLE_SEGMENTS {
		angle := f32(i) / NUM_CIRCLE_SEGMENTS * 2 * math.PI
		verts[i + 1].position = sdl.FPoint {
			cx + math.cos(angle) * f32(radius),
			cy + math.sin(angle) * f32(radius),
		}
		verts[i + 1].color = fcolor

		indices[i * 3 + 0] = 0
		indices[i * 3 + 1] = i32(i + 1)
		indices[i * 3 + 2] = i32((i + 1) % NUM_CIRCLE_SEGMENTS + 1)
	}

	sdl.RenderGeometry(
		renderer,
		nil,
		raw_data(verts[:]),
		NUM_CIRCLE_SEGMENTS + 1,
		raw_data(indices[:]),
		NUM_CIRCLE_SEGMENTS * 3,
	)
}

draw_rect :: proc(rect: engine.Rect, color: engine.Color) {

	trans_x, trans_y, trans_scale := camera_translation_position(rect.x, rect.y, 1.0)

	square := sdl.FRect {
		x = f32(trans_x),
		y = f32(trans_y),
		w = f32(rect.width * trans_scale),
		h = f32(rect.height * trans_scale),
	}
	set_renderer_draw_color(renderer, color.r, color.g, color.b, color.a)
	sdl.RenderFillRect(renderer, &square)
}

draw_rect_line :: proc(rect: engine.Rect, color: engine.Color) {

	trans_x, trans_y, trans_scale := camera_translation_position(rect.x, rect.y, 1.0)

	square := sdl.FRect {
		x = f32(trans_x),
		y = f32(trans_y),
		w = f32(rect.width * trans_scale),
		h = f32(rect.height * trans_scale),
	}
	set_renderer_draw_color(renderer, color.r, color.g, color.b, color.a)
	sdl.RenderRect(renderer, &square)
}

draw_arc :: proc(
	center: engine.Vector2,
	radius, start_angle, end_angle, thickness: f32,
	color: engine.Color,
) {

	@(static) buffer: [255]sdl.FPoint

	set_renderer_draw_color(renderer, color.r, color.g, color.b, color.a)

	trans_x, trans_y, _ := camera_translation_position(center.x, center.y, 1.0)

	rad_start := start_angle * (math.PI / 180.0)
	rad_end := end_angle * (math.PI / 180.0)

	n_circle_segments := math.max(NUM_CIRCLE_SEGMENTS, int(radius * 1.5))
	assert(n_circle_segments < 255)

	angle_step := (rad_end - rad_start) / f32(n_circle_segments)
	thickness_step: f32 = 0.4

	for t := thickness_step; t < thickness - thickness_step; t += thickness_step {
		points: [^]sdl.FPoint = &buffer[0]
		clamped_radius := math.max(radius - t, 1.0)

		for i := 0; i <= int(n_circle_segments); i += 1 {
			angle := rad_start + f32(i) * angle_step
			points[i] = sdl.FPoint {
				f32(sdl.round(trans_x)) + sdl.cosf(angle) * clamped_radius,
				f32(sdl.round(trans_y)) + sdl.sinf(angle) * clamped_radius,
			}

		}
		sdl.RenderLines(renderer, points, c.int(n_circle_segments + 1))
	}
}

set_clip_rect :: proc(rect: engine.Rect) {
	trans_x, trans_y, trans_scale := camera_translation_position(rect.x, rect.y, 1.0)
	clipping_rect := sdl.Rect {
		x = c.int(trans_x),
		y = c.int(trans_y),
		w = c.int(rect.width * trans_scale),
		h = c.int(rect.height * trans_scale),
	}
	sdl.SetRenderClipRect(renderer, &clipping_rect)
}

end_clip_rect :: proc() {
	sdl.SetRenderClipRect(renderer, nil)
}

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
	texture: ^sdl.Texture
	if (texture_handle != PLACEHOLDER_TEXTURE_HANDLE) {
		if texture_handle > len(textures) - 1 {
			sdl.LogError(
				cast(i32)sdl.LogCategory.CUSTOM,
				"proc draw_sprite tried to index > len(textures): index: %d, len: %d",
				texture_handle,
				len(textures),
			)
			return
		}
		texture = textures[texture_handle]
		sdl.SetTextureColorModFloat(
			texture,
			f32(color.r) / 255.0,
			f32(color.g) / 255.0,
			f32(color.b) / 255.0,
		)
		sdl.SetTextureAlphaModFloat(texture, f32(color.a) / 255.0)
	} else {
		texture = placeholder_texture
	}


	flip := sdl.FlipMode.NONE
	if flip_x do flip |= sdl.FlipMode.HORIZONTAL
	if flip_y do flip |= sdl.FlipMode.VERTICAL

	// translate camera position
	// keeping x, y and zoom translation on the sprite layer
	// rotation will be done on the world texture
	trans_x, trans_y, trans_scale := camera_translation_position(position.x, position.y, scale)

	sdl.RenderTextureRotated(
		renderer,
		texture,
		&sdl.FRect {
			x = f32(texture_rect.x),
			y = f32(texture_rect.y),
			w = f32(texture_rect.width),
			h = f32(texture_rect.height),
		},
		&sdl.FRect {
			x = f32(trans_x - texture_rect.width * trans_scale * pivot.x),
			y = f32(trans_y - texture_rect.height * trans_scale * pivot.y),
			w = f32((texture_rect.width + f64(stretch_x)) * trans_scale),
			h = f32((texture_rect.height + f64(stretch_y)) * trans_scale),
		},
		f64(rotation),
		nil,
		flip,
	)

}

measure_text :: proc(font_handle: int, text: string) -> (width: int, height: int) {
	if font_handle < 0 || font_handle >= len(fonts) do return 0, 0
	w, h: c.int
	if !ttf.GetStringSize(fonts[font_handle], cstring(raw_data(text)), len(text), &w, &h) {
		return 0, 0
	}
	return int(w), int(h)
}

draw_text :: proc(position: engine.Vector2, text: string, font_handle: int, color: engine.Color) {

	trans_x, trans_y, _ := camera_translation_position(position.x, position.y, 1.0)

	ctext := strings.clone_to_cstring(text)
	defer delete(ctext)

	font := fonts[font_handle]

	text := ttf.CreateText(text_engine, font, ctext, 0)
	defer ttf.DestroyText(text)
	ttf.SetTextColorFloat(
		text,
		f32(color.r) / 255,
		f32(color.g) / 255,
		f32(color.b) / 255,
		f32(color.a) / 255,
	)
	ttf.DrawRendererText(text, f32(trans_x), f32(trans_y))
}


draw_debug_text :: proc(position: engine.Vector2, text: string, scale: f32, color: engine.Color) {

	ctext := strings.clone_to_cstring(text)
	defer delete(ctext)

	sdl.SetRenderScale(renderer, scale, scale)
	set_renderer_draw_color(renderer, color.r, color.g, color.b, color.a)
	sdl.RenderDebugText(renderer, f32(position.x) / scale, f32(position.y) / scale, ctext)
	sdl.SetRenderScale(renderer, 1, 1) // reset render
}

attach_camera :: proc(cam: ^engine.Camera2D) {
	canvas := safe_get_texture(world_texture)
	render_cam = cam
	sdl.SetRenderTarget(renderer, canvas)
	sdl.RenderClear(renderer)
}

detach_camera :: proc() {
	canvas := safe_get_texture(world_texture)
	sdl.SetRenderTarget(renderer, nil)
	sdl.RenderClear(renderer)
	defer render_cam = nil

	w, h := get_window_size()
	dst := sdl.FRect {
		x = 0,
		y = 0,
		w = f32(w),
		h = f32(h),
	}
	center := engine.vector2(f64(w) / 2, f64(h) / 2)
	sdl.RenderTextureRotated(
		renderer,
		canvas,
		nil,
		&dst,
		f64(render_cam.rotation),
		&sdl.FPoint{f32(center.x), f32(center.y)},
		sdl.FlipMode.NONE,
	)
}

set_renderer_draw_color :: proc(renderer: ^sdl.Renderer, r, g, b, a: u8) -> bool {
	return sdl.SetRenderDrawColorFloat(
		renderer,
		f32(r) / 255.0,
		f32(g) / 255.0,
		f32(b) / 255.0,
		f32(a) / 255.0,
	)

}


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
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"failed to get file size: %s",
			sdl.GetError(),
		)
		return 0
	}
	return cast(int)outSize
}

// loads contents of the file into the user provided buffer
load_file :: proc(path: cstring, buffer: rawptr, size: int) -> bool {
	if (!sdl.ReadStorageFile(platform_storage.title, path, buffer, cast(u64)size)) {
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

	if !sdl.WriteStorageFile(platform_storage.writable, cpath, buffer, cast(u64)size) {
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

// create_canvas creates a blank texture onto which you can render onto
// it will be destoryed at shutdown with destory_all_textures
create_canvas :: proc(width: int, height: int) -> int {
	// Size the world texture to the real backing pixel size of the window
	// (not the WINDOW_WIDTH/HEIGHT points), so it matches the camera offset
	// computed from get_window_size() and blits 1:1 to the screen.
	texture := sdl.CreateTexture(
		renderer,
		sdl.PixelFormat.RGBA8888,
		sdl.TextureAccess.TARGET,
		i32(width),
		i32(height),
	)

	if (texture == nil) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"could not create texture %s",
			sdl.GetError(),
		)
		panic("failed to load texture")
	}
	if (!sdl.SetTextureBlendMode(texture, sdl.BLENDMODE_BLEND_PREMULTIPLIED)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"could not set texture blend mode %s",
			sdl.GetError(),
		)
		panic("failed to load texture")
	}

	// set scale mode to pixel art or nearest if using pixel art
	if (!sdl.SetTextureScaleMode(texture, sdl.ScaleMode.NEAREST)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"could not set texture scale mode %s",
			sdl.GetError(),
		)
		panic("failed to load texture")
	}
	append(&textures, texture)
	return len(textures) - 1
}


push_canvas :: proc(canvas: int) {
	current_canvas = safe_get_texture(canvas)
	if !sdl.SetRenderTarget(renderer, current_canvas) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"could not set texture render target %s",
			sdl.GetError(),
		)
	}
	sdl.RenderClear(renderer)
}

pop_canvas :: proc() {
	sdl.SetRenderTarget(renderer, nil)
	sdl.RenderClear(renderer)
	defer current_canvas = nil

	w, h := get_window_size()
	dst := sdl.FRect {
		x = 0,
		y = 0,
		w = f32(w),
		h = f32(h),
	}
	center := engine.vector2(f64(w) / 2, f64(h) / 2)
	sdl.RenderTextureRotated(
		renderer,
		current_canvas,
		nil,
		&dst,
		0,
		&sdl.FPoint{f32(center.x), f32(center.y)},
		sdl.FlipMode.NONE,
	)
}


create_placeholder_texture :: proc() {
	placeholder_texture = sdl.CreateTexture(
		renderer,
		sdl.PixelFormat.RGBA32,
		sdl.TextureAccess.TARGET,
		32,
		32,
	)

	if (placeholder_texture == nil) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"could not create texture %s",
			sdl.GetError(),
		)
		panic("failed to load texture")
	}

	if (!sdl.SetTextureBlendMode(placeholder_texture, sdl.BLENDMODE_BLEND_PREMULTIPLIED)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"could not set texture blend mode %s",
			sdl.GetError(),
		)
		panic("failed to load texture")
	}

	if (!sdl.SetTextureScaleMode(placeholder_texture, sdl.ScaleMode.NEAREST)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"could not set texture scale mode %s",
			sdl.GetError(),
		)
		panic("failed to load texture")
	}

	if (!sdl.SetRenderTarget(renderer, placeholder_texture)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"could not set texture render target %s",
			sdl.GetError(),
		)
		panic("failed to load texture")
	}

	if (!set_renderer_draw_color(renderer, 0, 0, 0, 255)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"could not set texture render draw color %s",
			sdl.GetError(),
		)
		panic("failed to load texture")
	}

	if (!sdl.RenderClear(renderer)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"could not clear renderer %s",
			sdl.GetError(),
		)
		panic("failed to load texture")
	}

	if (!set_renderer_draw_color(renderer, 255, 0, 255, 255)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"could not set draw color %s",
			sdl.GetError(),
		)
		panic("failed to load texture")
	}

	if (!sdl.RenderFillRect(renderer, &sdl.FRect{x = 0, y = 0, w = 16, h = 16})) {
		sdl.LogError(cast(i32)sdl.LogCategory.CUSTOM, "could not fill rect %s", sdl.GetError())
		panic("failed to load texture")
	}

	if (!sdl.SetRenderTarget(renderer, nil)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"could not set renderer target %s",
			sdl.GetError(),
		)
		panic("failed to load texture")
	}


}


create_texture :: proc(width, height, channels, bpp: int, data: ^u32) -> int {
	texture: ^sdl.Texture
	if (data != nil) {
		texture = sdl.CreateTexture(
			renderer,
			channels == 4 ? sdl.PixelFormat.RGBA32 : sdl.PixelFormat.RGB24,
			sdl.TextureAccess.STREAMING,
			cast(i32)width,
			cast(i32)height,
		)
		if (texture == nil) {
			sdl.LogError(
				cast(i32)sdl.LogCategory.CUSTOM,
				"failed to read file at %s: %s",
				sdl.GetError(),
			)
			return PLACEHOLDER_TEXTURE_HANDLE
		}
		pitch := width * bpp
		if (!sdl.UpdateTexture(texture, nil, data, cast(i32)pitch)) {
			sdl.LogError(
				cast(i32)sdl.LogCategory.CUSTOM,
				"Could not update texture %s",
				sdl.GetError(),
			)
			return PLACEHOLDER_TEXTURE_HANDLE
		}
		if texture.format == sdl.PixelFormat.RGBA32 {
			if (!sdl.SetTextureBlendMode(texture, sdl.BLENDMODE_BLEND)) {
				sdl.LogError(
					cast(i32)sdl.LogCategory.CUSTOM,
					"Could not set texture blend mode %s",
					sdl.GetError(),
				)
			}
		}

		if (!sdl.SetTextureScaleMode(texture, sdl.ScaleMode.NEAREST)) {
			sdl.LogError(
				cast(i32)sdl.LogCategory.CUSTOM,
				"Could not set texture scale mode %s",
				sdl.GetError(),
			)
		}

		append(&textures, texture)
		return len(textures) - 1

	} else {
		sdl.LogError(cast(i32)sdl.LogCategory.CUSTOM, "using placeholder texture")
		return PLACEHOLDER_TEXTURE_HANDLE
	}
}

// safely get texture from texture handle
@(private)
safe_get_texture :: #force_inline proc(handle: int) -> ^sdl.Texture {
	assert(textures != nil, "texture array is nil")
	assert(handle >= 0, "texture handle must be positive")
	assert(handle < len(textures), "texture handle must be in range of len(textures)")
	return textures[handle]
}


/*
	 Destroys all textures, should always be called as a placeholder is created in the init procedure.
*/
destroy_all_textures :: proc() {
	for tex in textures {
		sdl.DestroyTexture(tex)
	}
	delete(textures)
	sdl.DestroyTexture(placeholder_texture)
}

destroy_all_fonts :: proc() {
	for font in fonts {
		ttf.CloseFont(font)
	}
	delete(fonts)
}


shutdown :: proc() {

	sdl.LogInfo(cast(i32)sdl.LogCategory.APPLICATION, "Shutting down...")
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
	ttf.DestroyRendererTextEngine(text_engine)
	ttf.Quit()

	// platform
	platform_storage_destroy()
	platform_config_destroy(platform_config)


	sdl.DestroyGPUDevice(device)
	sdl.DestroyRenderer(renderer)
	sdl.DestroyWindow(window)
	sdl.Quit()
}

// get_window_size returns the window size in pixles
get_window_size :: #force_inline proc() -> (int, int) {
	w, h: i32
	if (!sdl.GetWindowSizeInPixels(window, &w, &h)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"failed to get window size %s",
			sdl.GetError(),
		)
	}
	return int(w), int(h)
}

// get_render_size returns the pixels size of the renderer context
// note: should be the same as sdl.GetWindowSizeInPixels
get_render_size :: proc() -> (int, int) {
	w, h: i32
	if (!sdl.GetRenderOutputSize(renderer, &w, &h)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"failed to get renderer size %s",
			sdl.GetError(),
		)
	}
	return int(w), int(h)
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
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL failed to rumble gamepad: %s",
			sdl.GetError(),
		)
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
		if (stream_count >= MAX_CONCURRENT_AUDIO_STREAMS) {
			sdl.LogError(
				cast(i32)sdl.LogCategory.CUSTOM,
				"SDL could not play sound: all audio streams in use",
			)
			return -1
		}
		new_stream = sdl.CreateAudioStream(&spec, nil)
		if new_stream == nil {
			sdl.LogError(
				cast(i32)sdl.LogCategory.CUSTOM,
				"SDL could not create new stream: %s",
				sdl.GetError(),
			)
			return -1
		}

		if !sdl.BindAudioStream(audio_device, new_stream) {
			sdl.LogError(
				cast(i32)sdl.LogCategory.CUSTOM,
				"SDL could not create new stream: %s",
				sdl.GetError(),
			)
			return -1
		}
		streams[stream_count] = new_stream
		handle = stream_count
		stream_count += 1
	}

	if !sdl.SetAudioStreamGain(new_stream, f32(volume)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not set audio stream grain: %s",
			sdl.GetError(),
		)
	}
	if !sdl.PutAudioStreamData(new_stream, data, i32(length)) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not put audio stream data: %s",
			sdl.GetError(),
		)
	}

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
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not load font: %s",
			sdl.GetError(),
		)
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

// for now lets do a simple logger, just debug level
logger :: proc(msg: string, args: ..any) {
	cmessage := fmt.ctprintf(msg, ..args)
	sdl.LogDebug(cast(i32)sdl.LogCategory.CUSTOM, cmessage)
}

// text input
start_text_input :: proc() {
	if !sdl.StartTextInput(window) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not start text input: %s",
			sdl.GetError(),
		)
	}
}

stop_text_input :: proc() {
	if !sdl.StopTextInput(window) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not start text input: %s",
			sdl.GetError(),
		)
	}
}

get_text_input_buffer :: proc() -> ([64]u8, int) {
	return text_buffer, text_buffer_len
}

// Platform Storage
platform_storage_init :: proc() {
	platform_storage = new(PlatformStorage, context.allocator)
	platform_storage.title = sdl.OpenTitleStorage(nil, 0)
	if (platform_storage.title == nil) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"Title storage could not be opened: %s",
			sdl.GetError(),
		)
		panic("initialisation error: failed to open title storage")
	}
	for !sdl.StorageReady(platform_storage.title) do sdl.Delay(1)
}


platform_storage_destroy :: proc() {
	ok := sdl.CloseStorage(platform_storage.title)
	if (!ok) {
		sdl.LogError(cast(i32)sdl.LogCategory.CUSTOM, "failed to close storage %s", sdl.GetError())
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
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"Writing storage could not be opened: %s",
			sdl.GetError(),
		)
		return false
	}
	for !sdl.StorageReady(platform_storage.writable) do sdl.Delay(1)
	return true
}

platform_storage_destroy_writer :: proc() {
	if platform_storage.writable == nil do return
	ok2 := sdl.CloseStorage(platform_storage.writable)
	if (!ok2) {
		sdl.LogError(cast(i32)sdl.LogCategory.CUSTOM, "failed to close storage %s", sdl.GetError())
	}
	platform_storage.writable = nil
}
