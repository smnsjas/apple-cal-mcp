#!/usr/bin/env python3

import json
import subprocess
import sys

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
        
        # Extract just the event count and titles for easier comparison
        if 'result' in response and 'content' in response['result']:
            content = response['result']['content'][0]['text']
            data = json.loads(content)
            if 'events' in data:
                events = data['events']
                print(f"Found {len(events)} events:")
                for event in events:
                    print(f"  - {event.get('title', 'Untitled')}: {event.get('time', 'No time')}")
            else:
                print(f"Response structure: {json.dumps(data, indent=2)}")
        return response
        
    except Exception as e:
        print(f"Error: {e}")
        return None

def main():
    """Test single date vs date range queries"""
    
    # Test 1: Single date query (Friday)
    test_mcp_tool("get_calendar_events", {
        "start_date": "2025-08-15",
        "end_date": "2025-08-15",
        "calendar_filter": {"preset": "all"}
    }, "Single Date Query (Friday 2025-08-15)")
    
    # Test 2: Date range query including Friday
    test_mcp_tool("get_calendar_events", {
        "start_date": "2025-08-14",
        "end_date": "2025-08-16",
        "calendar_filter": {"preset": "all"}
    }, "Date Range Query (2025-08-14 to 2025-08-16)")
    
    # Test 3: Single date with different end date calculation
    test_mcp_tool("get_calendar_events", {
        "start_date": "2025-08-15",
        "end_date": "2025-08-16",
        "calendar_filter": {"preset": "all"}
    }, "Single Date with Next Day End (2025-08-15 to 2025-08-16)")

if __name__ == "__main__":
    main()