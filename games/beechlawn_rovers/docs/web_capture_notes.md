# Archived Beechlawn Web capture notes

**Archived:** the owner retired the football Web version on 2026-10-22.
Do not resume Web exports/deployments. Current capture instructions are in
[native_capture_notes.md](native_capture_notes.md). The records below explain
historical evidence and do not define current delivery requirements.

The Web export uses Godot's **Compatibility** renderer (`renderer/rendering_method.web="gl_compatibility"`). Chromium reports WebGL 2 / Compatibility when it starts the export. This path is useful for checking startup, gameplay input, rough composition and browser errors; it does not reproduce the Mac build's Forward+ renderer or Metal lighting.

## Browser capture

The earlier capture attempt used Chromium's `--screenshot` command against a running Godot WebGL game. Godot renders continuously through `requestAnimationFrame`; the browser command kept waiting for virtual-time/idle completion and did not exit, even though the page had loaded and WebGL had initialized. The export itself was healthy.

Use `tools/capture/capture_beechlawn_web.py <output.png>` instead. It starts a local HTTP server, launches Chromium through Playwright, waits for the Godot canvas, captures an explicit frame, navigates away to stop Godot's perpetual WebGL frame loop, and reports page/console errors. A 1280×720 capture with no page errors is at [`art_briefs/rigged_4v4_web_compat_capture.png`](art_briefs/rigged_4v4_web_compat_capture.png). It shows the Y-Bot proxy in active play; the broadcast camera is now 7 m lower, though the view remains too distant for fine gait judgement.

The 4v4 project enables physics interpolation at 60 Hz. Kickoff and goal restarts teleport players and the ball, so the match now calls `reset_physics_interpolation()` after those placements to avoid interpolation streaks across the pitch.

## Native visual capture — primary appearance gate

The wrestling game's `tools/capture/run_capture.sh` uses native Godot
Forward+/Vulkan under Xvfb, Movie Maker and a frame/manifest evidence gate.
Its `tools/capture/native_reference.sh` runs the actual Mac application for
hardware captures. Its headless checks cover logic; they do not render artwork.
Those project-specific probes remain unchanged.

Football now has its own native Forward+ still runner:

```
python3 games/beechlawn_rovers/tools/capture_native.py \
  games/beechlawn_rovers/build/native-heads --players shane john des referee \
  --resolution 960x540
python3 games/beechlawn_rovers/tools/capture_native.py \
  games/beechlawn_rovers/build/native-match --match --resolution 960x540
```

The portrait fixture selects the actual roster head/eyes/groom/body on the
Kilmore pitch. It uses the unchanged match sky and sun by default; `--sky review`
and `--lighting soft` are explicit diagnostic alternatives. `--match` captures
the actual 11v11 scene, its sunny weather, 22 players plus referee and default
opposite-side Close Broadcast camera, held at kickoff. It does not use the
isolated portrait fixture's older illustrative broadcast angle.

Linux requires Xvfb and Vulkan. The runner finds `Xvfb` on PATH or the machine's
existing standalone installation under `/workspace/aegis-render-tools/`; this
is tool reuse without changing wrestling files. It uses the locally installed
Mesa Vulkan runtime where present. It never silently falls back to OpenGL or
the headless dummy renderer. macOS skips Xvfb and uses the native default
Godot graphics driver; set `--godot` to the intended Godot/app executable.

Every still records actual renderer, adapter/API, display server, resolution,
MSAA, shadows, player/scene and image hash. Blank images and script/compiler
errors fail the capture. The cold software Vulkan setup can be slow. Each
process has a hard deadline, live diagnostic log and process-group cleanup.
The observed llvmpipe teardown can remain alive after a successful readback;
a fresh saved PNG/JSON plus completion marker allow ten seconds to exit,
then bounded termination is recorded as `terminated_after_saved_capture`.
An absent or invalid image never passes through that cleanup path.

[Native proof images and manifests](art_briefs/native_forward_plus/brief.md)
show this setup working. These use the same rendering method as the Mac
build, so they are the primary cloud appearance evidence. Linux software
Vulkan, 960x540 stills and fixed-time playback do not establish exact Mac
GPU output, Retina/1080p detail, animation feel or 60 fps. Native hardware
appearance/performance remains an acceptance gate. Keep browser checks for
Web startup, controls, UI and Compatibility-specific regressions.

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
