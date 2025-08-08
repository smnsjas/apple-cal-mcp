#!/bin/bash

# Test the improved MCP server with Content-Length framing

echo "Testing improved MCP server with proper framing..."

# Function to send MCP message with Content-Length framing
send_mcp_message() {
    local message="$1"
    local length=${#message}
    printf "Content-Length: %d\r\n\r\n%s" "$length" "$message"
}

# Function to test MCP communication
test_mcp() {
    local server_pid
    
    # Start the server in background
    swift run apple-cal-mcp --verbose > server_output.log 2>&1 &
    server_pid=$!
    
    # Give it time to start
    sleep 3
    
    # Create a named pipe for communication
    mkfifo mcp_pipe
    
    # Send initialize request
    local init_request='{"jsonrpc":"2.0","id":"test-1","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}}'
    
    # Test with proper Content-Length framing
    {
        send_mcp_message "$init_request"
        # Give it time to process
        sleep 2
        
        # Send tools/list request
        local tools_request='{"jsonrpc":"2.0","id":"test-2","method":"tools/list"}'
        send_mcp_message "$tools_request"
        sleep 1
    } | swift run apple-cal-mcp --verbose 2>&1 | head -20
    
    # Clean up
    kill $server_pid 2>/dev/null || true
    rm -f mcp_pipe server_output.log
}

echo "Testing MCP protocol communication..."
test_mcp

echo "Test completed. Check output above for proper JSON-RPC responses."