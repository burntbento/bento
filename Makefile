
example ?= rectangle

flags = -file -vet -strict-style -vet-tabs -debug -warnings-as-errors -collection:bento=src

run-example:
	odin run ./examples/$(example)/$(example).odin $(flags)

run-all:
	odin run ./examples/all $(flags)

test:
	odin test ./tests --all-packages $(flags)






