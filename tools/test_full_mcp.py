#!/usr/bin/env python3
"""
Full MCP server test with proper JSON-RPC communication
"""
import subprocess
import json
import sys
import time
import threading
from queue import Queue, Empty

def test_mcp_server():
    print("🧪 Full MCP Server Test")
    print("=" * 30)
    
    # Start the server
    print("Starting MCP server...")
    process = subprocess.Popen(
        ['.build/debug/apple-cal-mcp', '--verbose'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=0
    )
    
    # Create queues for output
    stdout_queue = Queue()
    stderr_queue = Queue()
    
    def read_stdout():
        for line in iter(process.stdout.readline, ''):
            stdout_queue.put(('stdout', line.strip()))
        stdout_queue.put(('stdout', None))
    
    def read_stderr():
        for line in iter(process.stderr.readline, ''):
            stderr_queue.put(('stderr', line.strip()))
        stderr_queue.put(('stderr', None))
    
    # Start reader threads
    stdout_thread = threading.Thread(target=read_stdout)
    stderr_thread = threading.Thread(target=read_stderr)
    stdout_thread.daemon = True
    stderr_thread.daemon = True
    stdout_thread.start()
    stderr_thread.start()
    
    def send_request(request, description):
        print(f"\n📤 {description}")
        request_json = json.dumps(request)
        print(f"   Request: {request_json}")
        
        # Send request
        process.stdin.write(request_json + '\n')
        process.stdin.flush()
        
        # Wait for response
        print("   Waiting for response...")
        start_time = time.time()
        
        while time.time() - start_time < 5:  # 5 second timeout
            # Check stdout
            try:
                msg_type, line = stdout_queue.get_nowait()
                if line:
                    print(f"   📥 Response: {line}")
                    try:
                        response = json.loads(line)
                        return response
                    except json.JSONDecodeError:
                        print(f"   ⚠️  Non-JSON response: {line}")
                        return {"raw_response": line}
            except Empty:
                pass
            
            # Check stderr
            try:
                msg_type, line = stderr_queue.get_nowait()
                if line:
                    print(f"   🔧 Debug: {line}")
            except Empty:
                pass
            
            time.sleep(0.1)
        
        print("   ⏱️  Timeout waiting for response")
        return None
    
    try:
        # Wait a moment for server to start
        time.sleep(1)
        
        # Test 1: Initialize
        init_response = send_request({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "test-client", "version": "1.0.0"}
            }
        }, "Initialize MCP Server")
        
        if init_response and "result" in init_response:
            print("   ✅ Initialize successful")
        else:
            print("   ❌ Initialize failed")
            
        # Test 2: List tools
        tools_response = send_request({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list"
        }, "List Available Tools")
        
        if tools_response and "result" in tools_response:
            tools = tools_response["result"].get("tools", [])
            print(f"   ✅ Found {len(tools)} tools:")
            for tool in tools:
                print(f"      - {tool.get('name')}")
        else:
            print("   ❌ Tools list failed")
        
        # Test 3: Check calendar conflicts
        conflict_response = send_request({
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": ["2025-08-08", "2025-08-09"],
                    "time_type": "evening",
                    "calendar_names": ["Calendar"]
                }
            }
        }, "Check Calendar Conflicts")
        
        if conflict_response and "result" in conflict_response:
            print("   ✅ Calendar conflict check successful")
            content = conflict_response["result"].get("content", [])
            if content and len(content) > 0:
                print(f"   📅 Response: {content[0].get('text', 'No text content')[:200]}...")
        else:
            print("   ❌ Calendar conflict check failed")
            
    except Exception as e:
        print(f"❌ Test failed: {e}")
        import traceback
        traceback.print_exc()
        
    finally:
        # Cleanup
        print("\n🧹 Cleaning up...")
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
    
    print("\n🎯 Test Complete!")
    print("If you saw successful responses above, the MCP server is working!")

if __name__ == "__main__":
    test_mcp_server()