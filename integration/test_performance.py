#!/usr/bin/env python3
"""
Performance testing for the MCP server
"""
import subprocess
import json
import time
import threading
from datetime import datetime, timedelta
from queue import Queue, Empty

def test_performance():
    print("⚡ Performance Testing")
    print("=" * 25)
    
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
    
    def read_stdout():
        for line in iter(process.stdout.readline, ''):
            stdout_queue.put(line.strip())
    
    stdout_thread = threading.Thread(target=read_stdout)
    stdout_thread.daemon = True
    stdout_thread.start()
    
    def timed_request(request, description):
        start_time = time.time()
        
        # Send request
        process.stdin.write(json.dumps(request) + '\n')
        process.stdin.flush()
        
        # Wait for response
        while time.time() - start_time < 10:
            try:
                line = stdout_queue.get_nowait()
                if line and line.startswith('{"'):
                    end_time = time.time()
                    duration = end_time - start_time
                    print(f"   ⏱️  {description}: {duration:.3f}s")
                    return json.loads(line), duration
            except (Empty, json.JSONDecodeError):
                pass
            time.sleep(0.01)
        
        print(f"   ❌ {description}: Timeout")
        return None, None
    
    try:
        time.sleep(1)  # Let server start
        
        # Test 1: Single date check speed
        today = datetime.now().strftime("%Y-%m-%d")
        single_response, single_time = timed_request({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": [today],
                    "time_type": "evening",
                    "calendar_names": ["Calendar"]
                }
            }
        }, "Single date check")
        
        # Test 2: Multiple dates (as requested - 10+ dates)
        dates = [(datetime.now() + timedelta(days=i)).strftime("%Y-%m-%d") 
                for i in range(15)]  # 15 dates
        
        multi_response, multi_time = timed_request({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": dates,
                    "time_type": "evening",
                    "calendar_names": ["Calendar"]
                }
            }
        }, f"15 dates simultaneously")
        
        # Test 3: Large date range events query
        start_date = datetime.now().strftime("%Y-%m-%d")
        end_date = (datetime.now() + timedelta(days=90)).strftime("%Y-%m-%d")
        
        events_response, events_time = timed_request({
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "get_calendar_events",
                "arguments": {
                    "start_date": start_date,
                    "end_date": end_date,
                    "calendar_names": ["Calendar"]
                }
            }
        }, "90-day events query")
        
        # Test 4: All calendars check
        all_cal_response, all_cal_time = timed_request({
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": dates[:5],  # 5 dates across all calendars
                    "time_type": "all_day"
                    # No calendar_names = all 18 calendars
                }
            }
        }, "5 dates across all 18 calendars")
        
        # Performance Summary
        print(f"\n📊 Performance Summary:")
        print(f"   • Single date: {single_time:.3f}s" if single_time else "   • Single date: Failed")
        print(f"   • 15 dates: {multi_time:.3f}s" if multi_time else "   • 15 dates: Failed")
        print(f"   • 90-day query: {events_time:.3f}s" if events_time else "   • 90-day query: Failed")
        print(f"   • All calendars: {all_cal_time:.3f}s" if all_cal_time else "   • All calendars: Failed")
        
        if multi_time and multi_time < 2.0:
            print("   ✅ Meets requirement: 10+ dates in under 2 seconds")
        elif multi_time:
            print(f"   ⚠️  15 dates took {multi_time:.3f}s (target: <2s)")
        else:
            print("   ❌ Could not test multi-date performance")
            
    except Exception as e:
        print(f"❌ Performance test failed: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()

if __name__ == "__main__":
    test_performance()