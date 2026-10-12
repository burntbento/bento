
example ?= rectangle
backend ?= sdl

flags = -file -vet -strict-style -vet-tabs -warnings-as-errors -collection:bento=src -define:BACKEND=$(backend)

run-example:
	odin run ./examples/$(example)/$(example).odin $(flags)






