"""Kenny Omega in Blender, as the game builds him, rendered for review.

The owner, 8 Nov: "generate actual renders directly from Blender ... a
straight-on facial close-up, a left three-quarter, an exact left-side profile,
and a close-up of both eyes", under consistent neutral light, to compare
against his references.

The game's Kenny is Cody's model (cody_rhodes.glb) with Kenny's look applied
at load (KennyModel). This assembles the same thing in Blender:

* the head's shape -- the photo-fit bake (kenny_head_shape.tres: rest
  position -> offset, matched by position as KennyFaceShape does) plus the
  hand moves (KennyFaceShape.TABLE, parsed from the .gd, with
  RomanFaceShape.offset's smoothstep ellipsoid falloff);
* Kenny's skin, gear and eye atlases (KennyModel's tables), his skin tint;
* his groom, kenny_curls.glb, vertex colour over the curl-card atlas.

glTF is Y up, Blender Z up: a glTF point (x, y, z) is Blender (x, -z, y), and
the face looks down Blender's -Y.

Run:  /path/to/python-with-bpy tools/blender/kenny_review_render.py [out_dir]
Writes kenny_front.png, kenny_three_quarter.png, kenny_profile.png and
kenny_eyes.png (default gauntlet/refs/characters/review/blender/). Cycles on
the CPU: no GPU in the build container.
"""
import math
import pathlib
import re
import sys

import bpy
from mathutils import Vector, kdtree

REPO = pathlib.Path(__file__).resolve().parents[2]
CHAR = REPO / "game/assets/characters"
OUT = pathlib.Path(sys.argv[-1]) if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") \
    else REPO / "gauntlet/refs/characters/review/blender"

SKIN = {  # KennyModel.SKIN_TEXTURES
    "xmaterial_c3d4d9e78b44a79": "kenny_head.png",
    "xmaterial_495900de7002683": "kenny_body_abdomen.png",
    "xmaterial_90b39911eb484a2": "kenny_body_arm_r.png",
    "xmaterial_90b2b911eb46cd8": "kenny_body_arm_l.png",
    "xmaterial_5a329cd32db96c3": "kenny_body_chest.png",
}
GEAR = {  # KennyModel.GEAR_TEXTURES
    "xmaterial_e531cd813705b95": "kenny_gear_tights.png",
    "xmaterial_c7ae1bc9f4b14": "kenny_gear_belt.png",
    "xmaterial_6d1e7e57b971093": "kenny_gear_boot_r.png",
    "xmaterial_6d205e57b97438d": "kenny_gear_boot_l.png",
    "xmaterial_f003af958238385": "kenny_gear_wrist.png",
}
EYE_MATERIAL = "xmaterial_7d08cd4d239faf3"
HEAD_MATERIAL = "xmaterial_c3d4d9e78b44a79"
MOUTH_MATERIAL = "head_shared_inside_mouth_iw9"
MATCH = 0.0005


def read_floats(text: str, name: str) -> list:
    m = re.search(name + r" = PackedVector3Array\(([^)]*)\)", text)
    v = [float(x) for x in m.group(1).split(",")]
    return [Vector(v[i:i + 3]) for i in range(0, len(v), 3)]


def gd_const(path: pathlib.Path, name: str) -> str:
    return re.search(r"const %s := (.*?)\n(?=\S)" % name, path.read_text(), re.S).group(1)


def hand_moves() -> list:
    """KennyFaceShape.TABLE as absolute moves (KennyFaceShape.moves())."""
    gd = REPO / "game/core/match/kenny_face_shape.gd"
    midline = float(gd_const(gd, "MIDLINE_X"))
    table = gd_const(gd, "TABLE")
    rows = re.findall(r"\[Vector3\(([^)]*)\), Vector3\(([^)]*)\), Vector3\(([^)]*)\), (true|false)\]", table)
    moves = []
    for c, r, d, mirrored in rows:
        c, r, d = (Vector([float(x) for x in s.split(",")]) for s in (c, r, d))
        for side in ((1.0, -1.0) if mirrored == "true" else (1.0,)):
            moves.append((Vector((midline + c.x * side, c.y, c.z)), r, Vector((d.x * side, d.y, d.z))))
    return moves


def hand_offset(p: Vector, moves) -> Vector:
    """RomanFaceShape.offset: a smoothstep ellipsoid per move."""
    out = Vector((0.0, 0.0, 0.0))
    for c, r, d in moves:
        q = Vector(((p.x - c.x) / r.x, (p.y - c.y) / r.y, (p.z - c.z) / r.z))
        k = 1.0 - q.length
        if k > 0.0:
            out += d * (k * k * (3.0 - 2.0 * k))
    return out


def to_gltf(v: Vector) -> Vector:
    return Vector((v.x, v.z, -v.y))


def to_blender(v: Vector) -> Vector:
    return Vector((v.x, -v.z, v.y))


def shape_head(body) -> int:
    text = (REPO / "game/resources/characters/kenny_head_shape.tres").read_text()
    rest, offset = read_floats(text, "rest"), read_floats(text, "offset")
    tree = kdtree.KDTree(len(rest))
    for i, p in enumerate(rest):
        tree.insert(p, i)
    tree.balance()
    moves = hand_moves()
    mesh, mw = body.data, body.matrix_world
    inv = mw.inverted()
    mats = {i for i, m in enumerate(mesh.materials) if m and m.name in (HEAD_MATERIAL, MOUTH_MATERIAL)}
    head_mat = next(i for i, m in enumerate(mesh.materials) if m and m.name == HEAD_MATERIAL)
    on_head, on_skin = set(), set()
    for poly in mesh.polygons:
        if poly.material_index in mats:
            on_head.update(poly.vertices)
            if poly.material_index == head_mat:
                on_skin.update(poly.vertices)
    moved = 0
    for i in on_head:
        v = mesh.vertices[i]
        p = to_gltf(mw @ v.co)
        d = Vector((0.0, 0.0, 0.0))
        _, j, dist = tree.find(p)
        if j is not None and dist < MATCH:
            d += offset[j]
        if i in on_skin:  # the hand moves shape the skin only
            d += hand_offset(p, moves)
        if d.length > 1e-7:
            v.co = inv @ to_blender(p + d)
            moved += 1
    mesh.update()
    return moved


