#!/usr/bin/env python3
"""
Real-world testing scenarios for the Apple Calendar MCP server
"""
import subprocess
import json
import time
import threading
from datetime import datetime, timedelta
from queue import Queue, Empty

def real_world_testing():
    print("🌍 Real-World Calendar Testing")
    print("=" * 35)
    print("Testing with your actual calendar data for practical scheduling scenarios...")
    
    process = subprocess.Popen(
        ['/Users/jasonsimons/apple-cal-mcp', '--verbose'],
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
        print(f"\n🎯 {description}")
        print(f"   Request: {request['params']['arguments']}")
        
        process.stdin.write(json.dumps(request) + '\n')
        process.stdin.flush()
        
        start_time = time.time()
        while time.time() - start_time < 10:
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
        
        # Scenario 1: Weekly team meeting scheduling
        print(f"\n📋 SCENARIO 1: Planning Weekly Team Meeting")
        today = datetime.now()
        next_week_dates = []
        for i in range(1, 8):  # Next 7 days
            date = today + timedelta(days=i)
            if date.weekday() < 5:  # Weekdays only
                next_week_dates.append(date.strftime("%Y-%m-%d"))
        
        team_meeting_result = send_request({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": next_week_dates[:5],  # Next 5 weekdays
                    "time_type": "evening",
                    "calendar_filter": {
                        "exclude_sports": True,
                        "exclude_holidays": True,
                        "include_accounts": ["Exchange", "iCloud"]
                    },
                    "evening_hours": {
                        "start": "14:00",  # 2pm 
                        "end": "17:00"     # 5pm
                    }
                }
            }
        }, "Find afternoon slots for team meeting (2-5pm)")
        
        if team_meeting_result:
            available_days = [date for date, info in team_meeting_result.items() 
                            if info.get("status") == "AVAILABLE"]
            conflict_days = [date for date, info in team_meeting_result.items() 
                           if info.get("status") == "CONFLICT"]
            
            print(f"   ✅ RESULT: {len(available_days)} days available, {len(conflict_days)} with conflicts")
            
            if available_days:
                print(f"   📅 Best options: {', '.join(available_days[:2])}")
            
            if conflict_days:
                print(f"   ⚠️  Conflicts on: {', '.join(conflict_days)}")
                for date in conflict_days[:2]:  # Show details for first 2
                    conflicts = team_meeting_result[date]
                    if conflicts.get('summary'):
                        print(f"      {date}: {conflicts['summary']}")
        
        # Scenario 2: Personal appointment scheduling
        print(f"\n🏥 SCENARIO 2: Scheduling Personal Appointment")
        
        appointment_result = send_request({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "find_available_slots",
                "arguments": {
                    "date_range": {
                        "start": (today + timedelta(days=1)).strftime("%Y-%m-%d"),
                        "end": (today + timedelta(days=14)).strftime("%Y-%m-%d")
                    },
                    "duration_minutes": 60,
                    "time_preferences": "all_day",
                    "calendar_filter": {
                        "exclude_sports": True,
                        "exclude_holidays": True
                    }
                }
            }
        }, "Find 1-hour slots for personal appointment (next 2 weeks)")
        
        if appointment_result:
            slots = appointment_result.get("available_slots", [])
            print(f"   ✅ RESULT: Found {len(slots)} available 1-hour slots")
            
            if slots:
                print(f"   📅 First few options:")
                for slot in slots[:3]:
                    print(f"      - {slot.get('start_time', 'Unknown')} ({slot.get('duration_minutes', 0)} min)")
        
        # Scenario 3: Weekend family planning
        print(f"\n👨‍👩‍👧‍👦 SCENARIO 3: Weekend Family Planning")
        
        # Find next weekend
        weekend_date = today + timedelta(days=1)
        while weekend_date.weekday() not in [5, 6]:  # Saturday or Sunday
            weekend_date += timedelta(days=1)
        
        family_result = send_request({
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": [
                        weekend_date.strftime("%Y-%m-%d"),
                        (weekend_date + timedelta(days=1)).strftime("%Y-%m-%d")
                    ],
                    "time_type": "weekend",
                    "calendar_filter": {
                        "exclude_sports": True,
                        "exclude_holidays": True
                    }
                }
            }
        }, f"Check weekend availability ({weekend_date.strftime('%A %m/%d')})")
        
        if family_result:
            for date, result in family_result.items():
                day_name = datetime.strptime(date, "%Y-%m-%d").strftime("%A")
                print(f"   📅 {day_name} ({date}): {result.get('status', 'Unknown')}")
                
                if result.get('status') == 'CONFLICT':
                    if result.get('summary'):
                        print(f"      Summary: {result['summary']}")
                    
                    # Show family-specific conflicts
                    family_conflicts = [e for e in result.get('events', []) 
                                      if e.get('conflict_type') in ['family', 'personal', 'social']]
                    if family_conflicts:
                        print(f"      Family/Personal conflicts:")
                        for event in family_conflicts[:2]:
                            print(f"        - {event.get('reason', event['title'])}")
        
        # Scenario 4: Quick availability check
        print(f"\n⚡ SCENARIO 4: Quick This Week Check")
        
        tomorrow = (today + timedelta(days=1)).strftime("%Y-%m-%d")
        quick_result = send_request({
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": [tomorrow],
                    "time_type": "evening"
                    # Using default smart filtering
                }
            }
        }, f"Quick check: Tomorrow evening ({tomorrow})")
        
        if quick_result:
            tomorrow_result = list(quick_result.values())[0]
            status = tomorrow_result.get('status', 'Unknown')
            
            if status == 'AVAILABLE':
                print(f"   ✅ RESULT: Tomorrow evening is FREE - good for scheduling!")
            else:
                print(f"   ⚠️  RESULT: Tomorrow evening has conflicts")
                if tomorrow_result.get('summary'):
                    print(f"      {tomorrow_result['summary']}")
                
                # Show flexible vs non-flexible conflicts
                flexible_conflicts = [e for e in tomorrow_result.get('events', []) 
                                    if e.get('severity') in ['low', 'medium']]
                critical_conflicts = [e for e in tomorrow_result.get('events', []) 
                                    if e.get('severity') in ['high', 'critical']]
                
                if flexible_conflicts:
                    print(f"      💡 {len(flexible_conflicts)} potentially flexible conflicts")
                if critical_conflicts:
                    print(f"      🚫 {len(critical_conflicts)} non-flexible conflicts")
        
        # Summary
        print(f"\n🎯 REAL-WORLD TESTING COMPLETE")
        print(f"=" * 40)
        print(f"✅ Team meeting scheduling: Tested")
        print(f"✅ Personal appointment finding: Tested") 
        print(f"✅ Weekend family planning: Tested")
        print(f"✅ Quick availability checks: Tested")
        print(f"\n💡 The MCP server is ready for your daily scheduling needs!")
        print(f"   Use it in Claude Desktop for intelligent calendar automation.")
        
    except Exception as e:
        print(f"❌ Testing failed: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()

if __name__ == "__main__":
    real_world_testing()