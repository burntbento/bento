package engine


import vmem "core:mem/virtual"
/*
  Scene data structure and scene manager
*/

MAX_SCENES :: 5 // idk why you would go over 5 ever

SceneManager :: struct {
	stack:       [MAX_SCENES]^Scene,
	stack_count: int,
	next_cmd:    SceneCmd,
	state:       ^GameState,
	platform:    ^Platform,
}

SceneCmdReplace :: struct {
	scene: ^Scene,
}

SceneCmdPop :: struct {}

SceneCmdPush :: struct {
	scene: ^Scene,
}

SceneCmd :: union {
	SceneCmdReplace,
	SceneCmdPush,
	SceneCmdPop,
}

scene_manager_top :: proc(scene_manager: ^SceneManager) -> ^Scene {
	if scene_manager.stack_count == 0 {
		return nil
	}
	return scene_manager.stack[scene_manager.stack_count - 1]
}

scene_manager_new :: proc(
	platform: ^Platform,
	state: ^GameState,
	current_scene: ^Scene,
) -> ^SceneManager {

	scene_manager := new(SceneManager, state.global_allocator)
	scene_manager.state = state
	scene_manager.platform = platform

	scene_manager.stack[0] = current_scene
	scene_manager.stack_count = 1
	return scene_manager
}

scene_manager_clean :: proc(scene_manager: ^SceneManager) {
	// this is for when more than one cmd has been loaded, if there has already been one loaded then
	// we free the one trying to load.
	// TODO: have a explicit destroy proc instead of exit, might want exit transitions etc so
	// better to have destroy proc. Should also return a ok and let game layer handle the teardown

	cmd := scene_manager.next_cmd
	if cmd == nil do return
	switch v in cmd {
	case SceneCmdReplace:
		v.scene->destroy()
	case SceneCmdPush:
		v.scene->destroy()
	case SceneCmdPop:
	}
}

scene_manager_init :: proc(scene_manager: ^SceneManager) {
	top := scene_manager_top(scene_manager)
	if top != nil && top.on_enter != nil {
		top->on_enter()
	}
}


scene_manager_push :: proc(scene_manager: ^SceneManager, scene: ^Scene) {
	scene_manager_clean(scene_manager)
	check(scene_manager.stack_count < MAX_SCENES)
	scene_manager.next_cmd = SceneCmdPush{scene}
}

scene_manager_replace :: proc(scene_manager: ^SceneManager, scene: ^Scene) {
	scene_manager_clean(scene_manager)
	scene_manager.next_cmd = SceneCmdReplace{scene}
}

scene_manager_pop :: proc(scene_manager: ^SceneManager) {
	scene_manager_clean(scene_manager)
	scene_manager.next_cmd = SceneCmdPop{}
}

scene_manager_update :: proc(scene_manager: ^SceneManager, input: ^GameInput, dt: f64) {
	if scene_manager.next_cmd != nil {
		scene_manager_apply_cmd(scene_manager)
		return
	}

	if scene_manager.stack_count == 0 {
		panic("no current scene in scene manager")
	}

	start := scene_manager.stack_count - 1
	for start > 0 && scene_manager.stack[start].updates_below {
		start -= 1
	}

	for i in start ..< scene_manager.stack_count {
		scene := scene_manager.stack[i]
		if scene.update != nil {
			scene.update(scene, input, dt)
		}
	}
}

scene_manager_render :: proc(scene_manager: ^SceneManager) {
	if scene_manager.stack_count == 0 {
		return
	}

	start := scene_manager.stack_count - 1
	for start > 0 && scene_manager.stack[start].draws_below {
		start -= 1
	}

	for i in start ..< scene_manager.stack_count {
		scene := scene_manager.stack[i]
		if scene.render != nil {
			scene.render(scene)
		}
	}
}

scene_manager_destroy :: proc(scene_manager: ^SceneManager) {
	scene_manager_unwind(scene_manager)

	allocator := scene_manager.state.global_allocator
	free(scene_manager, allocator)
}


@(private)
scene_manager_apply_cmd :: proc(scene_manager: ^SceneManager) {
	cmd := scene_manager.next_cmd
	scene_manager.next_cmd = nil

	switch v in cmd {
	case SceneCmdPush:
		top := scene_manager_top(scene_manager)
		if top != nil && top.on_pause != nil {
			top->on_pause()
		}
		scene_manager.stack[scene_manager.stack_count] = v.scene
		scene_manager.stack_count += 1
		if v.scene.on_enter != nil {
			v.scene->on_enter()
		}
	case SceneCmdPop:
		if scene_manager.stack_count == 0 do return

		out := scene_manager.stack[scene_manager.stack_count - 1]
		if out.on_exit != nil {
			out->on_exit()
		}
		out->destroy()

		scene_manager.stack[scene_manager.stack_count - 1] = nil
		scene_manager.stack_count -= 1

		below := scene_manager_top(scene_manager)
		if below.on_resume != nil {
			below->on_resume()
		}
	case SceneCmdReplace:
		scene_manager_unwind(scene_manager)

		vmem.arena_free_all(&scene_manager.state.level_arena)

		scene_manager.stack[0] = v.scene
		scene_manager.stack_count = 1

		if v.scene.on_enter != nil {
			v.scene->on_enter()
		}
	}
}

@(private)
scene_manager_unwind :: proc(scene_manager: ^SceneManager) {
	for scene_manager.stack_count > 0 {
		scene := scene_manager.stack[scene_manager.stack_count - 1]
		if scene.on_exit != nil {
			scene->on_exit()
		}
		scene->destroy()

		scene_manager.stack[scene_manager.stack_count - 1] = nil
		scene_manager.stack_count -= 1
	}
}
