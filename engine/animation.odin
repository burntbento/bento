package engine

import "core:mem"
/*
   Simple animation system for now
   TODO: flesh out animation system further, map of animations
*/

Animation :: struct {
	width, height: int,
	animations:    map[string]AnimationState,
	current:       string,
	allocator:     mem.Allocator,
}

AnimationState :: struct {
	current_frame: int,
	duration:      f64,
	timer:         f64,
	row:           int,
	start_frame:   int,
	end_frame:     int,
	on_loop:       bool,
	finished:      bool,
}

animation_new :: proc(width, height: int, allocator := context.allocator) -> ^Animation {
	anim, err := new(Animation, allocator)
	ensure(err == nil)
	anim.animations = make(map[string]AnimationState, allocator)

	anim.width = width
	anim.height = height
	anim.allocator = allocator
	return anim
}

animation_add :: proc(
	anim: ^Animation,
	key: string,
	row: int,
	start_frame, frames: int,
	duration: f64,
	on_loop := true,
) -> bool {
	if _, ok := anim.animations[key]; ok {
		// already there
		return false
	}
	anim.animations[key] = AnimationState {
		duration      = duration,
		timer         = 0,
		current_frame = start_frame,
		start_frame   = start_frame,
		end_frame     = start_frame + frames,
		row           = row,
		on_loop       = on_loop,
		finished      = false,
	}
	return true
}


animation_update :: proc(anim: ^Animation, dt: f64) {
	frames, ok := &anim.animations[anim.current]
	if !ok {
		panic("animation not found!")
	}
	if frames.finished do return
	frames.timer += dt
	if (frames.timer >= frames.duration) {
		frames.timer -= frames.duration
		frames.current_frame += 1
		if frames.current_frame > frames.end_frame - 1 {
			if frames.on_loop {
				frames.current_frame = frames.start_frame
			} else {
				frames.current_frame -= 1
				frames.finished = true
			}
		}
	}
}

animation_destroy :: proc(anim: ^Animation) {
	allocator := anim.allocator
	delete(anim.animations)
	free(anim, allocator)
}

animation_switch :: proc(anim: ^Animation, new_animation: string) -> bool {
	new_anim, ok := &anim.animations[new_animation]
	if !ok {
		return false
	}
	if anim.current == new_animation {
		return true
	}

	anim.current = new_animation
	if !new_anim.on_loop && new_anim.finished {
		// restart
		new_anim.finished = false
		new_anim.current_frame = new_anim.start_frame
	}
	new_anim.timer = 0
	return true
}

animation_get_current_frame_dimensions :: proc(anim: ^Animation) -> (int, int) {
	return anim.animations[anim.current].current_frame * anim.width,
		anim.height * anim.animations[anim.current].row

}
