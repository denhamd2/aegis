# AI chances and speed-to-gait follow-up — 2026-10-18

Scope: BR-021 (21/25), BR-002 (2/25) and the associated BR-008 (8/25)
attacking-decision gate. Implemented locally; native Mac and final visual
acceptance remain open. This follows [the first control pass](pes_motion_control_pass.md).

## Reproduced defects and changes

**Open shooting opportunities were suppressed by trailing pressure.** A new
full-11v11 fixture placed the ball 16 m from goal, a carrier in contact range,
and one defender two metres behind the ball. The original decision returned
`carry`, because every defender within 3 m vetoed an outer-range shot regardless
of direction. The isolated turning carry-to-shot check succeeded, separating
this decision defect from an inability to move or deliver the authored contact.

`player_decision_controller.gd` now checks a goalward corridor, up to 6 m ahead
and 0.8 m either side of the centre line. A defender behind the ball no longer
counts as a frontal blocker. Existing shot range, close-shot priority, pass
selection, human-control exclusion and contact timing remain intact. This is
a small original heuristic, not a complete expected-goals or tactical system.
The new `ai_shot_lane_smoke.gd` failed before the fix and passes afterward for
both attack directions; the same defender moved ahead still discourages a shot.

**Jogging selected sprint footwork.** The visual used `speed / 6`, although the
blend space puts jog at 0.55 and sprint at 1. Holding sprint also forced at
least 0.72 even at zero speed. The extended animation regression failed with
blend 0.969 during a normal 6 m/s run.

`footballer_visual.gd` now maps actual speed to the existing idle/jog/sprint
points: 0, 6 and 8.6 m/s by default. Sprint intent no longer forces footwork
before acceleration. `FootballPlayer.bind_footballer_visual()` supplies the
player tuning's reference speeds, so changing the shared movement resource
also changes gait selection. The existing smoothed blend remains; there are
no new clips, bones, constraints, IK solvers or authoritative root-motion tracks.

## Loose-ball recovery

**Loose-ball standoff:** the opposite-kickoff run produced no shots and a
six-second stationary-ball spell. A replay found the nearest last-touch-team
player over two metres away, blocked behind a defender. That defender's pressure
target was outside loose-ball contact reach, and its 0.9 m arrival zone stopped
it even farther away. A minimized live-ball regression failed immediately on
the defender's zero movement intent.

`team_tactics_controller.gd` now sends the primary chaser directly to its
interception point when no opponent is within the existing 1.35 m carrier range.
`training_ground.gd` gives a primary pressing defender a 0.25 m arrival zone;
support and formation targets retain 0.9 m. The live regression now reaches a
physical opposition touch within three simulated seconds. Existing pressure,
marking and possession-transition tests pass. No collision shapes or physical
duel rules were changed.

## Direct Blender inspection

Used the repo's Blender director, animation, rigging and Godot export guidance,
opening the actual shared `.blend` with Blender 4.3.2/bpy. Sampled each jog,
sprint and mirrored turn action at 33 points. Results are in
[the source audit](pes_gait_source_followup.json): 65 bones, 60 fps,
jog 0.8 s and sprint 0.5333 s. Sampled foot-joint loop-position gaps are zero.

Source stride/plant polish is still needed: forward foot-joint excursion is
about 0.438 m in jog and 0.629 m in sprint. One foot barely moves locally in
each 0.6-second turn (0.0094 m / 0.0010 m forward excursion). That planted
in-place design conflicts with a translating controller. These measurements
describe source joint paths, not measured world-space stance slip in gameplay.
No Blender curves, mesh, weights or GLB bytes were modified in this pass.

## Verification

- New mirrored shooting-lane check: failed before the fix, then passed.
- New `ai_carry_to_shot_smoke.gd`: actual outfielder begins facing away,
  turns and carries the live ball from midfield into shot range; one authored
  shot is delivered, with the ball reaching x=36.41 m. Team tactics are paused
  to isolate execution; this is not a contested full-match test.
- Extended AnimationTree check: jog at 6 m/s, sprint at 8.6 m/s and idle with
  sprint held at rest all pass, together with existing close-control,
  stop/turn and committed slide/get-up checks.
- Human/AI reversal and single-controller dribble checks pass.
- Loose-ball recovery, defensive marking, possession transitions, full 11v11
  setup/switching, boundary restarts and the 4v4 AI activity check pass.
- Carrier decisions, pass/shot/receive integration and raw ball fundamentals pass.
  The old carrier-decision fixture incorrectly expected an immediate shot
  impulse. It now verifies the queued action and explicitly delivers its contact
  event, as it already did for passing. The separate integration checks still
  advance the real authored animation timeline and check no early impulse.

