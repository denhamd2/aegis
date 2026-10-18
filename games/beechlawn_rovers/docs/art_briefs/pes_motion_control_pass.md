# Movement and dribble-control pass — 2026-10-18

Scope: the first focused portion of BR-021 (21/25) and BR-002 (2/25), both
still in progress. Changes are local, not a published release or PES parity claim.

Follow-up: [AI chance, loose-ball and gait corrections](pes_chance_gait_followup.md)
address the reproduced decision and recovery defects found after this initial
pass. The zero-shot results below remain the historical diagnostic baseline.

## Inspection and diagnosis

Used the repo's diagnosing-bugs, blender-director, blender-animation, rigging
and godot-export guides. Opened `tools/blender/beechlawn/footballer_shared.blend`
directly in Blender 4.3.2 through headless bpy, inspecting the 65-bone armature,
constraints, action curves and sampled hip/foot paths. Source runs at 60 fps;
no runtime rig constraints were found. The sampled idle, jog, sprint, stop and
turn data are preserved in [the audit](pes_motion_blender_audit.json).

No Blender curves, meshes or exports changed in this pass. Jog is 0.8 seconds,
sprint approximately 0.533 seconds and turns 0.6 seconds. The in-place turn's
nearly planted local foot poses are a poor match for a translating controller.
Stride distance/phase and final-mesh deformation remain separate work; changing
the authoritative root trajectory or adding runtime IK was not justified here.

Three runtime defects were reproduced before editing:

| Case | Before | After |
| --- | --- | --- |
| 180-degree reversal at 6 m/s | Touch heading jumped 154.93 degrees away from body facing | Heading gap 0 degrees; forward velocity brakes to 5.75 m/s on the first 60 Hz tick |
| Nearby teammates requesting a touch | Two touch claims and competing assistance | One claim; the nearer eligible player wins in both caller orders |
| Pass requested during turn recovery | Rejected | Accepted; pass takes priority |

The reversal check covers human and AI input. The original small reproductions
were rerun after the fixes as well as the full-scene regression.

## Exact runtime changes

- `football_player.gd`: keep movement intent separate from facing. Destination
  input and braking remain immediate; grounded touch direction follows actual
  eased body facing. Turn detection compares consecutive movement intents.
- `football_ball.gd`: arbitrate a single dribble controller, apply at most one
  assistance force per physics tick, and release stale control after a short
  lease. A closer opponent can still contest at the existing close-contact
  reach; the ball remains an independent rigid body.
- Reject ground dribble assistance above the new editable 0.45 m height and
  while a keeper holds the ball. Allow a kicked ball a new editable 0.12-second
  release window before same-team dribble assistance can reclaim it.
- `footballer_visual.gd`: football actions may interrupt turn/stop recovery;
  turn/stop cannot continually restart each other. Existing committed-action
  rules remain in charge of slide and get-up recovery.

No new clips, rigs, physics solvers or gameplay controls were added.

## Verification and limits

Passed focused reversal/control, stop, pass contact and receive contact tests;
also passed ball fundamentals, passing, tackling, goalkeeper, AnimationTree,
shot contact, 11v11 setup and boundary-restart regression checks. The physics-only
ball-fundamentals fixture now explicitly unbinds animated presentation and pauses
the match director: immediate raw kick physics and marker-gated contact are
tested separately instead of sampling an animated shot before its contact frame.

Measured contacts: 4v4 pass 0.057 m at 0.4 s; receive 0.123 m at 0.333 s;
4v4 shot 0.006 m at 0.3 s. Full 11v11 pass gap was 0.075 m. A controlled
11v11 AI chance selected a shot and delivered exactly one impulse at 0.3 s,
with a 0.010 m toe gap and no early impulse. The shot integration test now
supports an alternate match scene and optional real AI chance selection:

```sh
BEECHLAWN_MATCH_SCENE=res://scenes/match_11v11.tscn BEECHLAWN_AI_CHANCE=1 \
  python3 games/beechlawn_rovers/tools/run_smoke_tests.py football_shot_contact_integration_smoke.gd
```

The full 180-second AI match reached full time, travelled 1,040.2 m, retained
finite player/ball positions and had no sampled stationary-ball seconds.
**It produced zero shots. This is not attacking-flow acceptance.** A comparison
with the previous runtime produced six shots and one goal; restoring only the
old ball code still produced zero, while restoring only the old movement code
produced one shot/goal. These physics-sensitive single runs flag reduced chance
creation, but do not establish a sole cause or reliable match-level balance.
Keep a repeatable midfield-to-shot scenario and multi-run match assessment ahead
of release; do not infer healthy football flow from ball travel alone.

An isolated debug Web export started in Chromium without browser errors. The
capture tool's optional `--motion-check` sends real D/A movement after kickoff.
[Captured frame](pes_motion_control_web.png): 960×540 software WebGL, shadows
disabled. This checks startup, inputs and HUD/layout only. A still frame cannot
validate smooth animation, and visible silhouette/garment issues remain.

## Performance and QA gates

The new ownership path is constant-time for established control and scans at
most the 22 players when choosing a new controller. No extra bones, IK chains,
cloth simulation or high-poly collision were added. This is a cost description,
not measured M1 performance: native 1080p/60 fps on M1 Pro/16 GB remains open.

Source/mannequin follow-up:
- Match jog/sprint stride distance and phase to simulated speed.
- Review planted feet through moving turns/stops in front/profile playback.
- Check hips, knees, shoulders and garment silhouettes through the existing clips.
- Preserve authored toe-contact timing when polishing curves or re-exporting.

Final in-game checks, still required:
- Human and AI: sprint reversal, controlled turn, stop-to-pass and receive-to-shot.
- Moving final meshes: stance slip, blend pops, arm pose and garment deformation.
- Contact reach and opponent alignment on uneven pitch at the broadcast camera.
- Sustained 11v11 attacking progression, chances, turnovers, keeper response and restarts.
- AnimationTree transitions, root-motion ownership and collisions without double movement.
- Native Mac appearance and sustained CPU/GPU/frame-time measurements at 1080p.

Next: BR-021 (21/25), still in progress, with BR-002 (2/25) contact coordination.
Prioritize stride/plant/transition polish and the attacking-flow comparison before
declaring this combined gameplay pass accepted.
