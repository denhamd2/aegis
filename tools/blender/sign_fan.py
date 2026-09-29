#!/usr/bin/env python3
"""Export the sign fan: one ringside spectator who stands and holds up a sign.

    python3 tools/blender/sign_fan.py [--out game/assets/environment/sign_fan.glb]

Two of these sit in the ringside rows opposite the hard camera
(core/arena/sign_fans.gd), each with his own sign: ENDA FEARS OMAR and CODY
SUCKS (game/assets/environment/signs/). They sit for most of the match and get
up and hold the sign over their heads now and then -- for the stare-down
before the bell, and once or twice more -- the way the owner's two reference
photographs of a WWE crowd show it done: up on their feet, the board over the
head at arm's length, a hand on each side edge, pumped.

What this is, and why it is rigged
----------------------------------
The rest of the crowd is baked, unrigged box figures (crowd.py / floor_crowd.py)
-- nine boxes a person, animated if at all by a vertex shader, because
thousands of skinned characters is not a thing that runs. Two people who have
to stand up, lift a board over their heads and sit back down cannot be a
vertex shader. So this is the SAME figure -- the same boxes, the same
proportions, the same flat shirt-and-skin dressing -- on a 14-bone armature,
every box weighted 100% to one bone, which is as cheap as skinning gets.

The board is its own bone. Its path is keyed (lifted off the lap, up past the
chest, over the head, pumped), and the arms are SOLVED to it every frame --
two-bone IK from each shoulder to a point on each side edge -- so the hands are
on the sign in every frame by construction rather than by keyframe luck. The
legs are solved the same way to feet that stay planted while he stands up.

Frame
-----
Built facing Blender -Y, which glTF's Y-up conversion turns into Godot +Z --
the frame floor_crowd.py builds in and the one a ringside chair's transform
expects. Seated, his backside is at the chair's 0.45 m seat height
(crowd.CHAIR_SEAT_HEIGHT), so he drops onto a chair transform unchanged.

Clips (30 fps; names as they come out of the .glb)
-----------------------------------------------------
  Fan_Seated  90 f  loop   sat, board face-down on his knees, a slow sway
  Fan_Rise    36 f         up out of the chair, the board up past his chest
  Fan_Hold    60 f  loop   board over his head, pumped twice, rocked side to side
  Fan_Lower   30 f         the board down and back into the chair

Materials: M_Shirt, M_Skin, M_Dark (trousers, shoes, hair), M_SignFace (UVs
0-1 across the front), M_SignBack (bare board). The game dresses the shirt and
puts the picture on the face per fan.

Deterministic: no randomness anywhere, so the same script writes the same file.
"""

from __future__ import annotations

import argparse
import math
import pathlib
import sys

import bpy
import bmesh
from mathutils import Matrix, Quaternion, Vector

import bpy_exit

REPO = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_OUT = REPO / "game" / "assets" / "environment" / "sign_fan.glb"

FPS = 30

# --- Rest skeleton (standing, facing -Y), metres ---------------------------
# name: (head, tail, parent)
BONES = {
    "root": ((0, 0, 0), (0, 0, 0.1), None),
    "pelvis": ((0, 0, 0.95), (0, 0, 1.05), "root"),
    "spine": ((0, 0, 1.0), (0, 0, 1.45), "pelvis"),
    "head": ((0, 0, 1.47), (0, 0, 1.75), "spine"),
    "upperarm_l": ((0.24, 0, 1.42), (0.24, 0, 1.13), "spine"),
    "forearm_l": ((0.24, 0, 1.13), (0.24, 0, 0.80), "upperarm_l"),
    "upperarm_r": ((-0.24, 0, 1.42), (-0.24, 0, 1.13), "spine"),
    "forearm_r": ((-0.24, 0, 1.13), (-0.24, 0, 0.80), "upperarm_r"),
    "thigh_l": ((0.10, 0, 0.93), (0.10, 0, 0.50), "pelvis"),
    "shin_l": ((0.10, 0, 0.50), (0.10, 0, 0.06), "thigh_l"),
    "thigh_r": ((-0.10, 0, 0.93), (-0.10, 0, 0.50), "pelvis"),
    "shin_r": ((-0.10, 0, 0.50), (-0.10, 0, 0.06), "thigh_r"),
    "sign": ((0, 0, 1.90), (0, 0, 2.00), "root"),
}
UPPER_ARM = 0.29
FOREARM = 0.33
THIGH = 0.43
SHIN = 0.44

