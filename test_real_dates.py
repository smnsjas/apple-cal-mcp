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
    print(f"Request args: {json.dumps(args, indent=2)}")
    
    try:
        process = subprocess.run(
            ['.build/debug/apple-cal-mcp', '--verbose'],  # Add verbose flag
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
        
        # Extract just the event count and titles for easier comparison
        if 'result' in response and 'content' in response['result']:
            content = response['result']['content'][0]['text']
            data = json.loads(content)
            if 'events' in data:
                events = data['events']
                print(f"Found {len(events)} events:")
                for event in events:
                    print(f"  - {event.get('title', 'Untitled')}: {event.get('time', event.get('start_time', 'No time'))}")
            else:
                print(f"Response structure: {json.dumps(data, indent=2)}")
        return response
        
    except Exception as e:
        print(f"Error: {e}")
        if process:
            print(f"Stderr: {process.stderr}")
        return None

def main():
    """Test with current and nearby dates"""
    
    today = datetime.now()
    print(f"Testing with dates around today: {today.strftime('%Y-%m-%d')}")
    
    # Test today
    today_str = today.strftime('%Y-%m-%d')
    test_mcp_tool("get_calendar_events", {
        "start_date": today_str,
        "end_date": today_str,
        "calendar_filter": {"preset": "all"}
    }, f"Today ({today_str})")
    
    # Test this week
    week_start = (today - timedelta(days=today.weekday())).strftime('%Y-%m-%d')
    week_end = (today + timedelta(days=6-today.weekday())).strftime('%Y-%m-%d')
    test_mcp_tool("get_calendar_events", {
        "start_date": week_start,
        "end_date": week_end,
        "calendar_filter": {"preset": "all"}
    }, f"This Week ({week_start} to {week_end})")
    
    # Test next 7 days
    next_week_end = (today + timedelta(days=7)).strftime('%Y-%m-%d')
    test_mcp_tool("get_calendar_events", {
        "start_date": today_str,
        "end_date": next_week_end,
        "calendar_filter": {"preset": "all"}
    }, f"Next 7 Days ({today_str} to {next_week_end})")

if __name__ == "__main__":
    main()