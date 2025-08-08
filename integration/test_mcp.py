#!/usr/bin/env python3
"""
Test script for Apple Calendar MCP Server
Tests MCP protocol communication via stdin/stdout
"""

import json
import subprocess
import sys
import time
from typing import Dict, Any

def send_mcp_request(process: subprocess.Popen, request: Dict[str, Any]) -> Dict[str, Any]:
    """Send an MCP request and get the response"""
    request_json = json.dumps(request) + '\n'
    print(f"→ Sending: {request_json.strip()}")
    
    process.stdin.write(request_json.encode('utf-8'))
    process.stdin.flush()
    
    # Read response
    response_line = process.stdout.readline().decode('utf-8').strip()
    print(f"← Received: {response_line}")
    
    if not response_line:
        return {"error": "No response received"}
    
    try:
        return json.loads(response_line)
    except json.JSONDecodeError as e:
        return {"error": f"Invalid JSON response: {e}", "raw": response_line}

def test_mcp_server():
    """Test the MCP server with various requests"""
    
    print("🧪 Testing Apple Calendar MCP Server")
    print("=" * 50)
    
    # Start the server
    try:
        print("Starting server...")
        process = subprocess.Popen(
            ['swift', 'run', 'apple-cal-mcp', '--verbose'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=False,
            bufsize=0
        )
        
        # Give server time to start
        time.sleep(2)
        
        # Test 1: Initialize
        print("\n📋 Test 1: Initialize")
        init_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "test-client", "version": "1.0.0"}
            }
        }
        
        response = send_mcp_request(process, init_request)
        if "error" in response:
            print(f"❌ Initialize failed: {response['error']}")
            return False
        else:
            print("✅ Initialize successful")
        
        # Test 2: List tools
        print("\n🔧 Test 2: List Tools")
        tools_request = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list"
        }
        
        response = send_mcp_request(process, tools_request)
        if "error" in response:
            print(f"❌ Tools list failed: {response['error']}")
        else:
            tools = response.get("result", {}).get("tools", [])
            print(f"✅ Found {len(tools)} tools:")
            for tool in tools:
                print(f"  - {tool.get('name', 'Unknown')}: {tool.get('description', 'No description')}")
        
        # Test 3: Check calendar conflicts (this will likely fail due to calendar permissions)
        print("\n📅 Test 3: Check Calendar Conflicts")
        conflict_request = {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {
                "name": "check_calendar_conflicts",
                "arguments": {
                    "dates": ["2025-08-10", "2025-08-11"],
                    "time_type": "evening",
                    "calendar_names": ["Calendar"]
                }
            }
        }
        
        response = send_mcp_request(process, conflict_request)
        if "error" in response:
            print(f"⚠️  Conflict check failed (expected - no calendar permission): {response['error']}")
        else:
            print("✅ Conflict check successful")
            content = response.get("result", {}).get("content", [])
            if content:
                print(f"Response content: {content[0].get('text', 'No text')}")
        
        # Test 4: Get calendar events
        print("\n📋 Test 4: Get Calendar Events")
        events_request = {
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": {
                "name": "get_calendar_events",
                "arguments": {
                    "start_date": "2025-08-01",
                    "end_date": "2025-08-31",
                    "calendar_names": ["Calendar"]
                }
            }
        }
        
        response = send_mcp_request(process, events_request)
        if "error" in response:
            print(f"⚠️  Get events failed (expected - no calendar permission): {response['error']}")
        else:
            print("✅ Get events successful")
        
        # Test 5: Invalid method
        print("\n🚫 Test 5: Invalid Method")
        invalid_request = {
            "jsonrpc": "2.0",
            "id": 5,
            "method": "invalid_method"
        }
        
        response = send_mcp_request(process, invalid_request)
        if "error" in response and response["error"]["code"] == -32601:
            print("✅ Invalid method correctly rejected")
        else:
            print(f"❌ Expected method not found error, got: {response}")
        
        return True
        
    except Exception as e:
        print(f"❌ Test failed with exception: {e}")
        return False
    
    finally:
        # Clean up
        if 'process' in locals():
            process.terminate()
            process.wait()

def test_json_parsing():
    """Test JSON parsing with sample data"""
    print("\n🔍 Testing JSON Parsing")
    print("=" * 30)
    
    # Test request parsing
    sample_request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "check_calendar_conflicts",
            "arguments": {
                "dates": ["2025-08-10"],
                "time_type": "evening"
            }
        }
    }
    
    try:
        json_str = json.dumps(sample_request)
        parsed = json.loads(json_str)
        print("✅ JSON request parsing works")
        print(f"   Method: {parsed['method']}")
        print(f"   Tool: {parsed['params']['name']}")
    except Exception as e:
        print(f"❌ JSON parsing failed: {e}")

if __name__ == "__main__":
    print("Apple Calendar MCP Server Test Suite")
    print("====================================")
    
    # Test JSON parsing first
    test_json_parsing()
    
    # Test MCP communication
    success = test_mcp_server()
    
    if success:
        print("\n🎉 Basic MCP protocol tests completed")
        print("Note: Calendar permission tests expected to fail without user approval")
    else:
        print("\n💥 Tests failed")
        sys.exit(1)