def retexture(obj) -> None:
    tint = (0.72, 0.62, 0.56, 1.0)  # KennyModel.KENNY_SKIN_TINT
    for slot in obj.material_slots:
        mat = slot.material
        if mat is None or not mat.use_nodes:
            continue
        name = mat.name
        path = SKIN.get(name) or GEAR.get(name) or ("kenny_eye_color.png" if name == EYE_MATERIAL else None)
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        tex = next((n for n in nodes if n.type == "TEX_IMAGE"), None)
        if path and tex is not None:
            tex.image = bpy.data.images.load(str(CHAR / path), check_existing=True)
        if name in SKIN and bsdf is not None and tex is not None:
            mul = nodes.new("ShaderNodeMix")
            mul.data_type, mul.blend_type = "RGBA", "MULTIPLY"
            mul.inputs[0].default_value = 1.0
            links.new(tex.outputs["Color"], mul.inputs[6])
            mul.inputs[7].default_value = tint
            links.new(mul.outputs[2], bsdf.inputs["Base Color"])
            # Skin: matte with a soft sheen (the glTF default read as grey
            # gloss on the scalp and lips under a studio key).
            bsdf.inputs["Roughness"].default_value = 0.62
            bsdf.inputs["Specular IOR Level"].default_value = 0.3
            bsdf.inputs["Subsurface Weight"].default_value = 0.15
            bsdf.inputs["Subsurface Radius"].default_value = (1.0, 0.35, 0.2)
        if name == EYE_MATERIAL and bsdf is not None:
            bsdf.inputs["Roughness"].default_value = 0.08
            bsdf.inputs["Coat Weight"].default_value = 0.6


def curl_material(cap: bool, attribute: str):
    mat = bpy.data.materials.new("KennyCurls" + ("Cap" if cap else ""))
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(CHAR / "kenny_curl_cards.png"), check_existing=True)
    col = nodes.new("ShaderNodeVertexColor")
    # The groom's colour is in its vertex colours (root to tip, per ringlet).
    col.layer_name = attribute
    mul = nodes.new("ShaderNodeMix")
    mul.data_type, mul.blend_type = "RGBA", "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    links.new(tex.outputs["Color"], mul.inputs[6])
    links.new(col.outputs["Color"], mul.inputs[7])
    links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9 if cap else 0.7
    # KennyModel's: the cap's specular 0.08, the curls' 0.12 -- Blender's
    # default 0.5 read as a grey sheen over the dark roots.
    bsdf.inputs["Specular IOR Level"].default_value = 0.08 if cap else 0.12
    if not cap:
        links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        mat.blend_method = "CLIP" if hasattr(mat, "blend_method") else None
    return mat


def add_curls() -> None:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(CHAR / "kenny_curls.glb"))
    for obj in set(bpy.data.objects) - before:
        if obj.type == "MESH":
            attrs = obj.data.color_attributes
            name = attrs[0].name if len(attrs) else ""
            print("curls:", obj.name, "colour attribute", repr(name))
            obj.data.materials.clear()
            obj.data.materials.append(curl_material(obj.name.startswith("CurlCap"), name))


def light(name, kind, loc, energy, size=1.0, colour=(1.0, 1.0, 1.0)):
    data = bpy.data.lights.new(name, kind)
    data.energy, data.color = energy, colour
    if kind == "AREA":
        data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = (Vector((0.0, 0.0, 1.70)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


def shoot(cam, head: Vector, yaw_deg: float, dist: float, lens: float, name: str, aim: Vector = None):
    yaw = math.radians(yaw_deg)
    # The face looks down -Y: yaw 0 is straight on, +90 his left side.
    d = Vector((math.sin(yaw), -math.cos(yaw), 0.0))
    target = aim or head
    cam.location = target + d * dist
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    bpy.context.scene.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)
    print("wrote", OUT / name)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(CHAR / "cody_rhodes.glb"))
    body = bpy.data.objects["Body"]
    print("head vertices moved:", shape_head(body))
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            retexture(obj)
    add_curls()
    # The glTF carries a stray Icosphere (a helper): not part of the man.
    for obj in bpy.data.objects:
        if obj.type == "MESH" and obj.name.startswith("Icosphere"):
            obj.hide_render = True

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = 900
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.02, 0.025, 1.0)
    scene.world = world
    # Neutral studio: a soft key front-left, a fill right, a rim behind.
    light("Key", "AREA", (-0.9, -1.2, 2.2), 420.0, 1.2, (1.0, 0.97, 0.92))
    light("Fill", "AREA", (1.1, -1.0, 1.8), 160.0, 1.5, (0.92, 0.95, 1.0))
    light("Rim", "AREA", (0.3, 1.2, 2.2), 200.0, 0.8)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam

    head = Vector((0.004, -0.02, 1.70))
    shoot(cam, head, 0.0, 0.95, 85.0, "kenny_front.png")
    shoot(cam, head, 40.0, 0.95, 85.0, "kenny_three_quarter.png")
    shoot(cam, head, 90.0, 0.95, 85.0, "kenny_profile.png")
    shoot(cam, head, 0.0, 0.30, 85.0, "kenny_eyes.png", Vector((0.004, -0.05, 1.722)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
