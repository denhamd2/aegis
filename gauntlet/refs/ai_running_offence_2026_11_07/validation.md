# Priorities 4–6: working offence, Roman's Spear and rope returns

Owner-approved related batch, following verified presentation publication
`6eab898999edc72821a774ffb4518da0dea5150c`. Owner explicitly requested immediate commit/deployment after the 99 focused checks; the complete CI run continues in the background.

## Behaviour

- Accepted attempts and named landings have independent counters. Paired moves
  count at GrappleRig acceptance; single-body attacks count at FSM entry. A draw
  that never starts a move does not consume its allowance.
- The last two big attempts survive intervening punches. An eight-move family
  history softly discourages repeated suplex variants and other repeated
  families. Legal candidates are deduplicated and the primary obeys opponent
  weight limits too. Existing phase/tier rules, identity, strike strings and
  deliberate body/weapon spots remain the selection framework. Fatigue favours
  shorter offence; damage mildly favours working an already hurt body part.
- When a working lock-up's basic allowance is exhausted, an earned, unused
  power move can be chosen. Once power allowances are spent, its fallback can
  draw ordinary legal working offence across both tiers, instead of feeding
  every later lock-up back into the small basic grapple pool.
- Roman can take an earned close standing opportunity during the existing
  comeback/finish phases. The controller checks the meter, legal states,
  weight, ring location, weapon and rig availability. An interrupted stalk is
  cancelled; accepting a running Spear stops further AI decisions that tick.
  Running into range remains interruptible; no new protection is introduced.
- Running attacks filter paired choices by both roles' actual legal states.
  Failed paired setups cannot become generic punches with paired-move damage.
  Charge cooldown starts on acceptance, with a bounded timeout for failed
  approaches. Rope-return travel includes distance to attack range and a
  bounded recovery allowance. Invalid targets produce 12 ticks of deceleration.
  The existing opponent rebound-counter path remains active.

## Focused validation

The final selection suites pass **31 cases**, including attempt versus draw
accounting, seeded selection, family/recent-move protection, illegal primaries,
duplicate candidates, phase ordering, fatigue/damage and exhausted-tier fallback.
See [selection_tests.xml](selection_tests.xml).

The final pure-AI suites pass **49 cases**, including charge acceptance/cooldown,
Spear interruption and authored setup retention. See [ai_logic_tests.xml](ai_logic_tests.xml).
Another **19 completed cases** cover the real-character Spear and running/rope
suites with no failures; their local process deadline preceded the Irish-whip
suite, so they are recorded as [completed checks](running_completed_checks.json),
not a completed full-suite run. Full CI remains in progress at [run 42403023484](https://github.com/denhamd2/aegis/actions/runs/42403023484); owner requested immediate publication while it continues.
The Spear suite uses the real Roman/Cody rigs and ring without arena scenery.
The actual-ring rebound test checks that a rebound enters a running attack.

## Seeded comparison

Baseline: published `6eab898`, with only the attached
[observability patch](baseline_observability.patch). Both versions use
`game/tools/probe/ai_quality_probe.tscn`, roster moves/personas and the shared
base rig. Arena, lighting and cosmetic processing are omitted. Seeds 1 and 2
cover Cody–Roman and both Kenny matchups in both slot orders, 12 matches per
version. Each has a 48,000-tick budget; the comparison rejects unfinished or
mismatched coverage. Ordered attempts and named landing counts are retained.

Both versions completed all 12 matches. See [comparison.json](comparison.json),
[baseline.json](baseline.json) and [after.json](after.json).
Do not interpret probe elapsed time as target-hardware performance. Unnamed
procedural contact stubs are reported separately from catalogued move landings.

## Isolated rope-return comparison

The same controller-only fixture, with fixed positions and real running MoveDef,
was run against baseline and final return logic:

| Opportunity | Before | After |
| --- | --- | --- |
| Near standing target | Attack on tick 25 | Attack on tick 25 |
| Far standing target | Timer expires on tick 45 at 7 m/s | Attack on tick 58 |
| Target down | Timer expires on tick 45 at 7 m/s | Recovery on tick 12 at 0 m/s |

See [before](rope_before.json), [after](rope_after.json) and
`game/tools/probe/rope_return_probe.gd`. This isolates the return controller;
it is not a claim about a whole match's rope-run success rate or a render.

## Reproduction

```sh
godot --headless --path game --fixed-fps 60 \
  tools/probe/ai_quality_probe.tscn -- --out /tmp/ai_quality.json
python3 tools/gauntlet/compare_ai_quality.py \
  --before baseline.json --after after.json --out comparison.json
godot --headless --path game --fixed-fps 60 \
  tools/probe/rope_return_probe.tscn -- --out /tmp/rope_return.json
```

Full regression uses the repository's existing CI command, including all tests;
focused concurrent runs use separate report destinations.

## Limits and Mac review

Arena appearance, perceived match pacing and M1/16 GB frame times remain for
owner review. These checks establish deterministic logic, reachable offence,
legal state transitions and completion. No animation resources were reauthored
in this batch. Named counters distinguish attacks from landings; they do not
classify every cancelled navigation intent as an attempted move. Later priorities
retain their existing reference-led animation, presentation and performance work.
