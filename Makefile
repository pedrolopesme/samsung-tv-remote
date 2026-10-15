.PHONY: help build test run open clean kill-stuck tv-info wake

# Configuration
PROJECT := SamsungRemote.xcodeproj
SCHEME := SamsungRemote
DERIVED := build/DerivedData
APP := $(DERIVED)/Build/Products/Debug/SamsungRemote.app
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
	@echo "  make tv-info IP=192.168.0.50"
	@echo "  make wake MAC=AA:BB:CC:DD:EE:FF"

# SWBBuildService (Xcode's build daemon) occasionally leaks a pipe and hangs
# forever on the next build, with no error or timeout. Kill it before every
# build/test so a stale instance never blocks us; xcodebuild respawns a fresh
# one automatically.
kill-stuck:
	@pkill -9 -f SWBBuildService >/dev/null 2>&1 && echo "$(CYAN)Killed stuck SWBBuildService$(RESET)" || true

build: kill-stuck
	@echo "$(CYAN)Building SamsungRemote ($(ARCH))...$(RESET)"
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		build < /dev/null

test: kill-stuck
	@echo "$(CYAN)Running tests ($(ARCH))...$(RESET)"
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) \
		test < /dev/null

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
