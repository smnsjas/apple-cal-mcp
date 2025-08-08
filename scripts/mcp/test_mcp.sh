#!/bin/bash

# Simple shell-based MCP test script
# Tests basic JSON-RPC communication with the Apple Calendar MCP server

echo "🧪 Testing Apple Calendar MCP Server Protocol"
echo "============================================="

# Build the project first
echo "Building server..."
swift build > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build successful"

# Start server in background
echo "Starting server..."
.build/debug/apple-cal-mcp --verbose &
SERVER_PID=$!

# Give server time to start
sleep 2

# Function to send MCP request
send_request() {
    local request="$1"
    local test_name="$2"
    
    echo ""
    echo "📋 Test: $test_name"
    echo "→ Request: $request"
    
    # Send request and capture response
    response=$(echo "$request" | timeout 5s .build/debug/apple-cal-mcp)
    exit_code=$?
    
    if [ $exit_code -eq 124 ]; then
        echo "⏱️  Timeout - server may be waiting for more input"
    elif [ $exit_code -ne 0 ]; then
        echo "❌ Server error (exit code: $exit_code)"
    else
        echo "← Response: $response"
        # Check if response is valid JSON
        if echo "$response" | jq . > /dev/null 2>&1; then
            echo "✅ Valid JSON response"
        else
            echo "⚠️  Invalid JSON response"
        fi
    fi
}

# Test 1: Initialize
send_request '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' "Initialize"

# Test 2: List tools
send_request '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' "List Tools"

# Test 3: Invalid method
send_request '{"jsonrpc":"2.0","id":3,"method":"invalid"}' "Invalid Method"

# Cleanup
echo ""
echo "🧹 Cleaning up..."
kill $SERVER_PID 2>/dev/null

echo ""
echo "🎯 Test Summary:"
echo "- These tests verify basic JSON-RPC communication"
echo "- Calendar permission prompts are expected on first real usage"
echo "- Full integration testing requires MCP client setup"
echo ""
echo "Next steps:"
echo "1. Run: ./install.sh"
echo "2. Add to MCP client configuration"  
echo "3. Test with real calendar data"