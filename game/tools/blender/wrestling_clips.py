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
    """Keyframe one action from a list of (frame, pose) entries.

    A pose maps bone name -> (rx, ry, rz) Euler degrees in ARMATURE space
    (see local_rot()), or -> (rx, ry, rz, dx, dy, dz) to also translate the
    bone by metres in armature space.

    Translation exists for the poses rotation alone cannot reach: a crouch
    and a cover have to drop the pelvis, and a man lying on the mat has to
    be laid ON it. Only translate the pelvis or root -- moving a limb's
    origin detaches it from its parent visually.
    """
    action = bpy.data.actions.new(name)
    arm.animation_data_clear()
    arm.animation_data_create()
    arm.animation_data.action = action

    for bone in arm.pose.bones:
        bone.rotation_mode = "QUATERNION"

    touched = sorted({b for _, pose in poses for b in pose})
    moved = sorted({b for _, pose in poses for b, v in pose.items() if len(v) > 3})
    for frame, pose in poses:
        for bone_name in touched:
            pb = arm.pose.bones.get(bone_name)
            if pb is None:
                raise SystemExit("%s: no bone %r on the rig" % (name, bone_name))
            value = pose.get(bone_name, (0.0, 0.0, 0.0))
            pb.rotation_quaternion = local_rot(arm, bone_name, *value[:3])
            pb.keyframe_insert("rotation_quaternion", frame=frame)
        for bone_name in moved:
            pb = arm.pose.bones[bone_name]
            value = pose.get(bone_name, (0.0, 0.0, 0.0))
            offset = mathutils.Vector(value[3:6]) if len(value) > 3 \
                else mathutils.Vector((0.0, 0.0, 0.0))
            rest = arm.data.bones[bone_name].matrix_local.to_3x3()
            pb.location = rest.inverted() @ offset
            pb.keyframe_insert("location", frame=frame)

    # Bezier everywhere. The animation skill is explicit that linear
    # interpolation on organic motion reads as mechanical, and a wrestler
    # moving at a constant rate between poses is the single clearest tell
    # that a clip was generated rather than performed.
    for fcurve in action.fcurves:
        for key in fcurve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"
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
# Poses are Euler degrees in ARMATURE space: Z up, X the left-right axis,
# character facing -Y. local_rot() re-expresses each in the bone's own frame,
# so a value means the same thing on a left bone as on its mirrored right
# one. A 6-tuple adds an armature-space translation in metres.
#
# All of this was measured off the rest pose, never guessed -- an earlier
# pass authored in bone-local space and swung one arm down while leaving the
# other at rest:
#
#   upperarm_r.Y  + raises the arm        (mirror: upperarm_l.Y)
#   upperarm_r.Z  + reaches FORWARD       (mirror: upperarm_l.Z)
#   lowerarm_r.Z  + bends the elbow       (mirror: lowerarm_l.Z)
#   thigh_*.X     - swings the leg forward, + swings it back
#   calf_*.X      + bends the knee (the leg folds backward: correct)
#   foot_*.X      + points the toes down
#   spine_03.X    + leans the chest forward, - arches it back
#   spine_03.Z    + drives the RIGHT shoulder forward (a strike's power)
#   pelvis.X      - lays the body on its back
#   Head.X        + drops the chin, - lifts it
#
# Timing follows .claude/skills/animation/references/combat-animation.md:
# anticipation 4-8 frames, action 2-4 (always the shortest), follow-through
# 4-8, recovery 8-16. Frames are at FPS (30), so each lands on a whole tick.

ARM_DOWN = 78.0


def stance(**over):
    """The wrestling base: knees bent, weight forward, hands up.

    Every clip starts and ends here so they cut together, and every clip
    poses the WHOLE body from it. The first authored pass keyframed only the
    arms and head, which baked 14 rotation tracks against the sampled clips'
    55 -- the hips and legs held whatever the AnimationTree happened to be
    blending from, so a strike never stepped into anything.
    """
    pose = {
        "spine_03": (8, 0, 0), "spine_01": (4, 0, 0), "Head": (0, 0, 0),
        "upperarm_r": (0, -48, 18), "lowerarm_r": (0, 0, 72),
        "upperarm_l": (0, 50, -18), "lowerarm_l": (0, 0, -72),
        "thigh_r": (-12, 5, 0), "thigh_l": (-12, -5, 0),
        "calf_r": (20, 0, 0), "calf_l": (20, 0, 0),
        "foot_r": (-8, 0, 0), "foot_l": (-8, 0, 0),
        "pelvis": (0, 0, 0, 0.0, 0.0, -0.045),
    }
    pose.update(over)
    return pose


