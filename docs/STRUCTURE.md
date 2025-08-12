# Project Structure

Clean, organized codebase for the Apple Calendar MCP server.

## Source Code Organization

```text
Sources/AppleCalendarMCP/
├── App/main.swift                    # Application entry point
├── Core/                            # MCP protocol implementation
│   ├── JSONRPCHandler.swift         # Tool routing & schema
│   ├── MCPServer.swift              # MCP server & communication
│   └── Models.swift                 # Request/response types
├── Calendar/                        # Calendar functionality
│   ├── CalendarManager.swift        # EventKit integration
│   ├── CalendarFiltering.swift      # Smart filtering
│   └── ConflictAnalyzer.swift       # Availability analysis
└── Utils/DateUtils.swift            # Date/time utilities
```

## Documentation Structure

```text
docs/
├── FEATURES.md          # Complete feature guide
├── TESTING.md           # Testing guide & structure
├── STRUCTURE.md         # This file
├── CLAUDE.md           # Claude Code guidance
├── CODE_OF_CONDUCT.md  # Community guidelines
└── CONTRIBUTING.md     # Development setup
```

## Testing & Development Structure

```text
Tests/                              # Swift unit tests only
└── AppleCalendarMCPTests/
    ├── AppleCalendarMCPTests.swift
    ├── ConflictAnalyzerTests.swift
    ├── DateUtilsTests.swift
    └── JSONRPCHandlerTests.swift

tools/                              # Development & integration tools
├── test_comprehensive.py          # Main integration test
├── test_calendar_filtering.py     # Filtering tests
├── test_conflict_reasoning.py     # Conflict logic tests
├── test_full_mcp.py               # Full MCP protocol test
├── test_with_events.py            # Event-based tests
├── test-integration.sh            # Integration test runner
└── mcp-debug.py                   # Unified debugging tool

scripts/dev/                        # Build & development scripts
├── test.sh                        # Run all tests
├── run.sh                         # Run server with --verbose
└── lint.sh                        # Code formatting
```

## Common Development Commands

### Build & Test

```bash
swift build                         # Build project
swift test                          # Unit tests
./scripts/dev/test.sh              # All tests
python3 test_comprehensive.py      # Integration tests
```

### Run & Debug

```bash
swift run apple-cal-mcp --verbose  # Run with debug logging
./scripts/dev/run.sh               # Convenience wrapper
```

### Install

```bash
./install.sh                       # Install to /usr/local/bin
```

## Key Files

| File                    | Purpose                        |
| ----------------------- | ------------------------------ |
| `README.md`             | Project overview & quick start |
| `install.sh`            | Installation script            |
| `Package.swift`         | Swift package configuration    |
| `Makefile`              | Build automation               |
| `test_comprehensive.py` | Main integration test          |

## Architecture Overview

The server implements the MCP (Model Context Protocol) specification with:

- **JSON-RPC 2.0** communication over stdin/stdout
- **EventKit integration** for native macOS calendar access
- **7 MCP tools** for calendar operations
- **Smart filtering** and conflict detection
- **Event management** with CRUD operations

All Swift code is organized under the single `AppleCalendarMCP` target for simplicity.
