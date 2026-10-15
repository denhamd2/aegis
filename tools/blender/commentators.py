#!/usr/bin/env python3
"""Build the seated Tony Schiavone and Excalibur commentary-table models.

The proportions, outfit palette, glasses/beard, and Excalibur's mask layout
are modeled from `gauntlet/refs/commentators/*_sheet.png`. The sheets are
visual production references, not runtime textures.

    blender --background --python tools/blender/commentators.py

Outputs are small articulated GLBs. Each has head and arm pivots so the game
can add restrained broadcast idle and speaking gestures without a full-body
skeletal update on every frame.
"""

from __future__ import annotations

import math
import pathlib
import sys

import bpy
import bmesh
from mathutils import Vector

import bpy_exit

REPO = pathlib.Path(__file__).resolve().parents[2]
OUT = REPO / "game" / "assets" / "environment"


def clear() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name: str, colour, roughness=0.72, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*colour, 1.0)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return m


def pivot(name: str, at=(0.0, 0.0, 0.0), parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.07
    obj.location = at
    obj.parent = parent
    return obj


def _uv_sphere(bm: bmesh.types.BMesh, centre, radii, material: int,
               axis=None, offset=(0, 0, 0)) -> None:
    result = bmesh.ops.create_uvsphere(
        bm, u_segments=20, v_segments=14, radius=1.0)
    verts = result["verts"]
    rot = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized()) \
        if axis is not None else None
    for v in verts:
        p = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
        if rot is not None:
            p = rot @ p
        v.co = p + Vector(centre) - Vector(offset)
    for v in verts:
        for f in v.link_faces:
            f.material_index = material
            f.smooth = True


def _box(bm: bmesh.types.BMesh, centre, size, material: int,
         offset=(0, 0, 0), rot_z=0.0) -> None:
    result = bmesh.ops.create_cube(bm, size=1.0)
    verts = result["verts"]
    c, o = Vector(centre), Vector(offset)
    co, si = math.cos(rot_z), math.sin(rot_z)
    for v in verts:
        x, y, z = v.co.x * size[0] * 0.5, v.co.y * size[1] * 0.5, v.co.z * size[2] * 0.5
        v.co = Vector((c.x + x * co - y * si, c.y + x * si + y * co, c.z + z)) - o
        for f in v.link_faces:
            f.material_index = material


def _triangle(bm, points, material: int, offset=(0, 0, 0)) -> None:
    verts = [bm.verts.new(Vector(p) - Vector(offset)) for p in points]
    try:
        f = bm.faces.new(verts)
        f.material_index = material
    except ValueError:
        pass


def mesh_object(name: str, shapes, materials, parent, offset=(0, 0, 0)):
    bm = bmesh.new()
    for shape in shapes:
        kind = shape[0]
        if kind == "sphere":
            _, centre, radii, material, *rest = shape
            _uv_sphere(bm, centre, radii, material,
                       axis=rest[0] if rest else None, offset=offset)
        elif kind == "box":
            _, centre, size, material, *rest = shape
            _box(bm, centre, size, material, offset,
                 rest[0] if rest else 0.0)
        elif kind == "tri":
            _triangle(bm, shape[1], shape[2], offset)
    me = bpy.data.meshes.new(name + "Mesh")
    bm.to_mesh(me)
    bm.free()
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    for m in materials:
        me.materials.append(m)
    for poly in me.polygons:
        poly.use_smooth = True
    obj.parent = parent
    obj.location = (0, 0, 0)
    obj.rotation_euler = (0, 0, 0)
    obj.scale = (1, 1, 1)
    return obj


