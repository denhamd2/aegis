#!/usr/bin/env python3
"""Build the seated Tony Schiavone and Excalibur commentary-table models.

The seated body proportions and posture come from the project's licensed
Quaternius CC0 mannequin and its `Sitting_Talking_Loop` animation. Suits,
glasses, beard, headset, and Excalibur's mask layout are modeled from
`gauntlet/refs/commentators/*_sheet.png`; the sheets are references, not
runtime textures.

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

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import bpy_exit

REPO = pathlib.Path(__file__).resolve().parents[2]
OUT = REPO / "game" / "assets" / "environment"
MANNEQUIN = REPO / "game" / "assets" / "characters" / "wrestler_base.glb"


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
        bm, u_segments=32, v_segments=20, radius=1.0)
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
    mesh = bpy.data.meshes.new(name + "Mesh")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for material in materials:
        mesh.materials.append(material)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj.parent = parent
    obj.location = (0, 0, 0)
    obj.rotation_euler = (0, 0, 0)
    obj.scale = (1, 1, 1)
    return obj


def _surface_object(name, vertices, faces, material, parent, offset=(0, 0, 0), uvs=None):
    """Create a smooth, correctly wound surface in the commentator's pose space."""
    origin = Vector(offset)
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata([Vector(v) - origin for v in vertices], [], faces)
    mesh.materials.append(material)
    mesh.update()
    if uvs is not None:
        uv_layer = mesh.uv_layers.new(name="UVMap")
        for polygon in mesh.polygons:
            values = [uvs[mesh.loops[li].vertex_index][0]
                      for li in polygon.loop_indices]
            crosses_seam = max(values) - min(values) > .5
            for li in polygon.loop_indices:
                vertex_index = mesh.loops[li].vertex_index
                u, v = uvs[vertex_index]
                if crosses_seam and u < .5:
                    u += 1.0
                uv_layer.data[li].uv = (u, v)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = (0, 0, 0)
    return obj


def _tube_object(name, points, material, parent, offset=(0, 0, 0),
                 radius=0.002, closed=False, sides=8):
    """Sweep a small round mesh along a path for piping, seams and headset parts."""
    points = [Vector(p) for p in points]
    if len(points) < 2:
        return None
    rings = []
    for i, point in enumerate(points):
        if closed:
            tangent = points[(i + 1) % len(points)] - points[(i - 1) % len(points)]
        elif i == 0:
            tangent = points[1] - point
        elif i == len(points) - 1:
            tangent = point - points[i - 1]
        else:
            tangent = points[i + 1] - points[i - 1]
        tangent.normalize()
        reference = Vector((0, 1, 0))
        if abs(tangent.dot(reference)) > .88:
            reference = Vector((1, 0, 0))
        u = tangent.cross(reference).normalized()
        v = tangent.cross(u).normalized()
        rings.append([point + radius * (math.cos(j * math.tau / sides) * u +
                                        math.sin(j * math.tau / sides) * v)
                      for j in range(sides)])
    faces = []
    segment_count = len(points) if closed else len(points) - 1
    for i in range(segment_count):
        ni = (i + 1) % len(points)
        for j in range(sides):
            nj = (j + 1) % sides
            faces.append((i * sides + j, i * sides + nj,
                          ni * sides + nj, ni * sides + j))
    return _surface_object(name, [p for ring in rings for p in ring], faces,
                           material, parent, offset)


def _head_profile(role):
    """Smoothed adult head silhouette, in the same world-space pose as the base."""
    # z, centre-y, width radius, front/back depth.  The front faces -Y.
    return [
        (1.151, .148, .012, .025), (1.158, .148, .027, .045),
        (1.170, .148, .043, .064), (1.188, .148, .057, .082),
        (1.210, .148, .067, .098), (1.236, .148, .074, .108),
        (1.266, .148, .078, .113), (1.296, .148, .079, .114),
        (1.326, .148, .078, .113), (1.356, .148, .075, .109),
        (1.385, .148, .069, .101), (1.411, .148, .060, .088),
        (1.433, .148, .044, .066), (1.449, .148, .025, .040),
        (1.455, .148, .008, .014),
    ]


def _profile_at(profile, z):
    if z <= profile[0][0]:
        return profile[0]
    if z >= profile[-1][0]:
        return profile[-1]
    for a, b in zip(profile, profile[1:]):
        if a[0] <= z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            # Smoothstep prevents visible ring transitions in the custom head.
            t = t * t * (3.0 - 2.0 * t)
            return tuple(a[i] + (b[i] - a[i]) * t for i in range(4))
    return profile[-1]


