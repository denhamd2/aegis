"""A pose solver for the CC0 base rig, in armature space.

Why this module exists
----------------------
The first authored pass (see git history of wrestling_clips.py) specified
every pose as per-bone Euler degrees, guessed against a remembered axis map
and never rendered. The result was measurable: every clip in the set --
Idle_Ready, Tie_Up_Collar, Strike_Forearm, Pin_Cover -- played with the arms
hanging at the sides, because `upperarm_r.Y` does not raise the arm from a
T-pose rest, it lowers it, and nothing in the loop ever checked. A
collar-and-elbow tie-up rendered as two men standing near each other.

So poses are not specified as joint angles here. They are specified as
**where the hands and feet are**, in metres, in armature space, and this
module solves the joints that put them there. That is the difference
between a pose you have to imagine and a pose you can measure: a foot at
z=0.104 is planted on the mat, a fist 0.62 m in front of the sternum is at
the end of a thrown punch, and both are checkable on a rendered frame.

Frame of reference
------------------
Armature space, measured off `wrestler_base.glb`'s rest pose:

    +X  the character's LEFT           -Y  the direction he FACES
    +Z  up                             origin  between the feet, on the mat

`vec(right, fwd, up)` builds a vector in the readable handedness -- `right`
is the character's own right, `fwd` is the way he is looking -- and converts.

Measured rest geometry (tools/blender/rig_pose.py::RIG_FACTS reproduces it):

    stands 1.65 m · pelvis 0.917 · sternum 1.478 · shoulder 1.441
    upperarm 0.274 · lowerarm 0.273 · thigh 0.400 · calf 0.429
    ankle 0.104 (a foot target at this height is planted)
    hips 0.089 either side of centre · shoulders 0.192

Everything is deterministic: no RNG, no time, no scene state that survives
between clips.
"""

import math

import bpy
import mathutils
from mathutils import Matrix, Quaternion, Vector

# --- Measured rest-pose geometry -----------------------------------------
# Reproduce with: for b in arm.data.bones: print(b.name, b.head_local, b.length)
RIG_FACTS = {
    "height": 1.651,
    "pelvis_z": 0.917,
    "shoulder_z": 1.441,
    "ankle_z": 0.104,
    "upperarm": 0.274,
    "lowerarm": 0.273,
    "thigh": 0.400,
    "calf": 0.429,
    "hip_x": 0.089,
    "shoulder_x": 0.192,
}

SPINE = ("spine_01", "spine_02", "spine_03")
FINGERS = ("index", "middle", "ring", "pinky")


def vec(right, fwd, up):
    """Readable (right, forward, up) -> armature space.

    The character faces -Y, so `fwd` negates. `right` is his right, which is
    -X: the rig's +X side carries the `_l` bones.
    """
    return Vector((-right, -fwd, up))


def _clamp(value, low, high):
    return max(low, min(high, value))


def _aim(rest_dir, target_dir, twist_deg=0.0):
    """Armature-space rotation taking `rest_dir` onto `target_dir`.

    Shortest arc, so a bone keeps as much of its rest roll as possible and
    never flips; `twist_deg` then spins it about its own new axis, which is
    how a forearm pronates without the elbow moving.
    """
    align = rest_dir.rotation_difference(target_dir)
    if abs(twist_deg) < 1e-9:
        return align
    return Quaternion(target_dir, math.radians(twist_deg)) @ align


def _euler(pitch, yaw, roll):
    """Armature-space Euler degrees -> quaternion.

    pitch + tips the part BACKWARD (about the character's right-left axis)
    yaw   + turns to his left
    roll  + leans his right shoulder down

    The pitch sign is the one to be careful with, and this docstring used to
    have it backwards -- it read "+ bows forward". Measured off the rest pose,
    one axis at a time, with the head's position taken relative to the pelvis:

        spine lean -30 -> head 0.241 m in FRONT of the pelvis
        spine lean   0 -> head 0.055 m in front
        spine lean +30 -> head 0.133 m BEHIND it

        hips pitch -30 -> head 0.374 m in front
        hips pitch +30 -> head 0.278 m behind

        head pitch moves the head bone's own origin by under 2 cm either way:
        it aims the face, it does not carry the skull across the frame. What
        carries a head is the spine chain underneath it.

    Run_Drive found this first ("needed a negative lean and for years had a
    positive one") and fixed itself; the wrong docstring then sent the next
    pass the same way round again, which is why STANCE, both hit reactions and
    all four strikes were authored reclining. Fixing the text rather than the
    sign is deliberate: every clip in wrestling_clips.py is expressed against
    this convention, and flipping it would move all 29 at once.
    """
    return mathutils.Euler(
        (math.radians(-pitch), math.radians(-roll), math.radians(-yaw)), "XYZ"
    ).to_quaternion()