def _arm_shapes(side: float, jacket_idx: int, skin_idx: int, cuff_idx: int):
    shoulder = Vector((side * 0.27, 0.0, 1.27))
    elbow = Vector((side * 0.38, -0.20, 1.08))
    wrist = Vector((side * 0.30, -0.54, 0.94))
    hand = Vector((side * 0.27, -0.64, 0.94))
    upper = elbow - shoulder
    lower = wrist - elbow
    return [
        ("sphere", shoulder.lerp(elbow, 0.5), (0.115, 0.12, upper.length * 0.62), jacket_idx, tuple(upper)),
        ("sphere", elbow, (0.095, 0.095, 0.09), jacket_idx),
        ("sphere", elbow.lerp(wrist, 0.5), (0.085, 0.09, lower.length * 0.62), jacket_idx, tuple(lower)),
        ("sphere", wrist, (0.087, 0.085, 0.035), cuff_idx),
        ("sphere", hand, (0.075, 0.105, 0.055), skin_idx),
    ]


def _finger_shapes(side: float, skin_idx: int):
    out = []
    for i in range(4):
        x = side * 0.27 + (i - 1.5) * 0.027
        out.append(("sphere", (x, -0.73, 0.91), (0.013, 0.055, 0.018), skin_idx))
    out.append(("sphere", (side * 0.20, -0.68, 0.93), (0.022, 0.06, 0.022), skin_idx,
                (side * 0.6, -0.8, 0.0)))
    return out


def _body_materials(role: str):
    skin = mat(role + "_Skin", (0.57, 0.39, 0.30), 0.78)
    hair = mat(role + "_HairBeard", (0.10, 0.055, 0.035), 0.88)
    white = mat(role + "_Shirt", (0.78, 0.75, 0.69), 0.8)
    black = mat(role + "_Dark", (0.018, 0.022, 0.03), 0.54)
    gold = mat(role + "_Gold", (0.70, 0.42, 0.08), 0.28, 0.55)
    burgundy = mat(role + "_Burgundy", (0.22, 0.035, 0.055), 0.82)
    lens = mat(role + "_Lens", (0.10, 0.13, 0.16), 0.3, 0.25)
    pants = mat(role + "_Trousers", (0.035, 0.04, 0.055), 0.84)
    leather = mat(role + "_Shoes", (0.025, 0.025, 0.03), 0.33)
    tie = mat(role + "_Tie", (0.075, 0.035, 0.045) if role == "Tony" else (0.055, 0.06, 0.075), 0.5)
    return {"skin": skin, "hair": hair, "shirt": white, "dark": black,
            "gold": gold, "jacket": burgundy if role == "Tony" else black,
            "lens": lens, "pants": pants, "shoes": leather, "tie": tie}


def _build_body(role, pivot_obj, m):
    names = ["skin", "hair", "shirt", "dark", "gold", "jacket", "lens", "pants", "shoes", "tie"]
    ix = {name: i for i, name in enumerate(names)}
    materials = [m[n] for n in names]
    pant = ix["pants"]
    body = [
        ("sphere", (0, 0.0, 0.59), (0.27, 0.18, 0.18), pant),
        # Bent seated legs: thighs run forward, shins drop to the floor.
        ("sphere", (-0.14, -0.20, 0.54), (0.105, 0.30, 0.12), pant),
        ("sphere", (0.14, -0.20, 0.54), (0.105, 0.30, 0.12), pant),
        ("sphere", (-0.14, -0.43, 0.29), (0.085, 0.10, 0.27), pant),
        ("sphere", (0.14, -0.43, 0.29), (0.085, 0.10, 0.27), pant),
        ("sphere", (-0.14, -0.52, 0.085), (0.095, 0.20, 0.07), ix["shoes"]),
        ("sphere", (0.14, -0.52, 0.085), (0.095, 0.20, 0.07), ix["shoes"]),
        # Jacket torso, shirt front and tie are layered, with raised lapels.
        ("sphere", (0, 0, 1.06), (0.32, 0.19, 0.37), ix["jacket"]),
        ("sphere", (0, -0.184, 1.08), (0.115, 0.025, 0.30), ix["shirt"]),
        ("sphere", (0, -0.214, 1.05), (0.036, 0.016, 0.25), ix["tie"]),
        ("sphere", (0, -0.216, 1.33), (0.052, 0.025, 0.052), ix["tie"]),
        ("tri", [(-0.17, -0.196, 1.39), (-0.04, -0.22, 1.28), (-0.11, -0.22, 1.02)], ix["shirt"]),
        ("tri", [(0.17, -0.196, 1.39), (0.04, -0.22, 1.28), (0.11, -0.22, 1.02)], ix["shirt"]),
        ("sphere", (0, -0.19, 1.39), (0.12, 0.055, 0.085), ix["shirt"]),
        ("sphere", (0, -0.205, 1.40), (0.07, 0.018, 0.018), ix["tie"]),
    ]
    # Buttons, pocket seam and subtle pin add small broadcast-readable detail.
    for z in (1.12, 1.02, 0.92):
        body.append(("sphere", (0.035, -0.195, z), (0.012, 0.008, 0.012), ix["gold"]))
    body.extend([
        ("box", (0.21, -0.177, 1.17), (0.09, 0.015, 0.08), ix["dark"]),
        ("sphere", (0.19, -0.191, 1.18), (0.026, 0.012, 0.018), ix["gold"]),
    ])
    mesh_object(role + "Body", body, materials, pivot_obj)


