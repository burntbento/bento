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

platform_config: ^PlatformConfig // config

// gpu
device: ^sdl.GPUDevice
formats: sdl.GPUShaderFormat
cmdbuf: ^sdl.GPUCommandBuffer
swapchain_texture: ^sdl.GPUTexture
render_pass: ^sdl.GPURenderPass
pipeline: ^sdl.GPUGraphicsPipeline
vertex_buffer: ^sdl.GPUBuffer

PositionColorVertex :: struct {
	x, y, z:    f32,
	r, g, b, a: u8,
}

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

	if !sdl.ClaimWindowForGPUDevice(device, window) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"GPU device failed to claim window: %s",
			sdl.GetError(),
		)
		panic("initialisation error: gpu device failed to claim window")
	}

	// pipeline init
	init_pipeline()

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
	text_engine = ttf.CreateGPUTextEngine(device)

}

get_base_path :: proc() -> cstring {
	return sdl.GetBasePath()
}

load_shader :: proc(
	device: ^sdl.GPUDevice,
	file: string,
	sampler_count: u32,
	uniform_buffer_count: u32,
	storage_buffer_count: u32,
	storage_texture_count: u32,
) -> ^sdl.GPUShader {

	stage: sdl.GPUShaderStage
	if strings.contains(file, ".vert") {
		stage = .VERTEX
	} else if strings.contains(file, ".frag") {
		stage = .FRAGMENT
	} else {
		sdl.Log("invalid shader")
		return nil
	}


	backends := sdl.GetGPUShaderFormats(device)
	format: sdl.GPUShaderFormat = {}

	base_path := get_base_path()
	entrypoint: cstring
	full_path: string
	if .SPIRV in backends {
		full_path = fmt.tprintf("%s/shaders/compiled/%s.spv", base_path, file)
		format = {.SPIRV}
		entrypoint = "main"
	} else if .MSL in backends {
		full_path = fmt.tprintf("%s/shaders/compiled/%s.msl", base_path, file)
		format = {.MSL}
		entrypoint = "main0"
	} else if .DXIL in backends {
		full_path = fmt.tprintf("%s/shaders/compiled/%s.dxil", base_path, file)
		format = {.DXIL}
		entrypoint = "main"
	} else {
		sdl.Log("failed choosing backend format")
		return nil
	}

	code_size: uint
	code := sdl.LoadFile(strings.clone_to_cstring(full_path, context.temp_allocator), &code_size)
	defer sdl.free(code)
	if code == nil {
		sdl.LogError(cast(i32)sdl.LogCategory.CUSTOM, "failed to read file: %s", sdl.GetError())
		return nil
	}

	gpu_shader_info := sdl.GPUShaderCreateInfo {
		code                = cast([^]u8)code,
		code_size           = code_size,
		entrypoint          = entrypoint,
		format              = format,
		stage               = stage,
		num_samplers        = sampler_count,
		num_uniform_buffers = uniform_buffer_count,
		num_storage_buffers = storage_texture_count,
	}

	shader := sdl.CreateGPUShader(device, gpu_shader_info)
	if shader == nil {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"failed to create shader: %s",
			sdl.GetError(),
		)
		return nil
	}
	return shader
}

