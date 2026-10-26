#!/usr/bin/env bash
# Attempt a Linux/X11 desktop export of the project. Usage: tools/ci_export.sh [out_dir]
# Needs: godot 4.4.1 binary ($GODOT, default /tmp/claude-0/godot), curl, unzip, network access to github.com.
# Exit codes: 0 exported; 10 templates unobtainable; 11 export ran but failed/produced nothing.
# Does NOT test the exported binary on a display, GPU, or Android; it only proves a binary is produced.
set -u
GODOT="${GODOT:-/tmp/claude-0/godot}"
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PROJ/build}"
VER="4.4.1.stable"
TPL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$VER"
CACHE="${CI_CACHE:-/tmp/godot_tpl_cache}"
URL="https://github.com/godotengine/godot-builds/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz"

if [ ! -f "$TPL_DIR/linux_release.x86_64" ]; then
  mkdir -p "$CACHE" "$TPL_DIR"
  if [ ! -s "$CACHE/templates.tpz" ]; then
    echo "[ci_export] downloading export templates (~1.2GB) ..."
    if ! curl -fsSL --retry 2 -o "$CACHE/templates.tpz.part" "$URL"; then
      echo "[ci_export] BLOCKED: cannot download $URL"; exit 10
    fi
    mv "$CACHE/templates.tpz.part" "$CACHE/templates.tpz"
  fi
  # only the linux x86_64 templates + version.txt are needed
  unzip -o -j -q "$CACHE/templates.tpz" 'templates/linux_release.x86_64' 'templates/linux_debug.x86_64' 'templates/version.txt' -d "$TPL_DIR" \
    || { echo "[ci_export] BLOCKED: templates archive unreadable"; exit 10; }
fi
[ -f "$TPL_DIR/linux_release.x86_64" ] || { echo "[ci_export] BLOCKED: linux template missing after extract"; exit 10; }

mkdir -p "$OUT"
PRESETS="$PROJ/export_presets.cfg"
CREATED=0
if [ ! -f "$PRESETS" ]; then
  CREATED=1
  cat > "$PRESETS" <<'CFG'
[preset.0]
name="Linux"
platform="Linux"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="tests/*, tools/*, docs/*"
export_path=""
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false

[preset.0.options]
custom_template/debug=""
custom_template/release=""
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
CFG
fi
trap '[ "$CREATED" = 1 ] && rm -f "$PRESETS"' EXIT
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1
"$GODOT" --headless --path "$PROJ" --export-release "Linux" "$OUT/lfg.x86_64" 2>&1 | tail -20
if [ -s "$OUT/lfg.x86_64" ]; then
  ls -la "$OUT/lfg.x86_64"; echo "[ci_export] OK (binary produced; NOT run on a display)"; exit 0
fi
echo "[ci_export] FAILED: no binary produced"; exit 11
