#!/bin/bash
# Fetch Godot 4.7 into /tmp/gd if missing. Usage: source tools/get_godot.sh; "$GODOT" --version
GODOT=/tmp/gd/Godot_v4.7-stable_linux.x86_64
if [ ! -x "$GODOT" ]; then
  mkdir -p /tmp/gd && cd /tmp/gd && curl -sL -o g.zip https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip && unzip -oq g.zip && chmod +x "$GODOT"
fi
export GODOT
