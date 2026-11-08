# Remaining AEW Fight Forever animations: plan (8 November 2026)

Owner request: work on the remaining AEW Fight Forever animations, to AAA
standard, matching Fight Forever's style, speed and smoothness, buttery smooth
for both wrestlers. Research first; this is the plan, not an implementation.

## The completion ledger, measured from the repo

| Bucket | Count | Notes |
| --- | ---: | --- |
| FF catalogue entries (`FFMoveLibrary.MOVES`) | **146** | |
| Authored paired clips (`ff_*` in `paired_moves.tres`) | **19** | See list below |
| Mapped to existing moves (`FFMoveLibrary.EXISTING`) | **8** | Cross Rhodes, Figure Four, Cody Cutter 4/5, Spear 2, Scoop Slam 2, Squatting Samoan Drop, Springboard Moonsault 3 |
| **Built total** | **27 / 146** | |
| **Remaining** | **119** | All tagged to wrestlers **not** on our roster |
| Roster fits (`FITS`: Kenny 8, Cody 11, Roman 10) | **29 / 29 built** | **Nothing missing** |

Built `ff_*` clips: brainbuster_1, buckle_bomb, casualty_of_war, chokeslam_1,
code_breaker_1, fireman_carry_bomb_2, inverted_ddt_1, oklahoma_stampede,
one_winged_angel, powerbomb_1, powerbomb_v_trigger_combo, running_v_trigger_1,
running_v_trigger_3, sit_out_powerbomb_2, snap_dragon_suplex_2,
snap_dragon_suplex_3, spinebuster_5, tiger_driver_98, v_trigger_1.

**The headline finding:** every FF move that fits our three wrestlers already
has an authored paired clip. The remaining 119 are other wrestlers' moves;
they only enter a match if we choose to widen `FITS` or the roster. The old
"3 of 146 built" claim is stale and is replaced by this ledger.

Remaining by family: driver 16, aerial 16, submission 14, knee 9, kick 9,
slam 8, strike 7, cutter 6, combo 5, backbreaker 4, powerbomb 4, piledriver 4,
suplex 4, takedown 2, lariat 2, neckbreaker 2, ddt 2, hurricanrana 2, pin 2,
stunner 1.

## References we actually have

- `gauntlet/refs/aew_ff_animation_review.md` — the owner's FF compilation
  review: measured lock-up speed, Cross Rhodes and One Winged Angel timings,
  the **hard camera cut on impact** with no whole-frame hit-stop, the shared
  numbered-variant pattern, two-tier framing, readable downed states, and the
  full 146-move table with performers. Only Cody and Kenny were timed at
  10 fps; five impacts were measured at 60 fps.
- `gauntlet/refs/ff_moves_and_gameplay_plan.md` — the earlier FF-style plan:
  which of our clips were still 2K26-era, and the FF treatment per family.
- `gauntlet/refs/ff_review/*.png` — review sheets already produced for the
  built batches (Tiger Driver, Roman's batch, Cody's batch, buckle bomb,
  casualty of war, springboard moonsault, Kenny's V-Triggers and snap dragons,
  spear setup, corner knee, crossbody).
- `game/resources/moves/ff_library.gd` — the catalogue, `EXISTING`, `FITS`,
  and `is_built()`.
- `game/resources/animations/paired_recipes.gd` and `paired_moves.tres` — the
  authored paired halves and root trajectories.
- `game/tools/blender/wrestling_clips.py` — where the authored FF clips live
  (e.g. `FF_Tiger_Driver_98_*`, `FF_One_Winged_Angel_*`, snap dragons).
- The existing gates: `test_clip_cadence` (holds/snaps/jerk),
  `test_pose_lint`, `test_paired_poses` / pair clearance,
  `test_clip_readability`, `test_authored_clips`, `test_strike_clips`,
  `test_ai_spacing`, `tools/probe/paired_shot.tscn`, `move_qa.tscn`,
  `moveset_tally.tscn`, and the seeded match matrices.

**What we do not have:** per-move frame data for the other 119. The
compilation only measured Cody's and Kenny's moves and five impacts. We must
not invent precise per-move frame counts and call them "FF-exact".

## The acceptance bar (what "FF style, speed, smoothness" means here)

Per move, for **both** attacker and defender:

1. **Timing:** the move resolves fast. Hoist-to-impact is about 0.8 s for a
   driver-class move; the attacker is back on his feet about 1 s after impact;
   the defender lands in a readable downed/sell state. Use the measured FF
   numbers where they exist, family timing otherwise.
2. **Impact emphasis:** a hard cut to the low ringside angle on the actual
   contact tick, then back wide. **No whole-frame hit-stop** on an ordinary
   move. Contact and camera insert must agree.
