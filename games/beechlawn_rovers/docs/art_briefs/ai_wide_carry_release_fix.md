# Wide final-third carrying — release follow-up

BR-008, item 8/25, in progress. Deployment verification found a weak attacking
case; no published build was replaced by the failed workflow.

GitHub run 39182890137 completed the Beechlawn-kickoff soak with zero physical
shots in 180 match seconds (1,074.9 m ball travel). The same source on this
workspace produced one Boardeaux shot. Whole-match outcome agreement between
hosts is therefore not established; the earlier local results are insufficient
evidence for robust chance creation.

Ranked investigation: straight-ahead wide carrying, pressure-triggered outlet
passes preventing penetration, and cross-host simulation divergence. A focused
test of the actual tactical controller reproduced the first defect: from
40 m forward and 23 m lateral, both teams targeted another 3 m straight upfield,
without improving their goal angle. Both flanks failed, while midfield width
was correct. This is a deterministic spatial defect independent of the soak.

The fix blends a wide carrier's forward direction toward the goal centre
between 12 and 35 m of attacking progress. Steering fades out between 18 and
12 m of lateral offset, leaving central carries unchanged. At (40, 23), the home carry target becomes
(41.43, 20.36), with mirrored behavior for the away side. Only 11v11 AI carrier
targets change. Existing movement/turn limits, physical dribble touches,
passing decisions and contact-timed shots still execute the action. There are
no ball teleports, forced shot events, increased kicking reach or easier shot
eligibility thresholds.

A second deterministic defect was a safe backward outlet with a defender
four metres behind and free goalward space. `ai_carry_space_smoke.gd` failed
on both teams before the correction. Outlet pressure now uses the existing
3.2 m pressure range for trailing opponents; defenders ahead still trigger
the original early release within 5 m. The test checks both cases, preserves a safe progressive pass, and permits
a backward outlet when a challenge is within 2 m. A trial
that reduced every outlet radius was rejected because it disrupted contested
progression; the final change distinguishes frontal and trailing pressure.

Three short carry candidates now score forward progress and opponent
clearance over a 4 m horizon. The old target ran directly into a defender
3 m ahead; the mirrored tactical regression failed before this correction.
The ball and players still move through their existing physics controllers.

A live queued shot could also be redirected by the next staggered tactical
update before its 0.3 s marker. `ai_shot_approach_smoke.gd` reproduced a
0.177 m/s unwanted lateral velocity, then passes with stable preparation and
steering resumed on contact. Only AI approach steering is held; human controls
and physical tackle/contact distance remain unchanged. The existing authored
marker integration still checks the toe gap and absence of early impulses.

`ai_wide_attack_smoke.gd` failed before and passes after the fix on both flanks
and attack directions, and checks that midfield width remains. It runs in the
release workflow alongside the existing carrier/reception/lane tests. The final local whole-match diagnostics remain sparse: home kickoff
records 1/0 shots and away kickoff 0/0. These are not presented as solved
chance creation.

Release gating now separates repeatable capability from match outcome. The
mandatory midfield-to-shot scenario runs for both teams, requires an actual
shot by the intended attacking team (not an opponent), and keeps the existing
contact-timing gate. Both mirrored scenarios pass locally with one shot.
Full 180-second matches still gate completion, finite positions, terrain
containment, ball movement and full-time freeze, while reporting shots/scores.
`BEECHLAWN_REQUIRE_SHOT=1` remains an explicit strict diagnostic option for
chance-creation work. It is no longer a mandatory cross-host assertion that
every natural three-minute match contains a shot. Logs from the failed workflow
remain available at https://github.com/denhamd2/aegis/actions/runs/39182890137.

This corrects one source of poor chances; it does not complete attacking AI
or establish balanced chance frequency. Next BR-008 acceptance is repeated
contested attacks with central support, useful passing options and shots for
both teams. Native Mac playtesting and frame-time measurement remain pending.