# The board: a sheet of poster board at the pictures' 3:2.
SIGN_W = 0.84
SIGN_H = 0.56
SIGN_T = 0.012
# The board's centre above its bone's head.
SIGN_UP = 0.05

# (bone, centre, size, material) -- material 0 shirt, 1 skin, 2 dark.
BOXES = [
    ("pelvis", (0, 0, 0.93), (0.34, 0.22, 0.20), 2),
    ("spine", (0, 0, 1.22), (0.38, 0.24, 0.46), 0),
    ("head", (0, 0, 1.50), (0.12, 0.12, 0.08), 1),
    ("head", (0, 0, 1.62), (0.19, 0.21, 0.22), 1),
    ("head", (0, 0.01, 1.74), (0.20, 0.22, 0.05), 2),
    ("upperarm_l", (0.24, 0, 1.28), (0.11, 0.12, 0.30), 0),
    ("forearm_l", (0.24, 0, 0.98), (0.09, 0.09, 0.28), 1),
    ("forearm_l", (0.24, 0, 0.82), (0.08, 0.10, 0.10), 1),
    ("upperarm_r", (-0.24, 0, 1.28), (0.11, 0.12, 0.30), 0),
    ("forearm_r", (-0.24, 0, 0.98), (0.09, 0.09, 0.28), 1),
    ("forearm_r", (-0.24, 0, 0.82), (0.08, 0.10, 0.10), 1),
    ("thigh_l", (0.10, 0, 0.72), (0.15, 0.17, 0.44), 2),
    ("shin_l", (0.10, 0, 0.29), (0.13, 0.14, 0.44), 2),
    ("shin_l", (0.10, -0.04, 0.04), (0.11, 0.26, 0.08), 2),
    ("thigh_r", (-0.10, 0, 0.72), (0.15, 0.17, 0.44), 2),
    ("shin_r", (-0.10, 0, 0.29), (0.13, 0.14, 0.44), 2),
    ("shin_r", (-0.10, -0.04, 0.04), (0.11, 0.26, 0.08), 2),
]


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def make_armature():
    data = bpy.data.armatures.new("SignFanRig")
    arm = bpy.data.objects.new("SignFanRig", data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, parent) in BONES.items():
        b = data.edit_bones.new(name)
        b.head = head
        b.tail = tail
        # Roll fixed so every bone's local X is world X at rest: the boxes'
        # widths stay square to the body whatever the solve does.
        b.align_roll(Vector((0, -1, 0)))
        if parent:
            b.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def _material(name: str, colour) -> bpy.types.Material:
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    return m


def _box(bm, centre, size, mat, layer, group_of, bone, uv_face=None):
    cx, cy, cz = centre
    sx, sy, sz = (s * 0.5 for s in size)
    verts = [bm.verts.new((cx + x * sx, cy + y * sy, cz + z * sz))
             for x, y, z in ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                             (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1))]
    faces = [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (3, 2, 1, 0), (4, 5, 6, 7)]
    made = []
    for f in faces:
        face = bm.faces.new([verts[i] for i in f])
        face.material_index = mat
        made.append(face)
    for v in verts:
        group_of[v] = bone
    if uv_face is not None:
        # The front (-Y) face carries the picture, 0-1 across it: +X is the
        # viewer's right, +Z the top.
        front = made[0]
        front.material_index = uv_face
        for loop in front.loops:
            co = loop.vert.co
            loop[layer].uv = ((co.x - (cx - sx)) / (2 * sx), (co.z - (cz - sz)) / (2 * sz))
    return made


def make_mesh(name, boxes, materials, arm, sign=False):
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for m in materials:
        mesh.materials.append(m)
    bm = bmesh.new()
    layer = bm.loops.layers.uv.new("UVMap")
    group_of = {}
    for bone, centre, size, mat in boxes:
        _box(bm, centre, size, mat, layer, group_of, bone, uv_face=0 if sign else None)
    bm.verts.index_update()
    order = {v.index: group_of[v] for v in bm.verts}
    bm.to_mesh(mesh)
    bm.free()
    groups = {}
    for i, bone in sorted(order.items()):
        if bone not in groups:
            groups[bone] = obj.vertex_groups.new(name=bone)
        groups[bone].add([i], 1.0, "REPLACE")
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return obj


# --- Posing ------------------------------------------------------------------

def rot_x(a: float) -> Quaternion:
    return Quaternion((1, 0, 0), a)


