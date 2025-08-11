# Calendar and Event Filtering

Your Apple Calendar MCP server now includes powerful filtering capabilities to help you focus on specific calendars and types of events during conversations.

## ⚠️ Important: Filtering Best Practices

**The Golden Rule: Start Broad, Then Narrow**

1. **Query ALL events first** - Don't filter at the initial query level
2. **Review before filtering** - See what you might miss with restrictive filters
3. **Be inclusive, not exclusive** - Better to show too many than miss important meetings
4. **Avoid title-only filtering** - Meetings like "Drew Stinnett - S - 2h" or "DevOps" don't contain keywords like "meeting"

### Common Pitfalls to Avoid

❌ **Don't do this:**
```json
{
  "event_filter": {
    "title_contains": ["meeting", "call", "sync"]  // Will miss "DevOps", "Drew Stinnett - S", etc.
  }
}
```

✅ **Do this instead:**
```json
// First query: Get ALL events
{
  "calendar_filter": {"preset": "work"}
  // No event_filter - see everything first
}

// Then optionally filter for specific analysis:
{
  "calendar_filter": {"preset": "work"},
  "event_filter": {
    "minimum_duration_minutes": 15,  // Focus on substantial meetings
    "exclude_all_day": true         // Remove all-day blocks
  }
}
```

## Calendar Filtering

### Quick Presets
Use these convenient presets for common filtering scenarios:

```json
{
  "calendar_filter": {
    "preset": "work"      // Only Work and Calendar calendars, excludes subscribed/holidays/sports
    "preset": "personal"  // Personal calendars only (iCloud, Gmail), excludes birthdays/holidays/sports
    "preset": "main"      // Core calendars: Calendar, Work, Home, Personal, Family
    "preset": "all"       // No filtering - shows all calendars
    "preset": "clean"     // Excludes subscribed calendars, holidays, sports, read-only
  }
}
```

### Advanced Calendar Filtering
For more specific control:

```json
{
  "calendar_filter": {
    "include_names": ["Work", "Personal"],           // Only these calendar names
    "exclude_names": ["Birthdays", "US Holidays"],   // Skip these calendar names
    "include_accounts": ["iCloud", "Exchange"],      // Only these account types
    "exclude_accounts": ["Gmail"],                   // Skip these account types
    "exclude_read_only": true,                      // Skip read-only calendars
    "exclude_subscribed": true,                     // Skip subscribed calendars
    "exclude_holidays": true,                       // Skip holiday calendars
    "exclude_sports": true                          // Skip sports team calendars
  }
}
```

## Event Filtering

Filter events by type, content, and duration:

```json
{
  "event_filter": {
    "exclude_all_day": true,                        // Skip all-day events
    "exclude_busy": true,                           // Skip events marked as busy
    "exclude_tentative": true,                      // Skip tentative events
    "title_contains": ["meeting", "call"],          // Only events with these keywords (NOT recommended)
    "title_excludes": ["lunch", "break", "coffee"], // Skip events with these keywords
    "minimum_duration_minutes": 30,                // Only events 30+ minutes long
    "maximum_duration_minutes": 120,                // Only events under 2 hours
    "work_meetings_only": true,                     // ✅ SMART: Detect work meetings using multiple heuristics
    "business_hours_only": true                     // Only events during business hours (8 AM - 6 PM)
  }
}
```

## 🧠 Smart Work Meeting Detection (RECOMMENDED)

Instead of relying on title keywords that miss events like "Drew Stinnett - S - 2h" or "DevOps", use smart detection:

```json
{
  "event_filter": {
    "work_meetings_only": true,           // ✅ Uses multiple heuristics
    "minimum_duration_minutes": 15       // Still include duration filters
  }
}
```

**Smart detection considers:**
- **Time of day**: Business hours (8 AM - 5 PM) get higher scores
- **Duration**: 30+ minute events are more likely meetings  
- **Calendar source**: Work calendars get bonus points
- **Title patterns**: Detects "Name - Code" patterns, "DevOps", "Team" references
- **Content keywords**: Meeting-related words (but doesn't require them)
- **Day of week**: Weekday events get bonus points
- **Exclusions**: Filters out obvious personal events (birthdays, lunch, etc.)

## Usage Examples

### Conversation-Friendly Usage

**"Show me my work meetings this week, but skip all-day events and short meetings"**
```json
{
  "calendar_filter": { "preset": "work" },
  "event_filter": {
    "work_meetings_only": true,              // ✅ SMART: Catches "DevOps", "Drew Stinnett - S" etc.
    "exclude_all_day": true,
    "minimum_duration_minutes": 15           // Lower threshold since smart detection is better
  }
}
```

**OLD WAY (problematic):**
```json
{
  "calendar_filter": { "preset": "work" },
  "event_filter": {
    "title_contains": ["meeting", "call"]    // ❌ Misses "DevOps", "Drew Stinnett - S - 2h"
  }
}
```

**"Check for conflicts on Friday evening, but ignore personal events and breaks"**
```json
{
  "calendar_filter": { "preset": "main" },
  "event_filter": {
    "title_excludes": ["personal", "lunch", "break", "coffee"],
    "minimum_duration_minutes": 15
  }
}
```

**"Find available slots this week, considering only important calendars"**
```json
{
  "calendar_filter": { "preset": "clean" },
  "event_filter": {
    "exclude_tentative": true,
    "minimum_duration_minutes": 60
  }
}
```

## Supported Tools

All four calendar tools support filtering:

1. **`list_calendars`** - Supports `calendar_filter`
2. **`check_calendar_conflicts`** - Supports both `calendar_filter` and `event_filter`
3. **`get_calendar_events`** - Supports both `calendar_filter` and `event_filter`  
4. **`find_available_slots`** - Supports both `calendar_filter` and `event_filter`

## Safe Filtering Strategies

### For Weekly Meeting Reviews
```json
// Step 1: Get everything
{
  "calendar_filter": {"preset": "work"}
}

// Step 2: If too much noise, filter conservatively
{
  "calendar_filter": {"preset": "work"},
  "event_filter": {
    "exclude_all_day": true,           // Remove daily blocks
    "minimum_duration_minutes": 10     // Keep even short meetings
  }
}
```

### For Conflict Checking
```json
// Be inclusive - check ALL events that might conflict
{
  "calendar_filter": {"preset": "main"},
  "event_filter": {
    "exclude_tentative": true,         // Only firm conflicts matter
    "minimum_duration_minutes": 5      // Even short meetings can conflict
  }
}
```

### For Finding Meeting Patterns
```json
// Don't filter by title - filter by context
{
  "calendar_filter": {"preset": "work"},
  "event_filter": {
    "exclude_all_day": true,
    "minimum_duration_minutes": 15,
    "maximum_duration_minutes": 180   // Focus on meeting-length events
  }
}
```

## Tips for Better Conversations

1. **Start broad, then narrow** - Always query without event filters first
2. **Use calendar presets** - "work", "personal", "main" are safer than event filtering
3. **Filter by structure, not content** - Duration and timing are more reliable than titles
4. **Double-check important queries** - If looking for "all meetings", verify you're not missing any
5. **Ask for help** - If results seem incomplete, ask Claude to query more broadly

## When Filtering Goes Wrong

If you suspect you're missing events:

1. **Remove all event filters** and query again
2. **Use broader calendar filters** (try "all" instead of "work")
3. **Check specific date ranges** where you expect events
4. **Look for patterns** in what's being missed vs. what's being shown

This filtering system makes it much easier to have focused conversations about specific types of calendar events, but remember: **it's better to have too much information than to miss something important**.