APP_NAME := Heycast
BUNDLE_ID := $(shell plutil -extract CFBundleIdentifier raw -o - Resources/Info.plist)

# Command Line Tools ship Testing.framework and its macro plugin, but SwiftPM
# only points the compiler at the plugin in an Xcode toolchain layout. Pass it
# explicitly when Xcode is absent; an Xcode toolchain needs no help.
ifeq ($(shell xcode-select -p 2>/dev/null),/Library/Developer/CommandLineTools)
SWIFT_USR := $(subst /bin/swift,,$(shell xcrun --find swift 2>/dev/null))/
TESTING_PLUGIN := $(SWIFT_USR)lib/swift/host/plugins/testing/libTestingMacros.dylib
TEST_PLUGIN_FLAGS := $(if $(wildcard $(TESTING_PLUGIN)),-Xswiftc -load-plugin-library -Xswiftc $(TESTING_PLUGIN))
endif

.PHONY: run test bundle stop reset-permissions dev-cert clean

# scripts/dev.sh owns bundle assembly so there is one build path; use
# `make bundle` for the release artifacts under dist/.
run:
	./scripts/dev.sh

bundle:
	./scripts/bundle.sh

# Unit tests for the pure logic: search ranking, usage scoring, config paths.
test:
	swift test $(TEST_PLUGIN_FLAGS)

stop:
	-@killall $(APP_NAME) 2>/dev/null

# Clear every TCC answer and the first-run flag so the wizard starts over.
# Useful after changing what the wizard asks for; ad-hoc rebuilds lose the
# grants anyway.
reset-permissions:
	-@tccutil reset All $(BUNDLE_ID)
	-@defaults delete $(BUNDLE_ID) setup.wizard.shown

# One-time: a stable self-signed identity so TCC grants survive rebuilds.
dev-cert:
	./scripts/dev-cert.sh

clean:
	swift package clean
	rm -rf dist
