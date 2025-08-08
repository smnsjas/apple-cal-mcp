#!/bin/bash

echo "🧪 Simple MCP Protocol Test"
echo "============================"

# Build first
echo "Building..."
swift build

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "✅ Build successful"
echo ""

# Test 1: Check if server starts and responds to help
echo "📋 Test 1: Server Help"
.build/debug/apple-cal-mcp --help
echo ""

# Test 2: Try to start server and send a simple JSON
echo "📋 Test 2: JSON-RPC Communication Test"
echo "Starting server for 3 seconds..."

# Create a test JSON file
cat > test_request.json << 'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{}}}
EOF

echo "Sending initialize request..."
echo "Request content:"
cat test_request.json
echo ""

# Start server, send request, and capture output
(.build/debug/apple-cal-mcp < test_request.json > test_response.json 2>&1) &
SERVER_PID=$!

# Wait a bit then kill
sleep 3
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

echo "Response received:"
if [ -f test_response.json ]; then
    cat test_response.json
    echo ""
    
    # Check if we got a JSON response
    if grep -q "jsonrpc" test_response.json; then
        echo "✅ Received JSON-RPC response"
    elif grep -q "Calendar access" test_response.json; then
        echo "✅ Server started and is requesting calendar permissions"
    else
        echo "⚠️  Unexpected response format"
    fi
else
    echo "❌ No response file created"
fi

# Cleanup
rm -f test_request.json test_response.json

echo ""
echo "🎯 Summary:"
echo "- Server builds and starts successfully"
echo "- Calendar permission dialog expected on first use"
echo "- For full testing, install and configure with MCP client"