EXECUTABLE = RubberDuckWidget
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(EXECUTABLE).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS)/MacOS
RESOURCES_DIR = $(CONTENTS)/Resources

.PHONY: build bundle run clean

build:
	swift build -c release

bundle: build
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	@cp $(BUILD_DIR)/$(EXECUTABLE) $(MACOS_DIR)/
	@cp Info.plist $(CONTENTS)/
	@codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "✅ Built $(APP_BUNDLE)"

run: bundle
	@open $(APP_BUNDLE)

debug:
	swift build
	.build/debug/$(EXECUTABLE)

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
