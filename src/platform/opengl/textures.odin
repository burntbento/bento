package platform_opengl

import gl "vendor:OpenGL"

@(private)
Textures: [dynamic]^TextureData

TextureData :: struct {
	tex:    u32,
	width:  int,
	height: int,
}

init_textures :: proc() {
	Textures = make([dynamic]^TextureData)
}

create_placeholder_texture :: proc() {}

// textures / canvas
create_texture :: proc(width, height, channels, bpp: int, data: ^u32) -> int {

	tex: u32
	gl.GenTextures(1, &tex)
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
		i32(width),
		i32(height),
		0,
		gl.RGBA,
		gl.UNSIGNED_BYTE,
		data,
	)
	gl.GenerateMipmap(gl.TEXTURE_2D)

	texture_data := new(TextureData)
	texture_data.tex = tex
	texture_data.width = width
	texture_data.height = height

	append(&Textures, texture_data)
	return len(Textures) - 1
}

destroy_all_textures :: proc() {
	for texture in Textures {
		free(texture)
	}
	delete(Textures)
}
