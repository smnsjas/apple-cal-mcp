#!/bin/bash
# Wrapper script for backward compatibility
# Forwards to the new location: scripts/mcp/test_mcp.sh

exec "$(dirname "$0")/scripts/mcp/test_mcp.sh" "$@"