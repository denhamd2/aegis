# BR-021 — stride and foot planting

Item 21 of 27, in progress. Scope: shared gameplay jog, sprint and close-control
footwork, steady-speed cadence and gait blending; preserve current player
identities, kits, body/rig, all football contact markers and keeper/skill clips.
Use original/free animation through create-player, Blender animation/rigging
and Godot export guidance. The archived character/kit sheets establish body
proportions; the original broadcast reference establishes gameplay readability.

The real 11v11 Shane fixture measures boots in world space while the normal
CharacterBody controller moves at 3, 6 and 8.6 m/s. The baseline low-boot
samples slide at roughly 3.0/6.1/8.3 m/s. The small source foot arcs lack a
rearward stance segment matched to world travel; motion alone did not establish
planting. Jog/sprint also have different cycle lengths in the current blend.

Author normalized, phase-aligned footwork loops on the unchanged shared rig,
with a backward stance segment, lifted recovery, correct foot orientation,
anatomical limb lengths and restrained pelvis motion. Runtime cadence scales
only the locomotion branch, keeping pass/shot/receive/skill timing authoritative
and unchanged. Preserve unrelated pose content while matching the arm swing
to the gait phase.

## Implementation and measured results

Five original 60 Hz normalized loops now cover walk, slow jog, jog, sprint and
close control. Each has an explicit backward stance segment, lifted recovery,
ankle pitch and restrained pelvis motion/lean. Runtime locomotion cadence and
phase are shared across the active gait blends; action AnimationPlayer timing
stays separate. The first native pass exposed stiff walking arms inherited
from jogging. All five gaits now have original contralateral arm motion,
relaxed low hands for walking, bent running elbows and neutral wrist alignment.
Existing spine/head/finger pose content remains, retimed by phase.
The source body's meshes, rest transforms, heads, kits and other motion exports
remain untouched.

The first idle-to-jog blend still drove boots below the turf. Walk and slow-jog
blend points resolved this. The final seven steady cases (1.5, 3, 4.5, 6, 7.3,
8.6 m/s and actual keyboard close control at 3.36 m/s) measure 0.023–0.104 m/s
mean low/flat-foot slip, with minimum toe-joint heights of 0.032–0.045 m.
These are toe-joint measurements, not boot-sole clearance. Baseline comparable
cases moved with the root at roughly 3/6/8 m/s. Whole-body and turning visual
acceptance remains distinct from this straight-line stance measurement.

The moving-contact fixture also exposed setup touches damping a fast ball
toward fixed close-control speed. Kick preparation now damps velocity relative
to the carrier, within the existing force/ownership/contact bounds. A real
physical boot strike is still required. All thirteen human/AI stationary,
jogging and sprinting pass/shot cases pass; the off-axis ball cannot be struck.
Marker timing and the 0.28 m gameplay contact radius are unchanged.

The fixture now loads one 11v11 match, resets cases fully and observes the
existing contact window. Repeated full-scene construction dominated the old
45 s timeout; the complete test now takes about 15 s without raising its
deadline. Final-human/proxy gait assembly separately caches immutable clips,
with independent actor playback checked at different phases.

Fast braking also entered the planted stop clip too early. The new real-sprint
regression reproduced 21 fast-deceleration ticks without the running gait.
The gait now continues above the 2.6 m/s stop-entry threshold; at default
braking this leaves about 0.23 m for the final planted weight shift. Root
acceleration/braking and input response are unchanged. The original stop/resume,
turn and moving-contact checks pass after this adjustment.

## Native evidence and limits

[Motion review](native/stride_review.mp4) and
[jogging still](native/match_broadcast.png).

The real 11v11 scene contains 22 players and one referee. The moving review
selects Shane by roster ID, parks unrelated actors and follows him at pitch
height. The 30 fps video shows walking, slow jogging, jogging, sprinting,
keyboard close control, then acceleration/sprinting/braking. It uses gait
frames 0–299 from `native/` followed by corrected braking frames 0–59 from
`native_brake/`; `video_frames.json` records the exact order. Both sequences
use 60 Hz physics, two ticks per sampled draw, with no playback-speed changes.
The main sequence's retained final block records the pre-fix stop for comparison.
Selected earlier visual-review frames are retained in `native_first_probe/`.

Godot 4.6.3 Forward+/Vulkan, Xvfb, llvmpipe software GPU, 640×360. Native
appearance and measured stance improve, but M1 appearance, input feel and
1080p60 still need the Mac. Existing headless ObjectDB/resource shutdown
warnings remain. The current Mac download has not been rebuilt with this pass.

The source/export audit preserves all 65 bone rest transforms and 28 protected
body/head/motion sources/exports. New source:
`tools/blender/beechlawn/author_stride_gaits.py`, `football_stride_gaits.blend`;
runtime add-on: `assets/characters/shared/stride_gaits.glb`. No meshes, kits or
head sculpts are changed. BR-021 remains in progress for broader turn/start/
intro footwork and native Mac acceptance. Full-match metrics are recorded in
`ai_chances/summary.json` and the final validation record.

## Final match gate and next action

All six full matches pass the unchanged chance gate: 26/42 physical shots,
38.2%/61.8% aggregate share, with both sides qualifying in 6/6 and creating
contested attempts in every fixture. The home-0 case is 2/13 shots, so
fixture-by-fixture tactical balance and cross-machine/human acceptance remain
open under BR-008. No quotas, attribute changes or keeper nerfs were introduced.

Thirteen motion/contact/shared-resource/skill/keeper checks pass on the refined
gaits; four final stop/turn/contact checks pass after the braking adjustment.
That is fourteen unique smoke checks. The bounded moving-contact fixture now
finishes in about 13–15 s, including all thirteen real strike/miss cases.

Next: BR-025 (25/27, in progress), commit/package the tested work into a fresh
universal Mac build and validate the combined movement and keeper changes on
hardware. This pass has not rebuilt the current download.

Acceptance: reduced measured planted-foot slip at multiple speeds, phase-safe
gait transitions, natural native full-body movement and the existing live-ball
contact/turn/stop/skill/keeper checks. Preserve source/export hashes for unrelated
assets. Target Mac appearance, feel and 1080p60 remain separate hardware gates.

Before/after traces, source/export audits and native moving evidence are stored
beside this brief. Remaining BR-021 motion work stays explicit after this pass.
