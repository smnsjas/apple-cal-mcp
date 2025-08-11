# Copy Format Feature

## Overview

The `create_event` tool now supports copying properties from existing events using the `copy_format_from` parameter. This is perfect for replicating meeting patterns like time-off requests (e.g., "Jason Simons-V-8h") without hardcoding specific business logic.

## Usage

### Basic Copy Format

```json
{
  "name": "create_event",
  "arguments": {
    "title": "Jane Smith-V-8h",
    "start_datetime": "2025-08-20T00:00:00",
    "end_datetime": "2025-08-20T23:59:59", 
    "copy_format_from": "ABC123-DEF456-GHI789"
  }
}
```

### Selective Property Inheritance

Control which properties to inherit with the `inherit` parameter:

```json
{
  "name": "create_event",
  "arguments": {
    "title": "New Meeting",
    "start_datetime": "2025-08-20T14:30:00",
    "copy_format_from": "ABC123-DEF456-GHI789",
    "inherit": ["calendar", "alarm_settings", "location", "notes"]
  }
}
```

## Available Inheritance Options

| Property | Description | Example Use Case |
|----------|-------------|------------------|
| `calendar` | Use the same calendar as source event | Keep all vacation requests in "Work" calendar |
| `all_day_setting` | Copy all-day vs timed event setting | Vacation days are always all-day |
| `duration` | Copy the time duration (calculates new end_datetime) | All meetings are 1 hour long |
| `alarm_settings` | Copy notification/alert settings | Standard 15min + 1hr alerts |
| `location` | Copy the location field | "Out of Office" for vacation |
| `notes` | Copy the notes/description | Standard vacation disclaimer |

**Default inheritance:** If `inherit` is not specified, defaults to `["calendar", "all_day_setting", "alarm_settings"]`

## Common Patterns

### Time-Off Replication
Perfect for your "Name-V-8h" vacation pattern:

```json
{
  "title": "Jason Simons-D-4h",
  "start_datetime": "2025-08-20T00:00:00", 
  "copy_format_from": "vacation-template-id",
  "inherit": ["calendar", "all_day_setting", "alarm_settings", "location"]
}
```

### Meeting Template
Replicate standard meeting formats:

```json
{
  "title": "Weekly Standup", 
  "start_datetime": "2025-08-20T10:00:00",
  "copy_format_from": "previous-standup-id",
  "inherit": ["duration", "calendar", "location", "alarm_settings"]
}
```

### Different Event Types
For your various time-off codes (V, D, S, W):

```json
// Sick day copying vacation template
{
  "title": "Jason Simons-S-8h",
  "start_datetime": "2025-08-20T00:00:00",
  "copy_format_from": "vacation-template-id", 
  "notes": "Sick day - not feeling well",  // Override notes
  "inherit": ["calendar", "all_day_setting", "alarm_settings"]  // Don't inherit notes
}
```

## Property Priority

Properties are applied in this order (later overrides earlier):

1. **Source event properties** (if `copy_format_from` specified)
2. **Request parameters** (always take highest priority)

Example:
```json
{
  "title": "New Title",           // Always used (request param)
  "location": "New Location",     // Always used (request param)  
  "copy_format_from": "source-id",
  "inherit": ["location", "notes"] // location ignored, notes copied from source
}
```

## Error Handling

- **Event not found**: Returns error if `copy_format_from` event ID doesn't exist
- **Invalid inherit options**: Silently ignores invalid inheritance properties
- **Read-only calendar**: Error if trying to create in read-only calendar (even from source)

## Benefits

✅ **Generic Solution**: Works for anyone's patterns, not just your specific use case  
✅ **Flexible Inheritance**: Choose exactly which properties to copy  
✅ **No Hardcoding**: Doesn't embed specific business logic into the MCP server  
✅ **Pattern Replication**: Perfect for recurring meeting types and time-off requests  
✅ **Backwards Compatible**: Existing `create_event` usage continues to work unchanged

This feature enables you to easily replicate your "Jason Simons-V-8h" vacation patterns while keeping the MCP server generic and shareable! 🎉