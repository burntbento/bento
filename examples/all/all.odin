package all

import "core:fmt"
import "core:os"


main :: proc() {
	info, _ := os.read_all_directory_by_path("examples", context.temp_allocator)
	if err := run(info); err != nil {
		os.print_error(os.stderr, err, "failed to execute examples")
	}
}

run :: proc(examples: []os.File_Info) -> (err: os.Error) {

	for example in examples {

		if example.type != .Directory || example.name == "all" do continue

		arg := fmt.tprintf("example=%s", example.name)

		p: os.Process; {
			p = os.process_start({command = {"make", "run-example", arg}}) or_return
		}

		_ = os.process_wait(p) or_return
	}

	return
}
