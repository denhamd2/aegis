#!/usr/bin/env bash
# Runs a frame-stable capture of one replay for gauntlet critics.
#
# Usage: tools/capture/run_capture.sh <replay.tres> <output_dir> [fps]
#
# If the replay does not exist yet it is recorded first, by running an
# AI-vs-AI match headless and saving the ReplayResource. Nothing in the repo
# saved a replay before, so there was never one to hand this script.
#
# The capture itself runs under xvfb-run with the OpenGL3 (llvmpipe) driver
# and *not* --headless: headless renders nothing, so the previous
# --headless --write-movie combination could only ever have produced empty
# frames. Software rendering is fine for timing/feel captures; GPU-backed
# visual-quality captures must be run on real hardware (see ARCHITECTURE.md).
set -euo pipefail

REPLAY_PATH="${1:?usage: run_capture.sh <replay.tres> <output_dir> [fps]}"
OUTPUT_DIR="${2:?usage: run_capture.sh <replay.tres> <output_dir> [fps]}"
FPS="${3:-60}"
RESOLUTION="${CAPTURE_RESOLUTION:-1280x720}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot4}"

mkdir -p "$OUTPUT_DIR"

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
	--rendering-driver opengl3 \
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
# GPU-backed capture; VISUAL_SLICE=1 makes the gate enforce that rather than
# leaving it to whoever reads the frames. See ARCHITECTURE.md.
GATE_ARGS=()
if [ "${VISUAL_SLICE:-0}" = "1" ]; then
	GATE_ARGS+=(--visual)
fi

python3 "$REPO_ROOT/tools/capture/evidence_gate.py" "${GATE_ARGS[@]}" "$MANIFEST"

if command -v ffmpeg >/dev/null 2>&1; then
	ffmpeg -y -pattern_type glob -i "$OUTPUT_DIR/*_tick*.png" \
		-vf "tile=5x1" "$OUTPUT_DIR/contact_sheet.png" 2>/dev/null || true
fi

echo "capture ok: $MANIFEST"
