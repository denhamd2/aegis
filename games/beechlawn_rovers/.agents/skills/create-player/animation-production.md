# Animation production

Use before authoring/importing clips, retargeting, adjusting locomotion or action transitions, or diagnosing a visible T-pose. Paths are relative to the repository root. These lessons supplement the main skill's rig, likeness and runtime gates.

## 1. Establish the live contract

Inspect `tools/blender/beechlawn/footballer_shared.blend`, its exported GLB and `games/beechlawn_rovers/scripts/footballer_visual.gd`. Record the actual action inventory, durations, looping, root channels, constraints, AnimationTree wiring and contact metadata. Read the current imported AnimationPlayer too. The original supplied Y-Bot FBX contained a one-frame pose; a rigged asset or named action is not proof of usable motion.

Archive motion provenance, use terms, original sample rate, rest pose and axes. Prefer original clips or supplied/free licensed sources. The archived CMU take was a timing reference; its distorted direct retarget was rejected. A raw capture must pass retarget and final-mesh review before entering production.

The live shared source is authoritative. Older proxy builders can recreate an earlier library and discard later clips, presentation, turn or tailoring corrections. Historical guides such as `docs/mixamo_animation_import.md` explain discoveries; their earlier 4v4 scope, clip counts, names and rebuild sequence do not override the current source/controller. Inspect each tool before running it.

**Gate:** identify changed channels/actions and the live consumers; record the untouched rig, curves, contact events and interfaces that must survive.

## 2. Preserve space and time

Inspect rig-local units, armature/object transforms, facing and bone axes before applying conversions. The current source uses local centimetres with Y up/Z forward and an object transform into Blender metres. Godot's visual orientation is another transform. Validate the full chain with evaluated hips, knees, ankles, feet and forward toe movement; changing rest transforms to improve a still can break the whole library.

Retarget with rest-pose and bone-roll awareness. Shane's axial leg twist remained wrong despite correct joint positions. Correct only the intended rotations on copies, preserve required joint paths and foot orientation, maintain quaternion sign continuity and compare evaluated results across the clip. Leave unkeyed lower-body channels unkeyed in upper-body actions. `shane_leg_retarget.py` records a historical prototype method, not a command to run blindly on the shared production source.

Keep authoring FPS, FPS base, clip origin/range, export sampling and event metadata consistent. A previous 60-to-30 authoring mismatch doubled exported durations. Compare imported seconds against source seconds and event frames. Resampling 30 Hz at 60 Hz does not add captured detail; 120 fps rendering does not repair a bad pose, stride or contact. Keep the game's fixed physics cadence distinct from authoring and display rates.

For in-place motion, keep horizontal displacement under the movement controller. Offline IK may be baked to ordinary bone curves and removed. Runtime IK, root-motion authority or additional solvers are separate design/performance changes. Preserve source curves/rests through digests where unchanged; check intentional edits against their stated scope.

**Gate:** axes, evaluated joint/foot paths, exported duration and event times agree; unrelated channels survive.

## 3. Motion and state transitions

Drive gait from actual speed and the authored blend points, not the held sprint button or a generic speed/max-speed ratio. Inspect stride length, stance phase, planted-foot drift and transitions on the final human/boots. The existing jog anchor is not the midpoint of the blend space; inspect the current tree rather than assuming evenly spaced anchors.

Keep locomotion active through translating turns; a nearly planted pivot sliding through the world produces foot dragging. Reserve stationary pivots for their intended context. Let meaningful football actions interrupt stop/turn recovery, and resume locomotion when braking intent ends. Preserve committed slide/get-up recovery rather than enabling unrestricted cancellation.

For T-pose defects, distinguish missing motion, inappropriate arm curves and stale/unprimed animation state. Check relaxed elbow/shoulder relationships through the clip. After replacing a rig or returning from an intro/action, rebind the AnimationTree to the active AnimationPlayer, clear stale caches where needed and evaluate the initial pose before first draw. The live `_prime_locomotion_pose()` path handles this; inspect it before duplicating fixes elsewhere.