def _front_y(profile, x, z, shell=0.0):
    _, cy, width, depth = _profile_at(profile, z)
    f = min(.999, abs(x) / max(width, .001))
    base = cy - depth * math.sqrt(1.0 - f * f)
    # Broad facial planes make the head read as a face rather than a smooth
    # cylinder: brow and cheek volumes, recessed eye sockets, nose bridge/tip,
    # and a small chin pad. These are intentionally subtle at game scale.
    frontness = max(0.0, 1.0 - f ** 4)
    gaussian = lambda dx, dz, sx, sz: math.exp(-((dx / sx) ** 2 + (dz / sz) ** 2))
    brow = -.0035 * sum(gaussian(x - side * .031, z - 1.343, .026, .010)
                        for side in (-1, 1))
    socket = .0024 * sum(gaussian(x - side * .031, z - 1.319, .018, .010)
                         for side in (-1, 1))
    cheek = -.0045 * sum(gaussian(x - side * .044, z - 1.278, .025, .026)
                         for side in (-1, 1))
    bridge = -.0065 * gaussian(x, z - 1.283, .014, .033)
    tip = -.010 * gaussian(x, z - 1.260, .018, .012)
    chin = -.0025 * gaussian(x, z - 1.177, .036, .012)
    return base + frontness * (brow + socket + cheek + bridge + tip + chin) - shell


def _head_surface(role, head_pivot, materials, profile):
    segments = 64
    vertices, faces = [], []
    # Interpolate between silhouette landmarks to get dense, smooth topology.
    rows = []
    for a, b in zip(profile, profile[1:]):
        for step in range(4):
            t = step / 4.0
            z = a[0] + (b[0] - a[0]) * t
            _, cy, width, depth = _profile_at(profile, z)
            rows.append((z, cy, width, depth))
    rows.append(profile[-1])
    uvs = []
    for row_index, (z, cy, width, depth) in enumerate(rows):
        for j in range(segments):
            angle = math.tau * j / segments
            x = width * math.sin(angle)
            base = cy - depth * math.cos(angle)
            frontness = max(0.0, math.cos(angle)) ** 4
            vertices.append((x, base + frontness * (_front_y(profile, x, z) - base), z))
            uvs.append((j / segments, row_index / max(1, len(rows) - 1)))
    for i in range(len(rows) - 1):
        for j in range(segments):
            jn = (j + 1) % segments
            a = i * segments + j
            b = i * segments + jn
            c = (i + 1) * segments + jn
            d = (i + 1) * segments + j
            faces.append((a, b, c, d))
    _surface_object(role + "SculptedHead", vertices, faces,
                    materials["skin"], head_pivot, (0, .165, 1.176), uvs)


def _surface_point(profile, x, z, extra=.0):
    return (x, _front_y(profile, x, z, extra), z)


def _build_beard(role, head_pivot, materials, profile):
    # A shaped, surface-conforming beard follows the jaw and leaves a clear
    # mouth line; distinct upper/lower silhouettes avoid the old sphere blob.
    rows = [(1.160, .023), (1.169, .040), (1.181, .054), (1.196, .064),
            (1.213, .068), (1.229, .067), (1.243, .062), (1.255, .052),
            (1.266, .038), (1.272, .021)]
    columns = 24
    verts, faces = [], []
    for z, half_width in rows:
        for col in range(columns + 1):
            x = -half_width + 2 * half_width * col / columns
            verts.append(_surface_point(profile, x, z, .003))
    for row in range(len(rows) - 1):
        for col in range(columns):
            a = row * (columns + 1) + col
            b = a + 1
            c = b + columns + 1
            d = a + columns + 1
            faces.append((a, b, c, d))
    _surface_object(role + "ShapedBeard", verts, faces, materials["beard"],
                    head_pivot, (0, .165, 1.176))
    # Separate moustache lobes frame the exposed lip instead of obscuring it.
    moustache = []
    for side in (-1, 1):
        moustache += [
            ("sphere", (side * .014, .028, 1.239), (.019, .009, .008), 0),
        ]
    mesh_object(role + "Moustache", moustache, [materials["beard"]],
                head_pivot, offset=(0, .165, 1.176))


