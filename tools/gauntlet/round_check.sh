#!/usr/bin/env bash
# Everything a gauntlet round has to re-prove, in one command.
#
# Usage: tools/gauntlet/round_check.sh [output_dir] [--write-baseline]
#
# A visual round changes what the game looks like. The risk is never that it
# fails to change anything -- it is that it changes something else too: a
# cosmetic edit that reaches the deterministic simulation, a material tweak
# that pushes a wrestler's silhouette out of VISUAL_BAR.md's band, an arena
# element that lands in the HUD probe's corner and blinds the evidence gate.
# None of those announce themselves in a screenshot.
#
# So this runs the hard gates and the measured bars together and prints one
# table. Three of them are pass/fail and void the round outright:
#
#   suite      gdUnit4 must be green.
#   hash       the replay's end-state hash must be byte-identical to the
#              baseline. This is the direct evidence that a cosmetic change
#              stayed cosmetic -- it is computed from damage, momentum and
#              tick count, so anything that reached gameplay moves it.
#   gate       the capture must pass evidence_gate.py --visual, i.e. it must
#              have been rendered on the pipeline the game ships.
#
# The rest are measurements, reported against the stored baseline with their
# deltas. They are not pass/fail here on purpose: a builder mid-round often
# has a number moving in the right direction but not yet in band, and a
# script that calls that a failure teaches people to stop running it. The
# critic reads the deltas.
#
# --write-baseline stores the current numbers as the comparison point. Do
# that when a round has been accepted, never to make a red check go green.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/tools/capture/out}"
WRITE_BASELINE=0
for arg in "$@"; do
	[ "$arg" = "--write-baseline" ] && WRITE_BASELINE=1
done

GODOT_BIN="${GODOT_BIN:-godot4}"
BASELINE="$REPO_ROOT/gauntlet/status/visual_baseline.json"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$OUT_DIR"
FAILED=0
note() { printf '  %-28s %s\n' "$1" "$2"; }

echo "== round check =="

# ---------------------------------------------------------------- suite
# gdUnit4 is deliberately not vendored (.gitignore: "fetched by CI"), so it
# exists only in whichever checkout someone installed it into. A git worktree
# therefore has no runner, and this script's first version read that as a
# failing suite -- reporting "round is void" at every builder in the fleet for
# a reason that had nothing to do with their work. A gate that fails on
# correct input is not a gate.
#
# So: borrow the runner from any sibling worktree that has one, else clone the
# version CI pins. If neither is possible the round still fails, but it says
# what actually happened instead of blaming the build.
RUNNER="addons/gdUnit4/bin/GdUnitCmdTool.gd"
if [ ! -f "$REPO_ROOT/game/$RUNNER" ]; then
	for candidate in $(git -C "$REPO_ROOT" worktree list --porcelain 2>/dev/null \
			| awk '/^worktree /{print $2}'); do
		if [ -f "$candidate/game/$RUNNER" ]; then
			# Copied, never symlinked. A symlink makes Godot see the same
			# scripts at two resource paths, and every gdUnit4 class then
			# fails to parse with "hides a global script class" -- 216 green
			# tests become an abnormal exit with no summary line.
			# rm first: `cp -r src dest` where dest already exists nests
			# the copy at addons/gdUnit4/gdUnit4, and Godot then sees every
			# gdUnit4 class twice -- "hides a global script class", 216
			# tests replaced by an abnormal exit.
			mkdir -p "$REPO_ROOT/game/addons"
			rm -rf "$REPO_ROOT/game/addons/gdUnit4"
			cp -r "$candidate/game/addons/gdUnit4" \
				"$REPO_ROOT/game/addons/gdUnit4"
			echo "  (copied gdUnit4 from $candidate)"
			break
		fi
	done
fi
if [ ! -f "$REPO_ROOT/game/$RUNNER" ] && command -v git >/dev/null 2>&1; then
	mkdir -p "$REPO_ROOT/game/addons"
	if git clone --depth 1 --branch v6.2.1 \
			https://github.com/MikeSchulze/gdUnit4.git "$WORK/gdUnit4" \
			>/dev/null 2>&1; then
		rm -rf "$REPO_ROOT/game/addons/gdUnit4"
		cp -r "$WORK/gdUnit4/addons/gdUnit4" "$REPO_ROOT/game/addons/gdUnit4"
		echo "  (cloned gdUnit4 v6.2.1, the version CI pins)"
	fi
