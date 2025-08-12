#!/bin/bash
# Run all tests - both unit and integration

cd "$(dirname "$0")/../.."

echo "🧪 Running Apple Calendar MCP Tests"
echo "=================================="

# Run Swift unit tests
echo "📦 Running Swift unit tests..."
swift test

# Run comprehensive integration test
if [ -f "tools/test_comprehensive.py" ]; then
    echo ""
    echo "🔗 Running integration tests..."
    python3 tools/test_comprehensive.py
else
    echo "⚠️  Integration test not found"
fi

echo ""
echo "✅ All tests completed!"