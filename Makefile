.PHONY: help build test run open clean kill-stuck release dmg tv-info wake

# Configuration
PROJECT := SamsungRemote.xcodeproj
SCHEME := SamsungRemote
DERIVED := build/DerivedData
CONFIGURATION ?= Debug
APP := $(DERIVED)/Build/Products/$(CONFIGURATION)/SamsungRemote.app
PLATFORM := macOS
ARCH := arm64

# Note: Force arm64 (Apple Silicon native) to avoid Xcode planning hangs
# that can occur when multiple architectures are available (arm64/x86_64)
DESTINATION := platform=$(PLATFORM),arch=$(ARCH)

# Color output
CYAN := \033[0;36m
RESET := \033[0m

help:
	@echo "$(CYAN)Samsung Remote - Build commands$(RESET)"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  build              Compile the app (Debug)"
	@echo "  test               Run unit tests"
	@echo "  run                Build and launch the app"
	@echo "  release            Build Release configuration"
	@echo "  dmg                Build Release and package as .dmg"
	@echo "  open               Open project in Xcode"
	@echo "  clean              Remove build artifacts"
	@echo "  kill-stuck         Kill a stuck SWBBuildService (runs before build/test)"
	@echo "  tv-info IP=<ip>    Get TV info (model, power state, MAC)"
	@echo "  wake MAC=<mac>     Wake-on-LAN by command line"
	@echo "  help               Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make run"
	@echo "  make test"
	@echo "  make dmg"
	@echo "  make tv-info IP=192.168.0.50"
	@echo "  make wake MAC=AA:BB:CC:DD:EE:FF"

# SWBBuildService (Xcode's build daemon) occasionally leaks a pipe and hangs
# forever on the next build, with no error or timeout. Kill it before every
# build/test so a stale instance never blocks us; xcodebuild respawns a fresh
# one automatically.
kill-stuck:
	@pkill -9 -f SWBBuildService >/dev/null 2>&1 && echo "$(CYAN)Killed stuck SWBBuildService$(RESET)" || true

build: kill-stuck
	@echo "$(CYAN)Building SamsungRemote ($(ARCH), $(CONFIGURATION))...$(RESET)"
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		-configuration $(CONFIGURATION) \
		build < /dev/null

test: kill-stuck
	@echo "$(CYAN)Running tests ($(ARCH), $(CONFIGURATION))...$(RESET)"
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		-configuration $(CONFIGURATION) \
		test < /dev/null

release:
	@$(MAKE) build CONFIGURATION=Release

# Packages the Release .app into a distributable .dmg with a drag-to-Applications
# shortcut. Ad-hoc signed (ADR 0001, no paid developer account) — first launch on
# another Mac needs right-click > Open (Gatekeeper, unidentified developer).
dmg: release
	@echo "$(CYAN)Packaging .dmg...$(RESET)"
	rm -rf build/dmg-staging
	mkdir -p build/dmg-staging
	cp -R "$(DERIVED)/Build/Products/Release/SamsungRemote.app" build/dmg-staging/
	ln -s /Applications build/dmg-staging/Applications
	rm -f build/SamsungRemote.dmg
	hdiutil create -volname "Samsung Remote" -srcfolder build/dmg-staging -ov -format UDZO build/SamsungRemote.dmg
	rm -rf build/dmg-staging
	@echo "$(CYAN)build/SamsungRemote.dmg$(RESET)"

run: build
	@echo "$(CYAN)Launching SamsungRemote...$(RESET)"
	open "$(APP)"

open:
	open $(PROJECT)

clean:
	@echo "$(CYAN)Cleaning build artifacts...$(RESET)"
	rm -rf build/

tv-info:
	@if [ -z "$(IP)" ]; then \
		echo "Error: IP parameter required"; \
		echo "Usage: make tv-info IP=192.168.0.50"; \
		exit 1; \
	fi
	scripts/tv-info.sh $(IP)

wake:
	@if [ -z "$(MAC)" ]; then \
		echo "Error: MAC parameter required"; \
		echo "Usage: make wake MAC=AA:BB:CC:DD:EE:FF"; \
		exit 1; \
	fi
	python3 scripts/wake.py $(MAC)
