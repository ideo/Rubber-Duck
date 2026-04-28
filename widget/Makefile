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
DIST_DMG = $(DIST_DIR)/DuckDuckDuck.dmg
SIGN_IDENTITY = Developer ID Application: Daniel Deruntz (6E5CFN69H5)
NOTARY_PROFILE = notarytool-profile

.PHONY: build bundle run sandbox clean release dist sign notarize dmg

build:
	swift build -c release

icon:
	@mkdir -p $(ICON_OUT)
	@xcrun actool --compile $(ICON_OUT) \
		--platform macosx \
		--minimum-deployment-target 26.0 \
		--app-icon duckIcon \
		--output-partial-info-plist .build/icon-info.plist \
		assets/duckIcon.icon > /dev/null

bundle: build icon
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	@cp $(BUILD_DIR)/$(EXECUTABLE) $(MACOS_DIR)/
	@cp Info.plist $(CONTENTS)/
	@cp $(ICON_OUT)/duckIcon.icns $(RESOURCES_DIR)/
	@cp $(ICON_OUT)/Assets.car $(RESOURCES_DIR)/
	@cp -R $(BUILD_DIR)/$(EXECUTABLE)_$(EXECUTABLE).bundle $(RESOURCES_DIR)/
	@rm -rf $(RESOURCES_DIR)/plugin
	@cp -R ../plugin $(RESOURCES_DIR)/plugin
	@# Sanity check: bundled plugin/.claude-plugin/plugin.json must match source.
	@# Catches any pre-bundle staleness from a broken cache or partial copy.
	@diff -q ../plugin/.claude-plugin/plugin.json $(RESOURCES_DIR)/plugin/.claude-plugin/plugin.json > /dev/null \
		|| (echo "❌ Bundled plugin.json differs from source — build aborted"; exit 1)
	@PLUGIN_V=$$(python3 -c 'import json; print(json.load(open("../plugin/.claude-plugin/plugin.json"))["version"])'); \
		APP_V=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist); \
		echo "📦 Bundled plugin v$$PLUGIN_V in app v$$APP_V"
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
	@codesign --force --deep --options runtime --entitlements RubberDuck.entitlements --sign "$(SIGN_IDENTITY)" $(DIST_APP)
	@echo "✅ Signed with Developer ID"

notarize: sign
	@cd $(DIST_DIR) && ditto -c -k --keepParent DuckDuckDuck.app DuckDuckDuck.zip
	@xcrun notarytool submit $(DIST_ZIP) --keychain-profile "$(NOTARY_PROFILE)" --wait
	@xcrun stapler staple $(DIST_APP)
	@echo "✅ Notarized and stapled"

dmg: notarize
	@rm -f $(DIST_DMG)
	@mkdir -p $(DIST_DIR)/dmg-staging
	@cp -R $(DIST_APP) $(DIST_DIR)/dmg-staging/
	@ln -s /Applications $(DIST_DIR)/dmg-staging/Applications
	@hdiutil create -volname "Duck Duck Duck" \
		-srcfolder $(DIST_DIR)/dmg-staging \
		-ov -format UDZO \
		$(DIST_DMG)
	@rm -rf $(DIST_DIR)/dmg-staging
	@codesign --force --sign "$(SIGN_IDENTITY)" $(DIST_DMG)
	@xcrun notarytool submit $(DIST_DMG) --keychain-profile "$(NOTARY_PROFILE)" --wait
	@xcrun stapler staple $(DIST_DMG)
	@echo "✅ DMG ready → $(DIST_DMG)"

release: dmg plugin-zip
	@echo "Ready to release $(DIST_DMG) + $(PLUGIN_ZIP)"
	@echo "Run: gh release create vX.Y $(DIST_DMG) $(PLUGIN_ZIP) --title 'Duck Duck Duck vX.Y' --notes 'Release notes'"

# --- Plugin zip for Claude Desktop upload ---

PLUGIN_ZIP = $(DIST_DIR)/duck-duck-duck-plugin.zip

plugin-zip:
	@mkdir -p $(DIST_DIR)
	@rm -f $(PLUGIN_ZIP)
	@cd ../plugin && zip -r $(CURDIR)/$(PLUGIN_ZIP) .claude-plugin hooks -x "*.DS_Store"
	@echo "✅ Plugin zip → $(PLUGIN_ZIP)"
	@echo "   Upload via Claude Desktop → Settings → Plugins → Upload local plugin"

