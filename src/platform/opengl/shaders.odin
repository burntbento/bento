package platform_opengl

import gl "vendor:OpenGL"


// -- Shaders -- //
triangle_vert_src := #load("../../../shaders/triangle.vert.glsl")
triangle_frag_src := #load("../../../shaders/triangle.frag.glsl")

shader_program: u32
vertex_shader: u32
frag_shader: u32

vertices: [12]f32
indicies: [6]u32

gl_texture: u32

VAO, VBO, EBO: u32

@(private)
init_shaders :: proc() {

	// NOTE: Should error check
	vex_src := cstring(&triangle_vert_src[0])
	vertex_shader = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, &vex_src, nil)
	gl.CompileShader(vertex_shader)

	frag_src := cstring(&triangle_frag_src[0])
	frag_shader = gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(frag_shader, 1, &frag_src, nil)
	gl.CompileShader(frag_shader)

	shader_program = gl.CreateProgram()

	gl.AttachShader(shader_program, vertex_shader)
	gl.AttachShader(shader_program, frag_shader)
	gl.LinkProgram(shader_program)


	// vertex array
	gl.GenVertexArrays(1, &VAO)

	// vertex buffer
	gl.GenBuffers(1, &VBO)

	// element buffer
	gl.GenBuffers(1, &EBO)

	// texture
	gl.GenTextures(1, &gl_texture)
}

shader_bind_verticies :: proc(vbo: u32, ebo: u32, size: int, stride: int) {

	// bind
	gl.BindVertexArray(VAO)

	// copy vertices for opengl to use
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), rawptr(&vertices), gl.STATIC_DRAW)

	// bind elements
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indicies), rawptr(&indicies), gl.STATIC_DRAW)

	// vertex attributes

	// position
	gl.VertexAttribPointer(0, i32(size), gl.FLOAT, gl.FALSE, i32(stride) * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)
}

destroy_all_shaders :: proc() {

	gl.DeleteBuffers(1, &VBO)
	gl.DeleteBuffers(1, &EBO)
	gl.DeleteVertexArrays(1, &VAO)
	gl.DeleteTextures(1, &gl_texture)

	gl.DeleteProgram(shader_program)
	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(frag_shader)
}
