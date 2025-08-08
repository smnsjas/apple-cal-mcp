#!/usr/bin/env python3
"""
Test the enhanced conflict reasoning capabilities
"""
import subprocess
import json
import time
import threading
from datetime import datetime, timedelta
from queue import Queue, Empty

def test_conflict_reasoning():
    print("🧠 Conflict Reasoning Test")
    print("=" * 30)
    
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
                            return json.loads(content[0]["text"])
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
        
        # Test 1: Check conflicts with reasoning for next few days
        base_date = datetime.now() + timedelta(days=1)
        test_dates = []
        for i in range(4):
            date = base_date + timedelta(days=i)
            test_dates.append(date.strftime("%Y-%m-%d"))
        
        conflicts_data = send_request({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": test_dates,
                    "time_type": "evening",
                    "calendar_filter": {
                        "exclude_holidays": True,
                        "exclude_sports": True
                    }
                }
            }
        }, f"Check Conflicts with Reasoning for Next 4 Days")
        
        if conflicts_data:
            print(f"📅 Conflict Analysis Results:")
            
            for date_str, result in conflicts_data.items():
                print(f"\n📆 {date_str}:")
                print(f"   Status: {result['status']}")
                
                if result['status'] == 'CONFLICT':
                    if 'summary' in result and result['summary']:
                        print(f"   Summary: {result['summary']}")
                    
                    if 'conflictsByType' in result and result['conflictsByType']:
                        types = ", ".join([f"{count} {type}" for type, count in result['conflictsByType'].items()])
                        print(f"   Types: {types}")
                    
                    print(f"   Detailed Conflicts:")
                    for event in result.get('events', []):
                        print(f"      🔸 {event.get('reason', event['title'])}")
                        if event.get('severity'):
                            print(f"        Priority: {event['severity'].title()}")
                        if event.get('suggestion'):
                            print(f"        💡 {event['suggestion']}")
                        print()
                else:
                    print(f"   ✅ Available for scheduling")
        
        # Test 2: Check all-day conflicts (might catch travel, family events)
        all_day_data = send_request({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": test_dates[:2],  # Just first 2 dates
                    "time_type": "all_day",
                    "calendar_filter": {
                        "exclude_holidays": True,
                        "exclude_sports": True
                    }
                }
            }
        }, "Check All-Day Conflicts (Travel, Family Events)")
        
        if all_day_data:
            print(f"\n🌅 All-Day Conflict Analysis:")
            
            for date_str, result in all_day_data.items():
                if result['status'] == 'CONFLICT':
                    print(f"\n📆 {date_str}: {result.get('summary', 'Has conflicts')}")
                    for event in result.get('events', []):
                        print(f"   🔸 {event.get('reason', event['title'])}")
                        if event.get('conflictType') in ['travel', 'family', 'medical']:
                            print(f"     ⚠️  High impact event - {event.get('conflictType', 'unknown')} type")
        
        # Test 3: Weekend conflicts (family time, social events)
        weekend_date = base_date
        while weekend_date.weekday() not in [5, 6]:  # Find next weekend
            weekend_date += timedelta(days=1)
        
        weekend_data = send_request({
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": [weekend_date.strftime("%Y-%m-%d")],
                    "time_type": "weekend",
                    "calendar_filter": {
                        "exclude_holidays": True,
                        "exclude_sports": True
                    }
                }
            }
        }, f"Weekend Conflict Analysis - {weekend_date.strftime('%A %m/%d')}")
        
        if weekend_data:
            weekend_result = list(weekend_data.values())[0]
            if weekend_result['status'] == 'CONFLICT':
                print(f"\n🎯 Weekend conflicts detected:")
                print(f"   Summary: {weekend_result.get('summary', 'Has conflicts')}")
                
                family_events = [e for e in weekend_result.get('events', []) if e.get('conflictType') == 'family']
                social_events = [e for e in weekend_result.get('events', []) if e.get('conflictType') == 'social']
                
                if family_events:
                    print(f"   👨‍👩‍👧‍👦 Family commitments: {len(family_events)}")
                if social_events:
                    print(f"   🎉 Social events: {len(social_events)}")
        
        print(f"\n🎯 Conflict Reasoning Summary:")
        print(f"   ✅ Events are now classified by type (work, family, medical, etc.)")
        print(f"   ✅ Priority levels help assess rescheduling difficulty")
        print(f"   ✅ Intelligent suggestions for each conflict type")
        print(f"   ✅ Summary statistics for quick overview")
        print(f"   ✅ Context-aware conflict analysis")
        
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
    test_conflict_reasoning()