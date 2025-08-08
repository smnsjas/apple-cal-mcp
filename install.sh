#!/bin/bash
# Wrapper script for backward compatibility
# Forwards to the new location: scripts/ops/install.sh

exec "$(dirname "$0")/scripts/ops/install.sh" "$@"