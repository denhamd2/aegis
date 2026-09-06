# Roman Reigns — immediate execution board

This is the active next-step plan for the Roman variant. It follows the project's Phase 3 gate: the Roman model and paired move content are present, but the real match loop still has to reach and tune them reliably.

## Priority 1 — reference capture

- [ ] Capture a clean reversal-window measurement with a visible prompt or clear timing cue.
- [ ] Isolate a single non-mutual strike and write startup/active/recovery timings to gauntlet/refs/timings.md.
- [ ] Capture a clear ring-crossing sprint or run-through with enough framing to measure distance and time.
- [ ] Add a visible-input or overlay-backed feel/input-latency measurement.
- [ ] Add one or two extra three-count examples to confirm cadence is stable, not single-clip-specific.

## Priority 2 — live match reachability

Verified live 2026-09-06 by `game/tools/probe/reach_probe.tscn` (Roman vs
Roman, AI-vs-AI, seeds 1-3, 20000-tick budget, `--fixed-fps 6000`): **PASS
on all 3 seeds**, zero script errors in the run output.

- [x] Confirm tie-up entry happens on a neutral tick for both wrestlers, not one wrestler ahead by scene order.
  Every entry atomic (both FSMs land in TIE_UP the same tick, zero SPLIT),
  always gated (zero GHOST without a grapple press, zero RANGE beyond
  1.4m). Winners vary by seed (B×4, A×5), so no side owns entry order.
- [x] Verify AI closing logic reaches tie-up range reliably before forcing a strike.
  First tie-up at t51/t53/t51 from spawn; no seed exceeded the 3000-tick
  watch limit.
- [x] Confirm grapple move selection resolves through the normal referee/controller path, not only via direct harness invocation.
  3/3/5 grapples resolved via move_landed with real tiers
  (signature_neckbreaker, signature_backbreaker, finisher_facebuster among
  them); `GrappleRig.begin()`'s only gameplay callers remain the controller
  and the reversal counter (grep to re-prove).
- [x] Confirm the move handoff returns both wrestlers cleanly to IDLE or the next legal FSM state.
  Zero bad handoffs: attacker IDLE (or instantly PIN/SUBMISSION_ATTACKER
  on a same-tick cover, which is legal), defender in HIT_REACT/DOWN/
  PIN/SUBMISSION_DEFENDER. All 3 matches completed with real wins
  (t845/t721/t1602).

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

The Roman variant is no longer blocked on “can the model load?” It is blocked on “can the live match actually reach and tune the Roman paired moves in normal play?” That is the correct next milestone for Phase 3.
