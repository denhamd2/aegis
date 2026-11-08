#!/usr/bin/env bash
# Backfill the per-move visual-QA sheets for every built move.
#
# Usage (inside the Debian proot, from the repo root):
#   tools/anim/render_all_move_sheets.sh [manifest] [outdir]
#
# Manifest columns: move_id, attacker, defender, move_def. The default is
# gauntlet/refs/ff_move_manifest.tsv. Existing sheets are skipped unless
# FORCE=1. One log per move is written next to the sheet.
set -euo pipefail

ROOT="${ROOT:-/data/data/com.termux/files/usr/tmp/opencode/aegis-phase-b}"
MANIFEST="${1:-$ROOT/gauntlet/refs/ff_move_manifest.tsv}"
OUTDIR="${2:-$ROOT/gauntlet/refs/ff_review/moves}"
LOG="${LOG:-/data/data/com.termux/files/usr/tmp/opencode/move_sheets}"
FORCE="${FORCE:-0}"

cd "$ROOT"
mkdir -p "$OUTDIR" "$LOG"

tail -n +2 "$MANIFEST" | while IFS=$'\t' read -r move attacker defender move_def; do
	[[ -z "$move" ]] && continue
	sheet="$OUTDIR/$move.png"
	if [[ -f "$sheet" && "$FORCE" != "1" ]]; then
		echo "SKIP $move (sheet exists)"
		continue
	fi
	echo "RENDER $move ($move_def, $attacker vs $defender)"
	if game/tools/anim/render_move_sheet.sh "$move_def" "$attacker,$defender" "$move" \
			> "$LOG/$move.render.log" 2>&1; then
		echo "OK $move"
	else
		echo "FAIL $move — see $LOG/$move.render.log"
	fi
done
