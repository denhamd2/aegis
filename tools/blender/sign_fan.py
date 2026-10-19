#!/usr/bin/env python3
"""Export the sign fans: ringside spectators who stand and hold up a sign.

    python3 tools/blender/sign_fan.py        # needs tools/blender/fetch_rocketbox.sh's checkout

Four of these sit in the ringside rows opposite the hard camera
(core/arena/sign_fans.gd), each with his own sign (game/assets/environment/
signs/). They sit for most of the match and get up and hold the sign over
their heads now and then -- for the stare-down before the bell, the opening's
ENDA FEARS OMAR cutaway, and once or twice more -- the way the owner's two
reference photographs of a WWE crowd show it done: up on their feet, the board
over the head at arm's length, a hand on each side edge, pumped.

Real people, not boxes (the owner, 19 Oct: "The fan holding the Enda Fears
Omar sign is blocky ... make him very realistic"). Each fan is a Microsoft
Rocketbox avatar (MIT; the same library the crowd is built from, see
game/assets/environment/CREDITS.md) with his own textures and his own full
skeleton. The opening cutaway frames the ENDA fan alone at a few metres, so he
is the avatar at full resolution, not the crowd's baked point colour.

How he is posed
---------------
The board is a bone of its own. Its path is keyed (lifted off the lap, up past
the chest, over the head, pumped), and the body is SOLVED to it every frame:
two-bone IK from each shoulder to a wrist just under each side edge, the hand
turned up along the edge; the legs to feet that stay planted while he stands
up; the spine leaning and the head nodding by the few numbers in `Pose`. The
hands are on the sign in every frame by construction rather than by keyframe
luck. Fingers, face and toes keep the avatar's own rest shapes.

Frame
-----
Rocketbox avatars face Blender -Y, which glTF's Y-up conversion turns into
Godot +Z -- the frame a ringside chair's transform expects. Seated, his
backside is at the chair's 0.45 m seat height.

Clips (30 fps; names as they come out of the .glb)
-----------------------------------------------------
  Fan_Seated  90 f  loop   sat, board face-down on his knees, a slow sway
  Fan_Rise    36 f         up out of the chair, the board up past his chest
  Fan_Hold    60 f  loop   board over his head, pumped twice, rocked side to side
  Fan_Lower   30 f         the board down and back into the chair

Output: game/assets/environment/sign_fan_<n>.glb, one per seat in
SignFans.FANS. Materials: the avatar's (textured), M_SignFace (UVs 0-1 across
the front) and M_SignBack. Deterministic: no randomness; textures resized and
written by PIL with fixed settings.
"""

from __future__ import annotations

import math
import pathlib
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector
import numpy as np
from PIL import Image

import bpy_exit

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import rocketbox_crowd  # noqa: E402  -- the checkout's location and pinned commit

REPO = HERE.parents[1]
OUT_DIR = REPO / "game" / "assets" / "environment"
TEX_DIR = OUT_DIR / "sign_fan_textures"

FPS = 30
## One per seat in SignFans.FANS, in order: the ENDA FEARS OMAR fan first.
AVATARS = ("Male_Adult_04", "Male_Adult_10", "Male_Adult_06", "Male_Adult_12")
## Body and head textures at this size (the cutaway frames him at a few metres).
TEX_SIZE = 1024

# The board: a sheet of poster board at the pictures' 3:2.
SIGN_W = 0.84
SIGN_H = 0.56
SIGN_T = 0.012
SIGN_BONE = "FanSign"
SIGN_REST = Vector((0.0, 0.0, 1.90))

SPINE = ["Bip01 Spine", "Bip01 Spine1", "Bip01 Spine2"]


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


# --- the avatar --------------------------------------------------------------

