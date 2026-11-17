#!/usr/bin/env bash
# Contact sheets of the walks the game plays, on the real roster models:
# one gait cycle at eight even steps, from the side (arm and leg swing,
# stride, torso) and from the front (sway, shoulders, head), per man. Each
# view is cropped to the union of the body's extent over its eight frames, so
# the man fills the cell and the frames stay registered against each other.
#
#   game/tools/anim/walk_sheets.sh OUT_DIR [man ...]     (default: all three)
#
# Entrance walk and gameplay walk for each of Roman, Cody and Kenny, plus the
# generic Entrance_Walk, Run_Jog and Run_Drive on Roman. Run it under the
# project's heavy-job lock; it takes about a minute a sheet. Needs xvfb-run
# and Pillow. GODOT names the binary (default godot4).
set -euo pipefail
cd "$(dirname "$0")/../.."
out="$1"; shift
mkdir -p "$out"
# The single frames go to a scratch directory; only the sheets are kept.
raw="${RAW_DIR:-$(mktemp -d)}"
men=("$@"); [[ ${#men[@]} -eq 0 ]] && men=(roman cody kenny)
declare -A MODEL=( [roman]=roman_model [cody]=cody_model [kenny]=kenny_model )
declare -A ENTRANCE=( [roman]=Walk_Slow_Look [cody]=Walk_Crowd [kenny]=Kenny_Walk )
declare -A CYCLES=( [Walk_Slow_Look]=3 [Walk_Crowd]=4 [Kenny_Walk]=4 [Entrance_Walk]=1 [Walk_Stalk]=1 [Run_Jog]=1 [Run_Drive]=1 )
godot="${GODOT:-godot4}"
shoot() { # man clip
  local man=$1 clip=$2 cyc=${CYCLES[$2]}
  local at
  at=$(python3 -c "print(','.join('%.4f' % (k/8.0/$cyc) for k in range(8)))")
  for view in side front; do
    timeout 900 xvfb-run -a "$godot" --path . --rendering-driver opengl3 --resolution 480x640 \
      tools/probe/clip_shot.tscn -- --glb res://assets/animations/wrestling_clips.glb \
      --model "res://scenes/${MODEL[$man]}.tscn" --clips "$clip" --view "$view" --at "$at" \
      --out "$raw/${man}_${clip}" >/dev/null 2>&1 || true
  done
}
for man in "${men[@]}"; do
  shoot "$man" "${ENTRANCE[$man]}"
  shoot "$man" Walk_Stalk
done
if [[ " ${men[*]} " == *" roman "* ]]; then
  shoot roman Entrance_Walk; shoot roman Run_Jog; shoot roman Run_Drive
fi
python3 - "$out" "$raw" <<'PY'
import sys, glob, os
from PIL import Image, ImageDraw, ImageChops
out, raw = sys.argv[1], sys.argv[2]
for d in sorted(glob.glob(os.path.join(raw, "*"))):
    name = os.path.basename(d)
    rows = []
    for view in ("side", "front"):
        files = sorted(glob.glob(os.path.join(d, "*_%s_*.png" % view)))
        if files:
            rows.append((view, [Image.open(f).convert("RGB") for f in files[:8]]))
    if not rows:
        continue
    H = 420
    strips = []
    for view, ims in rows:
        bg = Image.new("RGB", ims[0].size, ims[0].getpixel((2, 2)))
        box = None
        for im in ims:
            diff = ImageChops.difference(im, bg).convert("L").point(lambda v: 255 if v > 24 else 0)
            b = diff.getbbox()
            if b:
                box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
        pad = 12
        box = (max(box[0] - pad, 0), max(box[1] - pad, 0), min(box[2] + pad, ims[0].width), min(box[3] + pad, ims[0].height))
        cw = int((box[2] - box[0]) * H / (box[3] - box[1]))
        cells = []
        for c, im in enumerate(ims):
            cell = im.crop(box).resize((cw, H))
            ImageDraw.Draw(cell).text((4, 4), "%s %d/8" % (view, c), fill=(255, 255, 255))
            cells.append(cell)
        strips.append(cells)
    W = max(sum(c.width for c in s) for s in strips)
    sheet = Image.new("RGB", (W, H * len(strips) + 22), (20, 20, 24))
    ImageDraw.Draw(sheet).text((6, 4), name.replace("_", " ", 1) + "  (one gait cycle, 8 even steps; side row: arm/leg swing and stride, front row: sway, shoulders, head)", fill=(230, 230, 230))
    for r, cells in enumerate(strips):
        x = 0
        for cell in cells:
            sheet.paste(cell, (x, 22 + r * H))
            x += cell.width
    path = os.path.join(out, name + ".jpg")
    sheet.save(path, quality=82, optimize=True)
    print(path)
PY
