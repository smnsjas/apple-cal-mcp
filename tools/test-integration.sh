#!/bin/bash
# Run specific integration tests

cd "$(dirname "$0")/../.."

echo "🔗 Apple Calendar MCP Integration Tests"
echo "======================================"

if [ $# -eq 0 ]; then
    echo "Available integration tests:"
    find Tests -name "test_*.py" -type f | grep -v test_comprehensive | sed 's|Tests/||' | sed 's|\.py||'
    echo ""
    echo "Usage: $0 <test_name>"
    echo "   or: $0 all    # Run all integration tests"
    exit 0
fi

if [ "$1" = "all" ]; then
    echo "Running all integration tests..."
    for test_file in Tests/test_*.py; do
        if [ -f "$test_file" ]; then
            echo ""
            echo "▶️ Running $(basename "$test_file")..."
            python3 "$test_file"
        fi
    done
else
    test_file="Tests/test_$1.py"
    if [ -f "$test_file" ]; then
        echo "▶️ Running $1..."
        python3 "$test_file"
    else
        echo "❌ Test not found: $test_file"
        echo "Available tests:"
        find Tests -name "test_*.py" -type f | sed 's|Tests/test_||' | sed 's|\.py||'
        exit 1
    fi
fi