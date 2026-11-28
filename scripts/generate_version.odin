package scripts

import "bento:engine"
import "core:fmt"
import "core:os"
import "core:strings"

OUTPUT_FILE :: "src/engine/generated_version.odin"

main :: proc() {

	arg := ""
	if len(os.args) > 1 {
		arg = os.args[1]
	}

	f, _ := os.open(
		OUTPUT_FILE,
		{.Write, .Create, .Trunc},
		{.Write_User, .Read_Other, .Read_Group},
	)
	defer os.close(f)

	version := ""
	if arg != "clean" {
		version = engine.create_version(false, context.temp_allocator)
	}

	b := strings.builder_make(context.temp_allocator)
	file_str := `
// THIS IS GENERATED. DO NOT EDIT.
package engine


VERSION :: "`
	strings.write_string(&b, file_str)
	strings.write_string(&b, version)
	strings.write_string(&b, "\"")
	content := strings.to_string(b)
	fmt.fprintln(f, content)
}
