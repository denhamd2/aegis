#!/usr/bin/env bash
# The frames a QA reviewer looks at, one set per section of the game, rendered
# on Vulkan under xvfb (a software rasteriser is fine: these are stills). Run
# from the repo root:
#
#   tools/capture/qa_frames.sh /tmp/qa [WIDTHxHEIGHT]
#
# Sections: title, arena (the match camera), compat (the web renderer), pin,
# the referee's count, Roman's and Cody's entrances (sparse), the prop handoff
# and the stage. Each is ~2-10 minutes on a software rasteriser. A continuous
# render of a whole match is NOT among them: under llvmpipe a rendered sim
# tick costs ~0.7 s, so ten minutes of match is hours -- the headless
# pace_probe is what measures a whole match, and tools/capture/run_capture.sh
# the thing to run on a machine with a GPU.
set -uo pipefail
OUT="${1:?usage: qa_frames.sh <out_dir> [WIDTHxHEIGHT]}"
RES="${2:-960x540}"
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
# FIXED_FPS: probes that step timed things (the handoff's clocks, the
# entrances) need a fixed frame time, or a slow frame makes a long tick.
run() { # name, driver, scene, args...
	local name="$1" driver="$2" scene="$3"; shift 3
	mkdir -p "$OUT/$name"
	echo "== $name"
	xvfb-run -a "$GODOT_BIN" --path game --rendering-driver "$driver" --resolution "$RES" \
		--fixed-fps "${FIXED_FPS:-60}" "$scene" -- "$@" > "$OUT/$name.log" 2>&1 || echo "   (exit $?)"
}
run title      vulkan  tools/probe/title_shots.tscn      --out "$OUT/title/title.png"
run arena      vulkan  tools/probe/arena_shot.tscn       --out "$OUT/arena"
run arena_ice  vulkan  tools/probe/arena_shot.tscn       --out "$OUT/arena_ice" --ice
run flashes    vulkan  tools/probe/arena_shot.tscn       --out "$OUT/flashes" --flashes
run compat     opengl3 tools/probe/arena_shot.tscn       --out "$OUT/compat" --flashes
run pin        vulkan  tools/probe/pin_shot.tscn         --out "$OUT/pin" --match-camera
run stage      vulkan  tools/probe/stage_wide_shot.tscn  --out "$OUT/stage/stage.png"
FIXED_FPS=30 run handoff    vulkan  tools/probe/handoff_shots.tscn    --out "$OUT/handoff" --view 0 --every 12 --from 90 --until 160
FIXED_FPS=30 run handoff2   vulkan  tools/probe/handoff_shots.tscn    --out "$OUT/handoff2" --view 1 --every 12 --from 214 --until 262
FIXED_FPS=30 run handoff3   vulkan  tools/probe/handoff_shots.tscn    --out "$OUT/handoff3" --view 2 --every 15 --from 800 --until 890
echo "frames in $OUT"
