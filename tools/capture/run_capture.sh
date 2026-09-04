#!/usr/bin/env bash
# Runs a frame-stable capture of one replay for gauntlet critics.
#
# Usage: tools/capture/run_capture.sh <replay.tres> <output_dir> [fps]
#
# If the replay does not exist yet it is recorded first, by running an
# AI-vs-AI match headless and saving the ReplayResource. Nothing in the repo
# saved a replay before, so there was never one to hand this script.
#
# The capture runs under xvfb-run and *not* --headless: headless renders
# nothing, so the previous --headless --write-movie combination could only
# ever have produced empty frames.
#
# It renders on the pipeline the game ships (forward_plus, via the Vulkan
# driver), because that is what ARCHITECTURE.md's renderer rule is about.
# This used to force --rendering-driver opengl3, which silently produced
# gl_compatibility pixels -- no SSAO, no SSR, no volumetric fog, different
# tonemapping -- and every visual number the project recorded was read off
# them. RENDERING_DRIVER=opengl3 still forces the old behaviour for a
# timing/feel capture on a machine with no Vulkan driver at all; the gate
# will correctly void the result for a visual slice.
set -euo pipefail

REPLAY_PATH="${1:?usage: run_capture.sh <replay.tres> <output_dir> [fps]}"
OUTPUT_DIR="${2:?usage: run_capture.sh <replay.tres> <output_dir> [fps]}"
FPS="${3:-60}"
RESOLUTION="${CAPTURE_RESOLUTION:-1280x720}"
RENDERING_DRIVER="${RENDERING_DRIVER:-vulkan}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot4}"

mkdir -p "$OUTPUT_DIR"
# Absolute, because Godot resolves a relative path against res:// and not
# against the shell's cwd: `run_capture.sh ... tools/capture/out` used to
# write the whole capture to game/tools/capture/out/ and then fail here
# claiming the round was void, with the frames sitting on disk the whole time.
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "error: $GODOT_BIN not found on PATH. Set GODOT_BIN to your Godot 4.6 binary." >&2
	exit 1
fi

if ! command -v xvfb-run >/dev/null 2>&1; then
	echo "error: xvfb-run not found. A capture must render, so it needs a display." >&2
	exit 1
fi

if [ ! -f "$REPLAY_PATH" ]; then
	echo "recording $REPLAY_PATH (no replay supplied)..."
	"$GODOT_BIN" --headless --path "$REPO_ROOT/game" --fixed-fps 600 \
		-- --record-replay "$REPLAY_PATH"
	if [ ! -f "$REPLAY_PATH" ]; then
		echo "error: recording produced no replay at $REPLAY_PATH" >&2
		exit 2
	fi
fi

xvfb-run -a --server-args="-screen 0 ${RESOLUTION}x24" \
	"$GODOT_BIN" \
	--path "$REPO_ROOT/game" \
	--rendering-driver "$RENDERING_DRIVER" \
	--resolution "$RESOLUTION" \
	--fixed-fps "$FPS" \
	--write-movie "$OUTPUT_DIR/capture.avi" \
	-- --capture-replay "$REPLAY_PATH" --capture-output "$OUTPUT_DIR"

MANIFEST="$OUTPUT_DIR/capture_manifest.json"
if [ ! -f "$MANIFEST" ]; then
	echo "error: capture did not produce $MANIFEST — round is void, not lost." >&2
	exit 2
fi

# A visual-quality slice (ring/arena, wrestler look, HUD legibility) needs a
# capture on the shipping pipeline; PERF_SLICE=1 additionally needs a GPU,
# since a CPU rasteriser gets frame cost precisely wrong. Either flag makes
# the gate enforce it rather than leaving it to whoever reads the frames.
GATE_ARGS=()
if [ "${VISUAL_SLICE:-0}" = "1" ]; then
	GATE_ARGS+=(--visual)
fi
if [ "${PERF_SLICE:-0}" = "1" ]; then
	GATE_ARGS+=(--performance)
fi

python3 "$REPO_ROOT/tools/capture/evidence_gate.py" "${GATE_ARGS[@]}" "$MANIFEST"

if command -v ffmpeg >/dev/null 2>&1; then
	ffmpeg -y -pattern_type glob -i "$OUTPUT_DIR/*_tick*.png" \
		-vf "tile=5x1" "$OUTPUT_DIR/contact_sheet.png" 2>/dev/null || true
fi

# The raw Movie Maker AVI is uncompressed: a 15-second match is ~107MB. It is
# an intermediate -- the beat PNGs and the contact sheet are what a critic
# reads -- and a fleet of builders each running a few rounds fills the disk
# allowance with it. Kept only on request.
if [ "${KEEP_MOVIE:-0}" != "1" ]; then
	rm -f "$OUTPUT_DIR/capture.avi"
elif command -v ffmpeg >/dev/null 2>&1; then
	ffmpeg -y -i "$OUTPUT_DIR/capture.avi" -c:v libx264 -crf 20 \
		"$OUTPUT_DIR/capture.mp4" 2>/dev/null \
		&& rm -f "$OUTPUT_DIR/capture.avi" || true
fi

echo "capture ok: $MANIFEST"
