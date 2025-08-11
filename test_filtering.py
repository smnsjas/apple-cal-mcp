#!/usr/bin/env python3

import json
import subprocess
import sys
from datetime import datetime, timedelta

def test_mcp_tool(tool_name, args):
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
    
    print(f"Testing {tool_name} with filtering...")
    print(f"Request: {json.dumps(request, indent=2)}")
    
    try:
        # Run the MCP server
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
        print(f"Response: {json.dumps(response, indent=2)}")
        return response
        
    except subprocess.TimeoutExpired:
        print("Error: Request timed out")
        return None
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")
        print(f"Raw output: {process.stdout}")
        return None
    except Exception as e:
        print(f"Error: {e}")
        return None

def test_calendar_presets():
    """Test calendar filtering presets"""
    print("\n=== Testing Calendar Filtering Presets ===")
    
    # Test 'work' preset
    result = test_mcp_tool("list_calendars", {
        "calendar_filter": {
            "preset": "work"
        }
    })
    
    # Test 'clean' preset 
    result = test_mcp_tool("list_calendars", {
        "calendar_filter": {
            "preset": "clean"
        }
    })

def test_event_filtering():
    """Test event filtering"""
    print("\n=== Testing Event Filtering ===")
    
    # Get next 7 days
    start_date = datetime.now().strftime('%Y-%m-%d')
    end_date = (datetime.now() + timedelta(days=7)).strftime('%Y-%m-%d')
    
    # Test excluding all-day events
    result = test_mcp_tool("get_calendar_events", {
        "start_date": start_date,
        "end_date": end_date,
        "calendar_filter": {
            "preset": "main"
        },
        "event_filter": {
            "exclude_all_day": True,
            "minimum_duration_minutes": 15  # Only events 15+ minutes
        }
    })

def test_conflict_filtering():
    """Test conflict checking with filtering"""
    print("\n=== Testing Conflict Checking with Filtering ===")
    
    # Check conflicts for today, excluding short events
    today = datetime.now().strftime('%Y-%m-%d')
    
    result = test_mcp_tool("check_calendar_conflicts", {
        "dates": [today],
        "time_type": "evening",
        "calendar_filter": {
            "preset": "work"
        },
        "event_filter": {
            "exclude_all_day": True,
            "title_excludes": ["lunch", "break", "coffee"],
            "minimum_duration_minutes": 30  # Only consider meetings 30+ minutes
        }
    })

def main():
    """Run all filtering tests"""
    print("Testing Enhanced Calendar Filtering...")
    
    test_calendar_presets()
    test_event_filtering() 
    test_conflict_filtering()
    
    print("\n=== Testing Complete ===")

if __name__ == "__main__":
    main()