def _image(path: pathlib.Path, size: int, alpha: bool, out_name: str) -> bpy.types.Image:
    """A Rocketbox colour map, resized and saved beside the export (JPEG for
    opaque colour, PNG where the alpha cuts hair and lashes)."""
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    (TEX_DIR / ".gdignore").write_text("")
    img = Image.open(path)
    img = img.convert("RGBA" if alpha else "RGB").resize((size, size), Image.LANCZOS)
    out = TEX_DIR / (out_name + (".png" if alpha else ".jpg"))
    if alpha:
        img.save(out, optimize=False)
    else:
        img.save(out, quality=90, optimize=False, subsampling=0)
    return bpy.data.images.load(str(out))


def _material(name: str, image: bpy.types.Image, alpha: bool, roughness: float) -> bpy.types.Material:
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    if alpha:
        m.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        m.blend_method = "CLIP"
        m.alpha_threshold = 0.45
    return m


def load_avatar(avatar: str, n: int):
    folder = rocketbox_crowd.rocketbox_root() / "Assets" / "Avatars" / "Adults" / avatar
    bpy.ops.import_scene.fbx(filepath=str(folder / "Export" / (avatar + ".fbx")))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = next(o for o in bpy.data.objects if o.type == "MESH")
    for o in list(bpy.data.objects):
        if o.type not in ("ARMATURE", "MESH"):
            bpy.data.objects.remove(o)
    # bake the FBX's centimetre scale into the rig and the mesh: posing below
    # works in metres, in the armature's own space
    for o in (arm, body):
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # the FBX's own take is in the old centimetre space: drop it, and parent
    # the mesh to the rig afresh so no centimetre parent-inverse rides along
    if arm.animation_data:
        arm.animation_data.action = None
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    world = body.matrix_world.copy()
    body.parent = arm
    body.matrix_parent_inverse.identity()
    body.matrix_world = world
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    arm.name = "SignFanRig"
    body.name = "FanBody"
    # its own colour maps, not the dangling paths the FBX carries
    colours = {p.stem.split("_")[1]: p for p in sorted((folder / "Textures").glob("*_color.tga"))}
    for slot in body.material_slots:
        kind = slot.material.name.split("_")[-1]
        alpha = kind == "opacity"
        size = 512 if alpha else TEX_SIZE
        image = _image(colours[kind], size, alpha, "fan%d_%s" % (n, kind))
        slot.material = _material("M_Fan%d_%s" % (n, kind), image, alpha,
                                  0.55 if kind == "head" else 0.8)
    return arm, body


def add_sign(arm) -> bpy.types.Object:
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    b = arm.data.edit_bones.new(SIGN_BONE)
    b.head = SIGN_REST
    b.tail = SIGN_REST + Vector((0.0, 0.0, 0.1))
    b.align_roll(Vector((0, -1, 0)))
    bpy.ops.object.mode_set(mode="OBJECT")
    mesh = bpy.data.meshes.new("FanSign")
    obj = bpy.data.objects.new("FanSign", mesh)
    bpy.context.collection.objects.link(obj)
    hx, hy, hz = SIGN_W * 0.5, SIGN_T * 0.5, SIGN_H * 0.5
    c = SIGN_REST
    v = [(c.x + x * hx, c.y + y * hy, c.z + z * hz)
         for x, y, z in ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                         (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1))]
    faces = [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (3, 2, 1, 0), (4, 5, 6, 7)]
    mesh.from_pydata(v, [], faces)
    face = bpy.data.materials.new("M_SignFace")
    back = bpy.data.materials.new("M_SignBack")
    mesh.materials.append(face)
    mesh.materials.append(back)
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        poly.material_index = 0 if poly.index == 0 else 1
    # the front (-Y) face carries the picture, 0-1 across it: +X is the
    # viewer's right, +Z the top
    for li in mesh.polygons[0].loop_indices:
        co = mesh.vertices[mesh.loops[li].vertex_index].co
        uv.data[li].uv = ((co.x - (c.x - hx)) / SIGN_W, (co.z - (c.z - hz)) / SIGN_H)
    g = obj.vertex_groups.new(name=SIGN_BONE)
    g.add(list(range(8)), 1.0, "REPLACE")
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return obj


