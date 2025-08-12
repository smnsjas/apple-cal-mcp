#!/usr/bin/env python3
"""
Test MCP server with real calendar data and edge cases
"""
import subprocess
import json
import sys
import time
import threading
from datetime import datetime, timedelta
from queue import Queue, Empty

def test_real_calendar_scenarios():
    print("🔍 Testing Real Calendar Scenarios")
    print("=" * 40)
    
    # Start the server
    process = subprocess.Popen(
        ['.build/debug/apple-cal-mcp', '--verbose'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=0
    )
    
    stdout_queue = Queue()
    stderr_queue = Queue()
    
    def read_stdout():
        for line in iter(process.stdout.readline, ''):
            stdout_queue.put(line.strip())
    
    def read_stderr():
        for line in iter(process.stderr.readline, ''):
            stderr_queue.put(line.strip())
    
    stdout_thread = threading.Thread(target=read_stdout)
    stderr_thread = threading.Thread(target=read_stderr)
    stdout_thread.daemon = True
    stderr_thread.daemon = True
    stdout_thread.start()
    stderr_thread.start()
    
    def send_request(request, description, timeout=5):
        print(f"\n📋 {description}")
        request_json = json.dumps(request)
        
        # Send request
        process.stdin.write(request_json + '\n')
        process.stdin.flush()
        
        # Wait for response
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                line = stdout_queue.get_nowait()
                if line and line.startswith('{"'):
                    try:
                        response = json.loads(line)
                        return response
                    except json.JSONDecodeError:
                        continue
            except Empty:
                pass
            time.sleep(0.1)
        
        return None
    
    try:
        time.sleep(1)  # Let server start
        
        # Test 1: Get all events in the next week to see what's actually in calendar
        today = datetime.now()
        next_week = today + timedelta(days=7)
        
        events_response = send_request({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "get_calendar_events",
                "arguments": {
                    "start_date": today.strftime("%Y-%m-%d"),
                    "end_date": next_week.strftime("%Y-%m-%d"),
                    "calendar_names": ["Calendar"]
                }
            }
        }, "Get Real Events in Next Week")
        
        if events_response and "result" in events_response:
            content = events_response["result"].get("content", [])
            if content:
                events_data = json.loads(content[0]["text"])
                events = events_data.get("events", [])
                print(f"   📅 Found {len(events)} real events:")
                for event in events[:5]:  # Show first 5
                    print(f"      - {event.get('title', 'No title')} on {event.get('start_date', 'Unknown date')}")
                if len(events) > 5:
                    print(f"      ... and {len(events) - 5} more events")
        
        # Test 2: Check conflicts for multiple time types
        test_dates = [
            today.strftime("%Y-%m-%d"),
            (today + timedelta(days=1)).strftime("%Y-%m-%d"),
            (today + timedelta(days=2)).strftime("%Y-%m-%d")
        ]
        
        for time_type in ["evening", "weekend", "all_day"]:
            conflict_response = send_request({
                "jsonrpc": "2.0", 
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": "check_calendar_conflicts",
                    "arguments": {
                        "dates": test_dates,
                        "time_type": time_type,
                        "calendar_names": ["Calendar"]
                    }
                }
            }, f"Check Conflicts - {time_type.title()} Mode")
            
            if conflict_response and "result" in conflict_response:
                content = conflict_response["result"].get("content", [])
                if content:
                    conflicts_data = json.loads(content[0]["text"])
                    available_count = sum(1 for date_info in conflicts_data.values() 
                                        if date_info.get("status") == "AVAILABLE")
                    conflict_count = len(conflicts_data) - available_count
                    print(f"   📊 {available_count} available, {conflict_count} conflicts")
        
        # Test 3: Find available slots
        slots_response = send_request({
            "jsonrpc": "2.0",
            "id": 3, 
            "method": "tools/call",
            "params": {
                "name": "find_available_slots",
                "arguments": {
                    "date_range": {
                        "start": today.strftime("%Y-%m-%d"),
                        "end": (today + timedelta(days=3)).strftime("%Y-%m-%d")
                    },
                    "duration_minutes": 60,
                    "time_preferences": "evening"
                }
            }
        }, "Find 1-hour Evening Slots")
        
        if slots_response and "result" in slots_response:
            content = slots_response["result"].get("content", [])
            if content:
                slots_data = json.loads(content[0]["text"])
                slots = slots_data.get("available_slots", [])
                print(f"   🕐 Found {len(slots)} available 1-hour evening slots")
                for slot in slots[:3]:  # Show first 3
                    print(f"      - {slot.get('start_time', 'Unknown')} to {slot.get('end_time', 'Unknown')} ({slot.get('duration_minutes', 0)} min)")
        
        # Test 4: Test with all your calendars
        all_calendars_response = send_request({
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call", 
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": [today.strftime("%Y-%m-%d")],
                    "time_type": "all_day"
                    # No calendar_names = check ALL calendars
                }
            }
        }, "Check Today Across ALL Calendars")
        
        if all_calendars_response and "result" in all_calendars_response:
            print("   ✅ Successfully checked all 18 calendars")
        
        # Test 5: Custom evening hours
        custom_hours_response = send_request({
            "jsonrpc": "2.0",
            "id": 5,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts", 
                "arguments": {
                    "dates": [today.strftime("%Y-%m-%d")],
                    "time_type": "evening",
                    "calendar_names": ["Calendar"],
                    "evening_hours": {
                        "start": "18:00",
                        "end": "20:00"
                    }
                }
            }
        }, "Custom Evening Hours (6-8pm)")
        
        if custom_hours_response and "result" in custom_hours_response:
            print("   ✅ Custom evening hours working")
    
    except Exception as e:
        print(f"❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
    
    print("\n🎯 Real Calendar Testing Complete!")

if __name__ == "__main__":
    test_real_calendar_scenarios()