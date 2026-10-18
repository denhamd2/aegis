# Mixamo clips for the Beechlawn prototype

## Current state

The Y-Bot rig is imported and validated in Godot, but its supplied FBX has no
usable motion; it contains only a one-frame pose action. The remote build
workspace cannot access the Adobe sign-in or download session in the owner's
browser. The character asset itself is already in
`assets/characters/mixamo/`.

Original blocking clips have been authored on the same 65-bone rig with
Blender: `AN_Beechlawn_Idle`, `AN_Beechlawn_Jog`,
`AN_Beechlawn_Sprint`, `AN_Beechlawn_SlideTackle`, and
`AN_Beechlawn_ShoulderImpactSell`. The repeatable source is
`tools/blender/beechlawn/author_defensive_clips.py`; the editable result is
`tools/blender/beechlawn/y_bot_animation_set.blend`, and the Godot-importable
proxy GLB is `assets/characters/mixamo/y_bot_animation_set.glb`. A reusable
scene at `scenes/footballer_visual.tscn` blends idle, jog, and sprint with a
one-dimensional AnimationTree. Import, blend-space, and playback checks pass.
The clips remain blocking studies: they now drive the actual 4v4 actors, but
still need pose and foot-contact polish. A separately callable prone get-up is
now included; it is not triggered until a grounded/downed gameplay state is
implemented. Review of the existing slide-tackle action found that it stays
upright with arms spread, so it is not a suitable fall pose. The segmented Y-Bot body is only a
rig/motion proxy, not a human footballer base. Horizontal movement, tackle
contact, and ball response remain under Godot authority; only small vertical
pelvis motion is animated in place.

## Original right-foot pass/contact study

`tools/blender/author_football_kick.py` authors a short, in-place right-foot
instep-pass proxy on the same Y-Bot rig. It is sampled at 60 fps across 54
frames (0.9 s) and exported with the existing locomotion and defensive clips
as `assets/characters/mixamo/y_bot_animation_library.glb`, with the action
`AN_Beechlawn_PassRight`. Its phases are support-foot plant and load, backswing,
drive, contact at frame 24 (0.4 s), follow-through, and recovery. Temporary
foot and hand IK constraints are baked into ordinary bone curves and removed;
the scene contains no runtime IK or root motion. The export samples the older
30 fps clips at 60 fps while preserving their duration. A static ball-and-pose
review is available at [the contact sheet](images/y_bot_pass_contact_sheet.png).

The Blender source also writes
`assets/characters/mixamo/y_bot_pass_contact.json` from the frame-24 timeline
marker. `FootballerVisual` adds that event as a Godot AnimationPlayer method
track, and the match-scene `FootballerVisual` on each `FootballPlayer` defers
the physical pass impulse until the event fires. The event test measures the
actual match-scene toe within 5.7 cm of the ball at contact. It does not yet
prove alignment on the final human mesh or boot.

The kickoff test also samples `mixamorig_RightToe_End` from the evaluated Godot
skeleton at the event frame and compares it with the live ball. That check found
an axis-sign error in the first Blender pass: the toe travelled away from the
center ball and was 1.14 m away at contact. The Blender source now drives the
instep forward; the corrected toe tip is 0.092 m away in the ground plane and
0.026 m above the ball center at 0.4 s (0.095 m total) before the visual-axis
correction. With the corrected 180-degree rig orientation, the toe tip now
measures 0.057 m from ball center, and the integration test verifies it stays
within 0.14 m while checking that exactly one independent physical impulse
occurs. Recheck this against the final boot mesh and its actual contact surface.

## Original first-touch receive

`tools/blender/author_football_receive.py` authors the in-place
`AN_Beechlawn_ReceiveRight` action on the same rig. It lasts 42 frames at 60 fps
(0.7 s), with a cushioned right-foot contact marker at frame 20 (0.333 s). The
support leg stays planted while the receiving foot reaches, absorbs the ball,
and returns to a balanced stance. IK is temporary in Blender and baked into the
clip; there is no runtime IK or root translation. The shared visual exposes
`play_receive()` and restores its locomotion tree when the clip ends.

The Godot receive contact smoke test places an incoming ball in front of the
player and measures the evaluated `mixamorig_RightToe_End` at the event. The
toe tip is 12.3 cm from the ball center, roughly 1.3 cm beyond the 11 cm ball
radius, and the action completes with locomotion restored. The pose sheet shows the ready, contact, and recovery beats in
[the proxy render](images/y_bot_receive_pose_sheet.png). Reviewing its facing
revealed Y-Bot's imported forward axis opposed the game actor's attack axis, so
`footballer_visual.tscn` rotates the rig 180 degrees locally. Pass and receive
contact tests now both use that same orientation. The match controller now
automatically starts the receive clip for an intended incoming pass and applies
a short physical cushion at its marker; it does not attach or reposition the
ball.

## Braking and relaxed idle

