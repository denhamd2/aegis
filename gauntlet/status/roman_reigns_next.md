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

- **The AI never runs in open play.** `input["run"]` is only ever set by the
  whip decision inside `GRAPPLE_HOLD`, so `RUN` is only entered as the whipped
  man's rebound autopilot and `RUNNING_ATTACK` fires zero times in AI-vs-AI —
  an authored move with its own `MoveDef`, reversal window and tests that never
  happens in a match. This is a locomotion/feel gap, not a reachability one.
- **There is still no neutral.** The probe shows wrestlers going straight from
  a landed grapple into a strike on the next tick. No spacing, no circling.
  Measurable against nothing until Priority 1 lands ring-crossing run speed.

## Priority 3 — Roman move set

- [ ] Complete the remaining paired grapple/reversal move set to the architecture scope.
- [ ] Keep root-transform-only motion for paired clips unless a real multi-rig requirement is proven.
- [ ] Re-check move choreography for body clearance and floor-clip errors before tuning.

## Priority 4 — tuning

- [ ] Tune damage and momentum against the measured reference corpus.
- [ ] Tune move timing against the live footage and measurements in gauntlet/refs/.
- [ ] Re-test the Roman v Roman match loop after each tuning pass.

## Current gate

Priority 2 is closed: the live match reaches the paired moves and leaves them
cleanly, and there are now tests that fail if it stops doing either. The gate
moves to Priority 3 — completing the Roman move set — with the caveat that
every timing, damage and momentum number in the chain still traces to no
reference measurement, so Priority 1 remains the real blocker on *tuning* as
opposed to *reaching*.

## Note on the environment

Godot **is** available in this environment (`/usr/local/bin/godot4`, 4.6.stable)
and `game/addons/gdUnit4/` is present, so the suite and the headless probes
run. Earlier rounds recorded "no Godot binary in this environment" and left
`slices.json` entries unjudged on that basis — that is out of date.

A fresh checkout starts with a stale import cache: the four `.glb` assets added
in the Roman commits have no entry in `game/.godot/imported/`, and the suite
reports 3 failures and 2 errors until `godot4 --headless --path game --import`
is run. Those are not code failures.
