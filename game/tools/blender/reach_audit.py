"""Finds pose targets the rig physically cannot reach, and the shoulder
geometry that decides how far a punch can extend.

    python3 game/tools/blender/reach_audit.py
    python3 game/tools/blender/reach_audit.py --sweep

Why this exists
---------------
`rig_pose.RigPoser` expresses a pose as where the hands and feet are, in
metres, and solves the joints that put them there. That is what makes a pose
checkable -- but `_two_bone_ik` clamps its target to `(l1 + l2) * 0.995` and
then solves along the direction, so a target further than the limb can reach
is not rejected, it is quietly truncated. The pose table keeps its number and
the clip does something else.

Nothing said when that happened, and it happened a lot. Measured across the 29
clips in wrestling_clips.py, 171 of 640 limb targets -- 27% -- were beyond the
limb's reach.

The worst of it was the jab. Its contact pose asked for the left hand 0.685 m
from a shoulder with 0.544 m of arm, and the truncation ate almost the whole
forward component: the punch travelled 7 cm and peaked six ticks after the
frame strike_jab.tres applies damage on. Meanwhile the cross, whose every
target sits inside the reach sphere, measured perfectly through the identical
code path -- which is how the diagnosis was confirmed rather than guessed.

The shoulder, and why the jab's twist was backwards
--------------------------------------------------
`--sweep` reports where the left shoulder sits as the spine twists, because
"beyond reach" is only half the story: a punch's reach depends on where the
shoulder is when it is thrown, and the jab's torso was rotating the wrong way.

    spine yaw -16 -> left shoulder fwd -0.106, fist can reach 0.422
    spine yaw   0 -> fwd -0.036, reach 0.492
    spine yaw +28 -> fwd +0.116, reach 0.644
    spine yaw +28, clavicle protracted +20 -> fwd +0.189, reach 0.717

Negative yaw drives the RIGHT shoulder forward. The jab -- a LEFT hand -- was
authored at -16, so the torso rotated away from the arm throwing the punch and
put its own shoulder behind the body's origin.
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import wrestling_clips as WC  # noqa: E402
from rig_pose import RigPoser, vec  # noqa: E402

# Pose key -> the two-bone chain that solves it. `_two_bone_ik` plants the
# LOWER bone's tail on the target, so that tail is where the target landed.
CHAINS = {
    "hand_r": ("upperarm_r", "lowerarm_r"),
    "hand_l": ("upperarm_l", "lowerarm_l"),
    "foot_r": ("thigh_r", "calf_r"),
    "foot_l": ("thigh_l", "calf_l"),
}

# Targets closer than this to the reach limit are reported as tight rather
# than broken: the solver stays inside its clamp, but there is no room left.
TIGHT_MARGIN = 0.02


def _load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=WC.RIG)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    return arm, RigPoser(arm)


def audit():
    arm, poser = _load()
    rows = []
    for clip, keys in WC.CLIPS.items():
        for frame, p in keys:
            poser.apply(p)
            for key, (upper, lower) in CHAINS.items():
                if key not in p:
                    continue
                span = (arm.data.bones[upper].length
                        + arm.data.bones[lower].length) * 0.995
                root = poser.bone_head(upper)
                need = (vec(*p[key]) - root).length
                rows.append((need - span, clip, frame, key, p[key], need, span))

    over = sorted((r for r in rows if r[0] > 0.0), key=lambda r: -r[0])
    tight = [r for r in rows if -TIGHT_MARGIN < r[0] <= 0.0]

    print("limb targets: %d total, %d beyond reach, %d within %.0f cm of the limit"
          % (len(rows), len(over), len(tight), TIGHT_MARGIN * 100))
    if over:
        print("\nBEYOND REACH -- the solver truncates these, silently:")
        for excess, clip, frame, key, want, need, span in over:
            print("  short %5.3fm  %-22s f%-3d %-7s want=%-24s need %.3f > reach %.3f"
                  % (excess, clip, frame, key, str(tuple(want)), need, span))
    return len(over)


def sweep():
    """Where the left shoulder goes as the torso twists, and how far the fist
    can then reach. Reproduces the table in this file's docstring."""
    arm, poser = _load()
    span = (arm.data.bones["upperarm_l"].length
            + arm.data.bones["lowerarm_l"].length) * 0.995
    base = dict(
        pelvis=(-0.02, 0.06, 0.862), hips=(4, -14, 0), spine=(11, -16, 0),
        head=(-2, -6, 0), hand_l=(-0.06, 0.56, 1.40), hand_r=(0.19, 0.28, 1.28),
        foot_l=(-0.19, 0.18, 0.104), foot_r=(0.23, -0.17, 0.112),
    )

    def shoulder(pose):
        poser.apply(pose)
        s = poser.bone_head("upperarm_l")
        # vec() maps readable right/fwd/up onto -x/-y/z, so read it back.
        return (-s.x, -s.y, s.z)

    print("arm reach (0.995 of full) = %.3f m" % span)
    print("\nspine twist, hips following at half:")
    for yaw in (-16, -8, 0, 8, 16, 24, 28, 32, 40):
        p = WC.P(**{**base, "spine": (11, yaw, 0), "hips": (4, yaw / 2.0, 0)})
        _, fwd, up = shoulder(p)
        print("   yaw %+4d -> left shoulder fwd %+0.3f up %.3f   fist reaches %.3f"
              % (yaw, fwd, up, fwd + span * 0.97))
    print("\nclavicle protraction at yaw +28:")
    for clav in (-20, -10, 0, 10, 20, 30):
        p = WC.P(**{**base, "spine": (11, 28, 0), "hips": (4, 14, 0),
                    "clav_l": (0, clav, 0)})
        _, fwd, up = shoulder(p)
        print("   clav_l yaw %+4d -> fwd %+0.3f up %.3f   fist reaches %.3f"
              % (clav, fwd, up, fwd + span * 0.97))


if __name__ == "__main__":
    if "--sweep" in sys.argv:
        sweep()
        sys.exit(0)
    sys.exit(1 if audit() else 0)
