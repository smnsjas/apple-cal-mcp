#!/usr/bin/env python3
"""
Unified MCP debugging and testing tool
Combines debug_server.py, manual_test.py, and real_world_tests.py functionality
"""

import json
import subprocess
import sys
import time
from datetime import datetime, timedelta
from typing import Dict, Any, Optional

def send_mcp_request(tool_name: str, args: Dict[str, Any], verbose: bool = True) -> Optional[Dict]:
    """Send an MCP request and get the response"""
    request = {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": args
        },
        "id": 1
    }
    
    if verbose:
        print(f"→ Sending: {tool_name}")
        print(f"  Args: {json.dumps(args, indent=2)}")
    
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
        
        if verbose:
            print(f"← Response: {json.dumps(response, indent=2)}")
        
        return response
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def debug_server():
    """Test basic MCP server functionality"""
    print("🔧 MCP Server Debug Mode")
    print("=" * 30)
    
    # Test tools/list
    print("\n1. Testing tools/list...")
    list_request = {
        "jsonrpc": "2.0",
        "method": "tools/list",
        "id": 1
    }
    
    try:
        process = subprocess.run(
            ['.build/debug/apple-cal-mcp'],
            input=json.dumps(list_request) + '\n',
            text=True,
            capture_output=True,
            timeout=10
        )
        
        if process.returncode == 0:
            response = json.loads(process.stdout.strip())
            tools = response.get('result', {}).get('tools', [])
            print(f"✅ Found {len(tools)} tools:")
            for tool in tools:
                print(f"   - {tool['name']}")
        else:
            print("❌ tools/list failed")
            print(f"Stderr: {process.stderr}")
    
    except Exception as e:
        print(f"❌ Error testing tools/list: {e}")
    
    # Test a simple tool call
    print("\n2. Testing simple tool call...")
    today = datetime.now().strftime('%Y-%m-%d')
    tomorrow = (datetime.now() + timedelta(days=1)).strftime('%Y-%m-%d')
    
    response = send_mcp_request("get_calendar_events", {
        "start_date": today,
        "end_date": tomorrow
    })
    
    if response:
        print("✅ Basic tool call successful")
    else:
        print("❌ Basic tool call failed")

def manual_test_menu():
    """Interactive manual testing interface"""
    print("🛠️ Manual MCP Testing Interface")
    print("=" * 30)
    
    tools = [
        ("check_calendar_conflicts", "Check conflicts for dates"),
        ("get_calendar_events", "Get events in date range"),
        ("find_available_slots", "Find available time slots"),
        ("create_event", "Create a new event"),
        ("modify_event", "Modify existing event"),
        ("delete_event", "Delete an event"),
        ("list_calendars", "List available calendars")
    ]
    
    while True:
        print("\nAvailable tools:")
        for i, (tool, desc) in enumerate(tools, 1):
            print(f"{i}. {tool} - {desc}")
        print("0. Exit")
        
        choice = input("\nSelect tool (0-7): ").strip()
        
        if choice == "0":
            break
        
        try:
            tool_idx = int(choice) - 1
            if 0 <= tool_idx < len(tools):
                tool_name = tools[tool_idx][0]
                test_tool_interactive(tool_name)
            else:
                print("Invalid choice")
        except ValueError:
            print("Please enter a number")

