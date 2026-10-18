# 11v11 release evidence — 2026-10-18

BR-011/013/014 (items 11/13/14 of 25) are implemented for the initial 4-4-2
prototype. BR-021/022/023/025 remain in progress for motion/art/native acceptance.
The owner approved this shared-body/full-team pass ahead of individual likeness.

## Actual screenshots

These are 1280×720 captures from the real Godot Web scene after the kickoff
input was acknowledged. They show the initial pass moment. Chromium uses
SwiftShader software WebGL/Compatibility; the debug capture disables directional
shadows and freezes a game frame. They are not generated artwork, Mac lighting
comparisons, or frame-rate evidence.

- [Normal broadcast](match_11v11_broadcast.png)
- [Low touchline](match_11v11_touchline.png)
- [Goal and net](match_11v11_goal.png)
- [Corner](match_11v11_corner.png)

The Web scoreboard overlap seen in the first capture was corrected by placing
labels directly under the HUD canvas. Source idle and running clips contained
near-horizontal arms; their existing four arm-bone quaternion tracks were baked
with relaxed idle and foot-cycle-driven arm swing. Existing lower-body/root
curves and gameplay timing remain intact. Blender tests measure more than 15 cm
shoulder-to-elbow drop in all four locomotion samples; native Godot world-space
samples also show the corrected skeleton. Full moving-mesh deformation and
Web/native parity still require visual review; this is not final motion acceptance.

## Automated evidence

- Full 180 simulated seconds at 60 Hz simulation dt: 11,035 steps, 935.2 m ball
  travel, home/away shots 5/1, goals 1/0, no sampled stationary-ball stall. This
  accelerated headless run is match-progression evidence, not performance data.
- Integration: exactly 22 players, two keeper controllers, one separate referee;
  official/spectators excluded from player groups; all-eleven switching; neutral
  editable rosters, reserve #69 and correct kickoff/goal restart.
- Terrain: three physics rays agree with the visual height function within 4 mm;
  shallow broad deviations stay under about 6 cm. Heights are inferred, not surveyed.
- Boundaries: whole-ball ownership, corner/goal-kick/touchline placement and
  restart checked. Touchlines use a provisional ground pass, not a throw-in.
- Shared human pass: toe/ball distance 0.075 m at the authored 0.4 s contact,
  one physical impulse, locomotion restored. Regression checks retain the old
  4v4 match/keeper/shot/receive behaviors.
- Shared resources: default head mesh identity, teammate kit edit propagation,
  opposing-kit isolation and independent AnimationPlayer/AnimationTree state.
- Direct Blender/source/export inspection: 65 bones, 17 clips, 16 mesh parts,
  normalized maximum-four weights; topology-fingerprinted head-delta round trip
  and incompatible topology rejection. Count: 67,902 triangles including both
  sleeve variants; actual visible count depends on role. No runtime hair/cloth
  solver, procedural IK chain or net rigid-body grid was added.
- Web release has HTML/JS/nonempty PCK and valid WASM magic. Mac ZIP passes CRC,
  football bundle identifier/resource and universal arm64/x86_64 executable checks.
  The app is ad-hoc signed and not notarized. No native Mac execution is claimed.

## Remaining gaps and recommended next work

The common face is a Shane-derived draft, not accepted individual likeness.
Collar/hem deformation, short sleeves, arm transitions and exact keeper graphics
need a final-mesh motion review. Houses/cars/trees remain visibly modular and the
site is an approximation; window/roof detail, leaf coverage, terrain color and
specific reference alignment need further art passes. These captures are below
the requested final AAA/reference standard.

Next: BR-022 (22/25), in progress — resolve common garment/deformation and likeness
review at fixed front/profile/action views before producing individual heads.
BR-023 (23/25) follows with a camera-matched residential/vegetation pass. M1 Pro
16 GB 1080p frame timing, memory and input QA remain the BR-025 (25/25) gate.
Full rules/cards/offside/substitutions and additional formations remain open.

## Release isolation

Football publishes its own versioned `beechlawn-<commit>` release and Pages
subdirectory `/beechlawn-rovers/`. Existing wrestling site files are retained
from the last successful wrestling build. Future wrestling Pages builds include
the latest football Web release; the two Pages workflows share a serialized
concurrency group. Wrestling's `mac-latest` release is not replaced. Football-only
pushes do not rebuild the wrestling applications.
