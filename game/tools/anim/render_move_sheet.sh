#!/usr/bin/env bash
# Render one per-move visual-QA sheet.
#
# Usage (inside the Debian proot, from the repo root):
#   tools/anim/render_move_sheet.sh <move_id> [wrestlers]
#
# <move_id> is the library id ("ff/one_winged_angel") or a normal MoveDef id
# ("power_samoan_drop"). [wrestlers] is "roman,cody" or empty for the mannequin.
#
# Output: gauntlet/refs/ff_review/moves/<basename>.png
# The sheet is the game's match camera above the side/close probe, seven beats.
set -euo pipefail

MOVE="${1:?usage: render_move_sheet.sh <move_id> [wrestlers] [sheet_name]}"
WRESTLERS="${2:-}"
SHEET_NAME="${3:-}"
GODOT="${GODOT:-/data/data/com.termux/files/home/godot462/Godot_v4.6.2-stable_linux.arm64}"
ROOT="${ROOT:-/data/data/com.termux/files/usr/tmp/opencode/aegis-phase-b}"
TMP="${TMP:-/data/data/com.termux/files/usr/tmp/opencode/move_sheets}"
AT="${AT:-0.0,0.2,0.35,0.5,0.65,0.8,1.0}"
RES="${RES:-480x270}"
## "side" renders the mechanics view only (fast enough on Android); "both"
## adds the match camera and is intended for the Mac/CI render host.
VIEW="${VIEW:-side}"
SHOT="${SHEET_NAME:-$(basename "$MOVE")}"
OUT="$ROOT/gauntlet/refs/ff_review/moves/$SHOT.png"

cd "$ROOT"
rm -rf "$TMP/$SHOT"
mkdir -p "$TMP/$SHOT/match" "$TMP/$SHOT/side"

COMMON=(--path game --rendering-driver opengl3 --resolution "$RES"
	tools/probe/paired_shot.tscn -- --move "$MOVE" --at "$AT")
if [[ -n "$WRESTLERS" ]]; then
	COMMON+=(--wrestlers "$WRESTLERS")
fi

MATCH_DIR="-"
if [[ "$VIEW" == "both" ]]; then
	echo "SHEET_RENDER $MOVE match"
	xvfb-run -a "$GODOT" "${COMMON[@]}" --match-cam --out "$TMP/$SHOT/match" \
		> "$TMP/$SHOT/match.log" 2>&1
	MATCH_DIR="$TMP/$SHOT/match"
fi
echo "SHEET_RENDER $MOVE side"
xvfb-run -a "$GODOT" "${COMMON[@]}" --side --lit --bare --out "$TMP/$SHOT/side" \
	> "$TMP/$SHOT/side.log" 2>&1

python3 game/tools/anim/compose_move_sheet.py "$SHOT" \
	"$MATCH_DIR" "$TMP/$SHOT/side" "$OUT"
