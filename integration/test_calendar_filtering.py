#!/usr/bin/env python3
"""
Test the enhanced calendar filtering capabilities
"""
import subprocess
import json
import time
import threading
from queue import Queue, Empty

def test_calendar_filtering():
    print("📅 Calendar Filtering Test Suite")
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
    
    def send_request(request, description):
        print(f"\n🔍 {description}")
        
        process.stdin.write(json.dumps(request) + '\n')
        process.stdin.flush()
        
        start_time = time.time()
        while time.time() - start_time < 8:
            try:
                line = stdout_queue.get_nowait()
                if line and line.startswith('{"'):
                    response = json.loads(line)
                    if "result" in response:
                        content = response["result"].get("content", [])
                        if content:
                            data = json.loads(content[0]["text"])
                            return data
                        return response["result"]
                    else:
                        print(f"   ❌ Error: {response.get('error', {}).get('message', 'Unknown')}")
                        return None
            except (Empty, json.JSONDecodeError):
                pass
            time.sleep(0.1)
        
        print("   ⏱️ Timeout")
        return None
    
    try:
        time.sleep(1)
        
        # Test 1: List all calendars
        all_calendars = send_request({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "list_calendars",
                "arguments": {}
            }
        }, "List All Available Calendars")
        
        if all_calendars:
            print(f"   📊 Total: {all_calendars['count']} calendars shown, {all_calendars['total_available']} available")
            for cal in all_calendars['calendars'][:8]:  # Show first 8
                print(f"      - {cal['name']} ({cal['account']})")
            if len(all_calendars['calendars']) > 8:
                print(f"      ... and {len(all_calendars['calendars']) - 8} more")
        
        # Test 2: Filter out sports and holidays
        filtered_calendars = send_request({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "list_calendars",
                "arguments": {
                    "calendar_filter": {
                        "exclude_sports": True,
                        "exclude_holidays": True,
                        "exclude_subscribed": True
                    }
                }
            }
        }, "Exclude Sports, Holidays, and Subscribed")
        
        if filtered_calendars:
            print(f"   📊 Filtered to {filtered_calendars['count']} calendars:")
            for cal in filtered_calendars['calendars']:
                print(f"      - {cal['name']} ({cal['account']})")
        
        # Test 3: Only work calendars (Exchange + specific names)
        work_calendars = send_request({
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "list_calendars", 
                "arguments": {
                    "calendar_filter": {
                        "include_accounts": ["Exchange"],
                        "include_names": ["Calendar", "Work"],
                        "exclude_sports": True
                    }
                }
            }
        }, "Work Calendars Only (Exchange + Work names)")
        
        if work_calendars:
            print(f"   📊 Work calendars: {work_calendars['count']}")
            for cal in work_calendars['calendars']:
                print(f"      - {cal['name']} ({cal['account']})")
        
        # Test 4: Check conflicts using filtered calendars
        conflict_filtered = send_request({
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": ["2025-08-08", "2025-08-09"],
                    "time_type": "evening",
                    "calendar_filter": {
                        "exclude_sports": True,
                        "exclude_holidays": True,
                        "exclude_subscribed": True
                    }
                }
            }
        }, "Check Conflicts (Filtered - No Sports/Holidays)")
        
        if conflict_filtered:
            available_count = sum(1 for info in conflict_filtered.values() 
                                if info.get("status") == "AVAILABLE")
            print(f"   📊 {available_count}/{len(conflict_filtered)} dates available (filtered calendars)")
        
        # Test 5: Compare with specific calendar names
        conflict_specific = send_request({
            "jsonrpc": "2.0", 
            "id": 5,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": ["2025-08-08", "2025-08-09"],
                    "time_type": "evening",
                    "calendar_names": ["Calendar", "Work"]
                }
            }
        }, "Check Conflicts (Specific Names: Calendar, Work)")
        
        if conflict_specific:
            available_count = sum(1 for info in conflict_specific.values() 
                                if info.get("status") == "AVAILABLE")
            print(f"   📊 {available_count}/{len(conflict_specific)} dates available (specific calendars)")
        
        print(f"\n✅ Calendar Filtering Test Complete!")
        print(f"\n🎯 Key Benefits:")
        print(f"   • Exclude irrelevant calendars (sports, holidays, birthdays)")
        print(f"   • Focus on work vs personal calendars") 
        print(f"   • Filter by account type (Exchange, iCloud, Gmail)")
        print(f"   • Faster conflict checking with fewer calendars")
        print(f"   • Customizable filtering for different use cases")
        
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

if __name__ == "__main__":
    test_calendar_filtering()