def _build_head(role, head_pivot, m):
    names = ["skin", "hair", "shirt", "dark", "gold", "jacket", "lens", "pants", "shoes", "tie"]
    ix = {name: i for i, name in enumerate(names)}
    materials = [m[n] for n in names]
    o = (0.0, 0.0, 1.60)
    sh = ix["skin"]
    features = [
        ("sphere", o, (0.145, 0.14, 0.18), sh),
        ("sphere", (0, -0.075, 1.47), (0.11, 0.075, 0.09), ix["hair"]),
        ("sphere", (0, -0.135, 1.585), (0.022, 0.032, 0.048), sh),
        ("sphere", (0, -0.154, 1.54), (0.040, 0.012, 0.011), ix["hair"]),
        # Hair cap and ears.
        ("sphere", (0, 0.015, 1.735), (0.148, 0.13, 0.070), ix["hair"]),
        ("sphere", (-0.146, 0.0, 1.60), (0.028, 0.038, 0.05), sh),
        ("sphere", (0.146, 0.0, 1.60), (0.028, 0.038, 0.05), sh),
    ]
    if role == "Tony":
        # Full neatly trimmed beard and moustache, matching the official
        # portrait; the mouth remains readable as a separate speaking inset.
        features += [
            ("sphere", (0, -0.105, 1.50), (0.125, 0.065, 0.090), ix["hair"]),
            ("sphere", (-0.033, -0.157, 1.565), (0.047, 0.026, 0.027), ix["hair"]),
            ("sphere", (0.033, -0.157, 1.565), (0.047, 0.026, 0.027), ix["hair"]),
        ]
        for x in (-0.052, 0.052):
            features += [
                ("sphere", (x, -0.13, 1.625), (0.028, 0.014, 0.019), ix["lens"]),
                ("box", (x, -0.152, 1.626), (0.065, 0.012, 0.009), ix["dark"]),
                ("box", (x, -0.152, 1.588), (0.065, 0.012, 0.009), ix["dark"]),
                ("box", (x - 0.035, -0.152, 1.607), (0.010, 0.012, 0.040), ix["dark"]),
                ("box", (x + 0.035, -0.152, 1.607), (0.010, 0.012, 0.040), ix["dark"]),
            ]
        features += [("box", (0, -0.155, 1.61), (0.016, 0.012, 0.012), ix["dark"])]
    else:
        # Signature black/gold/white lucha mask. A narrow exposed mouth and
        # beard remain, while the eye surround and crown make its silhouette
        # unmistakable from the hard-cam wide.
        features += [
            ("sphere", (0, -0.10, 1.61), (0.147, 0.078, 0.175), ix["dark"]),
            ("sphere", (0, -0.179, 1.49), (0.11, 0.035, 0.07), ix["hair"]),
            ("sphere", (0, -0.19, 1.545), (0.05, 0.012, 0.010), ix["hair"]),
        ]
        for x in (-0.054, 0.054):
            features += [
                ("sphere", (x, -0.176, 1.646), (0.049, 0.018, 0.036), ix["shirt"]),
                ("sphere", (x, -0.194, 1.646), (0.030, 0.009, 0.018), ix["dark"]),
                ("sphere", (x, -0.203, 1.646), (0.010, 0.006, 0.010), ix["lens"]),
                ("sphere", (x, -0.175, 1.687), (0.055, 0.012, 0.010), ix["gold"]),
            ]
        # Crown lightning: a stepped, raised angular gold crest.
        features += [
            ("tri", [(-0.11, -0.177, 1.73), (-0.045, -0.198, 1.72),
                      (-0.008, -0.199, 1.79)], ix["gold"]),
            ("tri", [(-0.008, -0.199, 1.79), (0.018, -0.198, 1.72),
                      (0.105, -0.177, 1.73)], ix["gold"]),
            ("box", (0, -0.205, 1.755), (0.022, 0.009, 0.072), ix["gold"], math.radians(-16)),
            ("sphere", (-0.145, -0.01, 1.62), (0.026, 0.048, 0.06), ix["gold"]),
            ("sphere", (0.145, -0.01, 1.62), (0.026, 0.048, 0.06), ix["gold"]),
        ]
    # Over-ear broadcast headset: ear cups, crown band and soft boom mic.
    features += [
        ("sphere", (-0.172, 0.0, 1.66), (0.044, 0.052, 0.064), ix["dark"]),
        ("sphere", (0.172, 0.0, 1.66), (0.044, 0.052, 0.064), ix["dark"]),
        ("sphere", (-0.174, -0.006, 1.66), (0.029, 0.018, 0.043), ix["lens"]),
        ("sphere", (0.174, -0.006, 1.66), (0.029, 0.018, 0.043), ix["lens"]),
        ("sphere", (-0.18, -0.11, 1.55), (0.11, 0.012, 0.010), ix["dark"], (0.7, -0.7, -0.25)),
        ("sphere", (-0.23, -0.20, 1.54), (0.029, 0.026, 0.022), ix["dark"]),
    ]
    mesh_object(role + "Head", features, materials, head_pivot, offset=o)


