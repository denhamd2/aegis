# Load contact read-only checkpoint

Source candidate3 remains frozen. Runtime height-policy ablations are owned by
main/architect; no new source hand/arm targets were authored here.

## Source and runtime are different stages

At authored43 the original attacker uses pelvis(height.680), hips−30/spine−30,
wrists(.18,.60,.92) and(−.16,.58,.90), elbow poles(.8,−.4,−.4) and mirrored.
At48 he extends hips/chest into the lift, wrists(.18,.48,1.14) and
(−.16,.46,1.12). These are source right/forward/up targets, not measured drawn
world positions on Cody/Roman.

Runtime PairedContacts family is waist: both targets are opponent pelvis plus
7cm far-side wrap and±15cm lateral. WrestlerController._aim_grip_targets clamps
those to each shoulder reach. SkeletonIK3D then applies that hold AFTER the
animation; _build_ik_rig configures no explicit magnet/pole. Thus source elbows
and source wrist coordinates alone do not establish the drawn wrap.

PairClearance._points currently obtains body/arm endpoints with
get_bone_global_pose outside skeleton_updated. Controller docs specifically
warn that pre-modifier reads can miss grip IK. The same clearance measure uses
an inside-skeleton_updated callback for its drawn HANDS/grip metric, so raw arm
penetration and drawn hand contact need not describe the same pose stage.
Confirm post-IK shoulder/elbow/wrist endpoints before treating an arm number as
an authored-motion defect. Architect independently raised this issue.

## Reference limits / phase hypothesis

The actual saved230.23/230.48/230.65 panels were inspected (crop for convenient
review:/tmp/aegis-running-load-reference-panels.png). At230.48 Kenny has one arm
wide/back; by230.65 he wraps the upper-body/shoulder area. These frames do not
prove constant two-hands-at-pelvis contact throughout load43–47. The original
catch comment also describes waist plus arm contact before the load. A phased
hold/target or source-asymmetry issue is plausible, not established from these
small frames. Do not blindly move hands, disable pull, widen contact limits or
claim the no-pull three-in-reach sample is a passing hold.

## Required next evidence

Capture same-clock44–48 raw AND post-modifier upperarm/elbow/wrist capsules for
both roles, actual unclamped contact targets plus clamped targets/reach, and
both model separation vectors. Inspect a matched close/side image at46 with
both bodies. If the high raw overlap disappears in the drawn pose, repair the
measurement/solver-stage assumptions before authoring another arm pose. If it
remains, distinguish wrong target/phase from wrong elbow path and scope the
actual failing stage. No full-move quality or10/10 claim is made.
