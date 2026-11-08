# Phase C — generic FF animation library design (8 November 2026)

Owner decision: build all **119** remaining Fight Forever moves as a reusable
library for future wrestlers. They do not need to fit Kenny, Cody or Roman
today; they need a MoveDef, both paired roles, family/setup tags, a per-move
sheet and a recorded visual-QA verdict so they can be assigned later.

## Why base + variants

The catalogue is a numbered-variant library, not 119 unrelated mocap takes.
Authoring 119 bespoke clips would be slow and would produce 119 unreviewed
one-offs. Instead:

- one strong **base pair per family** (attacker + defender),
- variants change timing, height, rotation, carry distance, sell and finish,
- each variant is baked as its own clip pair and reviewed on its own sheet.

A variant is not "the base renamed". It must differ in at least one visible
parameter and must pass the same gates as a bespoke move.

## Base map

| Family | Base clip(s) | Variant knobs |
| --- | --- | --- |
| driver | `FF_Tiger_Driver_98`, `FF_One_Winged_Angel`, `FF_Brainbuster_1` | impact time, lift height, sit-out, landing side |
| aerial | `Springboard_Moonsault`, `Springboard_Cutter`, `Diving_*` | flip count, rotation axis, arc height, landing |
| submission | `Figure_Four`, `Submission_*` | hold target, crank depth, escape timing |
| knee | `FF_V_Trigger_1`, `FF_Running_V_Trigger_1` | strike height, run-in, sell |
| kick | `Cyclone_Kick`, `Disaster_Kick`, `FF_V_Trigger_1` | kick height, spin, sell |
| slam | `FF_Chokeslam_1`, `Samoan_Drop`, `FF_Powerbomb_1` | lift height, carry, slam angle |
| strike | `Strike_*`, `FF_V_Trigger_1` | hand, target, impact beat |
| cutter | `FF_Code_Breaker_1`, `Cross_Rhodes` | hook, rotation, landing |
| combo | two or three existing strikes | sequence order, beats |
| backbreaker | `Signature_Backbreaker` | rack, drop, sell |
| powerbomb | `FF_Powerbomb_1`, `FF_Sit_Out_Powerbomb_2` | lift, sit-out, release |
| piledriver | `FF_Tiger_Driver_98` base, new head grip | sit-out, spike, sell |
| suplex | `FF_Snap_Dragon_Suplex_2` | bridge, release, rotation |
| takedown | `Samoan_Drop` setup / new snapmare | drop direction, seat |
| lariat | `FF_Casualty_Of_War` | run-in, arm, sell |
| neckbreaker | `Signature_Neckbreaker` | hook, twist, landing |
| ddt | `FF_Inverted_DDT_1` | invert, spike, sell |
| hurricanrana | `Springboard_Moonsault` / new rana | flip, landing |
| pin | new pin base | cover, hook, kick-out |
| stunner | new stunner base | hook, sit-out, sell |

## Generation pipeline

1. **Source table** — one row per move: id, family, setup, users, base clip,
   parameter deltas. The table is the single source of truth; the FF catalogue
   already supplies id/family/setup/users.
2. **Clip generator** — in `tools/blender/wrestling_clips.py`, a
   `make_variant(base_keys, params)` helper retimes keys, offsets the root,
   rotates the defender and selects the finish. It writes
   `FF_<Name>_Attacker` / `FF_<Name>_Defender` into `CLIPS`.
3. **Resources** — generate a `MoveDef` for each id under
   `resources/moves/ff/`, add an `authored` recipe and a root trajectory.
   Generic trajectories may be synthesized by family; special cases override.
4. **Bake and import** — one Blender GLB bake, one Godot import, then
   `build_paired_moves.gd` and `build_paired_poses.gd`.
5. **Per-move QA** — render `gauntlet/refs/ff_review/moves/<id>.png`, get a
   `visual-qa` verdict, record it in `ff_visual_qa_ledger.md`.
6. **Registration** — `FFMoveLibrary.is_built` sees the `ff_<id>` clip; add a
   `FITS` entry only when a roster wrestler should use it.

## Batch order

- **C0** — shared generic variants first: `superkick_5`, `snapmare_1`,
  `diving_shooting_star`, `brutalizer`.
- **C1** — driver (16).
- **C2** — aerial (16).
- **C3** — submission (14).
- **C4** — knee (9) + kick (9).
- **C5** — slam (8) + strike (7).
- **C6** — cutter (6) + combo (5).
- **C7** — backbreaker (4) + powerbomb (4) + piledriver (4) + suplex (4).
- **C8** — takedown (2), lariat (2), neckbreaker (2), ddt (2),
  hurricanrana (2), pin (2), stunner (1).

The live queue is `gauntlet/refs/ff_phase_c_queue.md`.

## Acceptance per move

1. MoveDef and both paired roles exist; the clip plays in a configured match.
2. Timing, contact, grip, clearance, cadence, pose and landing gates pass.
3. Per-move sheet exists (match camera + close/side, six beats).
4. `visual-qa` records pass, pass-with-watch-item, or fail with a defect.
5. Seeded tally proves the move fires and lands when assigned.
6. No batch-only sign-off; a move without its sheet and verdict is not built.

## Risks and limits

- Blender bakes are expensive; batch variants to one bake.
- Aerial rotations are the hardest to parameterize; review them first.
- Submission holds need limb-specific contact targets; generic targets will
  not be enough for every hold.
- The software renderer is acceptable for appearance review, not Mac
  performance.
- No mocap; these are authored variants against the measured FF bar, not
  frame-identical reproductions.
