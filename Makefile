APP_NAME := Heycast

.PHONY: run bundle stop clean

# scripts/dev.sh owns bundle assembly so there is one build path; use
# `make bundle` for the release artifacts under dist/.
run:
	./scripts/dev.sh

bundle:
	./scripts/bundle.sh

stop:
	-@killall $(APP_NAME) 2>/dev/null

clean:
	swift package clean
	rm -rf dist
