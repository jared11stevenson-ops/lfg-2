#!/bin/bash
# Render a script under xvfb (software GL). Usage: tools/shot.sh res://tools/x.gd [args]
source "$(dirname "$0")/get_godot.sh"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1
S="$1"; shift
xvfb-run -a -s "-screen 0 1600x900x24" "$GODOT" --path . --rendering-driver opengl3 --resolution ${RES:-1280x720} -s "$S" "$@" 2>&1 | grep -v -e ALSA -e "^$" -e V-Sync -e set_use_vsync -e "Mesa" -e "audio" -e "init_output" -e "MSAA" -e render_target_set -e "Godot Engine" | tail -${TAILN:-40}
