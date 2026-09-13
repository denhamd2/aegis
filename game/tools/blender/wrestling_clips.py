"""Authors wrestling animation clips on the CC0 base rig and exports them
as a glTF animation library.

Run with the bpy module (no Blender application required):

    python3 game/tools/blender/wrestling_clips.py

Why this exists
---------------
Every clip the game plays today is *sampled* out of the 42 actions that ship
on wrestler_base.glb, by resources/animations/strike_recipes.gd and
paired_recipes.gd. That library is a generic CC0 character set -- Pistol_*,
Sword_*, Spell_*, Swim_*, Sitting_*, Walk/Jog/Sprint, Death01 -- and it
contains no wrestling whatsoever. Sampling can only recombine poses that
already exist, so a bump, a lock-up, a cover or a celebration has to be
approximated from Push, PickUp_Table, Jump_* and Death01. That ceiling is
why resources/animations/paired_recipes.gd reads the way it does, and why a
win reaction could not be built at all.

This module authors poses directly on the armature instead, so a pose that
is not in the source library is simply keyframed.

Output is deterministic: the same input table produces a byte-identical glb,
which is what lets it be committed and diffed like the .tres bakes.
"""

import math
import os
import sys

import bpy
import mathutils

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RIG = os.path.join(REPO, "assets", "characters", "wrestler_base.glb")
OUT = os.path.join(REPO, "assets", "animations", "wrestling_clips.glb")

# Authored at 30 fps: the project's physics runs at 60, so every frame lands
# on a whole tick and nothing has to be resampled on import.
FPS = 30


