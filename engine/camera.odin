package engine

import "core:math"

lerpSmoother :: struct {
	speed: f64,
}

linearSmoother :: struct {
	speed: f64,
}

Smoother :: union {
	lerpSmoother,
	linearSmoother,
}

Camera2D :: struct {
	target:   Vector2,
	offset:   Vector2,
	rotation: f64,
	zoom:     f64,
	smoother: Smoother,
}

camera_init :: proc(
	x: f64 = 0.0,
	y: f64 = 0.0,
	offset_x: f64 = 0.0,
	offset_y: f64 = 0.0,
	rotation: f64 = 0.0,
	zoom: f64 = 1.0,
	smoother: Smoother = nil,
	allocator := context.allocator,
) -> ^Camera2D {
	cam := new(Camera2D, allocator)
	cam.target.x = x
	cam.target.y = y
	cam.offset = vector2(offset_x, offset_y)
	cam.rotation = rotation
	cam.zoom = zoom
	cam.smoother = smoother
	return cam
}

@(private)
update_smoother_lerp :: proc(cam: ^Camera2D, dx, dy, speed, dt: f64) {
	assert(speed >= 0.0)
	t := 1.0 - math.exp(-speed * dt)
	cam.target.x += (dx) * t
	cam.target.y += (dy) * t
}

@(private)
update_smoother_linear :: proc(cam: ^Camera2D, dx, dy, speed, dt: f64) {
	assert(speed >= 0.0)
	udx, udy := dx, dy
	// normalise direction
	d := math.sqrt(dx * dx + dy * dy)
	dts := math.min(speed * dt, d)
	if d > 0 {
		udx, udy = dx / d, dy / d
	}
	cam.target.x += udx * dts
	cam.target.y += udy * dts
}

camera_update_smoother :: proc(cam: ^Camera2D, target: Vector2, dt: f64) {
	dx, dy := target.x - cam.target.x, target.y - cam.target.y
	switch v in cam.smoother {
	case lerpSmoother:
		update_smoother_lerp(cam, dx, dy, v.speed, dt)
	case linearSmoother:
		update_smoother_linear(cam, dx, dy, v.speed, dt)
	case:
		cam.target.x = target.x
		cam.target.y = target.y
	}
}

camera_update :: proc(cam: ^Camera2D, target: Vector2, dt: f64) {
	camera_update_smoother(cam, target, dt)
}

camera_destroy :: proc(cam: ^Camera2D, allocator := context.allocator) {
	free(cam, allocator)
}

camera_world_to_screen :: proc(cam: ^Camera2D, position: Vector2) -> Vector2 {
	rx := position.x - cam.target.x
	ry := position.y - cam.target.y
	return vector2(rx * cam.zoom + cam.offset.x, ry * cam.zoom + cam.offset.y)
}

camera_screen_to_world :: proc(cam: ^Camera2D, position: Vector2) -> Vector2 {
	rx := (position.x - cam.offset.x) / cam.zoom
	ry := (position.y - cam.offset.y) / cam.zoom
	return vector2(rx + cam.target.x, ry + cam.target.y)
}

camera_attach :: proc(cmdbuf: ^RenderCommandBuffer, cam: ^Camera2D) {
	cmd_attach_camera(cmdbuf, cam)
}

camera_detach :: proc(cmdbuf: ^RenderCommandBuffer) {
	cmd_detach_camera(cmdbuf)
}
