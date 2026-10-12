package platform

BACKEND :: #config(BACKEND, "sdl")

// @(require) import opengl_backend "bento:platform/opengl"
@(require) import sdl_backend "bento:platform/sdl_renderer"


when BACKEND == "sdl" {
	// main procs
	init :: sdl_backend.init
	update_input :: sdl_backend.update_input
	shutdown :: sdl_backend.shutdown

	// update loop
	get_performance_frequency :: sdl_backend.get_performance_frequency
	get_performance_counter :: sdl_backend.get_performance_counter

	// draw procs
	begin_frame :: sdl_backend.begin_frame
	end_frame :: sdl_backend.end_frame
	clear_screen :: sdl_backend.clear_screen
	draw_rect :: sdl_backend.draw_rect
	draw_rect_line :: sdl_backend.draw_rect_line
	draw_circle :: sdl_backend.draw_circle
	draw_arc :: sdl_backend.draw_arc
	draw_sprite :: sdl_backend.draw_sprite
	draw_debug_text :: sdl_backend.draw_debug_text
	draw_text :: sdl_backend.draw_text
	attach_camera :: sdl_backend.attach_camera
	detach_camera :: sdl_backend.detach_camera
	set_clip_rect :: sdl_backend.set_clip_rect
	end_clip_rect :: sdl_backend.end_clip_rect
	push_shader_state :: sdl_backend.push_shader_state
	pop_shader_state :: sdl_backend.pop_shader_state

	// files
	get_file_size :: sdl_backend.get_file_size
	load_file :: sdl_backend.load_file

	write_file :: sdl_backend.write_file

	// graphics
	create_texture :: sdl_backend.create_texture
	create_canvas :: sdl_backend.create_canvas
	push_canvas :: sdl_backend.push_canvas
	pop_canvas :: sdl_backend.pop_canvas
	destroy_all_textures :: sdl_backend.destroy_all_textures
	get_window_size :: sdl_backend.get_window_size
	get_render_size :: sdl_backend.get_render_size

	// audio
	is_sound_playing :: sdl_backend.is_sound_playing
	pause_sound :: sdl_backend.pause_sound
	resume_sound :: sdl_backend.resume_sound
	set_sound_volume :: sdl_backend.set_sound_volume
	play_sound :: sdl_backend.play_sound
	destroy_all_sounds :: sdl_backend.destroy_all_sounds
	load_sound :: sdl_backend.load_sound

	// fonts
	destroy_all_fonts :: sdl_backend.destroy_all_fonts
	load_font :: sdl_backend.load_font
	measure_text :: sdl_backend.measure_text

	// text input
	start_text_input :: sdl_backend.start_text_input
	stop_text_input :: sdl_backend.stop_text_input
	get_text_input_buffer :: sdl_backend.get_text_input_buffer

	// gamepad
	gamepad_rumble :: sdl_backend.gamepad_rumble
	set_deadzone :: sdl_backend.set_deadzone
	get_deadzone :: sdl_backend.get_deadzone

	// shaders
	shader_create_info :: sdl_backend.shader_create_info
	destroy_all_shaders :: sdl_backend.destroy_all_shaders
	set_gpu_fragment_shader_uniforms :: sdl_backend.set_gpu_fragment_shader_uniforms

	// logger
	logger :: sdl_backend.logger

	// memory
	free_mem :: sdl_backend.free_mem
}

when BACKEND == "opengl" {
	// main procs
	init :: opengl_backend.init
	update_input :: opengl_backend.update_input
	shutdown :: opengl_backend.shutdown

	// update loop
	get_performance_frequency :: opengl_backend.get_performance_frequency
	get_performance_counter :: opengl_backend.get_performance_counter

	// draw procs
	begin_frame :: opengl_backend.begin_frame
	end_frame :: opengl_backend.end_frame
	clear_screen :: opengl_backend.clear_screen
	draw_rect :: opengl_backend.draw_rect
	draw_rect_line :: opengl_backend.draw_rect_line
	draw_circle :: opengl_backend.draw_circle
	draw_arc :: opengl_backend.draw_arc
	draw_sprite :: opengl_backend.draw_sprite
	draw_debug_text :: opengl_backend.draw_debug_text
	draw_text :: opengl_backend.draw_text
	attach_camera :: opengl_backend.attach_camera
	detach_camera :: opengl_backend.detach_camera
	set_clip_rect :: opengl_backend.set_clip_rect
	end_clip_rect :: opengl_backend.end_clip_rect
	push_shader_state :: opengl_backend.push_shader_state
	pop_shader_state :: opengl_backend.pop_shader_state

	// files
	get_file_size :: opengl_backend.get_file_size
	load_file :: opengl_backend.load_file

	write_file :: opengl_backend.write_file

	// graphics
	create_texture :: opengl_backend.create_texture
	create_canvas :: opengl_backend.create_canvas
	push_canvas :: opengl_backend.push_canvas
	pop_canvas :: opengl_backend.pop_canvas
	destroy_all_textures :: opengl_backend.destroy_all_textures
	get_window_size :: opengl_backend.get_window_size
	get_render_size :: opengl_backend.get_render_size

	// audio
	is_sound_playing :: opengl_backend.is_sound_playing
	pause_sound :: opengl_backend.pause_sound
	resume_sound :: opengl_backend.resume_sound
	set_sound_volume :: opengl_backend.set_sound_volume
	play_sound :: opengl_backend.play_sound
	destroy_all_sounds :: opengl_backend.destroy_all_sounds
	load_sound :: opengl_backend.load_sound

	// fonts
	destroy_all_fonts :: opengl_backend.destroy_all_fonts
	load_font :: opengl_backend.load_font
	measure_text :: opengl_backend.measure_text

	// text input
	start_text_input :: opengl_backend.start_text_input
	stop_text_input :: opengl_backend.stop_text_input
	get_text_input_buffer :: opengl_backend.get_text_input_buffer

	// gamepad
	gamepad_rumble :: opengl_backend.gamepad_rumble
	set_deadzone :: opengl_backend.set_deadzone
	get_deadzone :: opengl_backend.get_deadzone

	// shaders
	shader_create_info :: opengl_backend.shader_create_info
	destroy_all_shaders :: opengl_backend.destroy_all_shaders
	set_gpu_fragment_shader_uniforms :: opengl_backend.set_gpu_fragment_shader_uniforms

	// logger
	logger :: opengl_backend.logger

	// memory
	free_mem :: opengl_backend.free_mem
}
