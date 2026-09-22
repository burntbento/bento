package engine

import "core:testing"

Vector2 :: struct {
	x: f64,
	y: f64,
}

vector2 :: #force_inline proc(x, y: f64) -> Vector2 {
	return {x = x, y = y}
}

vector2_add :: #force_inline proc(a, b: Vector2) -> Vector2 {
	return {x = a.x + b.x, y = a.y + b.y}
}

vector2_sub :: #force_inline proc(a, b: Vector2) -> Vector2 {
	return {x = a.x - b.x, y = a.y - b.y}
}

@(test)
test_add :: proc(t: ^testing.T) {
	a := vector2(2, 3)
	b := vector2(5, 6)
	expect := vector2(7, 9)
	testing.expect_value(t, vector2_add(a, b), expect)
}

@(test)
test_sub :: proc(t: ^testing.T) {
	a := vector2(5, 6)
	b := vector2(2, 3)
	expect := vector2(3, 3)
	testing.expect_value(t, vector2_sub(a, b), expect)
}
