# Contributing to Apple Calendar MCP

## Development Setup

1. **Prerequisites**
   - macOS 12+ (for EventKit framework)
   - Swift 5.9+ 
   - Xcode command line tools

2. **Clone and Build**
   ```bash
   git clone <repository>
   cd apple_cal_mcp
   swift build
   ```

3. **Run Tests**
   ```bash
   swift test
   # or
   make test
   ```

## Development Workflow

### Project Structure
See [docs/STRUCTURE.md](docs/STRUCTURE.md) for the complete project organization.

### Common Tasks
```bash
# Build and run
make build
make run

# Run specific test suites
swift test --filter DateUtilsTests
swift test --filter JSONRPCHandlerTests

# MCP protocol testing
./scripts/mcp/test_mcp.sh
./scripts/mcp/test_simple.sh

# Integration testing  
cd integration
python3 test_integration.py
```

### Code Style
- Follow Swift conventions (PascalCase types, camelCase members)
- Use comprehensive doc comments (///) for public APIs
- Prefer `guard` statements over force unwraps
- Use typed errors over NSError
- Mark classes `final` unless inheritance is intended

### Testing
- Write unit tests for new functionality
- Test MCP protocol compliance with scripts in `scripts/mcp/`
- Test calendar operations with integration tests
- Verify backward compatibility of any path changes

## Architecture Guidelines

### Swift Package Structure
- **App/**: Entry point and command-line interface
- **Core/**: MCP protocol implementation and models
- **Calendar/**: EventKit operations and conflict analysis
- **Utils/**: Shared utilities and helpers

### Error Handling
- Use `ValidationError` enum for input validation
- Use `CalendarError` enum for EventKit operations  
- Use `MCPError` for JSON-RPC protocol errors

### Async/Await
- CalendarManager methods are async for rate limiting
- Use `await` for EventKit operations to respect rate limits
- Handle errors with proper propagation

### Documentation
- All public APIs have doc comments
- Complex logic has inline comments
- Architecture decisions documented in relevant files

## Testing Calendar Integration

**Note**: Calendar operations require system permissions. First run:
```bash
swift run apple-cal-mcp --verbose
# Grant calendar access when prompted
```

Then test with real calendar data:
```bash
cd integration
python3 test_with_events.py
```

## Submitting Changes

1. Ensure all tests pass: `make test`
2. Test MCP protocol compliance: `./scripts/mcp/test_mcp.sh`
3. Verify no breaking changes to public APIs
4. Update documentation if needed
5. Submit pull request with clear description