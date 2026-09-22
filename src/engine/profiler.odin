package engine

import "core:prof/spall"
@(require) import "core:sync"

// basic profiling for a zone using spall
// use odin run . -define:PROFILE=true
PROFILE :: #config(PROFILE, false)

@(private)
spall_ctx: spall.Context

@(private)
@(thread_local)
spall_buffer: spall.Buffer

@(private)
buffer_backing: []u8


profiler_init :: proc(file_name: string = "trace_test.spall") {
	when PROFILE {
		spall_ctx = spall.context_create(file_name)
		buffer_backing = make([]u8, spall.BUFFER_DEFAULT_SIZE)
		spall_buffer = spall.buffer_create(buffer_backing, u32(sync.current_thread_id()))
	}
}


profiler_shutdown :: proc() {
	when PROFILE {
		spall.buffer_destroy(&spall_ctx, &spall_buffer)
		spall.context_destroy(&spall_ctx)
		delete(buffer_backing)
	}
}

@(deferred_in = _profiler_zone_end)
profiler_zone :: proc(name := "", loc := #caller_location) {
	when PROFILE {
		n := name if name != "" else loc.procedure
		spall._buffer_begin(&spall_ctx, &spall_buffer, n, "", loc)
	}
}

@(private)
_profiler_zone_end :: proc(name := "", loc := #caller_location) {
	when PROFILE {
		spall._buffer_end(&spall_ctx, &spall_buffer)
	}
}
