package platform

BACKEND :: #config(BACKEND, "sdl3")

@(require) import pkg_opengl "bento:platform/opengl"
@(require) import pkg_sdl3 "bento:platform/sdl3"

when BACKEND == "sdl3" {

	// main
	init :: pkg_sdl3.init
	begin_frame :: pkg_sdl3.begin_frame
	end_frame :: pkg_sdl3.end_frame
	shutdown :: pkg_sdl3.shutdown

	// files io
	get_file_size :: pkg_sdl3.get_file_size
	load_file :: pkg_sdl3.load_file
	write_file :: pkg_sdl3.write_file

	// storage
	platform_storage_init :: pkg_sdl3.platform_storage_init
	platform_storage_destroy :: pkg_sdl3.platform_storage_destroy
	platform_storage_init_writer :: pkg_sdl3.platform_storage_init_writer
	platform_storage_destroy_writer :: pkg_sdl3.platform_storage_destroy_writer

	// textures / canvas
	create_texture :: pkg_sdl3.create_texture
	create_placeholder_texture :: pkg_sdl3.create_placeholder_texture
	set_renderer_draw_color :: pkg_sdl3.set_renderer_draw_color
	create_canvas :: pkg_sdl3.create_canvas
	push_canvas :: pkg_sdl3.push_canvas
	pop_canvas :: pkg_sdl3.pop_canvas
	destroy_all_textures :: pkg_sdl3.destroy_all_textures
	get_window_size :: pkg_sdl3.get_window_size
	get_render_size :: pkg_sdl3.get_render_size

	// drawing
	clear_screen :: pkg_sdl3.clear_screen
	draw_rect :: pkg_sdl3.draw_rect
	draw_rect_line :: pkg_sdl3.draw_rect_line
	draw_circle :: pkg_sdl3.draw_circle
	draw_arc :: pkg_sdl3.draw_arc
	draw_sprite :: pkg_sdl3.draw_sprite
	set_clip_rect :: pkg_sdl3.set_clip_rect
	end_clip_rect :: pkg_sdl3.end_clip_rect
	attach_camera :: pkg_sdl3.attach_camera
	detach_camera :: pkg_sdl3.detach_camera

	// text
	destroy_all_fonts :: pkg_sdl3.destroy_all_fonts
	load_font :: pkg_sdl3.load_font
	measure_text :: pkg_sdl3.measure_text
	draw_text :: pkg_sdl3.draw_text
	draw_debug_text :: pkg_sdl3.draw_debug_text
	start_text_input :: pkg_sdl3.start_text_input
	stop_text_input :: pkg_sdl3.stop_text_input
	get_text_input_buffer :: pkg_sdl3.get_text_input_buffer

	// shaders
	shader_create_info :: pkg_sdl3.shader_create_info
	destroy_all_shaders :: pkg_sdl3.destroy_all_shaders
	set_gpu_fragment_shader_uniforms :: pkg_sdl3.set_gpu_fragment_shader_uniforms
	push_shader_state :: pkg_sdl3.push_shader_state
	pop_shader_state :: pkg_sdl3.pop_shader_state

	// audio
	destroy_all_sounds :: pkg_sdl3.destroy_all_sounds
	load_sound :: pkg_sdl3.load_sound
	play_sound :: pkg_sdl3.play_sound
	resume_sound :: pkg_sdl3.resume_sound
	pause_sound :: pkg_sdl3.pause_sound
	set_sound_volume :: pkg_sdl3.set_sound_volume
	is_sound_playing :: pkg_sdl3.is_sound_playing

	// input
	update_input :: pkg_sdl3.update_input
	input_set_state :: pkg_sdl3.input_set_state
	input_reset :: pkg_sdl3.input_reset
	in_between_deadzone :: pkg_sdl3.in_between_deadzone
	set_gamepad_axis_half :: pkg_sdl3.set_gamepad_axis_half
	set_half_axis_state :: pkg_sdl3.set_half_axis_state
	gamepad_rumble :: pkg_sdl3.gamepad_rumble
	set_deadzone :: pkg_sdl3.set_deadzone
	get_deadzone :: pkg_sdl3.get_deadzone

	get_performance_frequency :: pkg_sdl3.get_performance_frequency
	get_performance_counter :: pkg_sdl3.get_performance_counter
	logger :: pkg_sdl3.logger
	get_page_size :: pkg_sdl3.get_page_size
	free_mem :: pkg_sdl3.free_mem
}

