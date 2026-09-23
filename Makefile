
example ?= rectangle

run-example:
	odin run ./examples/$(example)/$(example).odin -file -collection:bento=src --debug
