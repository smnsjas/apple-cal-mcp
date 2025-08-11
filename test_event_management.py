#!/usr/bin/env python3

import json
import subprocess
import sys
from datetime import datetime, timedelta

def test_mcp_tool(tool_name, args, description):
    """Test an MCP tool by sending JSON-RPC request"""
    request = {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": args
        },
        "id": 1
    }
    
    print(f"\n=== {description} ===")
    print(f"Tool: {tool_name}")
    print(f"Args: {json.dumps(args, indent=2)}")
    
    try:
        process = subprocess.run(
            ['.build/debug/apple-cal-mcp'],
            input=json.dumps(request) + '\n',
            text=True,
            capture_output=True,
            timeout=30
        )
        
        if process.returncode != 0:
            print(f"❌ Error: Process returned {process.returncode}")
            print(f"Stderr: {process.stderr}")
            return None
            
        response = json.loads(process.stdout.strip())
        
        # Extract and display result
        if 'result' in response and 'content' in response['result']:
            content = response['result']['content'][0]['text']
            data = json.loads(content)
            
            if 'success' in data and data['success']:
                print(f"✅ Success: {data.get('message', 'Operation completed')}")
                if 'event' in data:
                    event = data['event']
                    print(f"   Event ID: {event.get('id', 'N/A')}")
                    print(f"   Title: {event.get('title', 'N/A')}")
                    print(f"   Time: {event.get('start_datetime', 'N/A')} to {event.get('end_datetime', 'N/A')}")
                    if event.get('location'):
                        print(f"   Location: {event['location']}")
                return data
            else:
                print(f"❌ Failed: {data.get('message', 'Unknown error')}")
                print(f"   Response: {json.dumps(data, indent=2)}")
        else:
            print(f"❌ Unexpected response format: {json.dumps(response, indent=2)}")
            
        return response
        
    except Exception as e:
        print(f"❌ Error: {e}")
        if 'process' in locals():
            print(f"Stderr: {process.stderr}")
        return None

def test_event_lifecycle():
    """Test creating, modifying, and deleting events"""
    
    # Calculate dates for testing
    tomorrow = datetime.now() + timedelta(days=1)
    start_time = tomorrow.replace(hour=14, minute=30, second=0, microsecond=0)
    end_time = start_time + timedelta(hours=1)
    
    start_iso = start_time.strftime('%Y-%m-%dT%H:%M:%S')
    end_iso = end_time.strftime('%Y-%m-%dT%H:%M:%S')
    
    print("🔧 Testing Complete Event Management Lifecycle")
    print("=" * 60)
    
    # Step 1: Create a new event
    create_result = test_mcp_tool("create_event", {
        "title": "MCP Test Meeting",
        "start_datetime": start_iso,
        "end_datetime": end_iso,
        "location": "Conference Room A",
        "notes": "Testing event creation via MCP server",
        "alarm_minutes": [15, 60]  # 15 min and 1 hour alerts
    }, "Create New Event")
    
    if not create_result or not create_result.get('success'):
        print("❌ Event creation failed - stopping test")
        return
        
    event_id = create_result['event']['id']
    
    # Step 2: Modify the event
    new_start = start_time.replace(hour=15)
    new_end = new_start + timedelta(hours=1, minutes=30)
    
    modify_result = test_mcp_tool("modify_event", {
        "event_id": event_id,
        "title": "MCP Test Meeting - Updated",
        "start_datetime": new_start.strftime('%Y-%m-%dT%H:%M:%S'),
        "end_datetime": new_end.strftime('%Y-%m-%dT%H:%M:%S'),
        "location": "Conference Room B",
        "notes": "Updated via MCP server - now 1.5 hours long"
    }, "Modify Existing Event")
    
    # Step 3: Delete the event
    test_mcp_tool("delete_event", {
        "event_id": event_id
    }, "Delete Event")

