#!/usr/bin/env python3
"""
Standalone test to verify MCP server works exactly as Claude Desktop would use it
"""
import subprocess
import json
import sys

def test_mcp_as_claude_would():
    print("🧪 Testing MCP Server (Claude Desktop simulation)")
    print("=" * 50)
    
    # Start server exactly as Claude Desktop would
    process = subprocess.Popen(
        ["/Users/jasonsimons/apple-cal-mcp", "--verbose"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    def send_and_check(request, description):
        print(f"\n📤 {description}")
        print(f"Request: {json.dumps(request)}")
        
        try:
            stdout, stderr = process.communicate(
                input=json.dumps(request) + '\n', 
                timeout=10
            )
            
            print(f"📥 Response: {stdout.strip()}")
            if stderr.strip():
                print(f"🔧 Debug: {stderr.strip()}")
            
            # Parse response
            if stdout.strip():
                response = json.loads(stdout.strip())
                if "result" in response:
                    print("✅ SUCCESS")
                    return response
                else:
                    print(f"❌ ERROR: {response.get('error', 'Unknown')}")
                    return None
            else:
                print("❌ No response")
                return None
                
        except subprocess.TimeoutExpired:
            print("⏱️ Timeout")
            process.kill()
            return None
        except json.JSONDecodeError as e:
            print(f"❌ JSON Error: {e}")
            return None
    
    # Test 1: Initialize (required first step)
    init_response = send_and_check({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "Claude Desktop", "version": "1.0.0"}
        }
    }, "Initialize MCP Server")
    
    if not init_response:
        print("\n❌ FAILED: MCP server won't initialize")
        sys.exit(1)
    
    print(f"\n🎯 MCP SERVER IS WORKING CORRECTLY")
    print(f"Server Info: {init_response['result']['serverInfo']}")
    print(f"Protocol: {init_response['result']['protocolVersion']}")
    
    print(f"\n💡 If Claude Desktop doesn't see this server:")
    print(f"1. Make sure you restarted Claude Desktop completely")
    print(f"2. Check the logs in Claude Desktop settings")
    print(f"3. Verify the config file path is correct")

if __name__ == "__main__":
    test_mcp_as_claude_would()