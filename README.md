# Apple Calendar MCP Server

A Model Context Protocol (MCP) server that provides automated calendar checking and conflict detection for macOS Calendar app. This eliminates the need for manual calendar review when checking availability across multiple dates.

## Features

- **Automated Conflict Detection**: Check multiple dates simultaneously for calendar conflicts
- **Smart Time Windows**: Distinguish between weekday evening (5pm-11pm), weekend, and all-day availability
- **Native macOS Integration**: Uses EventKit framework for reliable Calendar app access
- **Exchange Calendar Support**: Works with corporate/Exchange calendars in Calendar app
- **Structured Output**: Returns detailed conflict information in JSON format

## Installation

### Prerequisites
- macOS 12.0 or later
- Xcode 14.0 or later
- Swift 5.9 or later

### Build from Source

1. Clone this repository:
```bash
git clone <repository-url>
cd apple_cal_mcp
```

2. Build the project:
```bash
swift build -c release
```

3. The executable will be available at:
```bash
.build/release/apple-cal-mcp
```

### Installation for MCP Use

1. Copy the executable to a permanent location:
```bash
cp .build/release/apple-cal-mcp /usr/local/bin/
```

2. Make it executable:
```bash
chmod +x /usr/local/bin/apple-cal-mcp
```

## Configuration

### Calendar Permissions

The first time you run the server, macOS will prompt you to grant Calendar access. You must allow this for the server to function.

### MCP Client Configuration

Add this server to your MCP client configuration:

```json
{
  "mcpServers": {
    "apple-calendar": {
      "command": "/usr/local/bin/apple-cal-mcp",
      "args": ["--verbose"]
    }
  }
}
```

## MCP Tools

### 1. `check_calendar_conflicts`

Check multiple dates for calendar conflicts based on time preferences.

**Parameters:**
- `dates` (required): Array of dates in YYYY-MM-DD format
- `time_type` (required): "evening", "weekend", or "all_day"
- `calendar_names` (optional): Array of specific calendar names to check
- `evening_hours` (optional): Custom evening hours object with "start" and "end" times

**Example:**
```json
{
  "dates": ["2025-08-09", "2025-08-10", "2025-08-13"],
  "time_type": "evening",
  "calendar_names": ["Calendar"],
  "evening_hours": {"start": "17:00", "end": "23:00"}
}
```

**Returns:**
```json
{
  "2025-08-09": {
    "status": "AVAILABLE"
  },
  "2025-08-10": {
    "status": "CONFLICT",
    "events": [{"title": "Team Meeting", "time": "6:00 PM-7:00 PM"}]
  }
}
```

### 2. `get_calendar_events`

Get all events in a specified date range.

**Parameters:**
- `start_date` (required): Start date in YYYY-MM-DD format
- `end_date` (required): End date in YYYY-MM-DD format
- `calendar_names` (optional): Array of specific calendar names

**Example:**
```json
{
  "start_date": "2025-08-07",
  "end_date": "2025-09-07",
  "calendar_names": ["Calendar", "Work"]
}
```

### 3. `find_available_slots`

Find available time slots matching specified criteria.

**Parameters:**
- `date_range` (required): Object with "start" and "end" dates
- `duration_minutes` (required): Minimum duration in minutes
- `time_preferences` (required): "evening", "weekend", or "all_day"
- `calendar_names` (optional): Array of specific calendar names
- `evening_hours` (optional): Custom evening hours

**Example:**
```json
{
  "date_range": {"start": "2025-08-09", "end": "2025-08-30"},
  "duration_minutes": 60,
  "time_preferences": "evening"
}
```

## Time Type Behavior

- **evening**: Weekdays check 5pm-11pm window, weekends check entire day
- **weekend**: Friday, Saturday, Sunday check entire day, weekdays check evening hours
- **all_day**: All dates check entire day for conflicts

## Usage Examples

### Checking Evening Availability
```bash
# Using with Claude Code or other MCP clients
check_calendar_conflicts({
  "dates": ["2025-08-13", "2025-08-14", "2025-08-20"],
  "time_type": "evening"
})
```

### Finding Weekend Slots
```bash
find_available_slots({
  "date_range": {"start": "2025-08-10", "end": "2025-08-31"},
  "duration_minutes": 120,
  "time_preferences": "weekend"
})
```

## Troubleshooting

### Calendar Permission Issues
- Go to System Preferences → Security & Privacy → Privacy → Calendars
- Ensure the terminal app you're using has calendar access
- Restart the MCP server after granting permissions

### No Events Found
- Verify calendar names with `get_calendar_events` first
- Check that target calendars are enabled in Calendar app
- Ensure date formats are correct (YYYY-MM-DD)

### Exchange Calendar Issues
- Ensure Exchange account is properly configured in Calendar app
- Verify calendar sync is working in Calendar app first
- Try specifying the exact calendar name in `calendar_names` parameter

## Development

### Quick Start
```bash
# Build the project
make build

# Run in development mode with debug logging  
make run
# or
./scripts/dev/run.sh

# Run tests
make test
# or  
./scripts/dev/test.sh

# Install to system PATH
make install
# or
./install.sh
```

### Manual Commands
```bash
# Traditional commands still work
swift build
swift run apple-cal-mcp --verbose
swift test
```

For complete project structure and command reference, see [docs/STRUCTURE.md](docs/STRUCTURE.md).

### Debug Logging
Use the `--verbose` flag to enable detailed logging:
```bash
apple-cal-mcp --verbose
```

## Performance

- Can check 10+ dates simultaneously in under 2 seconds
- EventKit provides efficient native Calendar app integration
- Memory usage is minimal (~10MB typical)

## Limitations

- Requires macOS Calendar app (no direct CalDAV support)
- Calendar permissions must be granted via system prompt
- Only supports macOS platform