def build(role: str, out_path: pathlib.Path):
    clear()
    m = _body_materials(role)
    root = pivot(role + "Commentator")
    body_pivot = pivot("SpinePivot", parent=root)
    head_pivot = pivot("HeadPivot", (0.0, 0.0, 1.60), parent=root)
    arm_l = pivot("ArmLeftPivot", (-0.27, 0.0, 1.27), parent=root)
    arm_r = pivot("ArmRightPivot", (0.27, 0.0, 1.27), parent=root)
    _build_body(role, body_pivot, m)
    _build_head(role, head_pivot, m)
    names = ["skin", "hair", "shirt", "dark", "gold", "jacket", "lens", "pants", "shoes", "tie"]
    materials = [m[n] for n in names]
    ix = {name: i for i, name in enumerate(names)}
    for side, p, label in [(-1.0, arm_l, "ArmLeft"), (1.0, arm_r, "ArmRight")]:
        shapes = _arm_shapes(side, ix["jacket"], ix["skin"], ix["shirt"])
        shapes += _finger_shapes(side, ix["skin"])
        mesh_object(label, shapes, materials, p,
                    offset=(-0.27 if side < 0 else 0.27, 0.0, 1.27))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(out_path), export_format="GLB",
                              export_yup=True, export_apply=True,
                              export_animations=False, export_skins=False,
                              export_materials="EXPORT", export_cameras=False,
                              export_lights=False)
    print("commentators: wrote", out_path)


def main() -> int:
    for role in ("Tony", "Excalibur"):
        build(role, OUT / ("commentator_" + role.lower() + ".glb"))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main())
