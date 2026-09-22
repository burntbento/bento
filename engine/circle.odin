package engine


Circle :: struct {
	position: Vector2,
	radius:   f64,
}

circle :: #force_inline proc(x: f64, y: f64, r: f64) -> Circle {
	assert(r > 0.0, "Circle needs a positive radius")
	return Circle{position = vector2(x, y), radius = r}
}