def _build_eyes_and_face(role, head_pivot, materials, profile, masked=False):
    names = ["skin", "eye", "iris", "pupil", "brow", "lip"]
    shapes = []
    for side in (-1, 1):
        x = side * .031
        z = 1.319
        y = _front_y(profile, x, z, .006)
        shapes.extend([
            ("sphere", (x, y, z), (.011, .0055, .006), 1),
            ("sphere", (x - side * .001, y - .005, z), (.0037, .0022, .004), 2),
            ("sphere", (x - side * .001, y - .0068, z), (.0015, .0012, .0022), 3),
        ])
        if not masked:
            shapes.extend([
                ("sphere", (side * .032, _front_y(profile, side * .032, 1.342, .003), 1.342),
                 (.020, .006, .0045), 4),
                ("sphere", (side * .034, _front_y(profile, side * .034, 1.314, .001), 1.314),
                 (.015, .0025, .002), 0),
            ])
    # Nose bridge and tip create a readable profile at the three-quarter view.
    if not masked:
        shapes.extend([
            ("sphere", (0, _front_y(profile, 0, 1.286, .004), 1.286), (.008, .009, .022), 0),
            ("sphere", (0, _front_y(profile, 0, 1.263, .008), 1.263), (.011, .008, .007), 0),
            ("sphere", (-.006, _front_y(profile, -.006, 1.256, .007), 1.256), (.002, .0015, .0014), 5),
            ("sphere", (.006, _front_y(profile, .006, 1.256, .007), 1.256), (.002, .0015, .0014), 5),
        ])
    shapes.append(("sphere", (0, _front_y(profile, 0, 1.224, .004), 1.224),
                   (.010, .002, .0018), 5))
    mesh_object(role + "FacialFeatures", shapes,
                [materials[n] for n in names], head_pivot,
                offset=(0, .165, 1.176))
    # Raised eyelid and lower-eye creases, shaped brows, and small ears add
    # human facial planes without making oversized cartoon features.
    for side in (-1, 1):
        x = side * .031
        eye_path = []
        for step in range(9):
            t = math.pi * step / 8
            px = x + .014 * math.cos(t)
            pz = 1.319 + .008 * math.sin(t)
            eye_path.append(_surface_point(profile, px, pz, .009))
        if not masked:
            _tube_object(role + "UpperLid" + str(side), eye_path, materials["skin"],
                         head_pivot, (0, .165, 1.176), .0011)
            ear = [("sphere", (side * .078, .135, 1.292), (.012, .023, .027), 0),
                   ("sphere", (side * .087, .126, 1.292), (.003, .009, .016), 5)]
            mesh_object(role + "Ear" + str(side), ear, [materials["skin"], materials["lip"]],
                        head_pivot, offset=(0, .165, 1.176))


def _build_tony_identity(head_pivot, materials, profile):
    # A swept side part, shaped jaw beard, eyes and nose replace the imported
    # mannequin face with a mature adult likeness at the broadcast close-up.
    hair_profile = [
        (1.358, .148, .062, .091), (1.372, .148, .069, .101),
        (1.389, .148, .071, .104), (1.408, .148, .065, .097),
        (1.427, .148, .051, .079), (1.438, .148, .047, .072),
        (1.444, .148, .044, .067), (1.449, .148, .038, .058),
        (1.452, .148, .029, .045), (1.455, .148, .016, .027),
    ]
    segments = 64
    verts, faces = [], []
    for z, cy, width, depth in hair_profile:
        for j in range(segments):
            angle = math.tau * j / segments
            x = width * math.sin(angle)
            # A slightly higher center hairline creates the receding sweep in
            # Tony's sheet; the temples retain a lower, natural edge.
            frontness = max(0.0, math.cos(angle)) ** 5
            z_adjust = .008 * math.exp(-((x / .026) ** 2)) * frontness
            verts.append((x, cy - depth * math.cos(angle), z + z_adjust))
    for row in range(len(hair_profile) - 1):
        for col in range(segments):
            nxt = (col + 1) % segments
            a = row * segments + col
            b = row * segments + nxt
            c = (row + 1) * segments + nxt
            d = (row + 1) * segments + col
            faces.append((a, b, c, d))
    top_index = len(verts)
    verts.append((0, .148, 1.456))
    last_row = (len(hair_profile) - 1) * segments
    for col in range(segments):
        faces.append((last_row + col, last_row + (col + 1) % segments, top_index))
    _surface_object("TonySweptHair", verts, faces, materials["hair"],
                    head_pivot, (0, .165, 1.176))
    # Side-part grooves and a few short swept locks keep the cap from reading
    # as a smooth helmet at a close camera distance.
    strands = [
        [( -.040, .065, 1.377), (-.032, .078, 1.396), (-.016, .095, 1.420),
         (.012, .116, 1.440), (.039, .139, 1.427)],
        [(-.018, .051, 1.383), (-.009, .078, 1.405), (.010, .103, 1.432),
         (.034, .125, 1.435)],
    ]
    for i, path in enumerate(strands):
        _tube_object("TonyHairSweep" + str(i), path,
                     materials["hairlight"] if i == 0 else materials["hair"],
                     head_pivot, (0, .165, 1.176), .0015 if i == 0 else .0011)
    _build_beard("Tony", head_pivot, materials, profile)
    # Fine, short strand relief follows the beard's cheek-to-chin direction.
    for side in (-1, 1):
        for row, z in enumerate((1.184, 1.198, 1.212, 1.226, 1.239, 1.249)):
            x0 = side * (.018 + (row % 3) * .010)
            width = .006 + (row % 2) * .003
            path = [_surface_point(profile, x0 + side * dx, z + dz, .006)
                    for dx, dz in ((-width, -.003), (0, 0), (width, .004))]
            _tube_object("TonyBeardTexture_%d_%d" % (side, row), path,
                         materials["hair"], head_pivot,
                         (0, .165, 1.176), .00055)
    _build_eyes_and_face("Tony", head_pivot, materials, profile)
    # Rectangular blue-black prescription frames, fitted around both eyes.
    for side in (-1, 1):
        cx = side * .031
        zc = 1.319
        half_w, half_h, corner = .026, .018, .005
        frame = []
        for corner_index, (sx, sz, start) in enumerate([
                (1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)]):
            for q in range(5):
                angle = math.radians(start + q * 90 / 4)
                x = cx + sx * (half_w - corner) + corner * math.cos(angle)
                z = zc + sz * (half_h - corner) + corner * math.sin(angle)
                frame.append(_surface_point(profile, x, z, .014))
        _tube_object("TonyGlassesFrame" + str(side), frame, materials["frame"],
                     head_pivot, (0, .165, 1.176), .0026, closed=True)
    bridge = [_surface_point(profile, x, 1.319, .014) for x in (-.008, 0, .008)]
    _tube_object("TonyGlassesBridge", bridge, materials["frame"], head_pivot,
                 (0, .165, 1.176), .0025)
    for side in (-1, 1):
        temple = [_surface_point(profile, side * x, z, .008)
                  for x, z in ((.055, 1.323), (.073, 1.319), (.094, 1.309))]
        _tube_object("TonyGlassesTemple" + str(side), temple, materials["frame"],
                     head_pivot, (0, .165, 1.176), .0024)


