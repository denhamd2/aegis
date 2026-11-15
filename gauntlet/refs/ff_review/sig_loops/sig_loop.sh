#!/bin/bash
# Signature/finisher parity loop: render each move in moves.txt and build a
# reference-over-ours sheet against the AEW Fight Forever finishers compilation.
#
#   GODOT=/path/to/godot VIDEO=/path/to/sig.mp4 OUT=/path/to/out \
#       gauntlet/refs/ff_review/sig_loops/sig_loop.sh <loop-number> [move-name ...]
#
# With no move names it renders every row of moves.txt. Each row is:
#   <name> <MoveDef path under res://resources/moves, no .tres> <ref start s> <ref impact s> <ref end s>
# Output: $OUT/l<loop>/sheet_<name>.jpg, plus raw frames in $OUT/l<loop>/<name>/f/.
# Needs xvfb-run, python3 with Pillow, and ffmpeg (parity_sheet.py cuts the reference).
set -u
L=${1:?loop number}; shift
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GODOT=${GODOT:-godot}
VIDEO=${VIDEO:?set VIDEO to the downloaded compilation (see README)}
OUT=${OUT:-/tmp/sig_loops}
LOCK=${LOCK:-/tmp/heavy.lock}
AT=0,0.111,0.222,0.333,0.444,0.556,0.667,0.778,0.889,1.0
cd "$REPO/game"
while read -r name mv s i e; do
  [ -z "$name" ] && continue
  if [ $# -gt 0 ] && [[ ! " $* " =~ " $name " ]]; then continue; fi
  O=$OUT/l$L/$name; rm -rf "$O"; mkdir -p "$O"
  flock "$LOCK" timeout 900 xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 \
      --resolution 960x540 tools/probe/paired_shot.tscn -- --move "$mv" --out "$O/raw" \
      --side --orbit 45 --lit --bare --dist 5 --at $AT > "$O/log.txt" 2>&1
  python3 - "$O" "$VIDEO" "$s" "$i" "$e" "$name" "$L" "$REPO" <<'PY'
import sys, glob, os, re, subprocess
from PIL import Image
O, V, s, i, e, name, L, REPO = sys.argv[1:]
s, i, e = float(s), float(i), float(e)
fs = sorted(glob.glob(O + '/raw/*.png'), key=lambda p: int(re.search(r'_(\d+)\.png$', p).group(1)))
os.makedirs(O + '/f', exist_ok=True)
nums = []
for p in fs:
    n = int(re.search(r'_(\d+)\.png$', p).group(1)); nums.append(n)
    Image.open(p).save(O + '/f/f%03d.png' % n)
refs = [s + (e - s) * k / 9 for k in range(10)]
ci = min(range(10), key=lambda k: abs(refs[k] - i))
refs[ci] = i
subprocess.run(['python3', REPO + '/game/tools/anim/parity_sheet.py', '--video', V,
                '--ref', ','.join('%.3f' % r for r in refs), '--contact-ref', '%.3f' % i,
                '--ours', O + '/f', '--ours-frames', ','.join('%03d' % n for n in nums),
                '--contact-ours', '%d' % nums[ci], '--title', '%s - loop %s' % (name, L),
                '--out', O + '/../sheet_%s.jpg' % name], check=False)
PY
done < "$HERE/moves.txt"
