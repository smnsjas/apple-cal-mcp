#!/usr/bin/env python3

import json
import subprocess
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
                    print(f"   Calendar: {event.get('calendar', 'N/A')}")
                    if event.get('location'):
                        print(f"   Location: {event['location']}")
                    if event.get('is_all_day'):
                        print(f"   All-day: {event['is_all_day']}")
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

def test_copy_format_functionality():
    """Test the copy_format_from feature"""
    
    print("🔧 Testing Copy Format Functionality")
    print("=" * 50)
    
    # Calculate dates for testing
    tomorrow = datetime.now() + timedelta(days=1)
    day_after = tomorrow + timedelta(days=1)
    
    # Step 1: Create a template event (like your vacation pattern)
    template_start = tomorrow.replace(hour=0, minute=0, second=0, microsecond=0)
    template_end = tomorrow.replace(hour=23, minute=59, second=59, microsecond=0)
    
    print("\n📋 Step 1: Create Template Event")
    template_result = test_mcp_tool("create_event", {
        "title": "John Doe-V-8h",  # Vacation template pattern
        "start_datetime": template_start.strftime('%Y-%m-%dT%H:%M:%S'),
        "end_datetime": template_end.strftime('%Y-%m-%dT%H:%M:%S'),
        "is_all_day": True,
        "calendar": "Work",
        "notes": "Vacation day - out of office",
        "alarm_minutes": [1440, 60]  # 1 day and 1 hour alerts
    }, "Create Template Vacation Event")
    
    if not template_result or not template_result.get('success'):
        print("❌ Template creation failed - stopping test")
        return
    
    template_event_id = template_result['event']['id']
    print(f"\n✨ Template Event Created: {template_event_id}")
    
    # Step 2: Copy the format for a new vacation day
    new_vacation_start = day_after.replace(hour=0, minute=0, second=0, microsecond=0)
    new_vacation_end = day_after.replace(hour=23, minute=59, second=59, microsecond=0)
    
    print("\n🔄 Step 2: Copy Format for New Vacation")
    copy_result = test_mcp_tool("create_event", {
        "title": "Jane Smith-V-8h",  # Different person, same pattern
        "start_datetime": new_vacation_start.strftime('%Y-%m-%dT%H:%M:%S'),
        "end_datetime": new_vacation_end.strftime('%Y-%m-%dT%H:%M:%S'),
        "copy_format_from": template_event_id,
        "inherit": ["calendar", "all_day_setting", "alarm_settings", "notes"]
    }, "Copy Template Format for New Vacation")
    
    if copy_result and copy_result.get('success'):
        copied_event_id = copy_result['event']['id']
        print(f"\n✨ Copied Event Created: {copied_event_id}")
        
        # Step 3: Test different inheritance options
        sick_day_start = (day_after + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
        sick_day_end = (day_after + timedelta(days=1)).replace(hour=23, minute=59, second=59, microsecond=0)
        
        print("\n🏥 Step 3: Copy for Sick Day (Different Type)")
        sick_result = test_mcp_tool("create_event", {
            "title": "Jane Smith-S-8h",  # Sick day pattern
            "start_datetime": sick_day_start.strftime('%Y-%m-%dT%H:%M:%S'),
            "end_datetime": sick_day_end.strftime('%Y-%m-%dT%H:%M:%S'),
            "copy_format_from": template_event_id,
            "notes": "Sick day - not feeling well",  # Override notes
            "inherit": ["calendar", "all_day_setting", "alarm_settings"]  # Don't inherit notes
        }, "Copy Template with Different Notes")
        
        # Step 4: Test duration inheritance for different times
        meeting_start = (day_after + timedelta(days=2)).replace(hour=14, minute=30, second=0, microsecond=0)
        
        print("\n⏰ Step 4: Copy Duration for Meeting")
        duration_result = test_mcp_tool("create_event", {
            "title": "Team Meeting",
            "start_datetime": meeting_start.strftime('%Y-%m-%dT%H:%M:%S'),
            "copy_format_from": template_event_id,
            "inherit": ["duration", "calendar", "alarm_settings"],
            "location": "Conference Room A"
        }, "Copy Duration from All-Day Event")
        
        # Cleanup created events
        print("\n🧹 Cleanup: Deleting Test Events")
        for event_id, name in [
            (template_event_id, "Template Event"),
            (copied_event_id, "Copied Vacation"),
        ]:
            test_mcp_tool("delete_event", {"event_id": event_id}, f"Delete {name}")
        
        if sick_result and sick_result.get('success'):
            test_mcp_tool("delete_event", {"event_id": sick_result['event']['id']}, "Delete Sick Day")
            
        if duration_result and duration_result.get('success'):
            test_mcp_tool("delete_event", {"event_id": duration_result['event']['id']}, "Delete Meeting")

def main():
    """Run copy format testing"""
    print("🚀 Apple Calendar MCP - Copy Format Feature Testing")
    print("This demonstrates copying properties from existing events")
    print("Perfect for replicating time-off patterns like 'Name-V-8h'")
    print()
    
    test_copy_format_functionality()
    
    print("\n" + "=" * 60)
    print("🎉 Copy Format Testing Complete!")
    print("=" * 60)
    print("\n🆕 New Feature: copy_format_from")
    print("• Copy properties from existing events")
    print("• Inherit: calendar, all_day_setting, duration, alarm_settings, location, notes")
    print("• Perfect for replicating meeting patterns")
    print("• Example: Vacation requests, recurring 1:1s, standard meetings")
    print("\n📝 Usage:")
    print('  "copy_format_from": "event-id"')
    print('  "inherit": ["calendar", "all_day_setting", "alarm_settings"]')

if __name__ == "__main__":
    main()