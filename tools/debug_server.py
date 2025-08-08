#!/usr/bin/env python3
"""
Debug the MCP server startup
"""
import subprocess
import time

def debug_server():
    print("🔍 Debugging MCP Server Startup")
    print("=" * 35)
    
    try:
        # Start the server and capture all output
        print("Starting server with full output capture...")
        
        result = subprocess.run(
            ['.build/debug/apple-cal-mcp', '--verbose'],
            input='{"jsonrpc":"2.0","id":1,"method":"initialize"}\n',
            capture_output=True,
            text=True,
            timeout=10
        )
        
        print(f"Exit code: {result.returncode}")
        print(f"STDOUT:\n{result.stdout}")
        print(f"STDERR:\n{result.stderr}")
        
    except subprocess.TimeoutExpired as e:
        print("Server timed out (this might be expected if it's waiting for input)")
        print(f"STDOUT so far: {e.stdout}")
        print(f"STDERR so far: {e.stderr}")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    debug_server()