# Beechlawn native capture notes

Current delivery: universal Mac build. The owner retired the Web game on
2026-10-22. Native M1 appearance and performance still require hardware checks.

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
appearance/performance remains an acceptance gate. Football delivery is Mac-only. Use headless tests for logic and native captures
for appearance; the Web game and deployment have been retired.

## Match repair sequences

`--review-mode movement|throw|net|montage` records numbered native PNG frames
plus metadata in `match_broadcast.json`. Movement/throw/net use six real 60 Hz
simulation steps per draw; assemble at 10 fps to review simulated timing, not
cloud rendering throughput. The montage samples the start/middle/end of each
of its six three-second shots; its primary still is a midpoint because the
first instant intentionally fades from black. These sequences use existing
match assets/controllers. They do not replace real-time human playtesting.

```
python3 games/beechlawn_rovers/tools/capture_native.py \
  games/beechlawn_rovers/build/native-movement --review-mode movement \
  --resolution 640x360 --deadline 220
ffmpeg -framerate 10 -i games/beechlawn_rovers/build/native-movement/frame_%03d.png \
  -c:v libx264 -pix_fmt yuv420p games/beechlawn_rovers/build/native-movement/review.mp4
```

## Goalkeeper handling/recovery review

`--review-mode keeper_home|keeper_away` isolates the actual John/Boardeaux
keeper in the 11v11 scene. A rolling shot starts five metres in front; physical
ball travel, reaction, movement, save and recovery run through production code.
The goal-side camera stays close enough to see keeper, ball and net, with the
pitch filling the frame. Other actors are parked for this fixture; these clips
are not evidence of natural full-match chance creation. The manifest records
ball action/velocity, keeper position/recovery and actual save/catch events.
The current standing-save animation remains; low/dive motion is an open gate.

```sh
python3 games/beechlawn_rovers/tools/capture_native.py build/keeper-home \
  --review-mode keeper_home --resolution 640x360 --deadline 220
```

## Aerial contact and broadcast review

`--review-mode header_close|chest_close|cross_home|cross_away` records physical
contact sequences at six 60 Hz simulation steps per draw (assemble at 10 fps).
Close modes select actual roster Shane and script an incoming ball, explicitly
labelled in JSON; they isolate the authored animation and independent contact.
Cross modes use a winger's production foot marker, receiving AI, a central
marker, wide presser and live keeper, viewed through Close Broadcast. Unrelated
actors are parked. These are controlled integration fixtures, not full-match
chance evidence. JSON records head/chest/foot contact points and distances,
actor identity, ball velocity and renderer. A missing aerial contact fails.

## Advanced strikes

The review runner also accepts `volley_close`, `half_volley_close`,
`cross_driven_home`, `cross_driven_away`, `cross_lofted_home`, `cross_early_home`
and `shot_finesse|shot_power|shot_low`. Close boot-strike fixtures use actual
Shane with a scripted incoming ball; half-volley setup waits for integration
before forecasting. Physical bounce and real authored boot contact are required.
Cross modes use a production foot delivery and receiving AI. Ground-shot modes
use Shane's normal shot marker with a live goalkeeper. Other players are parked;
these are controlled integration views, separate from natural full-match tests.
JSON records variant, strike part and half-volley bounce age as well as renderer,
ball velocity and actor identity. Close volley/half-volley sequences capture
one 60 Hz step per draw (72 frames, assembled at 60 fps). Wide cross and ground
shot sequences capture six 60 Hz steps per draw (30 frames, assembled at 10 fps).
Use each report's `sequence_fps`; software throughput is not a Mac FPS result.
