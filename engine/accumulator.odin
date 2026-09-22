package engine

import "core:math"

accumulator: f64

accumulator_set :: proc(t: f64) {
	accumulator = t
}

accumulator_add :: proc(dt: f64) {
	if math.is_inf(accumulator) do accumulator_reset()
	accumulator += dt
}

accumulator_reset :: proc() {
	accumulator = 0
}
