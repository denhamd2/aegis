#!/usr/bin/env python3
"""Cody's swept short groom: a scalp cap and curved, tapered strand cards.

Build: blender --background --python-exit-code 1 --python tools/blender/cody_groom.py
The source mesh/rig is never edited. Hair stays in the source armature space
used by CodyModel's Head attachment. Fixed seeds make outputs repeatable.
"""
from pathlib import Path
import json
import math
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cody_hair as source
import bpy_exit

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/characters/cody_groom.glb"
ATLAS = ROOT / "game/assets/characters/cody_groom_cards.png"
CARD_COUNT = 1200
STEPS = 5
ATLAS_CELLS = 8


def atlas():
    """Eight non-tiling clumps with fine fibres, staggered tips and clear edges."""
    rng = np.random.default_rng(161026)
    scale, size = 2, 1024
    rgba = Image.new("RGBA", (size * scale, size * scale), (220, 220, 220, 0))
    draw = ImageDraw.Draw(rgba)
    cell = size / ATLAS_CELLS
    for group in range(ATLAS_CELLS):
        for strand in range(18):
            spread = rng.uniform(-.43, .43)
            start = rng.uniform(0, .045)
            length = rng.uniform(.69, .985)
            lean = rng.uniform(-.09, .09)
            phase = rng.uniform(0, 2 * math.pi)
            tone = int(rng.uniform(160, 252))
            points = []
            for t in np.linspace(start, length, 22):
                # Broad, dense root; individual ends converge without a blunt edge.
                taper = 1 - .65 * (t / length) ** 1.8
                x = (group + .5 + spread * taper + lean * t
                     + .018 * math.sin(t * 7 + phase)) * cell
                points.append((x * scale, (12 + t * 1000) * scale))
            width = int(rng.integers(1, 3)) * scale
            draw.line(points, fill=(tone, tone, tone, 255), width=width)
    rgba.resize((size, size), Image.Resampling.LANCZOS).save(ATLAS)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source.SOURCE))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = bpy.data.objects["Body"]
    bm = bmesh.new()
    bm.from_mesh(body.data)
    uv = bm.loops.layers.uv.active
    head = next(i for i, mat in enumerate(body.data.materials)
                if mat.name == source.HEAD_MATERIAL)
    remove = []
    for face in bm.faces:
        centre = sum((loop[uv].uv for loop in face.loops), Vector((0, 0))) / len(face.loops)
        if face.material_index != head or not source.is_hair(*centre):
            remove.append(face)
    bmesh.ops.delete(bm, geom=remove, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.0008)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.normal_update()
    bm.verts.ensure_lookup_table()
    bm.verts.index_update()
    mw = body.matrix_world
    to_arm = arm.matrix_world.inverted()
    normal_to_arm = to_arm.to_3x3().inverted().transposed()
    points = [mw @ v.co for v in bm.verts]
    normals = [(mw.to_3x3().inverted().transposed() @ v.normal).normalized()
               for v in bm.verts]
    faces = [tuple(v.index for v in f.verts) for f in bm.faces]
    bvh = BVHTree.FromPolygons(points, faces, all_triangles=True)
    rim = {v.index for edge in bm.edges if len(edge.link_faces) == 1 for v in edge.verts}
    rim_tree = KDTree(len(rim))
    for i, idx in enumerate(sorted(rim)):
        rim_tree.insert(points[idx], i)
    rim_tree.balance()
    low = min(p.z for p in points)
    high = max(p.z for p in points)
    front = min(p.y for p in points)
    back = max(p.y for p in points)
    cx = (min(p.x for p in points) + max(p.x for p in points)) * .5

    def topness(p, n):
        return source.smooth((p.z - low) / (high - low)) * source.smooth((n.z + .15) / .95)

    def height(p, n):
        top = topness(p, n)
        return .005 + top * (.012 + .012 * source.smooth((back - p.y) / (back - front)))

    def edge_fade(p):
        return source.smooth(rim_tree.find(p)[2] / .024)

    def sample(p):
        hit, normal, idx, _ = bvh.find_nearest(p)
        # Interpolate authored scalp normals instead of jumping between triangle planes.
        a, b, c = (points[i] for i in faces[idx])
        v0, v1, v2 = b - a, c - a, hit - a
        d00, d01, d11 = v0.dot(v0), v0.dot(v1), v1.dot(v1)
        denom = d00 * d11 - d01 * d01
        if abs(denom) > 1e-16:
            v = (d11 * v2.dot(v0) - d01 * v2.dot(v1)) / denom
            w = (d00 * v2.dot(v1) - d01 * v2.dot(v0)) / denom
            normal = (normals[faces[idx][0]] * (1-v-w)
                      + normals[faces[idx][1]] * v + normals[faces[idx][2]] * w).normalized()
        return hit, normal

    def flow(p, n, side):
        up = -.6 + 1.25 * topness(p, n)
        wanted = Vector((side, 1, up))
        tangent = wanted - n * wanted.dot(n)
        if tangent.length_squared < .001:
            tangent = Vector((0, 0, 1)) - n * n.z
        return tangent.normalized()

    parts = []
    stats = {}

    def mesh_object(name, verts, polys, uvs, colors, shading_normals=None):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([to_arm @ p for p in verts], [], polys)
        mesh.update()
        layer = mesh.uv_layers.new(name="UVMap")
        color = mesh.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
        for poly in mesh.polygons:
            poly.use_smooth = True
            for loop in poly.loop_indices:
                layer.data[loop].uv = uvs[mesh.loops[loop].vertex_index]
        for idx, value in enumerate(colors):
            color.data[idx].color = value
        if shading_normals is not None:
            # Cards inherit the groom's smooth volume normal. Lighting every
            # thin ribbon as a separate plane made it look like white leaves.
            mesh.normals_split_custom_set_from_vertices([
                (normal_to_arm @ n).normalized() for n in shading_normals])
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        mesh.materials.append(bpy.data.materials.new(name))
        parts.append(obj)
        stats[name] = sum(len(p.vertices)-2 for p in mesh.polygons)

    # A low cap provides scalp coverage; the cards, not stacked closed shells,
    # supply the visible sweep and irregular silhouette.
    cap = [p + n * (.0015 + height(p, n) * .55 * edge_fade(p)) for p, n in zip(points, normals)]
    cap_uv = [(math.atan2(p.x-cx, p.z-(low-.35)) * (high-low+.35) * 6,
               (p.y-front)*11 + (high-p.z)*7) for p in points]
    mesh_object("HairCap", cap, faces, cap_uv, [(1, 1, 1, 1)] * len(cap))

    areas = np.array([(points[f[1]]-points[f[0]]).cross(points[f[2]]-points[f[0]]).length
                      for f in faces])
    # More roots on the visible swept crown; sides retain short, close growth.
    weights = np.array([.55 + 1.25 * topness(sum((points[i] for i in f), Vector())/3,
                                           sum((normals[i] for i in f), Vector()).normalized())
                        for f in faces]) * areas
    rng = np.random.default_rng(161026)
    groups = {name: [[], [], [], [], []] for name in ["HairCardsCrown", "HairCardsSides", "HairCardsHairline"]}
    for card in range(CARD_COUNT):
        f = faces[int(rng.choice(len(faces), p=weights/weights.sum()))]
        u, v = rng.random(2)
        u = math.sqrt(u)
        p = points[f[0]]*(1-u) + points[f[1]]*(u*(1-v)) + points[f[2]]*(u*v)
        p, n = sample(p)
        top = topness(p, n)
        length = rng.uniform(.009, .015) + top * rng.uniform(.045, .065)
        half_width = rng.uniform(.0006, .0014) * (.8 + .3 * top)
        side = rng.uniform(-.25, .25)
        cell = int(rng.integers(0, ATLAS_CELLS))
        name = "HairCardsCrown" if top > .35 else "HairCardsSides"
        if p.y < front + .035 and p.z > low + (high-low)*.55:
            name = "HairCardsHairline"
        verts, polys, uvs, colors, shading_normals = groups[name]
        start = len(verts)
        q = p.copy()
        phase = rng.uniform(0, 2*math.pi)
        h_gain = rng.uniform(.78, 1.08)
        for step in range(STEPS+1):
            t = step / STEPS
            q, normal = sample(q)
            direction = flow(q, normal, side)
            across = direction.cross(normal).normalized()
            standoff = .0015 + height(q, normal) * edge_fade(q) \
                * (.52 + .35 * math.sin(t*math.pi*.5)) * h_gain
            centre = q + normal * standoff
            centre += across * (math.sin(t*4 + phase)-math.sin(phase)) * .0015 * t
            width = half_width * (1 - .65*t**2)
            for column in range(2):
                s = column*2-1
                verts.append(centre + across * width*s + normal * width*.12*(1-s*s))
                uvs.append(((cell + .03 + .94*column)/ATLAS_CELLS, 1-t))
                shade = .76 + .24 * math.sqrt(t)
                colors.append((shade, shade, shade, 1))
                shading_normals.append(normal.copy())
            q += direction * (length/STEPS)
        for step in range(STEPS):
            a = start + step*2
            polys.append((a, a+1, a+3, a+2))
    for name, (verts, polys, uvs, colors, shading_normals) in groups.items():
        mesh_object(name, verts, polys, uvs, colors, shading_normals)
    bm.free()
    for obj in list(bpy.data.objects):
        if obj not in parts:
            bpy.data.objects.remove(obj, do_unlink=True)
    atlas()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                             export_materials="PLACEHOLDER", export_yup=True,
                             export_animations=False, export_skins=False,
                             export_vertex_color="ACTIVE")
    report = ROOT / "gauntlet/refs/visual_target_2026_10_16/cody_groom_budget.json"
    report.write_text(json.dumps({"cards": CARD_COUNT, "triangles": stats,
                                 "total_triangles": sum(stats.values()), "seed": 161026}, indent=2)+"\n")
    print("CODY_GROOM", stats, "total", sum(stats.values()))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main())
