#!/usr/bin/env bash
# Headless test runner. Usage: GODOT=/path/to/godot tests/run_all.sh (from the td/ directory)
set -e
G=${GODOT:-godot}
$G --headless --path . --import >/dev/null 2>&1 || true
$G --headless --path . -s tests/test_type_chart.gd | tail -1
$G --headless --path . -s tests/test_upgrades.gd | tail -1
$G --headless --path . --fixed-fps 60 -s tests/sim_waves.gd -- tickindle:500,260:aaab dugloom:430,260:bbb hutzin:850,420:aab tickindle:850,470:bbbb dugloom:560,260:aaa hutzin:640,250:bbb tickindle:430,470:aa | grep state=
