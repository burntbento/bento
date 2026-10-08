package platform_opengl

import "bento:engine"
import "core:c"
import "core:mem"
import "core:strings"

platform_config: ^PlatformConfig

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
