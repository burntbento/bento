package engine

import "core:mem"

StateMachine :: struct {
	current:   string,
	next:      string,
	states:    map[string]State,
	allocator: mem.Allocator,
}

State :: struct {
	ctx:      rawptr,
	on_enter: proc(ctx: rawptr),
	on_exit:  proc(ctx: rawptr),
	update:   proc(ctx: rawptr, input: ^GameInput, dt: f64),
}


statemachine_new :: proc(allocator := context.allocator) -> ^StateMachine {
	sm := new(StateMachine, allocator)
	sm.allocator = allocator
	sm.states = make(map[string]State, allocator)
	return sm
}

statemachine_add_state :: proc(
	statemachine: ^StateMachine,
	key: string,
	on_enter: proc(ctx: rawptr),
	on_exit: proc(ctx: rawptr),
	update: proc(ctx: rawptr, input: ^GameInput, dt: f64),
) -> bool {

	if _, ok := statemachine.states[key]; ok {
		// duplicate
		return false
	}

	statemachine.states[key] = State {
		on_enter = on_enter,
		on_exit  = on_exit,
		update   = update,
	}
	return true
}


statemachine_update :: proc(statemachine: ^StateMachine, ctx: rawptr, input: ^GameInput, dt: f64) {
	if statemachine.current == "" do return
	current_state := statemachine.states[statemachine.current]
	if statemachine.next == "" {
		current_state.update(ctx, input, dt)
	} else {
		if current_state.on_exit != nil {
			current_state.on_exit(ctx)
		}
		statemachine.current = statemachine.next
		statemachine.next = ""
		if statemachine.states[statemachine.current].on_enter != nil {
			statemachine.states[statemachine.current].on_enter(ctx)
		}
	}
}


statemachine_destroy :: proc(statemachine: ^StateMachine) {
	allocator := statemachine.allocator
	delete(statemachine.states)
	free(statemachine, allocator)
}


statemachine_switch_state :: proc(statemachine: ^StateMachine, next_state: string) {
	if _, ok := statemachine.states[next_state]; ok {
		statemachine.next = next_state
	}
}