def test_recurring_event():
    """Test creating a recurring event"""
    
    # Weekly meeting starting next Monday
    next_monday = datetime.now() + timedelta(days=(7 - datetime.now().weekday()))
    start_time = next_monday.replace(hour=10, minute=0, second=0, microsecond=0)
    end_time = start_time + timedelta(minutes=30)
    
    print("\n🔄 Testing Recurring Events")
    print("=" * 40)
    
    create_result = test_mcp_tool("create_event", {
        "title": "Weekly Standup",
        "start_datetime": start_time.strftime('%Y-%m-%dT%H:%M:%S'),
        "end_datetime": end_time.strftime('%Y-%m-%dT%H:%M:%S'),
        "location": "Team Room",
        "notes": "Weekly team standup meeting",
        "recurrence": {
            "frequency": "weekly",
            "count": 4,  # 4 occurrences
            "days_of_week": [2]  # Monday (1=Sunday, 2=Monday, etc.)
        },
        "alarm_minutes": [10]
    }, "Create Weekly Recurring Event")
    
    if create_result and create_result.get('success'):
        event_id = create_result['event']['id']
        
        # Clean up - delete the recurring event
        test_mcp_tool("delete_event", {
            "event_id": event_id,
            "delete_recurring": "all"
        }, "Delete Recurring Event (All Occurrences)")

def test_all_day_event():
    """Test creating an all-day event"""
    
    next_friday = datetime.now() + timedelta(days=(4 - datetime.now().weekday()) % 7 + 7)
    
    print("\n📅 Testing All-Day Events")
    print("=" * 30)
    
    create_result = test_mcp_tool("create_event", {
        "title": "Company Holiday",
        "start_datetime": next_friday.strftime('%Y-%m-%dT00:00:00'),
        "end_datetime": next_friday.strftime('%Y-%m-%dT23:59:59'),
        "is_all_day": True,
        "notes": "Company-wide holiday - no meetings scheduled"
    }, "Create All-Day Event")
    
    if create_result and create_result.get('success'):
        event_id = create_result['event']['id']
        
        # Clean up
        test_mcp_tool("delete_event", {
            "event_id": event_id
        }, "Delete All-Day Event")

def test_calendar_integration():
    """Test that events integrate with existing calendar tools"""
    
    tomorrow = datetime.now() + timedelta(days=1)
    
    print("\n🔗 Testing Calendar Integration")
    print("=" * 40)
    
    # Create a test event
    start_time = tomorrow.replace(hour=16, minute=0, second=0, microsecond=0)
    end_time = start_time + timedelta(hours=2)
    
    create_result = test_mcp_tool("create_event", {
        "title": "Integration Test Event",
        "start_datetime": start_time.strftime('%Y-%m-%dT%H:%M:%S'),
        "end_datetime": end_time.strftime('%Y-%m-%dT%H:%M:%S'),
        "location": "Test Location"
    }, "Create Event for Integration Test")
    
    if create_result and create_result.get('success'):
        event_id = create_result['event']['id']
        
        # Check if the event shows up in get_calendar_events
        test_mcp_tool("get_calendar_events", {
            "start_date": tomorrow.strftime('%Y-%m-%d'),
            "end_date": tomorrow.strftime('%Y-%m-%d')
        }, "Verify Event Appears in Calendar Query")
        
        # Check conflicts
        test_mcp_tool("check_calendar_conflicts", {
            "dates": [tomorrow.strftime('%Y-%m-%d')],
            "time_type": "evening"
        }, "Check for Conflicts with New Event")
        
        # Clean up
        test_mcp_tool("delete_event", {
            "event_id": event_id
        }, "Clean Up Integration Test Event")

def main():
    """Run all event management tests"""
    print("🚀 Apple Calendar MCP - Event Management Testing")
    print("This will test creating, modifying, and deleting calendar events")
    print("Note: This will create and delete real calendar events for testing")
    print()
    
    # Test basic lifecycle
    test_event_lifecycle()
    
    # Test advanced features
    test_recurring_event()
    test_all_day_event() 
    test_calendar_integration()
    
    print("\n" + "=" * 60)
    print("🎉 Event Management Testing Complete!")
    print("=" * 60)
    print("\nNew MCP Tools Available:")
    print("• create_event - Create new calendar events")
    print("• modify_event - Update existing events") 
    print("• delete_event - Remove events (supports recurring)")
    print("\nFeatures Supported:")
    print("• Full event details (title, time, location, notes)")
    print("• Recurring events (daily, weekly, monthly, yearly)")
    print("• Alarms/notifications")
    print("• All-day events")
    print("• Calendar selection")
    print("• Event modification and deletion")

if __name__ == "__main__":
    main()