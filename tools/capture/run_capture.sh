#!/usr/bin/env bash
# Runs a headless, frame-stable capture of one replay for gauntlet critics.
#
# Usage: tools/capture/run_capture.sh <replay.tres> <output_dir> [fps]
#
# Wraps Godot's Movie Maker mode (--write-movie, constant delta) under
# xvfb-run with the OpenGL3 (llvmpipe) driver so it runs in CI without a
# GPU. Software rendering is fine for timing/feel captures; GPU-backed
# visual-quality captures must be run on real hardware (see ARCHITECTURE.md).
set -euo pipefail

REPLAY_PATH="${1:?usage: run_capture.sh <replay.tres> <output_dir> [fps]}"
OUTPUT_DIR="${2:?usage: run_capture.sh <replay.tres> <output_dir> [fps]}"
FPS="${3:-60}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot4}"

mkdir -p "$OUTPUT_DIR"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "error: $GODOT_BIN not found on PATH. Set GODOT_BIN to your Godot 4.6 binary." >&2
	exit 1
fi

CAPTURE_CMD=(
	"$GODOT_BIN"
	--headless
	--path "$REPO_ROOT/game"
	--fixed-fps "$FPS"
	--write-movie "$OUTPUT_DIR/capture.avi"
	-- --capture-replay "$REPLAY_PATH" --capture-output "$OUTPUT_DIR"
)

if command -v xvfb-run >/dev/null 2>&1; then
	xvfb-run -a "${CAPTURE_CMD[@]}"
else
	"${CAPTURE_CMD[@]}"
fi

MANIFEST="$OUTPUT_DIR/capture_manifest.json"
if [ ! -f "$MANIFEST" ]; then
	echo "error: capture did not produce $MANIFEST — round is void, not lost." >&2
	exit 2
fi

python3 "$REPO_ROOT/tools/capture/evidence_gate.py" "$MANIFEST"

if command -v ffmpeg >/dev/null 2>&1; then
	ffmpeg -y -pattern_type glob -i "$OUTPUT_DIR/*_tick*.png" \
		-vf "tile=5x1" "$OUTPUT_DIR/contact_sheet.png" 2>/dev/null || true
fi

echo "capture ok: $MANIFEST"
