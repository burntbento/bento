package engine

import "core:mem"
/*
   Particles system package, some resources

   - https://natureofcode.com/particles/
   - https://www.gamedeveloper.com/programming/building-an-advanced-particle-system
   - http://buildnewgames.com/particle-systems/
   - https://love2d.org/wiki/ParticleSystem
*/

Emitter :: struct {
	position:   Vector2,
	rate:       f32,
	screen_dim: Vector2,
	amp:        f32,
	spawn:      proc(e: ^Emitter),
	update:     proc(e: ^Emitter, dt: f64),
	render:     proc(e: ^Emitter, cmdbuf: ^RenderCommandBuffer),
	pool:       [dynamic]Particle,
	count:      int,
	acc:        f32,
	allocator:  mem.Allocator,
}

Particle :: struct {
	position: Vector2,
	velocity: Vector2,
	scale:    f32,
	phase:    f32,
	freq:     f32,
	alpha:    f32,
	size:     f32,
	life:     f32,
}

particle_new :: proc(allocator := context.allocator) -> ^Emitter {
	emitter := new(Emitter, allocator)
	emitter.allocator = allocator
	emitter.pool = make([dynamic]Particle, allocator)
	return emitter
}

particle_emit :: proc(e: ^Emitter) {
	e->spawn()
}

particle_update :: proc(e: ^Emitter, dt: f64) {
	e->update(dt)
}

particle_render :: proc(e: ^Emitter, cmdbuf: ^RenderCommandBuffer) {
	e->render(cmdbuf)
}


particle_destroy :: proc(emitter: ^Emitter) {
	allocator := emitter.allocator
	delete(emitter.pool)
	free(emitter, allocator)
}
