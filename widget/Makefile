EXECUTABLE = RubberDuckWidget
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(EXECUTABLE).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS)/MacOS
RESOURCES_DIR = $(CONTENTS)/Resources
ICON_OUT = .build/icon-out

.PHONY: build bundle run clean

build:
	swift build -c release

icon:
	@mkdir -p $(ICON_OUT)
	@xcrun actool --compile $(ICON_OUT) \
		--platform macosx \
		--minimum-deployment-target 26.0 \
		--app-icon duckIcon \
		--output-partial-info-plist .build/icon-info.plist \
		assets/duckIcon.icon

bundle: build icon
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	@cp $(BUILD_DIR)/$(EXECUTABLE) $(MACOS_DIR)/
	@cp Info.plist $(CONTENTS)/
	@cp $(ICON_OUT)/duckIcon.icns $(RESOURCES_DIR)/
	@cp $(ICON_OUT)/Assets.car $(RESOURCES_DIR)/
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