The original three-minute probe reproduced zero shots with the first control
pass. After the corridor fix, the same initial setup produced **two shots and
one Beechlawn goal**, with 1,020.2 m ball travel, full time reached and no sampled
stationary-ball seconds. This improvement identifies a real decision defect;
it does not establish the sole cause of every trajectory difference from the
older runtime or establish balanced chance creation across matches.

The maintained full-match soak now counts actual shot-contact signals rather
than polling the latest action once per tick. It also supports
`BEECHLAWN_KICKOFF_TEAM=Bordeaux` to exercise the opposite initial possession.

Final replay after the loose-ball fix and gait mapping:

| Initial kickoff | Ball travel | Shots (Beechlawn/Bordeaux) | Goals | Longest sampled stationary-ball spell |
| --- | --- | --- | --- | --- |
| Beechlawn | 1,069.3 m | 1 / 0 | 1 / 0 | 0 s |
| Bordeaux, original stall replay | 1,017.9 m | 0 / 0 | 0 / 0 | 0 s (previously 6 s) |

Both reached full time with finite player/ball positions. The original replay
also checks for a four-second stall and now exits successfully. **The Bordeaux
run still created no shots.** These two initial conditions verify the specific
standoff correction, not sustained balanced attack quality or overall AI parity.

The final source was exported again to an isolated debug Web build and exercised
in Chromium with real kickoff, movement and reversal inputs. Startup/input
capture completed with no browser page errors. The
[captured frame](pes_chance_gait_web.png) uses 960×540 software WebGL with shadows
disabled. It confirms functional/layout coverage; arm silhouettes and footwork
still need improvement. It is neither Mac-renderer parity nor temporal animation
or frame-rate acceptance. No build was published by this pass.

## Full-formation buildup follow-up — 2026-10-18

The opposite-kickoff soak was rerun with an optional zero-shot failure gate and
added exact ball-to-goal distance tracking. With the Bordeaux kickoff it
completed 180 simulated seconds, travelled 976.9 m, recorded no shots, and
produced no stationary-ball spell. The closest possession ball came within
24.1 m of goal at a 16.0 m lateral offset; neither side entered the current
18 m central shooting zone. This localizes the remaining short-match weakness
to progression and central chance creation, rather than a missing shot-contact
event or the previous loose-ball standoff.

In `choose_carrier_action`, the progressive through-pass decision was evaluated
after a generic safe-pass option using an overlapping pressure condition. The
safe option commonly returned first, starving forward runs of a through ball.
The through-pass check now runs first under that same pressure and still
requires forward gain and a safe lane. The existing short-pass fallback is
unchanged. A full-formation midfield scenario now produces progressive
through-pass contacts and advances the ball, while the isolated trailing-
defender scenario still delivers a shot at its authored contact. Both are
included in CI as separate controlled and full-opposition checks.

This correction improves one buildup decision only. The 180-second Bordeaux
soak still recorded zero shots, so it remains a failing diagnostic when run
with `BEECHLAWN_REQUIRE_SHOT=1`; no balanced full-match chance quality is
claimed. The next gameplay investigation is central support/run geometry and
pass reception under pressure. No Blender asset or animation curve was changed:
the isolated scenario already proved that its shot action can reach ball
contact, and this run's measured bottleneck is before the shooting zone.

A paired Beechlawn-kickoff replay also produced 0/0 physical shots, despite
1,067.3 m of ball travel; its closest x-z approach was 5.4 m from goal at the
centre. That distance alone does not prove a valid shot opportunity because
the ball may be airborne or outside an eligible player's contact window. The
Bordeaux-kickoff rerun remained at 0/0 with 976.9 m travel and a 24.1 m closest
x-z approach. In the latter run the full-match diagnostic recorded no shot
status events, confirming that shot contact/animation was never attempted.
Both runs reached full time without a stationary-ball spell. These results
keep chance creation unresolved despite the improved forward-pass behavior.

The subsequent [attacking-flow continuation](attacking_flow_followup.md) fixes
complete-lane scoring, selection of the current reachable carrier and stale
receiver targets. Both kickoff variants now pass the physical-shot gate; the
earlier zero-shot figures above describe the pre-correction build. Chance
frequency and team balance remain open.

## Performance and remaining acceptance

The corridor adds at most ten short vector checks for an eligible AI shooter
in range, and loose-ball targeting scans the opposing team once, at the existing
staggered team decision rate. Gait mapping adds only
constant-time scalar arithmetic to the existing visual update. There is no new
per-frame physics or skeletal evaluation layer. These are cost descriptions;
M1 Pro/16 GB sustained 1080p/60 fps still requires native measurement.

Next is **BR-021 (21/25), still in progress**: polish existing stride/plant
curves and moving-turn transitions on a light proxy, preserve action contacts,
then validate moving final meshes in the actual match. Also retain BR-008
(8/25) contested chance-creation checks. Full-mesh garment/arm silhouettes,
receiver alignment, opponent interactions, keeper quality and native frame
times remain open; structural tests and a static Web capture cannot accept them.
