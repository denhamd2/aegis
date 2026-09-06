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

- [ ] Complete the remaining paired grapple/reversal move set to the architecture scope.
- [ ] Keep root-transform-only motion for paired clips unless a real multi-rig requirement is proven.
- [ ] Re-check move choreography for body clearance and floor-clip errors before tuning.

## Priority 4 — tuning

- [ ] Tune damage and momentum against the measured reference corpus.
- [ ] Tune move timing against the live footage and measurements in gauntlet/refs/.
- [ ] Re-test the Roman v Roman match loop after each tuning pass.

## Current gate

The Roman variant is no longer blocked on “can the model load?” It is blocked on “can the live match actually reach and tune the Roman paired moves in normal play?” That is the correct next milestone for Phase 3.
