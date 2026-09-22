package engine

import "base:runtime"
import "core:fmt"


@(private)
ErrorContext :: struct {
	message:  string,
	location: runtime.Source_Code_Location,
}

/*
	Error types
*/
IO_ERROR :: distinct ErrorContext
VALUE_ERROR :: distinct ErrorContext

Error :: union {
	IO_ERROR,
	VALUE_ERROR,
}

/*
	 Returns the formatted string for the error.

	 The reciever owns the memory after and must destroy.
*/
fmt_error :: proc(error: Error, allocator := context.allocator) -> string {
	message: string
	location: runtime.Source_Code_Location
	switch v in error {
	case IO_ERROR:
		message = v.message
		location = v.location
	case VALUE_ERROR:
		message = v.message
		location = v.location
	}
	return fmt.aprintf("%v: %s", location, message, allocator = allocator)
}