def test_tool_interactive(tool_name: str):
    """Interactive testing for a specific tool"""
    print(f"\n🔧 Testing {tool_name}")
    
    today = datetime.now()
    tomorrow = today + timedelta(days=1)
    
    if tool_name == "check_calendar_conflicts":
        args = {
            "dates": [today.strftime('%Y-%m-%d'), tomorrow.strftime('%Y-%m-%d')],
            "time_type": "evening"
        }
    elif tool_name == "get_calendar_events":
        args = {
            "start_date": today.strftime('%Y-%m-%d'),
            "end_date": (today + timedelta(days=7)).strftime('%Y-%m-%d')
        }
    elif tool_name == "find_available_slots":
        args = {
            "date_range": {
                "start": today.strftime('%Y-%m-%d'),
                "end": (today + timedelta(days=7)).strftime('%Y-%m-%d')
            },
            "duration_minutes": 60,
            "time_preferences": "evening"
        }
    elif tool_name == "create_event":
        test_time = (today + timedelta(days=1)).replace(hour=14, minute=30, second=0, microsecond=0)
        args = {
            "title": "Test Event",
            "start_datetime": test_time.strftime('%Y-%m-%dT%H:%M:%S'),
            "end_datetime": (test_time + timedelta(hours=1)).strftime('%Y-%m-%dT%H:%M:%S'),
            "notes": "Created by MCP debug tool"
        }
    elif tool_name == "list_calendars":
        args = {}
    else:
        print("Tool not configured for interactive testing")
        return
    
    send_mcp_request(tool_name, args)

def real_world_scenarios():
    """Run realistic usage scenarios"""
    print("🌍 Real World Scenarios")
    print("=" * 30)
    
    scenarios = [
        ("Quick availability check", test_quick_availability),
        ("Weekly planning", test_weekly_planning),
        ("Event management workflow", test_event_workflow)
    ]
    
    for name, test_func in scenarios:
        print(f"\n▶️ {name}...")
        try:
            test_func()
            print(f"✅ {name} completed")
        except Exception as e:
            print(f"❌ {name} failed: {e}")

def test_quick_availability():
    """Test quick availability checking"""
    today = datetime.now()
    dates = [(today + timedelta(days=i)).strftime('%Y-%m-%d') for i in range(3)]
    
    send_mcp_request("check_calendar_conflicts", {
        "dates": dates,
        "time_type": "evening"
    }, verbose=False)

def test_weekly_planning():
    """Test weekly planning scenario"""
    today = datetime.now()
    start = today.strftime('%Y-%m-%d')
    end = (today + timedelta(days=7)).strftime('%Y-%m-%d')
    
    # Get events for the week
    send_mcp_request("get_calendar_events", {
        "start_date": start,
        "end_date": end
    }, verbose=False)
    
    # Find available slots
    send_mcp_request("find_available_slots", {
        "date_range": {"start": start, "end": end},
        "duration_minutes": 60,
        "time_preferences": "all_day"
    }, verbose=False)

def test_event_workflow():
    """Test create -> modify -> delete workflow"""
    tomorrow = datetime.now() + timedelta(days=1)
    start_time = tomorrow.replace(hour=15, minute=0, second=0, microsecond=0)
    end_time = start_time + timedelta(hours=1)
    
    # Create event
    create_response = send_mcp_request("create_event", {
        "title": "Debug Test Event",
        "start_datetime": start_time.strftime('%Y-%m-%dT%H:%M:%S'),
        "end_datetime": end_time.strftime('%Y-%m-%dT%H:%M:%S'),
        "notes": "Created by debug tool"
    }, verbose=False)
    
    if create_response and 'result' in create_response:
        # Try to extract event ID and clean up
        try:
            content = create_response['result']['content'][0]['text']
            data = json.loads(content)
            if 'event' in data and 'id' in data['event']:
                event_id = data['event']['id']
                # Clean up
                send_mcp_request("delete_event", {
                    "event_id": event_id
                }, verbose=False)
        except:
            pass  # Cleanup failed, but test succeeded

def main():
    if len(sys.argv) < 2:
        print("MCP Debug Tool")
        print("Usage:")
        print("  python3 mcp-debug.py debug      # Debug server functionality")
        print("  python3 mcp-debug.py manual     # Interactive testing")
        print("  python3 mcp-debug.py scenarios  # Real world scenarios")
        return
    
    mode = sys.argv[1]
    
    if mode == "debug":
        debug_server()
    elif mode == "manual":
        manual_test_menu()
    elif mode == "scenarios":
        real_world_scenarios()
    else:
        print(f"Unknown mode: {mode}")

if __name__ == "__main__":
    main()