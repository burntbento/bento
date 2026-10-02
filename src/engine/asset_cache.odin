package engine

import "core:mem"

TextureAsset :: struct {
	handle: int,
	width:  int,
	height: int,
}

AssetCache :: struct {
	texture_cache: map[string]TextureAsset,
	audio_cache:   map[string]AudioClip,
	font_cache:    map[string]int,
	shader_cache:  map[string]int,
	_allocator:    mem.Allocator,
}

asset_cache_new :: proc(allocator := context.allocator) -> ^AssetCache {
	cache := new(AssetCache, allocator)
	cache.texture_cache = make(map[string]TextureAsset, allocator)
	cache.font_cache = make(map[string]int, allocator)
	cache.audio_cache = make(map[string]AudioClip, allocator)
	cache.shader_cache = make(map[string]int, allocator)
	cache._allocator = allocator
	return cache
}

asset_cache_destroy :: proc(cache: ^AssetCache) {
	allocator := cache._allocator

	// destroy texture keys
	for key in cache.texture_cache {
		delete(key)
	}
	delete(cache.texture_cache)

	// destroy fonts keys
	for key in cache.font_cache {
		delete(key)
	}
	delete(cache.font_cache)

	// destroy shader keys
	for key in cache.shader_cache {
		delete(key)
	}
	delete(cache.shader_cache)

	// destory audio keys
	for key in cache.audio_cache {
		delete(key)
	}
	delete(cache.audio_cache)

	// finally
	free(cache, allocator)
}
