package platform_opengl

import "bento:engine"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"


set_renderer_draw_color :: proc(r, g, b, a: u8) -> bool {
	return false
}

create_canvas :: proc(width, height: int) -> int {
	return -1
}

push_canvas :: proc(canvas: int) {}

pop_canvas :: proc() {}

// drawing


begin_frame :: proc() {}

end_frame :: proc() {
	sdl.GL_SwapWindow(window)
	gl.Flush()
}

clear_screen :: proc(color: engine.Color) {
	gl_color := engine_color_to_gl_color(color)
	gl.ClearColor(gl_color.r, gl_color.g, gl_color.b, gl_color.a)
	gl.Clear(gl.COLOR_BUFFER_BIT)
}


draw_rect :: proc(rect: engine.Rect, color: engine.Color) {
	// just in case, i had w, h = 0 and i thought i was going crazy
	engine.assert_rect(rect)

	shader_program := get_shader(basic_shader_handle)

	t_x, t_y, t_s := camera_translation_position(rect.x, rect.y, 1)

	vertices = {1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0}
	indicies = {0, 1, 3, 1, 2, 3}
	shader_bind_verticies(VBO, EBO, 3, 3)

	gl_color := engine_color_to_gl_color(color)
	v_color := gl.GetUniformLocation(shader_program.program, "vColor")
	if v_color == -1 {
		// log
		return
	}

	v_proj := gl.GetUniformLocation(shader_program.program, "v_proj")
	v_translation := gl.GetUniformLocation(shader_program.program, "v_translation")
	v_scale := gl.GetUniformLocation(shader_program.program, "v_scale")

	projection := glm.mat4Ortho3d(0, f32(w), f32(h), 0, -1, 1)
	translate := glm.mat4Translate({f32(t_x), f32(t_y), 0})
	scale := glm.mat4Scale({f32(rect.width * t_s), f32(rect.height * t_s), 1})

	gl.UseProgram(shader_program.program)

	gl.Uniform4f(v_color, gl_color.r, gl_color.g, gl_color.b, gl_color.a)

	gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)

	gl.UniformMatrix4fv(v_proj, 1, gl.FALSE, &projection[0][0])
	gl.UniformMatrix4fv(v_translation, 1, gl.FALSE, &translate[0][0])
	gl.UniformMatrix4fv(v_scale, 1, gl.FALSE, &scale[0][0])

	gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)
}

draw_rect_line :: proc(rect: engine.Rect, color: engine.Color) {
	// just in case, i had w, h = 0 and i thought i was going crazy
	engine.assert_rect(rect)

	shader_program := get_shader(basic_shader_handle)

	t_x, t_y, t_s := camera_translation_position(rect.x, rect.y, 1)

	vertices = {1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0}
	indicies = {0, 1, 2, 3, 0, 0}
	shader_bind_verticies(VBO, EBO, 3, 3)

	gl_color := engine_color_to_gl_color(color)
	v_color := gl.GetUniformLocation(shader_program.program, "vColor")
	if v_color == -1 {
		// log
		return
	}
	v_proj := gl.GetUniformLocation(shader_program.program, "v_proj")
	v_translation := gl.GetUniformLocation(shader_program.program, "v_translation")
	v_scale := gl.GetUniformLocation(shader_program.program, "v_scale")

	projection := glm.mat4Ortho3d(0, f32(w), f32(h), 0, -1, 1)
	translate := glm.mat4Translate({f32(t_x), f32(t_y), 0})
	scale := glm.mat4Scale({f32(rect.width * t_s), f32(rect.height * t_s), 1})

	gl.UseProgram(shader_program.program)

	gl.Uniform4f(v_color, gl_color.r, gl_color.g, gl_color.b, gl_color.a)

	gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)

	gl.UniformMatrix4fv(v_proj, 1, gl.FALSE, &projection[0][0])
	gl.UniformMatrix4fv(v_translation, 1, gl.FALSE, &translate[0][0])
	gl.UniformMatrix4fv(v_scale, 1, gl.FALSE, &scale[0][0])

	gl.DrawElements(gl.LINE_LOOP, 4, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)
}

draw_circle :: proc(circle: engine.Circle, color: engine.Color) {}

draw_arc :: proc(
	center: engine.Vector2,
	radius, start_angle, end_angle, thickness: f32,
	color: engine.Color,
) {}

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
	handle := Textures[texture_handle]

	shader_program := get_shader(texture_shader_handle)

	// t_x, t_y, t_s := camera_translation_position(position.x, position.y, 1)

	// gl_color := engine_color_to_gl_color(color)
	// v_color := gl.GetUniformLocation(shader_program.program, "vColor")
	// if v_color == -1 {
	// 	// log
	// 	return
	// }
	//
	// v_proj := gl.GetUniformLocation(shader_program.program, "v_proj")
	// v_translation := gl.GetUniformLocation(shader_program.program, "v_translation")
	// v_scale := gl.GetUniformLocation(shader_program.program, "v_scale")
	//
	// projection := glm.mat4Ortho3d(0, f32(w), f32(h), 0, -1, 1)
	// translate := glm.mat4Translate({f32(t_x), f32(t_y), 0})
	// scale := glm.mat4Scale({f32(texture_rect.width * t_s), f32(texture_rect.height * t_s), 1})

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, handle)

	gl.UseProgram(shader_program.program)

	gl.Uniform1i(gl.GetUniformLocation(shader_program.program, "ourTexture"), 0)

	// gl.Uniform4f(v_color, gl_color.r, gl_color.g, gl_color.b, gl_color.a)

	// gl.UniformMatrix4fv(v_proj, 1, gl.FALSE, &projection[0][0])
	// gl.UniformMatrix4fv(v_translation, 1, gl.FALSE, &translate[0][0])
	// gl.UniformMatrix4fv(v_scale, 1, gl.FALSE, &scale[0][0])

	// gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(VAO)
	gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)


}

set_clip_rect :: proc(rect: engine.Rect) {}

end_clip_rect :: proc() {}
