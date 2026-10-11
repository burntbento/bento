package platform_opengl

import "bento:engine"
import "core:c"
import glm "core:math/linalg/glsl"
import "core:strings"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

text_engine: ^ttf.TextEngine
fonts: [dynamic]^ttf.Font

// text
destroy_all_fonts :: proc() {
	for font in fonts {
		ttf.CloseFont(font)
	}
	delete(fonts)
}

load_font :: proc(path: string, size: f32) -> int {
	cpath := strings.clone_to_cstring(path)
	defer delete(cpath)
	font := ttf.OpenFont(cpath, size)
	if font == nil {
		sdl.LogError(
			cast(i32)sdl.LogCategory.CUSTOM,
			"SDL could not load font: %s",
			sdl.GetError(),
		)
	}
	append(&fonts, font)
	return len(fonts) - 1
}

measure_text :: proc(font_handle: int, text: string) -> (width: int, height: int) {
	if font_handle < 0 || font_handle >= len(fonts) do return 0, 0
	w, h: c.int
	if !ttf.GetStringSize(fonts[font_handle], raw_data(text), len(text), &w, &h) {
		return 0, 0
	}
	return int(w), int(h)
}

draw_text :: proc(position: engine.Vector2, text: string, font_handle: int, color: engine.Color) {

	t_x, t_y, t_s := camera_translation_position(position.x, position.y, 1)

	font := fonts[font_handle]

	text_surface := ttf.RenderText_Blended_Wrapped(
		font,
		raw_data(text),
		len(text),
		{color.r, color.g, color.b, color.a},
		0,
	)
	defer sdl.DestroySurface(text_surface)

	conv_surface := sdl.ConvertSurface(text_surface, sdl.PixelFormat.RGBA32)
	defer sdl.DestroySurface(conv_surface)

	text_w, text_h := conv_surface.w, conv_surface.h

	shader_program := get_shader(texture_shader_handle)

	v_proj := gl.GetUniformLocation(shader_program.program, "v_proj")
	v_translation := gl.GetUniformLocation(shader_program.program, "v_translation")
	v_scale := gl.GetUniformLocation(shader_program.program, "v_scale")
	uv_offset := gl.GetUniformLocation(shader_program.program, "uv_offset")
	uv_scale := gl.GetUniformLocation(shader_program.program, "uv_scale")

	projection := glm.mat4Ortho3d(0, f32(w), f32(h), 0, -1, 1)
	translate := glm.mat4Translate(
		{f32((t_x + f64(text_w / 2) * t_s)), f32((t_y + f64(text_h / 2) * t_s)), 0},
	)
	scale := glm.mat4Scale({f32(f64(text_w) * t_s), f32(f64(text_h) * t_s), 1})

	u0 := f32(0)
	v0 := f32(0)
	u1 := f32(1)
	v1 := f32(1)

	tex: u32
	gl.GenTextures(1, &tex)
	defer gl.DeleteTextures(1, &tex)

	gl.BindTexture(gl.TEXTURE_2D, tex)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	gl.BindVertexArray(VAO_t)
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RGBA,
		i32(text_w),
		i32(text_h),
		0,
		gl.RGBA,
		gl.UNSIGNED_BYTE,
		conv_surface.pixels,
	)
	gl.GenerateMipmap(gl.TEXTURE_2D)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, tex)

	gl.UseProgram(shader_program.program)
	location := gl.GetUniformLocation(shader_program.program, "texture1")
	ensure(location != -1)
	gl.Uniform1i(location, 0)


	// gl.Uniform4f(v_color, gl_color.r, gl_color.g, gl_color.b, gl_color.a)

	gl.UniformMatrix4fv(v_proj, 1, gl.FALSE, &projection[0][0])
	gl.UniformMatrix4fv(v_translation, 1, gl.FALSE, &translate[0][0])
	gl.UniformMatrix4fv(v_scale, 1, gl.FALSE, &scale[0][0])

	gl.Uniform2f(uv_offset, u0, v0)
	gl.Uniform2f(uv_scale, u1 - u0, v1 - v0)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	// gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(VAO_t)
	gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
	gl.BindVertexArray(0)

}


// deprecated below?

draw_debug_text :: proc(position: engine.Vector2, text: string, scale: f32, color: engine.Color) {}

start_text_input :: proc() {}

stop_text_input :: proc() {}

get_text_input_buffer :: proc() -> ([64]u8, int) {
	return {}, 0
}