Share immutable meshes/materials/animation content while keeping each actor's playback state independent. Duplicate mutable trees/libraries/clips before per-instance mutation, including added event tracks. Verify staggered playback on teammates, opposition, keepers and referee; shared resources must not put everyone in the same pose or add a second skeleton. Exercise scene startup, intro-to-kickoff, stop/resume, action finish, menu return and appearance swaps.

**Gate:** complete changed clips and boundary transitions look correct on the final mesh; no first-frame T-pose, translating planted pivot or coupled actor playback.

### Sustained runtime failures

Inspect the imported Animation resource's loop mode, not only its
AnimationNodeAnimation setting. In Godot 4.6, nodes marked linear still froze
at the end of non-looping imported jog/sprint clips. Copy/configure the actual
motion resources as looping; preserve one-shot pass/shot/throw/card actions.
Holding a one-shot preparation pose must not change that clip into a loop.
Test several cycles after constant speed, not only the first pose transition.

For apparent jumps, measure CharacterBody height/vertical velocity separately
from hips and boot motion. A capsule climbing its independently rolling ball
caused a 1.128 m launch; animation edits could not fix that. Keep ball collision
response against players while excluding the ball from the player's kinematic
floor/platform mask. Test actual sustained dribbling on terrain with contacts.

Animation-only additions can export the existing rig plus new actions in a
small GLB without rewriting shared body/kit/head exports. Retain the exact
rest transform and imported track paths. Prove marker timing and recovery on
the real actor. Dead-ball hand holding is separate from open-play possession;
release the independent rigid body at the authored throw marker.

## 4. Contact belongs to gameplay

For partial upper-body layers, inspect the imported tracks before building a
bone filter: glTF forced sampling can expand an unkeyed lower body into baked
tracks. Retain only the intended upper-body bones. At the same animation time,
compare shield blend 0/1 to prove leg poses stay equal; advance the running
clip with the overlay active to prove the legs still cycle. A blend parameter
reaching 1 does not establish correct filtering.

Store authored contact markers in the existing metadata contract and verify its clip name, time origin, frame and FPS against the export. Install the Godot event once on an appropriate clip copy. Repeated setup must not add duplicate markers, and cancellation/interruptions must not leave a stale pending action.

The marker signals contact; the fixed-tick gameplay code validates reach and applies the independent ball impulse. Preserve aim/power, input buffering and action-priority behavior. Check no early impulse, exactly one valid impulse, correct cancellation and locomotion recovery. Keep raw ball-physics fixtures separate from marker-gated action tests.

When gameplay samples the live skeleton, both the locomotion AnimationTree and
action AnimationPlayer must evaluate on the physics clock. Setting only the
player left running poses stale for five ticks at 10 Hz rendering. Exercise a
slow draw cadence against 60 Hz physics, then ordinary marker/contact checks.
Seeded full-match replays also need an explicit fixed draw cadence; a seed
alone does not make wall-clock-driven replays repeatable across hosts. Keep
the gameplay timestep and chance thresholds unchanged when fixing the harness.

Measure the evaluated toe/boot against the live ball in the actual 11v11 scene. A proxy's acceptable toe distance does not prove the final boot contacts correctly after body scale, retargeting or clothing changes. Recheck pass, receive and shot on the actual visual orientation. A full match reaching full time or moving the ball does not by itself prove realistic contact or healthy attacking flow.

Distinguish root approach reach from the live boot contact window. Check standing,
jogging and sprinting contacts for human and AI actors: long sprint touches and
post-collision speed caps can lose the ball during wind-up. For a fast first-time
return, shorten anticipation while preserving contact and follow-through timing.
When interrupting an old action, arm new pending gameplay state after its
synchronous cleanup. Fixtures with movement disabled must still tick the contact
window; a frozen-ball pose check alone misses these failures. When selecting a
new dribble controller, consider facing and reach alongside distance; preserve
the existing short lease and release rules for established control.

