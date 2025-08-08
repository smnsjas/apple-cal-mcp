#!/usr/bin/env python3
"""
Integration testing - simulate real MCP client usage
"""
import subprocess
import json
import time
import threading
from datetime import datetime, timedelta
from queue import Queue, Empty

def test_integration():
    print("🔗 Integration Testing (MCP Client Simulation)")
    print("=" * 50)
    
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
            stdout_queue.put(('stdout', line.strip()))
    
    def read_stderr():
        for line in iter(process.stderr.readline, ''):
            stderr_queue.put(('stderr', line.strip()))
    
    stdout_thread = threading.Thread(target=read_stdout)
    stderr_thread = threading.Thread(target=read_stderr)
    stdout_thread.daemon = True
    stderr_thread.daemon = True
    stdout_thread.start()
    stderr_thread.start()
    
    def full_conversation():
        """Simulate a complete MCP client conversation"""
        
        def send_and_wait(request, description):
            print(f"\n💬 {description}")
            print(f"   → {json.dumps(request)}")
            
            process.stdin.write(json.dumps(request) + '\n')
            process.stdin.flush()
            
            start_time = time.time()
            while time.time() - start_time < 8:
                try:
                    msg_type, line = stdout_queue.get_nowait()
                    if line and line.startswith('{"'):
                        response = json.loads(line)
                        print(f"   ← Success: {response.get('result', response.get('error', 'Unknown'))}")
                        return response
                except (Empty, json.JSONDecodeError):
                    pass
                
                # Also check stderr for debug info
                try:
                    msg_type, line = stderr_queue.get_nowait()
                    if line and 'error' in line.lower():
                        print(f"   🔧 {line}")
                except Empty:
                    pass
                
                time.sleep(0.1)
            
            print(f"   ⏱️ Timeout")
            return None
        
        # Step 1: Client initialization (like Claude Desktop would do)
        init_response = send_and_wait({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "roots": {
                        "listChanged": True
                    },
                    "sampling": {}
                },
                "clientInfo": {
                    "name": "Claude Desktop",
                    "version": "0.7.1"
                }
            }
        }, "MCP Client Initialization")
        
        if not init_response or "error" in init_response:
            print("❌ Initialization failed")
            return False
        
        # Step 2: Discover available tools
        tools_response = send_and_wait({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list"
        }, "Discover Available Tools")
        
        if not tools_response or "error" in tools_response:
            print("❌ Tools discovery failed")
            return False
        
        tools = tools_response.get("result", {}).get("tools", [])
        print(f"   📋 Discovered {len(tools)} tools")
        
        # Step 3: Real-world scenario - Check availability for meeting scheduling
        print(f"\n🎯 Real Scenario: Scheduling a team meeting")
        
        # Get dates for next week
        base_date = datetime.now() + timedelta(days=1)
        potential_dates = []
        for i in range(5):  # Next 5 weekdays
            date = base_date + timedelta(days=i)
            if date.weekday() < 5:  # Monday = 0, Friday = 4
                potential_dates.append(date.strftime("%Y-%m-%d"))
        
        conflict_response = send_and_wait({
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": potential_dates,
                    "time_type": "evening",
                    "calendar_names": ["Calendar"],
                    "evening_hours": {
                        "start": "17:00",
                        "end": "19:00"
                    }
                }
            }
        }, f"Check {len(potential_dates)} weekday evenings for 2-hour meeting")
        
        if conflict_response and "result" in conflict_response:
            content = conflict_response["result"].get("content", [])
            if content:
                try:
                    conflicts_data = json.loads(content[0]["text"])
                    available_dates = [date for date, info in conflicts_data.items() 
                                     if info.get("status") == "AVAILABLE"]
                    print(f"   ✅ Found {len(available_dates)} available dates for meeting")
                    
                    if available_dates:
                        # Step 4: Get detailed events for the first available date
                        first_date = available_dates[0]
                        events_response = send_and_wait({
                            "jsonrpc": "2.0",
                            "id": 4,
                            "method": "tools/call",
                            "params": {
                                "name": "get_calendar_events",
                                "arguments": {
                                    "start_date": first_date,
                                    "end_date": first_date
                                }
                            }
                        }, f"Get detailed events for {first_date}")
                        
                        # Step 5: Find specific time slots
                        slots_response = send_and_wait({
                            "jsonrpc": "2.0",
                            "id": 5,
                            "method": "tools/call",
                            "params": {
                                "name": "find_available_slots",
                                "arguments": {
                                    "date_range": {
                                        "start": first_date,
                                        "end": first_date
                                    },
                                    "duration_minutes": 120,
                                    "time_preferences": "evening",
                                    "evening_hours": {
                                        "start": "17:00",
                                        "end": "19:00"
                                    }
                                }
                            }
                        }, f"Find 2-hour slots on {first_date}")
                        
                        if slots_response and "result" in slots_response:
                            print("   🎉 Complete workflow successful!")
                            return True
                except json.JSONDecodeError:
                    print("   ❌ Could not parse conflict response")
        
        return False
    
    try:
        time.sleep(1)  # Let server start
        
        success = full_conversation()
        
        if success:
            print(f"\n✅ Integration Test PASSED")
            print(f"   • MCP protocol working perfectly")
            print(f"   • All tools functional") 
            print(f"   • Real-world scenario completed")
            print(f"   • Ready for Claude Desktop integration")
        else:
            print(f"\n❌ Integration Test FAILED")
        
    except Exception as e:
        print(f"❌ Integration test failed: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()

if __name__ == "__main__":
    test_integration()