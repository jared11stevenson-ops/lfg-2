#!/bin/bash
# Usage: tools/run_tests.sh [filter]   -- exits nonzero on failure
source "$(dirname "$0")/get_godot.sh"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . -s res://tests/run_all.gd -- "$@" 2>&1 | grep -v "^$"
exit ${PIPESTATUS[0]}
