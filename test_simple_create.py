#!/usr/bin/env python3

import json
import subprocess
from datetime import datetime, timedelta

def test_simple_create():
    """Test simple event creation"""
    
    tomorrow = datetime.now() + timedelta(days=1)
    start_time = tomorrow.replace(hour=14, minute=30, second=0, microsecond=0)
    end_time = start_time + timedelta(hours=1)
    
    request = {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "create_event",
            "arguments": {
                "title": "Simple Test Event",
                "start_datetime": start_time.strftime('%Y-%m-%dT%H:%M:%S'),
                "end_datetime": end_time.strftime('%Y-%m-%dT%H:%M:%S')
            }
        },
        "id": 1
    }
    
    print("Testing simple event creation...")
    print(f"Request: {json.dumps(request, indent=2)}")
    
    try:
        process = subprocess.run(
            ['.build/debug/apple-cal-mcp', '--verbose'],
            input=json.dumps(request) + '\n',
            text=True,
            capture_output=True,
            timeout=30
        )
        
        print(f"Return code: {process.returncode}")
        print(f"Stdout: {process.stdout}")
        print(f"Stderr: {process.stderr}")
        
        if process.returncode == 0:
            response = json.loads(process.stdout.strip())
            print(f"Response: {json.dumps(response, indent=2)}")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_simple_create()