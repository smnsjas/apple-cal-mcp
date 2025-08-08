#!/usr/bin/env python3
"""
Test edge cases and error handling
"""
import subprocess
import json
import time
import threading
from queue import Queue, Empty

def test_edge_cases():
    print("🧪 Edge Cases & Error Handling")
    print("=" * 35)
    
    process = subprocess.Popen(
        ['.build/debug/apple-cal-mcp', '--verbose'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=0
    )
    
    stdout_queue = Queue()
    
    def read_stdout():
        for line in iter(process.stdout.readline, ''):
            stdout_queue.put(line.strip())
    
    stdout_thread = threading.Thread(target=read_stdout)
    stdout_thread.daemon = True
    stdout_thread.start()
    
    def send_request(request, description, expect_error=False):
        print(f"\n🔍 {description}")
        
        process.stdin.write(json.dumps(request) + '\n')
        process.stdin.flush()
        
        start_time = time.time()
        while time.time() - start_time < 5:
            try:
                line = stdout_queue.get_nowait()
                if line and line.startswith('{"'):
                    response = json.loads(line)
                    
                    if expect_error:
                        if "error" in response:
                            print(f"   ✅ Correctly returned error: {response['error']['message']}")
                        else:
                            print(f"   ⚠️  Expected error but got success")
                    else:
                        if "result" in response:
                            print(f"   ✅ Success")
                        else:
                            print(f"   ❌ Unexpected error: {response.get('error', {}).get('message', 'Unknown')}")
                    return response
            except (Empty, json.JSONDecodeError):
                pass
            time.sleep(0.1)
        
        print("   ❌ Timeout")
        return None
    
    try:
        time.sleep(1)
        
        # Test 1: Invalid date formats
        send_request({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": ["2025-13-45", "not-a-date", "2025/08/08"],  # Invalid formats
                    "time_type": "evening",
                    "calendar_names": ["Calendar"]
                }
            }
        }, "Invalid date formats", expect_error=True)
        
        # Test 2: Non-existent calendar
        send_request({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": ["2025-08-08"],
                    "time_type": "evening",
                    "calendar_names": ["NonExistentCalendar123"]
                }
            }
        }, "Non-existent calendar name")
        
        # Test 3: Invalid time_type
        send_request({
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": ["2025-08-08"],
                    "time_type": "invalid_time_type",
                    "calendar_names": ["Calendar"]
                }
            }
        }, "Invalid time_type", expect_error=True)
        
        # Test 4: Missing required parameters
        send_request({
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": ["2025-08-08"]
                    # Missing time_type
                }
            }
        }, "Missing required parameter", expect_error=True)
        
        # Test 5: Invalid evening hours
        send_request({
            "jsonrpc": "2.0",
            "id": 5,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": ["2025-08-08"],
                    "time_type": "evening",
                    "calendar_names": ["Calendar"],
                    "evening_hours": {
                        "start": "25:00",  # Invalid hour
                        "end": "23:00"
                    }
                }
            }
        }, "Invalid evening hours")
        
        # Test 6: Very old and future dates
        send_request({
            "jsonrpc": "2.0",
            "id": 6,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": ["1900-01-01", "2099-12-31"],
                    "time_type": "all_day",
                    "calendar_names": ["Calendar"]
                }
            }
        }, "Extreme date ranges")
        
        # Test 7: Empty dates array
        send_request({
            "jsonrpc": "2.0",
            "id": 7,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": [],  # Empty array
                    "time_type": "evening",
                    "calendar_names": ["Calendar"]
                }
            }
        }, "Empty dates array")
        
        # Test 8: Invalid method
        send_request({
            "jsonrpc": "2.0",
            "id": 8,
            "method": "invalid_method"
        }, "Invalid MCP method", expect_error=True)
        
        # Test 9: Invalid tool name
        send_request({
            "jsonrpc": "2.0",
            "id": 9,
            "method": "tools/call",
            "params": {
                "name": "invalid_tool_name",
                "arguments": {}
            }
        }, "Invalid tool name", expect_error=True)
        
        # Test 10: Malformed JSON request
        print(f"\n🔍 Malformed JSON request")
        process.stdin.write('{"jsonrpc":"2.0","id":10,"method":"tools/list"invalid}\n')
        process.stdin.flush()
        
        start_time = time.time()
        while time.time() - start_time < 3:
            try:
                line = stdout_queue.get_nowait()
                if line and '"error"' in line:
                    print(f"   ✅ Correctly handled malformed JSON")
                    break
            except Empty:
                pass
            time.sleep(0.1)
        
    except Exception as e:
        print(f"❌ Edge case testing failed: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
    
    print("\n🎯 Edge Case Testing Complete!")

if __name__ == "__main__":
    test_edge_cases()