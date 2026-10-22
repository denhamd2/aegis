# BR-009 — legal handling, catch/parry selection and recovery

BR-009 is **item 9 of 25, in progress**. This pass fixes controller outcomes;
it does not close authored low/diving motion or final goalkeeper quality.

## Reproduction and fixes

`python3 games/beechlawn_rovers/tools/run_smoke_tests.py goalkeeper_outcomes_smoke.gd`
initially demonstrated four failures on each side (eight total):

1. Speed alone permitted a two-handed catch at full lateral stretch. The catch
   envelope now requires a body-line ball (default half-width 0.42 m), chest
   height 0.55–1.55 m and the existing attribute-dependent speed threshold.
   Other reachable contacts still parry. The existing 0.95 m reach is unchanged.
2. Hand contacts had no area constraint. The ball must now be inside the
   keeper's own penalty area, including its side and goal-line bounds. Keeper
   feet inside the box cannot authorize handling a ball outside it.
3. A second action serial immediately rearmed a keeper after a save. Explicit
   standing/stretch recovery (defaults 0.24/0.65 s) now survives a new shot;
   movement, new human actions, AI tackling and dribble assistance respect it.
   Stoppages clear recovery. Shot reaction still elapses during recovery, but
   a second save cannot occur until the commitment ends.
4. The controller only considered opposing `shot` events, so it could not
   collect its own slow parry. After recovery, a low own-parry ball at <=3 m/s
   may be approached from within three metres and physically claimed inside
   the existing contact reach/body width. No remote claim; balls behind the
   body, fast/high/wide rebounds, teammate touches and deliberate back-passes
   cannot use this path. The existing capped spring holds the independent
   rigid body before physical distribution.

Ranked hypotheses were tested separately: the failing count fell 8 → 6 → 4 →
2 → 0. Those red logs are retained here. A stronger test through the actual
player physics call site then exposed a fifth bug: dribble assistance ran
before legal hand contacts and relabeled the recovered rebound. Hand contacts
now resolve first at the post-movement position. The later red/green logs
record that integration failure and fix. The final regression exercises both
sides on separate physics ticks so a per-frame dribble guard cannot hide one.

New tuning values are shared through FootballTuning. Reaction time, keeper
speed, physical reach, shot range and neutral player attributes are preserved.
The existing manual keeper-selection check still passes; neither keeper
teleports. The existing response test explicitly resets between its independent
low-save and manual-selection fixtures, while the new test preserves the
consecutive-save chain to exercise real recovery.

## Native evidence and limits

[Frame comparison](keeper_frames.jpg), [John clip](home_keeper.mp4),
[Boardeaux keeper clip](away_keeper.mp4).

Both fixtures load the actual 11v11 scene, park unrelated actors, then send a
rolling shot from five metres in front. The production controller physically
parries at tick 23 on each side. The recorded recovery state ends before
movement resumes. Manifests retain ball action/velocity, keeper position,
recovery and emitted save events. No ball is moved to the keeper by the fixture.
These are isolated controller reviews, not natural full-match attacks.

Forward+/Vulkan, Xvfb, llvmpipe LLVM 19.1.7, Godot 4.6.3; 640×360. The simulation
uses real 60 Hz steps, sampled at 10 frames/s for each 2.4-second clip. These
software-GPU captures do not establish Mac appearance, input feel or 1080p60.

**Visible open gap:** the retained standing-save clip keeps the hands too high
for a low shot. The physical contact-radius outcome is corrected, but the clip
does not yet depict measured hand-to-ball contact. This pass changes no body,
head, kit, rig or animation asset and makes no final-motion/AAA claim.

## Match and regression acceptance

Fourteen focused regression scripts passed, including moving kick contact,
first-time pass/shot, grounding, tackles/discipline, restarts, pose safety,
tactical parity, receiving and net contacts. The goalkeeper outcome regression
is also part of the separate Mac release workflow.

Six fixed full 180-second matches passed the existing chance gate for both
teams (6/6 qualifying each): **31/34 physical shots**, with contested attempts
from both teams in every match and aggregate shares 47.7%/52.3%. No sampled
stationary-ball stall. Scores and saves are diagnostics, not runtime quotas.
The exact scenarios and metrics are retained in [full_matches.json](full_matches.json)
and [validation.json](validation.json). Existing reach/reaction/rating defaults
were not reduced to preserve the attacking gate.

```sh
python3 games/beechlawn_rovers/tools/run_smoke_tests.py goalkeeper_outcomes_smoke.gd goalkeeper_response_smoke.gd goalkeeper_smoke.gd
python3 games/beechlawn_rovers/tools/check_ai_chances.py build/keeper-matches
```

## Next acceptance gate

Continue BR-009 (9/25) with original directional low-save, dive, catch/gather and
recovery actions on the current shared rig, using `create-player` and its
animation/rigging/export guides. Match hand placement/contact timing to the
independent ball without enlarging reach or driving the ball from animation.
Inspect complete clips and transitions on John and Boardeaux Des in native
close/broadcast footage. Distribution animation and human/M1 testing remain.
The football Web game stays retired; wrestling remains unchanged.