3. **Both bodies authored:** the attacker lifts/turns/drives and the defender
   folds/flies/falls in contact with each other, not two unrelated gestures.
   Grips within 5 cm at contact windows; no body overlap beyond the pair
   clearance ratchet.
4. **Smoothness:** no frozen holds or frame snaps beyond
   `test_clip_cadence` budgets, and a per-clip jerk figure recorded for each
   new clip. Add in-between keys wherever a clip lurches.
5. **Recovery:** attacker returns to a neutral stance; defender stays down in
   a clear sell; no teleport pops at state changes.
6. **Wiring:** the move fires in real matches from the correct tier/position,
   with contact/damage on the authored tick.
7. **Evidence:** a review sheet of both halves at match camera and close
   range, plus a seeded match tally proving it lands.

"Exactly matching" can only mean this measured bar, not mocap identity — we
have no mocap and no per-move FF frames for most of the catalogue.

## Phase A — audit the 27 built moves first (before authoring anything new)

For each of the 27, score against the bar and file a finding:

- Are both halves genuinely authored (not a two-pose fallback)?
- Contact tick vs the FF number where known (TD98, OWA, Cross Rhodes).
- Pair clearance, grip error, mat clearance, PoseLint.
- Cadence holds/snaps and jerk; does it read as buttery at 60 Hz?
- Impact cut present and on the contact tick; no freeze.
- Recovery timing and the downed sell.
- Does it fire and land in the seeded matrix?

Deliverable: `gauntlet/refs/ff_audit_2026_11_08.md` with a per-move table
(built / both roles / contacts / recovery / cadence / impact cut / wired /
verdict). Moves that pass stay; anything that fails goes into Phase B.

## Phase B — fix the failing built moves in family batches

Order by how often they appear and how much of the roster they cover:

1. **Drivers/slams** — one_winged_angel, tiger_driver_98, powerbomb_1,
   sit_out_powerbomb_2, spinebuster_5, chokeslam_1, fireman_carry_bomb_2,
   buckle_bomb, oklahoma_stampede, scoop_slam_2, squatting_samoan_drop,
   brainbuster_1.
2. **Suplex/neck** — snap_dragon_suplex_2/3, inverted_ddt_1, code_breaker_1.
3. **Running** — running_v_trigger_1/3, casualty_of_war, spear_2.
4. **Signatures/finishers and dives** — cross_rhodes, cody_cutter_4/5,
   springboard_moonsault_3.
5. **Submission** — figure_four_leglock.

Each batch: re-key timing/contact/recovery, add in-betweens, re-bake, run the
gates, render both halves, review sheet, seeded tally, then commit and deploy
as one batch. Small enough to review in one sitting.

## Phase C — the remaining 119, by family, with base + variants

Do **not** author 119 bespoke moves. FF itself uses a shared numbered-variant
library; copy that pattern:

- Build one strong **base paired clip per family** (driver, slam, powerbomb,
  suplex, piledriver, backbreaker, neckbreaker, ddt, stunner, cutter, lariat,
  takedown, pin, combo, strike, kick, knee, submission, aerial), then vary
  height, speed, rotation, carry distance and landing to produce the numbered
  variants. A variant should be a parameter change plus a review, not a fresh
  clip from zero.
- Prioritise the **shared generic variants** first: spinebuster_5 (3 users),
  superkick_5, spear_2, snapmare_1, sit_out_powerbomb_2, scoop_slam_2,
  diving_shooting_star, brutalizer, brainbuster_1 (2 users each).
- Then the biggest families: **driver (16), aerial (16), submission (14),
  knee (9), kick (9), slam (8), strike (7), cutter (6), combo (5)**.
- Unique specials (One Winged Angel-style) come last and only when a base
  exists to build on.

**Roster reality:** these 119 belong to other wrestlers. They only appear in
matches if `FITS` is widened or the roster grows. Before Phase C, decide with
the owner whether to (a) add selected library moves to the existing three
wrestlers, or (b) build a generic library for a future roster. Option (a) is
far cheaper and shows up in matches immediately.

## Per-batch delivery rules

- One focused commit per change; one validation + Mac deployment per batch;
  verify the `mac-latest` tag points at the batch commit before starting the
  next.
- Cheapest adequate check first: mannequin logic/contact checks, real-mesh
  deformation renders, then full-arena captures.
- Native M1/16 GB 60 fps is the performance gate; cloud timings are not Mac
  evidence.
- Update the backlog and release ledger with each batch's evidence and
  remaining limits.

## Honest limits

- No mocap, no per-move FF footage for most of the catalogue.
- No Blender/Godot in this workspace, so the audit and every new clip must be
  built and rendered on the Mac; nothing here can be claimed as rendered.
- "Buttery smooth for both wrestlers" is an acceptance bar to prove on frames,
  not something to assert from clip flags.
