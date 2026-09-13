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
    has to drop the body, and a man lying on the mat has to be laid ON it.

    Translate ROOT, never pelvis. Keyframing pelvis location made Blender's
    exporter emit a second pelvis ROTATION track carrying the bind pose --
    a single key of 104 deg about X -- which Godot imported alongside the
    authored one and applied instead. Every state that used the shared
    stance then rendered as a man lying flat on his back, IDLE included.
    root has no such conflict and is what the project's root-motion path
    already expects.
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
        "root": (0, 0, 0, 0.0, 0.0, -0.045),
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
                    root=(0, 0, 0, 0.0, 0.0, -0.10))),
        # Explosion: arms overhead, chest out, up onto the toes.
        (14, stance(upperarm_r=(0, 72, 0), upperarm_l=(0, -72, 0),
                    lowerarm_r=(0, 0, 18), lowerarm_l=(0, 0, -18),
                    spine_03=(-13, 0, 0), Head=(-19, 0, 0),
                    calf_r=(6, 0, 0), calf_l=(6, 0, 0),
                    foot_r=(16, 0, 0), foot_l=(16, 0, 0),
                    root=(0, 0, 0, 0.0, 0.0, 0.03))),
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
                    root=(0, 0, 0, 0.0, 0.04, -0.05))),
        # Contact: the torso twist drives it, and the back leg pushes
        # through so the whole man arrives, not just the arm.
        (9,  stance(upperarm_r=(0, -15, 70), lowerarm_r=(0, 0, 10),
                    upperarm_l=(0, 58, -10), lowerarm_l=(0, 0, -60),
                    spine_03=(11, 0, 30), Head=(0, 0, 16),
                    thigh_r=(-20, 5, 0), calf_r=(12, 0, 0),
                    thigh_l=(-4, -5, 0), foot_r=(4, 0, 0),
                    root=(0, 0, 0, 0.0, -0.06, -0.04))),
        # Follow-through PAST contact, not a stop at it.
        (13, stance(upperarm_r=(0, -14, 82), lowerarm_r=(0, 0, 20),
                    upperarm_l=(0, 60, -8), lowerarm_l=(0, 0, -62),
                    spine_03=(12, 0, 24), Head=(0, 0, 11),
                    thigh_r=(-22, 5, 0), calf_r=(14, 0, 0),
                    root=(0, 0, 0, 0.0, -0.07, -0.04))),
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
                    root=(0, 0, 0, 0.0, 0.07, -0.07))),
        (16, stance(Head=(-5, 0, -9), neck_01=(-2, 0, -4), spine_03=(3, 0, -5),
                    root=(0, 0, 0, 0.0, 0.02, -0.05))),
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
                    root=(0, 0, 0, 0.0, -0.04, -0.045))),
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
                    calf_l=(14, 0, 0), root=(0, 0, 0, 0.0, 0.05, -0.03))),
        # Contact: the knee straightens and the hips open through it.
        (8,  stance(thigh_r=(-62, 6, 0), calf_r=(10, 0, 0), foot_r=(22, 0, 0),
                    spine_03=(-6, 0, 0), Head=(-4, 0, 0),
                    upperarm_r=(0, -74, -14), upperarm_l=(0, 78, -10),
                    thigh_l=(-2, -5, 0), calf_l=(10, 0, 0),
                    root=(0, 0, 0, 0.0, 0.08, -0.02))),
        # Follow-through, then the leg folds back down under him.
        (12, stance(thigh_r=(-56, 6, 0), calf_r=(26, 0, 0), foot_r=(16, 0, 0),
                    spine_03=(-2, 0, 0), upperarm_r=(0, -70, -10),
                    upperarm_l=(0, 74, -8), root=(0, 0, 0, 0.0, 0.06, -0.03))),
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
                    root=(0, 0, 0, 0.0, 0.08, -0.07))),
        (13, stance(thigh_r=(-48, 8, 0), calf_r=(84, 0, 0), foot_r=(12, 0, 0),
                    spine_03=(2, 0, -4), upperarm_r=(0, -68, -8),
                    upperarm_l=(0, 72, -8), root=(0, 0, 0, 0.0, 0.04, -0.03))),
        (17, stance(thigh_r=(-70, 8, 0), calf_r=(6, 0, 0), foot_r=(26, 0, 0),
                    spine_03=(-12, 0, 4), Head=(-8, 0, 0),
                    upperarm_r=(0, -78, -18), upperarm_l=(0, 82, -14),
                    thigh_l=(0, -5, 0), calf_l=(8, 0, 0),
                    root=(0, 0, 0, 0.0, 0.10, -0.01))),
        (22, stance(thigh_r=(-58, 8, 0), calf_r=(30, 0, 0), foot_r=(18, 0, 0),
                    spine_03=(-4, 0, 2), upperarm_r=(0, -72, -12),
                    upperarm_l=(0, 76, -10), root=(0, 0, 0, 0.0, 0.07, -0.03))),
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
                    root=(0, 0, 0, 0.0, 0.05, -0.09))),
        (8,  stance(spine_01=(22, 0, 0), spine_03=(30, 0, 0), Head=(18, 0, 0),
                    upperarm_r=(0, -54, 34), upperarm_l=(0, 56, -34),
                    lowerarm_r=(0, 0, 92), lowerarm_l=(0, 0, -92),
                    thigh_r=(-20, 5, 0), thigh_l=(-20, -5, 0),
                    calf_r=(38, 0, 0), calf_l=(38, 0, 0),
                    root=(0, 0, 0, 0.0, 0.08, -0.13))),
        (16, stance(spine_01=(10, 0, 0), spine_03=(16, 0, 0), Head=(8, 0, 0),
                    calf_r=(28, 0, 0), calf_l=(28, 0, 0),
                    root=(0, 0, 0, 0.0, 0.03, -0.08))),
        (24, stance()),
    ],

    # Stunned: on the feet but gone. A slow unbalanced sway with the guard
    # dropped -- not a pose held still, which is what a frozen clip looks
    # like and what this state used to render as.
    "Stunned_Sway": [
        (1,  stance(upperarm_r=(0, -70, 6), upperarm_l=(0, 72, -6),
                    lowerarm_r=(0, 0, 30), lowerarm_l=(0, 0, -30),
                    Head=(16, 0, 8), spine_03=(14, 0, 6),
                    root=(0, 0, 0, 0.03, 0.02, -0.08))),
        (8,  stance(upperarm_r=(0, -74, 2), upperarm_l=(0, 70, -10),
                    lowerarm_r=(0, 0, 24), lowerarm_l=(0, 0, -26),
                    Head=(12, 0, -14), spine_03=(11, 0, -10),
                    thigh_r=(-6, 8, 0), calf_r=(26, 0, 0),
                    root=(0, 0, 0, -0.04, 0.03, -0.07))),
        (15, stance(upperarm_r=(0, -68, 8), upperarm_l=(0, 74, -4),
                    lowerarm_r=(0, 0, 32), lowerarm_l=(0, 0, -28),
                    Head=(18, 0, 12), spine_03=(15, 0, 9),
                    thigh_l=(-6, -8, 0), calf_l=(26, 0, 0),
                    root=(0, 0, 0, 0.04, 0.01, -0.09))),
        (22, stance(upperarm_r=(0, -72, 4), upperarm_l=(0, 72, -8),
                    lowerarm_r=(0, 0, 28), lowerarm_l=(0, 0, -28),
                    Head=(14, 0, -6), spine_03=(12, 0, -4),
                    root=(0, 0, 0, -0.02, 0.02, -0.08))),
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
                    root=(0, 0, 0, 0.0, -0.08, -0.03))),
        (14, stance(upperarm_r=(0, 6, 92), lowerarm_r=(0, 0, 10),
                    upperarm_l=(0, 38, -44), spine_03=(4, 0, 20),
                    Head=(0, 0, 12), thigh_r=(-20, 5, 0),
                    root=(0, 0, 0, 0.0, -0.10, -0.04))),
        (24, stance()),
    ],

    # --- states that were playing raw rig clips ---------------------------

    # IDLE. The rig's Idle is a relaxed civilian stand with the arms down.
    # A wrestler at rest is still coiled: weight forward, hands up, always
    # moving a little. Loops -- f1 and f72 are the same pose.
    "Idle_Ready": [
        (1,  stance()),
        (18, stance(spine_03=(10, 0, 3), Head=(2, 0, 4),
                    upperarm_r=(0, -46, 20), upperarm_l=(0, 52, -16),
                    calf_r=(23, 0, 0), calf_l=(18, 0, 0),
                    root=(0, 0, 0, 0.015, 0.0, -0.052))),
        (36, stance(spine_03=(7, 0, 0), Head=(0, 0, 0),
                    calf_r=(18, 0, 0), calf_l=(22, 0, 0),
                    root=(0, 0, 0, 0.0, 0.0, -0.038))),
        (54, stance(spine_03=(10, 0, -3), Head=(2, 0, -4),
                    upperarm_r=(0, -50, 16), upperarm_l=(0, 48, -20),
                    calf_r=(18, 0, 0), calf_l=(23, 0, 0),
                    root=(0, 0, 0, -0.015, 0.0, -0.052))),
        (72, stance()),
    ],

    # LOCOMOTION. Contact / down / pass / up twice, per the walk-cycle
    # reference, but carried in the wrestling stance -- this is a man
    # circling an opponent, not walking down a street, so the hands stay up
    # and the steps stay short.
    "Walk_Stalk": [
        (1,  stance(thigh_r=(-24, 5, 0), thigh_l=(20, -5, 0), calf_l=(26, 0, 0),
                    foot_r=(-14, 0, 0))),
        (8,  stance(thigh_r=(-10, 5, 0), calf_r=(28, 0, 0),
                    thigh_l=(10, -5, 0), calf_l=(16, 0, 0),
                    root=(0, 0, 0, 0.0, 0.0, -0.075))),
        (16, stance(thigh_r=(14, 5, 0), calf_r=(14, 0, 0),
                    thigh_l=(-20, -5, 0), calf_l=(24, 0, 0),
                    foot_l=(-14, 0, 0))),
        (24, stance(thigh_r=(10, 5, 0), calf_r=(18, 0, 0),
                    thigh_l=(-8, -5, 0), calf_l=(28, 0, 0),
                    root=(0, 0, 0, 0.0, 0.0, -0.075))),
        (32, stance(thigh_r=(-24, 5, 0), thigh_l=(20, -5, 0), calf_l=(26, 0, 0),
                    foot_r=(-14, 0, 0))),
    ],

    # RUN. Contact / drive / flight / recovery. Longer stride, deeper lean,
    # and the arms actually drive -- the rig's Sprint is a jog with the
    # torso upright.
    "Run_Drive": [
        (1,  stance(spine_03=(18, 0, 0), thigh_r=(-42, 5, 0), calf_r=(20, 0, 0),
                    thigh_l=(30, -5, 0), calf_l=(54, 0, 0),
                    upperarm_r=(0, -54, -28), lowerarm_r=(0, 0, 92),
                    upperarm_l=(0, 56, 28), lowerarm_l=(0, 0, -92))),
        (6,  stance(spine_03=(20, 0, 0), thigh_r=(-14, 5, 0), calf_r=(16, 0, 0),
                    thigh_l=(20, -5, 0), calf_l=(72, 0, 0),
                    upperarm_r=(0, -56, -8), lowerarm_r=(0, 0, 86),
                    upperarm_l=(0, 58, 8), lowerarm_l=(0, 0, -86),
                    root=(0, 0, 0, 0.0, 0.0, -0.09))),
        (11, stance(spine_03=(18, 0, 0), thigh_r=(30, 5, 0), calf_r=(54, 0, 0),
                    thigh_l=(-42, -5, 0), calf_l=(20, 0, 0),
                    upperarm_r=(0, -54, 28), lowerarm_r=(0, 0, 92),
                    upperarm_l=(0, 56, -28), lowerarm_l=(0, 0, -92))),
        (16, stance(spine_03=(20, 0, 0), thigh_r=(20, 5, 0), calf_r=(72, 0, 0),
                    thigh_l=(-14, -5, 0), calf_l=(16, 0, 0),
                    upperarm_r=(0, -56, 8), lowerarm_r=(0, 0, 86),
                    upperarm_l=(0, 58, -8), lowerarm_l=(0, 0, -86),
                    root=(0, 0, 0, 0.0, 0.0, -0.09))),
        (20, stance(spine_03=(18, 0, 0), thigh_r=(-42, 5, 0), calf_r=(20, 0, 0),
                    thigh_l=(30, -5, 0), calf_l=(54, 0, 0),
                    upperarm_r=(0, -54, -28), lowerarm_r=(0, 0, 92),
                    upperarm_l=(0, 56, 28), lowerarm_l=(0, 0, -92))),
    ],

    # TIE_UP. The collar-and-elbow: both arms forward at head height, one
    # high for the collar and one lower for the elbow, chest square, legs
    # braced and driving. "Push" is a two-armed shove, which was closer than
    # the one-armed point it replaced but is still a man pushing a crate.
    "Tie_Up_Collar": [
        (1,  stance()),
        (10, stance(upperarm_r=(0, -18, 58), lowerarm_r=(0, 0, 46),
                    upperarm_l=(0, 4, -66), lowerarm_l=(0, 0, -34),
                    spine_03=(16, 0, 0), Head=(-6, 0, 0),
                    thigh_r=(10, 6, 0), thigh_l=(-18, -6, 0),
                    calf_r=(16, 0, 0), calf_l=(30, 0, 0),
                    root=(0, 0, 0, 0.0, -0.03, -0.08))),
        (22, stance(upperarm_r=(0, -14, 62), lowerarm_r=(0, 0, 42),
                    upperarm_l=(0, 8, -70), lowerarm_l=(0, 0, -30),
                    spine_03=(19, 0, 4), Head=(-8, 0, 2),
                    thigh_r=(12, 6, 0), thigh_l=(-20, -6, 0),
                    calf_r=(14, 0, 0), calf_l=(32, 0, 0),
                    root=(0, 0, 0, 0.02, -0.05, -0.085))),
        (30, stance(upperarm_r=(0, -18, 58), lowerarm_r=(0, 0, 46),
                    upperarm_l=(0, 4, -66), lowerarm_l=(0, 0, -34),
                    spine_03=(16, 0, 0), Head=(-6, 0, 0),
                    thigh_r=(10, 6, 0), thigh_l=(-18, -6, 0),
                    calf_r=(16, 0, 0), calf_l=(30, 0, 0),
                    root=(0, 0, 0, 0.0, -0.03, -0.08))),
    ],

    # DOWN / PIN_DEFENDER. Death01 is a man dying: he collapses and lies
    # still, arms splayed. A wrestler who has been dropped is on his back
    # with his knees up, and he is still breathing. pelvis.-X lays him out;
    # the translation drops him onto the mat.
    "Down_Supine": [
        (1,  {"pelvis": (-84, 0, 0), "root": (0, 0, 0, 0.0, 0.0, -0.86),
              "spine_01": (-6, 0, 0), "spine_03": (-10, 0, 0),
              "neck_01": (10, 0, 0), "Head": (14, 0, 0),
              "thigh_r": (-54, 10, 0), "thigh_l": (-48, -10, 0),
              "calf_r": (56, 0, 0), "calf_l": (44, 0, 0),
              "foot_r": (-10, 0, 0), "foot_l": (-10, 0, 0),
              "upperarm_r": (0, -34, 26), "lowerarm_r": (0, 0, 40),
              "upperarm_l": (0, 38, -22), "lowerarm_l": (0, 0, -36)}),
        (20, {"pelvis": (-84, 0, 0), "root": (0, 0, 0, 0.0, 0.0, -0.845),
              "spine_01": (-3, 0, 0), "spine_03": (-6, 0, 0),
              "neck_01": (12, 0, 0), "Head": (16, 0, 0),
              "thigh_r": (-50, 10, 0), "thigh_l": (-52, -10, 0),
              "calf_r": (50, 0, 0), "calf_l": (50, 0, 0),
              "foot_r": (-8, 0, 0), "foot_l": (-8, 0, 0),
              "upperarm_r": (0, -30, 30), "lowerarm_r": (0, 0, 46),
              "upperarm_l": (0, 34, -26), "lowerarm_l": (0, 0, -42)}),
        (40, {"pelvis": (-84, 0, 0), "root": (0, 0, 0, 0.0, 0.0, -0.86),
              "spine_01": (-6, 0, 0), "spine_03": (-10, 0, 0),
              "neck_01": (10, 0, 0), "Head": (14, 0, 0),
              "thigh_r": (-54, 10, 0), "thigh_l": (-48, -10, 0),
              "calf_r": (56, 0, 0), "calf_l": (44, 0, 0),
              "foot_r": (-10, 0, 0), "foot_l": (-10, 0, 0),
              "upperarm_r": (0, -34, 26), "lowerarm_r": (0, 0, 40),
              "upperarm_l": (0, 38, -22), "lowerarm_l": (0, 0, -36)}),
    ],

    # FINISHER. This state plays Sword_Attack -- a two-handed overhead sword
    # swing. The finisher is the biggest moment in a match and it has been
    # a man chopping at the air. A big lift-and-drive instead: load deep,
    # haul up through the legs, drive forward and down.
    "Finisher_Drive": [
        (1,  stance()),
        # Load: down into the legs, arms wrapping low.
        (10, stance(spine_03=(30, 0, 0), Head=(10, 0, 0),
                    upperarm_r=(0, -30, 48), lowerarm_r=(0, 0, 62),
                    upperarm_l=(0, 34, -48), lowerarm_l=(0, 0, -62),
                    thigh_r=(-34, 6, 0), thigh_l=(-34, -6, 0),
                    calf_r=(54, 0, 0), calf_l=(54, 0, 0),
                    root=(0, 0, 0, 0.0, 0.06, -0.20))),
        # Haul: legs drive, chest opens, the load comes up.
        (18, stance(spine_03=(-14, 0, 0), Head=(-16, 0, 0),
                    upperarm_r=(0, 10, 40), lowerarm_r=(0, 0, 70),
                    upperarm_l=(0, -6, -40), lowerarm_l=(0, 0, -70),
                    thigh_r=(-6, 6, 0), thigh_l=(-6, -6, 0),
                    calf_r=(6, 0, 0), calf_l=(6, 0, 0),
                    foot_r=(14, 0, 0), foot_l=(14, 0, 0),
                    root=(0, 0, 0, 0.0, -0.04, 0.04))),
        # Drive down: the throw, whole body committing forward.
        (26, stance(spine_03=(38, 0, 0), Head=(16, 0, 0),
                    upperarm_r=(0, -34, 74), lowerarm_r=(0, 0, 26),
                    upperarm_l=(0, 38, -74), lowerarm_l=(0, 0, -26),
                    thigh_r=(-30, 8, 0), thigh_l=(-16, -8, 0),
                    calf_r=(46, 0, 0), calf_l=(30, 0, 0),
                    root=(0, 0, 0, 0.0, -0.10, -0.22))),
        (40, stance(spine_03=(16, 0, 0), calf_r=(28, 0, 0), calf_l=(28, 0, 0),
                    root=(0, 0, 0, 0.0, -0.02, -0.09))),
    ],

    # SUBMISSION_ATTACKER. Crouch_Idle is a man crouching by himself. This
    # is someone WORKING: down on one knee, leaning his weight into a hold,
    # hauling back rhythmically rather than sitting still.
    "Submission_Work": [
        (1,  stance(spine_03=(26, 0, 0), Head=(12, 0, 0),
                    upperarm_r=(0, -26, 56), lowerarm_r=(0, 0, 50),
                    upperarm_l=(0, 30, -52), lowerarm_l=(0, 0, -46),
                    thigh_r=(-72, 8, 0), calf_r=(86, 0, 0), foot_r=(16, 0, 0),
                    thigh_l=(-30, -10, 0), calf_l=(40, 0, 0),
                    root=(0, 0, 0, 0.0, 0.06, -0.34))),
        (14, stance(spine_03=(8, 0, 0), Head=(-4, 0, 0),
                    upperarm_r=(0, -12, 34), lowerarm_r=(0, 0, 78),
                    upperarm_l=(0, 16, -30), lowerarm_l=(0, 0, -74),
                    thigh_r=(-70, 8, 0), calf_r=(84, 0, 0), foot_r=(16, 0, 0),
                    thigh_l=(-26, -10, 0), calf_l=(36, 0, 0),
                    root=(0, 0, 0, 0.0, 0.12, -0.30))),
        (30, stance(spine_03=(26, 0, 0), Head=(12, 0, 0),
                    upperarm_r=(0, -26, 56), lowerarm_r=(0, 0, 50),
                    upperarm_l=(0, 30, -52), lowerarm_l=(0, 0, -46),
                    thigh_r=(-72, 8, 0), calf_r=(86, 0, 0), foot_r=(16, 0, 0),
                    thigh_l=(-30, -10, 0), calf_l=(40, 0, 0),
                    root=(0, 0, 0, 0.0, 0.06, -0.34))),
    ],

    # --- the grapple family -----------------------------------------------
    #
    # These replace the last clips taken straight off the rig, and they are
    # the ones that were furthest from what they represent: a lock-up
    # played "Interact" (a one-armed reach-and-point), the attacker in a
    # hold played "PickUp_Table", and the man being thrown played
    # "Death01".

    # GRAPPLE_HOLD, no role known. A collar-and-elbow held and worked: both
    # arms up and engaged, weight driving forward through bent legs.
    "Grapple_Hold_Neutral": [
        (1,  stance(upperarm_r=(0, -16, 56), lowerarm_r=(0, 0, 48),
                    upperarm_l=(0, 6, -64), lowerarm_l=(0, 0, -36),
                    spine_03=(15, 0, 0), Head=(-5, 0, 0),
                    thigh_r=(8, 6, 0), thigh_l=(-16, -6, 0),
                    calf_r=(16, 0, 0), calf_l=(30, 0, 0),
                    root=(0, 0, 0, 0.0, -0.03, -0.08))),
        (15, stance(upperarm_r=(0, -12, 60), lowerarm_r=(0, 0, 44),
                    upperarm_l=(0, 10, -68), lowerarm_l=(0, 0, -32),
                    spine_03=(18, 0, 5), Head=(-7, 0, 3),
                    thigh_r=(10, 6, 0), thigh_l=(-18, -6, 0),
                    calf_r=(14, 0, 0), calf_l=(32, 0, 0),
                    root=(0, 0, 0, 0.02, -0.05, -0.085))),
        (30, stance(upperarm_r=(0, -16, 56), lowerarm_r=(0, 0, 48),
                    upperarm_l=(0, 6, -64), lowerarm_l=(0, 0, -36),
                    spine_03=(15, 0, 0), Head=(-5, 0, 0),
                    thigh_r=(8, 6, 0), thigh_l=(-16, -6, 0),
                    calf_r=(16, 0, 0), calf_l=(30, 0, 0),
                    root=(0, 0, 0, 0.0, -0.03, -0.08))),
    ],

    # GRAPPLE_HOLD, attacker. A front waistlock: bent at the waist, both
    # arms wrapped LOW around the other man, legs braced wide and driving.
    # PickUp_Table is a man lifting furniture with a straight back.
    "Grapple_Hold_Attacker": [
        (1,  stance(spine_01=(20, 0, 0), spine_03=(30, 0, 0), Head=(-16, 0, 0),
                    upperarm_r=(0, -30, 62), lowerarm_r=(0, 0, 58),
                    upperarm_l=(0, 34, -62), lowerarm_l=(0, 0, -58),
                    thigh_r=(-14, 12, 0), thigh_l=(-14, -12, 0),
                    calf_r=(34, 0, 0), calf_l=(34, 0, 0),
                    root=(0, 0, 0, 0.0, -0.05, -0.14))),
        (15, stance(spine_01=(24, 0, 0), spine_03=(35, 0, 0), Head=(-18, 0, 0),
                    upperarm_r=(0, -26, 66), lowerarm_r=(0, 0, 62),
                    upperarm_l=(0, 30, -66), lowerarm_l=(0, 0, -62),
                    thigh_r=(-18, 12, 0), thigh_l=(-18, -12, 0),
                    calf_r=(40, 0, 0), calf_l=(40, 0, 0),
                    root=(0, 0, 0, 0.0, -0.08, -0.18))),
        (30, stance(spine_01=(20, 0, 0), spine_03=(30, 0, 0), Head=(-16, 0, 0),
                    upperarm_r=(0, -30, 62), lowerarm_r=(0, 0, 58),
                    upperarm_l=(0, 34, -62), lowerarm_l=(0, 0, -58),
                    thigh_r=(-14, 12, 0), thigh_l=(-14, -12, 0),
                    calf_r=(34, 0, 0), calf_l=(34, 0, 0),
                    root=(0, 0, 0, 0.0, -0.05, -0.14))),
    ],

    # GRAPPLE_HOLD, defender. Bent over and held, hands on the other man's
    # shoulders, legs braced against being moved -- resisting, not dead.
    # Death01 is a corpse, which is what this state has played.
    "Grapple_Hold_Defender": [
        (1,  stance(spine_01=(26, 0, 0), spine_03=(34, 0, 0), Head=(-20, 0, 0),
                    upperarm_r=(0, -20, 50), lowerarm_r=(0, 0, 62),
                    upperarm_l=(0, 24, -50), lowerarm_l=(0, 0, -62),
                    thigh_r=(-10, 10, 0), thigh_l=(-10, -10, 0),
                    calf_r=(30, 0, 0), calf_l=(30, 0, 0),
                    root=(0, 0, 0, 0.0, 0.04, -0.13))),
        (15, stance(spine_01=(30, 0, 0), spine_03=(39, 0, 0), Head=(-22, 0, 0),
                    upperarm_r=(0, -16, 54), lowerarm_r=(0, 0, 66),
                    upperarm_l=(0, 20, -54), lowerarm_l=(0, 0, -66),
                    thigh_r=(-14, 10, 0), thigh_l=(-14, -10, 0),
                    calf_r=(36, 0, 0), calf_l=(36, 0, 0),
                    root=(0, 0, 0, 0.0, 0.07, -0.17))),
        (30, stance(spine_01=(26, 0, 0), spine_03=(34, 0, 0), Head=(-20, 0, 0),
                    upperarm_r=(0, -20, 50), lowerarm_r=(0, 0, 62),
                    upperarm_l=(0, 24, -50), lowerarm_l=(0, 0, -62),
                    thigh_r=(-10, 10, 0), thigh_l=(-10, -10, 0),
                    calf_r=(30, 0, 0), calf_l=(30, 0, 0),
                    root=(0, 0, 0, 0.0, 0.04, -0.13))),
    ],

    # MOVE_EXEC: the beat a throw resolves. Jump_Land is a man landing from
    # a jump -- knees absorbing a drop he took himself. This is the OTHER
    # side of that: he has just put someone down and is coming back up out
    # of the follow-through.
    "Move_Exec_Impact": [
        (1,  stance(spine_01=(22, 0, 0), spine_03=(32, 0, 0), Head=(-10, 0, 0),
                    upperarm_r=(0, -32, 60), lowerarm_r=(0, 0, 40),
                    upperarm_l=(0, 36, -60), lowerarm_l=(0, 0, -40),
                    thigh_r=(-26, 10, 0), thigh_l=(-20, -10, 0),
                    calf_r=(44, 0, 0), calf_l=(38, 0, 0),
                    root=(0, 0, 0, 0.0, -0.06, -0.20))),
        (9,  stance(spine_01=(14, 0, 0), spine_03=(22, 0, 0), Head=(-6, 0, 0),
                    upperarm_r=(0, -40, 46), lowerarm_r=(0, 0, 52),
                    upperarm_l=(0, 44, -46), lowerarm_l=(0, 0, -52),
                    thigh_r=(-18, 8, 0), thigh_l=(-14, -8, 0),
                    calf_r=(34, 0, 0), calf_l=(30, 0, 0),
                    root=(0, 0, 0, 0.0, -0.02, -0.13))),
        (18, stance()),
    ],

    # IRISH_WHIP: the throw itself. "Push" is a two-armed shove straight
    # ahead; a whip turns the hips and SLINGS the other man past you, so the
    # arm finishes across the body and the chest opens after him.
    "Irish_Whip_Throw": [
        (1,  stance(upperarm_r=(0, -20, 54), lowerarm_r=(0, 0, 50),
                    upperarm_l=(0, 14, -58), lowerarm_l=(0, 0, -44),
                    spine_03=(14, 0, -18), thigh_r=(6, 6, 0),
                    calf_r=(22, 0, 0),
                    root=(0, 0, 0, 0.0, 0.02, -0.07))),
        (7,  stance(upperarm_r=(0, -6, 74), lowerarm_r=(0, 0, 22),
                    upperarm_l=(0, 20, -40), lowerarm_l=(0, 0, -30),
                    spine_03=(10, 0, 30), Head=(0, 0, 22),
                    thigh_r=(-22, 6, 0), calf_r=(16, 0, 0),
                    thigh_l=(8, -6, 0),
                    root=(0, 0, 0, 0.0, -0.06, -0.05))),
        (13, stance(upperarm_r=(0, 4, 86), lowerarm_r=(0, 0, 14),
                    upperarm_l=(0, 26, -34), lowerarm_l=(0, 0, -26),
                    spine_03=(6, 0, 40), Head=(0, 0, 28),
                    thigh_r=(-26, 6, 0), calf_r=(18, 0, 0),
                    root=(0, 0, 0, 0.0, -0.09, -0.05))),
        (24, stance()),
    ],

    # --- paired halves ----------------------------------------------------
    #
    # One clip per role per move, 30 frames = the 1.0s every trajectory in
    # paired_recipes.gd runs for. The two halves of a move are authored
    # against each other beat for beat: where the attacker's knee drives at
    # f20, the defender folds at f20.

    # Collar-and-elbow, drag down, knee to the midsection, shove off.
    # Nobody leaves the mat and nobody inverts, by design.
    "Clinch_Knee_Attacker": [
        (1,  stance(upperarm_r=(0, -16, 56), lowerarm_r=(0, 0, 48),
                    upperarm_l=(0, 6, -64), lowerarm_l=(0, 0, -36),
                    spine_03=(15, 0, 0), Head=(-5, 0, 0))),
        # Drag him down into the clinch.
        (9,  stance(spine_01=(18, 0, 0), spine_03=(28, 0, 0), Head=(-14, 0, 0),
                    upperarm_r=(0, -28, 64), lowerarm_r=(0, 0, 58),
                    upperarm_l=(0, 32, -64), lowerarm_l=(0, 0, -58),
                    thigh_r=(-16, 10, 0), thigh_l=(-16, -10, 0),
                    calf_r=(36, 0, 0), calf_l=(36, 0, 0),
                    root=(0, 0, 0, 0.0, -0.04, -0.15))),
        # Load the knee.
        (16, stance(spine_01=(16, 0, 0), spine_03=(24, 0, 0), Head=(-12, 0, 0),
                    upperarm_r=(0, -26, 66), lowerarm_r=(0, 0, 56),
                    upperarm_l=(0, 30, -66), lowerarm_l=(0, 0, -56),
                    thigh_r=(-48, 8, 0), calf_r=(84, 0, 0), foot_r=(14, 0, 0),
                    thigh_l=(-6, -10, 0), calf_l=(18, 0, 0),
                    root=(0, 0, 0, 0.0, -0.02, -0.08))),
        # Drive it in -- the action frame.
        (20, stance(spine_01=(22, 0, 0), spine_03=(30, 0, 0), Head=(-10, 0, 0),
                    upperarm_r=(0, -30, 70), lowerarm_r=(0, 0, 52),
                    upperarm_l=(0, 34, -70), lowerarm_l=(0, 0, -52),
                    thigh_r=(-64, 8, 0), calf_r=(40, 0, 0), foot_r=(20, 0, 0),
                    thigh_l=(-4, -10, 0), calf_l=(14, 0, 0),
                    root=(0, 0, 0, 0.0, -0.07, -0.05))),
        # Shove off.
        (25, stance(upperarm_r=(0, -14, 72), lowerarm_r=(0, 0, 18),
                    upperarm_l=(0, 18, -72), lowerarm_l=(0, 0, -18),
                    spine_03=(12, 0, 0), thigh_r=(-12, 8, 0),
                    calf_r=(26, 0, 0))),
        (30, stance()),
    ],

    "Clinch_Knee_Defender": [
        (1,  stance(upperarm_r=(0, -16, 56), lowerarm_r=(0, 0, 48),
                    upperarm_l=(0, 6, -64), lowerarm_l=(0, 0, -36),
                    spine_03=(15, 0, 0), Head=(-5, 0, 0))),
        # Bent forward and held.
        (9,  stance(spine_01=(30, 0, 0), spine_03=(40, 0, 0), Head=(-18, 0, 0),
                    upperarm_r=(0, -18, 48), lowerarm_r=(0, 0, 64),
                    upperarm_l=(0, 22, -48), lowerarm_l=(0, 0, -64),
                    thigh_r=(-12, 10, 0), thigh_l=(-12, -10, 0),
                    calf_r=(32, 0, 0), calf_l=(32, 0, 0),
                    root=(0, 0, 0, 0.0, 0.05, -0.16))),
        (16, stance(spine_01=(32, 0, 0), spine_03=(43, 0, 0), Head=(-16, 0, 0),
                    upperarm_r=(0, -16, 46), lowerarm_r=(0, 0, 68),
                    upperarm_l=(0, 20, -46), lowerarm_l=(0, 0, -68),
                    thigh_r=(-14, 10, 0), thigh_l=(-14, -10, 0),
                    calf_r=(34, 0, 0), calf_l=(34, 0, 0),
                    root=(0, 0, 0, 0.0, 0.06, -0.18))),
        # The knee lands, on the attacker's f20: he folds hard around it.
        (20, stance(spine_01=(44, 0, 0), spine_03=(56, 0, 0), Head=(10, 0, 0),
                    upperarm_r=(0, -46, 34), lowerarm_r=(0, 0, 88),
                    upperarm_l=(0, 50, -34), lowerarm_l=(0, 0, -88),
                    thigh_r=(-26, 10, 0), thigh_l=(-26, -10, 0),
                    calf_r=(48, 0, 0), calf_l=(48, 0, 0),
                    root=(0, 0, 0, 0.0, 0.12, -0.26))),
        # Shoved off, folded back and staggering upright.
        (25, stance(spine_01=(12, 0, 0), spine_03=(-6, 0, 0), Head=(-14, 0, 0),
                    upperarm_r=(0, -58, 10), upperarm_l=(0, 62, -10),
                    lowerarm_r=(0, 0, 40), lowerarm_l=(0, 0, -40),
                    root=(0, 0, 0, 0.0, 0.10, -0.09))),
        (30, stance()),
    ],

    # A drops to one knee, B folded across it. The attacker's kneel is
    # EARLY on purpose -- it has to be there before the victim arrives.
    "Backbreaker_Attacker": [
        (1,  stance(upperarm_r=(0, -16, 56), lowerarm_r=(0, 0, 48),
                    upperarm_l=(0, 6, -64), lowerarm_l=(0, 0, -36),
                    spine_03=(15, 0, 0))),
        (7,  stance(spine_01=(20, 0, 0), spine_03=(30, 0, 0),
                    upperarm_r=(0, -28, 64), lowerarm_r=(0, 0, 58),
                    upperarm_l=(0, 32, -64), lowerarm_l=(0, 0, -58),
                    thigh_r=(-20, 10, 0), thigh_l=(-20, -10, 0),
                    calf_r=(40, 0, 0), calf_l=(40, 0, 0),
                    root=(0, 0, 0, 0.0, -0.04, -0.18))),
        # The kneel: right knee to the mat, chest up, arms carrying him.
        (14, stance(spine_01=(-4, 0, 0), spine_03=(-12, 0, 0), Head=(-14, 0, 0),
                    upperarm_r=(0, -20, 50), lowerarm_r=(0, 0, 54),
                    upperarm_l=(0, 24, -50), lowerarm_l=(0, 0, -54),
                    thigh_r=(-76, 10, 0), calf_r=(92, 0, 0), foot_r=(18, 0, 0),
                    thigh_l=(-34, -12, 0), calf_l=(46, 0, 0),
                    root=(0, 0, 0, 0.0, 0.0, -0.36))),
        # The drop across the knee.
        (20, stance(spine_01=(-8, 0, 0), spine_03=(-18, 0, 0), Head=(-16, 0, 0),
                    upperarm_r=(0, -14, 58), lowerarm_r=(0, 0, 44),
                    upperarm_l=(0, 18, -58), lowerarm_l=(0, 0, -44),
                    thigh_r=(-78, 10, 0), calf_r=(94, 0, 0), foot_r=(18, 0, 0),
                    thigh_l=(-36, -12, 0), calf_l=(48, 0, 0),
                    root=(0, 0, 0, 0.0, 0.0, -0.40))),
        (30, stance(spine_03=(6, 0, 0), thigh_r=(-40, 8, 0), calf_r=(60, 0, 0),
                    thigh_l=(-20, -8, 0), calf_l=(34, 0, 0),
                    root=(0, 0, 0, 0.0, 0.0, -0.20))),
    ],

    "Backbreaker_Defender": [
        (1,  stance(upperarm_r=(0, -16, 56), lowerarm_r=(0, 0, 48),
                    upperarm_l=(0, 6, -64), lowerarm_l=(0, 0, -36),
                    spine_03=(15, 0, 0))),
        (7,  stance(spine_01=(24, 0, 0), spine_03=(34, 0, 0), Head=(-14, 0, 0),
                    upperarm_r=(0, -26, 30), lowerarm_r=(0, 0, 58),
                    upperarm_l=(0, 30, -30), lowerarm_l=(0, 0, -58),
                    thigh_r=(-16, 10, 0), thigh_l=(-16, -10, 0),
                    calf_r=(34, 0, 0), calf_l=(34, 0, 0),
                    root=(0, 0, 0, 0.0, 0.05, -0.14))),
        # Lifted, body starting to arch back over the knee.
        (14, stance(spine_01=(-18, 0, 0), spine_03=(-30, 0, 0), Head=(18, 0, 0),
                    upperarm_r=(0, -8, -20), lowerarm_r=(0, 0, 34),
                    upperarm_l=(0, 12, 20), lowerarm_l=(0, 0, -34),
                    thigh_r=(-30, 12, 0), thigh_l=(-26, -12, 0),
                    calf_r=(40, 0, 0), calf_l=(36, 0, 0),
                    root=(0, 0, 0, 0.0, 0.0, 0.10))),
        # Folded across the knee: the arch is the whole point of the move.
        (20, stance(spine_01=(-30, 0, 0), spine_03=(-46, 0, 0), Head=(26, 0, 0),
                    upperarm_r=(0, 16, -40), lowerarm_r=(0, 0, 26),
                    upperarm_l=(0, -12, 40), lowerarm_l=(0, 0, -26),
                    thigh_r=(-44, 12, 0), thigh_l=(-40, -12, 0),
                    calf_r=(54, 0, 0), calf_l=(50, 0, 0),
                    root=(0, 0, 0, 0.0, 0.0, -0.06))),
        # Rolls off onto the mat.
        (30, {"pelvis": (-80, 0, 0), "root": (0, 0, 0, 0.0, 0.0, -0.80),
              "spine_01": (-6, 0, 0), "spine_03": (-12, 0, 0),
              "neck_01": (8, 0, 0), "Head": (12, 0, 0),
              "thigh_r": (-50, 10, 0), "thigh_l": (-44, -10, 0),
              "calf_r": (52, 0, 0), "calf_l": (44, 0, 0),
              "foot_r": (-8, 0, 0), "foot_l": (-8, 0, 0),
              "upperarm_r": (0, -30, 28), "lowerarm_r": (0, 0, 42),
              "upperarm_l": (0, 34, -24), "lowerarm_l": (0, 0, -38)}),
    ],

    # A hooks the head, turns, and drops. No somersault in it -- that was
    # taken out once already and should not come back.
    "Neckbreaker_Attacker": [
        (1,  stance(upperarm_r=(0, -16, 56), lowerarm_r=(0, 0, 48),
                    upperarm_l=(0, 6, -64), lowerarm_l=(0, 0, -36),
                    spine_03=(15, 0, 0))),
        # Hook the head, high and across.
        (8,  stance(upperarm_r=(0, 10, 52), lowerarm_r=(0, 0, 76),
                    upperarm_l=(0, 30, -44), lowerarm_l=(0, 0, -54),
                    spine_03=(10, 0, -16), Head=(0, 0, -12),
                    thigh_r=(-10, 8, 0), calf_r=(24, 0, 0),
                    root=(0, 0, 0, 0.0, 0.0, -0.06))),
        # Turn through, taking him with it.
        (16, stance(upperarm_r=(0, 16, 64), lowerarm_r=(0, 0, 70),
                    upperarm_l=(0, 34, -50), lowerarm_l=(0, 0, -48),
                    spine_03=(4, 0, 28), Head=(0, 0, 20),
                    thigh_r=(-18, 8, 0), calf_r=(30, 0, 0),
                    thigh_l=(-8, -8, 0), calf_l=(22, 0, 0),
                    root=(0, 0, 0, 0.0, -0.04, -0.11))),
        # Drop: both men go down, attacker landing seated over him.
        (23, stance(spine_01=(10, 0, 0), spine_03=(16, 0, 0), Head=(6, 0, 0),
                    upperarm_r=(0, -6, 58), lowerarm_r=(0, 0, 54),
                    upperarm_l=(0, 26, -46), lowerarm_l=(0, 0, -44),
                    thigh_r=(-64, 12, 0), calf_r=(86, 0, 0), foot_r=(16, 0, 0),
                    thigh_l=(-50, -12, 0), calf_l=(70, 0, 0),
                    root=(0, 0, 0, 0.0, -0.06, -0.44))),
        (30, stance(spine_03=(10, 0, 0), thigh_r=(-44, 10, 0), calf_r=(62, 0, 0),
                    thigh_l=(-34, -10, 0), calf_l=(48, 0, 0),
                    root=(0, 0, 0, 0.0, -0.02, -0.24))),
    ],

    "Neckbreaker_Defender": [
        (1,  stance(upperarm_r=(0, -16, 56), lowerarm_r=(0, 0, 48),
                    upperarm_l=(0, 6, -64), lowerarm_l=(0, 0, -36),
                    spine_03=(15, 0, 0))),
        # Head hooked: chin pulled up and across, arms coming loose.
        (8,  stance(spine_01=(-10, 0, 0), spine_03=(-18, 0, 0),
                    neck_01=(-10, 0, 8), Head=(-20, 0, 14),
                    upperarm_r=(0, -50, 16), lowerarm_r=(0, 0, 46),
                    upperarm_l=(0, 54, -16), lowerarm_l=(0, 0, -46),
                    thigh_r=(-8, 10, 0), thigh_l=(-8, -10, 0),
                    root=(0, 0, 0, 0.0, 0.04, -0.02))),
        # Dragged backward off his feet.
        (16, stance(spine_01=(-22, 0, 0), spine_03=(-34, 0, 0),
                    neck_01=(-14, 0, 12), Head=(-26, 0, 20),
                    upperarm_r=(0, -34, -14), lowerarm_r=(0, 0, 30),
                    upperarm_l=(0, 38, 14), lowerarm_l=(0, 0, -30),
                    thigh_r=(-24, 12, 0), thigh_l=(-20, -12, 0),
                    calf_r=(30, 0, 0), calf_l=(26, 0, 0),
                    root=(0, 0, 0, 0.0, 0.10, -0.14))),
        # Down on his back.
        (23, {"pelvis": (-78, 0, 0), "root": (0, 0, 0, 0.0, 0.06, -0.78),
              "spine_01": (-8, 0, 0), "spine_03": (-14, 0, 0),
              "neck_01": (6, 0, 0), "Head": (10, 0, 0),
              "thigh_r": (-42, 10, 0), "thigh_l": (-38, -10, 0),
              "calf_r": (46, 0, 0), "calf_l": (40, 0, 0),
              "foot_r": (-8, 0, 0), "foot_l": (-8, 0, 0),
              "upperarm_r": (0, -28, 22), "lowerarm_r": (0, 0, 44),
              "upperarm_l": (0, 32, -18), "lowerarm_l": (0, 0, -40)}),
        (30, {"pelvis": (-82, 0, 0), "root": (0, 0, 0, 0.0, 0.04, -0.84),
              "spine_01": (-6, 0, 0), "spine_03": (-10, 0, 0),
              "neck_01": (10, 0, 0), "Head": (14, 0, 0),
              "thigh_r": (-52, 10, 0), "thigh_l": (-46, -10, 0),
              "calf_r": (54, 0, 0), "calf_l": (46, 0, 0),
              "foot_r": (-10, 0, 0), "foot_l": (-10, 0, 0),
              "upperarm_r": (0, -34, 26), "lowerarm_r": (0, 0, 40),
              "upperarm_l": (0, 38, -22), "lowerarm_l": (0, 0, -36)}),
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
