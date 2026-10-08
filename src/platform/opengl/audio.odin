package platform_opengl

import sdl "vendor:sdl3"

// audio
audio_device: sdl.AudioDeviceID
MAX_CONCURRENT_AUDIO_STREAMS :: 32
streams: [MAX_CONCURRENT_AUDIO_STREAMS]^sdl.AudioStream // array of audio streams
stream_count := 0 // current stream count, could also migrate to dynamic array

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

destroy_all_sounds :: proc() {
	for s in 0 ..< stream_count {
		sdl.DestroyAudioStream(streams[s])
	}
	stream_count = 0
}
