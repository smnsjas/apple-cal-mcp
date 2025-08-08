# Makefile for Apple Calendar MCP

.PHONY: build run test clean install help lint fix-lint release

# Default target
help:
	@echo "Available targets:"
	@echo "  build     - Build the project"
	@echo "  run       - Run the server with --verbose"
	@echo "  test      - Run all tests"
	@echo "  lint      - Run SwiftLint (strict)"
	@echo "  fix-lint  - Run SwiftLint with autocorrect"
	@echo "  clean     - Clean build artifacts"
	@echo "  install   - Install to system PATH"
	@echo "  release   - Build release configuration"
	@echo "  help      - Show this help"

build:
	swift build

run:
	swift run apple-cal-mcp --verbose

test:
	swift test

lint:
	@./scripts/dev/lint.sh

fix-lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint --autocorrect; \
	else \
		echo "SwiftLint not found. Install with: brew install swiftlint" >&2; \
		exit 127; \
	fi

clean:
	swift package clean

install:
	./scripts/ops/install.sh

# Release build
release:
	swift build -c release