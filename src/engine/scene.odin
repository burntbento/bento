package engine

/*
	 I explicitly added the destroy proc that is separated from the on_exit proc. This is to mirror the init proc where init pairs with destory and on_enter pairs with on_exit. Some bugs arose as some scenes would try to load and if there are more than one trying to load it would fail and try unmount with a on_exit, leading to bad pointer frees as on exit frees all things allocated to on enter. This new approach means that if it now fails it will just free all allocated in init and thats all since on enter never ran.

	 For any creation of a scene it should always be paired with a assert_scene(scene) this ensures if anything else is added that must be there can be caught at runtime.
*/

Scene :: struct {
	on_enter:      proc(self: ^Scene),
	update:        proc(self: ^Scene, input: ^GameInput, dt: f64),
	render:        proc(self: ^Scene),
	on_exit:       proc(self: ^Scene),
	on_pause:      proc(self: ^Scene),
	on_resume:     proc(self: ^Scene),
	destroy:       proc(self: ^Scene),
	draws_below:   bool,
	updates_below: bool,
	platform:      ^Platform,
	state:         ^GameState,
	ctx:           rawptr,
}


assert_scene :: proc(scene: ^Scene, loc := #caller_location) {
	assert(scene.destroy != nil, "The destroy proc must be set", loc)
}
