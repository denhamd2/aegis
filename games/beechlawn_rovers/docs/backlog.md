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

The standalone Godot 4.6 project contains an early 4v4 blockout on a local-park
Sunday-league pitch, with one human-controlled Beechlawn outfielder, basic
keyboard player switching, a rigid-body ball,
camera-relative movement, sprint/close-control input, basic dribble assistance,
pass/through-pass, charged shot, goals and score reset.
The small-sided AI assigns support, pressure, marking and cover roles; an AI
carrier can now choose a close shot, a safe forward pass under pressure, or to
continue carrying.
The match now waits for a center-spot kickoff, pauses on a goal, restarts with
the team that conceded, and counts match time only during open play.
The gameplay ball now renders the owner-supplied worn model (optimized to about
4.4k triangles) while retaining the independent 22 cm collision sphere. The
player and park environment are blockout quality. The M1 60 fps target has not
been measured on the owner's Mac.

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
  - Research decision: keep the ball physically independent and retain the
    existing force-assisted dribble. Establish reliable pass/shot trajectories
    before considering drag or Magnus-force tuning; only add aerodynamic forces
    if measured ball flight shows a clear need, with coefficients calibrated
    against observed trajectories. Do not enable a custom rigid-body integrator
    for this without a specific requirement. If player movement stalls against
    the ball during contact checks, test collision layer/mask arrangements in a
    minimal scene before changing the match setup.
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
  the pass action in an AnimationTree-compatible library; headless checks cover
  skeleton, clip playback, and the contact event. Remaining: polish gait and
  foot contacts against football reference, replace the robot shell with the
  human visual, and extend the set with stop/turn, close control, receive, shot
  and recovery.
  Keep primitive blockout actors until these clips pass visual review. The first
    import/check stage is now complete; this BR-003 item stays open.
  **Additional cloud gait pass:** the Blender side-view proxy render showed a
  short, low-knee jog/sprint silhouette. I increased the existing in-place
  stride and knee drive modestly, added a small torso counterbalance, and kept
  the existing 2–3 cm pelvis bob. Evaluated foot-bone forward travel increased
  from 0.359 m to 0.438 m for jog and 0.534 m to 0.629 m for sprint; the Godot
  animation-tree smoke test still passes with the imported actions. This is a
  proxy improvement only: the visual scene is not yet integrated into the 4v4
  match, so foot planting at match speed, blending during turns, and contact
  with the live ball still need the full in-game pass.
  - Research decision: keep the current lightweight 1D idle/jog/sprint blend
    while these clips are being polished and integrated. Add a directional
    BlendSpace2D only when authored backpedal/strafe/turn clips are available;
    add upper-body layering only with a tested additive clip and bone mask.
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
    method event at that authored time; when the optional Y-Bot visual is
    attached to a `FootballPlayer`, the existing physical pass impulse waits
    for that event. A kickoff integration smoke check verifies there is no
    early kick, exactly one ball impulse at 0.4 s, and locomotion resumes.
    This remains a mannequin blocking study and the default 4v4 scene still uses
    primitive players; final human-mesh contact, live camera review, and M1
    performance validation remain outstanding.
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
    close-contact possession change. Authored receive/first-touch animation
    and richer interception decisions remain polish work. Keyboard controls
    remain WASD + arrows, E ground pass, Q through-ball.
- [ ] **BR-008 — Small-sided attacking/defending AI**
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
  They use the verified 65-bone proxy and are not yet wired into the match:
  current 4v4 actors still use primitive visuals, and contact/timing remain
  controlled by Godot. Human playtest, authored-clip visual polish on the final
  footballer mesh, and tuning under match conditions remain.
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
  Add 4-4-2, 4-3-3, 4-2-3-1 and 4-5-1 using team-relative coordinates. Implement
  goalkeeper, centre-back, fullback, defensive/central/attacking midfielder,
  winger and striker responsibilities.
- [ ] **BR-012 — Team tactics and transitions**
  Add width, depth, pressing, directness and tempo settings. Shift defensive
  shape to the ball, preserve cover, create passing triangles, counterpress
  selectively and make late-game score-aware adjustments.
- [ ] **BR-013 — Efficient 22-player simulation**
  Expand from the validated 4v4 architecture, not a monolithic AI function. Stagger
  tactical decisions, use primitive collisions and shared resources, and
  measure physics, animation, draw calls and memory before adding detail.
- [ ] **BR-014 — Broadcast camera, HUD and radar**
  Tune the elevated sideline camera to the supplied screenshot; predict long
  passes, keep relevant players visible and frame goalmouth action. Add score,
  clock, phase, controlled-player feedback and a team-coloured tactical radar.

**P2 exit check:** both full teams preserve recognizable shape, support attacks,
recover on loss, create and defend chances, and remain readable from the camera.

### P3 — Complete match rules and team management

- [ ] **BR-015 — Match state machine and boundaries**
  Implement pre-match, kickoff, open play, stoppages, half-time and full-time.
  Detect the whole ball over touchlines and goal lines; award throw-ins, corners
  and goal kicks to the correct side.
- [ ] **BR-016 — Fouls, offside and referee**
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
  Refine foot planting, turning, acceleration/deceleration, action interruption,
  first touch, contact timing and transitions across the animation set. Validate
  at gameplay camera distance with the final rig and moving ball.

### P5 — Art direction, presentation and shipping

- [ ] **BR-022 — Character and kit production**
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
- [ ] **BR-023 — Bordeaux park environment**
  Replace the flat pitch/backdrop blockout with locally appropriate worn grass,
  irregular chalk, weathered goal/net, residential houses, hedges, trees,
  roadside/park details, subdued crowd and overcast/evening lighting. Prefer
  free assets or original Blender work and retain source files/licenses.
- [ ] **BR-024 — Audio and match feedback**
  Add distinct ball/player contact, referee, crowd, goal and UI sounds; tune the
  mix so key events remain audible without overwhelming play.
- [ ] **BR-025 — M1 performance and Mac delivery**
  Profile the full 11v11 build at 1080p on the M1 Pro/16 GB. Target stable 60
  fps; identify CPU/GPU frame-time spikes, memory growth, shader stutter and
  input latency. Optimize only measured bottlenecks. Add a separate Beechlawn
  Mac export/release workflow that cannot replace Aegis builds.

**P5 exit check:** the complete match is legible and attractive at broadcast
distance, stays within the Mac frame-time budget, and can be built/released
without touching Aegis artifacts.

## Risks and scope guardrails

- Keep 11v11 behind the 4v4 acceptance gate; more players amplify broken
  movement, AI and performance problems.
- Use original code, rigs, animation and art. The commercial-game references
  guide general feel and camera/control conventions, not copied assets or code.
- Do not add detailed faces, crowds or expensive animation before profiling the
  playable match loop. Use LODs, shared materials, instancing and simple
  collision geometry for the distant park setting.
- Re-run the milestone smoke checks after gameplay changes and record what is
  genuinely playable in the README.

## Confirmed first-slice format

- Start with a short playable 4v4 match.
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
