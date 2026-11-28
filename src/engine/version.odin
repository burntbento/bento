package engine

import "core:os"
import "core:strings"


get_version :: proc(allocator := context.allocator) -> string {
	if VERSION != "" {
		return VERSION
	}
	return create_version(allocator)
}

create_version :: proc(allocator := context.allocator) -> string {

	_, stdout, _, err := os.process_exec(
		{
			command = {
				"git",
				"show",
				"--pretty=%cd",
				"--date=format:%Y-%m",
				"--no-patch",
				"--no-notes",
				"HEAD",
			},
		},
		context.temp_allocator,
	)
	if err != nil {
		return "no version"
	}

	_, sha, _, err2 := os.process_exec(
		{command = {"git", "show", "--pretty=\'%h\'", "--no-patch", "--no-notes", "HEAD"}},
		context.temp_allocator,
	)
	if err2 != nil {
		return "no version"
	}

	b := strings.builder_make(allocator)
	strings.write_string(&b, "dev-")
	strings.write_bytes(&b, stdout[:len(stdout) - 1])
	strings.write_string(&b, "-")
	strings.write_bytes(&b, sha[1:len(sha) - 2])
	return strings.to_string(b)
}
