# Beechlawn Rovers development backlog

This backlog turns the supplied gameplay specification into a dependency-aware
build order. It prioritizes a small, genuinely playable match before scaling
to 22 players or expanding the move list. The status reflects the current
prototype; an item is complete only after its acceptance checks pass.

For art-, animation-, environment-, camera-, or lighting-related backlog
items, use the archived references and skill workflow in
[`art_reference_implementation_plan.md`](art_reference_implementation_plan.md)
and [`../references/README.md`](../references/README.md) before implementation.

## Current state

The standalone Godot 4.6.3 project opens on the Beechlawn Rovers 27 title
screen, offering Play (keyboard vs AI) or Watch (AI vs AI), then launches a
three-minute 11v11 match: ten outfield players and one keeper per side, plus a separate
referee. Shared human body, rig, animation and team/role materials replace the
proxy in this scene. Individual heads still use the common Shane-derived draft.
The original 4v4 scene remains the regression fixture.

Role-aware 4-4-2 targets, staggered team decisions, player switching including
keepers, contact-timed passing/shooting, kickoff/goal/full-time behavior and
basic boundary restarts are implemented. Current paired 180-second AI-vs-AI
replays produce three shots/two goals and one shot/no goals respectively,
without a sampled ball stall; attacking frequency and balance remain open.
Touchlines currently restart with a ground pass; authentic throw-ins, complete
fouls/offside/cards, substitutions and additional formations remain open.

The close broadcast camera, scoreboard and radar accompany shallow terrain,
rough chalk, weathered goals/nets, house/tree/car modules and eight spectators.
These are reference-led drafts, not exact likeness or venue acceptance. See
[`11v11_implementation.md`](11v11_implementation.md) and the release evidence.
Native Mac appearance and M1 Pro/16 GB 1080p/60 fps are not yet measured.

## Confirmed PES-style direction (2026-10-18)

The owner confirmed gameplay feel first, unmodded PES 2021 at default speed as
reference, strictly free assets, weighted responsive movement, bounded passing
assistance and original Blender animation where needed. The complete Gemini
report and its technical assessment are archived in
[`research/pes2021_gemini_review.md`](research/pes2021_gemini_review.md). Its paid-tool,
rig-replacement, literal engine-port and career-mode instructions are not adopted.
The active follow-on plan is
[`pes2021_gameplay_plan.md`](pes2021_gameplay_plan.md). It incorporates directional
locomotion/layers, first-touch and independent-ball control, role-based AI/duels,
keeper positioning/parries, calibrated airborne drag/spin, reference-led art,
texture import fixes and measured performance acceptance.
BR-021/BR-002 (items 21/2 of 25), both in progress, lead with coherent movement,
reception and contact in the existing full match. Native performance remains
unverified; the existing 25-item scope is retained. These are planned improvements,
not new completion claims.

First focused runtime pass is implemented; see
[`art_briefs/pes_motion_control_pass.md`](art_briefs/pes_motion_control_pass.md).
Sharp-turn touch alignment, single-controller dribble arbitration and pass
interruption of turn recovery have passing regressions. The
[chance/gait follow-up](art_briefs/pes_chance_gait_followup.md) corrects open-shot
rejection under trailing pressure, loose-ball recovery targets and speed-to-gait
mapping. The initial zero-shot run exposed these acceptance gaps; focused checks
now cover both attack directions and the reproduced loose-ball standoff. Source
stride/plant polish, balanced contested attacking flow and final-mesh motion
remain open; no complete gameplay or native performance acceptance is implied.
The 2026-10-18 full-formation buildup follow-up also removes safe-pass
starvation of through-ball decisions. Controlled tests now verify forward pass
progression. The subsequent [attacking-flow corrections](art_briefs/attacking_flow_followup.md)
fix complete-lane scoring, current-carrier selection and stale receiver targets.
Earlier local kickoff variants passed the physical-shot check, including a 1–1 result
from Boardeaux's kickoff. Chance frequency and team balance remain open under
BR-008; a single shot in the other fixture is a regression floor.

## Stack-specific practices to carry through the backlog

- Keep the 60 Hz physics loop authoritative and use the existing physics
  interpolation setting for presentation. On kickoff and goal-restart
  teleports, call `reset_physics_interpolation()` for the moved actors and
  ball so rendering does not blend across the entire field. Godot documents
  this reset requirement for objects repositioned after they enter the tree
  ([physics interpolation guide](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/2d_and_3d_physics_interpolation.html)).