# --- posing ------------------------------------------------------------------

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


class Rig:
    """The avatar's skeleton at rest, and how to put a bone somewhere."""

    def __init__(self, arm):
        self.arm = arm
        self.rest = {b.name: b.matrix_local.copy() for b in arm.data.bones}
        self.head = {b.name: b.head_local.copy() for b in arm.data.bones}
        self.tail = {b.name: b.tail_local.copy() for b in arm.data.bones}
        self.moved: list[str] = []

    def length(self, a: str, b: str) -> float:
        return (self.head[b] - self.head[a]).length

    def place(self, name: str, head: Vector, rot: Quaternion) -> None:
        """Bone `name` with its head at `head`, turned by `rot` from rest."""
        self.arm.pose.bones[name].matrix = (Matrix.Translation(head) @ rot.to_matrix().to_4x4()
                                            @ Matrix.Translation(-self.head[name]) @ self.rest[name])
        if name not in self.moved:
            self.moved.append(name)
        bpy.context.view_layer.update()

    def aim(self, name: str, head: Vector, toward: Vector, child: str | None = None) -> Quaternion:
        """Bone `name` at `head`, turned so its rest line to `child`'s head
        (or its own tail) points at `toward`. Returns the turn."""
        end = self.head[child] if child else self.tail[name]
        rest_dir = (end - self.head[name]).normalized()
        rot = rest_dir.rotation_difference((toward - head).normalized())
        self.place(name, head, rot)
        return rot


def apply(rig: Rig, p: Pose) -> None:
    h = rig.head
    # the pelvis, then the spine bending by `lean` over its three joints
    r = rot_x(p.tilt)
    rig.place("Bip01 Pelvis", p.pelvis, r)
    at = p.pelvis + r @ (h[SPINE[0]] - h["Bip01 Pelvis"])
    for k, name in enumerate(SPINE):
        r = rot_x(p.tilt * (1.0 - (k + 1) / 3.0) + p.lean * (k + 1) / 3.0)
        rig.place(name, at, r)
        nxt = SPINE[k + 1] if k + 1 < len(SPINE) else "Bip01 Neck"
        at = at + r @ (h[nxt] - h[name])
    chest = r
    neck_r = rot_x(p.lean + p.nod * 0.5)
    rig.place("Bip01 Neck", at, neck_r)
    head_at = at + neck_r @ (h["Bip01 Head"] - h["Bip01 Neck"])
    rig.place("Bip01 Head", head_at, rot_x(p.lean + p.nod))
    # the board: its bone at the centre
    rig.place(SIGN_BONE, p.sign_at, p.sign_rot)
    for side in (1.0, -1.0):
        s = "L" if side > 0 else "R"
        clav = "Bip01 %s Clavicle" % s
        upper, fore, hand = "Bip01 %s UpperArm" % s, "Bip01 %s Forearm" % s, "Bip01 %s Hand" % s
        clav_at = at + neck_r @ (h[clav] - h["Bip01 Neck"])
        rig.place(clav, clav_at, chest)
        shoulder = clav_at + chest @ (h[upper] - h[clav])
        # a hand on each side edge, from behind: the wrist just under the
        # edge, the hand turned up along it
        edge = p.sign_at + p.sign_rot @ Vector((0.41 * side, 0.03, -0.04))
        wrist_target = edge + p.sign_rot @ Vector((0.0, 0.035, -0.075))
        pole = Vector((p.arm_pole.x * side, p.arm_pole.y, p.arm_pole.z))
        elbow, wrist = _two_bone(shoulder, wrist_target, rig.length(upper, fore),
                                 rig.length(fore, hand), pole)
        rig.aim(upper, shoulder, elbow, fore)
        rig.aim(fore, elbow, wrist, hand)
        rig.aim(hand, wrist, edge + p.sign_rot @ Vector((0.0, 0.0, 0.05)), "Bip01 %s Finger2" % s)
        # the legs to planted feet
        thigh, calf, foot = "Bip01 %s Thigh" % s, "Bip01 %s Calf" % s, "Bip01 %s Foot" % s
        pr = rot_x(p.tilt)
        hip = p.pelvis + pr @ (h[thigh] - h["Bip01 Pelvis"])
        ankle = Vector((h[foot].x * 1.15, p.feet_y, h[foot].z))
        knee, ankle = _two_bone(hip, ankle, rig.length(thigh, calf), rig.length(calf, foot),
                                Vector((0, -1, 0.1)))
        rig.aim(thigh, hip, knee, calf)
        rig.aim(calf, knee, ankle, foot)
        rig.place(foot, ankle, Quaternion())          # flat on the floor