def _mask_shell(head_pivot, materials, profile):
    segments = 128
    rows = 64
    z_min, z_max = 1.169, 1.454
    vertices, faces, uvs = [], [], []
    for row in range(rows + 1):
        z = z_min + (z_max - z_min) * row / rows
        _, cy, width, depth = _profile_at(profile, z)
        for col in range(segments):
            theta = math.tau * col / segments
            x = (width + .0025) * math.sin(theta)
            front = max(0.0, math.cos(theta))
            nose_ridge = .008 * math.exp(-((z - 1.275) / .038) ** 2) * front ** 8
            y = cy - (depth + .003) * math.cos(theta) - nose_ridge
            vertices.append((x, y, z))
            uvs.append((col / segments, row / rows))
    for row in range(rows):
        zc = z_min + (z_max - z_min) * (row + .5) / rows
        for col in range(segments):
            next_col = (col + 1) % segments
            theta = math.tau * (col + .5) / segments
            _, _, width, _ = _profile_at(profile, zc)
            x = (width + .0025) * math.sin(theta)
            is_front = math.cos(theta) > .55
            eye_hole = any(((x - side * .032) / .028) ** 2 +
                           ((zc - 1.320) / .017) ** 2 < 1.0
                           for side in (-1, 1))
            mouth_hole = is_front and abs(x) < .039 and 1.207 < zc < 1.235
            if is_front and (eye_hole or mouth_hole):
                continue
            a = row * segments + col
            b = row * segments + next_col
            c = (row + 1) * segments + next_col
            d = (row + 1) * segments + col
            faces.append((a, b, c, d))
    _surface_object("ExcaliburFullHeadMaskShell", vertices, faces,
                    materials["mask"], head_pivot, (0, .165, 1.176), uvs)


