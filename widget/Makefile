EXECUTABLE = RubberDuckWidget
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(EXECUTABLE).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS)/MacOS
RESOURCES_DIR = $(CONTENTS)/Resources
ICON_OUT = .build/icon-out

# Distribution
DIST_DIR = .build/dist
DIST_APP = $(DIST_DIR)/DuckDuckDuck.app
DIST_ZIP = $(DIST_DIR)/DuckDuckDuck.zip
SIGN_IDENTITY = Developer ID Application: Daniel Deruntz (6E5CFN69H5)
NOTARY_PROFILE = notarytool-profile

.PHONY: build bundle run sandbox clean release dist sign notarize

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
	@cp -R $(BUILD_DIR)/$(EXECUTABLE)_$(EXECUTABLE).bundle $(RESOURCES_DIR)/
	@codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "✅ Built $(APP_BUNDLE)"

run: bundle
	@open $(APP_BUNDLE)

sandbox: bundle
	@echo "🔒 Re-signing with App Sandbox entitlements..."
	@codesign --force --deep --sign - --entitlements Sandbox.entitlements $(APP_BUNDLE)
	@echo "🔒 Launching in sandbox mode"
	@open $(APP_BUNDLE)

debug:
	swift build
	.build/debug/$(EXECUTABLE)

clean:
	swift package clean
	rm -rf $(APP_BUNDLE) $(DIST_DIR)

# --- Distribution ---

dist: bundle
	@rm -rf $(DIST_DIR)
	@mkdir -p $(DIST_DIR)
	@cp -R $(APP_BUNDLE) $(DIST_APP)
	@echo "✅ Copied to $(DIST_APP)"

sign: dist
	@codesign --force --deep --options runtime --sign "$(SIGN_IDENTITY)" $(DIST_APP)
	@echo "✅ Signed with Developer ID"

notarize: sign
	@cd $(DIST_DIR) && ditto -c -k --keepParent DuckDuckDuck.app DuckDuckDuck.zip
	@xcrun notarytool submit $(DIST_ZIP) --keychain-profile "$(NOTARY_PROFILE)" --wait
	@xcrun stapler staple $(DIST_APP)
	@cd $(DIST_DIR) && rm DuckDuckDuck.zip && ditto -c -k --keepParent DuckDuckDuck.app DuckDuckDuck.zip
	@echo "✅ Notarized and stapled → $(DIST_ZIP)"

release: notarize
	@echo "Ready to release $(DIST_ZIP)"
	@echo "Run: gh release create vX.Y $(DIST_ZIP) --title 'Duck Duck Duck vX.Y' --notes 'Release notes'"
