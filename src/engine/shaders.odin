package engine

import "core:strings"

// WARNING: shaders will crash if the shader has num_samplers > 0 and there are no sprites to sample from

// NOTE: I also want to be able to push several shaders onto the same texture, not sure how to do this yet
// could just copy the texture over and push

// NOTE: Currently only fragment is supported
ShaderStage :: enum {
	VERTEX,
	FRAGMENT,
}

// entry point moved here as vulkan and dxil have main but metal will be main0
ShaderData :: struct {
	entry_point: string,
	code_size:   uint,
	code:        [^]u8,
}

// TODO: Need to hook up platform to game layer
// need to also add spirv, dxil and msl shader formats
// should support all formats
ShaderCreateInfo :: struct {
	data:                ShaderFormatData,
	stage:               ShaderStage,
	num_samplers:        u32,
	num_storage_buffers: u32,
	num_uniform_buffers: u32,
}


// we need to provide all formats to the engine
// this means when it runs on windows, mac and linux.
// it can choose the correct one
ShaderFormatData :: struct {
	spirv: ShaderData,
	msl:   ShaderData,
	dxil:  ShaderData,
}


@(private)
assert_shader :: proc(info: ShaderCreateInfo) {
	assert(
		info.data.spirv.code != nil,
		"Shader must implement vulkan, metal and directX11, shader binaries",
	)
	assert(
		info.data.msl.code != nil,
		"Shader must implement vulkan, metal and directX11, shader binaries",
	)
	assert(
		info.data.dxil.code != nil,
		"Shader must implement vulkan, metal and directX11, shader binaries",
	)
	assert(info.data.spirv.code_size > 0)
	assert(info.data.dxil.code_size > 0)
	assert(info.data.msl.code_size > 0)
}

shader_create :: proc(name: string, info: ShaderCreateInfo, state: ^GameState) -> (int, Error) {
	assert_shader(info)

	if asset, ok := state.asset_cache.shader_cache[name]; ok {
		return asset, nil
	}

	handle := state.platform.shader_create_info(info)
	if handle == -1 {
		state.platform.logger("Failed to create shader")
		return -1, VALUE_ERROR{message = "Not found"}
	}

	state.asset_cache.shader_cache[strings.clone(name)] = handle
	return handle, nil
}

shader_get_handle :: proc(
	name: string,
	state: ^GameState,
	loc := #caller_location,
) -> (
	int,
	Error,
) {
	if asset, ok := state.asset_cache.shader_cache[name]; ok {
		return asset, nil
	}

	return -1, VALUE_ERROR{message = "shader not found", location = loc}
}
