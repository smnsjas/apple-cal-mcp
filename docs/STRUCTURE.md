# Project Structure

This document describes the organized project layout and how to use the various scripts and tools.

## Directory Organization

### Swift Source Code
```
Sources/
├── AppleCalendarMCP/
│   ├── App/              # Application entry point
│   │   └── main.swift
│   ├── Core/             # MCP protocol and server logic  
│   │   ├── JSONRPCHandler.swift
│   │   ├── MCPServer.swift
│   │   └── Models.swift
│   ├── Calendar/         # Calendar operations and analysis
│   │   ├── CalendarManager.swift
│   │   ├── CalendarFiltering.swift
│   │   └── ConflictAnalyzer.swift
│   └── Utils/            # Shared utilities
│       └── DateUtils.swift
```

### Scripts and Tools
```
scripts/
├── dev/                  # Development convenience scripts
│   ├── run.sh           # Run server with --verbose
│   └── test.sh          # Run swift test
├── ops/                 # Operations and deployment
│   └── install.sh       # Install to system PATH
└── mcp/                 # MCP testing scripts
    ├── test_mcp.sh      # Basic MCP protocol test
    ├── test_simple.sh   # Simple functionality test
    └── test_mcp_improved.sh # Enhanced MCP test

tools/                   # Development and debugging tools
├── debug_server.py      # Debug MCP server communication
├── manual_test.py       # Manual testing harness
└── real_world_tests.py  # Real-world scenario tests

examples/                # Configuration examples
├── example-config.json  # Basic configuration
└── claude-desktop-config.json # Claude Desktop integration

integration/            # Integration and end-to-end tests
├── test_*.py           # Python integration tests
└── test_permissions.swift # Swift permission tests
```

## Common Commands

### Development
```bash
# Build the project
swift build

# Run tests  
swift test
# or
./scripts/dev/test.sh

# Run server in debug mode
swift run apple-cal-mcp --verbose
# or
./scripts/dev/run.sh

# Install to system PATH
./scripts/ops/install.sh
```

### Testing
```bash
# Basic MCP protocol test
./scripts/mcp/test_mcp.sh

# Simple functionality test
./scripts/mcp/test_simple.sh

# Enhanced MCP test with more scenarios
./scripts/mcp/test_mcp_improved.sh

# Run integration tests
cd integration
python3 test_integration.py
python3 test_performance.py
```

### Debugging
```bash
# Debug MCP communication
./tools/debug_server.py

# Manual testing interface
./tools/manual_test.py

# Real-world scenario testing
./tools/real_world_tests.py
```

## Path Migration Reference

For backward compatibility, wrapper scripts are provided at the original locations:

| Original Path | New Location | Wrapper Available |
|--------------|-------------|------------------|
| `install.sh` | `scripts/ops/install.sh` | ✅ |
| `test_mcp.sh` | `scripts/mcp/test_mcp.sh` | ✅ |
| `test_simple.sh` | `scripts/mcp/test_simple.sh` | ✅ |
| `test_mcp_improved.sh` | `scripts/mcp/test_mcp_improved.sh` | ✅ |
| `debug_server.py` | `tools/debug_server.py` | ✅ |
| `manual_test.py` | `tools/manual_test.py` | ✅ |
| `real_world_tests.py` | `tools/real_world_tests.py` | ✅ |
| `example-config.json` | `examples/example-config.json` | - |
| `claude-desktop-config.json` | `examples/claude-desktop-config.json` | - |
| `test_*.py` | `integration/test_*.py` | - |
| `CLAUDE.md` | `docs/CLAUDE.md` | - |

## Architecture Notes

- **SwiftPM Target Structure**: All Swift files remain in the same `AppleCalendarMCP` target, organized into logical subfolders for better maintainability
- **No Breaking Changes**: The module name, imports, and public API remain unchanged
- **Backward Compatibility**: All original script paths continue to work via wrapper scripts
- **Logical Grouping**: Files are organized by purpose (dev tools, ops tools, tests, examples, docs)

## Rollback Plan

If any issues arise:

1. **Swift compilation issues**: Check `swift build` and `swift test` - the target structure should be identical
2. **Wrapper script issues**: Check file paths and permissions in wrapper scripts
3. **Full rollback**: Use `git checkout HEAD -- <file>` to restore original file locations if needed

The reorganization preserves all functionality while providing a cleaner, more maintainable structure.