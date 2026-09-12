# Roman Reigns — immediate execution board

This is the active next-step plan for the Roman variant. It follows the project's Phase 3 gate: the Roman model and paired move content are present, but the real match loop still has to reach and tune them reliably.

## Priority 1 — reference capture

- [ ] Capture a clean reversal-window measurement with a visible prompt or clear timing cue.
- [ ] Isolate a single non-mutual strike and write startup/active/recovery timings to gauntlet/refs/timings.md.
- [ ] Capture a clear ring-crossing sprint or run-through with enough framing to measure distance and time.
- [ ] Add a visible-input or overlay-backed feel/input-latency measurement.
- [ ] Add one or two extra three-count examples to confirm cadence is stable, not single-clip-specific.

## Priority 2 — live match reachability — DONE, measured

Measured with `tools/probe/reachability_probe.tscn` (new), which runs AI-vs-AI
matches to their finish and reports what the loop actually reaches. Numbers
below are from seeds 1-5 unless stated. Regression-tested by
`game/tests/test_match_loop_reachability.gd` (new), which runs a live match
scene rather than calling into the controller directly.

- [x] **Tie-up entry happens on a neutral tick for both wrestlers.** Already
  true in code before this round — entry was moved off the scene-order path
  into `MatchReferee._try_start_tie_up()` in an earlier session. Confirmed in
  play: the old bug's signature (progress pair always exactly one tick apart,
  the loser permanently behind) appears in 0 of 21 resolutions.
  **But the measurement found a second, unfixed defect the checkbox did not
  ask about: the tie-up *outcome* was constant.** In 3 of 3 seeds one wrestler
  won every tie-up in the match, and every resolution reported an identical
  progress pair — (6,10) four times, (7,10) three times, (10,6) five times.
  `setup_jitter()` shifts the mash rate once per match, then the rate never
  changes, so whoever drew the shorter interval won every contest by the same
  margin. Entry was neutral; the contest was decided once and re-read. Fixed
  by `WrestlerAI._roll_tie_up_timing()`, which re-rolls per tie-up from
  `(match_seed, player_index, attempt)`. Identical-pair seeds: 3 of 3 → **0 of 5**.
  A genuine (10,10) dead heat now occurs, exercising the seeded coin-flip
  tie-break that was previously described as reachable but never fired.
