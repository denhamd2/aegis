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
The clips remain blocking studies: rendered review showed they need more pose
and foot-contact polish before replacing the match's primitive fallback.
Horizontal movement, tackle contact, and ball response remain under Godot
authority; only small vertical pelvis motion is animated in place.

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
track, and an optional `FootballerVisual` child on `FootballPlayer` defers the
physical pass impulse until the event fires. Without that visual, the existing
primitive-player path retains its immediate kick behavior. The event integration
has a headless kickoff smoke test; it does not yet prove contact alignment on
the final human mesh or replace the default match-scene blockout.

The kickoff test also samples `mixamorig_RightToe_End` from the evaluated Godot
skeleton at the event frame and compares it with the live ball. That check found
an axis-sign error in the first Blender pass: the toe travelled away from the
center ball and was 1.14 m away at contact. The Blender source now drives the
instep forward; the corrected toe tip is 0.092 m away in the ground plane and
0.026 m above the ball center at 0.4 s (0.095 m total). The test verifies the
toe tip stays within 0.14 m of the ball center and still checks that exactly one
independent physical ball impulse occurs. This fits the current simplified boot
and 0.22 m ball; recheck it against the final boot mesh and its actual contact
surface.

The CMU take was used only as a timing/arc reference. A direct BVH retarget
failed its pose review due to rest-pose and bone-axis mismatch, so no CMU-derived
motion is included in the export. The new clip remains a mannequin blocking
pass, not a final footballer animation. Godot event synchronization and
AnimationTree resumption are verified for the proxy; contact height/alignment
on the final human mesh and live 4v4 play validation are still outstanding.

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
3. Rename reviewed clips `AN_Idle`, `AN_Walk`, `AN_Jog`, and `AN_Run`; preserve
   discrete pass and shot clips for future contact-marker hookup.
4. Export a GLB animation library and verify the imported AnimationPlayer,
   AnimationTree transitions, playback speed, and looping in Godot.
5. Test one actor at the broadcast camera before replacing the match-scene
   blockout; only then repeat the same rig for the first 4v4 slice.

The Mixamo robot shell remains a rig/animation proxy. The visual target is a
human Beechlawn player based on the supplied character sheets.
