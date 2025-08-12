# Apple Calendar MCP Features

Complete feature guide for the Apple Calendar MCP server.

## 🗓️ Core Calendar Tools

### 1. Check Calendar Conflicts

Check for scheduling conflicts on specific dates and times.

```json
{
  "name": "check_calendar_conflicts",
  "arguments": {
    "dates": ["2025-08-15", "2025-08-16"],
    "time_type": "evening"
  }
}
```

### 2. Get Calendar Events

Retrieve events from calendars within a date range.

```json
{
  "name": "get_calendar_events", 
  "arguments": {
    "start_date": "2025-08-15",
    "end_date": "2025-08-22"
  }
}
```

### 3. Find Available Slots

Discover free time slots for scheduling.

```json
{
  "name": "find_available_slots",
  "arguments": {
    "date_range": {"start": "2025-08-15", "end": "2025-08-22"},
    "duration_minutes": 60,
    "time_preferences": "all_day"
  }
}
```

## 📝 Event Management

### Create Events

```json
{
  "name": "create_event",
  "arguments": {
    "title": "Team Meeting",
    "start_datetime": "2025-08-15T14:30:00",
    "end_datetime": "2025-08-15T15:30:00",
    "location": "Conference Room A",
    "notes": "Weekly sync",
    "alarm_minutes": [15, 60],
    "recurrence": {
      "frequency": "weekly",
      "count": 10
    }
  }
}
```

### Modify Events

```json
{
  "name": "modify_event",
  "arguments": {
    "event_id": "ABC123...",
    "title": "Updated Meeting Title",
    "location": "Conference Room B"
  }
}
```

### Delete Events

```json
{
  "name": "delete_event",
  "arguments": {
    "event_id": "ABC123...",
    "delete_recurring": "this_and_future"
  }
}
```

### Copy Event Format

Perfect for replicating meeting patterns like time-off requests:

```json
{
  "name": "create_event",
  "arguments": {
    "title": "Jason Simons-V-8h",
    "start_datetime": "2025-08-20T00:00:00",
    "copy_format_from": "template-event-id",
    "inherit": ["calendar", "all_day_setting", "alarm_settings"]
  }
}
```

## 🔍 Smart Filtering

### Calendar Presets

- **work**: Focus on work-related calendars and smart meeting detection
- **personal**: Personal calendars only
- **main**: Primary calendar only

```json
{
  "calendar_filter": {
    "preset": "work"
  }
}
```

### Smart Meeting Detection

The "work" preset uses intelligent heuristics to identify work meetings:

- **Time-based**: 8 AM - 5 PM gets higher score
- **Duration**: 30+ minute meetings prioritized  
- **Title patterns**: Detects patterns like "Name - S - 2h", "Team", "DevOps"
- **Calendar type**: Work vs personal calendar context

### Custom Filtering

```json
{
  "calendar_filter": {
    "calendar_names": ["Work", "Project Alpha"],
    "calendar_types": ["exchange", "icloud"]
  },
  "event_filter": {
    "exclude_all_day": true,
    "min_duration_minutes": 30
  }
}
```

## ⏰ Time Preferences

### Time Types

- **evening**: Weekdays 5-11 PM, weekends all day
- **weekend**: Fridays/weekends all day, weekdays evening  
- **all_day**: Always full day availability

### Evening Hours Customization

```json
{
  "evening_hours": {
    "start": "17:30",
    "end": "22:00"
  }
}
```

## 🎯 Best Practices

### Filtering Guidelines

✅ **Start broad, then narrow** - Query all events first  
✅ **Be inclusive** - Better to see too much than miss important meetings  
✅ **Use smart detection** - Let the "work" preset find meetings intelligently  
❌ **Avoid restrictive title filters** - They miss meetings like "DevOps" or "Drew Stinnett - S - 2h"

### Event Creation Tips

- Use ISO8601 datetime format: `2025-08-15T14:30:00`
- Specify calendar names exactly as they appear in Calendar app
- Use `copy_format_from` for consistent meeting patterns
- Set appropriate alarms: `[15, 60]` for 15min + 1hr alerts

### Error Handling

- **Calendar not found**: Check exact spelling and permissions
- **Event not found**: Ensure event ID is current and valid
- **Permission denied**: Grant calendar access in System Preferences

## 🔧 Advanced Features

### Recurring Events

```json
{
  "recurrence": {
    "frequency": "weekly",
    "interval": 2,
    "days_of_week": [2, 4],
    "count": 12
  }
}
```

### Property Inheritance

When copying event formats:

- `calendar` - Use same calendar
- `all_day_setting` - Copy all-day vs timed
- `duration` - Maintain time duration
- `alarm_settings` - Copy notification alerts
- `location` - Copy location field
- `notes` - Copy description

### Multiple Calendars

The server automatically discovers and works with:

- iCloud calendars
- Exchange/Office 365 calendars  
- Google calendars (via macOS sync)
- Local calendars

Perfect for managing complex calendar setups across multiple accounts! 🎉
