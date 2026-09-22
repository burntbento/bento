package engine

import "core:mem"
import "core:testing"

/*
	 Signals package for a pub sub system.

	 based on https://hump.readthedocs.io/en/latest/signal.html
*/
Signals :: struct {
	registry:  map[string][dynamic]proc(),
	// procs
	register:  proc(self: ^Signals, event: string, callback: proc()) -> bool,
	emit:      proc(self: ^Signals, event: string) -> bool,
	clear:     proc(self: ^Signals, event: string) -> bool,
	delete:    proc(self: ^Signals, event: string) -> bool,
	reset:     proc(self: ^Signals),
	destroy:   proc(self: ^Signals),
	allocator: mem.Allocator,
}

signals_new :: proc(allocator := context.allocator) -> ^Signals {
	signals := new(Signals, allocator)
	signals.allocator = allocator
	signals.registry = make(map[string][dynamic]proc(), allocator)

	// procs
	signals.register = signals_register
	signals.emit = signals_emit
	signals.destroy = signals_destroy
	signals.clear = signals_clear_event
	signals.reset = signals_reset
	signals.delete = signals_delete_event
	return signals
}

signals_register :: proc(signals: ^Signals, event: string, callback: proc()) -> bool {
	if _, ok := signals.registry[event]; !ok {
		signals.registry[event] = make([dynamic]proc(), signals.allocator)
	}
	append(&signals.registry[event], callback)
	return true
}

signals_emit :: proc(signals: ^Signals, event: string) -> bool {
	callbacks, ok := signals.registry[event]
	if !ok {
		return false
	}
	// run callbacks
	for callback in callbacks {
		if callback == nil do continue
		callback()
	}

	return true
}

/*
	 Clear will clear the event array but keep the underlying memory allocation
*/
signals_clear_event :: proc(signals: ^Signals, event: string) -> bool {
	if _, ok := signals.registry[event]; !ok {
		return false
	}
	clear(&signals.registry[event])
	return true
}

/*
	 Deletes the array and key for event
*/
signals_delete_event :: proc(signals: ^Signals, event: string) -> bool {
	if _, ok := signals.registry[event]; !ok {
		return false
	}
	// delete array
	delete(signals.registry[event])
	// delete key
	delete_key(&signals.registry, event)
	return true
}

/*
	 Reset the signals registry, deletes arrays and keys. Zeros the underlying map.
*/
signals_reset :: proc(signals: ^Signals) {
	for key, callbacks in signals.registry {
		delete(callbacks)
		delete_key(&signals.registry, key)
	}
	clear_map(&signals.registry)
}


signals_destroy :: proc(signals: ^Signals) {
	allocator := signals.allocator
	for _, callbacks in signals.registry {
		delete(callbacks)
	}
	delete(signals.registry)
	free(signals, allocator)
}


@(test)
test_signals_register :: proc(t: ^testing.T) {
	signals := signals_new()
	defer signals->destroy()

	ok := signals->register("event", proc() {})
	testing.expect(t, ok)
}

@(test)
test_signals_reset :: proc(t: ^testing.T) {
	signals := signals_new()
	defer signals->destroy()

	ok := signals->register("event", proc() {})
	signals->reset()
	_, ok2 := signals.registry["event"]
	testing.expect(t, ok)
	testing.expect(t, !ok2)
}

@(test)
test_signals_delete_event :: proc(t: ^testing.T) {
	signals := signals_new()
	defer signals->destroy()

	ok := signals->register("event", proc() {})
	signals->delete("event")
	_, ok2 := signals.registry["event"]
	testing.expect(t, ok)
	testing.expect(t, !ok2)
}

@(test)
test_signals_clear_event :: proc(t: ^testing.T) {
	signals := signals_new()
	defer signals->destroy()

	ok := signals->register("event", proc() {})
	ok_clear := signals->clear("event")
	val, ok_get := signals.registry["event"]

	testing.expect(t, ok)
	testing.expect(t, ok_clear)
	testing.expect(t, ok_get)
	testing.expect_value(t, len(val), 0)
}
