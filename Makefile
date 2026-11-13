SHELL := /bin/zsh

FVM_BIN := $(HOME)/.pub-cache/bin/fvm

# Use FVM when available, otherwise fallback to global Flutter.
FLUTTER := $(shell if [ -x "$(FVM_BIN)" ]; then echo '$(FVM_BIN) flutter'; elif command -v fvm >/dev/null 2>&1; then echo 'fvm flutter'; else echo 'flutter'; fi)

BUILD_DIR := build/macos/Build/Products/Release
DIST_DIR := dist
DMG_NAME := Witrack.dmg
DMG_PATH := $(DIST_DIR)/$(DMG_NAME)

.PHONY: help install cleare clean run-mac create-dmg

help:
	@echo "Available targets:"
	@echo "  make install     - Run flutter pub get"
	@echo "  make cleare      - Clear Flutter/Dart caches and clean build outputs"
	@echo "  make run-mac     - Run app on macOS"
	@echo "  make create-dmg  - Build macOS release app and package DMG"

install:
	$(FLUTTER) pub get

# Keep user's requested name; also provide 'clean' alias.
cleare:
	$(FLUTTER) clean
	@dart pub cache repair >/dev/null 2>&1 || true
	@rm -rf $(DIST_DIR)

clean: cleare

run-mac:
	$(FLUTTER) run -d macos

create-dmg:
	$(FLUTTER) build macos --release
	@mkdir -p $(DIST_DIR)
	@APP_BUNDLE="$$(find "$(BUILD_DIR)" -maxdepth 1 -type d -name '*.app' | head -n 1)"; \
	if [ -z "$$APP_BUNDLE" ]; then \
		echo "No .app bundle found in $(BUILD_DIR)."; \
		exit 1; \
	fi; \
	rm -f "$(DMG_PATH)"; \
	hdiutil create -volname "Witrack" -srcfolder "$$APP_BUNDLE" -ov -format UDZO "$(DMG_PATH)"
	@echo "DMG created at $(DMG_PATH)"
