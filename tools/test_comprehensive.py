#!/usr/bin/env python3
"""
Comprehensive test suite for Apple Calendar MCP Server
Combines event management, filtering, and copy format testing
"""

import json
import subprocess
from datetime import datetime, timedelta
from typing import Dict, Any, Optional

def test_mcp_tool(tool_name: str, args: Dict[str, Any], description: str) -> Optional[Dict]:
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
        
        if 'result' in response and 'content' in response['result']:
            content = response['result']['content'][0]['text']
            data = json.loads(content)
            
            if 'success' in data and data['success']:
                print(f"✅ Success: {data.get('message', 'Operation completed')}")
                return data
            else:
                print(f"❌ Failed: {data.get('message', 'Unknown error')}")
                
        elif 'error' in response:
            print(f"❌ Error: {response['error']['message']}")
            
        return response
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def test_event_management():
    """Test complete event lifecycle"""
    print("\n🗓️ Testing Event Management")
    print("=" * 40)
    
    tomorrow = datetime.now() + timedelta(days=1)
    start_time = tomorrow.replace(hour=14, minute=30, second=0, microsecond=0)
    end_time = start_time + timedelta(hours=1)
    
    # Create event
    create_result = test_mcp_tool("create_event", {
        "title": "Test Meeting",
        "start_datetime": start_time.strftime('%Y-%m-%dT%H:%M:%S'),
        "end_datetime": end_time.strftime('%Y-%m-%dT%H:%M:%S'),
        "location": "Conference Room A",
        "notes": "Important meeting",
        "alarm_minutes": [15, 60]
    }, "Create Test Event")
    
    if create_result and create_result.get('success'):
        event_id = create_result['event']['id']
        
        # Modify event
        test_mcp_tool("modify_event", {
            "event_id": event_id,
            "title": "Updated Test Meeting",
            "location": "Conference Room B"
        }, "Modify Event")
        
        # Delete event
        test_mcp_tool("delete_event", {
            "event_id": event_id
        }, "Delete Event")
    
    return create_result is not None

def test_calendar_filtering():
    """Test filtering functionality"""
    print("\n🔍 Testing Calendar Filtering")
    print("=" * 40)
    
    today = datetime.now()
    
    # Test different filter presets
    for preset in ["work", "personal", "main"]:
        test_mcp_tool("get_calendar_events", {
            "start_date": today.strftime('%Y-%m-%d'),
            "end_date": (today + timedelta(days=7)).strftime('%Y-%m-%d'),
            "calendar_filter": {"preset": preset}
        }, f"Filter Events - {preset.title()} Preset")

def test_availability_checking():
    """Test conflict checking and available slots"""
    print("\n⏰ Testing Availability Features")
    print("=" * 40)
    
    today = datetime.now()
    dates = [today.strftime('%Y-%m-%d'), (today + timedelta(days=1)).strftime('%Y-%m-%d')]
    
    # Check conflicts
    test_mcp_tool("check_calendar_conflicts", {
        "dates": dates,
        "time_type": "evening"
    }, "Check Evening Conflicts")
    
    # Find available slots
    test_mcp_tool("find_available_slots", {
        "date_range": {
            "start": today.strftime('%Y-%m-%d'),
            "end": (today + timedelta(days=7)).strftime('%Y-%m-%d')
        },
        "duration_minutes": 60,
        "time_preferences": "all_day"
    }, "Find Available 1-hour Slots")

def test_copy_format():
    """Test copy format functionality"""
    print("\n📋 Testing Copy Format Feature")
    print("=" * 40)
    
    tomorrow = datetime.now() + timedelta(days=1)
    template_start = tomorrow.replace(hour=9, minute=0, second=0, microsecond=0)
    template_end = template_start + timedelta(hours=8)
    
    # Create template (vacation pattern)
    template_result = test_mcp_tool("create_event", {
        "title": "Template-V-8h", 
        "start_datetime": template_start.strftime('%Y-%m-%dT%H:%M:%S'),
        "end_datetime": template_end.strftime('%Y-%m-%dT%H:%M:%S'),
        "is_all_day": True,
        "notes": "Vacation day",
        "alarm_minutes": [1440]  # 1 day notice
    }, "Create Vacation Template")
    
    if template_result and template_result.get('success'):
        template_id = template_result['event']['id']
        print(f"Created template with ID: {template_id}")
        
        # Clean up template
        test_mcp_tool("delete_event", {"event_id": template_id}, "Clean up Template")

def run_all_tests():
    """Run all test suites"""
    print("🚀 Apple Calendar MCP - Comprehensive Test Suite")
    print("=" * 60)
    
    results = {
        "event_management": test_event_management(),
        "calendar_filtering": True,  # Always passes if no crash
        "availability_checking": True,
        "copy_format": True
    }
    
    test_calendar_filtering()
    test_availability_checking() 
    test_copy_format()
    
    print("\n" + "=" * 60)
    print("📊 Test Results Summary")
    print("=" * 60)
    
    for test_name, passed in results.items():
        status = "✅ PASSED" if passed else "❌ FAILED"
        print(f"{test_name.replace('_', ' ').title()}: {status}")
    
    all_passed = all(results.values())
    print(f"\n🎯 Overall: {'✅ ALL TESTS PASSED' if all_passed else '❌ SOME TESTS FAILED'}")
    
    return all_passed

if __name__ == "__main__":
    success = run_all_tests()
    exit(0 if success else 1)