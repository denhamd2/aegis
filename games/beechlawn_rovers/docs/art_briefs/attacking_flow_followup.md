# Attacking flow and reception — 2026-10-18

Backlog: **BR-008 (8/25), in progress**, with reception/contact coverage for
BR-002 (2/25) and BR-007 (7/25). This follows the
[chance/gait investigation](pes_chance_gait_followup.md). All changes are local
to the football project and its release checks.

## Reproduced defects and corrections

1. **Pass obstruction was measured from the receiver.** `_choose_pass_target`
   scored the short receiver-to-lead-point segment, omitting defenders along
   the actual pass. A blocked straight runner therefore outranked an open
   diagonal runner; the AI subsequently rejected the chosen lane and fell back
   to a short pass. Scoring now starts at the authoritative ball position.
   `pass_lane_selection_smoke.gd` reproduced the wrong choice before the fix;
   it now checks ground/through targeting and AI selection in both directions.

2. **Future interception displaced present ball contact.** In a 16 m shooting
   opportunity, an eligible carrier was assigned `support` while a teammate
   outside kicking reach became the primary chaser because it was nearer the
   predicted future ball point. No shot was queued. `_update_team_ai` now gives
   the nearest currently kickable teammate the carrier action and movement
   target. When nobody can play the ball, predictive interception remains.
   `ai_carrier_identity_smoke.gd` failed on the real team-update call before the
   fix, and now queues the carrier's shot in both directions and verifies the
   travelling-ball fallback.

3. **Successful receivers retained stale arrival points.** A physical control
   touch did not end `receive_target_time`; a player could move back toward an
   obsolete pass target instead of continuing the attack. That target also
   took priority over defending after a turnover. Successful dribble/first-touch
   contact now retires the arrival target. Loss of possession clears its timer,
   and tactical reception targets require current team possession.
   `ai_receive_handoff_smoke.gd` failed after a real control touch before the
   fix. It now verifies approach, control-to-carry, turnover-to-defense and
   timer cancellation in both directions. The authored receive integration
   also verifies that first-touch contact releases the target.

The existing `diagnosing-bugs` workflow was used: each correction has a small
failing scenario at the gameplay call site, followed by the original full-match
replay. No shooting-distance, power, kick-reach or AI-pressure tuning was
changed. There are no new Blender assets, animation curves or physics owners.

## Full-match results

Godot 4.6.3, headless Linux, actual `match_11v11.tscn`, 22 players plus referee,
shared rig/AnimationTree and terrain. Accelerated execution preserves a 1/60 s
gameplay step. Shot counts use physical `ball.touched` events, not sampled
decision availability. Match clock is 180 seconds; physics ticks also include
restart/celebration pauses.

| Replay | Shots Beechlawn/Boardeaux | Goals Beechlawn/Boardeaux | Ball travel | Physics ticks | Longest sampled stationary spell |
| --- | --- | --- | --- | --- | --- |
| Entry baseline, Boardeaux kickoff | 0 / 0 | 0 / 0 | 976.9 m | 10,927 | 0 s |
| After all three corrections, Boardeaux kickoff | 1 / 2 | 1 / 1 | 1,158.7 m | 11,605 | 0 s |
| After all three corrections, Beechlawn kickoff | 0 / 1 | 0 / 0 | 1,082.2 m | 11,305 | 0 s |

Both corrected initial conditions reach full time with finite actor/ball
positions and pass the previous zero-physical-shot gate. The first replay
records three `Shot fired` events; the second records one. These are coarse
regression gates, not a claim of competent or balanced attacking AI.
Repeating the corrected Boardeaux-kickoff replay on this host returned the
same shot, score, ball-travel and physics-tick totals.

The separate 30-second full-formation midfield scenario records five through
passes and no shots; its check still covers progression only. The isolated
trailing-defender scenario delivers one physical shot. This distinction remains
visible in CI and must not be presented as a complete contested attack sequence.

## Contact and regression checks

- Full 11v11 rigged pass integration: one physical kick at 0.400 s, toe gap
  0.075 m; locomotion restored.
- Full 11v11 rigged shot integration: one physical shot at 0.300 s, toe gap
  0.047 m; no early impulse.
- Authored receive integration: one cushioned touch at 0.333 s, toe gap 0.123 m;
  arrival target released and buffered pass interruption preserved.
- New mirrored lane/carrier/reception checks, existing passing, carrier
  decisions, team tactics, possession transitions, reversals, single-controller
  dribbling and loose-ball recovery pass.

Release follow-up: cross-host whole-match outcomes did not reproduce these
local shot totals. Current CI gates repeatable physical attacks in both
directions and whole-match stability, and reports natural match shot totals.
See [the follow-up](ai_wide_carry_release_fix.md); chance frequency is open.
The runner retains a 45-second deadline for short tests and gives the full
match a dedicated 75-second bound. A 300-simulated-second hard loop limit at
6x speed can need 50 wall seconds before CPU overhead, so its old 45-second
deadline could terminate an otherwise completing replay. Process-group cleanup
and explicit timeout overrides remain available.

Reproduce the whole-match gates from the football project:

```sh
BEECHLAWN_REQUIRE_SHOT=1 python3 tools/run_smoke_tests.py eleven_v_eleven_match_soak.gd
BEECHLAWN_REQUIRE_SHOT=1 BEECHLAWN_KICKOFF_TEAM=Bordeaux python3 tools/run_smoke_tests.py eleven_v_eleven_match_soak.gd
```

## Web functional check

An isolated debug Web export was exercised with the existing Playwright menu
harness. The [automated report](attacking_flow_web_evidence/title_web_check.json)
records no browser/page errors, working options, minimum-size layout, automatic
Watch kickoff with no human players, return to title, and Play kickoff with one
human-controlled player. Captures show
[Watch](attacking_flow_web_evidence/title_watch_match.png) and
[keyboard Play](attacking_flow_web_evidence/title_play_match.png).

This uses Chromium SwiftShader/Compatibility at 1280×720 with the existing
software-capture flag (shadows disabled and an 8 fps presentation cap). It
verifies startup and input/mode integration; the full-match shot measurements
above are from the headless native simulation. Kickoff captures still show
outstretched/elevated arms on several players, so BR-021 arm silhouettes and
temporal animation quality remain unaccepted. This local export was not published.

## Performance and next acceptance

Full-path scoring uses the existing candidate/opponent loops. Carrier priority
adds at most ten short distance checks per in-possession team decision, at the
existing staggered rate. Reception cleanup is constant-time in the existing
physics/contact paths. This describes added work, not measured M1 performance.
Native M1 Pro/16 GB 1080p/60 fps and final-mesh motion remain separate acceptance
checks; the software-Web smoke pass does not establish either.

**Next: BR-008 (8/25), still in progress.** Measure grounded central possession
and actual action eligibility in repeated attacks, then improve central support
and receiver timing where those measurements identify a gap. Require useful
chances for both sides across both kickoff variants; one physical shot in a
three-minute fixture is a regression floor. Preserve the passing/contact checks.
BR-021 (21/25) source stride/plant and final-mesh animation acceptance also remain
open; this gameplay correction does not complete them.