- Keep tactical target selection separate from movement execution, which the
  current `TeamTacticsController` and `FootballPlayer` already do. For the
  flat pitch, prefer formation targets plus cheap local separation over a
  navigation mesh and 22 continuously avoiding agents; Godot recommends
  staggering navigation queries when agents are needed
  ([navigation performance](https://docs.godotengine.org/en/4.4/tutorials/navigation/navigation_optimizing_performance.html)).
- Preserve shared rigs/material resources and measure before adding per-player
  detail. Profile skinning and animation cost at 4v4 first; if 11v11 profiling
  shows animation overhead, reduce update rates for distant or off-screen
  players before lowering the close players' animation quality
  ([3D performance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html)).
- Treat Web Compatibility screenshots as functional/layout checks, not visual
  parity or performance evidence for the Mac Forward+/Metal build. Use fixed,
  repeatable gameplay scenarios and event/range assertions in automated tests;
  Godot physics is not guaranteed deterministic, so tests should not require
  identical rigid-body trajectories across renderers or devices
  ([physics introduction](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html)).
- Continue authoring football actions in Blender with explicit contact frames,
  shared rest pose/scale, and in-place movement where Godot owns locomotion.
  Validate toe/ball contact, player alignment, and clip interruptions in the
  match scene after proxy checks; a clean standalone animation preview is not
  sufficient acceptance for a two-player interaction.

## Recommended order

### P0 — Make the first prototype trustworthy

- [ ] **BR-001 — Mac playtest and controls pass**
  Run the project on the M1 Pro at 1080p. Verify keyboard movement,
  sprint exhaustion, close control, pass/through-pass, shot charging, ball
  bounce, goal-frame collisions and HUD readability. Fix issues found before
  adding more systems. Record average and worst-frame time over a repeatable
  60-second run.
  - Cloud Web smoke pass: added a dedicated Web preset and verified the
    release export starts in Chromium with the Compatibility renderer. Pressing
    E starts kickoff, the match clock advances, F3 shows the 60 Hz/player/ball/
    stamina debug HUD, and holding W+Shift moves the controlled player (8.4 m/s
    in the captured check). A browser screenshot exposed the kickoff prompt's
    poor contrast over the scenery; a dark font outline now keeps it readable.
    The browser test used software WebGL and is
    functional coverage only; it does not establish M1 frame rate or visual
    parity. The local export is `build/web/index.html` (about 49 MiB total).
    Still required: full Mac playtest at 1080p and target-hardware timing.
  - Research decision: use the Web export only for functional smoke coverage;
    keep the M1 Pro run at 1080p as the performance and visual acceptance gate.
    Profile first, then test reduced 3D render scale or Godot 4.6's FSR 2.2 /
    macOS MetalFX options only if GPU timing shows a need. Do not assume the
    22-player target is already performance-bound while the playable is 4v4.
- [ ] **BR-002 — Ball action/contact pass**
  - 2026-10-18 focused follow-up: grounded touches follow eased facing;
    nearest-eligible-player arbitration prevents competing dribble forces;
    height and post-kick release gates preserve independent ball travel.
    Human/AI reversals, competing callers and authored contacts pass. Full-match
    chance creation still needs assessment; see the motion-control pass above.
  Tune touch distance, sprint touches, rolling resistance, pass/shot power and
  aiming. Buffer pass/shot inputs and prevent actions outside a plausible
  contact window. Synchronize the eventual ball impulse to Blender-authored
  kick contact markers rather than a free-running animation timer.
  - Cloud pass: pass and shot taps now buffer for 0.20 s; kick assistance is
    limited to 1.12 m; shot charging takes 1.0 s to reach full power; goal aim
    respects the player's attack direction. Smoke checks cover buffered
    pass/shot contact and reject a kick at 1.30 m. A 12 m/s ground pass moved
    about 17.8 m over two simulated seconds after reducing excessive rolling
    resistance; 6 and 18 m/s passes covered 8.3 m and 27.9 m. Close-control,
    normal, and sprint touch spacing is now distinct, with continuous capped
    possession assistance and touch events throttled by cooldown. Shot charge
    and directional aim are covered by the new `ball_fundamentals_smoke.gd`.
    The optional Y-Bot visual gates a pass impulse on a Godot method track
    inserted at the Blender-authored contact frame; an integration smoke check
    confirms no early impulse and one physical pass at 0.4 s. This is a
    first-pass event hookup, not final human-mesh contact validation, and the
    M1 check still needs the target Mac.
  - Tuning follow-up: measured close/normal/sprint dribble spacing is
    0.78/0.91/1.15 m; six/twelve/eighteen m/s ground passes travel
    8.30/17.76/27.89 m in two seconds; tap/full shot speed is 12.97/30.00 m/s.
    A first-time pass now starts its authored pass clip when its contact event
    can meet the predicted incoming-ball window, accelerating the clip up to
    5x for a fast arrival instead of waiting for the ball to drift past the
    player. A new live-rigid-body test launches an 8.5 m/s incoming pass and
    confirms one pass impulse at frame 12 (0.200 s) for an 8.5 m/s ball and
    frame 6 (0.100 s) for an 18 m/s ball; both contact clips speed up and emit
    once. Web/headless tests validate this timing path, but animation quality
    and touch feel still need a Mac playtest. The shot action has since gained
    its own Blender contact event; see the BR-003 shot pass below.
  - Research decision: keep the ball physically independent and retain the
    existing force-assisted dribble. Establish reliable pass/shot trajectories
    before considering drag or Magnus-force tuning; only add aerodynamic forces
    if measured ball flight shows a clear need, with coefficients calibrated
    against observed trajectories. Do not enable a custom rigid-body integrator
    for this without a specific requirement. If player movement stalls against
    the ball during contact checks, test collision layer/mask arrangements in a
    minimal scene before changing the match setup.
  - Additional cloud pass: the selected ground/through-pass receiver now gets a
    timed target. When trajectory prediction places the ball at the authored
    right-toe contact window, an attached `FootballerVisual` starts the receive
    clip with a small timing correction from its Blender event metadata. At the
    contact marker, a short mass-scaled impulse cushions the live ball while
    preserving some player movement intent; it does not reposition or attach
    the ball. A buffered pass can interrupt the receive settle. The focused
    receive smoke test verifies intended-receiver triggering, toe/ball gap,
    contact timing, one physical cushion, locomotion restoration and pass
    interruption. Passing, ball-fundamentals, AI-carrier and animation-tree
    smoke checks pass; the Web release export also starts with no page errors.
    The receive event now runs on the actual 4v4 rigged actors. The M1 playtest
    remains outstanding.
- [ ] **BR-003 — Reusable footballer rig and first animation set**
  Use Mixamo Y-Bot as the replaceable rig/import baseline, then verify one
  shared skeleton can represent the Beechlawn outfielders and goalkeeper.
  Establish the Godot skeleton/import convention and a lightweight
  AnimationTree. Add idle, jog, sprint, stop/turn, close control, receive, pass,
  shot, hit/tackle response and get-up clips. Keep gameplay movement
  authoritative in Godot; use in-place locomotion and event markers for ball
  contact. **Cloud pass:** the owner-supplied Y-Bot FBX is preserved and a clean
  GLB exports/imports successfully; Blender and Godot checks confirm its 65
  bones, two skinned surfaces and approximately 1.805 m Y-up height. A reusable
  `scenes/footballer_visual.tscn` blends idle/jog/sprint proxy clips and includes
  pass and first-touch receive actions in an AnimationTree-compatible library.
  Headless checks cover skeleton, clip playback, and contact events. The receive
  clip is 42 frames at 60 fps, contacts at 0.333 s, and its toe tip comes within
  12.3 cm from the incoming ball center (about 1.3 cm beyond its 0.11 m
  radius) in the match-scene harness. A Blender pose sheet
  records ready, contact, and recovery. The proxy render also exposed the
  Y-Bot front axis facing opposite the game attack direction; its reusable
  visual now carries a 180-degree local rig correction, with pass and receive
  arcs measured against that orientation. Remaining: polish gait and foot
  contacts against football reference, replace the robot shell with the human
  visual, author the remaining hit/tackle responses, and validate the existing
  proxy actions on final player meshes.
  The verified Y-Bot scene is now the visual rig for all eight 4v4 actors, with
  team/keeper palette colors and idle/jog/sprint AnimationTrees active in the
  match. Event-gated pass and receive tests now use the scene's real Visual
  nodes: the pass toe is 0.057 m from the ball at 0.4 s and receive cushioning
  triggers once at 0.333 s. A Web play capture shows the rig running in-match;
  it is a Compatibility/SwiftShader view at broadcast distance, not a final
  likeness or Mac-renderer quality check. The import/check stage is complete;
  BR-003 stays open for animation polish and the human visual.
  **Additional cloud gait pass:** the Blender side-view proxy render showed a
  short, low-knee jog/sprint silhouette. I increased the existing in-place
  stride and knee drive modestly, added a small torso counterbalance, and kept
  the existing 2–3 cm pelvis bob. Evaluated foot-bone forward travel increased
  from 0.359 m to 0.438 m for jog and 0.534 m to 0.629 m for sprint; the Godot
  animation-tree smoke test still passes with the imported actions. This proxy
  improvement is now integrated into the 4v4 match. Foot planting at match
  speed and transitions during turns still need a closer visual pass; the Web
  capture is too distant for judging fine gait quality.
  **Braking/idle pass:** Blender pose-sheet review exposed that the imported
  Y-Bot idle left both arms extended in a T-pose. The idle action now bakes a
  relaxed arm position with slight breathing variation, and a new
  `AN_Beechlawn_StopFromRun` clip lowers the centre of mass, plants the support
  foot, catches with the other foot, and settles into the same idle pose. The
  stop is 36 frames at 60 fps with its brake plant at 0.233 s; Blender IK is
  baked to bone curves and creates no runtime IK. Godot starts it when movement
  intent is released above 0.8 m/s, cancels it if movement resumes above
  1.2 m/s, and otherwise restores the locomotion blend at clip completion.
  The animation-tree and live-match smoke tests verify the idle arm pose, stop
  playback, movement interruption, and return to locomotion; pass and receive
  contact integration tests still pass. A Web capture has no browser errors, but its
  distant Compatibility view cannot establish fine motion quality. The stop
  is a first blocking pass; human-mesh proportions, turn transitions, close
  foot-plant review, and M1 visual/performance validation remain open.
  **Directional-turn pass:** authored mirrored `AN_Beechlawn_Turn90Left` and
  `AN_Beechlawn_Turn90Right` actions at 60 fps (36 intervals / 0.6 s). Each
  starts with a short load, catches on a support foot, counterbalances through
  hips/torso/arms, and settles through a small recovery step. Temporary Blender
  IK for the planted foot and ready-arm hand positions is baked to bone curves;
  the exported clips contain no runtime IK or root motion. In Godot, a turn
  action starts after a >~69° change in movement direction while horizontal
  speed exceeds 2.2 m/s; player steering and the root remain physics-owned.
  Blender proxy renders caught and corrected the initial T-pose arms before
  export. Animation-tree and live actor smoke tests verify mirrored playback,
  return to locomotion, and triggering on an in-motion direction change.
  Human-mesh foot sliding and contact, blend feel under a real controller, and
  Mac 60 fps validation remain open.
  **Shot/contact pass:** added `AN_Beechlawn_ShotRight`, a 54-frame in-place
  instep shot at 60 fps with anticipation, support-foot plant, strike, forward
  hinge, follow-through, and recovery. Blender validates the support plant and
  strike-foot target, then bakes temporary foot/hand IK before export. Its
  contact event is at 0.300 s; `FootballPlayer` now queues direction, charge-
  derived speed, and lift, then applies exactly one rigid-body kick only when
  the animation reaches that marker and the ball remains in reach. The new
  integration check measures a 6 mm toe-to-ball-center gap at contact and
  confirms there is no early impulse. Milestone 1, pass/receive contacts, shot
  event, and animation playback checks pass. The proxy action still needs
  review on the final human mesh and Mac; no player-specific left-foot or
  finesse/power-shot variants are authored yet.
  **Close-control pass:** authored a 60-frame (0.983 s) in-place loop with a
  lowered ready stance, alternating small foot touches, and restrained upper-
  body counter-motion. Temporary Blender IK for foot/hand placement is baked
  into the action; the start/end pose seam is checked before export, with no
  runtime IK or root motion. The clip is a separate AnimationTree layer that
  blends in only while close control is held and the player is moving, so
  regular slow locomotion cannot accidentally trigger it. The layer eases in
  and out at 12/s; the underlying idle/jog/sprint speed blend remains intact.
  The animation-tree smoke test, milestone-one, braking/turn, pass, receive,
  and shot contact tests pass. The loop was reviewed on the lightweight Y-Bot
  proxy only; foot contact and close-control feel on the final player meshes,
  ball-touch synchronization in a live match, and Mac 60 fps validation remain
  open.
  **Prone-recovery pass:** Blender authors `AN_Beechlawn_GetUpFromProne`, a
  55-frame (0.9 s) in-place transition from a low, hand-supported prone pose
  through a tucked-knee/half-kneel to an athletic ready stance. Temporary hand
  and foot IK is baked to ordinary bone curves; keyed Hips motion lowers the
  body while the armature root remains fixed. Blender proxy renders are saved
  in `docs/images/y_bot_getup_pose_sheet.png`. Godot exposes this as
  `FootballerVisual.play_get_up()` and the animation-tree smoke test verifies
  playback and return to locomotion. Blender now also authors
  `AN_Beechlawn_GroundedSlideTackle`, a 38-frame (0.617 s) in-place action
  with a compressed approach, grounded side slide, and prone settle, sharing
  its end pose with the get-up start. `FootballPlayer` keeps the 0.62 s
  commitment and 0.18 s ball-contact window authoritative; animation is visual
  only. The visual driver chains the slide into the 0.9 s get-up and holds
  locomotion/actions during recovery. The old `AN_Beechlawn_SlideTackle` clip
  remains in the shared source library but is no longer played for this action.
  Blender proxy renders are saved in
  `docs/images/y_bot_grounded_slide_pose_sheet.png`. Final-mesh ground contact,
  tackle contact alignment, and M1 frame-rate validation remain open.
  - Research decision: keep the current lightweight 1D idle/jog/sprint blend
    and the separately blended close-control loop while these clips
    are being polished and integrated. Keep the 90-degree
    turn as a one-shot action; add a directional BlendSpace2D only after
    backpedal and strafe locomotion clips exist. Add upper-body layering only
    with a tested additive clip and bone mask.
    Retargeting or bone renaming must be verified against the Y-Bot track names
    and rest pose before changing import conventions.
  - Free-motion-source check: CMU subject 10, take 03 (“soccer - kick ball”) is
    archived with its usage terms in `references/animation_sources/cmu/`.
    A Blender 4.3.2 60 Hz retarget trial showed unacceptable pose distortion
    from rest-pose/axis mismatch, so it was discarded before Godot integration.
    It was retained as timing/arc reference for an original right-foot pass
    blocking clip. `tools/blender/author_football_kick.py` uses temporary IK
    for a planted support foot and counterbalancing arms, then bakes and removes
    those constraints. The resulting `AN_Beechlawn_PassRight` clip is 54 frames
    at 60 fps (0.9 s), with contact at frame 24 (0.4 s); see
    `docs/images/y_bot_pass_contact_sheet.png`. The Blender script exports it
    alongside the existing clips in `y_bot_animation_library.glb`, preserving
    their durations when sampling the library at 60 fps. It also writes
    `y_bot_pass_contact.json` from the Blender contact frame. Godot inserts a
    method event at that authored time; the `FootballerVisual` instance on each
    match `FootballPlayer` now gates the physical pass impulse on that event.
    An integration smoke check verifies there is no
    early kick, exactly one ball impulse at 0.4 s, and locomotion resumes. A
    follow-up Godot skeleton measurement exposed that the authored right-foot
    arc moved backward at contact: the toe was 1.14 m from the center ball. I
    corrected the Blender-authored forward arc and regenerated the animation
    library. The integration test now measures the animated toe tip at the event
    and verifies it is within 0.14 m of the ball center; the corrected proxy
    measures 0.057 m horizontal / 0.001 m vertical (0.057 m total), with the physical
    impulse still fired once at 0.4 s. This validates blockout contact geometry,
    not final human-mesh appearance or match-camera readability. The 4v4 scene
    now uses the shared Y-Bot visual on all eight actors; the primitive shapes
    remain as gameplay collision bodies only. Final human-mesh contact, live
    camera review, and M1 performance validation remain outstanding.
    Keep BR-003 open for locomotion refinement, receive/shot/recovery clips,
    shared-rig validation, and in-match visual QA. Do not ship the raw BVH.
  Check Rokoko's free sports mocap set only as optional supplemental material.
- [ ] **BR-004 — Configurable controls and action buffering**
  Keep the first playable match keyboard-only. Put its keyboard mappings in a
  remappable settings resource or UI; defer gamepad mappings until a later
  milestone. Add input buffering/cancellation rules for receive, pass and
  shoot; keep committed actions such as a slide tackle non-cancellable once
  that move exists.

**P0 exit check:** the player can move, keep the ball under control, pass and
shoot with predictable response. Goal-line/frame checks work, and a match-scene
playtest has no stuck bodies or unreported frame-rate failure on the target Mac.

### P1 — Validate football in a small-sided match

- [x] **BR-005 — Player/team data and tuning resources**
  Define reusable player attributes, team colours, roles and formation-relative
  positions as editable Godot resources. Populate Beechlawn with Shane Denham
  (#8), Robbie Roden (#10), David Murray (#5) and John O’Rourke (#1, goalkeeper)
  from their supplied character sheets. Use Des Feeney (#9) as the visual base
  for Bordeaux’s three outfield slots and goalkeeper because only his sheet is
  available; distinguish slots by role/kit details where useful, but do not
  invent names, facial identities or player-specific ratings. Use balanced
  editable defaults until ratings are supplied.
  - Complete: editable player, attributes and team resources now define both
    four-slot rosters. Beechlawn uses the supplied names/numbers; Bordeaux's
    four slots reference Des Feeney as the visual base and leave unsupported
    identities/numbers blank. Attributes stay at neutral 50 placeholders.
    Starting positions are generic 4v4 slots, not claimed real-world player
    positions. Automated checks validate roster size, unique IDs/slots, visual
    bases, and defaults. The 4v4 scene now instantiates these profiles as
    blockout actors; the remaining BR-006 work is match gameplay and flow.
- [x] **BR-006 — Build a 4v4 vertical slice**
  Add two sides with three outfield players and a goalkeeper each. Use the
  supplied Beechlawn roster and the Des Feeney visual base for all four
  Bordeaux slots. Start the first playable as a short match, with the human in
  control of one Beechlawn outfielder.
  Implement manual/automatic player switching, a visible controlled-player
  marker, and possession changes.
  - Complete for the current 4v4 blockout: all eight actors assemble from the
    team resources; Tab switches among Beechlawn outfielders; close contact can
    change the ball's team touch; play starts from a center kickoff, goal pauses
    restart with the conceding team, and the three-minute open-play clock ends
    at full time. Tests cover kickoff spacing, frozen pre-play state, goal
    pause, and AI restart. Tackling, robust contests and a true opposing
    goalkeeper remain later gameplay systems, not prerequisites to this
    assembly milestone.
- [x] **BR-007 — Passing, receiving and first touch**
  Score teammate targets using stick direction, angle, range, lanes and player
  motion. Add lead passes into space, first-time pass buffering, receiver
  movement and opponent interceptions. Keep assistance bounded by the intended
  direction.
  - Cloud progress: short and through passes now select a teammate in the
    intended arrow-key lane, score range/alignment and nearby opponent lane
    risk, and lead through-balls using receiver velocity. AI receivers make a
    time-limited run toward the predicted target. A pass press buffers longer
    only when a friendly ground ball is approaching the kick window. The AI
    selects a reachable point on a moving ball's short path and only takes
    possession on close contact. `passing_smoke.gd` verifies target selection,
    lead, receiver movement, first-time buffer, interception positioning and
    close-contact possession change. In the 4v4 scene, an incoming pass starts
    the rigged receiver's authored receive clip and resolves a velocity-based
    cushion at its contact marker. Final human player visuals and richer
    interception decisions remain polish work. Keyboard controls remain WASD +
    arrows, E ground pass, Q
    through-ball.
- [ ] **BR-008 — Small-sided attacking/defending AI**
  - Release follow-up: a mirrored tactical regression exposed straight-ahead
    wide carriers running to the byline. Full 11v11 carriers now gradually
    turn goalward in the final third, retaining width during build-up. Both
    mirrored controlled-attack contact gates now complement full-match stability
    and reported chance metrics; sparse natural-match shooting remains open. See
    [`art_briefs/ai_wide_carry_release_fix.md`](art_briefs/ai_wide_carry_release_fix.md).
  - Attacking-flow continuation: full-path pass scoring preserves open diagonal
    runs; actual kicking reach takes priority over future interception when
    selecting a carrier; successful control and turnovers retire reception
    targets. Three mirrored regressions failed before their respective fixes
    and now pass. Earlier local 180-second kickoff variants passed a physical-shot check,
    while balanced chance creation remains open. See
    [`art_briefs/attacking_flow_followup.md`](art_briefs/attacking_flow_followup.md).
  - 2026-10-18 follow-up: an open goalward shooting corridor is no longer vetoed
    by a nearby defender behind the ball. Primary defenders chase loose balls
    into contact range instead of stopping at a possession-pressure offset;
    support/formation arrival zones are unchanged. Mirrored shot selection and
    a collision-standoff recovery regression pass. See
    [`art_briefs/pes_chance_gait_followup.md`](art_briefs/pes_chance_gait_followup.md)
    for full-match results and remaining tactical-balance limitations.
  Separate team shape, individual decisions and movement execution. Teammates
  offer support and forward runs without clustering; defenders cover lanes,
  mark threats and selectively press. A close-range standing tackle is now
  bound to F for the human player, with a facing/range check, directional ball
  redirection, cooldown and matching AI tackle attempt. `tackle_smoke.gd`
  verifies contact, range rejection and AI transfer. Wide teammates now hold
  separated support lanes and advance on possession; the nearest AI carrier
  moves forward with the ball; defenders not pressing the ball recover
  goal-side in a ball-shifted line. `team_shape_smoke.gd` checks lane spacing,
  carrier intent and goal-side recovery. The nearest outfielder presses the
  ball while the other two greedily take distinct off-ball marks using distance
  and lane alignment; mark targets shade runners from goal and remain goal-side
  of the ball. `defensive_ai_smoke.gd` checks pressure, distinct assignments,
  lane matching and mark positions. Late-game context now lets a trailing side
  add a second presser in the opponent half, while a leading side drops its
  defensive line and keeps a single presser. `tactical_context_smoke.gd` checks
  score, clock and field-zone triggers. Possession changes now start a brief
  transition window: the losing side can counterpress with one player held in
  cover only when a second presser is within 18 m; otherwise the team holds
  shape instead of chasing across the pitch. The winning side gets more direct
  support runs, and the short press expires without resetting on same-team
  touches. `transition_ai_smoke.gd` checks turnover detection, range gating,
  preserved cover, expiry, same-team touch handling and forward support.
  `TeamTacticsController` now computes role/shape targets and
  returns intent data separately; `training_ground.gd` applies those decisions
  as movement requests, while `FootballPlayer` owns movement execution.
  `team_tactics_controller_smoke.gd` checks this separation. Still needed:
  fuller transition choices and authored tackle/success/foul animations. A
  committed G-key slide now advances before contact; ball-first
  contact redirects the live ball, while opponent-first contact emits a foul
  event and HUD call without changing possession. AI uses the same slide option
  outside standing-tackle range only when the defender is closing with a useful
  approach angle on a nearby carrier. `tackle_smoke.gd` checks clean wins, foul
  event, unchanged possession after a foul, AI slide commitment and rejection
  of a stationary challenge. Free-kick handling
  is still BR-016. Running outfielders now apply a brief, strength/balance-scaled
  shoulder response when contesting an opponent-held ball side by side, with a
  pair cooldown and no direct ball-possession change. `shoulder_challenge_smoke.gd`
  checks contact eligibility, balance reaction, cooldown, speed gate and
  possession preservation. Final authored animation polish and match-tested
  tuning remain. The assembled 4v4 scene now has a repeatable AI-vs-AI smoke
  run: after kickoff and 720 fixed physics frames, six outfielders moved more
  than 1 m and both teams had tactical intents; the ball stayed finite and all
  actors remained inside the playable envelope. This verifies basic match
  activity, not match quality or Mac frame pacing. Blender-authored blocking
  clips for a slide tackle (1.00 s) and shoulder-impact sell (0.73 s) are
  exported in `assets/characters/mixamo/y_bot_animation_set.glb`, with their
  editable source at `tools/blender/beechlawn/y_bot_animation_set.blend` and
  repeatable authoring script at `tools/blender/beechlawn/author_defensive_clips.py`.
  They use the verified 65-bone proxy but are not yet wired to slide/tackle
  events. The 4v4 actors now use this rig for locomotion/pass/receive; contact
  and movement remain controlled by Godot. Human playtest, authored-clip polish
  on the final footballer mesh, and tuning under match conditions remain.
  - Additional cloud pass: an individual carrier decision layer now lets an AI
    take a close central shot, release a safe forward through-pass when tightly
    pressed, or keep carrying when neither option is justified. Decisions only
    execute for an AI outfielder with the ball inside the normal kick window;
    action cooldowns prevent repeated kicks, and human-controlled players are
    left alone. `ai_carrier_decision_smoke.gd` verifies the three choices and
    confirms the match layer executes shots/passes and assigns the receiving
    run. Team-shape, defensive-marking, transition, tackle and passing checks
    also pass. BR-008 remains open for authored-clip integration and actual
    human-vs-AI / AI-vs-AI play-quality review.
  - AI-vs-AI acceptance samples two-second movement windows and reports action
    counts after kickoff. At 720 physics frames (~12 simulated seconds), runs
    consistently show all six outfielders moving and zero movement-stall
    windows, while pass counts vary (one pass in one run, none in another).
    The short-run pass count is diagnostic rather than a hard assertion; the
    carrier scenario test deterministically verifies that safe through-passes
    and close central shots are selected and executed. In a disposable,
    windowed Godot Agent run over 34 simulated seconds, the match produced 4
    passes, 10 tackles, 78 controlled dribble touches and zero movement stalls,
    but no shot. The sample is too short to tune match shot frequency; that
    remains a longer play-quality review. The render probe also now counts
    dribbles because `FootballBall.touched` emits for controlled touches.
  - The rendered probe exposed stale possession being treated as active carrier
    control: AI defenders could tackle a loose ball solely because the last
    touch belonged to the opposing team. AI standing tackles now require an
    opposing outfielder within 1.35 m of the ball; the existing slide rule
    retains a slightly wider 1.55 m carrier window. `tackle_smoke.gd` verifies
    that a close carrier can still be challenged, but stale team possession
    cannot trigger a tackle or consume the cooldown. The 12-second AI-vs-AI
    smoke test no longer treats an occasional absent pass as a failure; it
    checks movement, finite positions, tactical intents and stalls, while
    deterministic action choice/execution remains covered by
    `ai_carrier_decision_smoke.gd`.
- [ ] **BR-009 — First goalkeeper**
  Position between ball and goal, predict shot crossing, react with a readable
  delay, move to reachable saves, and catch/parry/deflect without teleporting.
  Add simple distribution after possession.
  - Cloud progress: both keepers track a goal-centred position; a goal-bound
    shot is projected to the keeper line, filtered against the frame, and met
    after an attribute-scaled reaction delay. The keeper moves through the
    existing CharacterBody controller and saves only inside a short contact
    radius. Fast shots are parried; slower ones are physically held near the
    keeper briefly, then distributed toward a teammate selected for distance
    and passing-lane safety. `goalkeeper_smoke.gd` covers prediction, frame
    rejection, reach, parries, catch, hold and distribution. Authored dive/catch
    animations, throws, tuning and gameplay validation remain.
- [ ] **BR-010 — 4v4 match loop and debug views**
  Add kickoff, goal, restart and short-match timer states. Add development
  overlays for player/ball velocity, AI targets, pass target, collision shapes
  and keeper prediction. Keep overlays disabled in ordinary play.
  - Cloud progress: kickoff, goal pause, conceded-team restart and three-minute
    open-play timer are implemented and smoke-tested. Remaining: debug overlays
    for tactical targets, collision shapes and goalkeeper prediction.

**P1 exit check:** a short 4v4 game (three outfield players and a goalkeeper
per side) can start, produce purposeful support and
defending, change possession, create shots and saves, score, restart and finish
without AI stalls. Validate the same actions with human-vs-AI and AI-vs-AI.

### P2 — Scale the validated systems to 11v11

- [ ] **BR-011 — Formation and role positioning**
  - 2026-10-18: full 4-4-2 team-relative slots and role-aware support/cover are
    active in 11v11. Additional formations and tactical tuning remain open.
  Add 4-4-2, 4-3-3, 4-2-3-1 and 4-5-1 using team-relative coordinates. Implement
  goalkeeper, centre-back, fullback, defensive/central/attacking midfielder,
  winger and striker responsibilities.
- [ ] **BR-012 — Team tactics and transitions**
  Add width, depth, pressing, directness and tempo settings. Shift defensive
  shape to the ball, preserve cover, create passing triangles, counterpress
  selectively and make late-game score-aware adjustments.
- [ ] **BR-013 — Efficient 22-player simulation**
  - 2026-10-18: 22 shared human actors plus separate referee validated; teams
    alternate 5 Hz tactical decisions, movement/ball remain fixed 60 Hz. Shared
    mesh/material propagation and independent playback are tested. Native
    frame-time, draw-call and memory budgets remain unmeasured.
  Expand from the validated 4v4 architecture, not a monolithic AI function. Stagger
  tactical decisions, use primitive collisions and shared resources, and
  measure physics, animation, draw calls and memory before adding detail.
- [ ] **BR-014 — Broadcast camera, HUD and radar**
  Tune the elevated sideline camera to the supplied screenshot; predict long
  passes, keep relevant players visible and frame goalmouth action. Add score,
  clock, phase, controlled-player feedback and a team-coloured tactical radar.
  - 2026-10-18 camera/presentation slice: nine original camera presets, saved
    height/zoom/angle tuning and C cycling. Camera-relative input and invalid
    preference fallback are covered by `broadcast_camera_smoke.gd`. Close
    Broadcast remains the default; see
    [`art_briefs/broadcast_presentation_plan.md`](art_briefs/broadcast_presentation_plan.md).
  **Current camera pass:** 12 m high / 26 m offset, smooth predictive tracking
  and up to 35% widening for long passes. Added a continuously updated tactical
  radar and debug-only touchline, goal and corner capture cameras. Native M1
  camera/input QA remains open.

**P2 exit check:** both full teams preserve recognizable shape, support attacks,
recover on loss, create and defend chances, and remain readable from the camera.

### P3 — Complete match rules and team management

- [ ] **BR-015 — Match state machine and boundaries**
  - 2026-10-18: whole-ball boundary ownership, goal kicks and corners have
    smoke coverage. A short ground-pass restart substitutes for throw-ins.
    Half-time and complete regulation restart presentation remain open.
  Implement pre-match, kickoff, open play, stoppages, half-time and full-time.
  Detect the whole ball over touchlines and goal lines; award throw-ins, corners
  and goal kicks to the correct side.
- [ ] **BR-016 — Fouls, offside and referee**
  - 2026-10-18: a separate black-kit referee follows play diagonally and stays
    outside player selection/possession/tackle groups. Adjudication is still open.
  Judge tackle timing/contact, advantage and cards. Evaluate offside at the
  teammate's ball-play moment and penalize only involvement. Add visible referee
  reactions and restart placement.
- [ ] **BR-017 — Substitutions and reduced teams**
  Select eligible substitutes, replace players, refresh role assignments and
  player switching, and keep playing with a dismissed player removed.
- [ ] **BR-018 — Tactical controls and match awareness**
  Expose tactical adjustments in-game and have teams react to score, time,
  formation changes and player count.

**P3 exit check:** a regulation-length match can progress through restarts,
goals, fouls, offside, cards, substitutions, half-time and full-time.

### P4 — Advanced football actions and feel

- [ ] **BR-019 — Shooting and aerial actions**
  Add driven, finesse, low, first-time and contextual shots; headers, volleys,
  jumps, aerial contests, crosses, lofted passes and goalkeeper cross claims.
- [ ] **BR-020 — Defending and skill moves**
  Add jockeying, shielding, teammate pressure, ball roll, step-over, body feint,
  fake shot, drag-back and directional skill turn. Each move must affect control
  or ball position, not just play a cosmetic clip.
- [ ] **BR-021 — Animation contact and blending pass**
  - 2026-10-18 T-pose fix: spawning now instantiates a clean player scene;
    duplicating the configured live player reproduced two skeletons per clone.
    Added a one-rig-per-player and immediate startup-pose regression, primed
    the replacement rig before its first frame, and relaxed StopFromRun arms
    in Blender without changing existing leg/root/contact curves. Added shared
    original 60 fps WalkOn/WarmupJog clips for the broadcast intro.
    See `art_briefs/presentation_source_audit.json` and the presentation brief.
  - 2026-10-18 release pass: running direction changes retain the locomotion
    gait instead of playing a planted pivot. Both shared-human pivot clips
    now reuse relaxed idle arms; all non-arm curves and contact timings are
    preserved. The source builder, `.blend` and GLB share the fix. Imported-rig
    pose and moving-turn regression checks pass. See
    [`art_briefs/shared_turn_polish.md`](art_briefs/shared_turn_polish.md).
    General stride/stance calibration and native moving-mesh acceptance remain open.
  - 2026-10-18 gait follow-up: visual blending now matches actual speed to the
    authored jog/sprint points and no longer forces sprint footwork at rest.
    Reference speeds come from each player's movement tuning. Source action
    paths were inspected directly in Blender; stride/plant curves were not
    changed. Final-mesh movement and source-footwork acceptance remain open.
  - 2026-10-18 focused follow-up: inspected shared Blender action curves and
    foot paths; no source curves changed. Pass/shot can interrupt harmless
    turn/stop recovery. In-place moving-turn foot slide, stride/phase matching,
    garment deformation and native moving-mesh acceptance remain open. Evidence:
    [`art_briefs/pes_motion_control_pass.md`](art_briefs/pes_motion_control_pass.md).
  - 2026-10-18: shared-human pass contact checked at 0.075 m from toe to ball;
    idle arms and near-horizontal locomotion arms corrected offline. Keeper set
    and standing save layers share the same 65-bone rig. Full action/deformation
    and target-Mac review remain open.
  Refine foot planting, turning, acceleration/deceleration, action interruption,
  first touch, contact timing and transitions across the animation set. Validate
  at gameplay camera distance with the final rig and moving ball.

### P5 — Art direction, presentation and shipping

- [ ] **BR-022 — Character and kit production**
  - 2026-10-20 shared neckline repair: removes disconnected throat scraps and
    the redundant collar ring, fits neck/shoulder cloth clearance and matches
    garment/skin weights while preserving the 65-bone rig and all 19 clips.
    See `art_briefs/shared_kit_repair/brief.md`. Collar/shoulder silhouette,
    underarm folds and individual likeness approval remain open.
  - 2026-10-19 shared-head follow-up: Shane's neutral head/eyes/skin are now the
    common starting master for both teams and referee. Each identity has an
    independent sculpt slot; compatible common changes regenerate with personal
    offsets retained. Separate hair selection preserves Shane's groom and bald
    identities without copying the groom to everyone. See
    `art_briefs/shared_head_pipeline.md` for source, commands and acceptance
    evidence. This completes the shared-head pipeline subtask; individual
    likeness, hair and garment approval remain open under this item.
  - 2026-10-19: Shane original-photo pass adds a separate head/eye/hair package
    on the unchanged shared rig, with a neutral identity and editable restrained
    smile. Integrated into both roster and retained 4v4 profile; likeness remains
    in review. See `art_briefs/shane_photo_likeness/brief.md`. The `/create-player`
    workflow now includes current production checks and removes stale first-pass
    and prototype-only assumptions. Photorealistic title portraits use the
    original David/owner photos and remain separate promotional artwork.
  - 2026-10-18 roster integration supersedes the prototype-only note below:
    a modular shared body/65-bone rig, 17 clips, six role atlases, small identity
    prints, editable height/build and topology-checked head sculpt deltas now
    drive the default 11v11 scene. 67,902 triangles include both sleeve variants;
    this is not a per-actor measured rendering budget. Collar/hem polish,
    individual face/hair likeness and exact keeper graphics remain open.
  Follow the project-local `.agents/skills/create-player/SKILL.md` for each
  reference-led player build; it requires source-to-feature mapping and fixed
  front/profile/three-quarter/broadcast review before accepting the asset.
  Replace the proxy with sheet-matched Beechlawn players: Shane Denham (#8),
  Robbie Roden (#10), David Murray (#5) and goalkeeper John O’Rourke (#1).
  Create a reusable roster/kit workflow. For Bordeaux, use Des Feeney (#9) as
  the supplied visual base for three outfield slots and the goalkeeper; keep
  those slots generic until more references arrive. Match face, proportions,
  hair, number, crest, fabric and skin tone; validate close and broadcast
  views. Build one shared animation rig and vary only mesh/material/kit data
  where practical.
  - Cloud progress: the current Y-Bot 4v4 rig uses the archived team and keeper
    palette values. An earlier primitive-visual pass tested sponsor/crest
    placement, numbers, socks and gloves against the kit object sheets. A
    reference-led Shane Denham #8 Blender/GLB draft now uses a licensed
    anatomical base and geometry-based face without a portrait texture. It
    passes the body/rig coordinate, normalized-weight, shared-neck-boundary
    and authored export-timing checks. The 2026-10-18 body/face/kit pass adds
    compact head/full torso shaping, anatomical facial targets, curved textured
    eyes, opaque short hair, a 2K anatomical head map and complete 2K panel kit.
    S. DENHAM / 8 and the enlarged sponsor are retained. Garments have sewn
    boundaries, loose shorts, cuffs and fitted socks; final counts and captures
    are in `docs/art_briefs/br022_shane_body_face_tailored_pass.md` and the
    checksum-bearing validation JSON. The subsequent likeness/deformation
    cleanup corrects the reversed neck normals, adds a clean CC0 skin bake and
    alpha-tested short hair, and replaces shorts with a fitted quad pattern.
    It removes a measured 125-degree thigh-roll mismatch in the prototype's
    six leg rotation tracks while preserving sampled contact paths. The rig
    stays at 65 bones with 15 clips; all other curves are unchanged. Current
    export: 51,022 triangles / six surfaces. See
    `docs/art_briefs/br022_shane_likeness_cleanup.md`.
    Blender pose/clay captures, Godot import smoke and fresh Web idle/portrait
    captures pass their structural checks. Visual review still exposes jagged
    collar/shoulder edges, a sleeve join and an uneven shirt hem. The prototype
    is still outside the roster: facial likeness/hair, garment cleanup, complete
    motion coverage, gameplay contact and M1 frame-time gates remain open.
    Follow `docs/art_briefs/br022_shane_likeness_and_kit_plan.md`; the next
    acceptance check is the reference-matched face/hair and full-clip garment
    review, before roster integration or duplicating the process to others.
- [ ] **BR-023 — Kilmore Drive park environment**
  - 2026-10-20 wet goalmouth/weather pass: shared mud/water masks at both goals,
    physical ground-ball resistance and persisted Sunny/Cloudy/Light rain/Mist
    options. Sunny remains sunlit with damp ground. Depth haze is used across
    Web/native; volumetric fog is not a clear-weather requirement. See
    `art_briefs/kilmore_wet_weather.md` for implementation, research and checks.
    Native shadow/performance and faithful backdrop/vegetation approval remain open.
  - 2026-10-19 sky/light pass: owner requested brighter, less-overcast weather.
    A CC0 4K partly-cloudy panorama replaces the blank gradient, with sky fill,
    a matching warm directional sun and cast shadows. Shared editable daylight
    settings serve match and player-review scenes. See
    [`art_briefs/kilmore_sky.md`](art_briefs/kilmore_sky.md) for source, before/after
    captures and validation. Native M1 lighting/performance approval remains open.
  - Satellite-footprint follow-up: added the tapered western green, inset
    back-garden edge, western road/path continuation and nine reused roadside
    houses. Blender/Godot geometry preserves the open 105 x 68 m playing area
    and grass buffer. Property/vegetation realism remains open; see
    [`art_briefs/kilmore_site_footprint.md`](art_briefs/kilmore_site_footprint.md).
  - Pitch-paint follow-up: softened the chalk pigment and reduced specular
    highlights while retaining uneven widths and worn edges. See
    [`art_briefs/chalk_fade.md`](art_briefs/chalk_fade.md) for the broadcast comparison.
  - 2026-10-19 satellite placement correction: a 35 m authored grassy apron
    now separates the road-facing touchline from the footpath; the near road
    edge is 37.75 m away instead of 8.5 m. Street, houses, cars and service
    details move together, trees concentrate near the distant park edge, and
    spectators remain by the touchline. Ground meets the field at grade while
    leaving its terrain relief unobscured. Exact site outline and road bends
    remain open. These distances are reference-led approximations, not survey
    measurements. See [`art_briefs/kilmore_road_setback.md`](art_briefs/kilmore_road_setback.md).
  - 2026-10-18: added shallow matched heightfield/render terrain (under 6 cm),
    broken-width chalk, weathered regulation goals with sagging alpha-test nets
    and a cheap impact ripple, leaf-card trees, textured houses/cars/walls and
    eight human spectators. Roadside is open rather than ringed by a wall.
    Heights and placement are inferred, not surveyed; individual houses/trees
    and precise reference matching remain open.
  Replace the flat pitch/backdrop blockout with locally appropriate worn grass,
  irregular chalk, weathered goal/net, residential houses, hedges, trees,
  roadside/park details, subdued crowd and overcast/evening lighting. Establish
  a reusable Godot venue setup around the Kilmore Drive reference: keep pitch
  dimensions/layout, ground and marking materials, boundary/backdrop dressing,
  and lighting/weather settings separable so later grounds can be assembled
  without duplicating the whole scene. Finish and validate this baseline before
  producing additional venues. Prefer free, properly licensed assets or original
  Blender work; record each asset's source and license. PES-specific stadium
  exporters do not produce Godot-ready assets and are not part of this pipeline.
  - Cloud progress: `scripts/kilmore_drive_venue.gd` now assembles the park
    backdrop around the existing 105 m × 68 m field, with original low-cost
    Blender house, tree and car modules plus wall, hedge, path, road and lamp
    dressing. The editable Blender source and reproducible builder are in
    `tools/blender/beechlawn/`; the imported GLBs are in
    `assets/environment/kilmore/`. This is a first modular blockout, not the
    finished reference-matched environment or an M1-validated render. A first
    web capture exposed and helped fix houses facing away from the pitch; the
    capture now shows their facades, CC0 grass/asphalt textures blended with
    broad wear, roadside and softer overcast light. Tree, car and house assets
    remain visibly stylized and surface/goal wear needs another pass. Asset
    sources/licenses are recorded under `assets/environment/surfaces/ambientcg/`.
    A 4v4 scene smoke test checks module loading, inward-facing facades, licensed
    surface maps, site dressing and kit variants.
- [ ] **BR-024 — Audio and match feedback**
  - 2026-10-18 pre-match slice: approximately 40-second original TV-style intro
    with walk-on, lineup, roster-labelled player/keeper portraits, venue,
    goal/net, fan, chalk/grass, ball and warm-up shots. Options toggle and
    Space/Enter skip; no intro after goals. Play/Watch freeze, restoration and
    kickoff checks pass. Final animation/art polish and the audio/event
    director below remain open. See
    [`art_briefs/broadcast_presentation_plan.md`](art_briefs/broadcast_presentation_plan.md).
  - Title/presentation slice: reference-led GPT Image key art, supplied-kit
    crest, native keyboard/mouse menu, Play/Watch launch modes and saved master
    volume/native fullscreen preferences. Spectator mode keeps all 22 players
    autonomous through either team's goal restart. See
    [`art_briefs/title_screen.md`](art_briefs/title_screen.md). This does not
    complete the remaining audio/event-director work below.
  Add distinct ball/player contact, referee, crowd, goal and UI sounds; tune the
  mix so key events remain audible without overwhelming play. Route feedback
  from typed match events rather than screen capture or OCR. Give events the
  context needed by listeners (event type, players involved, match time, score,
  and urgency), then use an audio/commentary director to prioritize important
  moments, select relevant recorded lines, apply per-line and event cooldowns,
  prevent commentary overlap, and duck crowd audio where appropriate. Start
  with gameplay events and audio hooks; add recorded commentary only when
  suitable, properly licensed recordings are available. Verify event routing,
  timing, priority, cooldowns, and mix behavior with test clips before content
  production.
- [ ] **BR-025 — M1 performance and Mac delivery**
  - 2026-10-18: separate football universal Mac/Web exports and release workflow
    added, preserving the wrestling Pages root and its Mac release. Package
    structure checks do not substitute for native playtesting or 60 fps profiling.
  Profile the full 11v11 build at 1080p on the M1 Pro/16 GB. Target stable 60
  fps; identify CPU/GPU frame-time spikes, memory growth, shader stutter and
  input latency. Optimize only measured bottlenecks. Add a separate Beechlawn
  Mac export/release workflow that cannot replace Aegis builds.

**P5 exit check:** the complete match is legible and attractive at broadcast
distance, stays within the Mac frame-time budget, and can be built/released
without touching Aegis artifacts.

## Risks and scope guardrails

- The approved 11v11 pass supersedes the old 4v4-only gate. Retain 4v4
  regression checks and validate full-team movement, AI and performance separately.
- Use original code, rigs, animation and art. The commercial-game references
  guide general feel and camera/control conventions, not copied assets or code.
  Apply a clean-room workflow: use observed behavior and high-level design
  principles as references, while implementing Beechlawn's systems independently.
  Do not make the project depend on PES binaries, extracted PES content, or
  PES-specific archive/export tools. Track provenance and license terms for
  third-party assets before they enter the project.
- Do not add detailed faces, crowds or expensive animation before profiling the
  playable match loop. Use LODs, shared materials, instancing and simple
  collision geometry for the distant park setting.
- Re-run the milestone smoke checks after gameplay changes and record what is
  genuinely playable in the README.

## Confirmed first-slice format

- Initial 4v4 slice is retained for regression; the approved default is now 11v11.
- Keyboard controls only for the first playable; gamepad support is deferred.

## Confirmed character and animation sourcing decision

- Use Mixamo's Y-Bot as the current temporary rig/import base. Its supplied
  robot shell is for pipeline validation only, not the visual target for the
  human player sheets. Keep the character replaceable and record source/license
  with imported assets. Do not treat stock clips as final football-specific
  animation without review and cleanup.
- Check Rokoko's free sports mocap clips as an optional supplement where a
  motion is relevant; availability of a suitable football action is not
  assumed.
- The intended final characters remain the supplied-sheet-matched Beechlawn
  players on a reusable shared rig, with the Bordeaux visual-base approach
  defined above. Temporary assets must not replace those likeness targets.
- Import/retarget through Blender and Godot's glTF pipeline, checking bone rest
  poses, scale, root motion, foot sliding and action contact timing. The
  owner-supplied Mixamo Y-Bot source FBX and cleaned GLB are integrated; no
  usable animation clips or final human player mesh have been integrated yet.

Research references:

- [Adobe Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html)
  and [Mixamo rigging and animation guide](https://helpx.adobe.com/creative-cloud/help/mixamo-rigging-animation.html)
- [Rokoko free sports mocap clips](https://www.rokoko.com/resources/rokoko-mocap-12-free-sports-animations)
- [Godot 3D scene formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)
  and [skeleton retargeting](https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/retargeting_3d_skeletons.html)

## Confirmed first-slice roster

| Team | Slot | Reference | Notes |
| --- | --- | --- | --- |
| Beechlawn Rovers | Outfield 1 | Shane Denham, #8 | Supplied full character sheet |
| Beechlawn Rovers | Outfield 2 | Robbie Roden, #10 | Supplied full character sheet |
| Beechlawn Rovers | Outfield 3 | David Murray, #5 | Supplied full character sheet |
| Beechlawn Rovers | Goalkeeper | John O’Rourke, #1 | Supplied goalkeeper sheet |
| Bordeaux | Three outfield slots | Des Feeney, #9 sheet | Shared visual base; identities/ratings remain generic |
| Bordeaux | Goalkeeper | Des Feeney sheet | Shared visual base with generic keeper kit/slot data |

The first team-versus-team gameplay milestone is therefore **4v4**, not a
full 11v11 match. This keeps the prototype small enough to validate passing,
switching, tackles, goalkeeper reactions and AI shape before scaling up.
