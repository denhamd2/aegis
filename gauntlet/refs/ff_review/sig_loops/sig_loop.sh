#!/bin/bash
# Signature/finisher parity loop: render each move in moves.txt and build a
# reference-over-ours sheet against the AEW Fight Forever finishers compilation.
#
#   GODOT=/path/to/godot VIDEO=/path/to/sig.mp4 OUT=/path/to/out \
#       gauntlet/refs/ff_review/sig_loops/sig_loop.sh <loop-number> [move-name ...]
#
# With no move names it renders every row of moves.txt. Each row is:
#   <name> <MoveDef path under res://resources/moves, no .tres> <ref start s> <ref impact s> <ref end s> [extra ...]
# Optional extras after the fifth column: contact=<fraction of the move> (our
# impact; default the MoveDef's startup_frames, which ends on impact), and any
# paired_shot flags (--run-in 3.5 --run-ticks 36, --corner, ...). Our columns
# are true 60 fps ticks (paired_shot --ticks): the contact column sits on our
# impact tick, and the columns before and after it spread evenly over our run
# and approach and over our recovery, as the reference's do over its window.
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
cd "$REPO/game"
while read -r name mv s i e extra; do
  [ -z "$name" ] && continue
  if [ $# -gt 0 ] && [[ ! " $* " =~ " $name " ]]; then continue; fi
  O=$OUT/l$L/$name; rm -rf "$O"; mkdir -p "$O"
  # The schedule: run ticks, our total and contact tick, the ten columns.
  read -r RUN CT TICKS < <(python3 - "$REPO/game/resources/moves/$mv.tres" "$s" "$i" "$e" $extra <<'PY'
import sys, re
tres, s, i, e = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
extra = sys.argv[5:]
txt = open(tres).read()
fr = {k: int(re.search(r'^%s = (\d+)' % k, txt, re.M).group(1))
      for k in ('startup_frames', 'active_frames', 'recovery_frames')}
total = sum(fr.values())
contact = fr['startup_frames']
run = 0
for k, tok in enumerate(extra):
    if tok.startswith('contact='):
        contact = int(round(float(tok[8:]) * total))
    if tok == '--run-ticks':
        run = int(extra[k + 1])
refs = [s + (e - s) * k / 9 for k in range(10)]
ci = min(range(10), key=lambda k: abs(refs[k] - i))
c = run + contact
end = run + total
ticks = []
for k in range(10):
    if k < ci:
        ticks.append(int(round(c * k / ci)))
    elif k == ci:
        ticks.append(c)
    else:
        ticks.append(int(round(c + (end - c) * (k - ci) / (9 - ci))))
print(run, c, ','.join(str(t) for t in ticks))
PY
)
  FLAGS=$(for t in $extra; do case $t in contact=*) ;; *) printf '%s ' "$t";; esac; done)
  flock "$LOCK" timeout 900 xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 \
      --resolution 960x540 tools/probe/paired_shot.tscn -- --move "$mv" --out "$O/raw" \
      --side --orbit 45 --lit --bare --dist 5 $FLAGS --ticks "$TICKS" > "$O/log.txt" 2>&1
  python3 - "$O" "$VIDEO" "$s" "$i" "$e" "$name" "$L" "$REPO" "$CT" <<'PY'
import sys, glob, os, re, subprocess
from PIL import Image
O, V, s, i, e, name, L, REPO, CT = sys.argv[1:]
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
                '--contact-ours', CT, '--title', '%s - loop %s' % (name, L),
                '--out', O + '/../sheet_%s.jpg' % name], check=False)
PY
done < "$HERE/moves.txt"
