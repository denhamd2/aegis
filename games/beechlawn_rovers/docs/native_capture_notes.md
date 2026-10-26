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
Use `keeper_high_shots` and `keeper_full_dives` for the later high and
full-stretch save/recovery coverage; this basic fixture checks near-body handling.

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

## Directed presentation and reference-led heads

The current follow-up is documented in
[its evidence brief](art_briefs/broadcast_turf_refresh_2026_10_23/brief.md).
`--review-mode outro` now records wide/medium/close celebration views, two
replay angles and full-time reactions/handshakes/results. Its JSON identifies
shot stations, FOV, playback time and any occlusion fallback. This remains a
scripted integration fixture. `--review-mode presentation` adds a dry near-turf
view beside the real venue/team/referee graphics and goalmouth shots.

Use `--verbose` only to diagnose engine teardown or rendering issues; normal
captures remain strict about script, shader and engine errors. Review scenes
can instantiate an unstarted match for light/line references; its restart Node
must be created and parented in _ready so these temporary sources can be freed.


Arena placement checks also audit the native MultiMesh buffers after rendering:
look for `seating_audit` in match capture JSON. The headless dummy RenderingServer
returns identity from `get_instance_transform`, so it cannot prove GPU chair
placement. The seating smoke check exercises the production placement function;
native Forward+ readback separately checks actual near/far transforms, upright
chairs, inward facing, aligned columns and clear aisles. Do not treat dummy
MultiMesh readback as visual evidence.

## Stadium/grass review — v0.4.0

`capture_native.py --match --venue rovers_arena --venue-view all` now includes both goal ends and low grass. `--venue-view corners` captures all four joins; `--venue-view exterior` captures four building elevations; `--venue-view pitch` captures turf, paint and a goalmouth. `--weather sunny|cloudy|rain|mist` selects the actual match weather. The normal close broadcast camera remains the primary image. All secondary shots are grounded camera positions with the actual match actors/settings. Turf triangle counts are recorded and bounded at 240k.

Native chair readback now uses the descriptive section/row manifest and actual block world transforms. Blocks have local origins at their centres so HLOD distance selection is meaningful. Overlapping Forward+ self-fades avoid empty seat patches at initial threshold distances; near/far seats share the imported blue material. See Godot's GeometryInstance3D visibility-range documentation: https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html .

Turf has a bounded dense near footprint and intermediate hash-faded fins. Fade only exposed intermediate residency boundaries and preserve an upward average normal: scissor-only fades plus dark downward normals exposed rectangular chunk edges. Check low moving/cut views as well as geometry budgets. The smoke runner now fails shader compilation errors immediately instead of accepting a nominal SceneTree exit.

## Turf glare and mowing diagnostic

`--match --venue rovers_arena --venue-view turf --weather sunny` isolates the
actual production pitch, weather, sky and sun before rendering. Other geometry
and its processes are hidden/disabled, including roof/actor shadows and turf
detail meshes. It samples 48 world-space stripe centres from four opposite
camera stations, with paired surface and SPECULAR=0 renders. The latter changes
only specular response; no global exposure or lighting substitution is used.
Run `python3 tools/check_turf_capture.py <capture-folder>` for mowing-contrast
and broad-reflection limits. Use full `--venue-view broadcast` captures for
complete-scene appearance; the material fixture cannot establish target-Mac
graphics parity, animation or performance. See
[the Mac glare repair](art_briefs/turf_glare_2026_10_26/brief.md).

## Ball appearance review

`--ball ucl_26_27_league|worn_sunday_league` explicitly chooses the production appearance. `--match --venue-view ball` saves the unchanged broadcast view plus four rotations and an emboss macro on the actual pitch. The JSON records the ball ID and each rotation. `--setup-preview` also captures Options. Combine with either venue and sunny/cloudy/rain; these are native Forward+ stills, not Mac frame-rate measurements.

## Contextual first-touch motion

`--review-mode receive` captures five original live receptions with current Shane: standing right/left, Ctrl close, running carry and Sprint push. `receive_broadcast` uses a broadcast-distance view of those same cases. Input basis is fixed to world X for repeatable before/after trajectories; actor movement, ball physics, contacts and clips remain production code. The JSON records the actual identity, 60 Hz ticks, 20 fps sampling, touching events and each pose/action. Other actors are parked and HUD hidden.

`--project /absolute/path/to/isolated/football/snapshot --receive-baseline` runs the same review driver against a prior snapshot and records its actual first-touch count without requiring the new behaviour. Keep the review driver identical between snapshots. Use the default project for final evidence. These software Forward+ sequences do not establish M1 frame timing.

## Bilateral strikes and explicit graphics profiles

The runner defaults to `--graphics balanced_60`, independent of saved Options.
Use `BEECHLAWN_STRIKE_FOOT=left` with `shot_power`, `volley_close` or a cross
review to exercise a real selected-left-boot contact. Reports record the foot,
actor, variant and gap; a missing left contact fails. The left motion review uses
a broadcast-distance telephoto lens for full-body framing; this legitimately
selects the normal head/cloth LOD. It is motion evidence rather than close-skin
appearance approval.

The initial viewport is drawn before the accelerated review physics cadence is
changed. In the 2026-10-25 software Vulkan review, the first close-view image
arrived near the four-minute deadline, while the telephoto image arrived in
about 51 seconds. Trace first draw, physics ticks and first saved PNG separately
so expensive close-view material startup is not mistaken for a stalled contact.
Keep a hard process bound and retain the failed-run scope. Native Mac startup,
close-material appearance, memory and frame time still need its actual hardware.

```sh
BEECHLAWN_STRIKE_FOOT=left python3 games/beechlawn_rovers/tools/capture_native.py \
  games/beechlawn_rovers/build/left-volley --match --review-mode volley_close \
  --graphics balanced_60 --resolution 960x540 --deadline 180
```