def _build_excalibur_identity(head_pivot, materials, profile):
    _build_beard("Excalibur", head_pivot, materials, profile)
    _build_eyes_and_face("Excalibur", head_pivot, materials, profile, masked=True)
    _mask_shell(head_pivot, materials, profile)
    def shell_point(x, z, extra=.006):
        _, _, width, _ = _profile_at(profile, z)
        x = max(-width * .97, min(width * .97, x))
        return _surface_point(profile, x, z, extra)
    # Gold crown chevrons and side filigree follow the mask surface rather than
    # floating as flat triangles in front of the face.
    motifs = [
        ("ExcaliburGoldCrown", [(-.064, 1.381), (-.047, 1.402),
                                (-.023, 1.388), (0, 1.407), (.023, 1.388),
                                (.047, 1.402), (.064, 1.381)]),
        ("ExcaliburCrownCenter", [(-.041, 1.392), (0, 1.426), (.041, 1.392)]),
        ("ExcaliburLeftCheekGold", [(-.061, 1.302), (-.073, 1.278),
                                     (-.067, 1.244), (-.052, 1.226)]),
        ("ExcaliburRightCheekGold", [(.061, 1.302), (.073, 1.278),
                                      (.067, 1.244), (.052, 1.226)]),
        ("ExcaliburLeftCheekWhite", [(-.053, 1.300), (-.063, 1.277),
                                      (-.059, 1.251)]),
        ("ExcaliburRightCheekWhite", [(.053, 1.300), (.063, 1.277),
                                       (.059, 1.251)]),
    ]
    for name, path in motifs:
        color = materials["white"] if "White" in name else materials["gold"]
        _tube_object(name, [shell_point(x, z, .006) for x, z in path],
                     color, head_pivot, (0, .165, 1.176), .0032)
    for side in (-1, 1):
        # AEW's mask has swept, angular eye borders rather than round goggles.
        eye_shape = [(0.000, -.012), (.015, -.015), (.027, -.006),
                     (.023, .008), (.010, .015), (-.012, .012),
                     (-.027, .003), (-.021, -.008)]
        eye_outline = [shell_point(side * (.032 + dx), 1.320 + dz, .007)
                       for dx, dz in eye_shape]
        _tube_object("ExcaliburEyeTrim" + str(side), eye_outline,
                     materials["white"], head_pivot, (0, .165, 1.176), .0015,
                     closed=True)
    # The mask's center seam and short stitch marks wrap over the crown and back.
    seam = []
    for i in range(25):
        z = 1.198 + (1.445 - 1.198) * i / 24
        seam.append((0, _profile_at(profile, z)[1] + _profile_at(profile, z)[3] + .005, z))
    _tube_object("ExcaliburRearMaskSeam", seam, materials["gold"],
                 head_pivot, (0, .165, 1.176), .002)


def _build_headset(role, head_pivot, materials):
    shapes = []
    for side in (-1, 1):
        # Distinct padded cup, outer shell and hinge on either side of the mask.
        shapes.extend([
            ("sphere", (side * .090, .150, 1.316), (.025, .039, .046), 0),
            ("sphere", (side * .105, .145, 1.316), (.013, .030, .036), 1),
            ("sphere", (side * .114, .145, 1.316), (.004, .021, .026), 2),
        ])
    mesh_object(role + "BroadcastHeadsetCups", shapes,
                [materials["dark"], materials["headset"], materials["gold"]],
                head_pivot, offset=(0, .165, 1.176))
    band = [(-.095, .151, 1.342), (-.083, .151, 1.391),
            (-.052, .151, 1.426), (0, .151, 1.438),
            (.052, .151, 1.426), (.083, .151, 1.391), (.095, .151, 1.342)]
    _tube_object(role + "HeadsetBand", band, materials["headset"], head_pivot,
                 (0, .165, 1.176), .006)
    # Boom is placed on the commentator's left, clear of mask eye/cheek design.
    boom = [(-.102, .115, 1.301), (-.096, .082, 1.278),
            (-.078, .039, 1.250), (-.050, .015, 1.241)]
    _tube_object(role + "HeadsetBoom", boom, materials["dark"], head_pivot,
                 (0, .165, 1.176), .003)
    tip = [("sphere", (-.049, .012, 1.240), (.010, .008, .008), 0)]
    mesh_object(role + "Microphone", tip, [materials["dark"]], head_pivot,
                offset=(0, .165, 1.176))


def _srgb(linear):
    return 12.92 * linear if linear <= .0031308 else 1.055 * (linear ** (1.0 / 2.4)) - .055


def _apply_skin_detail(material, role):
    """Small packed skin color/normal maps keep the sculpt from reading flat."""
    size = 256
    base = tuple(material.diffuse_color[:3])
    seed = 7 if role == "Tony" else 19
    color_pixels, normal_pixels = [], []
    for y in range(size):
        v = y / size
        for x in range(size):
            u = x / size
            broad = (math.sin((u * 7.0 + v * 2.0 + seed) * math.tau) * .010 +
                     math.sin((v * 13.0 - u * 3.0 + seed * .37) * math.tau) * .006 +
                     math.sin((u * 53.0 + v * 37.0 + seed) * math.tau) * .003)
            pore = math.sin((u * 193.0 + seed) * math.tau) * math.sin((v * 181.0 - seed) * math.tau) * .003
            variation = broad + pore
            for channel, value in enumerate(base):
                color_pixels.append(_srgb(max(0.0, min(1.0, value * (1.0 + variation)))))
            color_pixels.append(1.0)
            # Very restrained tangent-space micro relief, packed as a standard
            # OpenGL normal map for glTF and Godot's PBR shader.
            dx = .03 * math.cos((u * 193.0 + seed) * math.tau) * math.sin((v * 181.0 - seed) * math.tau)
            dy = .03 * math.sin((u * 193.0 + seed) * math.tau) * math.cos((v * 181.0 - seed) * math.tau)
            nx, ny, nz = -dx, -dy, 1.0
            length = math.sqrt(nx * nx + ny * ny + nz * nz)
            normal_pixels.extend((.5 + .5 * nx / length, .5 + .5 * ny / length,
                                  .5 + .5 * nz / length, 1.0))
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    color = bpy.data.images.new(role + "SkinColor", width=size, height=size, alpha=True)
    color.pixels.foreach_set(color_pixels)
    color.pack()
    color_node = nodes.new("ShaderNodeTexImage")
    color_node.name = role + "SkinColorTexture"
    color_node.image = color
    links.new(color_node.outputs["Color"], bsdf.inputs["Base Color"])
    normal = bpy.data.images.new(role + "SkinNormal", width=size, height=size, alpha=True)
    normal.colorspace_settings.name = "Non-Color"
    normal.pixels.foreach_set(normal_pixels)
    normal.pack()
    normal_tex = nodes.new("ShaderNodeTexImage")
    normal_tex.name = role + "SkinNormalTexture"
    normal_tex.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = .15
    links.new(normal_tex.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])


