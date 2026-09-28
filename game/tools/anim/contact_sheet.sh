#!/usr/bin/env bash
# Contact sheets for clips you changed (gauntlet/refs/animation_gap.md,
# Phase 1): side and front views at 0/30/60/100% through each clip, on the
# base mannequin, one PNG per clip plus an index sheet.
#
#   game/tools/anim/contact_sheet.sh OUT_DIR Clip_A Clip_B ...
#   game/tools/anim/contact_sheet.sh OUT_DIR --paired move_id ...   (two-man)
#
# The clip gate (tests/test_clip_authoring_gate.gd) points here. PoseLint and
# the pair check catch what they can measure; the rest is caught by looking.
set -euo pipefail
cd "$(dirname "$0")/../.."
out="$1"; shift
mkdir -p "$out"
if [[ "${1:-}" == "--paired" ]]; then
  shift
  for move in "$@"; do
    for orbit in 0 90; do
      timeout 900 xvfb-run -a godot4 --path . --rendering-driver opengl3 --resolution 960x720 \
        tools/probe/paired_shot.tscn -- --move "$move" --side --lit --orbit $orbit \
        --at 0.0,0.3,0.5,0.7,1.0 --out "$out/$move-o$orbit" >/dev/null 2>&1 || true
    done
  done
else
  clips=$(IFS=,; echo "$*")
  timeout 1800 xvfb-run -a godot4 --path . --rendering-driver opengl3 --resolution 600x600 \
    tools/probe/clip_shot.tscn -- --glb res://assets/animations/wrestling_clips.glb \
    --clips "$clips" --out "$out/raw" >/dev/null 2>&1 || true
fi
python3 - "$out" <<'PY'
import sys, glob, os
from PIL import Image, ImageDraw
out = sys.argv[1]
groups = {}
for f in sorted(glob.glob(os.path.join(out, "**", "*.png"), recursive=True)):
    if os.path.basename(f).startswith("sheet_"):
        continue
    key = os.path.basename(f).rsplit("_", 1)[0]
    groups.setdefault(key + ("" if "raw" in f else "@" + os.path.basename(os.path.dirname(f))), []).append(f)
for key, files in groups.items():
    files = files[:10]
    tiles = []
    for f in files:
        im = Image.open(f).resize((240, 240))
        ImageDraw.Draw(im).text((4, 4), os.path.basename(f), fill=(255, 255, 255))
        tiles.append(im)
    cols = min(5, len(tiles))
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 240, rows * 240))
    for k, im in enumerate(tiles):
        sheet.paste(im, ((k % cols) * 240, (k // cols) * 240))
    path = os.path.join(out, "sheet_%s.png" % key.replace("@", "_").replace("/", "_"))
    sheet.save(path)
    print(path)
PY
