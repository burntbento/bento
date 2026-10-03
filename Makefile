
example ?= rectangle

flags = -file -vet -strict-style -vet-tabs -warnings-as-errors -collection:bento=src

run-example:
	odin run ./examples/$(example)/$(example).odin $(flags)






