#!/bin/bash
# Usage: tools/run_tests.sh [filter]   -- exits nonzero on test failure OR any engine SCRIPT ERROR
source "$(dirname "$0")/get_godot.sh"
cd "$(dirname "$0")/.."
OUT=$(mktemp)
"$GODOT" --headless --path . -s res://tests/run_all.gd -- "$@" 2>&1 | grep -v "^$" | tee "$OUT"
RC=${PIPESTATUS[0]}
if grep -q "SCRIPT ERROR" "$OUT"; then echo "FAIL: engine SCRIPT ERROR(s) during tests"; rm -f "$OUT"; exit 1; fi
rm -f "$OUT"
exit $RC