The imported Y-Bot idle action left its arms in the source T-pose. The repeatable
script `tools/blender/author_football_stop.py` corrects the existing idle pose
using temporary hand IK, then bakes the result into the shared 65-bone action.
It also authors `AN_Beechlawn_StopFromRun`, a 36-frame/60 Hz braking clip with
the support foot planted through its 0.233 s brake pose and a settle matching the
relaxed idle. All constraints are removed before saving/export; Godot adds no
runtime IK. `FootballerVisual` triggers the stop when movement intent releases
while speed is above 0.8 m/s, and interrupts it if movement resumes above
1.2 m/s. The animation-tree smoke test checks the relaxed idle arm, stop action,
resume interruption, and return to locomotion. Blender pose sheets are in
`docs/art_briefs/br003_idle_pose_sheet.png` and
`docs/art_briefs/br003_stop_pose_sheet.png`. These remain proxy blocking poses;
close review with the final human player mesh and the M1 game build is pending.

## Prone recovery

`tools/blender/author_football_getup.py` authors
`AN_Beechlawn_GetUpFromProne` as a 55-frame/60 Hz (0.9 s) in-place transition.
It starts with the chest and hands supported near the ground, shifts through a
tucked knee and half-kneel, then drives back into a ready stance. Blender hand
and foot IK is temporary and baked into the action; the armature object has no
root motion. The proxy sequence is in
[`the get-up pose sheet`](images/y_bot_getup_pose_sheet.png). Godot exposes
`FootballerVisual.play_get_up()` and tests that the action returns to the
locomotion tree. `AN_Beechlawn_GroundedSlideTackle` now settles on the same
prone pose, and the visual driver chains into get-up automatically at the end
of the committed slide clip. The slide window and ball-contact time remain
owned by `FootballPlayer`; the in-place animations do not determine gameplay
movement. The action pair is currently invoked by a valid slide tackle, while
final-mesh ground contact and match-scene contact alignment remain to be
verified.

To rebuild the combined asset library from the original animation-set source,
run `author_football_kick.py` first, then `author_football_receive.py`; the kick
script recreates its source library before the receive script appends its clip.

The CMU take was used only as a timing/arc reference. A direct BVH retarget
failed its pose review due to rest-pose and bone-axis mismatch, so no CMU-derived
motion is included in the export. The pass and receive clips remain mannequin
blocking studies, not final footballer animations. Godot event synchronization
and AnimationTree resumption are verified on the proxy in the 4v4 scene; contact
alignment on the final human mesh and a close visual review of match play remain
outstanding.

## First clips to bring in

Use the same Y-Bot character for each download so Mixamo keeps its skeleton
consistent. Download a small locomotion set first:

- Idle
- Walk
- Jog or Run
- Sprint/Run (if the library has a distinct faster cycle)

For locomotion, choose **FBX Binary**, **Without Skin**, **30 FPS**, and enable
**In Place**. Keep the downloaded FBXs together in a ZIP and attach it to the
project conversation. This avoids duplicating the mesh and allows the clips to
be checked against the exact supplied skeleton before export. Then add suitable
pass and shot/kick clips if Mixamo's library has motions that survive review;
generic kicks are only placeholders for football-specific contacts.

## Freely usable football motion study

The CMU Graphics Lab database includes soccer-ball kick takes for subject 10
and subject 11. Subject 10, take 03 is archived under
`references/animation_sources/cmu/subject_10_03/`, with its source, timing, and
use terms recorded in the adjacent README. CMU's terms permit use of its
original data, including in commercial products, while prohibiting resale of
the data itself. The GitHub mirror adds no restrictions.

I imported the 120 Hz BVH into Blender 4.3.2 and attempted a 60 Hz retarget to
the Y-Bot proxy. The first retarget render showed serious pose distortion from
the BVH/Y-Bot bone-axis and rest-pose differences, so that derived clip was
discarded and is not part of the runtime animation set. Keep the CMU capture as
a licensed motion reference until a proper rest-pose-aware retarget pass is
validated. Do not treat this raw capture as a drop-in game animation.

## Blender and Godot checks after clips arrive

1. Compare bone names, hierarchy, and rest pose against `y_bot_source.blend`.
2. Reject clips with missing/renamed bones, unintended root translation, or
   large foot drift during an in-place cycle.
3. Rename reviewed clips `AN_Idle`, `AN_Walk`, `AN_Jog`, and `AN_Run`; keep
   discrete pass, receive, and shot clips separate from the locomotion blend.
4. Export a GLB animation library and verify the imported AnimationPlayer,
   AnimationTree transitions, playback speed, and looping in Godot.
5. For every ball-action clip, store an explicit Blender contact frame in a
   sidecar manifest and apply ball impulses from a Godot animation event at
   that frame. Validate toe-to-ball distance and one-shot impulse behavior in
   the match scene.
6. Test one actor at the broadcast camera before replacing the match-scene
   blockout; only then repeat the same rig for the first 4v4 slice.

The Mixamo robot shell remains a rig/animation proxy. The visual target is a
human Beechlawn player based on the supplied character sheets.
