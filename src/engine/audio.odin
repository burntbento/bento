package engine

import "core:strings"

@(private)
AUDIO_MAX_SOUNDS :: 128

@(private)
AUDIO_HASH_MAP_EXP :: 10

@(private)
AudioAsset :: struct {
	format, channels, freq: int,
	buffer:                 [^]u8,
	length:                 u32,
	path:                   string,
	data:                   bool,
}

AudioClip :: struct {
	asset: ^AudioAsset,
	ok:    bool,
}

AudioSettings :: struct {
	loop:   bool,
	volume: f64,
}

Sound :: struct {
	clip:            AudioClip,
	settings:        AudioSettings,
	platform_handle: int,
}

AudioSystem :: struct {
	sounds:      [AUDIO_MAX_SOUNDS]Sound,
	assets:      map[string]AudioAsset,
	sound_count: int,
}

audio_system: ^AudioSystem

audio_init :: proc(allocator := context.allocator) {
	audio_system = new(AudioSystem, allocator)
	audio_system.assets = make(map[string]AudioAsset, allocator)
	reserve(&audio_system.assets, AUDIO_MAX_SOUNDS)
}

@(private)
audio_play_internal :: proc(state: ^GameState, clip: AudioClip, settings: ^AudioSettings) -> int {
	if (!clip.ok) {
		return -1
	}
	asset := clip.asset
	handle := state.platform.play_sound(
		asset.format,
		asset.channels,
		asset.freq,
		asset.buffer,
		int(asset.length),
		settings.volume,
	)
	return handle
}

audio_repeat :: proc(state: ^GameState, clip: AudioClip, settings: ^AudioSettings) {
	audio_play_internal(state, clip, settings)
}


audio_update :: proc(state: ^GameState) {
	sounds_to_delete: [AUDIO_MAX_SOUNDS]int = {}
	deletion_count := 0

	defer {
		for i in 0 ..< deletion_count {
			audio_system.sounds[sounds_to_delete[i]] =
				audio_system.sounds[audio_system.sound_count - 1]
			audio_system.sound_count -= 1
		}
	}

	for i in 0 ..< audio_system.sound_count {
		sound: ^Sound = &audio_system.sounds[i]
		if (!state.platform.is_sound_playing(sound.platform_handle)) {
			if (sound.settings.loop) {
				audio_repeat(state, sound.clip, &sound.settings)
			} else {
				sounds_to_delete[deletion_count] = i
				deletion_count += 1
			}
		}
	}
}

audio_shutdown :: proc(state: ^GameState, allocator := context.allocator) {
	for _, asset in audio_system.assets {
		if asset.data {
			state.platform.free_mem(asset.buffer)
		}
	}
	delete(audio_system.assets)
	free(audio_system, allocator)
	state.platform.destroy_all_sounds()
}

// loads clip with asset cache
// safe to recall to get the clip without allocating memory
audio_load :: proc(state: ^GameState, path: string) -> AudioClip {
	if clip, ok := state.asset_cache.audio_cache[path]; ok {
		return clip
	}
	clip := audio_load_private(state, path)
	key := strings.clone(path, state.global_allocator)
	state.asset_cache.audio_cache[key] = clip
	return clip
}

@(private)
audio_load_private :: proc(state: ^GameState, path: string) -> AudioClip {
	clip: AudioClip

	c_path := strings.clone_to_cstring(path)
	defer delete(c_path)

	size := state.platform.get_file_size(c_path)
	buffer := make([]u8, size, state.scratch_allocator)

	state.platform.load_file(c_path, raw_data(buffer), size)
	assert(size > 0)

	format, channels, freq: int
	audio_buffer: [^]u8
	audio_length: u32
	if (!state.platform.load_sound(
			   raw_data(buffer),
			   size,
			   &format,
			   &channels,
			   &freq,
			   &audio_buffer,
			   &audio_length,
		   )) {
		return clip
	}

	asset := AudioAsset {
		format   = format,
		channels = channels,
		freq     = freq,
		buffer   = audio_buffer,
		length   = audio_length,
		path     = path,
		data     = true,
	}

	_, ptr, _ := map_upsert(&audio_system.assets, path, asset)
	if ptr == nil {
		return clip
	}

	clip.asset = ptr
	clip.ok = true
	return clip
}

audio_pause :: proc(state: ^GameState, handle: int) -> bool {
	return state.platform.pause_sound(handle)
}

audio_resume :: proc(state: ^GameState, handle: int) -> bool {
	return state.platform.resume_sound(handle)
}

audio_set_volume :: proc(state: ^GameState, handle: int, volume: f64) -> bool {
	return state.platform.set_sound_volume(handle, volume)
}

audio_play :: proc(state: ^GameState, clip: AudioClip, settings: ^AudioSettings) -> int {
	if audio_system.sound_count >= AUDIO_MAX_SOUNDS {
		return -1
	}

	handle := audio_play_internal(state, clip, settings)

	sound := Sound {
		clip            = clip,
		settings        = settings^,
		platform_handle = handle,
	}

	audio_system.sounds[audio_system.sound_count] = sound
	audio_system.sound_count += 1
	return handle
}
