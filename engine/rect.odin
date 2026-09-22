package engine

Rect :: struct {
	x:      f64,
	y:      f64,
	width:  f64,
	height: f64,
}

rect :: #force_inline proc(x, y, width, height: f64) -> Rect {
	return {x = x, y = y, width = width, height = height}
}

assert_rect :: #force_inline proc(r: Rect) {
	assert(r.width > 0)
	assert(r.height > 0)
}
