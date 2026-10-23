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

Store authored contact markers in the existing metadata contract and verify its clip name, time origin, frame and FPS against the export. Install the Godot event once on an appropriate clip copy. Repeated setup must not add duplicate markers, and cancellation/interruptions must not leave a stale pending action.

The marker signals contact; the fixed-tick gameplay code validates reach and applies the independent ball impulse. Preserve aim/power, input buffering and action-priority behavior. Check no early impulse, exactly one valid impulse, correct cancellation and locomotion recovery. Keep raw ball-physics fixtures separate from marker-gated action tests.

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

Evidence and remaining limitations: `docs/art_briefs/aerial_play_2026_10_22/brief.md`.

## 5. Select verification by change

Run bounded, serial checks with `games/beechlawn_rovers/tools/run_smoke_tests.py`; inspect test fixtures and supported environment switches first. Relevant existing cases include:

| Change | Checks to select |
| --- | --- |
| Startup, shared playback, relaxed poses | `shared_pose_safety_smoke.gd`, `shared_roster_resources_smoke.gd`, `shared_head_roster_smoke.gd` |
| Gait, braking, pivots, reversal | `footballer_animation_tree_smoke.gd`, `football_stop_runtime_smoke.gd`, `shared_pivot_pose_smoke.gd`, `turn_dribble_control_smoke.gd` |
| Marker-gated contact | `football_kick_contact_integration_smoke.gd`, `football_receive_contact_smoke.gd`, `football_shot_contact_integration_smoke.gd`; select the actual 11v11 fixture where supported |
| Moving contact and combinations | `moving_kick_contact_smoke.gd`, `first_time_pass_timing_smoke.gd`, `first_time_shot_smoke.gd`, `ai_shot_approach_smoke.gd` |

Sample whole changed clips, not only beginning/middle/end. Use a fixed nine-pose garment sheet as an additional deformation check, then inspect moving close and broadcast playback. Stills and skeleton proxies cannot establish animation smoothness or final-mesh quality. Preserve the main skill's logic/native-appearance/hardware distinction and report unmeasured hardware performance.

Evidence/rationale: `games/beechlawn_rovers/docs/art_briefs/br022_shane_foundation_pass.md`, `br022_shane_body_face_tailored_pass.md`, `pes_motion_control_pass.md`, `pes_chance_gait_followup.md` and `shared_turn_polish.md`.
