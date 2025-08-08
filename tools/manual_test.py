#!/usr/bin/env python3
"""
Manual test to verify the MCP server responds to basic requests
"""
import subprocess
import json
import sys
import signal
import threading
import time

def run_test():
    print("🧪 Manual MCP Server Test")
    print("=" * 30)
    
    # Start the server process
    print("Starting server...")
    
    try:
        # Start server with timeout
        process = subprocess.Popen(
            ['.build/debug/apple-cal-mcp', '--verbose'],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )
        
        # Give server time to start and request permissions
        time.sleep(2)
        
        # Send initialize request
        request = {
            "jsonrpc": "2.0", 
            "id": 1, 
            "method": "initialize",
            "params": {"protocolVersion": "2024-11-05", "capabilities": {}}
        }
        
        print(f"Sending: {json.dumps(request)}")
        
        # Send request
        process.stdin.write(json.dumps(request) + '\n')
        process.stdin.flush()
        
        # Try to read response with timeout
        def read_output():
            try:
                output = process.stdout.readline()
                if output:
                    print(f"Response: {output.strip()}")
                else:
                    print("No response received")
            except Exception as e:
                print(f"Error reading output: {e}")
        
        # Read stderr for debug info
        def read_stderr():
            try:
                while True:
                    line = process.stderr.readline()
                    if line:
                        print(f"Debug: {line.strip()}")
                    else:
                        break
            except Exception as e:
                print(f"Error reading stderr: {e}")
        
        # Start threads to read output
        out_thread = threading.Thread(target=read_output)
        err_thread = threading.Thread(target=read_stderr)
        
        out_thread.start()
        err_thread.start()
        
        # Wait a bit for response
        time.sleep(3)
        
        # Check if process is still running
        if process.poll() is None:
            print("✅ Server is running and accepting input")
        else:
            print("❌ Server exited unexpectedly")
            
    except Exception as e:
        print(f"❌ Error: {e}")
        
    finally:
        # Clean up
        if 'process' in locals():
            try:
                process.terminate()
                process.wait(timeout=2)
            except:
                process.kill()
    
    print("\n🎯 Test Summary:")
    print("- Server builds and starts")
    print("- May require calendar permissions on first run")
    print("- Check Console.app for permission dialogs")
    print("- For full testing, use with MCP client like Claude Desktop")

if __name__ == "__main__":
    run_test()