"""Build Shane's independent photo-led head on the existing shared bind pose.

blender -b --python-exit-code 1 --python tools/blender/beechlawn/refine_shane_photo_head.py
The common body, rig, animation clips and other identities are never rewritten.
All sculpt coordinates below are armature-local centimetres, +Y up, +Z face.
"""
from pathlib import Path
import hashlib
import json
import math
import struct
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from shane_head_variants import fingerprint, save_delta

SOURCE = ROOT / "tools/blender/beechlawn/footballer_shared.blend"
BLEND = SOURCE.with_name("shane_photo_head.blend")
ASSETS = ROOT / "games/beechlawn_rovers/assets/characters/shane"
TEXTURES = ROOT / "tools/blender/beechlawn/textures"
EVIDENCE = ROOT / "games/beechlawn_rovers/docs/art_briefs/shane_photo_likeness"
PARTS = ("Skin_Head", "Eye_l", "Eye_r", "Hair_Shane_ShortCropRoots", "Hair_Shane_ShortCropCards")


def smooth(a, b, value):
    t = max(0.0, min(1.0, (value - a) / (b - a)))
    return t * t * (3 - 2 * t)


def field(x, y, cx, cy, sx, sy):
    return math.exp(-((abs(x) - cx) / sx) ** 2 - ((y - cy) / sy) ** 2)


def sculpt(p, eyes=False):
    x, y, z = p
    if y < 154 or eyes:
        return p.copy()  # The orbital centres and the complete neck seam stay put.
    front = smooth(2.5, 7.5, z)
    side = smooth(3.5, 6.5, abs(x))
    # Rounded tapered mandibular outline instead of the base's rectangular jaw.
    jaw = field(x, y, 5.7, 157.6, 3.1, 3.4)
    x *= 1 - .055 * jaw * smooth(-5, 2, z)
    y -= .60 * field(x, y, 0, 156.8, 5.8, 2.8) * front
    z += .16 * field(x, y, 0, 156.8, 3.0, 1.4) * front
    # Full malar/medial cheeks and an anatomical cheek-to-mouth transition.
    cheek = field(x, y, 5.1, 163.3, 2.1, 2.0) * front
    x += math.copysign(.19 * cheek, x)
    z += .36 * cheek
    # The photograph has full buccal tissue rather than the base's hollow cheeks.
    buccal = field(x, y, 4.6, 160.8, 2.4, 2.5) * front
    x += math.copysign(.38 * buccal, x)
    z += .78 * buccal
    x *= 1 + .035 * field(x, y, 2.9, 156.6, 2.0, 1.4) * front
    z += .15 * field(x, y, 3.3, 161.0, 1.0, 1.5) * front
    # Open the actual lid loops, not an enlarged painted eye or iris disc.
    orbit = field(x, y, 3.4, 166.4, 1.75, .95) * smooth(8.35, 9.0, z)
    y += .43 * (y - 166.38) * orbit
    z += .17 * field(x, y, 3.5, 167.8, 2.1, .72) * front
    z += .22 * field(x, y, 2.4, 167.7, 1.6, .7) * front
    y -= .11 * field(x, y, 2.1, 167.8, 1.2, .65) * front
    z += .10 * field(x, y, 3.9, 165.1, 1.8, .65) * front
    # Rounded tip/alar wings and a readable bridge, without a pointed wedge.
    tip = field(x, y, 0, 162.3, 1.45, .95) * front
    wing = field(x, y, 1.45, 161.9, .75, .68) * front
    x *= 1 + .10 * tip
    x += math.copysign(.28 * wing, x)
    z += .04 * tip + .33 * wing
    z -= .14 * field(x, y, 0, 165.5, .8, 1.0) * front
    # Reference lip span is smaller than the base; preserve the mouth loops.
    mouth = field(x, y, 0, 159.85, 4.1, 1.1) * front
    x *= 1 - .065 * mouth
    y += .10 * field(x, y, 2.85, 159.8, .65, .55) * front
    z -= .14 * field(x, y, 0, 160.25, 2.0, .35) * front
    # Subtle temporal taper, leaving the recognizable broad cheeks intact.
    x *= 1 - .025 * field(x, y, 7.4, 171.0, 2.0, 3.6) * side
    return Vector((x, y, z))