// triangle pipeline
init_pipeline :: proc() {
	vertex_shader := load_shader(device, "PositionColor.vert", 0, 0, 0, 0)
	if vertex_shader == nil {
		panic("failed t init pipeline, vertex_shader")
	}
	defer sdl.ReleaseGPUShader(device, vertex_shader)

	fragment_shader := load_shader(device, "SolidColor.frag", 0, 1, 0, 0)
	if fragment_shader == nil {
		panic("failed t init pipeline, frag")
	}
	defer sdl.ReleaseGPUShader(device, fragment_shader)

	pipeline_create_info := sdl.GPUGraphicsPipelineCreateInfo {
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = raw_data(
				[]sdl.GPUColorTargetDescription {
					{format = sdl.GetGPUSwapchainTextureFormat(device, window)},
				},
			),
		},
		vertex_input_state = sdl.GPUVertexInputState {
			num_vertex_buffers = 1,
			vertex_buffer_descriptions = raw_data(
				[]sdl.GPUVertexBufferDescription {
					{
						slot = 0,
						input_rate = .VERTEX,
						instance_step_rate = 0,
						pitch = size_of(PositionColorVertex),
					},
				},
			),
			num_vertex_attributes = 2,
			vertex_attributes = raw_data(
				[]sdl.GPUVertexAttribute {
					{buffer_slot = 0, format = .FLOAT3, location = 0, offset = 0},
					{
						buffer_slot = 0,
						format = .UBYTE4_NORM,
						location = 1,
						offset = size_of(c.float) * 3,
					},
				},
			),
		},
		primitive_type = .TRIANGLELIST,
		vertex_shader = vertex_shader,
		fragment_shader = fragment_shader,
	}

	pipeline = sdl.CreateGPUGraphicsPipeline(device, pipeline_create_info)
	if pipeline == nil {
		sdl.Log("failed to create fill pipeline")
		return
	}

	vertex_buffer = sdl.CreateGPUBuffer(
		device,
		sdl.GPUBufferCreateInfo{usage = {.VERTEX}, size = size_of(PositionColorVertex) * 1024},
	)

	transfer_buffer := sdl.CreateGPUTransferBuffer(
		device,
		sdl.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = size_of(PositionColorVertex) * 3},
	)

	raw := sdl.MapGPUTransferBuffer(device, transfer_buffer, false)
	transfer_data := cast([^]PositionColorVertex)raw

	// triangle
	transfer_data[0] = PositionColorVertex{-1, -1, 0, 255, 255, 255, 255}
	transfer_data[1] = PositionColorVertex{1, -1, 0, 255, 255, 255, 255}
	transfer_data[2] = PositionColorVertex{0, 1, 0, 255, 255, 255, 255}

	// square
	transfer_data[3] = PositionColorVertex{-1, -1, 0, 255, 255, 255, 255}
	transfer_data[4] = PositionColorVertex{1, -1, 0, 255, 255, 255, 255}
	transfer_data[5] = PositionColorVertex{1, 1, 0, 255, 255, 255, 255}
	transfer_data[6] = PositionColorVertex{-1, -1, 0, 255, 255, 255, 255}
	transfer_data[7] = PositionColorVertex{1, 1, 0, 255, 255, 255, 255}
	transfer_data[8] = PositionColorVertex{-1, 1, 0, 255, 255, 255, 255}

	sdl.UnmapGPUTransferBuffer(device, transfer_buffer)

	upload_cmdbuf := sdl.AcquireGPUCommandBuffer(device)
	copyPass := sdl.BeginGPUCopyPass(upload_cmdbuf)

	sdl.UploadToGPUBuffer(
		copyPass,
		sdl.GPUTransferBufferLocation{transfer_buffer = transfer_buffer, offset = 0},
		sdl.GPUBufferRegion {
			buffer = vertex_buffer,
			offset = 0,
			size = size_of(PositionColorVertex) * 9,
		},
		false,
	)

	sdl.EndGPUCopyPass(copyPass)
	_ = sdl.SubmitGPUCommandBuffer(upload_cmdbuf)
	sdl.ReleaseGPUTransferBuffer(device, transfer_buffer)

}


begin_frame :: proc() {
	// aquire cmdbuffer
	cmdbuf = sdl.AcquireGPUCommandBuffer(device)
	if cmdbuf == nil {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"Failed to aquire cmd buffer: %s",
			sdl.GetError(),
		)
	}

	// aquire swapchain
	if !sdl.WaitAndAcquireGPUSwapchainTexture(cmdbuf, window, &swapchain_texture, nil, nil) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"Failed to aquire swapchain_texture: %s",
			sdl.GetError(),
		)
	}
}