def _apply_mask_fabric(material, role):
    """Packed, subtle black woven-cloth color and normal detail for the mask."""
    size = 256
    base = tuple(material.diffuse_color[:3])
    color_pixels, normal_pixels = [], []
    for y in range(size):
        v = y / size
        for x in range(size):
            u = x / size
            weave = .025 * (math.sin(u * math.tau * 128) ** 8 +
                            math.sin(v * math.tau * 128) ** 8)
            shade = max(.55, 1.0 - weave)
            for value in base:
                color_pixels.append(_srgb(min(1.0, value * shade)))
            color_pixels.append(1.0)
            dx = .035 * math.cos(u * math.tau * 128) * math.sin(v * math.tau * 128)
            dy = .035 * math.sin(u * math.tau * 128) * math.cos(v * math.tau * 128)
            length = math.sqrt(dx * dx + dy * dy + 1.0)
            normal_pixels.extend((.5 - .5 * dx / length, .5 - .5 * dy / length,
                                  .5 + .5 / length, 1.0))
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    color = bpy.data.images.new(role + "MaskFabricColor", width=size, height=size, alpha=True)
    color.pixels.foreach_set(color_pixels)
    color.pack()
    color_node = nodes.new("ShaderNodeTexImage")
    color_node.name = role + "MaskFabricColorTexture"
    color_node.image = color
    links.new(color_node.outputs["Color"], bsdf.inputs["Base Color"])
    normal = bpy.data.images.new(role + "MaskFabricNormal", width=size, height=size, alpha=True)
    normal.colorspace_settings.name = "Non-Color"
    normal.pixels.foreach_set(normal_pixels)
    normal.pack()
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_node.name = role + "MaskFabricNormalTexture"
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = .22
    links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])


def _commentator_materials(role: str):
    """Low-sheen broadcast cloth and natural skin, with reference-sheet colors."""
    result = {
        "skin": mat(role + "_Skin", (.43, .27, .21) if role == "Tony" else (.42, .25, .20), .80),
        "hair": mat(role + "_Hair", (.080, .038, .024) if role == "Tony" else (.045, .023, .016), .82),
        "hairlight": mat(role + "_HairHighlight", (.13, .078, .048), .80),
        "beard": mat(role + "_Beard", (.065, .027, .018) if role == "Tony" else (.060, .026, .018), .86),
        "frame": mat(role + "_GlassesFrame", (.012, .023, .047), .42, .04),
        "eye": mat(role + "_EyeWhite", (.67, .54, .45), .50),
        "iris": mat(role + "_Iris", (.16, .075, .035), .38),
        "pupil": mat(role + "_Pupil", (.012, .009, .008), .22),
        "brow": mat(role + "_Brow", (.09, .047, .029), .82),
        "lip": mat(role + "_Lip", (.24, .095, .075), .68),
        "shirt": mat(role + "_Shirt", (.82, .80, .75), .9),
        "jacket": mat(role + "_Suit", (.12, .012, .032) if role == "Tony" else (.016, .020, .028), .78),
        "pants": mat(role + "_Trousers", (.018, .021, .027) if role == "Tony" else (.11, .12, .135), .9),
        "shoes": mat(role + "_Shoes", (.012, .013, .016), .38, .04),
        "tie": mat(role + "_Tie", (.035, .006, .018) if role == "Tony" else (.019, .020, .024), .72),
        "gold": mat(role + "_Gold", (.63, .36, .075), .39, .22),
        "white": mat(role + "_MaskWhite", (.62, .65, .67), .62),
        "dark": mat(role + "_MaskHeadset", (.004, .005, .007), .74),
        "mask": mat(role + "_MaskFabric", (.003, .0035, .005), .86),
        "headset": mat(role + "_HeadsetShell", (.052, .058, .064), .40, .12),
        "lens": mat(role + "_Lens", (.018, .026, .032), .22, .04),
        "accent": mat(role + "_Accent", (.62, .012, .07), .58),
    }
    _apply_skin_detail(result["skin"], role)
    if role == "Excalibur":
        _apply_mask_fabric(result["mask"], role)
    return result