def smile(p):
    """Editable restrained closed-mouth smile, separate from identity/Basis."""
    x, y, z = p
    front = smooth(6.0, 8.5, z)
    corner = field(x, y, 2.8, 159.9, 1.15, 1.0) * front
    cheek = field(x, y, 4.5, 163.0, 1.8, 1.8) * front
    # Slight asymmetry visible in the photo, bounded to expression only.
    lift = .32 if x < 0 else .27
    x += math.copysign(.15 * corner, x)
    y += lift * corner + .18 * cheek
    z += .16 * cheek
    return Vector((x, y, z))


def rebuild_normals(obj, original_normals=None):
    mesh = obj.data
    if mesh.has_custom_normals:
        with bpy.context.temp_override(object=obj, active_object=obj):
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
    mesh.update()
    normals = [v.normal.copy() for v in mesh.vertices]
    if original_normals:
        for v in mesh.vertices:
            if v.co.y < 154:
                normals[v.index] = original_normals[v.index]
    mesh.normals_split_custom_set_from_vertices(normals)


def refine_brow_pigment(head):
    """Paint registered brow pigment through anatomical UVs, keeping all skin.

    The owner's image supplies shape/density evidence, never projected pixels.
    Copy an existing FILE image so its colour interpretation survives saving.
    """
    material = head.data.materials[0].copy()
    material.name = "MAT_Skin_Shane_PhotoRefined"
    head.data.materials[0] = material
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    node = bsdf.inputs["Base Color"].links[0].from_node
    image = node.image.copy()
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape(height, width, 4)
    original = pixels.copy()
    uv = head.data.uv_layers.active
    head.data.calc_loop_triangles()
    for tri in head.data.loop_triangles:
        points = np.array([head.data.vertices[i].co[:] for i in tri.vertices])
        if points[:, 1].max() < 167.2 or points[:, 1].min() > 168.8 or points[:, 2].max() < 8:
            continue
        coords = np.array([uv.data[i].uv[:] for i in tri.loops]) * [width-1, height-1]
        lo = np.maximum(0, np.floor(coords.min(axis=0)).astype(int))
        hi = np.minimum([width-1,height-1], np.ceil(coords.max(axis=0)).astype(int))
        ax, ay = coords[0]; bx, by = coords[1]; cx, cy = coords[2]
        den = (by-cy)*(ax-cx)+(cx-bx)*(ay-cy)
        if abs(den) < 1e-9:
            continue
        yy, xx = np.mgrid[lo[1]:hi[1]+1, lo[0]:hi[0]+1]
        a = ((by-cy)*(xx-cx)+(cx-bx)*(yy-cy))/den
        b = ((cy-ay)*(xx-cx)+(ax-cx)*(yy-cy))/den
        c = 1-a-b
        p = a[...,None]*points[0]+b[...,None]*points[1]+c[...,None]*points[2]
        x, y, z = np.abs(p[...,0]), p[...,1], p[...,2]
        line = 168.05 + .14*np.exp(-((x-3.7)/1.1)**2) - .10*(x-3.0)
        brow = np.exp(-((x-3.5)/1.85)**6 - ((y-line)/.245)**2)
        brow *= np.clip((z-8)/1.0,0,1) * (.84+.16*np.sin(x*61+y*37))
        brow *= (a>=0)&(b>=0)&(c>=0)
        region = pixels[lo[1]:hi[1]+1,lo[0]:hi[0]+1,:3]
        region[:] = region*(1-brow[...,None]*.68) + np.array([.105,.062,.039])*brow[...,None]*.68
    image.name = "shane_photo_head_albedo_2k"
    TEXTURES.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(TEXTURES / "shane_photo_head_albedo_2k.png")
    image.file_format = "PNG"
    image.save()
    reloaded = bpy.data.images.load(image.filepath_raw, check_existing=False)
    check = np.empty(width*height*4,dtype=np.float32)
    reloaded.pixels.foreach_get(check)
    # Quantisation only; reject unintended whole-atlas gamma conversion.
    untouched = np.max(abs(pixels-original),axis=2) < 1e-6
    assert np.max(abs(check.reshape(height,width,4)[untouched]-original[untouched])) < .012
    reloaded.pack()
    node.image = reloaded


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    original_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    rig = bpy.data.objects["YBot_Armature"]
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        bone.location = (0, 0, 0)
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.scale = (1, 1, 1)
    head = bpy.data.objects["Skin_Head"]
    before = head.data.copy()
    normals = [v.normal.copy() for v in head.data.vertices]
    for name in PARTS:
        obj = bpy.data.objects[name]
        for vertex in obj.data.vertices:
            vertex.co = sculpt(vertex.co, eyes=name.startswith("Eye_"))
        obj.data.update()
        rebuild_normals(obj, normals if name == "Skin_Head" else None)
    head.shape_key_add(name="Basis")
    expression = head.shape_key_add(name="Shane_Smile")
    for point in expression.data:
        point.co = smile(point.co)
    expression.value = 0.0
    refine_brow_pigment(head)
    head["identity_reference"] = "owner photo 69012.jpg, 2026-10-19"
    head["expression_note"] = "Neutral Basis; restrained closed smile is separate from identity"
    save_delta(before, head.data, ASSETS / "shane_photo_sculpt_delta.json")
    offsets = [(a.co-b.co).length for a, b in zip(head.data.vertices, before.vertices)]
    assert fingerprint(before) == fingerprint(head.data)
    bpy.data.meshes.remove(before)
    from shane_photo_groom import build_groom
    build_groom(head, rig, TEXTURES)
    # Retain only the reusable head package; its full original bind skeleton is
    # exported for correct skin indices, never instantiated as another live rig.
    for obj in list(bpy.context.scene.objects):
        if obj != rig and obj.name not in PARTS:
            bpy.data.objects.remove(obj, do_unlink=True)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    bpy.data.orphans_purge(do_recursive=True)
    bpy.context.scene.frame_set(1)
    for obj in bpy.context.scene.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)
    bpy.ops.export_scene.gltf(
        filepath=str(ASSETS / "shane_photo_head.glb"), export_format="GLB",
        use_selection=True, export_yup=True, export_apply=True,
        export_cameras=False, export_lights=False, export_animations=False,
        export_skins=True, export_influence_nb=4, export_leaf_bone=False,
        export_rest_position_armature=True, export_morph=True,
    )
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == original_hash
    report = {
        "source_shared_blend_sha256_unchanged": original_hash,
        "head_vertices": len(head.data.vertices), "topology_sha256": fingerprint(head.data),
        "moved_head_vertices": sum(v > 1e-6 for v in offsets),
        "largest_sculpt_offset_cm": max(offsets),
        "bones": len(rig.data.bones), "parts": list(PARTS),
        "expression": "Shane_Smile (neutral default 0; closed mouth)",
        "hair": "1800 curved, tapered tufts with geometric normals over close roots",
        "limits": "Single-photo reconstruction; profile depth estimated; no teeth photo projection",
    }
    def gltf(path):
        raw = path.read_bytes()
        return raw, json.loads(raw[20:20+struct.unpack_from("<I", raw, 12)[0]])
    raw, exported = gltf(ASSETS / "shane_photo_head.glb")
    base_raw, base = gltf(ASSETS.parent / "shared/footballer_base.glb")
    def joints(data):
        return [data["nodes"][i]["name"] for i in data["skins"][0]["joints"]]
    def triangles(data):
        indices = {node["mesh"] for node in data["nodes"] if node.get("name") in PARTS and "mesh" in node}
        return sum(data["accessors"][p["indices"]]["count"]//3
                   for index, mesh in enumerate(data["meshes"]) if index in indices
                   for p in mesh["primitives"])
    assert joints(exported) == joints(base)
    report.update({"glb_bytes": len(raw), "head_package_triangles": triangles(exported),
                   "base_head_package_triangles": triangles(base),
                   "surfaces": sum(len(m["primitives"]) for m in exported["meshes"]),
                   "additional_animation_libraries": len(exported.get("animations", [])),
                   "joint_order_matches_shared": True,
                   "base_glb_sha256_unchanged": hashlib.sha256(base_raw).hexdigest()})
    (EVIDENCE / "sculpt_report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("SHANE_PHOTO_HEAD", json.dumps(report))


if __name__ == "__main__":
    main()
