#!/usr/bin/env python3
"""Wrapper script for backward compatibility - forwards to tools/manual_test.py."""

import subprocess
import sys
import os

script_dir = os.path.dirname(os.path.abspath(__file__))
new_location = os.path.join(script_dir, "tools", "manual_test.py")

sys.exit(subprocess.call([sys.executable, new_location] + sys.argv[1:]))