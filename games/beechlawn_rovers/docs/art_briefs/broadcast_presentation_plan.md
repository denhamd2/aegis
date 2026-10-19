# Broadcast presentation production brief — 2026-10-18

Validation completed 2026-10-19.

Scope: BR-021 (21/25) shared pose correction; BR-014 (14/25) gameplay camera
selection; BR-024 (24/25) pre-match TV presentation, using the existing
BR-022/023 roster, kits and Kilmore Drive assets. These remain original Godot
systems and original/free Blender assets. The football and wrestling projects
retain separate scenes, settings and pipelines.

## Research and design direction

PES 2021 has distinct camera families: Dynamic Wide, Stadium, Live Broadcast,
Fan View, Blimp, Vertical, Player and Field Side. The
[2020 camera comparison](https://www.youtube.com/watch?v=BIMDmgoF_9E) was found via contemporary video metadata; playback was unavailable; the
[2021 settings overview](https://www.gamersdecide.com/articles/pes-21-best-camera-settings)
describes the families and per-mode customization limits. Third-party Sider
camera mods add parameters beyond stock menus and are not evidence that every
setting was available in unmodified PES. Our implementation uses independent
presets with height, zoom and angle adjustments, rather than copying engine
parameters or claiming numerical equivalence. Close Broadcast remains default.

For pre-match comparison, use the publisher's
[PS4 Pro full-match capture](https://www.gamereactor.eu/video/533713/eFootball+PES+2021+-+Data+Pack+30+4K+PS4+Pro+Full+Match+Gameplay/).
Inspected frames show a two-file walk-on (25 s), crowd cutaway (32 s), and
formation overlay (48 s). Our requested player portraits and ground-detail
shots are an original extension. Anthem ceremonies are not established by
these frames and depend on competition and match type. Modern modded entrance packs are not a reliable
record of stock PES 2021. This Sunday-league club fixture uses a team lineup,
not a national-anthem ceremony. No third-party footage, music or PES assets
will be shipped.

## Shared animation brief

Use the existing 65-bone humanoid rig and 16 modular mesh parts, without adding
geometry or textures. Audit source and imported poses first. Correct the
overextended braking-arm silhouette, preserving every existing leg/root/contact
curve and action duration. Keep the source builder consistent with the fix.
Add reusable original in-place walk-on and warm-up jog clips sampled at 60 fps,
with opposite arm swing, foot stance/swing arcs and a stable character root.
Reuse the relaxed idle for the lineup and portraits. Godot owns presentation
paths while the ball and match simulation remain stopped.

Apply the installed Blender director, animation, rigging, Godot-export and
camera-cinematography guides through headless Blender/bpy and direct Godot
checks. Validate source arm drops, imported bone poses and rendered full meshes;
preserve kick/receive marker checks. Avoid a rig replacement or blanket rewrite
of football actions.

## Sequence and controls

Create an approximately 40-second, skippable sequence with editable shot data:
venue establishment, two-file walk-on, weathered goal frame, net detail,
touchline spectators, team lineup, named player/keeper portraits, chalk/grass,
ball close-up, warm-up run, then a clean gameplay-camera handoff.

Use purpose-specific lenses, slow dollies and readable lower thirds, with the
original oval crest and roster names/numbers. Staged shot-to-shot blocking is
presentation-only; it must restore canonical kickoff positions, ball state,
referee, physics, camera and HUD on normal finish or skip. No match-clock,
possession, score or AI advancement is allowed during the intro. It plays only
once on menu-launched matches, never after a goal restart. Space/Enter skips;
Options can disable it; C cycles gameplay cameras.

## Acceptance

1. The reproduced braking pose regression turns green on the real shared rig;
   idle, gait and football-action/contact checks remain valid.
2. All camera presets frame finite targets and preserve camera-relative input;
   preference save/load, keyboard cycling and default framing work.
3. Full and skipped intros restore exact kickoff state in Play and Watch,
   release their presentation overrides and leave no duplicate camera/HUD.
4. Source/GLB inspection and rendered start/middle/end samples show useful
   player, object and venue views; the Web build starts and accepts input.
5. M1 Pro/16 GB 1080p/60 fps, likeness, final venue fidelity and final temporal
   animation quality remain explicit native/art acceptance gates.

## Implemented and checked

- Player duplication reproduced two skeletons in a clone of the configured
  kickoff player. `_spawn_player` now instantiates `football_player.tscn`.
  `shared_pose_safety_smoke.gd` requires one skeleton in every player and an
  already-evaluated idle before the first animation tick, then samples ten
  standing/locomotion/presentation clips. No sustained T silhouette remains
  in those samples. This fixes an extra 21 visual rigs in the 11v11 lineup.
- Direct Blender changes: StopFromRun arm quaternion channels only, two new
  60 fps in-place clips, no new bones/rest-pose or mesh changes. Retained
  original-curve digest, loop endpoints and ankle-solver residuals are in
  `presentation_source_audit.json`. Both new loops have zero endpoint channel
  difference; maximum ankle-target residual is below 0.000001 m in the source
  solver. This is a source construction check, not a blanket foot-slip claim.
- Camera preset/settings round trip, invalid settings, all nine finite camera
  transforms, ball framing at kickoff and camera-relative movement pass.
- Automatic traversal of the complete intro and mid-walk skip pass in Play
  and Watch. Physics/clock/kickoff are isolated; player interpolation, referee,
  HUD, animation trees and selected gameplay camera are restored. Intro camera
  and overlay are freed, and goals do not restart the sequence.
- Ten focused initial suites plus receive, full-11v11 pass/shot contact and HUD
  layout checks pass. Pass toe-to-ball gap remains 0.075 m at 0.400 s; full-team
  AI-shot test measures 0.010 m at 0.300 s with one impulse and no early kick.
  The receive fixture remains 0.123 m at 0.333 s.
- Both 180-second whole-match physical-shot gates remain identical after the
  rig fix: Beechlawn kickoff shots 0/1, goals 0/0, 1,082.2 m ball travel,
  11,305 physics ticks; Boardeaux kickoff shots 1/2, goals 1/1, 1,158.7 m,
  11,605 ticks. These are regression checks, not balanced-AI acceptance.

Rendered review also exposed a separate backdrop bug: joined tree meshes kept
`LeafUV` beside the bark's `UVMap`, so exported leaf material UV0 sampled a
transparent texture corner. Both `.blend` tree UV0 surfaces and GLBs were
repaired without changing topology; the module builder now normalizes UV names
before joining. The imported leaf UV test requires a full 0–1 span in both
variants. Net texture alpha now retains mip coverage instead of erasing ropes
with a hard cutoff; chalk micro-grit is derivative-filtered to reduce distant
sparkle while retaining authored width/edge irregularity.

The final browser composition/camera check passes with zero console errors:
`broadcast_presentation_evidence/broadcast_web_check.json`. The recorded
headless, whole-match and source-authoring logs are in
`broadcast_presentation_evidence/validation.log`. Disabling the intro and
Options signal bindings, a clear warm-up lane, overhead angle control and matching handoff orientation
for all nine gameplay cameras are also covered.

See [actual rendered review gallery](broadcast_presentation_evidence/index.html).
The Blender images are start/middle/end samples of each new loop, rendered
from the source on CPU. Web captures use actual Compatibility/WebGL scenes,
with software-capture shadows disabled. Final likeness, visible collar/cuff
seams, torso/hand tailoring, authentic venue detail and moving-mesh/native M1
quality remain open. No claim of PES/AAA visual parity or a measured 60 fps.

Next: **BR-021 (21/25), in progress** — calibrate shared stride/plant timing and
inspect moving cloth/limb deformation using the now single-rig players. Follow
with BR-022/023 likeness, kit-seam and venue-fidelity refinement; those assets
will propagate automatically into the intro. Native M1 acceptance remains
pending; continue cloud-rendered checks while the Mac is unavailable.
