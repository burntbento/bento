package engine

import "core:fmt"


check :: #force_inline proc(condition: bool, loc := #caller_location) {
	if !condition {
		fmt.panicf("check failed at %v", loc)
	}
}
