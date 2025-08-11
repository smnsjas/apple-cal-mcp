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

def main():
    """Test copy format with simple approach"""
    
    print("🔧 Testing Copy Format - Simple Version")
    print("=" * 50)
    
    # Calculate dates for testing
    tomorrow = datetime.now() + timedelta(days=1)
    day_after = tomorrow + timedelta(days=1)
    
    # Step 1: Create a template event (using default calendar)
    template_start = tomorrow.replace(hour=14, minute=30, second=0, microsecond=0)
    template_end = template_start + timedelta(hours=1)
    
    print("\n📋 Step 1: Create Template Event")
    template_result = test_mcp_tool("create_event", {
        "title": "Jason Simons-V-8h",  # Your vacation pattern
        "start_datetime": template_start.strftime('%Y-%m-%dT%H:%M:%S'),
        "end_datetime": template_end.strftime('%Y-%m-%dT%H:%M:%S'),
        "location": "Out of Office",
        "notes": "Vacation day",
        "alarm_minutes": [60, 15]  # 1 hour and 15 min alerts
    }, "Create Template Event")
    
    if not template_result or not template_result.get('success'):
        print("❌ Template creation failed - stopping test")
        return
    
    template_event_id = template_result['event']['id']
    print(f"\n✨ Template Event Created: {template_event_id}")
    
    # Step 2: Copy the format for a new event
    new_start = day_after.replace(hour=16, minute=0, second=0, microsecond=0)
    
    print("\n🔄 Step 2: Copy Format for New Event")
    copy_result = test_mcp_tool("create_event", {
        "title": "Jason Simons-D-4h",  # Different type and duration
        "start_datetime": new_start.strftime('%Y-%m-%dT%H:%M:%S'),
        "end_datetime": (new_start + timedelta(hours=2)).strftime('%Y-%m-%dT%H:%M:%S'),  # Explicit end time
        "copy_format_from": template_event_id,
        "inherit": ["calendar", "alarm_settings", "location"]
    }, "Copy Template Format")
    
    if copy_result and copy_result.get('success'):
        copied_event_id = copy_result['event']['id']
        print(f"\n✨ Copied Event Created: {copied_event_id}")
        
        # Step 3: Test duration inheritance
        duration_start = (day_after + timedelta(days=1)).replace(hour=10, minute=0, second=0, microsecond=0)
        
        print("\n⏰ Step 3: Test Duration Inheritance")
        duration_result = test_mcp_tool("create_event", {
            "title": "Jason Simons-S-8h",  # Sick day
            "start_datetime": duration_start.strftime('%Y-%m-%dT%H:%M:%S'),
            "copy_format_from": template_event_id,
            "inherit": ["duration", "calendar", "alarm_settings"],
            "notes": "Sick day - not feeling well"
        }, "Copy Duration from Template")
        
        # Cleanup
        print("\n🧹 Cleanup: Deleting Test Events")
        test_mcp_tool("delete_event", {"event_id": template_event_id}, "Delete Template")
        test_mcp_tool("delete_event", {"event_id": copied_event_id}, "Delete Copy")
        
        if duration_result and duration_result.get('success'):
            test_mcp_tool("delete_event", {"event_id": duration_result['event']['id']}, "Delete Duration Test")
    
    print("\n" + "=" * 60)
    print("🎉 Copy Format Testing Complete!")
    print("✨ You can now replicate your 'Name-V-8h' patterns easily!")

if __name__ == "__main__":
    main()