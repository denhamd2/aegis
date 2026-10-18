# Beechlawn render and capture notes

The Web export uses Godot's **Compatibility** renderer (`renderer/rendering_method.web="gl_compatibility"`). Chromium reports WebGL 2 / Compatibility when it starts the export. This path is useful for checking startup, gameplay input, rough composition and browser errors; it does not reproduce the Mac build's Forward+ renderer or Metal lighting.

## Browser capture

The earlier capture attempt used Chromium's `--screenshot` command against a running Godot WebGL game. Godot renders continuously through `requestAnimationFrame`; the browser command kept waiting for virtual-time/idle completion and did not exit, even though the page had loaded and WebGL had initialized. The export itself was healthy.

Use `tools/capture/capture_beechlawn_web.py <output.png>` instead. It starts a local HTTP server, launches Chromium through Playwright, waits for the Godot canvas, captures an explicit frame, navigates away to stop Godot's perpetual WebGL frame loop, and reports page/console errors. A 1280×720 capture with no page errors is at [`art_briefs/rigged_4v4_web_compat_capture.png`](art_briefs/rigged_4v4_web_compat_capture.png). It shows the Y-Bot proxy in active play; the broadcast camera is now 7 m lower, though the view remains too distant for fine gait judgement.

The 4v4 project enables physics interpolation at 60 Hz. Kickoff and goal restarts teleport players and the ball, so the match now calls `reset_physics_interpolation()` after those placements to avoid interpolation streaks across the pitch.

## Native visual capture

The wrestling project uses the better visual-review path for native scenes: `tools/capture/qa_frames.sh` launches Godot with `xvfb-run` and Vulkan, while `tools/capture/run_capture.sh` uses Godot Movie Maker (`--write-movie --fixed-fps`) and its `CaptureHarness`. The project notes explain that captures must use the game's Forward+ pipeline; Compatibility captures cannot assess Forward+ lighting/material results. This workspace currently has no `xvfb-run`/Xvfb executable, and its Vulkan adapter reports CPU `llvmpipe`, so it cannot yet reproduce the wrestling project's native capture setup or make performance claims. The M1 Pro Metal result still requires the target Mac.

## 11v11 captures (2026-10-18)

Use the isolated full-scene export and capture tool with `--start-match`,
`--ready-expression 'window.BEECHLAWN_MATCH_READY === true'` and
`--query 'software=1'`. The real kickoff key is held until the game acknowledges
it, rather than losing a short key tap within a very slow software-rendered frame.
The debug-only capture callback freezes a rendered game state before reading
pixels. Readiness/explicit capture fixes the hang; it is not a gameplay speed fix.

For additional debug camera angles append `&view=touchline`, `&view=goal` or
`&view=corner`. Default remains the normal tracking broadcast camera. Software
capture disables sun shadows and caps rendering; release builds ignore these
review settings. Screenshots therefore cannot judge native shadows or M1 fps.
A Web capture also exposed nested scoreboard labels rendering at overlapping
origins; the labels now use direct HUD coordinates and retain the same native
layout. No CSS or synthetic overlay replaces the game's scoreboard.
