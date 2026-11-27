#!/usr/bin/env bash
# Headless test runner. Usage: GODOT=/path/to/godot tests/run_all.sh (from the td/ directory)
set -e
G=${GODOT:-godot}
$G --headless --path . --import >/dev/null 2>&1 || true
$G --headless --path . -s tests/test_type_chart.gd | tail -1
$G --headless --path . -s tests/test_upgrades.gd | tail -1
$G --headless --path . -s tests/test_levels.gd | tail -1
$G --headless --path . --quit-after 300 -s tests/test_session.gd | tail -1
$G --headless --path . --quit-after 600 -s tests/test_capture.gd | grep "capture:"
HOME=$(mktemp -d) $G --headless --path . --quit-after 3000 -s tests/test_flow.gd | grep "flow:"
$G --headless --path . -s tests/test_ui.gd | tail -1
$G --headless --path . --fixed-fps 60 -s tests/sim_auto.gd -- level=mossgate n=9 tiers=2 seed=5 | grep RESULT