**Gate:** the final mesh reaches a plausible ball contact at the authored event, gameplay impulses occur once at the intended time, and action recovery remains responsive.

### Receiving while moving

Schedule reception and buffered strike intent before generic dribble assistance.
The spring can otherwise relabel an incoming pass before its authored receive
marker. Defer only the receiving actor's spring; keep opposing tackles and
interceptions live. Bind preparation to the incoming serial and restore any
owned capsule exception on contact, miss, interruption, possession loss or whistle.
Check the stoppage version after contact signals before rearming recovery state.

Keep the gait/supporting leg active under a moving receive overlay; compare its
pose with overlay weight zero at the same phase. Use one fixed-tick pose clock
and exported metadata crossing for seek-driven layers, whose method callbacks
may be skipped. Measure live selected-boot reach and integrated post-impulse
velocity. An impulse callback's velocity getter may still show the incoming ball.
Profile dormant layers across all 22 players: several zero-weight receive branches
still added measurable graph cost. One selected clip behind a single layer kept
the supporting gait and actor-local filtering while removing that overhead.
Use raw movement input or actual carrier travel for the outlet; cursor assistance
can set an internal placeholder stick that is not the user's intended direction.

Evidence: `games/beechlawn_rovers/docs/art_briefs/contextual_control_2026_10_25/brief.md`.

### Aerial contact lessons (2026-10-23)

Keep the short physical jump in CharacterBody movement and the authored clip
in place. Verify measured root height, landing and recovery separately from
head/chest pose. Restore the exact baseline pose at clip endpoints; review bent
balancing elbows throughout, rather than accepting a single contact still.

For aerial clips on the physics animation path, prime playback at time zero
and dispatch contact methods immediately; restore the previous deferred policy
on finish/reset. Delayed callbacks plus unprimed playback missed the short
anatomical window. Sample fixture poses with `seek(..., update_only=true)` so
review setup cannot trigger the marker it is supposed to test.

A coarse standing capsule can repel the incoming ball before chest/forehead
contact. Probe the trajectory first. The current solution temporarily exempts
only the predicted receiving actor during a narrow contact approach and restores
collision after success, miss, cancellation or stoppage. Keep the real anatomical
reach check; increasing reach to hide the capsule fault weakens contact quality.

Reserve a receiver's run during the foot wind-up and allow its forecast before
the ball enters local reach. Otherwise tactical updates can turn the intended
striker into an outlet before delivery. Test the whole foot-to-flight-to-header
sequence, including a nearby opponent and both attack directions. Keyboard
press/release tests use normal 60 Hz cadence; accelerated physics bursts can
coalesce queued synthetic input. Confirm actual roster identity in native
metadata instead of assuming array slot zero is Shane.

Evidence and remaining limitations:
`games/beechlawn_rovers/docs/art_briefs/aerial_play_2026_10_22/brief.md`.

### Fast boot strikes and export origins

When metadata subtracts the first source frame, explicitly export the GLB with
`export_anim_slide_to_zero=True`. The default exporter retained a first key at
1/60 s while metadata assumed zero. Check the actual GLB key ranges, imported
clip duration and evaluated toe pose at the marker; authoring FPS alone cannot
prove timing. The new volley clips have source frames 1–49, export 0–0.8 s and
contact at 0.30 s. Preserve existing libraries during a scoped clip addition.

Fast driven crosses need a matching fixed-tick launch and contact forecast;
continuous flight error can move a low contact point by half a metre. Reserve
preparation at the striker's body position behind the intended boot contact,
lead according to flight time minus wind-up, and account for braking distance.
Measure actual marker/tick/ball/toe traces before changing timing or reach.
Half-volleys require a recorded upward ground-contact rebound; inspect normals
in the physics API's reported frame rather than rotating them a second time.
Keep half-volley bounce timing separate from fast volley tick scheduling.
For grounded recovery on uneven turf, compare the ball with the surface under
it. A player root in a shallow rut can otherwise misclassify an adjacent
stationary cross as airborne and reverse the tactical pursuit direction.

