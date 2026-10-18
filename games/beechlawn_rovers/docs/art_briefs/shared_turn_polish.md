# Shared pivot and moving-turn pass — 2026-10-18

BR-021 (21/25), still in progress. This focused release pass builds on the
[control](pes_motion_control_pass.md) and [AI/gait](pes_chance_gait_followup.md)
changes. It does not accept the full animation set or claim PES-quality motion.

## Reference gap and exact change

Reviewed the archived Shane #8 body sheet, the reference implementation plan
and the actual shared `.blend`, using the Blender director, animation, rigging
and Godot-export guides. The supplied character silhouette has relaxed arms.
The old mirrored pivots instead raised elbows about 4 cm above the shoulders.
The source's 0.6-second planted footwork was also being played during running
direction changes, moving that planted pose through the world.

- `FootballPlayer` now keeps its locomotion gait active while the existing
  controller eases body rotation through a running turn. Planted pivot clips
  remain available through `FootballerVisual.play_turn()` for stationary use
  and preview; they no longer override moving gameplay footwork.
- Blender `polish_turn_arms()` reuses the already-validated idle arm motion on
  `AN_Beechlawn_Turn90Left` and `AN_Beechlawn_Turn90Right`. Only four arm/forearm
  quaternion channels per clip change; hips, feet, spine and all other clips
  retain their original curves. Both pivot durations remain 0.6 seconds.
- The modular character builder calls the same function, so regeneration
  preserves the fix. The source `.blend` and shared human GLB were updated.

The repeatable audit/apply/export tool is
`tools/blender/beechlawn/polish_shared_turns.py`. It defaults to read-only;
`--apply --render` writes the asset and a lightweight blank-scene proxy comparison.
No runtime IK, extra bones, physics solvers or independent root-motion path were
added. The 65-bone rig, 16 mesh parts and 67,902 triangles including both sleeve
variants are unchanged; this triangle total is not a measured per-player budget.

## Evidence

[Before/after proxy render](shared_turn_proxy_before_after.png) and
[curve-preservation report](shared_turn_polish.json). The elbow's minimum sampled
drop below its shoulder changes from -0.039/-0.040 m to +0.267 m in both pivots.
A digest verifies every non-arm curve in those pivots and every curve in the
other actions is unchanged. Godot's imported-human pose check verifies both
mirrored clips retain their duration and relaxed arms. The mannequin render is
a pose check, not final-mesh animation acceptance.

The moving-turn regression was changed to require continued locomotion rather
than the incorrect planted override. It failed on the old runtime and passed
after the fix. Existing stop/resume, human/AI reversal, gait mapping, dribble
ownership, AI-shot lane, carry-to-shot, loose-ball recovery, shared-roster,
11v11 startup/restart and HUD checks pass. The release workflow now runs the
critical regressions and actual 11v11 authored pass/shot contact checks before
exporting Web and Mac packages.

Measured 11v11 contacts remain 0.075 m toe-to-ball at 0.4 s for the pass and
0.010 m at 0.3 s for the AI-selected shot, with one impulse and no early kick.
The final 180-second AI simulation reached full time with 1,001.7 m ball travel,
one Beechlawn shot, no goals and no sampled stationary-ball seconds. This verifies
progression and the specific regression gates, not balanced attacking quality.

Local release exports for Web and macOS pass the package verifier, including
WebAssembly/PCK presence and Mac universal arm64/x86_64 executable, football
bundle identifier, resources and ZIP integrity. The actual release Web export
started in Chromium and accepted kickoff, movement and reversal inputs without
browser page errors. [Release frame](shared_turn_release_web.png): 640×360 software
WebGL with the normal release configuration, not the debug shadow-disable mode.
It is functional/visual evidence at that resolution, not a smoothness or M1
frame-time measurement. Visible pose/garment issues remain for the next pass.

## Remaining acceptance and next work

BR-021 (21/25) remains open for offline stride/stance-phase calibration,
braking/turn transition blending, final-mesh garment/arm deformation and moving
broadcast review. This pass removes one cause of foot dragging; it does not
prove every foot is planted correctly throughout the match.

Keep BR-008 (8/25) attacking-flow tuning open: the preceding Bordeaux-kickoff
simulation recovered its loose-ball stall but created no shots. Continue with
controlled contested attacks as well as whole matches, retaining formation cover.
Native M1 Pro/16 GB 1080p/60 fps and appearance remain unmeasured; Web captures
and structural Mac package checks cannot replace that hardware playtest.
