#!/usr/bin/env bash
# The whole show as a player sees it (master plan stage 8): the title with its
# theme, WATCH, the select, the VS card, both entrances in full, the match to
# its finish, the post-match and the menu -- cut into the stills a QA reviewer
# reads, section by section, and full-motion clips of the moments stills cannot
# judge, with their sound.
#
#   tools/capture/show_reel.sh <out_dir> [WIDTHxHEIGHT] [seed]
#
# Writes <out_dir>/qa/ (stills, a contact sheet per section, index.md with the
# timeline), <out_dir>/clips/*.mp4 and, with FULL=1, <out_dir>/show.mp4.
#
# It is tools/probe/title_video.tscn with --watch on Vulkan under xvfb
# (forward_plus, the pipeline the game ships), in passes:
#
#   1. simulate the whole show with its 3D switched off (~0.03 s a frame), which
#      writes the timeline and the sound log;
#   2. plan the frames QA needs from that timeline (show_sections.py plan);
#   3. run the same show again, drawing the 3D only for those frames, each after the
#      capture harness's 24 settle frames (title_video --frames);
#   4. rebuild the soundtrack from the sound log, cut stills, sheets and clips.
#
# Why not simply record every frame: on the software renderer a drawn arena
# frame costs ~3 s at any resolution (measured: 960x540 and 640x360 alike --
# shadows, skinning and the fog volume do not scale with pixels), so a
# 13-minute show is ~20 hours. FULL=1 does it anyway, resumably, for a machine
# with a GPU. The show is deterministic (fixed fps, a seeded launch, presses on
# fixed frames), and pass 3's timeline is checked against pass 1's.
set -uo pipefail
OUT="${1:?usage: show_reel.sh <out_dir> [WIDTHxHEIGHT] [seed]}"
RES="${2:-1280x720}"
SEED="${3:-7}"
FPS="${FPS:-30}"
# The cap on the match scene, entrances included. A match runs 7-12 minutes
# and the entrances ~4; the cap only matters if a match never finishes.
MATCH_SECONDS="${MATCH_SECONDS:-1500}"
MENU_HOLD="${MENU_HOLD:-4}"
ATTEMPTS="${ATTEMPTS:-8}"
GODOT_BIN="${GODOT_BIN:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

mkdir -p "$OUT/frames"
OUT="$(cd "$OUT" && pwd)"
FRAMES="$OUT/frames"

show() { # log, extra args...
	local log="$1"; shift
	xvfb-run -a "$GODOT_BIN" --path "$ROOT/game" --rendering-driver vulkan \
		--resolution "$RES" --fixed-fps "$FPS" tools/probe/title_video.tscn -- \
		--out "$FRAMES" --watch --seed "$SEED" --match-seconds "$MATCH_SECONDS" \
		--menu-hold "$MENU_HOLD" "$@" > "$log" 2>&1
	grep -q "^TITLE_VIDEO [0-9]* frames" "$log"
}

# Re-runs a pass until it finishes: each one picks up from the frames on disk.
until_done() { # name, extra args...
	local name="$1"; shift
	for attempt in $(seq 1 "$ATTEMPTS"); do
		echo "== $name, attempt $attempt"
		if show "$OUT/${name}_$attempt.log" "$@"; then
			return 0
		fi
		echo "   ended early (see ${name}_$attempt.log); resuming"
		ls "$FRAMES"/f_*.jpg >/dev/null 2>&1 && rm -f "$(ls "$FRAMES"/f_*.jpg | tail -1)"
	done
	echo "error: $name did not finish in $ATTEMPTS attempts" >&2
	exit 2
}

if [ "${FULL:-0}" = "1" ]; then
	until_done full --resume
	cp "$FRAMES/timeline.txt" "$FRAMES/timeline_sim.txt"
else
	echo "== pass 1: simulate"
	show "$OUT/sim.log" --audio-only || { echo "error: simulation failed (sim.log)" >&2; exit 2; }
	grep -E "^(PICKED|FINISH|TITLE_VIDEO [0-9])" "$OUT/sim.log"
	cp "$FRAMES/timeline.txt" "$FRAMES/timeline_sim.txt"
	cp "$FRAMES/sound_log.txt" "$FRAMES/sound_log_sim.txt"
	python3 "$ROOT/tools/capture/show_sections.py" plan "$OUT" "$FPS"
	until_done render --frames "$FRAMES/wanted.txt"
	# The drawn run must be the simulated one, frame for frame.
	if ! diff -q "$FRAMES/timeline_sim.txt" "$FRAMES/timeline.txt" >/dev/null; then
		echo "error: the render's timeline differs from the simulation's:" >&2
		diff "$FRAMES/timeline_sim.txt" "$FRAMES/timeline.txt" >&2
		exit 3
	fi
fi

END=$(awk '$2 == "end" {print $1}' "$FRAMES/timeline.txt")
python3 "$ROOT/tools/capture/mix_sound_log.py" "$FRAMES" "$FPS" "$END"
python3 "$ROOT/tools/capture/show_sections.py" cut "$OUT" "$FPS"
if [ "${FULL:-0}" = "1" ]; then
	ffmpeg -loglevel error -y -framerate "$FPS" -i "$FRAMES/f_%05d.jpg" -i "$FRAMES/sound.wav" \
		-c:v libx264 -crf 21 -preset medium -pix_fmt yuv420p -c:a aac -b:a 192k \
		-shortest -movflags +faststart "$OUT/show.mp4"
fi
echo "show ok: stills in $OUT/qa/, clips in $OUT/clips/"