fi
# A runner that has just appeared is not yet usable: its own class_name
# globals live in .godot/global_script_class_cache.cfg, which was written
# before the addon existed, so GdUnitCmdTool.gd fails to parse with
# "Could not find type GdUnitTestCIRunner". One import registers them.
if [ -f "$REPO_ROOT/game/$RUNNER" ] \
		&& ! grep -qs "GdUnitTestCIRunner" \
			"$REPO_ROOT/game/.godot/global_script_class_cache.cfg"; then
	"$GODOT_BIN" --headless --path "$REPO_ROOT/game" --import >/dev/null 2>&1
fi
if [ ! -f "$REPO_ROOT/game/$RUNNER" ]; then
	note "suite" "UNAVAILABLE  no gdUnit4 runner and could not fetch one --"
	note "" "this is an environment failure, not a build failure"
	FAILED=1
fi

SUITE_LOG="$WORK/suite.log"
if [ -f "$REPO_ROOT/game/$RUNNER" ]; then
"$GODOT_BIN" --headless --path "$REPO_ROOT/game" \
	-s addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests -c \
	--ignoreHeadlessMode >"$SUITE_LOG" 2>&1
SUITE_LINE="$(grep -a "Overall Summary" "$SUITE_LOG" | tail -1 | sed 's/\x1b\[[0-9;]*m//g')"
if echo "$SUITE_LINE" | grep -qE "0 errors \| 0 failures"; then
	note "suite" "PASS  ${SUITE_LINE#*Summary: }"
else
	note "suite" "FAIL  ${SUITE_LINE:-no summary line; see $SUITE_LOG}"
	cp "$SUITE_LOG" "$OUT_DIR/suite.log"
	FAILED=1
fi
fi

# ------------------------------------------------------- capture + gate
# A fresh replay every run, so the hash below is recorded by the code under
# test rather than read back from a file it did not produce.
rm -f "$WORK/round.tres"
if VISUAL_SLICE=1 "$REPO_ROOT/tools/capture/run_capture.sh" \
		"$WORK/round.tres" "$OUT_DIR" 60 >"$WORK/capture.log" 2>&1; then
	note "gate" "PASS  $(grep -a 'EVIDENCE GATE' "$WORK/capture.log" | tail -1)"
else
	note "gate" "FAIL  round is void -- see $OUT_DIR/capture.log"
	cp "$WORK/capture.log" "$OUT_DIR/capture.log"
	FAILED=1
fi

MANIFEST="$OUT_DIR/capture_manifest.json"
HASH=""
[ -f "$MANIFEST" ] && HASH="$(python3 -c "
import json,sys
print(json.load(open('$MANIFEST')).get('replay_end_state_hash',''))" 2>/dev/null)"

# ------------------------------------------------------------ art shots
SHOT_DIR="$OUT_DIR/shots"
mkdir -p "$SHOT_DIR"
xvfb-run -a --server-args="-screen 0 1280x720x24" "$GODOT_BIN" \
	--path "$REPO_ROOT/game" --rendering-driver vulkan --resolution 1280x720 \
	scenes/match.tscn -- --art-shots "$SHOT_DIR" >"$WORK/shots.log" 2>&1
if [ -f "$SHOT_DIR/wide_broadcast.png" ]; then
	note "art shots" "PASS  $(ls "$SHOT_DIR"/*.png | wc -l) shots in $SHOT_DIR"
else
	note "art shots" "FAIL  no shots rendered -- see $WORK/shots.log"
	FAILED=1
fi

# ----------------------------------------------------------- silhouette
xvfb-run -a --server-args="-screen 0 1280x720x24" "$GODOT_BIN" \
	--path "$REPO_ROOT/game" --rendering-driver vulkan --resolution 1280x720 \
	scenes/match.tscn -- --silhouette-shot "$WORK/sil" >"$WORK/sil.log" 2>&1
