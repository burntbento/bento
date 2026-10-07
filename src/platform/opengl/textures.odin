package platform_opengl


@(private)
Textures: [dynamic]u32

init_textures :: proc() {
	Textures = make([dynamic]u32)
}

destroy_all_textures :: proc() {
	delete(Textures)
}
