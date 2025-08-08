# Makefile for Apple Calendar MCP

.PHONY: build run test clean install help

# Default target
help:
	@echo "Available targets:"
	@echo "  build     - Build the project"
	@echo "  run       - Run the server with --verbose"
	@echo "  test      - Run all tests"
	@echo "  clean     - Clean build artifacts"
	@echo "  install   - Install to system PATH"
	@echo "  help      - Show this help"

build:
	swift build

run:
	swift run apple-cal-mcp --verbose

test:
	swift test

clean:
	swift package clean

install:
	./scripts/ops/install.sh

# Release build
release:
	swift build -c release