python3 "$REPO_ROOT/tools/refs/measure_silhouette.py" "$WORK/sil" \
	>"$WORK/sil.txt" 2>&1 || true

# ------------------------------------------------- collect and compare
python3 - "$WORK" "$SHOT_DIR" "$BASELINE" "$HASH" "$WRITE_BASELINE" <<'PY'
import json, re, subprocess, sys
from pathlib import Path

work, shot_dir, baseline_path, hash_now, write_baseline = sys.argv[1:6]
repo = Path(__file__).resolve().parents[2] if False else Path.cwd()
tools = Path(baseline_path).parents[2] / "tools"

now = {"replay_end_state_hash": hash_now}

sil = Path(work, "sil.txt")
if sil.exists():
    for key, label in [("mat_luminance", "mat "), ("mat_a", "mat <-> wrestler_a"),
                       ("mat_b", "mat <-> wrestler_b"),
                       ("a_b", "wrestler <-> wrestler")]:
        for line in sil.read_text().splitlines():
            if line.strip().startswith(label):
                m = re.search(r"(\d+\.\d+)", line)
                if m:
                    now[key] = float(m.group(1))
                break

wide = Path(shot_dir, "wide_broadcast.png")
if wide.exists():
    out = subprocess.run([sys.executable, str(tools / "refs" / "compare_frame.py"),
                          str(wide), "--json"], capture_output=True, text=True)
    if out.returncode == 0:
        data = json.loads(out.stdout)
        now["histogram_distance"] = data["histogram_distance"]
        for row in data["metrics"]:
            now[row["metric"]] = row["ours"]
            now["ref_" + row["metric"]] = row["reference"]
    out = subprocess.run([sys.executable, str(tools / "refs" / "measure_frame.py"),
                          str(wide), "--void"], capture_output=True, text=True)
    m = re.search(r"void_fraction\s*[:=]?\s*(\d+\.\d+)", out.stdout)
    if m:
        now["void_fraction"] = float(m.group(1))

base = {}
bp = Path(baseline_path)
if bp.exists():
    base = json.loads(bp.read_text())

ORDER = ["mat_luminance", "mat_a", "mat_b", "a_b", "void_fraction",
         "mean_luminance", "p95", "tile_contrast", "mean_saturation",
         "edge_density_fine", "edge_density_coarse", "histogram_distance"]
TARGET = {
    "mat_luminance": "0.43-0.49", "mat_a": "0.24-0.31", "mat_b": "0.24-0.31",
    "a_b": "0.00-0.07", "void_fraction": "0.010-0.066",
}

print("\n  measurements (not pass/fail -- the critic reads the deltas)")
print(f"  {'':22}{'now':>9}{'baseline':>10}{'delta':>9}   target/ref")
for key in ORDER:
    if key not in now:
        continue
    b = base.get(key)
    delta = f"{now[key] - b:+9.3f}" if isinstance(b, (int, float)) else f"{'-':>9}"
    bs = f"{b:10.3f}" if isinstance(b, (int, float)) else f"{'-':>10}"
    ref = TARGET.get(key) or (f"ref {now['ref_' + key]:.3f}"
                              if "ref_" + key in now else "")
    print(f"  {key:22}{now[key]:9.3f}{bs}{delta}   {ref}")

hb = base.get("replay_end_state_hash")
if hb and hash_now:
    same = hb == hash_now
    print(f"\n  hash                         "
          f"{'PASS  byte-identical to baseline' if same else 'FAIL  CHANGED -- a cosmetic edit reached the simulation'}")
    print(f"    baseline {hb}\n    now      {hash_now}")
    if not same:
        Path(work, "HASH_CHANGED").write_text("1")
elif hash_now:
    print(f"\n  hash                         (no baseline stored) {hash_now}")

if write_baseline == "1":
    bp.write_text(json.dumps(now, indent=2, sort_keys=True) + "\n")
    print(f"\n  baseline written to {bp}")
PY

[ -f "$WORK/HASH_CHANGED" ] && FAILED=1

echo
if [ "$FAILED" -ne 0 ]; then
	echo "ROUND CHECK: FAIL -- the round is void, not lost. Fix and re-run."
	exit 1
fi
echo "ROUND CHECK: PASS"
