
example ?= rectangle

run-example:
	odin run ./examples/$(example)/$(example).odin -file -collection:bento=src --debug

docs-build:
	mkdir -p ./website/static
	odin doc ./docs/docs.odin -file -all-packages -doc-format -collection:bento=src -out:./docs/docs
	cd ./website/static/ && odin-doc ../../docs/docs.odin-doc ../../docs/docs_config.json

docs-serve:
	npx wrangler dev


docs-clean:
	rm -rf website




