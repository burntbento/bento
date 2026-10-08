package platform_opengl

import "bento:engine"
import "core:math"

// -- Camera -- //
camera_2d: ^engine.Camera2D

@(private)
camera_translation_position :: proc(x, y, scale: f64) -> (f64, f64, f64) {
	if camera_2d == nil do return x, y, scale
	pos := engine.camera_world_to_screen(camera_2d, engine.vector2(x, y))
	// NOTE: position needs to be rounded to nearest int otherwise
	// we have sub pixel rendering of textures -> little gaps/flashing
	return math.round(pos.x), math.round(pos.y), camera_2d.zoom * scale
}

attach_camera :: proc(cam: ^engine.Camera2D) {
	camera_2d = cam
}

detach_camera :: proc() {
	camera_2d = nil
}