def _weights_for_face(source, face, vertex_group_names):
    weights = {}
    for vertex_index in face.vertices:
        vertex = source.data.vertices[vertex_index]
        for assignment in vertex.groups:
            name = vertex_group_names.get(assignment.group, "")
            weights[name] = weights.get(name, 0.0) + assignment.weight / len(face.vertices)
    return weights


def _partition_baked_mesh(source, root, materials, role):
    """Bake the mannequin's CC0 seated-idle pose and dress it by skin weights."""
    armature = bpy.data.objects.get("Armature")
    if armature is None or "Sitting_Idle_Loop_Armature" not in bpy.data.actions:
        raise RuntimeError("wrestler_base.glb needs its Armature and sitting-idle action")
    armature.animation_data_create()
    # The bundled talking-seat pose puts both hands naturally on the desk;
    # the quiet idle pose leaves them down in the lap behind the table.
    armature.animation_data.action = bpy.data.actions["Sitting_Talking_Loop_Armature"]
    bpy.context.scene.frame_set(20)
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = source.evaluated_get(depsgraph)
    baked = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True,
                                             depsgraph=depsgraph)
    source.data = baked
    source.modifiers.clear()
    source.parent = root
    source.matrix_world.identity()
    source.name = role + "SeatedMannequin"

    slot_names = ["skin", "jacket", "pants", "shoes"]
    source.data.materials.clear()
    for name in slot_names:
        source.data.materials.append(materials[name])
    groups = {g.index: g.name for g in source.vertex_groups}
    for face in source.data.polygons:
        weights = _weights_for_face(source, face, groups)
        shoe = sum(v for n, v in weights.items() if n.startswith("foot_") or n.startswith("ball_"))
        leg = sum(v for n, v in weights.items() if n.startswith("thigh_") or n.startswith("calf_"))
        skin = weights.get("Head", 0.0) + weights.get("neck_01", 0.0)
        for name, value in weights.items():
            if name in {"hand_l", "hand_r"} or name.startswith(("index_", "middle_", "ring_", "pinky_", "thumb_")):
                skin += value
        if shoe > .35:
            face.material_index = slot_names.index("shoes")
        elif leg > .38:
            face.material_index = slot_names.index("pants")
        elif skin > .38:
            face.material_index = slot_names.index("skin")
        else:
            face.material_index = slot_names.index("jacket")
        face.use_smooth = True

    head_bone = armature.pose.bones["Head"]
    head_origin = armature.matrix_world @ head_bone.matrix.translation
    # Keep the anatomy rig pivots the game actor animates. The head's weighted
    # region and identity accessories are isolated under HeadPivot so nods move
    # the actual head, not just floating props.
    head_pivot = pivot("HeadPivot", tuple(head_origin), parent=root)
    spine_pivot = pivot("SpinePivot", (0, 0, .70), parent=root)
    left_origin = armature.matrix_world @ armature.pose.bones["upperarm_l"].matrix.translation
    right_origin = armature.matrix_world @ armature.pose.bones["upperarm_r"].matrix.translation
    arm_l = pivot("ArmLeftPivot", tuple(left_origin), parent=root)
    arm_r = pivot("ArmRightPivot", tuple(right_origin), parent=root)
    # Bake head vertices into their own pivoted mesh; this preserves a clean
    # neck seam and lets the existing restrained speaking nod remain visible.
    head_group = source.vertex_groups.get("Head")
    if head_group is not None:
        head_index = head_group.index
        head_faces = []
        body_faces = []
        for face in source.data.polygons:
            mean = sum(next((g.weight for g in source.data.vertices[i].groups if g.group == head_index), 0.0)
                       for i in face.vertices) / len(face.vertices)
            (head_faces if mean > .45 else body_faces).append(face.index)
        # Keep the full head with the body when this particular importer does
        # not preserve enough head weights to split it without visible seams.
        if head_faces and len(head_faces) > 40:
            def make_part(name, polygon_indices, parent, origin):
                polys = [source.data.polygons[i] for i in polygon_indices]
                used = sorted({vi for p in polys for vi in p.vertices})
                mapping = {old: new for new, old in enumerate(used)}
                verts = [source.data.vertices[i].co - origin for i in used]
                faces = [[mapping[i] for i in p.vertices] for p in polys]
                mesh = bpy.data.meshes.new(name + "Mesh")
                mesh.from_pydata(verts, [], faces)
                mesh.update()
                for material in source.data.materials:
                    mesh.materials.append(material)
                for p, old_poly in zip(mesh.polygons, polys):
                    p.material_index = old_poly.material_index
                    p.use_smooth = True
                obj = bpy.data.objects.new(name, mesh)
                bpy.context.collection.objects.link(obj)
                obj.parent = parent
                obj.location = (0, 0, 0)
                return obj
            left_arm_faces = []
            right_arm_faces = []
            torso_faces = []
            for face_index in body_faces:
                face = source.data.polygons[face_index]
                weights = _weights_for_face(source, face, groups)
                left_weight = sum(value for name, value in weights.items()
                                  if name.endswith("_l") or name.endswith("_leaf_l"))
                right_weight = sum(value for name, value in weights.items()
                                   if name.endswith("_r") or name.endswith("_leaf_r"))
                if left_weight > .52 and left_weight > right_weight:
                    left_arm_faces.append(face_index)
                elif right_weight > .52 and right_weight > left_weight:
                    right_arm_faces.append(face_index)
                else:
                    torso_faces.append(face_index)
            # The low-detail mannequin head is deliberately omitted. A bespoke
            # head is fitted to each reference below; retaining the base would
            # show through the Excalibur shell and flatten Tony's facial planes.
            make_part(role + "SeatedBody", torso_faces, root, Vector((0, 0, 0)))
            if left_arm_faces:
                make_part(role + "LeftArm", left_arm_faces, arm_l, left_origin)
            if right_arm_faces:
                make_part(role + "RightArm", right_arm_faces, arm_r, right_origin)
            bpy.data.objects.remove(source, do_unlink=True)
    return head_pivot, spine_pivot, arm_l, arm_r