when BACKEND == "opengl" {

	// main
	init :: pkg_opengl.init
	begin_frame :: pkg_opengl.begin_frame
	end_frame :: pkg_opengl.end_frame
	shutdown :: pkg_opengl.shutdown

	// files io
	get_file_size :: pkg_opengl.get_file_size
	load_file :: pkg_opengl.load_file
	write_file :: pkg_opengl.write_file

	// storage
	platform_storage_init :: pkg_opengl.platform_storage_init
	platform_storage_destroy :: pkg_opengl.platform_storage_destroy
	platform_storage_init_writer :: pkg_opengl.platform_storage_init_writer
	platform_storage_destroy_writer :: pkg_opengl.platform_storage_destroy_writer

	// textures / canvas
	create_texture :: pkg_opengl.create_texture
	create_placeholder_texture :: pkg_opengl.create_placeholder_texture
	set_renderer_draw_color :: pkg_opengl.set_renderer_draw_color
	create_canvas :: pkg_opengl.create_canvas
	push_canvas :: pkg_opengl.push_canvas
	pop_canvas :: pkg_opengl.pop_canvas
	destroy_all_textures :: pkg_opengl.destroy_all_textures
	get_window_size :: pkg_opengl.get_window_size
	get_render_size :: pkg_opengl.get_render_size

	// drawing
	clear_screen :: pkg_opengl.clear_screen
	draw_rect :: pkg_opengl.draw_rect
	draw_rect_line :: pkg_opengl.draw_rect_line
	draw_circle :: pkg_opengl.draw_circle
	draw_arc :: pkg_opengl.draw_arc
	draw_sprite :: pkg_opengl.draw_sprite
	set_clip_rect :: pkg_opengl.set_clip_rect
	end_clip_rect :: pkg_opengl.end_clip_rect
	attach_camera :: pkg_opengl.attach_camera
	detach_camera :: pkg_opengl.detach_camera

	// text
	destroy_all_fonts :: pkg_opengl.destroy_all_fonts
	load_font :: pkg_opengl.load_font
	measure_text :: pkg_opengl.measure_text
	draw_text :: pkg_opengl.draw_text
	draw_debug_text :: pkg_opengl.draw_debug_text
	start_text_input :: pkg_opengl.start_text_input
	stop_text_input :: pkg_opengl.stop_text_input
	get_text_input_buffer :: pkg_opengl.get_text_input_buffer

	// shaders
	shader_create_info :: pkg_opengl.shader_create_info
	destroy_all_shaders :: pkg_opengl.destroy_all_shaders
	set_gpu_fragment_shader_uniforms :: pkg_opengl.set_gpu_fragment_shader_uniforms
	push_shader_state :: pkg_opengl.push_shader_state
	pop_shader_state :: pkg_opengl.pop_shader_state

	// audio
	destroy_all_sounds :: pkg_opengl.destroy_all_sounds
	load_sound :: pkg_opengl.load_sound
	play_sound :: pkg_opengl.play_sound
	resume_sound :: pkg_opengl.resume_sound
	pause_sound :: pkg_opengl.pause_sound
	set_sound_volume :: pkg_opengl.set_sound_volume
	is_sound_playing :: pkg_opengl.is_sound_playing

	// input
	update_input :: pkg_opengl.update_input
	input_set_state :: pkg_opengl.input_set_state
	input_reset :: pkg_opengl.input_reset
	in_between_deadzone :: pkg_opengl.in_between_deadzone
	set_gamepad_axis_half :: pkg_opengl.set_gamepad_axis_half
	set_half_axis_state :: pkg_opengl.set_half_axis_state
	gamepad_rumble :: pkg_opengl.gamepad_rumble
	set_deadzone :: pkg_opengl.set_deadzone
	get_deadzone :: pkg_opengl.get_deadzone

	get_performance_frequency :: pkg_opengl.get_performance_frequency
	get_performance_counter :: pkg_opengl.get_performance_counter
	logger :: pkg_opengl.logger
	get_page_size :: pkg_opengl.get_page_size
	free_mem :: pkg_opengl.free_mem

}
