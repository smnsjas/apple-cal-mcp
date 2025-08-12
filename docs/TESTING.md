# Testing Guide

## Clear Structure

Now there's a clear distinction between tests and tools:

### Tests/ - Swift Unit Tests Only
- **Location**: `Tests/AppleCalendarMCPTests/`  
- **Purpose**: Test Swift code functionality
- **Language**: Swift
- **Run**: `swift test`

### tools/ - Development & Integration Tools
- **Location**: `tools/`
- **Purpose**: Integration testing, debugging, development utilities
- **Language**: Python + Shell scripts
- **Run**: Individual tools as needed

### scripts/ - Build & Development Scripts  
- **Location**: `scripts/dev/`
- **Purpose**: Build, run, and orchestrate testing
- **Language**: Shell scripts
- **Run**: Convenience wrappers

## Clear Distinction

| Directory | Contents | Purpose | Language |
|-----------|----------|---------|----------|
| `Tests/` | Swift unit tests | Test Swift code | Swift |
| `tools/` | Integration tests, debug tools | Test MCP protocol | Python |
| `scripts/` | Build/run scripts | Development workflow | Shell |

## Usage

### Run All Tests
```bash
./scripts/dev/test.sh           # Runs Swift tests + main integration test
```

### Swift Unit Tests Only
```bash
swift test                      # Just the Swift unit tests
```

### Integration Testing Tools
```bash
python3 tools/test_comprehensive.py    # Main integration test
python3 tools/test_calendar_filtering.py # Specific feature test
tools/test-integration.sh calendar_filtering # Convenient wrapper
tools/mcp-debug.py debug               # Debug MCP protocol
```

### Development Scripts
```bash
scripts/dev/run.sh             # Run server with debug logging
scripts/dev/lint.sh            # Code formatting
```

## What Goes Where?

### Tests/ 
✅ Swift unit tests for classes/functions  
❌ No Python files  
❌ No integration tests  

### tools/
✅ Python integration tests  
✅ MCP protocol testing  
✅ Debug utilities  
✅ Development tools  
❌ No Swift unit tests

### scripts/
✅ Shell scripts that orchestrate builds/tests  
✅ Convenience wrappers  
❌ No actual test code

This makes it crystal clear what each directory is for! 🎯