#!/usr/bin/env python3

import json
import subprocess
from datetime import datetime, timedelta

def test_copy_workflow():
    """Test copy functionality in a single MCP session"""
    
    # Calculate test dates
    tomorrow = datetime.now() + timedelta(days=1)
    day_after = tomorrow + timedelta(days=1)
    
    # Create JSON-RPC commands
    commands = []
    
    # 1. Create template event
    template_start = tomorrow.replace(hour=14, minute=30, second=0, microsecond=0)
    template_end = template_start + timedelta(hours=1)
    
    commands.append({
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "create_event",
            "arguments": {
                "title": "Jason Simons-V-8h",
                "start_datetime": template_start.strftime('%Y-%m-%dT%H:%M:%S'),
                "end_datetime": template_end.strftime('%Y-%m-%dT%H:%M:%S'),
                "location": "Out of Office",
                "notes": "Vacation day",
                "alarm_minutes": [60, 15]
            }
        },
        "id": 1
    })
    
    # 2. List recent events to get the template ID
    commands.append({
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "get_calendar_events",
            "arguments": {
                "start_date": tomorrow.strftime('%Y-%m-%d'),
                "end_date": tomorrow.strftime('%Y-%m-%d')
            }
        },
        "id": 2
    })
    
    # Write commands to stdin for a single MCP session
    stdin_input = ""
    for cmd in commands:
        stdin_input += json.dumps(cmd) + '\n'
    
    print("🔧 Testing Copy Format in Single Session")
    print("=" * 50)
    print(f"Commands to execute:")
    print(f"1. Create template: {commands[0]['params']['arguments']['title']}")
    print(f"2. List events to get ID")
    
    try:
        process = subprocess.run(
            ['.build/debug/apple-cal-mcp', '--verbose'],
            input=stdin_input,
            text=True,
            capture_output=True,
            timeout=30
        )
        
        print(f"\nReturn code: {process.returncode}")
        print(f"Stderr: {process.stderr}")
        
        if process.stdout:
            lines = process.stdout.strip().split('\n')
            for i, line in enumerate(lines):
                if line.startswith('{') and 'result' in line:
                    try:
                        response = json.loads(line)
                        if 'result' in response:
                            print(f"\nResponse {i+1}:")
                            if 'content' in response['result']:
                                content = response['result']['content'][0]['text']
                                data = json.loads(content)
                                print(json.dumps(data, indent=2))
                            else:
                                print(json.dumps(response['result'], indent=2))
                    except json.JSONDecodeError:
                        print(f"Raw line: {line}")
        
    except Exception as e:
        print(f"❌ Error: {e}")

def main():
    test_copy_workflow()

if __name__ == "__main__":
    main()