CLIPS = {
    # --- already shipping -------------------------------------------------

    # Task #97. No celebration exists in the 42 source actions, so this
    # could only ever be authored.
    "Win_Celebrate": [
        (1,  stance()),
        # Anticipation: chin drops, arms load down, knees sink.
        (5,  stance(upperarm_r=(0, -90, 0), upperarm_l=(0, 90, 0),
                    lowerarm_r=(0, 0, 24), lowerarm_l=(0, 0, -24),
                    spine_03=(14, 0, 0), Head=(11, 0, 0),
                    calf_r=(30, 0, 0), calf_l=(30, 0, 0),
                    pelvis=(0, 0, 0, 0.0, 0.0, -0.10))),
        # Explosion: arms overhead, chest out, up onto the toes.
        (14, stance(upperarm_r=(0, 72, 0), upperarm_l=(0, -72, 0),
                    lowerarm_r=(0, 0, 18), lowerarm_l=(0, 0, -18),
                    spine_03=(-13, 0, 0), Head=(-19, 0, 0),
                    calf_r=(6, 0, 0), calf_l=(6, 0, 0),
                    foot_r=(16, 0, 0), foot_l=(16, 0, 0),
                    pelvis=(0, 0, 0, 0.0, 0.0, 0.03))),
        # Settles back off the extreme instead of stopping dead on it.
        (22, stance(upperarm_r=(0, 62, 0), upperarm_l=(0, -62, 0),
                    lowerarm_r=(0, 0, 22), lowerarm_l=(0, 0, -22),
                    spine_03=(-9, 0, 0), Head=(-14, 0, 0),
                    calf_r=(12, 0, 0), calf_l=(12, 0, 0))),
        (39, stance(upperarm_r=(0, 65, 0), upperarm_l=(0, -65, 0),
                    lowerarm_r=(0, 0, 20), lowerarm_l=(0, 0, -20),
                    spine_03=(-10, 0, 0), Head=(-15, 0, 0),
                    calf_r=(14, 0, 0), calf_l=(14, 0, 0))),
    ],

    # Right forearm. Contact on f9, which Hit_React_Head is timed against.
    # .Z is the reach and .Y only the height: a pass using Y alone rendered
    # as a man with his arms hanging, and at Y=-45 the contact frame sat 55
    # deg below horizontal, aimed at the opponent's knees.
    "Strike_Forearm": [
        (1,  stance()),
        # Wind-up: shoulder pulls back, elbow loads, weight onto the back leg.
        (5,  stance(upperarm_r=(0, -40, -15), lowerarm_r=(0, 0, 92),
                    upperarm_l=(0, 54, -26), spine_03=(10, 0, -26),
                    Head=(0, 0, -12), thigh_r=(6, 5, 0), calf_r=(26, 0, 0),
                    pelvis=(0, 0, 0, 0.0, 0.04, -0.05))),
        # Contact: the torso twist drives it, and the back leg pushes
        # through so the whole man arrives, not just the arm.
        (9,  stance(upperarm_r=(0, -15, 70), lowerarm_r=(0, 0, 10),
                    upperarm_l=(0, 58, -10), lowerarm_l=(0, 0, -60),
                    spine_03=(11, 0, 30), Head=(0, 0, 16),
                    thigh_r=(-20, 5, 0), calf_r=(12, 0, 0),
                    thigh_l=(-4, -5, 0), foot_r=(4, 0, 0),
                    pelvis=(0, 0, 0, 0.0, -0.06, -0.04))),
        # Follow-through PAST contact, not a stop at it.
        (13, stance(upperarm_r=(0, -14, 82), lowerarm_r=(0, 0, 20),
                    upperarm_l=(0, 60, -8), lowerarm_l=(0, 0, -62),
                    spine_03=(12, 0, 24), Head=(0, 0, 11),
                    thigh_r=(-22, 5, 0), calf_r=(14, 0, 0),
                    pelvis=(0, 0, 0, 0.0, -0.07, -0.04))),
        (24, stance()),
    ],

    # Head snaps first and furthest, neck follows, torso last -- the overlap
    # that reads as force arriving rather than the body turning as one board.
    "Hit_React_Head": [
        (1,  stance()),
        (3,  stance(Head=(-20, 0, -18), neck_01=(-9, 0, -8),
                    spine_03=(0, 0, -9), upperarm_r=(0, -62, 8),
                    upperarm_l=(0, 66, -10), calf_r=(26, 0, 0),
                    calf_l=(26, 0, 0))),
        (8,  stance(Head=(-14, 0, -26), neck_01=(-7, 0, -13),
                    spine_03=(-12, 0, -17), upperarm_r=(0, -56, 4),
                    upperarm_l=(0, 60, -6), thigh_r=(2, 5, 0),
                    calf_r=(30, 0, 0), calf_l=(24, 0, 0),
                    pelvis=(0, 0, 0, 0.0, 0.07, -0.07))),
        (16, stance(Head=(-5, 0, -9), neck_01=(-2, 0, -4), spine_03=(3, 0, -5),
                    pelvis=(0, 0, 0, 0.0, 0.02, -0.05))),
        (24, stance()),
    ],

    # --- new this pass ----------------------------------------------------

    # The jab: the fastest thing in the game. Short anticipation, 2-frame
    # action, quick recovery -- Punch_Cross retimed to 0.514s gave the same
    # duration but spent it as one slow arc with no snap anywhere in it.
    "Strike_Jab": [
        (1,  stance()),
        (4,  stance(lowerarm_l=(0, 0, -86), spine_03=(8, 0, -8))),
        # Contact: the LEFT hand, and only a short step behind it.
        (6,  stance(upperarm_l=(0, 22, -64), lowerarm_l=(0, 0, -14),
                    spine_03=(9, 0, 14), thigh_l=(-16, -5, 0),
                    pelvis=(0, 0, 0, 0.0, -0.04, -0.045))),
        (9,  stance(upperarm_l=(0, 26, -56), lowerarm_l=(0, 0, -28),
                    spine_03=(9, 0, 10))),
        (15, stance()),
    ],

    # A boot. The kicking leg is the whole performance, so the arms stay
    # where a wrestler's arms actually go -- out for balance, not pumping.
    "Strike_Kick": [
        (1,  stance()),
        # Chamber: knee up and folded before anything extends.
        (5,  stance(thigh_r=(-52, 6, 0), calf_r=(76, 0, 0), foot_r=(10, 0, 0),
                    spine_03=(4, 0, 0), upperarm_r=(0, -66, -6),
                    upperarm_l=(0, 70, -6), thigh_l=(-6, -5, 0),
                    calf_l=(14, 0, 0), pelvis=(0, 0, 0, 0.0, 0.05, -0.03))),
        # Contact: the knee straightens and the hips open through it.
        (8,  stance(thigh_r=(-62, 6, 0), calf_r=(10, 0, 0), foot_r=(22, 0, 0),
                    spine_03=(-6, 0, 0), Head=(-4, 0, 0),
                    upperarm_r=(0, -74, -14), upperarm_l=(0, 78, -10),
                    thigh_l=(-2, -5, 0), calf_l=(10, 0, 0),
                    pelvis=(0, 0, 0, 0.0, 0.08, -0.02))),
        # Follow-through, then the leg folds back down under him.
        (12, stance(thigh_r=(-56, 6, 0), calf_r=(26, 0, 0), foot_r=(16, 0, 0),
                    spine_03=(-2, 0, 0), upperarm_r=(0, -70, -10),
                    upperarm_l=(0, 74, -8), pelvis=(0, 0, 0, 0.0, 0.06, -0.03))),
        (17, stance()),
    ],

    # The heavy kick: the same boot thrown slower, wound further back, and
    # recovered from properly. Length comes from the anticipation and the
    # recovery, never from a slower action phase.
    "Strike_Kick_Heavy": [
        (1,  stance()),
        (8,  stance(thigh_r=(16, 6, 0), calf_r=(48, 0, 0), spine_03=(14, 0, -10),
                    upperarm_r=(0, -40, -20), upperarm_l=(0, 60, -20),
                    thigh_l=(-8, -5, 0), calf_l=(24, 0, 0),
                    pelvis=(0, 0, 0, 0.0, 0.08, -0.07))),
        (13, stance(thigh_r=(-48, 8, 0), calf_r=(84, 0, 0), foot_r=(12, 0, 0),
                    spine_03=(2, 0, -4), upperarm_r=(0, -68, -8),
                    upperarm_l=(0, 72, -8), pelvis=(0, 0, 0, 0.0, 0.04, -0.03))),
        (17, stance(thigh_r=(-70, 8, 0), calf_r=(6, 0, 0), foot_r=(26, 0, 0),
                    spine_03=(-12, 0, 4), Head=(-8, 0, 0),
                    upperarm_r=(0, -78, -18), upperarm_l=(0, 82, -14),
                    thigh_l=(0, -5, 0), calf_l=(8, 0, 0),
                    pelvis=(0, 0, 0, 0.0, 0.10, -0.01))),
        (22, stance(thigh_r=(-58, 8, 0), calf_r=(30, 0, 0), foot_r=(18, 0, 0),
                    spine_03=(-4, 0, 2), upperarm_r=(0, -72, -12),
                    upperarm_l=(0, 76, -10), pelvis=(0, 0, 0, 0.0, 0.07, -0.03))),
        (28, stance()),
    ],

    # Body shot. Folds AROUND the hit -- chest hollows, shoulders close in,
    # knees give -- where the head reaction whips backward.
    "Hit_React_Torso": [
        (1,  stance()),
        (3,  stance(spine_01=(18, 0, 0), spine_03=(24, 0, 0), Head=(14, 0, 0),
                    upperarm_r=(0, -58, 30), upperarm_l=(0, 60, -30),
                    lowerarm_r=(0, 0, 86), lowerarm_l=(0, 0, -86),
                    calf_r=(30, 0, 0), calf_l=(30, 0, 0),
                    pelvis=(0, 0, 0, 0.0, 0.05, -0.09))),
        (8,  stance(spine_01=(22, 0, 0), spine_03=(30, 0, 0), Head=(18, 0, 0),
                    upperarm_r=(0, -54, 34), upperarm_l=(0, 56, -34),
                    lowerarm_r=(0, 0, 92), lowerarm_l=(0, 0, -92),
                    thigh_r=(-20, 5, 0), thigh_l=(-20, -5, 0),
                    calf_r=(38, 0, 0), calf_l=(38, 0, 0),
                    pelvis=(0, 0, 0, 0.0, 0.08, -0.13))),
        (16, stance(spine_01=(10, 0, 0), spine_03=(16, 0, 0), Head=(8, 0, 0),
                    calf_r=(28, 0, 0), calf_l=(28, 0, 0),
                    pelvis=(0, 0, 0, 0.0, 0.03, -0.08))),
        (24, stance()),
    ],

    # Stunned: on the feet but gone. A slow unbalanced sway with the guard
    # dropped -- not a pose held still, which is what a frozen clip looks
    # like and what this state used to render as.
    "Stunned_Sway": [
        (1,  stance(upperarm_r=(0, -70, 6), upperarm_l=(0, 72, -6),
                    lowerarm_r=(0, 0, 30), lowerarm_l=(0, 0, -30),
                    Head=(16, 0, 8), spine_03=(14, 0, 6),
                    pelvis=(0, 0, 0, 0.03, 0.02, -0.08))),
        (8,  stance(upperarm_r=(0, -74, 2), upperarm_l=(0, 70, -10),
                    lowerarm_r=(0, 0, 24), lowerarm_l=(0, 0, -26),
                    Head=(12, 0, -14), spine_03=(11, 0, -10),
                    thigh_r=(-6, 8, 0), calf_r=(26, 0, 0),
                    pelvis=(0, 0, 0, -0.04, 0.03, -0.07))),
        (15, stance(upperarm_r=(0, -68, 8), upperarm_l=(0, 74, -4),
                    lowerarm_r=(0, 0, 32), lowerarm_l=(0, 0, -28),
                    Head=(18, 0, 12), spine_03=(15, 0, 9),
                    thigh_l=(-6, -8, 0), calf_l=(26, 0, 0),
                    pelvis=(0, 0, 0, 0.04, 0.01, -0.09))),
        (22, stance(upperarm_r=(0, -72, 4), upperarm_l=(0, 72, -8),
                    lowerarm_r=(0, 0, 28), lowerarm_l=(0, 0, -28),
                    Head=(14, 0, -6), spine_03=(12, 0, -4),
                    pelvis=(0, 0, 0, -0.02, 0.02, -0.08))),
    ],

    # The clothesline, for RUNNING_ATTACK. That state plays Punch_Cross
    # today: a wrestler sprints across the ring and throws a boxing jab.
    # The arm is out and LOCKED through the whole contact -- a clothesline
    # does not swing, the run supplies the force.
    "Running_Clothesline": [
        (1,  stance(upperarm_r=(0, -60, 20), lowerarm_r=(0, 0, 50),
                    thigh_r=(-26, 5, 0), thigh_l=(14, -5, 0),
                    spine_03=(12, 0, 0))),
        # The arm comes up and across before contact, so it is already
        # there when the bodies meet.
        (5,  stance(upperarm_r=(0, -10, 52), lowerarm_r=(0, 0, 12),
                    upperarm_l=(0, 44, -30), spine_03=(10, 0, -14),
                    thigh_r=(16, 5, 0), thigh_l=(-28, -5, 0),
                    calf_l=(28, 0, 0))),
        # Contact: arm straight across the chest, torso turning through it.
        (9,  stance(upperarm_r=(0, 2, 78), lowerarm_r=(0, 0, 4),
                    upperarm_l=(0, 40, -40), spine_03=(6, 0, 26),
                    Head=(0, 0, 18), thigh_r=(-30, 5, 0), calf_r=(16, 0, 0),
                    thigh_l=(10, -5, 0),
                    pelvis=(0, 0, 0, 0.0, -0.08, -0.03))),
        (14, stance(upperarm_r=(0, 6, 92), lowerarm_r=(0, 0, 10),
                    upperarm_l=(0, 38, -44), spine_03=(4, 0, 20),
                    Head=(0, 0, 12), thigh_r=(-20, 5, 0),
                    pelvis=(0, 0, 0, 0.0, -0.10, -0.04))),
        (24, stance()),
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