end_frame :: proc() {
	defer render_pass = nil
	if swapchain_texture != nil {
		sdl.EndGPURenderPass(render_pass)
	}
	if !sdl.SubmitGPUCommandBuffer(cmdbuf) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"Failed to submit gpu cmdbuf: %s",
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


	shader_data := new(ShaderData, context.allocator)
	shader_data.shader = shader
	shader_data.state = nil // Note: fix

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
}

pop_shader_state :: proc() {
}

@(private)
engine_color_to_fcolor :: #force_inline proc(color: engine.Color) -> sdl.FColor {
	return sdl.FColor {
		f32(color.r) / 255.0,
		f32(color.g) / 255.0,
		f32(color.b) / 255.0,
		f32(color.a) / 255.0,
	}
}

clear_screen :: proc(color: engine.Color) {
	if swapchain_texture == nil do return

	color_target_info := sdl.GPUColorTargetInfo {
		texture     = swapchain_texture,
		clear_color = engine_color_to_fcolor(color),
		load_op     = .CLEAR,
		store_op    = .STORE,
	}
	render_pass = sdl.BeginGPURenderPass(cmdbuf, &color_target_info, 1, nil)
}

draw_circle :: proc(circle: engine.Circle, color: engine.Color) {
}

draw_rect :: proc(rect: engine.Rect, color: engine.Color) {
	if swapchain_texture == nil do return

	sdl.SetGPUViewport(
		render_pass,
		{f32(rect.x), f32(rect.y), f32(rect.width), f32(rect.height), 0.1, 0.1},
	)
	shader_color := engine_color_to_fcolor(color)
	sdl.BindGPUGraphicsPipeline(render_pass, pipeline)
	sdl.PushGPUFragmentUniformData(cmdbuf, 0, rawptr(&shader_color), size_of(shader_color))
	sdl.BindGPUVertexBuffers(
		render_pass,
		0,
		&sdl.GPUBufferBinding{buffer = vertex_buffer, offset = 0},
		1,
	)
	sdl.DrawGPUPrimitives(render_pass, 6, 2, 3, 0)
}

draw_rect_line :: proc(rect: engine.Rect, color: engine.Color) {
}

draw_arc :: proc(
	center: engine.Vector2,
	radius, start_angle, end_angle, thickness: f32,
	color: engine.Color,
) {

}

set_clip_rect :: proc(rect: engine.Rect) {
}

end_clip_rect :: proc() {
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

}

attach_camera :: proc(cam: ^engine.Camera2D) {
}

detach_camera :: proc() {
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
	return -1
}


push_canvas :: proc(canvas: int) {
}

pop_canvas :: proc() {
}


create_placeholder_texture :: proc() {

}


create_texture :: proc(width, height, channels, bpp: int, data: ^u32) -> int {
	return -1
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
	if !sdl.WaitForGPUIdle(device) {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"error waiting for gpu to be idle: %s",
			sdl.GetError(),
		)
	}

	sdl.LogInfo(cast(i32)sdl.LogCategory.APPLICATION, "Shutting down...")
	if (gamepad != nil) {
		sdl.CloseGamepad(gamepad)
		gamepad = nil
	}

	sdl.ReleaseGPUGraphicsPipeline(device, pipeline)
	sdl.ReleaseGPUBuffer(device, vertex_buffer)

	// destory textures
	destroy_all_textures()

	// destory fonts
	destroy_all_fonts()


	// shutdown audio
	sdl.CloseAudioDevice(audio_device)

	// shutdown fonts
	ttf.DestroyGPUTextEngine(text_engine)
	ttf.Quit()

	// platform
	platform_storage_destroy()
	platform_config_destroy(platform_config)


	sdl.DestroyGPUDevice(device)
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
	return -1, -1
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

// set existing audio stream
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
