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
    print(f"Request: {json.dumps(args, indent=2)}")
    
    try:
        process = subprocess.run(
            ['.build/debug/apple-cal-mcp'],
            input=json.dumps(request) + '\n',
            text=True,
            capture_output=True,
            timeout=30
        )
        
        if process.returncode != 0:
            print(f"Error: Process returned {process.returncode}")
            print(f"Stderr: {process.stderr}")
            return None
            
        response = json.loads(process.stdout.strip())
        
        # Extract and display events
        if 'result' in response and 'content' in response['result']:
            content = response['result']['content'][0]['text']
            data = json.loads(content)
            if 'events' in data:
                events = data['events']
                print(f"Found {len(events)} events:")
                for event in events:
                    print(f"  ✓ {event.get('title', 'Untitled')}: {event.get('start_time', event.get('time', 'No time'))}")
            else:
                print("No events found")
        return response
        
    except Exception as e:
        print(f"Error: {e}")
        return None

def test_smart_filtering():
    """Test smart work meeting detection"""
    
    # Use the date range where we know there are events (based on user's feedback)
    start_date = "2025-08-15"  # Friday with known events
    end_date = "2025-08-15"
    
    print("🧠 Testing Smart Work Meeting Detection")
    print("=" * 50)
    
    # Test 1: Get ALL events first (baseline)
    print("\n📋 BASELINE: All events (no filtering)")
    test_mcp_tool("get_calendar_events", {
        "start_date": start_date,
        "end_date": end_date,
        "calendar_filter": {"preset": "all"}
    }, "All Events (No Filtering)")
    
    # Test 2: Old keyword-based filtering (problematic)
    print("\n❌ OLD METHOD: Keyword filtering (misses events)")
    test_mcp_tool("get_calendar_events", {
        "start_date": start_date,
        "end_date": end_date,
        "calendar_filter": {"preset": "work"},
        "event_filter": {
            "title_contains": ["meeting", "team", "call", "sync"]
        }
    }, "Keyword-Based Filtering (Will Miss Events)")
    
    # Test 3: Smart work meeting detection (should catch everything)
    print("\n✅ NEW METHOD: Smart work meeting detection")
    test_mcp_tool("get_calendar_events", {
        "start_date": start_date,
        "end_date": end_date,
        "calendar_filter": {"preset": "work"},
        "event_filter": {
            "work_meetings_only": True,
            "minimum_duration_minutes": 10  # Include even short meetings
        }
    }, "Smart Work Meeting Detection")
    
    # Test 4: Business hours only
    print("\n🕐 BUSINESS HOURS: Only events during work hours")
    test_mcp_tool("get_calendar_events", {
        "start_date": start_date,
        "end_date": end_date,
        "calendar_filter": {"preset": "work"},
        "event_filter": {
            "business_hours_only": True,
            "minimum_duration_minutes": 10
        }
    }, "Business Hours Only (8 AM - 6 PM)")
    
    # Test 5: Combined smart filtering
    print("\n🎯 COMBINED: Smart detection + business hours")
    test_mcp_tool("get_calendar_events", {
        "start_date": start_date,
        "end_date": end_date,
        "calendar_filter": {"preset": "work"},
        "event_filter": {
            "work_meetings_only": True,
            "business_hours_only": True,
            "minimum_duration_minutes": 15
        }
    }, "Smart + Business Hours + 15min minimum")

def main():
    """Run smart filtering tests"""
    print("🚀 Testing Enhanced Smart Filtering System")
    print("This will demonstrate how smart work meeting detection")
    print("captures events that keyword filtering misses.")
    print()
    
    test_smart_filtering()
    
    print("\n" + "=" * 50)
    print("📊 SUMMARY:")
    print("• Smart detection should catch: 'Drew Stinnett - S - 2h', 'DevOps', 'Windows Team Meeting'")
    print("• Keyword filtering would miss: 'Drew Stinnett - S - 2h', 'DevOps'")  
    print("• Business hours filter: Includes events from 8 AM - 6 PM")
    print("=" * 50)

if __name__ == "__main__":
    main()