APP_NAME    = VoiceInput
BUNDLE_ID   = com.voiceinput.app
BUILD_DIR   = .build
RELEASE_DIR = $(BUILD_DIR)/apple/Products/Release
APP_BUNDLE  = $(APP_NAME).app
INSTALL_DIR = /Applications

.PHONY: build app run install clean

# ─── Build binary ────────────────────────────────────────────────────────────
build:
	swift build -c release

# ─── Assemble .app bundle ────────────────────────────────────────────────────
app: build
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@# Try Xcode-style output path first, then fallback to plain release
	@if [ -f "$(RELEASE_DIR)/$(APP_NAME)" ]; then \
		cp "$(RELEASE_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"; \
	else \
		cp "$(BUILD_DIR)/release/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"; \
	fi
	@cp "Sources/VoiceInput/Resources/Info.plist" "$(APP_BUNDLE)/Contents/"
	@# Ad-hoc sign (allows Accessibility + Microphone entitlements to be requested at runtime)
	@codesign --force --deep --sign - \
		--entitlements "$(APP_NAME).entitlements" \
		"$(APP_BUNDLE)" 2>/dev/null || \
	codesign --force --deep --sign - "$(APP_BUNDLE)"
	@echo "✓ Built $(APP_BUNDLE)"

# ─── Run directly ────────────────────────────────────────────────────────────
run: app
	@open "$(APP_BUNDLE)"

# ─── Install to /Applications ────────────────────────────────────────────────
install: app
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "✓ Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"

# ─── Clean ───────────────────────────────────────────────────────────────────
clean:
	@rm -rf "$(BUILD_DIR)" "$(APP_BUNDLE)"
	@echo "✓ Cleaned"