Evidence: `games/beechlawn_rovers/docs/art_briefs/advanced_shots_2026_10_23/brief.md`.

### Runtime assets, keeper motion and presentation

For new skill clips, preserve the shipping neutral pose at both endpoints,
but fit contact soles from bind-foot orientation and actual toe offsets. An
idle foot can point sideways or backward; its current toe offset is not a
safe contact target. Solve the crouch before planting either leg and verify
the exported left/right toe positions on the actual actor.

Moving setup forces must damp velocity relative to the carrier. Route them
through the ball's controller arbitration and one-force-per-tick guard, then
recheck the claim at the strike marker. Test a rolling ball at controlled and
jogging speeds alongside stationary contacts. Unfreeze the fixture before
launching a real impulse: a cached velocity assigned while frozen can be
discarded on the first physics-server step. Keep spin and observed physical
velocity in the evidence. BR-020's skill tests and native moving review cover
these cases; full-sprint entries currently require slowing to controlled pace.

For a partial gait edit, compare the imported shipping clip with the Blender
source first. Runtime leg-retarget corrections may be absent from an older
source action. Merge only changed arm tracks and assert untouched leg/root keys
are equal; a moving-but-tiny leg rotation does not prove a useful stride.

For stride edits, measure world-space boot motion while the normal controller
moves the actual player. Define stance from low height and low vertical speed;
the lowest point of a swinging foot alone is insufficient. Author backward
stance travel to cancel carrier speed, lifted recovery and stable foot axes.
Dense 60 Hz baked samples preserve constant stance velocity. Check intermediate
paces for feet sinking below turf when rotations blend; dedicated walk/slow-jog
poses fixed this where idle-to-jog interpolation failed. Normalize gait phase
and scale only the locomotion branch, preserving one-shot action/marker clocks.
Review the whole body too: steady-foot metrics missed stiff walking arms.
Use a gait-specific contralateral swing and neutral wrists. Keep the running
gait through fast deceleration; enter a planted stop only near rest and recheck
resume/interruption. This avoids translating a nearly fixed stop pose.
Immutable merged gait clips can be cached per rig import while each actor keeps
independent AnimationTree state; verify actual staggered poses after sharing.

During a kick preparation touch, velocity damping must follow the carrier.
A fixed close-control target braked a sprinting ball behind the strike foot.
Retain the force cap, ownership arbitration and boot-contact radius. Measure
contact at the physical kick through the existing marker-opened window.
Reuse a heavy match fixture with complete player/ball/input/stamina resets;
reloading all 23 actors for every case hid useful assertions behind a deadline.
Evidence: `games/beechlawn_rovers/docs/art_briefs/br021_stride_2026_10_24/brief.md`.

Keeper motion needs travelling-ball tests after reaction delay. Adapt preparation
to observed arrival time, then restore ordinary follow-through speed. Validate
actual glove reach, whole-body dive/low collision proxy, legal handling, recovery
and collider restoration. A standing body-radius save or frozen contact pose is
insufficient. Held balls should follow the evaluated hands physically, including
gravity compensation; a fixed chest offset can leave a high catch floating away
from the gloves. Rebounds need a lowering/glove contact before a claim.

High-shot saves need separate coverage from slow high crosses. Measure wrist
height in the exported extension pose, then align both that pose and the
physical jump apex with the predicted arrival. Longer flights exposed early
take-off even after short-range saves passed. Preserve the recovery movement
lock while a bounded launch velocity drives real vertical/lateral flight;
verify landing and standing-collider restoration. Keep the anatomical hand
window and reaction delay rather than boosting reach to pass a test.

Test high central, under-bar and both lateral shots on each keeper, including
longer arrivals, unreachable corners, late reaction and over-bar misses. A tip
must physically clear the crossbar. For a short-arrival fixture, use the
physics-calibrated launch and measure its crossing tick: the generic flight
helper clamps duration to 0.35 s and can turn a late shot into a saveable one.
Evidence: `games/beechlawn_rovers/docs/art_briefs/br009_high_shots_2026_10_24/brief.md`.

