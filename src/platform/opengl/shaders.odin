package platform_opengl

import gl "vendor:OpenGL"


// -- Shaders -- //
basic_shader_handle: int
texture_shader_handle: int

triangle_vert_src := #load("../../../shaders/triangle.vert.glsl")
triangle_frag_src := #load("../../../shaders/triangle.frag.glsl")

textures_vert_src := #load("../../../shaders/textures.vert.glsl")
textures_frag_src := #load("../../../shaders/textures.frag.glsl")

ShaderProgram :: struct {
	program: u32,
}

MAX_SHADER_PROGRAMS :: 16
shaders: [MAX_SHADER_PROGRAMS]^ShaderProgram
shader_count: int

vertices: [12]f32
indicies: [6]u32

gl_texture: u32

VAO, VBO, EBO: u32
VAO_t, VBO_t, EBO_t: u32

@(private)
load_vertex_shader :: proc(vertex_src: []u8) -> u32 {
	// NOTE: Should error check
	vex_src := cstring(&vertex_src[0])
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)

	gl.ShaderSource(vertex_shader, 1, &vex_src, nil)
	gl.CompileShader(vertex_shader)
	return vertex_shader
}

@(private)
load_frag_shader :: proc(frag_src: []u8) -> u32 {
	frag_src := cstring(&frag_src[0])
	frag_shader := gl.CreateShader(gl.FRAGMENT_SHADER)

	gl.ShaderSource(frag_shader, 1, &frag_src, nil)
	gl.CompileShader(frag_shader)
	return frag_shader
}

@(private)
load_shader_program :: proc(vertex_src: []u8, frag_src: []u8) -> int {
	if shader_count > MAX_SHADER_PROGRAMS {
		logger(.ERROR, "Reached max shaders")
		return -1
	}

	vertex_shader := load_vertex_shader(vertex_src)
	defer gl.DeleteShader(vertex_shader)

	frag_shader := load_frag_shader(frag_src)
	defer gl.DeleteShader(frag_shader)

	program := gl.CreateProgram()

	gl.AttachShader(program, vertex_shader)
	gl.AttachShader(program, frag_shader)
	gl.LinkProgram(program)

	shader_program := new(ShaderProgram)
	shader_program.program = program

	shaders[shader_count] = shader_program
	shader_count += 1
	return shader_count
}

@(private)
get_shader :: proc(handle: int) -> ^ShaderProgram {
	if handle < 0 || handle > MAX_SHADER_PROGRAMS do return nil
	return shaders[handle - 1]
}

@(private)
init_shaders :: proc() {


	// vertex array
	gl.GenVertexArrays(1, &VAO)

	// vertex buffer
	gl.GenBuffers(1, &VBO)

	// element buffer
	gl.GenBuffers(1, &EBO)

	// vertex array
	gl.GenVertexArrays(1, &VAO_t)

	// vertex buffer
	gl.GenBuffers(1, &VBO_t)

	// element buffer
	gl.GenBuffers(1, &EBO_t)

	// texture
	gl.GenTextures(1, &gl_texture)


	// texture vertices

	// bind
	gl.BindVertexArray(VAO_t)

	verticies_t := [?]f32 {
		-0.5,
		-0.5,
		0.0,
		0.0,
		0.5,
		-0.5,
		1.0,
		0.0,
		0.5,
		0.5,
		1.0,
		1.0,
		0.5,
		0.5,
		1.0,
		1.0,
		-0.5,
		0.5,
		0.0,
		1.0,
		-0.5,
		-0.5,
		0.0,
		0.0,
	}

	// copy vertices for opengl to use
	gl.BindBuffer(gl.ARRAY_BUFFER, VBO_t)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(verticies_t), rawptr(&verticies_t), gl.STATIC_DRAW)

	// vertex attributes

	// position
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 2 * size_of(f32))
	gl.EnableVertexAttribArray(1)

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

	gl.DeleteBuffers(1, &VBO_t)
	gl.DeleteBuffers(1, &EBO_t)
	gl.DeleteVertexArrays(1, &VAO_t)

	gl.DeleteTextures(1, &gl_texture)

	// kill shaders
	for shader in shaders {
		if shader == nil do continue
		gl.DeleteShader(shader.program)
		free(shader)
	}
}
