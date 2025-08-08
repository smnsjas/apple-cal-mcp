# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Swift-based MCP (Model Context Protocol) server that provides automated calendar checking and conflict detection for macOS Calendar app. It uses EventKit framework for native calendar access and implements MCP protocol over JSON-RPC for integration with AI assistants.

## Common Development Commands

### Build and Run
- `swift build` - Build the project
- `swift build -c release` - Build optimized release version
- `swift run apple-cal-mcp --verbose` - Run with debug logging
- `swift test` - Run tests

### Installation
- `swift build -c release` - Build release version
- `cp .build/release/apple-cal-mcp /usr/local/bin/` - Install system-wide

## Architecture Overview

### Core Components
- **MCPServer**: Main server class handling stdin/stdout MCP communication
- **CalendarManager**: EventKit integration for calendar access and permissions
- **JSONRPCHandler**: MCP protocol implementation and tool routing
- **Models**: Data types for MCP requests/responses and calendar operations

### Key Features
- **EventKit Integration**: Native macOS calendar access with permission handling
- **MCP Protocol**: JSON-RPC over stdin/stdout for AI assistant integration  
- **Three MCP Tools**: `check_calendar_conflicts`, `get_calendar_events`, `find_available_slots`
- **Smart Time Logic**: Handles evening hours, weekends, and all-day availability patterns

### Calendar Access Flow
1. Request calendar permissions via EventKit on startup
2. Filter calendars by name if specified (supports Exchange calendars)
3. Query events using date ranges and calendar-specific predicates
4. Apply time-based conflict detection logic based on weekday vs weekend

### Time Type Logic
- **evening**: Weekdays check 5pm-11pm, weekends check all day
- **weekend**: Fridays/weekends check all day, weekdays use evening hours  
- **all_day**: Always check entire day regardless of date

## Important Implementation Details

### Permission Handling
The server requests calendar permissions on startup using `EKEventStore.requestAccess()`. This shows a system dialog that users must approve. Calendar access is required for all functionality.

### Date Handling
- Input dates use ISO format (YYYY-MM-DD)
- Internal processing uses Swift Date/Calendar APIs
- Timezone handling uses system locale (typically EDT/EST for user)

### MCP Protocol
- Uses JSON-RPC 2.0 over stdin/stdout
- Implements standard MCP methods: `initialize`, `tools/list`, `tools/call`
- Tool responses wrapped in MCP content format with JSON text

### Error Handling
- Calendar permission errors return specific MCPError codes
- Date parsing errors include helpful validation messages
- EventKit errors are caught and returned as internal errors

## Testing and Development

### Manual Testing
Use MCP protocol directly via stdin/stdout:
```json
{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}
```

### Calendar Setup
- Test with both iCloud and Exchange calendars
- Verify calendar names match exactly (case sensitive)
- Ensure Calendar app sync is working before testing server

## Dependencies
- **EventKit**: Native macOS calendar framework
- **ArgumentParser**: Command-line interface
- **Logging**: Structured logging support