def _two_bone(root: Vector, target: Vector, a: float, b: float, pole: Vector):
    """Elbow/knee and wrist/ankle for a two-bone chain reaching `target`."""
    to = target - root
    d = max(abs(a - b) + 1e-3, min(to.length, (a + b) * 0.999))
    direction = to.normalized()
    perp = pole - direction * pole.dot(direction)
    perp.normalize()
    cos_a = (a * a + d * d - b * b) / (2 * a * d)
    sin_a = math.sqrt(max(0.0, 1.0 - cos_a * cos_a))
    mid = root + direction * (a * cos_a) + perp * (a * sin_a)
    return mid, root + direction * d


class Pose:
    """One frame of the fan, as the few numbers that decide it."""

    def __init__(self, pelvis, tilt, lean, nod, sign_at, sign_rot, feet_y, arm_pole):
        self.pelvis = Vector(pelvis)
        self.tilt = tilt
        self.lean = lean
        self.nod = nod
        self.sign_at = Vector(sign_at)       # the board's centre
        self.sign_rot = sign_rot             # Quaternion
        self.feet_y = feet_y
        self.arm_pole = Vector(arm_pole)     # for the +X arm; mirrored for -X

    def lerp(self, other: "Pose", t: float) -> "Pose":
        s = t * t * (3.0 - 2.0 * t)
        return Pose(self.pelvis.lerp(other.pelvis, s),
                    self.tilt + (other.tilt - self.tilt) * s,
                    self.lean + (other.lean - self.lean) * s,
                    self.nod + (other.nod - self.nod) * s,
                    self.sign_at.lerp(other.sign_at, s),
                    self.sign_rot.slerp(other.sign_rot, s),
                    self.feet_y + (other.feet_y - self.feet_y) * s,
                    self.arm_pole.lerp(other.arm_pole, s))


def _rest(arm, name):
    bone = arm.data.bones[name]
    return bone.matrix_local.copy(), Vector(BONES[name][0]), \
        (Vector(BONES[name][1]) - Vector(BONES[name][0])).normalized()


def _place(arm, name, head: Vector, rot: Quaternion) -> None:
    rest, rest_head, _ = _rest(arm, name)
    arm.pose.bones[name].matrix = (Matrix.Translation(head) @ rot.to_matrix().to_4x4()
                                   @ Matrix.Translation(-rest_head) @ rest)
    bpy.context.view_layer.update()


def _aim(arm, name, head: Vector, toward: Vector) -> None:
    _, _, rest_dir = _rest(arm, name)
    _place(arm, name, head, rest_dir.rotation_difference((toward - head).normalized()))


def apply(arm, p: Pose) -> None:
    ident = Quaternion()
    _place(arm, "root", Vector((0, 0, 0)), ident)
    r_pelvis = rot_x(p.tilt)
    _place(arm, "pelvis", p.pelvis, r_pelvis)
    spine_head = p.pelvis + r_pelvis @ Vector((0, 0, 0.05))
    r_spine = rot_x(p.lean)
    _place(arm, "spine", spine_head, r_spine)
    _place(arm, "head", spine_head + r_spine @ Vector((0, 0, 0.47)), rot_x(p.lean + p.nod))
    # The board: its bone sits SIGN_UP below the centre, along the board.
    _place(arm, "sign", p.sign_at - p.sign_rot @ Vector((0, 0, SIGN_UP)), p.sign_rot)
    for side in (1.0, -1.0):
        s = "l" if side > 0 else "r"
        shoulder = spine_head + r_spine @ Vector((0.24 * side, 0, 0.42))
        # A hand on each side edge, from behind, a little below the middle.
        grip = p.sign_at + p.sign_rot @ Vector((0.40 * side, 0.03, -0.05))
        pole = Vector((p.arm_pole.x * side, p.arm_pole.y, p.arm_pole.z))
        elbow, wrist = _two_bone(shoulder, grip, UPPER_ARM, FOREARM, pole)
        _aim(arm, "upperarm_" + s, shoulder, elbow)
        _aim(arm, "forearm_" + s, elbow, wrist)
        hip = p.pelvis + r_pelvis @ Vector((0.10 * side, 0, -0.02))
        ankle = Vector((0.13 * side, p.feet_y, 0.06))
        knee, foot = _two_bone(hip, ankle, THIGH, SHIN, Vector((0, -1, 0.1)))
        _aim(arm, "thigh_" + s, hip, knee)
        _aim(arm, "shin_" + s, knee, foot)