# The poses, as numbers. Face-down on the knees; lifted; over the head. Sized
# to a 1.87 m avatar whose hip joints stand at 0.895 m.
FLAT = rot_x(math.radians(90))   # face (-Y) turned to the floor
UP = Quaternion()                # face to the ring
SEATED = Pose((0, 0.04, 0.56), -0.12, 0.10, 0.08, (0, -0.30, 0.66), FLAT, -0.42, (1, 0.8, -0.3))
PUSH_UP = Pose((0, -0.08, 0.64), 0.10, 0.48, -0.10, (0, -0.40, 0.86), rot_x(math.radians(45)),
               -0.42, (1, 0.6, -0.4))
RISING = Pose((0, -0.26, 0.84), 0.0, 0.16, 0.0, (0, -0.40, 1.24), rot_x(math.radians(8)),
              -0.42, (1, 0.5, -0.5))
LIFTING = Pose((0, -0.32, 0.885), 0.0, 0.0, -0.05, (0, -0.33, 1.66), UP, -0.42, (1, 0.4, -0.2))
OVERHEAD = Pose((0, -0.33, 0.89), 0.0, -0.04, -0.12, (0, -0.25, 1.92), UP, -0.42, (1, 0.35, 0.0))


def _hold(t: float) -> Pose:
    """Fan_Hold at `t` of its loop: pumped twice, rocked once each way."""
    phase = 2.0 * math.pi * t
    pump = 0.05 * max(0.0, math.sin(2.0 * phase))
    rock = math.radians(5.0) * math.sin(phase)
    at = OVERHEAD.sign_at + Vector((0.05 * math.sin(phase), 0, pump))
    rot = Quaternion((0, 1, 0), rock)
    return Pose(OVERHEAD.pelvis + Vector((0, 0, -0.01 * pump / 0.05)), 0.0,
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
    rig = Rig(arm)
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    arm.animation_data_create()
    apply(rig, SEATED)                  # learn which bones move
    for name, frames, pose_at in CLIPS:
        action = bpy.data.actions.new(name)
        arm.animation_data.action = action
        for f in range(frames + 1):
            apply(rig, pose_at(f / frames))
            for bone in rig.moved:
                pb = arm.pose.bones[bone]
                pb.keyframe_insert("location", frame=f)
                pb.keyframe_insert("rotation_quaternion", frame=f)
        for fc in action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
        action.use_fake_user = True
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)


def build(n: int, avatar: str) -> pathlib.Path:
    reset_scene()
    arm, _body = load_avatar(avatar, n)
    add_sign(arm)
    bake(arm)
    out = OUT_DIR / ("sign_fan_%d.glb" % n)
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_apply=False,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_image_format="AUTO",
    )
    return out


def main(argv: list[str]) -> int:
    for n, avatar in enumerate(AVATARS):
        out = build(n, avatar)
        print("sign_fan: %s, %d clips -> %s" % (avatar, len(CLIPS), out.relative_to(REPO)))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main(sys.argv[1:]))