def load_rig():
    """Fresh scene with just the base rig's armature in it."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=RIG)
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if len(arms) != 1:
        raise SystemExit("expected exactly one armature, got %d" % len(arms))
    bpy.context.scene.render.fps = FPS
    return arms[0]


def clear_actions():
    """Drop the 42 source actions so only authored ones are exported."""
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)


def drop_mesh():
    """Export the skeleton and its clips, not the body.

    The rig's mesh is ~680 KB of the glb and is already shipped by
    wrestler_base.glb and each roster model; carrying a second copy here
    just to hold animation would bloat the repo for nothing. The existing
    animation-only assets (assets/animations/motifect_*.glb) are ~80 KB for
    the same reason.
    """
    for obj in list(bpy.data.objects):
        if obj.type != "ARMATURE":
            bpy.data.objects.remove(obj, do_unlink=True)


def local_rot(arm, bone_name, rx, ry, rz):
    """Armature-space Euler degrees -> that bone's local rotation quaternion.

    Authoring directly in a bone's own space does not survive mirroring: a
    left and right upperarm have opposite local axes, so the same local X on
    both swung one arm down and left the other at rest (rendered, first pass).
    Armature space has no such ambiguity -- Z is up, the character faces -Y --
    so a pose reads the same for both sides and the conversion handles the
    mirror.

    rest^-1 @ R @ rest re-expresses the armature-space rotation R in the
    bone's local frame. Parent rotations still compound, which is what we
    want: a twisting spine should carry the arms with it.
    """
    rest = arm.data.bones[bone_name].matrix_local.to_3x3()
    R = mathutils.Euler(
        (math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ"
    ).to_matrix()
    return (rest.inverted() @ R @ rest).to_quaternion()


def author(arm, name, poses):
    """Keyframe one action from a list of (frame, {bone: (rx, ry, rz)}) poses.

    Rotations are Euler degrees in ARMATURE space -- see local_rot().
    """
    action = bpy.data.actions.new(name)
    arm.animation_data_clear()
    arm.animation_data_create()
    arm.animation_data.action = action

    for bone in arm.pose.bones:
        bone.rotation_mode = "QUATERNION"

    touched = sorted({b for _, pose in poses for b in pose})
    for frame, pose in poses:
        for bone_name in touched:
            pb = arm.pose.bones.get(bone_name)
            if pb is None:
                raise SystemExit("%s: no bone %r on the rig" % (name, bone_name))
            rx, ry, rz = pose.get(bone_name, (0.0, 0.0, 0.0))
            pb.rotation_quaternion = local_rot(arm, bone_name, rx, ry, rz)
            pb.keyframe_insert("rotation_quaternion", frame=frame)
    return action


def export(path):
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_apply=False,
        # Determinism: no timestamps, no generator string churn.
        export_yup=True,
    )


# --- Authored clips -------------------------------------------------------
#
# Poses are Euler degrees in ARMATURE space: Z is up, X is the left-right
# axis, and the character faces -Y. local_rot() re-expresses each one in the
# bone's own frame, so a value means the same thing on a left bone as on its
# mirrored right one.
#
# Derived from the rest pose (a T-pose: upperarm_* lies along +/-X, spine
# along +Z, thigh along -Z), not guessed:
#
#   upperarm_r.Y   + raises the arm, - lowers it       (mirror: upperarm_l.Y)
#   lowerarm_r.Z   + bends the elbow forward           (mirror: lowerarm_l.Z)
#   spine_03.X     + leans the chest forward, - arches it back
#   spine_03.Z     + drives the RIGHT shoulder forward (the twist a worked
#                  strike gets its weight from; Punch_Cross uses the same
#                  rotation, running 0 -> 29 deg -> 0 through its cross)
#   Head.X         + drops the chin, - lifts it
#
# Timing is in frames at FPS (30), so every frame lands on a whole 60 Hz tick.

ARM_DOWN = 78.0   # |upperarm_*.Y| that hangs the arm by the side from T-pose

CLIPS = {
    # Task #97. Blocked until now because no celebration exists anywhere in
    # the 42 source actions -- it cannot be sampled, only authored.
    #
    # Blocked as anticipation -> explosion -> settle, per the animation
    # skill's pass order: the dip at f5 is what sells the thrust at f14.
    # Without it the arms simply translate upward and read as a lift, not a
    # celebration.
    "Win_Celebrate": [
        (1,  {"upperarm_r": (0, -ARM_DOWN, 0), "upperarm_l": (0, ARM_DOWN, 0),
              "lowerarm_r": (0, 0, 16),  "lowerarm_l": (0, 0, -16),
              "spine_03":   (5, 0, 0),   "Head": (0, 0, 0)}),
        # Anticipation: chin drops, arms load down, chest closes.
        (5,  {"upperarm_r": (0, -90, 0), "upperarm_l": (0, 90, 0),
              "lowerarm_r": (0, 0, 24),  "lowerarm_l": (0, 0, -24),
              "spine_03":   (13, 0, 0),  "Head": (11, 0, 0)}),
        # Explosion: arms overhead and slightly open, chest out, head up.
        (14, {"upperarm_r": (0, 72, 0),  "upperarm_l": (0, -72, 0),
              "lowerarm_r": (0, 0, 18),  "lowerarm_l": (0, 0, -18),
              "spine_03":   (-12, 0, 0), "Head": (-18, 0, 0)}),
        # Overshoot settles back rather than stopping dead on the extreme.
        (22, {"upperarm_r": (0, 62, 0),  "upperarm_l": (0, -62, 0),
              "lowerarm_r": (0, 0, 22),  "lowerarm_l": (0, 0, -22),
              "spine_03":   (-8, 0, 0),  "Head": (-14, 0, 0)}),
        (39, {"upperarm_r": (0, 65, 0),  "upperarm_l": (0, -65, 0),
              "lowerarm_r": (0, 0, 20),  "lowerarm_l": (0, 0, -20),
              "spine_03":   (-9, 0, 0),  "Head": (-15, 0, 0)}),
    ],

    # The striking half of the impact pair: a right forearm. Contact is on
    # f9 so the receiving clip below can be lined up against it.
    # The striking half of the impact pair: a right forearm. Contact is on
    # f9 so the receiving clip below can be lined up against it.
    #
    # The reach is upperarm_r.Z, NOT .Y -- measured on the rest pose, +30 deg
    # about armature Z takes the right arm to (-0.87,-0.49,0), i.e. forward,
    # while Y only raises and lowers it at the side. A first pass used Y
    # alone and rendered as a man standing with his arms hanging: the strike
    # never travelled toward anything.
    #
    # Child rotations compound on the parent's, so lowerarm_r.Z is a bend ON
    # TOP of whatever the upper arm is already doing -- the guard values look
    # smaller than the elbow angle they produce.
    # The striking half of the impact pair: a right forearm. Contact is on
    # f9 so the receiving clip below can be lined up against it.
    #
    # Two things were measured rather than guessed, both off the rest pose
    # and both wrong on a first pass:
    #
    # .Z is the REACH. +30 deg about armature Z takes the right arm to
    # (-0.87,-0.49,0) -- forward. .Y only raises and lowers it at the side,
    # and a version using Y alone rendered as a man standing with his arms
    # hanging: the strike never travelled toward anything.
    #
    # .Y is the HEIGHT, and it has to stay shallow. At Y=-45 the exported
    # clip put the arm at (-0.04,-0.57,-0.82) on the contact frame -- 55 deg
    # below horizontal, a forearm aimed at the opponent's knees. Contact
    # wants roughly -15.
    #
    # Child rotations compound on the parent's, so lowerarm_r.Z is a bend ON
    # TOP of whatever the upper arm is already doing.
    "Strike_Forearm": [
        # Guard: elbow bent, hands up, arm carried slightly forward.
        (1,  {"upperarm_r": (0, -45, 15), "lowerarm_r": (0, 0, 85),
              "upperarm_l": (0, 48, -15), "lowerarm_l": (0, 0, -85),
              "spine_03":   (8, 0, 0),    "Head": (0, 0, 0)}),
        # Wind-up: the right shoulder pulls BACK and the elbow loads deeper.
        (5,  {"upperarm_r": (0, -40, -15), "lowerarm_r": (0, 0, 100),
              "upperarm_l": (0, 52, -22),  "lowerarm_l": (0, 0, -88),
              "spine_03":   (10, 0, -26),  "Head": (0, 0, -12)}),
        # Contact: torso twist drives through and the arm extends across at
        # chest height. The power reads from spine_03.Z, not the arm alone.
        (9,  {"upperarm_r": (0, -15, 70), "lowerarm_r": (0, 0, 10),
              "upperarm_l": (0, 58, -12), "lowerarm_l": (0, 0, -70),
              "spine_03":   (10, 0, 30),  "Head": (0, 0, 16)}),
        # Follow-through PAST contact, not a stop at it.
        (13, {"upperarm_r": (0, -14, 82), "lowerarm_r": (0, 0, 20),
              "upperarm_l": (0, 60, -10), "lowerarm_l": (0, 0, -72),
              "spine_03":   (11, 0, 24),  "Head": (0, 0, 11)}),
        (24, {"upperarm_r": (0, -45, 15), "lowerarm_r": (0, 0, 85),
              "upperarm_l": (0, 48, -15), "lowerarm_l": (0, 0, -85),
              "spine_03":   (8, 0, 0),    "Head": (0, 0, 0)}),
    ],

    "Hit_React_Head": [
        (1,  {"Head": (0, 0, 0), "neck_01": (0, 0, 0), "spine_03": (7, 0, 0),
              "upperarm_r": (0, -62, 20), "upperarm_l": (0, 64, -20),
              "lowerarm_r": (0, 0, 48), "lowerarm_l": (0, 0, -48)}),
        # Impact.
        (3,  {"Head": (-20, 0, -18), "neck_01": (-9, 0, -8), "spine_03": (0, 0, -9),
              "upperarm_r": (0, -70, 0), "upperarm_l": (0, 72, 0),
              "lowerarm_r": (0, 0, 32), "lowerarm_l": (0, 0, -30)}),
        # Torso catches up a beat later.
        (8,  {"Head": (-14, 0, -26), "neck_01": (-7, 0, -13), "spine_03": (-12, 0, -17),
              "upperarm_r": (0, -62, 0), "upperarm_l": (0, 64, 0),
              "lowerarm_r": (0, 0, 42), "lowerarm_l": (0, 0, -40)}),
        (16, {"Head": (-5, 0, -9), "neck_01": (-2, 0, -4), "spine_03": (3, 0, -5),
              "upperarm_r": (0, -74, 0), "upperarm_l": (0, 76, 0),
              "lowerarm_r": (0, 0, 26), "lowerarm_l": (0, 0, -25)}),
        (24, {"Head": (0, 0, 0), "neck_01": (0, 0, 0), "spine_03": (7, 0, 0),
              "upperarm_r": (0, -62, 20), "upperarm_l": (0, 64, -20),
              "lowerarm_r": (0, 0, 48), "lowerarm_l": (0, 0, -48)}),
    ],
}


def main():
    arm = load_rig()
    clear_actions()
    drop_mesh()
    for name in sorted(CLIPS):
        author(arm, name, CLIPS[name])
        print("authored %s (%d poses)" % (name, len(CLIPS[name])))
    export(OUT)
    print("exported %s (%d bytes)" % (OUT, os.path.getsize(OUT)))


if __name__ == "__main__":
    main()