# The poses, as numbers. Face-down on the knees; lifted; over the head.
FLAT = rot_x(math.radians(90))   # face (-Y) turned to the floor
UP = Quaternion()                # face to the ring
SEATED = Pose((0, 0.02, 0.57), -0.10, 0.12, 0.08, (0, -0.24, 0.67), FLAT, -0.40, (1, 0.8, -0.3))
PUSH_UP = Pose((0, -0.10, 0.66), 0.10, 0.50, -0.10, (0, -0.36, 0.86), rot_x(math.radians(45)),
               -0.40, (1, 0.6, -0.4))
RISING = Pose((0, -0.30, 0.88), 0.0, 0.16, 0.0, (0, -0.38, 1.26), rot_x(math.radians(8)),
              -0.40, (1, 0.5, -0.5))
LIFTING = Pose((0, -0.36, 0.945), 0.0, 0.0, -0.05, (0, -0.30, 1.72), UP, -0.40, (1, 0.4, -0.2))
OVERHEAD = Pose((0, -0.37, 0.95), 0.0, -0.04, -0.10, (0, -0.22, 2.02), UP, -0.40, (1, 0.35, 0.0))


def _hold(t: float) -> Pose:
    """Fan_Hold at `t` of its loop: pumped twice, rocked once each way."""
    phase = 2.0 * math.pi * t
    pump = 0.06 * max(0.0, math.sin(2.0 * phase))
    rock = math.radians(5.0) * math.sin(phase)
    at = OVERHEAD.sign_at + Vector((0.05 * math.sin(phase), 0, pump))
    rot = Quaternion((0, 1, 0), rock)
    return Pose(OVERHEAD.pelvis + Vector((0, 0, -0.01 * pump / 0.06)), 0.0,
                OVERHEAD.lean, OVERHEAD.nod, at, rot, OVERHEAD.feet_y, OVERHEAD.arm_pole)


def _seated(t: float) -> Pose:
    """Fan_Seated at `t` of its loop: a slow lean in and back."""
    sway = math.sin(2.0 * math.pi * t)
    return Pose(SEATED.pelvis, SEATED.tilt, SEATED.lean + 0.05 * sway,
                SEATED.nod + 0.03 * sway, SEATED.sign_at + Vector((0, -0.01 * sway, 0)),
                SEATED.sign_rot, SEATED.feet_y, SEATED.arm_pole)


def _path(keys):
    """A pose-at-t function through (t, Pose) keys, smoothstepped between."""
    def at(t: float) -> Pose:
        for (t0, p0), (t1, p1) in zip(keys, keys[1:]):
            if t <= t1:
                return p0.lerp(p1, (t - t0) / (t1 - t0) if t1 > t0 else 1.0)
        return keys[-1][1]
    return at


CLIPS = [
    ("Fan_Seated", 90, _seated),
    ("Fan_Rise", 36, _path([(0.0, SEATED), (0.30, PUSH_UP), (0.55, RISING),
                            (0.80, LIFTING), (1.0, _hold(0.0))])),
    ("Fan_Hold", 60, _hold),
    ("Fan_Lower", 30, _path([(0.0, _hold(0.0)), (0.25, LIFTING), (0.55, RISING),
                             (0.78, PUSH_UP), (1.0, SEATED)])),
]


def bake(arm) -> None:
    arm.animation_data_create()
    for name, frames, pose_at in CLIPS:
        action = bpy.data.actions.new(name)
        arm.animation_data.action = action
        for f in range(frames + 1):
            apply(arm, pose_at(f / frames))
            for bone in BONES:
                pb = arm.pose.bones[bone]
                pb.keyframe_insert("location", frame=f)
                pb.keyframe_insert("rotation_quaternion", frame=f)
        for fc in action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
        action.use_fake_user = True
    arm.animation_data.action = None
    for bone in BONES:
        pb = arm.pose.bones[bone]
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    args = parser.parse_args(argv)
    reset_scene()
    arm = make_armature()
    shirt = _material("M_Shirt", (0.8, 0.8, 0.8))
    skin = _material("M_Skin", (0.55, 0.40, 0.32))
    dark = _material("M_Dark", (0.06, 0.06, 0.07))
    face = _material("M_SignFace", (1.0, 1.0, 1.0))
    back = _material("M_SignBack", (0.72, 0.68, 0.60))
    make_mesh("FanBody", BOXES, [shirt, skin, dark], arm)
    make_mesh("FanSign", [("sign", (0, 0, 1.90 + SIGN_UP), (SIGN_W, SIGN_T, SIGN_H), 1)],
              [face, back], arm, sign=True)
    bake(arm)
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_apply=False,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )
    print("sign_fan: %d bones, %d clips, %s" % (len(BONES), len(CLIPS), out))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main(sys.argv[1:]))