- [x] **AI closing logic reaches tie-up range before forcing a strike.** The
  approach itself was already correct (the AI keeps closing past strike range
  rather than stalling). **The defect was that it struck on the way in and
  could not possibly connect:** the closing branch fired a strike anywhere
  inside `strike_range` (1.6m) while a strike only lands inside
  `STRIKE_HIT_RANGE` (1.15m, measured off the jab's own contact frame). Worse
  than a wasted press — entering STRIKE zeroes velocity and the STRIKE branch
  never processes movement, so every whiff also stopped the approach for
  31-35 ticks. The AI was interrupting its own walk to punch air.
  Whiffs: 7 of 31 strikes (**23%**) → **0%**. Grapple moves per match: 10.0 → 11.0.
- [x] **Grapple move selection resolves through the normal referee/controller
  path.** 60 of 60 grapple moves across 5 seeds arrived via `move_landed`,
  which only `WrestlerController._resolve_grapple_move()` emits, reached from
  `_process_grapple_hold()` through the normal `_physics_process` dispatch.
  `CaptureHarness` never invokes selection — it only subscribes to signals.
  The only direct invocation anywhere is `test_grapple_move_selection.gd`.
- [x] **The move handoff returns both wrestlers cleanly to a legal FSM state.**
  0 strandings in 60 handoffs. Both sides are in a legal post-move state on the
  very next tick, and `MOVE_EXEC` is never observable on a frame boundary at
  all — confirming it does not survive a single tick for a rig-driven move,
  which is the assumption `MatchReferee._check_for_reversal()` rests on when it
  skips `MOVE_EXEC`.

### Defects found and fixed this round

Three of the four boxes above were already satisfied in code; what this round
added is the evidence and the regression tests. These are the things the
measurement found genuinely broken:

- **Same-tick mutual reversal crashed the match.** `_check_for_reversal()`
  read `_reversing` once, above its `[[a,b],[b,a]]` loop, so two wrestlers
  inside each other's reversal window on one tick applied two reversals and
  the second tripped `GrappleRig.begin()`'s `assert(not _active)`. Mutual
  windows are not exotic here — the AI presses reversal off the opponent's
  window and rapid mutual trading is the normal texture of this loop. Same
  bug class the file already fixes twice elsewhere: an outcome decided by
  iteration order.
- **The constant tie-up outcome** described above.
- **The whiffing approach strike** described above.
- **Two states with no exit.** `IRISH_WHIP` left only on a rope collision (a
  whip that reaches no rope hung the match), and `_process_grapple_hold()`'s
  weight-class early return retried forever with no timeout. Both now have a
  tick budget falling back to a legal state. Unreachable in the shipped scenes
  today, but Priority 3 adds moves.
- **`_is_grapple_attacker` was never cleared** — a latch on role state that
  outlived the role, the same shape as the knockdown bug. Cleared when the
  grapple resolves.
- **`roman_match.tscn` could never reach a fair tie-up.** It inherited
  `is_ai = false` on WrestlerA from `match.tscn`, and `MatchSetup` only forces
  both sides onto the AI for a recording run — so the one scene named for
  Roman-vs-Roman reachability was AI-vs-passive, which `match_setup.gd` itself
  calls "an infinite strike loop that never reaches a finish". Now plays to a
  finish on a bare run.

### Not fixed, still open

- ~~**The AI never runs in open play.**~~ **FIXED, measured.**
  `WrestlerAI.poll_input()` now charges when there is room and presses the
  attack on arrival. The mechanism is a **latch**: tested per tick as a plain
  distance check, the AI leaves `RUN` at exactly the distance where the attack
  becomes possible, so it could never fire at all.
  `ladder_probe` seeds 1-3: `running` **0 -> 1 in all six wrestler-matches**,
  and `RUN` is now present in every entries dict where it was absent.
  The decision sits below `poll_input()`'s `GRAPPLE_HOLD` branch on purpose --
  `input["run"]` means "Irish whip" there and "sprint" in free movement, so a
  charge visible from a hold would silently become a whip.
  **Two limits stand, both predicted rather than discovered:** it does not yet
  LOOK like a running attack (`_start_move()` zeroes velocity and the double
  leg's clip was deleted, so it plays a stationary `Punch_Cross`), and each man
  charges exactly **once** per match -- the ring is 3.3 m half-extent against a
  2.5 m engage distance, so the opening is the only run-up. Making it a
  recurring beat needs the item below.
- **There is still no neutral.** The probe shows wrestlers going straight from
  a landed grapple into a strike on the next tick. No spacing, no circling.
  Measurable against nothing until Priority 1 lands ring-crossing run speed.

### Independently re-verified on `roman-reachability-r1`

The same four boxes were measured a second time, in parallel and with a
separate instrument (`game/tools/probe/reach_probe.tscn`, Roman vs Roman,
seeds 1-3, 20000-tick budget, `--fixed-fps 6000`): **PASS on all 3 seeds**,
zero script errors. Two probes, written independently against the same loop,
agree — which is worth more than either run alone:

- Entry atomic on every tie-up (both FSMs land in `TIE_UP` the same tick,
  zero SPLIT) and always gated (zero GHOST without a grapple press, zero
  RANGE beyond 1.4m). Winners vary by seed (B×4, A×5), so no side owns entry
  order — the same conclusion the per-tie-up re-roll above was written to
  produce, reached from a different direction.
- First tie-up at t51/t53/t51 from spawn; no seed exceeded the 3000-tick
  watch limit.
- 3/3/5 grapples resolved via `move_landed` with real tiers
  (signature_neckbreaker, signature_backbreaker, finisher_facebuster among
  them); `GrappleRig.begin()`'s only gameplay callers remain the controller
  and the reversal counter.
- Zero bad handoffs: attacker IDLE (or instantly PIN/SUBMISSION_ATTACKER on a
  same-tick cover, which is legal), defender in HIT_REACT/DOWN/PIN/
  SUBMISSION_DEFENDER. All 3 matches completed with real wins
  (t845/t721/t1602).

Both probes are kept. `reachability_probe.tscn` reports the contest detail
(progress pairs, whiff distances, per-handoff states) the defect work above
needed; `reach_probe.tscn` is the tighter pass/fail gate.

## Model rendering — retarget fixed, two strike beats still float

Rendering a shotlist of the Roman variant in play
(`tools/probe/roman_shots.tscn`) found the model inverted in a match: head at
0.320m, feet at 1.729m, and in STRIKE a foot 0.316m *below* the mat, with the
torso torn away from the legs. Measured at three beats
(`tools/probe/roman_diag.tscn`), and the inversion held in all three. The
asset itself was never at fault — `tools/probe/roman_bare.tscn` loads
`roman_model.tscn` with no controller and no AnimationTree and it stands up
correctly (feet 0.092, hips 1.012, chest 1.323, head 1.654, height 1.927m).

**Second inversion path, found and fixed after the merge.** The retarget
below was only ever applied to the base rig's own animation library. Measured
on the merge result (seed 3, `roman_match.tscn`), `GRAPPLE_HOLD` and the mocap
strikes were still head-down while `LOCOMOTION`, `TIE_UP` and `HIT_REACT` were
upright — identical tick-for-tick to `f3e4f38`, confirmed by running the same
probe in a worktree at the pre-merge commit, so this was the original defect
half-fixed rather than a merge regression.

The cause was `adapt_animation_library()`'s own signature.
`source_skeleton` is what makes it a retarget rather than a rename, and it
was optional, with null meaning "copy verbatim" — the bug the function exists
to fix. `RomanModel` passed a real skeleton, so the base library converted
properly; `WrestlerController._adapt_animation_library()` called the same
method with *one* argument for `PAIRED_POSES` and `STRIKE_CLIPS`, so both took
the null path in silence. A default argument that quietly does the broken
thing is the whole bug. The fallback now resolves the base rig on demand
instead of abandoning the conversion.

Result, same seed and ticks:

| tick | state | `J_Hips` | `J_Chest` | `J_Head` | `J_Foot_L` | before → after |
| --- | --- | --- | --- | --- | --- | --- |
| 100 | GRAPPLE_HOLD | 0.996 | 1.308 | 1.622 | 0.122 | inverted → upright |
| 120 | GRAPPLE_HOLD | 1.520 | 1.815 | 2.009 | 1.087 | inverted → upright (lifted) |
| 140 | STRIKE | 1.064 | 1.375 | 1.694 | 0.199 | inverted → upright |
| 200 | STRIKE | 1.064 | 1.376 | 1.692 | 0.200 | inverted → upright |

**Still open, and not to be recorded as fixed.** Two strike beats did not come
back with the rest:

| tick | state | `J_Hips` | `J_Chest` | `J_Head` | `J_Foot_L` | root |
| --- | --- | --- | --- | --- | --- | --- |
| 150 | STRIKE | 1.722 | 1.613 | 1.600 | 1.582 | y=0.000, on floor |
| 160 | STRIKE | 1.854 | 1.638 | 1.535 | 1.881 | y=0.000, on floor |

The whole skeleton is bunched between 1.5m and 1.9m with the head the *lowest*
joint, while the controller root sits on the mat and reports `is_on_floor()`.
That is a body floating horizontally at chest height, not a legitimate leap,
and it is specific to certain frames of certain strike clips — `t140` and
`t200`, also `STRIKE`, are correct. Whatever remains is in the imported mocap
clips themselves rather than in the retarget path, which is now uniform for
every library. Needs a per-clip pass, and a visual one: the numbers can say
"wrong", but only footage says which clip and which frames.

**Cause and fix.** `adapt_animation_library()` copied the base rig's bone
rotations onto Roman verbatim. Bone tracks are *local* rotations, meaningful
only against their own skeleton's rest pose, and these two rigs share none.
They are now converted through global rest space: the delta is taken in the
parent's frame (`key * rest^-1`, not `rest^-1 * key` — the pre-multiplied
form measures the offset in the bone's own rotating frame, which straightens
legs whose rest axes happen to agree while leaving arms folded over the head)
and carried into the target's frame through both parents' global rests.

The texture faults found alongside it are fixed too, and were reconciled
against a second, parallel pass at the same surface on `roman-face-r1`; the
merged result is documented in `roman_model.gd` and keeps whichever fix the
measurement supports:

- **Head albedo** was orphaned *and* damaged — `roman_reigns_Image.png` has
  its blue channel pinned to 255 across 100% of the image and its red clipped
  at both ends across ~26%, so pointing the head at it directly renders a
  blue-white face. The face is reconstructed from the surviving green channel
  instead, tinted with the skin tone measured off the undamaged `body_color`
  atlas.
- **Hair and beard** rendered magenta because their packed `*_rai` data maps
  were wired in as base colour (R and B carry identical data; the GREEN
  channel is the strand opacity mask). Rebuilt as white RGB plus that green
  channel as alpha, tinted at runtime, with the beard and brows cut at their
  own lower scissor (their mask is 9.6% opaque against the hair's 32%).
  Flat-colouring these instead loses the strands entirely, so the alpha maps
  are what ships.
- **Eyes** are the one thing the face round solved better and the merge takes
  wholesale: the eyeball ships untextured, so iris and pupil are now real
  geometry seated on the cornea and parented to the `J_Eye` bones. `M_EYE`
  itself is a white sclera behind them rather than the flat brown tint that
  stood in when no iris existed.
- **Mouth.** `M_Teeth`, `M_Tongue` and `M_MouthBag` carry no material at all
  and are painted by node name.
- **Clothing** (tops/bottoms ship only `_nrm` maps) is coloured to the gear
  Roman wrestles in, the T-shirt and the duplicate "entrance" hair sets are
  hidden, and trousers and boots get a few millimetres of grow to stop skin
  erupting through them.

`test_roman_model.gd` passed throughout the inversion, because it asserts
*structure* — that the skeleton keeps its named bones and that animations were
remapped — not that the result is upright. Same shape of gap as the
source-grep assertion in `test_strike_clips.gd` that this round replaced with
a behavioural sweep.

## Priority 3 — Roman move set

Worked 2026-09-06 on `roman-moveset-r1` (suite 236/236 green locally,
Godot 4.7.1; canonical 4.6.3 in CI). Audit first: content coverage was
already complete -- all 17 MoveDefs carry a trajectory clip, both role
recipes, and pools that reach them (proven by test_paired_moveset) -- so
this round was choreography, not authoring.

- [x] Complete the remaining paired grapple/reversal move set to the architecture scope.
  Nothing missing: 17/17 trajectories + 34 role clips + MoveDefs + pools.
  (12th grapple slot stays held for a mocap replacement per the suplex
  decision, not backfilled.)
- [x] Keep root-transform-only motion for paired clips unless a real multi-rig requirement is proven.
  Untouched: rebake via build_paired_moves.gd writes position/rotation root
  tracks only; bone performance stays in paired_poses.tres.
- [x] Re-check move choreography for body clearance and floor-clip errors before tuning.
  New tucked-body clearance gate (test_no_trajectory_buries_even_a_tucked_body:
  1.15m cannonball, -0.12m floor, sampled at 60Hz off the real curves)
  caught 5 floor clips the root-only test cannot see (roots never go below
  the mat; the rotated bodies did, worst -0.21m neckbreaker). Fixed by
  raising mid-air defender roots (hiptoss, snapmare, spinebuster,
  neckbreaker) and, for armdrag, retiming the flip to complete at the arc
  peak -- lifting alone kept losing to cubic overshoot. Verified: gate
  green, full suite green, rebake deterministic (13 generated, 4 hand-keyed
  preserved). Remaining judgement is visual (arc character), for a capture
  critic, not more blind keys.

## Priority 4 — tuning

Worked 2026-09-06 on `roman-tuning-r1`. Method first: every tunable was
mapped against `gauntlet/refs/timings.md`, and anything without a
measurement was left alone -- ARCHITECTURE.md's reference-driven-tuning
rule cuts both ways, and inventing numbers is worse than keeping
placeholders.

- [x] Tune damage and momentum against the measured reference corpus.
  Finding: the corpus HAS no damage scale (nothing in footage measures
  damage) and no momentum schedule, so no damage/momentum number traces to
  it -- and none was changed. What was verified instead is pacing health,
  live over seeds 1-5 (ladder probe, 30000-tick budget): 2 submissions +
  3 pinfalls (both finishes reachable), signature in 5/5, chain ordered
  5/5, matches ending t721-t1602 with zero timeouts or grind, true
  knockdowns 1.2/match (signal-counted -- see below). Finisher fired 1/5:
  inherent to the knockdown-vs-climb race (a full climb needs 4 grapples,
  a match affords ~3.4 before the first cover usually ends it), NOT
  retuned blind -- weakening kickouts or stretching matches to force it
  would trade measured-healthy pacing for an unmeasured ideal. Finisher
  rate is capture-judgement material, not a headless-tuning item.
- [x] Tune move timing against the live footage and measurements in gauntlet/refs/.
  Finding: every measured timing is ALREADY adopted (jab startup 8,
  clothesline/double-leg 18 startup + 46 recovery, getup 126/68, count
  60/135/195 + 92 lead-in, submission 240-breakpoint ~2.5s) -- all covered
  by existing tests. Nothing new traces; nothing changed. Explicitly
  unmeasured surface (do not tune without footage): kick startup (shares
  the jab's 8 unexamined), jab active/recovery, all grapple frame data,
  ALL reversal windows (jab 6-9 included -- timings.md marks reversal
  length pending), limb damage ratios, momentum thresholds/schedule,
  match length, finisher rate.
- [x] Re-test the Roman v Roman match loop after each tuning pass.
  reach_probe (seeds 1-3): PASS, first tie-ups t51-53, zero violations,
  real wins. ladder_probe (seeds 1-5): above. Plus a real instrument fix
  found along the way: ladder counted knockdowns by sampling DOWN entries,
  but same-tick covers skip DOWN between samples (measured 0.2/match
  against 5 finishes) -- it now counts the knocked_down signal (true
  1.2/match).

## Current gate

Priorities 2, 3 and 4 are all closed on their own terms, but the model does
not yet render correctly under animation in every state. What each round
actually established:

- The Roman model is upright in `GRAPPLE_HOLD` and in most of `STRIKE`, but
  two strike beats still float horizontally (see "Model rendering" above).
  The moveset round's arc work was choreographed against curves rather than
  against what renders, so it is worth re-judging visually once those clips
  are clean.
- The live match **reaches** the paired moves and leaves them cleanly, proven
  by two independent probes and held by regression tests that run a real match
  scene rather than calling into the controller.
- The move set is **complete** (17/17 trajectories, 34 role clips) and its
  choreography now passes a tucked-body clearance gate, not just a root-only
  one.
- Tuning is **method-blocked, not work-blocked**: every measured timing is
  already adopted, and the corpus contains no damage scale and no momentum
  schedule, so those numbers trace to nothing and were deliberately left
  alone.

That leaves two gates, not one. The near one is the residual strike-clip
float above — narrowed to specific frames of specific mocap clips, with the
retarget path itself now uniform for every animation library.
The far one is **Priority 1 — reference capture**, which blocks in two
distinct ways. It blocks tuning, as it always has: the
explicitly unmeasured surface (kick startup, jab active/recovery, all grapple
frame data, all reversal windows, limb damage ratios, momentum thresholds,
match length) cannot be touched without footage, and inventing numbers is
worse than keeping placeholders. It also blocks two open questions that
headless measurement has now taken as far as it can and that need a capture
critic rather than another probe run: the arc *character* of the raised move
trajectories, and the finisher rate (1 in 5 matches — inherent to the
knockdown-vs-climb race, and not to be retuned blind).

The two locomotion gaps under "Not fixed, still open" above sit behind the
same gate: there is no neutral or spacing game, and the AI never enters RUN in
open play, so `RUNNING_ATTACK` never fires in AI-vs-AI. Neither is measurable
against anything until Priority 1 lands a ring-crossing run speed.

## Note on the environment

Godot **is** available in this environment (`/usr/local/bin/godot4`, 4.6.stable)
and `game/addons/gdUnit4/` is present, so the suite and the headless probes
run. Earlier rounds recorded "no Godot binary in this environment" and left
`slices.json` entries unjudged on that basis — that is out of date.

A fresh checkout starts with a stale import cache: the four `.glb` assets added
in the Roman commits have no entry in `game/.godot/imported/`, and the suite
reports 3 failures and 2 errors until `godot4 --headless --path game --import`
is run. Those are not code failures.