For full-stretch saves, author low/mid/high silhouettes separately from near-body
reaches. Pair whole-body roll with real sideways flight; a horizontal pose on
a stationary root cannot reach a wide shot. Include side landing, hand brace,
kneel and rise phases rather than reversing the extension directly to idle.
Calibrate take-off and lateral travel from the exported glove positions while
preserving the existing reaction/contact guards. The full-dive add-on leaves
central high tips and near-body actions intact. Measure torso lean in world
space: GLB skeleton-local axes can make an upright pose falsely read as a
90-degree dive. Require bilateral low/mid/high ball contacts, committed travel,
flight, recovery/collider restoration and genuine late/unreachable misses.
Evidence: `games/beechlawn_rovers/docs/art_briefs/br009_dives_2026_10_24/brief.md`.

For pose replays, copy the runtime visual tree without scene reconstruction or
scripts (`duplicate(0)`), freeze animation evaluation and apply recorded bone
poses. Reinstantiating the packed proxy loses individual heads and kit overrides.
Assert mesh/material identity, no physics bodies, no gameplay events, and exactly
one state restore on finish/skip. Check a native view with both team kits.

Run Blender with `--python-exit-code 1` and make dependent shell steps fail fast;
a later successful import/test must never hide a failed asset generation. Helpers
written for child bones may not handle Hips without a parent; use the root bone's
local-to-pose conversion and validate exported full-body joint positions.

## 5. Select verification by change

Run bounded, serial checks with `games/beechlawn_rovers/tools/run_smoke_tests.py`; inspect test fixtures and supported environment switches first. Relevant existing cases include:

| Change | Checks to select |
| --- | --- |
| Startup, shared playback, relaxed poses | `shared_pose_safety_smoke.gd`, `shared_roster_resources_smoke.gd`, `shared_head_roster_smoke.gd` |
| Gait, braking, pivots, reversal | `footballer_animation_tree_smoke.gd`, `football_stop_runtime_smoke.gd`, `shared_pivot_pose_smoke.gd`, `turn_dribble_control_smoke.gd` |
| Stride calibration and shared phase | `stride_plant_smoke.gd`, `braking_gait_smoke.gd`, `shared_gait_integrity_smoke.gd`, `shared_roster_resources_smoke.gd`; native `--review-mode stride_review` / `stride_brake` |
| Marker-gated contact | `football_kick_contact_integration_smoke.gd`, `football_receive_contact_smoke.gd`, `football_shot_contact_integration_smoke.gd`; select the actual 11v11 fixture where supported |
| Keeper contact and recovery | `keeper_live_contact_smoke.gd`, `keeper_diving_high_smoke.gd`, `keeper_high_shots_smoke.gd`, `keeper_full_dive_smoke.gd`, `goalkeeper_outcomes_smoke.gd`; native `--review-mode keeper_high_shots` / `keeper_full_dives` |
| Replay appearance and state | `replay_results_smoke.gd`, native `--review-mode outro` |
| Moving contact and combinations | `moving_kick_contact_smoke.gd`, `first_time_pass_timing_smoke.gd`, `first_time_shot_smoke.gd`, `ai_shot_approach_smoke.gd` |
| Shielding and possession skills | `skill_control_smoke.gd`, `skill_moving_smoke.gd`; native `--review-mode skills` and `skills_moving` |

Sample whole changed clips, not only beginning/middle/end. Use a fixed nine-pose garment sheet as an additional deformation check, then inspect moving close and broadcast playback. Stills and skeleton proxies cannot establish animation smoothness or final-mesh quality. Preserve the main skill's logic/native-appearance/hardware distinction and report unmeasured hardware performance.

Evidence/rationale: `games/beechlawn_rovers/docs/art_briefs/br022_shane_foundation_pass.md`, `br022_shane_body_face_tailored_pass.md`, `pes_motion_control_pass.md`, `pes_chance_gait_followup.md` and `shared_turn_polish.md`.
