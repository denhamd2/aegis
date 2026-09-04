# Roman Reigns — immediate execution board

This is the active next-step plan for the Roman variant. It follows the project's Phase 3 gate: the Roman model and paired move content are present, but the real match loop still has to reach and tune them reliably.

## Priority 1 — reference capture

- [ ] Capture a clean reversal-window measurement with a visible prompt or clear timing cue.
- [ ] Isolate a single non-mutual strike and write startup/active/recovery timings to gauntlet/refs/timings.md.
- [ ] Capture a clear ring-crossing sprint or run-through with enough framing to measure distance and time.
- [ ] Add a visible-input or overlay-backed feel/input-latency measurement.
- [ ] Add one or two extra three-count examples to confirm cadence is stable, not single-clip-specific.

## Priority 2 — live match reachability

- [ ] Confirm tie-up entry happens on a neutral tick for both wrestlers, not one wrestler ahead by scene order.
- [ ] Verify AI closing logic reaches tie-up range reliably before forcing a strike.
- [ ] Confirm grapple move selection resolves through the normal referee/controller path, not only via direct harness invocation.
- [ ] Confirm the move handoff returns both wrestlers cleanly to IDLE or the next legal FSM state.

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
