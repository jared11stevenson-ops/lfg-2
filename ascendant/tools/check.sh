#!/bin/bash
# Compile-check every script; prints only errors. Usage: tools/check.sh
source "$(dirname "$0")/get_godot.sh"; cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1
for f in $(find core sim art game ui -name '*.gd' 2>/dev/null); do
  out=$("$GODOT" --headless --path . --check-only --script res://$f 2>&1 | grep -A1 "SCRIPT ERROR")
  [ -n "$out" ] && echo "== $f" && echo "$out"
done; echo check-done
