APP_NAME := Heycast
CONFIG   := release
BIN_DIR  := .build/$(CONFIG)
BUNDLE   := .build/$(APP_NAME).app

.PHONY: build run stop clean

build:
	swift build -c $(CONFIG)
	rm -rf "$(BUNDLE)"
	mkdir -p "$(BUNDLE)/Contents/MacOS" "$(BUNDLE)/Contents/Resources"
	cp "$(BIN_DIR)/$(APP_NAME)" "$(BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(BUNDLE)/Contents/Info.plist"
	codesign --force --sign - "$(BUNDLE)"

run: build
	open "$(BUNDLE)"

stop:
	-@killall $(APP_NAME) 2>/dev/null

clean:
	swift package clean
	rm -rf .build/$(APP_NAME).app