def _build_tailoring(role, root, materials):
    """Raised shirt, collar, tie and restrained suit details on the posed base."""
    names = list(materials)
    ix = {name: i for i, name in enumerate(names)}
    # Front of the Quaternius humanoid points toward local -Y.
    shapes = [
        ("tri", [(-.036, .036, 1.145), (-.008, .022, 1.105), (-.046, .03, 1.075)], ix["shirt"]),
        ("tri", [(.036, .036, 1.145), (.008, .022, 1.105), (.046, .03, 1.075)], ix["shirt"]),
        ("sphere", (0, .018, 1.145), (.043, .023, .017), ix["shirt"]),
        ("sphere", (0, .002, 1.126), (.020, .010, .014), ix["tie"]),
        ("sphere", (0, -.003, 1.01), (.014, .008, .095), ix["tie"]),
        ("tri", [(-.014, -.005, .915), (.014, -.005, .915), (0, -.006, .885)], ix["tie"]),
    ]
    if role == "Tony":
        for z in (.96, 1.0, 1.04, 1.08):
            shapes.append(("sphere", (0, -.002, z), (.004, .003, .004), ix["accent"]))
        shapes.append(("sphere", (.21, .04, 1.04), (.018, .009, .010), ix["accent"]))
    else:
        shapes.append(("box", (.20, .026, 1.12), (.065, .008, .040), ix["dark"]))
        shapes.append(("box", (.20, .02, 1.12), (.045, .006, .006), ix["shirt"]))
    mesh_object(role + "Tailoring", shapes, [materials[n] for n in names], root)


def _build_identity(role, head_pivot, materials):
    profile = _head_profile(role)
    _head_surface(role, head_pivot, materials, profile)
    if role == "Tony":
        _build_tony_identity(head_pivot, materials, profile)
    else:
        _build_excalibur_identity(head_pivot, materials, profile)
    _build_headset(role, head_pivot, materials)


def build(role: str, out_path: pathlib.Path):
    clear()
    materials = _commentator_materials(role)
    bpy.ops.import_scene.gltf(filepath=str(MANNEQUIN))
    for obj in list(bpy.context.scene.objects):
        if obj.name not in {"Mannequin", "Armature"}:
            bpy.data.objects.remove(obj, do_unlink=True)
    root = pivot(role + "Commentator")
    source = bpy.data.objects.get("Mannequin")
    if source is None:
        raise RuntimeError("Could not import CC0 mannequin from " + str(MANNEQUIN))
    head_pivot, _spine, _arm_l, _arm_r = _partition_baked_mesh(source, root, materials, role)
    # Remove imported armature and any importer residue after the sitting pose
    # has been baked into a static, lightweight mesh.
    for obj in list(bpy.context.scene.objects):
        if obj != root and obj.parent != root and obj.parent != head_pivot and obj.type in {"ARMATURE", "CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)
    _build_tailoring(role, root, materials)
    _build_identity(role, head_pivot, materials)
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