class RigPoser:
    """Applies solved poses to one armature and keyframes the result."""

    def __init__(self, arm):
        self.arm = arm
        self.rest = {b.name: b.matrix_local.copy() for b in arm.data.bones}
        self.rest_dir = {}
        for b in arm.data.bones:
            self.rest_dir[b.name] = (b.tail_local - b.head_local).normalized()
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"

    # --- plumbing --------------------------------------------------------

    def _update(self):
        bpy.context.view_layer.update()

    def _set(self, name, rot, head=None):
        """Orient `name` by an armature-space rotation of its rest basis.

        Assigning `pose_bone.matrix` lets Blender solve the local basis
        against whatever the parent chain is already doing, so a pose is
        absolute: an arm aimed forward is forward regardless of the spine.
        """
        pb = self.arm.pose.bones[name]
        basis = self.rest[name].to_3x3()
        m = (rot.to_matrix() @ basis).to_4x4()
        m.translation = pb.head if head is None else head
        pb.matrix = m
        self._update()

    def _reset(self):
        for pb in self.arm.pose.bones:
            pb.matrix_basis = Matrix()
        self._update()

    def bone_head(self, name):
        return self.arm.pose.bones[name].head.copy()

    def bone_tail(self, name):
        return self.arm.pose.bones[name].tail.copy()

    # --- solvers ---------------------------------------------------------

    def _two_bone_ik(self, upper, lower, target, pole):
        """Plant `lower`'s tail on `target`, bending the joint toward `pole`.

        Standard law-of-cosines solve. The reach is clamped just short of
        full extension: a perfectly straight limb is both a singularity for
        the pole and, on a wrestler, a locked knee that reads as a stilt.
        """
        root = self.bone_head(upper)
        l1 = self.arm.data.bones[upper].length
        l2 = self.arm.data.bones[lower].length

        to_target = target - root
        dist = _clamp(to_target.length, 1e-4, (l1 + l2) * 0.995)
        direction = to_target.normalized()

        cos_a = _clamp((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
        angle = math.acos(cos_a)

        axis = direction.cross(pole)
        if axis.length < 1e-5:
            axis = direction.cross(Vector((0.0, 0.0, 1.0)))
        if axis.length < 1e-5:
            axis = direction.cross(Vector((1.0, 0.0, 0.0)))
        axis.normalize()

        upper_dir = (Quaternion(axis, angle) @ direction).normalized()
        joint = root + upper_dir * l1
        lower_dir = (root + direction * dist - joint).normalized()

        self._set(upper, _aim(self.rest_dir[upper], upper_dir))
        self._set(lower, _aim(self.rest_dir[lower], lower_dir))
        return joint

    def _curl_fingers(self, side, amount):
        """0 = open hand, 1 = closed fist.

        A strike thrown with an open hand reads as a slap at any speed, and
        the rig carries the finger bones already. Useful values, read off
        rendered frames rather than picked: 0.0 a flat pressing palm, 0.45
        a loose hand hanging, 0.6 a grip closed around a collar or an arm,
        0.75 a guard, 1.0 a thrown fist. Below about 0.5 the fingers are
        still mostly straight and the hand reads as a claw.
        """
        if amount <= 0.0:
            return
        for finger in FINGERS:
            for i, seg in enumerate(("01", "02", "03")):
                name = "%s_%s_%s" % (finger, seg, side)
                if name not in self.arm.pose.bones:
                    continue
                # The knuckle curls furthest; the tip segments follow it.
                # About the bone's LOCAL X, which is the finger's hinge --
                # measured, because local Z (tried first) splays the fingers
                # sideways in the plane of the palm and renders as a claw.
                # The sign is the same on both hands: local X maps to -Y on
                # the right and +Y on the left, so +deg folds both inward.
                deg = (58.0, 72.0, 62.0)[i] * amount
                pb = self.arm.pose.bones[name]
                pb.rotation_quaternion = mathutils.Euler(
                    (math.radians(deg), 0.0, 0.0), "XYZ"
                ).to_quaternion()
        thumb = "thumb_01_%s" % side
        if thumb in self.arm.pose.bones:
            deg = 40.0 * amount
            self.arm.pose.bones[thumb].rotation_quaternion = mathutils.Euler(
                (math.radians(deg), 0.0, 0.0), "XYZ"
            ).to_quaternion()
        self._update()

    # --- the pose interface ----------------------------------------------

    def apply(self, pose):
        """Solve one pose.

        Keys, all optional (see wrestling_clips.py for worked examples):

          pelvis      (right, fwd, up) absolute position, metres
          hips        (pitch, yaw, roll) degrees
          spine       (lean, twist, side) degrees RELATIVE to the hips,
                      spread cumulatively over spine_01..03
          head        (pitch, yaw, roll) degrees relative to the chest
          hand_r/l    (right, fwd, up) absolute wrist target
          elbow_r/l   (right, fwd, up) pole direction the elbow points down
          wrist_r/l   (pitch, yaw, roll) degrees on the hand bone
          fist_r/l    0..1 finger curl
          foot_r/l    (right, fwd, up) absolute ankle target
          knee_r/l    (right, fwd, up) pole direction the knee points
          ankle_r/l   (pitch, yaw, roll) degrees on the foot bone
          clav_r/l    (pitch, yaw, roll) degrees on the clavicle
        """
        self._reset()

        pelvis_pos = pose.get("pelvis")
        hips = pose.get("hips", (0.0, 0.0, 0.0))
        head_pos = vec(*pelvis_pos) if pelvis_pos else None
        if head_pos is not None:
            # `pelvis` names where the hip joint sits, so lift to the bone head.
            head_pos = Vector((head_pos.x, head_pos.y, head_pos.z))
        self._set("pelvis", _euler(*hips), head_pos)

        # `spine` and `head` are read RELATIVE to the hips, so they compose
        # with them rather than replacing them. Setting each absolutely
        # (tried first) left the torso standing vertically while the pelvis
        # lay back, and Down_Supine rendered as a man doing a sit-up on the
        # canvas instead of lying on it.
        body = _euler(*hips)

        lean, twist, side = pose.get("spine", (0.0, 0.0, 0.0))
        # Cumulative down the chain: the lower back carries a quarter of the
        # bend and the chest carries all of it, which is what stops a lean
        # reading as a single hinge at the hips.
        spine_total = _euler(lean, twist, side)
        for name, share in zip(SPINE, (0.25, 0.60, 1.00)):
            self._set(name, body @ _euler(lean * share, twist * share, side * share))

        chest = body @ spine_total
        neck_pitch, neck_yaw, neck_roll = pose.get("head", (0.0, 0.0, 0.0))
        self._set("neck_01",
                  chest @ _euler(neck_pitch * 0.4, neck_yaw * 0.4, neck_roll * 0.4))
        self._set("Head", chest @ _euler(neck_pitch, neck_yaw, neck_roll))

        for side_id in ("r", "l"):
            clav = pose.get("clav_%s" % side_id)
            if clav:
                self._set("clavicle_%s" % side_id, chest @ _euler(*clav))

            hand = pose.get("hand_%s" % side_id)
            if hand:
                # Elbows hang down and just behind the hands. An outward
                # pole (tried first) reads as chicken-winged, which is the
                # one thing a wrestler's guard never looks like.
                default_pole = vec(0.16 if side_id == "r" else -0.16, -0.38, -0.91)
                pole = pose.get("elbow_%s" % side_id)
                pole = vec(*pole).normalized() if pole else default_pole.normalized()
                elbow_at = self._two_bone_ik(
                    "upperarm_%s" % side_id, "lowerarm_%s" % side_id,
                    vec(*hand), pole,
                )
                # A hand on the mat lies flat on it: rest orientation (palm
                # down, fingers out), turned to carry on the line of the
                # forearm. Left to the chain it points wherever the forearm
                # does, and on a man lying down that put the fingers 17 cm
                # through the canvas.
                if hand[2] <= 0.13 and not pose.get("wrist_%s" % side_id):
                    at = vec(*hand)
                    heading = Vector((at.x - elbow_at.x, at.y - elbow_at.y, 0.0))
                    rest = self.rest_dir["hand_%s" % side_id]
                    rest = Vector((rest.x, rest.y, 0.0))
                    if heading.length > 1e-4 and rest.length > 1e-4:
                        turn = rest.normalized().rotation_difference(heading.normalized())
                        turn = Quaternion((0.0, 0.0, 1.0), turn.to_euler("XYZ").z)
                        self._set("hand_%s" % side_id, turn)
            wrist = pose.get("wrist_%s" % side_id)
            if wrist:
                rot = _euler(*wrist) @ Quaternion(
                    self.arm.pose.bones["hand_%s" % side_id].y_axis, 0.0
                )
                self._set("hand_%s" % side_id, rot)
            self._curl_fingers(side_id, pose.get("fist_%s" % side_id, 0.0))

            foot = pose.get("foot_%s" % side_id)
            if foot:
                # A standing knee points forward and very slightly outward.
                # Ground work needs this overridden: a man on his back with
                # his knees up bends them toward the ceiling, and the
                # standing default would straighten his legs out flat.
                knee = pose.get("knee_%s" % side_id)
                knee_pole = vec(*knee) if knee \
                    else vec(0.25 if side_id == "r" else -0.25, 1.0, 0.05)
                knee_at = self._two_bone_ik(
                    "thigh_%s" % side_id, "calf_%s" % side_id,
                    vec(*foot), knee_pole.normalized(),
                )
                # A planted foot is flat on the canvas. Left to the chain it
                # inherits the calf's tilt, and in STANCE that dug the right
                # toes 5 cm into the mat -- measured, and true of every
                # standing pose in the set. So a foot on the mat takes its
                # rest orientation (sole flat), turned only to follow the
                # knee. Standing and knees-up poses only: a man face down
                # rests on his toes, not his soles.
                upright = abs(hips[0]) <= 60.0 or (knee and knee[2] >= 0.5)
                if foot[2] <= 0.12 and upright and not pose.get("ankle_%s" % side_id) \
                        and not pose.get("free_feet"):
                    hip_at = self.bone_head("thigh_%s" % side_id)
                    heading = Vector((knee_at.x - hip_at.x, knee_at.y - hip_at.y, 0.0))
                    if knee and knee[2] >= 0.5:
                        heading = Vector((0.0, -1.0, 0.0))
                    if heading.length > 1e-4:
                        turn = Vector((0.0, -1.0, 0.0)).rotation_difference(heading.normalized())
                        # Yaw only: a knee well out to the side still leaves
                        # the foot on the mat.
                        turn = Quaternion((0.0, 0.0, 1.0), turn.to_euler("XYZ").z)
                        self._set("foot_%s" % side_id, turn)
            ankle = pose.get("ankle_%s" % side_id)
            if ankle:
                self._set("foot_%s" % side_id, _euler(*ankle))

    # --- keyframing ------------------------------------------------------

    def key(self, frame, bones):
        """Key the current solved pose at `frame` for every bone in `bones`."""
        for name in bones:
            pb = self.arm.pose.bones[name]
            pb.keyframe_insert("rotation_quaternion", frame=frame)
        self.arm.pose.bones["pelvis"].keyframe_insert("location", frame=frame)


def keyed_bones(arm):
    """Every bone a clip writes: the whole body, so no clip inherits a limb
    from whatever the AnimationTree happened to be blending from."""
    return [b.name for b in arm.pose.bones]
