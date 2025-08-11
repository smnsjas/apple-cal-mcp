# Calendar Event Management

Your Apple Calendar MCP server now includes comprehensive event management capabilities!

## 🆕 New Tools Added

### 1. `create_event` - Create New Calendar Events

Create events with full details including location, notes, alarms, and recurrence.

**Basic Usage:**
```json
{
  "title": "Team Meeting",
  "start_datetime": "2025-08-15T14:30:00",
  "end_datetime": "2025-08-15T15:30:00"
}
```

**Advanced Usage:**
```json
{
  "title": "Weekly Standup", 
  "start_datetime": "2025-08-15T10:00:00",
  "end_datetime": "2025-08-15T10:30:00",
  "location": "Conference Room A",
  "notes": "Weekly team sync meeting",
  "calendar": "Work",
  "alarm_minutes": [15, 60],
  "recurrence": {
    "frequency": "weekly",
    "count": 10,
    "days_of_week": [2]
  }
}
```

### 2. `modify_event` - Update Existing Events

Modify any aspect of an existing event. Only specify the fields you want to change.

```json
{
  "event_id": "ABC123-DEF456...",
  "title": "Updated Meeting Title",
  "start_datetime": "2025-08-15T15:00:00",
  "location": "New Location",
  "move_to_calendar": "Personal"
}
```

### 3. `delete_event` - Remove Events

Delete events with support for recurring event options.

**Delete single event:**
```json
{
  "event_id": "ABC123-DEF456..."
}
```

**Delete recurring event:**
```json
{
  "event_id": "ABC123-DEF456...",
  "delete_recurring": "all"
}
```

## 📅 Features Supported

### **Event Details**
- ✅ Title, location, notes
- ✅ Start/end times (supports all-day events)
- ✅ Calendar selection
- ✅ Multiple date/time formats

### **Smart Scheduling**
- ✅ Automatic calendar selection (uses first writable calendar)
- ✅ Date validation (start before end)
- ✅ Timezone handling (uses system timezone)

### **Recurring Events**
- ✅ Daily, weekly, monthly, yearly frequencies
- ✅ Custom intervals (every N periods)
- ✅ End by count or date
- ✅ Days of week for weekly recurrence

### **Notifications**
- ✅ Multiple alarms per event
- ✅ Custom alert times (minutes before event)
- ✅ System notification integration

### **Advanced Options**
- ✅ All-day event support
- ✅ Cross-calendar event moving
- ✅ Recurring event deletion options

## 🔧 Integration with Existing Tools

Events created through the management tools integrate seamlessly with:

- **`get_calendar_events`** - Shows created events with full details and IDs
- **`check_calendar_conflicts`** - Detects conflicts with new events
- **`find_available_slots`** - Accounts for newly created events
- **Smart filtering** - Works with all filtering options

## 💡 Usage Examples

### **Quick Meeting Creation**
*"Create a 1-hour meeting tomorrow at 2 PM"*
```json
{
  "title": "Strategy Discussion",
  "start_datetime": "2025-08-16T14:00:00", 
  "end_datetime": "2025-08-16T15:00:00"
}
```

### **Recurring Team Meeting**
*"Set up weekly standups for the next 2 months"*
```json
{
  "title": "Weekly Standup",
  "start_datetime": "2025-08-18T09:00:00",
  "end_datetime": "2025-08-18T09:30:00",
  "recurrence": {
    "frequency": "weekly", 
    "count": 8,
    "days_of_week": [2]
  },
  "alarm_minutes": [10]
}
```

### **All-Day Event**
*"Block out Friday as a company holiday"*
```json
{
  "title": "Company Holiday",
  "start_datetime": "2025-08-22T00:00:00",
  "end_datetime": "2025-08-22T23:59:59",
  "is_all_day": true
}
```

### **Event Modification**
*"Move the meeting to 3 PM and add a location"*
```json
{
  "event_id": "event-id-from-creation",
  "start_datetime": "2025-08-15T15:00:00",
  "end_datetime": "2025-08-15T16:00:00", 
  "location": "Conference Room B"
}
```

## 🚀 What This Enables

Your MCP server is now a **complete calendar management solution**:

1. **📝 Create** events with full details and scheduling options
2. **✏️ Modify** existing events (time, location, attendees, etc.)
3. **🗑️ Delete** events (including recurring event handling)
4. **🔍 Query** and analyze calendars (existing functionality)
5. **🧠 Smart filtering** to focus on relevant events

This makes it perfect for:
- **Meeting scheduling automation**
- **Calendar conflict resolution** 
- **Recurring event management**
- **Cross-calendar coordination**
- **Automated calendar maintenance**

## 🔒 Security & Permissions

- **Write permissions required** - Will request calendar write access when needed
- **Safe calendar selection** - Only modifies writable calendars
- **Validation built-in** - Prevents invalid dates and configurations
- **Error handling** - Clear error messages for troubleshooting

The event management functionality is now **fully operational and ready for use**! 🎉