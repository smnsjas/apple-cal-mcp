#!/bin/bash
# Run SwiftLint if installed; print a helpful message otherwise

set -euo pipefail

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "SwiftLint not found. Install with: brew install swiftlint" >&2
  exit 127
fi

swiftlint --strict
