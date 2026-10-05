package execute

@(require) import "core:fmt"
@(require) import "core:mem"

import "bento:engine"
import "bento:platform"

Game :: struct {
	platform_config: engine.PlatformConfig,
	game_init:       proc(platform_data: ^engine.Platform),
	game_update:     proc(input: ^engine.GameInput, dt: f64) -> bool,
	game_render:     proc() -> ^engine.RenderCommandBuffer,
	game_shutdown:   proc(),
}

engine_run :: proc(game_data: ^Game) {

	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	engine.profiler_init()
	defer engine.profiler_shutdown()

	platform.init(game_data.platform_config)
	defer platform.shutdown()

	platform_data := engine.Platform {
		get_file_size                    = platform.get_file_size,
		load_file                        = platform.load_file,
		write_file                       = platform.write_file,
		create_texture                   = platform.create_texture,
		create_canvas                    = platform.create_canvas,
		push_canvas                      = platform.push_canvas,
		pop_canvas                       = platform.pop_canvas,
		destroy_all_textures             = platform.destroy_all_textures,
		get_window_size                  = platform.get_window_size,
		get_render_size                  = platform.get_render_size,
		destroy_all_sounds               = platform.destroy_all_sounds,
		load_sound                       = platform.load_sound,
		play_sound                       = platform.play_sound,
		resume_sound                     = platform.resume_sound,
		pause_sound                      = platform.pause_sound,
		set_sound_volume                 = platform.set_sound_volume,
		is_sound_playing                 = platform.is_sound_playing,
		destroy_all_fonts                = platform.destroy_all_fonts,
		load_font                        = platform.load_font,
		measure_text                     = platform.measure_text,
		start_text_input                 = platform.start_text_input,
		stop_text_input                  = platform.stop_text_input,
		get_text_input_buffer            = platform.get_text_input_buffer,
		gamepad_rumble                   = platform.gamepad_rumble,
		set_deadzone                     = platform.set_deadzone,
		get_deadzone                     = platform.get_deadzone,
		shader_create_info               = platform.shader_create_info,
		destroy_all_shaders              = platform.destroy_all_shaders,
		set_gpu_fragment_shader_uniforms = platform.set_gpu_fragment_shader_uniforms,
		logger                           = platform.logger,
		free_mem                         = platform.free_mem,
	}

	input: engine.GameInput

	game_data.game_init(&platform_data)
	defer game_data.game_shutdown()

	game_is_running := true

	// set accumulator
	engine.accumulator = 0.0

	// set deadzone
	platform.set_deadzone(0.8)

	performance_frequency_inverse := 1.0 / cast(f64)platform.get_performance_frequency()
	last_time := platform.get_performance_counter()

	for (game_is_running) {
		current_time := platform.get_performance_counter()
		dt := cast(f64)(current_time - last_time) * performance_frequency_inverse

		// explicitly free all temp allocator in hot loop
		free_all(context.temp_allocator)

		//accumulate
		engine.accumulator_add(dt)

		platform.update_input(&input)
		if (input.app_exit_requested) {
			game_is_running = false
			break
		}

		if (!game_data.game_update(&input, dt)) {
			break
		}

		cmdbuf := game_data.game_render()


		platform.begin_frame()
		{
			for i in 0 ..< cmdbuf.count {
				cmd := cmdbuf.commands[i]
				switch v in cmd {
				case engine.RenderCommandClearScreen:
					platform.clear_screen(v.color)
				case engine.RenderCommandDrawRect:
					platform.draw_rect(v.rect, v.color)
				case engine.RenderCommandDrawRectLine:
					platform.draw_rect_line(v.rect, v.color)
				case engine.RenderCommandDrawCircle:
					platform.draw_circle(v.circle, v.color)
				case engine.RenderCommandDrawArc:
					platform.draw_arc(
						v.center,
						v.radius,
						v.start_angle,
						v.end_angle,
						v.thickness,
						v.color,
					)
				case engine.RenderCommandDrawSprite:
					platform.draw_sprite(
						v.position,
						v.scale,
						v.rotation,
						v.pivot,
						v.texture,
						v.texture_rect,
						v.color,
						v.flip_x,
						v.flip_y,
						v.stretch_x,
						v.stretch_y,
					)
				case engine.RenderCommandDrawDebugText:
					platform.draw_debug_text(v.position, v.text, v.scale, v.color)
				case engine.RenderCommandDrawText:
					platform.draw_text(v.position, v.text, v.font, v.color)
				case engine.RenderCommandAttachCamera:
					platform.attach_camera(v.cam)
				case engine.RenderCommandDetachCamera:
					platform.detach_camera()
				case engine.RenderCommandSetClippingRect:
					platform.set_clip_rect(v.rect)
				case engine.RenderCommandEndClippingRect:
					platform.end_clip_rect()
				case engine.RenderCommandPushShader:
					platform.push_shader_state(v.handle)
				case engine.RenderCommandPopShader:
					platform.pop_shader_state()
				case engine.RenderCommandPushCanvas:
					platform.push_canvas(v.canvas)
				case engine.RenderCommandPopCanvas:
					platform.pop_canvas()
				case:
					break
				}
			}
		}
		platform.end_frame()

		last_time = current_time
	}

}
