"""Build the first Beechlawn human player mesh on the existing Mixamo rig.

Run from repository root:
  blender -b --python tools/blender/beechlawn/build_shane_denham_player.py

The existing 65-bone skeleton and authored animation actions are retained.
The Y-Bot shell is replaced with a lightweight, smooth human-form prototype
guided by the archived Shane Denham #8 and Beechlawn kit sheets. This is a
repeatable first modeling pass, not a final likeness approval.
"""
from pathlib import Path
import bpy
import math
import bmesh
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "games/beechlawn_rovers/tools/blender/y_bot_animation_library.blend"
BLEND_OUT = ROOT / "tools/blender/beechlawn/shane_denham_08.blend"
GLB_OUT = ROOT / "games/beechlawn_rovers/assets/characters/_prototypes/shane_denham_08_prototype.glb"


def material(name, color, roughness=0.82, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = 0.035 if name.startswith("MAT_Skin") else 0.0
    return mat


SKIN = HAIR = EYE_WHITE = IRIS = PUPIL = BOOT = BOOT_TRIM = None
SHORTS = SOCK = BLUE = BLACK = WHITE = CREST = JERSEY = None
FACE_SKIN = None
ROOT = Path(__file__).resolve().parents[3]
FABRIC_TEXTURE = ROOT / "games/beechlawn_rovers/assets/characters/textures/beechlawn_jersey_fabric_reference.png"
JERSEY_ATLAS = ROOT / "games/beechlawn_rovers/assets/characters/textures/beechlawn_home_shane_08_albedo.png"
MAKEHUMAN_BASE = ROOT / "games/beechlawn_rovers/references/third_party/makehuman/base.obj"


def create_materials():
    global SKIN, HAIR, EYE_WHITE, IRIS, PUPIL, BOOT, BOOT_TRIM
    global SHORTS, SOCK, BLUE, BLACK, WHITE, CREST, JERSEY
    SKIN = material("MAT_Skin_FairNatural", (0.52, 0.31, 0.23), .72)
    HAIR = material("MAT_Hair_ShortBrown", (0.095, 0.044, 0.022), .78)
    EYE_WHITE = material("MAT_Eye_OffWhite", (0.74, 0.70, 0.62), .36)
    IRIS = material("MAT_Eye_HazelBrown", (0.15, 0.075, 0.028), .3)
    PUPIL = material("MAT_Eye_Pupil", (0.012, 0.009, 0.007), .2)
    BOOT = material("MAT_Boot_BlackLeather", (0.025, 0.029, 0.032), .5)
    BOOT_TRIM = material("MAT_Boot_BlueTrim", (0.04, 0.14, 0.36), .56)
    SHORTS = material("MAT_Shorts_Black", (0.018, 0.02, 0.025), .82)
    SOCK = material("MAT_Sock_Black", (0.02, 0.025, 0.031), .9)
    BLUE = material("MAT_Kit_RoyalBlue", (0.025, 0.16, 0.58), .8)
    BLACK = material("MAT_Kit_Black", (0.012, 0.015, 0.02), .84)
    WHITE = material("MAT_Kit_White", (0.82, 0.82, 0.76), .77)
    CREST = material("MAT_Crest_WhiteBlue", (0.78, 0.82, 0.78), .72)
    JERSEY = material("MAT_Beechlawn_HomeKit_Atlas", (0.03, 0.12, 0.40), .84)
    if JERSEY_ATLAS.exists():
        atlas_image = bpy.data.images.load(str(JERSEY_ATLAS), check_existing=True)
        atlas_image.pack()
        atlas_tex = JERSEY.node_tree.nodes.new("ShaderNodeTexImage")
        atlas_tex.name = "BeechlawnFullShirtDesign_ReferenceUV"
        atlas_tex.image = atlas_image
        atlas_tex.interpolation = "Linear"
        atlas_uv = JERSEY.node_tree.nodes.new("ShaderNodeUVMap")
        atlas_uv.uv_map = "JerseyUV"
        JERSEY.node_tree.links.new(atlas_uv.outputs["UV"], atlas_tex.inputs["Vector"])
        JERSEY.node_tree.links.new(atlas_tex.outputs["Color"],
                                   JERSEY.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
        JERSEY.node_tree.nodes.active = atlas_tex
    apply_reference_fabric()


def apply_reference_fabric():
    """Use the supplied kit-board knit swatch as subtle fabric relief.

    The dark/royal-blue panel colors remain authored by the jersey materials;
    the image drives small-scale knit roughness and bump so it does not replace
    the reference's distinct black/blue panel layout.
    """
    if not FABRIC_TEXTURE.exists():
        return
    image = bpy.data.images.load(str(FABRIC_TEXTURE), check_existing=True)
    for mat in (BLUE, BLACK, JERSEY):
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links
        bsdf = nodes.get("Principled BSDF")
        texcoord = nodes.new("ShaderNodeTexCoord")
        scale = nodes.new("ShaderNodeVectorMath")
        scale.operation = "SCALE"
        scale.inputs[3].default_value = 24.0
        links.new(texcoord.outputs["UV"], scale.inputs[0])
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = image
        texture.extension = "REPEAT"
        texture.interpolation = "Linear"
        links.new(scale.outputs["Vector"], texture.inputs["Vector"])
        gray = nodes.new("ShaderNodeRGBToBW")
        links.new(texture.outputs["Color"], gray.inputs["Color"])
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.09
        bump.inputs["Distance"].default_value = 0.0012
        links.new(gray.outputs["Val"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
        roughness = nodes.new("ShaderNodeMapRange")
        roughness.inputs["From Min"].default_value = 0.0
        roughness.inputs["From Max"].default_value = 1.0
        roughness.inputs["To Min"].default_value = 0.74
        roughness.inputs["To Max"].default_value = 0.90
        links.new(gray.outputs["Val"], roughness.inputs["Value"])
        links.new(roughness.outputs["Result"], bsdf.inputs["Roughness"])


def make_shane_face_material():
    """Create plain procedural skin; the portrait remains reference-only."""
    mat = bpy.data.materials.new("MAT_Skin_Shane_Procedural_NoPhoto")
    mat.diffuse_color = (0.62, 0.39, 0.32, 1.0)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = .68
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = .025
    coordinates = nodes.new("ShaderNodeTexCoord")
    color_noise = nodes.new("ShaderNodeTexNoise")
    color_noise.inputs["Scale"].default_value = 24.0
    color_noise.inputs["Detail"].default_value = 2.0
    links.new(coordinates.outputs["Generated"], color_noise.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = .22
    ramp.color_ramp.elements[0].color = (.46, .25, .19, 1.0)
    ramp.color_ramp.elements[1].position = .78
    ramp.color_ramp.elements[1].color = (.56, .33, .26, 1.0)
    links.new(color_noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    pores = nodes.new("ShaderNodeTexNoise")
    pores.inputs["Scale"].default_value = 190.0
    pores.inputs["Detail"].default_value = 2.0
    links.new(coordinates.outputs["Generated"], pores.inputs["Vector"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = .075
    bump.inputs["Distance"].default_value = .00035
    links.new(pores.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def add_uv_head():
    """Extract and reference-sculpt the real MakeHuman face topology.

    This deliberately replaces the rejected ellipsoid/portrait projection.
    Shane's sheet supplies front and side landmarks; the licensed base mesh
    supplies continuous facial anatomy, ears, eye sockets and the actual nose
    and mouth forms. Localized vertex displacements adjust its jaw, cheeks,
    nose bridge/tip, brow and chin while preserving that topology and its
    head-bone fit. The portrait is not used as a texture.
    """
    raw_vertices, groups = [], {}
    group = ""
    for line in MAKEHUMAN_BASE.read_text().splitlines():
        if line.startswith("v "):
            raw_vertices.append(tuple(float(value) for value in line.split()[1:4]))
        elif line.startswith("g "):
            group = line.split(maxsplit=1)[1]
            groups.setdefault(group, [])
        elif line.startswith("f "):
            groups.setdefault(group, []).append(
                [int(token.split("/")[0]) - 1 for token in line.split()[1:]])

    def fit_face_point(index):
        sx, sy, sz = raw_vertices[index]
        return Vector((sx * 10.6, sy * 10.6 + 89.5,
                       -(sz - 1.0765) * 10.6))

    # Shane has fuller cheeks and a softly squared lower face than the neutral
    # base. These shallow, overlapping fields are the Blender equivalent of
    # the localized reference refit used on Roman: geometry moves, not just UVs.
    def sculpt_reference(p):
        x, y, z = p
        # Shane's sheet has a compact, broad adult face. Compress the source's
        # long lower-face proportion around the eye line before shaping details.
        y = 166.5 + (y - 166.5) * 0.93
        front = max(0.0, min(1.0, (-z - 0.1) / 2.5))
        jaw = math.exp(-((abs(x) - 5.5) / 2.4) ** 2 - ((y - 163.5) / 4.4) ** 2)
        cheek = math.exp(-((abs(x) - 4.2) / 2.1) ** 2 - ((y - 168.4) / 2.5) ** 2)
        bridge = math.exp(-(x / 1.65) ** 2 - ((y - 168.0) / 3.0) ** 2)
        tip = math.exp(-(x / 1.8) ** 2 - ((y - 165.7) / 1.25) ** 2)
        brow = math.exp(-((abs(x) - 3.1) / 1.7) ** 2 - ((y - 169.4) / 1.0) ** 2)
        chin = math.exp(-(x / 3.5) ** 2 - ((y - 160.4) / 1.7) ** 2)
        mouth = math.exp(-(x / 3.2) ** 2 - ((y - 162.8) / 1.0) ** 2)
        smile_corner = math.exp(-((abs(x) - 2.1) / .85) ** 2
                                - ((y - 162.7) / .75) ** 2)
        x += math.copysign(0.70 * jaw + 0.28 * cheek, x) if abs(x) > 1e-4 else 0.0
        y += 0.24 * smile_corner
        z -= front * (0.27 * cheek + 0.24 * brow + 0.40 * bridge
                      + 0.58 * tip + 0.20 * chin + 0.14 * mouth)
        return Vector((x, y, z))

    body_head_faces = []
    for face in groups.get("body", []):
        points = [fit_face_point(index) for index in face]
        if sum(point.y for point in points) / len(points) > 150.0:
            body_head_faces.append(face)
    head_faces = list(body_head_faces)
    # The base OBJ stores eyeball forms as separate licensed helper groups.
    # Include their geometry and give them a distinct off-white material.
    for eye_group in ("helper-l-eye", "helper-r-eye"):
        head_faces.extend(groups.get(eye_group, []))
    source_ids = sorted({index for face in head_faces for index in face})
    source_to_mesh = {source_id: i for i, source_id in enumerate(source_ids)}
    vertices = [sculpt_reference(fit_face_point(index)) for index in source_ids]
    faces = [[source_to_mesh[index] for index in face] for face in head_faces]
    mesh = bpy.data.meshes.new("Shane_MakeHuman_ReferenceSculpt")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    uv = mesh.uv_layers.new(name="JerseyUV")
    # Keep a stable head UV layout for export and future hand-authored skin
    # detail. It is deliberately not wired to Shane's portrait image.
    landmarks = [(158.8, 0.12), (160.4, 0.18), (162.8, 0.27),
                 (165.0, 0.36), (166.7, 0.47), (169.4, 0.55),
                 (173.5, 0.70), (178.5, 0.86)]
    def face_v(y):
        for (y0, v0), (y1, v1) in zip(landmarks, landmarks[1:]):
            if y <= y1:
                t = max(0.0, min(1.0, (y - y0) / (y1 - y0)))
                return v0 + (v1 - v0) * t
        return landmarks[-1][1]

    for poly in mesh.polygons:
        poly.use_smooth = True
        for li in poly.loop_indices:
            vertex = vertices[mesh.loops[li].vertex_index]
            x, y, z = vertex
            # Front axis is -Z. This is a continuous UV projection with a
            # wrapped rear seam; no photo projection is involved.
            angle = math.atan2(x, 4.6 - z)
            uv.data[li].uv = (0.5 + angle / math.tau, face_v(y))
    mesh.materials.append(FACE_SKIN or SKIN)
    mesh.materials.append(EYE_WHITE)
    mesh.materials.append(IRIS)
    mesh.materials.append(PUPIL)
    mesh.materials.append(WHITE)
    # The source's separate eye shells occupy the final polygon ranges.
    for poly in mesh.polygons:
        if poly.index >= len(body_head_faces):
            poly.material_index = 1
    # Actual iris, pupil, and catchlight geometry, included in this one head
    # mesh so they inherit the head bone and cannot drift during animation.
    bm = bmesh.new()
    bm.from_mesh(mesh)
    for eye_x in (-3.26, 3.26):
        for radius, y, z, depth, material_index in (
                (.55, 166.70, -3.39, .16, 2),
                (.245, 166.70, -3.525, .10, 3),
                (.075, 166.82, -3.615, .045, 4)):
            result = bmesh.ops.create_uvsphere(
                bm, u_segments=16, v_segments=10, radius=radius)
            eye_geo = result["verts"]
            eye_vertices = set(eye_geo)
            eye_faces = [face for face in bm.faces
                         if all(vertex in eye_vertices for vertex in face.verts)]
            bmesh.ops.scale(bm, verts=eye_geo,
                            vec=Vector((1.0, 1.0, depth / radius)))
            bmesh.ops.translate(bm, verts=eye_geo,
                                vec=Vector((eye_x, y, z)))
            for face in eye_faces:
                face.material_index = material_index
                face.smooth = True
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj = bpy.data.objects.new("Skin_Head", mesh)
    bpy.context.collection.objects.link(obj)
    obj["body_face_count"] = len(body_head_faces)
    return obj


def add_hair_dome():
    """Create a hair cap from Shane's actual scalp surface, not an ellipsoid."""
    head = bpy.data.objects.get("Skin_Head")
    if head is None:
        raise RuntimeError("Build Skin_Head before its fitted hair cap")
    source = head.data
    vertices = [vertex.co + vertex.normal.normalized() * 0.12
                for vertex in source.vertices]
    faces = []
    # Follow the skull with a short cropped hairline. It rises over the brow,
    # drops naturally at the temples, and wraps down the back. The prior dome
    # was a separate ellipsoid, which left a visible helmet edge and bald gaps.
    body_face_count = int(head.get("body_face_count", len(source.polygons)))
    for polygon in source.polygons:
        # Body head faces are first; the two eye helper groups follow them.
        if polygon.index >= body_face_count:
            continue
        points = [vertices[index] for index in polygon.vertices]
        center = sum(points, Vector()) / len(points)
        angle = abs(math.atan2(center.x, 4.6 - center.z))
        hairline_y = 173.5 - max(0.0, min(1.0, (angle - 0.75) / 0.9)) * 4.2
        hairline_y += 0.08 * math.sin(angle * 8.0)
        if center.y >= hairline_y:
            faces.append(tuple(polygon.vertices))
    mesh = bpy.data.meshes.new("Shane_HairCap_FittedToScalp")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    mesh.uv_layers.new(name="HairUV")
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    mesh.materials.append(HAIR)
    obj = bpy.data.objects.new("Hair_Cap_SkullFitted", mesh)
    bpy.context.collection.objects.link(obj)
    edge_use = {}
    for polygon in mesh.polygons:
        for edge in polygon.edge_keys:
            key = tuple(sorted(edge))
            edge_use[key] = edge_use.get(key, 0) + 1
    boundary_vertices = {index for edge, count in edge_use.items() if count == 1
                         for index in edge}
    if boundary_vertices:
        edge_group = obj.vertex_groups.new(name="HairlineBoundary")
        edge_group.add(sorted(boundary_vertices), 1.0, "REPLACE")
        soften = obj.modifiers.new("Soften_Hairline", "SMOOTH")
        soften.factor = 0.72
        soften.iterations = 8
        soften.vertex_group = edge_group.name
    smooth = obj.modifiers.new("Hairline_Subdivision", "SUBSURF")
    smooth.levels = 2
    smooth.render_levels = 2
    conform = obj.modifiers.new("Conform_To_Reference_Scalp", "SHRINKWRAP")
    conform.target = head
    conform.wrap_method = "NEAREST_SURFACEPOINT"
    conform.offset = 0.12
    return obj


def add_ellipsoid(name, center, scale, mat, segments=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.data.materials.append(mat)
    return obj


def add_limb(name, start, end, radius, mat, radius_y=None, vertices=20):
    a, b = Vector(start), Vector(end)
    delta = b - a
    center = (a + b) * 0.5
    bpy.ops.mesh.primitive_uv_sphere_add(segments=vertices, ring_count=max(12, vertices // 2), radius=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (radius, delta.length * .57, radius if radius_y is None else radius_y)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 1, 0)).rotation_difference(delta.normalized())
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.data.materials.append(mat)
    return obj


def add_tapered_neck():
    """Create a neck that broadens into the trapezius and overlaps the shirt."""
    # Shane's sheet shows a sturdy, short adult neck. Keep more volume at the
    # collar and transition more directly into the jaw instead of the thin,
    # elongated mannequin neck from the previous render.
    profile = [(146.0, 6.6, 5.8), (149.0, 5.9, 5.3), (153.0, 5.2, 4.9),
               (157.0, 4.9, 4.6), (161.0, 4.3, 4.1), (164.0, 3.7, 3.6),
               (166.0, 3.1, 3.1)]
    segments = 32
    vertices, faces = [], []
    for y, radius_x, radius_z in profile:
        for index in range(segments):
            angle = math.tau * index / segments
            vertices.append((radius_x * math.sin(angle), y,
                             -0.2 + radius_z * math.cos(angle)))
    for ring in range(len(profile) - 1):
        for index in range(segments):
            a = ring * segments + index
            b = ring * segments + (index + 1) % segments
            c = (ring + 1) * segments + (index + 1) % segments
            d = (ring + 1) * segments + index
            faces.append((a, b, c, d))
    # Close both ends: the continuous-body voxel union deliberately ignores
    # open sheets, which otherwise left the neck out and caused a visible gap.
    bottom_center = len(vertices)
    vertices.append((0.0, profile[0][0], -0.2))
    top_center = len(vertices)
    vertices.append((0.0, profile[-1][0], -0.2))
    for index in range(segments):
        nxt = (index + 1) % segments
        faces.append((bottom_center, nxt, index))
        a = (len(profile) - 1) * segments + index
        b = (len(profile) - 1) * segments + nxt
        faces.append((top_center, a, b))
    mesh = bpy.data.meshes.new("Shane_NeckTrapeziusTransition")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(SKIN)
    obj = bpy.data.objects.new("Skin_Neck", mesh)
    bpy.context.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def add_tailored_shorts():
    """Voxel-union the waistband and two legs into one deforming garment."""
    pieces = [
        add_ellipsoid("ShortsWaistPiece", (0, 94.0, 0), (17.5, 9.0, 11.4), SHORTS, 40, 24),
        add_ellipsoid("ShortsLeftLegPiece", (9.4, 79.7, 0.0), (9.7, 13.5, 11.6), SHORTS, 40, 24),
        add_ellipsoid("ShortsRightLegPiece", (-9.4, 79.7, 0.0), (9.7, 13.5, 11.6), SHORTS, 40, 24),
    ]
    bpy.ops.object.select_all(action="DESELECT")
    for piece in pieces:
        piece.select_set(True)
        piece.parent = None
        bpy.context.view_layer.objects.active = piece
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.join()
    shorts = bpy.context.object
    shorts.name = "Kit_Shorts"
    shorts.data.name = "Shane_JoinedShorts"
    remesh = shorts.modifiers.new("REMESH_ShortsSeams", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.85
    remesh.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = shorts.modifiers.new("SMOOTH_ShortsTailoring", "SMOOTH")
    smooth.factor = 0.55
    smooth.iterations = 2
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    for polygon in shorts.data.polygons:
        polygon.use_smooth = True
    return shorts


def add_sleeve_tube(prefix, side, y=143.0, z=-6.1):
    """One continuous, tapered long sleeve surface from shoulder to wrist."""
    # The reference is a full-length fitted sleeve. Extend it to the actual
    # wrist rather than ending at the forearm, which exposed a pale skin band.
    rings = [(12.0, 7.0, 6.1), (16.0, 6.8, 6.0), (20.0, 6.6, 5.8), (29.0, 5.7, 5.2),
             (38.0, 5.1, 4.8), (47.0, 4.75, 4.45), (56.0, 4.35, 4.1),
             (65.0, 3.95, 3.75), (74.0, 3.55, 3.4), (81.0, 3.2, 3.1),
             (85.0, 3.0, 2.9)]
    segments = 32
    vertices, faces = [], []
    for distance, radius_y, radius_z in rings:
        for index in range(segments):
            angle = math.tau * index / segments
            vertices.append((side * distance, y + radius_y * math.cos(angle),
                             z + radius_z * math.sin(angle)))
    for ring in range(len(rings) - 1):
        for index in range(segments):
            a = ring * segments + index
            b = ring * segments + (index + 1) % segments
            c = (ring + 1) * segments + (index + 1) % segments
            d = (ring + 1) * segments + index
            faces.append((a, b, c, d) if side > 0 else (d, c, b, a))
    for end_ring, reverse in ((0, True), (len(rings) - 1, False)):
        center_index = len(vertices)
        vertices.append((side * rings[end_ring][0], y, z))
        for index in range(segments):
            a = end_ring * segments + index
            b = end_ring * segments + (index + 1) % segments
            faces.append((center_index, b, a) if reverse else (center_index, a, b))
    mesh = bpy.data.meshes.new(prefix + "_ContinuousSleeve")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(BLUE)
    mesh.materials.append(BLACK)
    obj = bpy.data.objects.new(prefix + "SleeveTube", mesh)
    bpy.context.collection.objects.link(obj)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
        # The reference has a black inner/underarm panel. Keep it narrow and
        # continuous instead of layering separate black capsule overlays.
        angle = (polygon.index % segments) * math.tau / segments
        if math.cos(angle) < -0.82:
            polygon.material_index = 1
    return obj


def add_uv_torso(name, center, scale, base, stripe, stripe_count=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, radius=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.data.materials.append(base)
    obj.data.materials.append(stripe)
    uv_layer = obj.data.uv_layers.active
    for polygon in obj.data.polygons:
        us = [uv_layer.data[loop_index].uv.x for loop_index in polygon.loop_indices]
        u = sum(us) / len(us)
        band = int(u * stripe_count)
        # Four royal-blue shirt panels alternating with dark body panels.
        polygon.material_index = 1 if band % 2 == 0 else 0
    return obj


def add_jersey_shell(name="YBot_Surface"):
    """Tailored jersey shell with rounded shoulder slope and collar opening."""
    # Shane's sheet reads as a sturdy, average-build adult: a fuller abdomen,
    # defined chest, broad but sloping shoulders, and a clean collar taper.
    # Closely spaced profile rings let subdivision round the silhouette without
    # the pinched, capsule-like waist of the previous proxy.
    profile = [(88, 18.0, 13.0), (92, 18.8, 13.5), (98, 19.8, 14.0),
               (106, 20.8, 14.5), (114, 21.5, 15.0), (122, 21.9, 15.3),
               (130, 20.6, 15.0), (137, 21.0, 14.5), (143, 25.0, 13.8),
               (147, 24.0, 12.4), (150, 16.2, 9.0), (153, 6.2, 5.2)]
    segments = 64
    vertices = []
    faces = []
    for y, width, depth in profile:
        for i in range(segments):
            angle = math.tau * i / segments
            vertices.append((width * math.sin(angle), y, depth * math.cos(angle)))
    for ring in range(len(profile) - 1):
        for i in range(segments):
            a = ring * segments + i
            b = ring * segments + (i + 1) % segments
            c = (ring + 1) * segments + (i + 1) % segments
            d = (ring + 1) * segments + i
            faces.append((a, b, c, d))
    mesh = bpy.data.meshes.new("Shane_JerseyTailoredPanels")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(JERSEY)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    uv_layer = mesh.uv_layers.new(name="JerseyUV")
    for poly in mesh.polygons:
        poly.use_smooth = True
        ring_index = poly.index // segments
        segment_index = poly.index % segments
        u0 = segment_index / segments
        u1 = (segment_index + 1) / segments
        v0 = ring_index / (len(profile) - 1)
        v1 = (ring_index + 1) / (len(profile) - 1)
        uvs = ((u0, v0), (u1, v0), (u1, v1), (u0, v1))
        for loop_index, uv in zip(poly.loop_indices, uvs):
            uv_layer.data[loop_index].uv = uv
        poly.material_index = 0
    smooth = obj.modifiers.new("SUBD_TailoredJerseySurface", "SUBSURF")
    smooth.levels = 2
    smooth.render_levels = 2
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    return obj


def assign_weights(obj, armature, influences):
    """Assign a smoothly blended two-bone skin by vertical ranges.

    influences maps the mesh's local-Y thresholds to target bone names. This
    keeps the generated torso pieces compact while preserving the established
    skeleton and animation data.
    """
    obj.parent = armature
    groups = {name: obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
              for name in set(influences)}
    ys = [point.co.y for point in obj.data.vertices]
    low, high = min(ys), max(ys)
    span = max(high - low, 1.0)
    for vertex in obj.data.vertices:
        t = (vertex.co.y - low) / span
        pos = t * (len(influences) - 1)
        lower = min(int(pos), len(influences) - 1)
        upper = min(lower + 1, len(influences) - 1)
        blend = pos - lower
        groups[influences[lower]].add([vertex.index], 1.0 - blend, "REPLACE")
        if upper != lower and blend > .0001:
            groups[influences[upper]].add([vertex.index], blend, "REPLACE")
    mod = obj.modifiers.new("ARM_GameRig", "ARMATURE")
    mod.object = armature
    mod.use_deform_preserve_volume = True
    return obj


def rigid_weights(obj, armature, bone_name):
    obj.parent = armature
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    mod = obj.modifiers.new("ARM_GameRig", "ARMATURE")
    mod.object = armature
    return obj


def bone_segment_distance(point, head, tail):
    segment = tail - head
    denom = max(segment.length_squared, 1e-8)
    t = max(0.0, min(1.0, (point - head).dot(segment) / denom))
    return (point - (head + segment * t)).length


def assign_nearest_bone_weights(obj, armature):
    """Bind the unified body smoothly to the existing deform skeleton."""
    obj.parent = armature
    deform_names = [
        "Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
        "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
        "RightShoulder", "RightArm", "RightForeArm", "RightHand",
        "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
        "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase",
    ]
    bones = []
    for suffix in deform_names:
        bone = armature.data.bones.get("mixamorig:" + suffix)
        if bone:
            bones.append(("mixamorig:" + suffix, bone.head_local.copy(), bone.tail_local.copy()))
    groups = {name: obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name) for name, _, _ in bones}
    for vertex in obj.data.vertices:
        point = vertex.co
        nearest = sorted((bone_segment_distance(point, head, tail), name)
                         for name, head, tail in bones)[:2]
        first_distance, first_name = nearest[0]
        second_distance, second_name = nearest[1]
        # Keep joint transitions soft, but don't let distant bones pollute the
        # head, hand, foot, or torso. Four-centimetre transition zone.
        blend_width = 4.0
        if second_distance - first_distance >= blend_width:
            groups[first_name].add([vertex.index], 1.0, "REPLACE")
        else:
            second_weight = max(.0, min(.48, .5 * (1.0 - (second_distance - first_distance) / blend_width)))
            groups[first_name].add([vertex.index], 1.0 - second_weight, "REPLACE")
            groups[second_name].add([vertex.index], second_weight, "REPLACE")
    mod = obj.modifiers.new("ARM_GameRig", "ARMATURE")
    mod.object = armature
    mod.use_deform_preserve_volume = True


def prune_vertex_weights(obj, limit=4):
    """Normalize skinned weights and keep the strongest four per vertex."""
    groups = {group.index: group for group in obj.vertex_groups}
    for vertex in obj.data.vertices:
        # Snapshot values before deleting memberships: Blender's live RNA
        # wrappers can point to a different slot after a removal.
        assignments = sorted(((item.group, float(item.weight)) for item in vertex.groups),
                             key=lambda item: item[1], reverse=True)
        for group_id, _value in assignments[limit:]:
            group = groups.get(group_id)
            if group is not None:
                group.remove([vertex.index])
        kept = assignments[:limit]
        total = sum(value for _, value in kept)
        if total <= 1e-8:
            continue
        for group_id, value in kept:
            group = groups.get(group_id)
            if group is not None:
                group.add([vertex.index], value / total, "REPLACE")


def cache_source_weights(meshes):
    weighted_vertices = []
    for mesh_obj in meshes:
        group_names = {group.index: group.name for group in mesh_obj.vertex_groups}
        for vertex in mesh_obj.data.vertices:
            weights = {}
            for assignment in vertex.groups:
                group_name = group_names.get(assignment.group)
                if group_name:
                    weights[group_name] = assignment.weight
            weighted_vertices.append((vertex.co.copy(), weights))
    tree = KDTree(len(weighted_vertices))
    for index, (co, _weights) in enumerate(weighted_vertices):
        tree.insert(co, index)
    tree.balance()
    return tree, weighted_vertices


def assign_transferred_weights(obj, armature, donor_cache):
    """Transfer validated Y-Bot weights onto the new continuous body surface."""
    tree, donor_vertices = donor_cache
    obj.parent = armature
    group_cache = {}
    for vertex in obj.data.vertices:
        samples = tree.find_n(vertex.co, 4)
        accum = {}
        total = 0.0
        for _co, donor_index, distance in samples:
            sample_weight = 1.0 / max(distance * distance, 0.02)
            total += sample_weight
            for group_name, value in donor_vertices[donor_index][1].items():
                accum[group_name] = accum.get(group_name, 0.0) + value * sample_weight
        if total <= 0.0:
            continue
        normalized = sorted(((name, value / total) for name, value in accum.items()
                            if value / total > .015), key=lambda item: item[1], reverse=True)[:4]
        weight_sum = sum(value for _name, value in normalized)
        if weight_sum <= 1e-6:
            continue
        for group_name, value in normalized:
            group = group_cache.get(group_name)
            if group is None:
                group = obj.vertex_groups.get(group_name) or obj.vertex_groups.new(name=group_name)
                group_cache[group_name] = group
            group.add([vertex.index], value / weight_sum, "REPLACE")
    mod = obj.modifiers.new("ARM_GameRig", "ARMATURE")
    mod.object = armature
    mod.use_deform_preserve_volume = True


def assign_sleeve_weights(obj, armature, side):
    """Weight the continuous sleeve across shoulder, upper arm and elbow."""
    side_name = "Left" if side > 0 else "Right"
    shoulder = obj.vertex_groups.new(name="mixamorig:" + side_name + "Shoulder")
    upper = obj.vertex_groups.new(name="mixamorig:" + side_name + "Arm")
    fore = obj.vertex_groups.new(name="mixamorig:" + side_name + "ForeArm")
    for vertex in obj.data.vertices:
        distance = abs(vertex.co.x)
        if distance < 23.0:
            forearm = 0.0
            upper_weight = max(0.0, min(1.0, (distance - 18.0) / 5.0))
            shoulder_weight = 1.0 - upper_weight
        elif distance < 43.0:
            shoulder_weight, upper_weight, forearm = 0.0, 1.0, 0.0
        elif distance < 49.0:
            forearm = (distance - 43.0) / 6.0
            shoulder_weight, upper_weight = 0.0, 1.0 - forearm
        else:
            shoulder_weight, upper_weight, forearm = 0.0, 0.0, 1.0
        if shoulder_weight > 0.001:
            shoulder.add([vertex.index], shoulder_weight, "REPLACE")
        if upper_weight > 0.001:
            upper.add([vertex.index], upper_weight, "REPLACE")
        if forearm > 0.001:
            fore.add([vertex.index], forearm, "REPLACE")
    obj.parent = armature
    modifier = obj.modifiers.new("ARM_GameRig", "ARMATURE")
    modifier.object = armature
    modifier.use_deform_preserve_volume = True


def make_makehuman_body(armature):
    """Load the CC0 MakeHuman anatomical surface and fit it to the Y-Bot rig.

    Only the documented `body` OBJ group is used; helper tights, skirt, eyes,
    genital and joint proxies are excluded. The geometry is authored in the
    Mixamo armature's centimetre-space, then receives joint-aware weights.
    """
    if not MAKEHUMAN_BASE.exists():
        raise FileNotFoundError(MAKEHUMAN_BASE)
    raw_vertices, raw_uvs, source_faces = [], [], []
    group = ""
    for line in MAKEHUMAN_BASE.read_text().splitlines():
        if line.startswith("v "):
            raw_vertices.append(tuple(float(value) for value in line.split()[1:4]))
        elif line.startswith("vt "):
            raw_uvs.append(tuple(float(value) for value in line.split()[1:3]))
        elif line.startswith("g "):
            group = line.split(maxsplit=1)[1]
        elif line.startswith("f ") and group == "body":
            corners = []
            for token in line.split()[1:]:
                indices = token.split("/")
                corners.append((int(indices[0]) - 1,
                                int(indices[1]) - 1 if len(indices) > 1 and indices[1] else 0))
            source_faces.append(corners)

    def fit_point(source_index):
        sx, sy, sz = raw_vertices[source_index]
        x = sx * 10.6
        y = sy * 10.6 + 89.5
        z = -(sz - 1.0765) * 10.6  # Match Y-Bot's -Z-facing front.
        # Shane's sheet shows a slightly stockier adult build than the neutral
        # MakeHuman base. Broaden pelvis/thigh and chest mass without changing
        # limb length or head scale.
        if abs(x) < 16.0 and 48.0 < y < 149.0:
            x *= 1.12
        # MakeHuman's relaxed A-pose arms are extended to the existing rig's
        # horizontal rest pose and length, so the supplied Mixamo clips start
        # without a shoulder pop.
        is_upper_arm = y > 110.0 and abs(x) > 20.0
        is_hand_or_lower_arm = y > 80.0 and abs(x) > 30.0
        if y < 153.0 and (is_upper_arm or is_hand_or_lower_arm):
            side = 1.0 if x > 0 else -1.0
            shoulder_x = side * 16.0
            radial_x = side * (16.0 + (abs(x) - 16.0) * 1.8)
            dx, dy = radial_x - shoulder_x, y - 147.0
            theta = side * 0.42
            x = shoulder_x + dx * math.cos(theta) - dy * math.sin(theta)
            y = 147.0 + dx * math.sin(theta) + dy * math.cos(theta)
        elif y < 80.0 and abs(x) > 2.0:
            side = 1.0 if x > 0 else -1.0
            source_center = (23.6 if y < 20.0 else
                             23.6 + (20.2 - 23.6) * ((y - 20.0) / 20.0) if y < 40.0 else
                             20.2 + (17.0 - 20.2) * ((y - 40.0) / 20.0) if y < 60.0 else
                             17.0 + (9.4 - 17.0) * ((y - 60.0) / 20.0))
            x = side * max(0.8, 9.5 + (abs(x) - source_center) * 0.84)
        return (x, y, z)

    used = sorted({vertex for face in source_faces for vertex, _uv in face})
    remap = {old: new for new, old in enumerate(used)}
    vertices = [fit_point(index) for index in used]
    retained_faces = []
    retained_uvs = []
    for corners in source_faces:
        face_vertices = [fit_point(vertex) for vertex, _uv in corners]
        center_y = sum(point[1] for point in face_vertices) / len(face_vertices)
        if center_y > 150.0:
            continue  # Custom Shane face/head mesh replaces the generic head.
        retained_faces.append([remap[vertex] for vertex, _uv in corners])
        retained_uvs.append([uv_index for _vertex, uv_index in corners])

    mesh = bpy.data.meshes.new("Shane_MakeHuman_CC0_Body")
    mesh.from_pydata(vertices, [], retained_faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="MakeHumanBodyUV")
    for polygon, face_uvs in zip(mesh.polygons, retained_uvs):
        for loop_index, uv_index in zip(polygon.loop_indices, face_uvs):
            if uv_index < len(raw_uvs):
                uv_layer.data[loop_index].uv = raw_uvs[uv_index]
        polygon.use_smooth = True
    mesh.materials.append(SKIN)
    mesh.materials.append(SHORTS)
    for polygon in mesh.polygons:
        center = polygon.center
        if 69.0 <= center.y <= 105.0 and abs(center.x) <= 25.0:
            polygon.material_index = 1
    body = bpy.data.objects.new("YBot_Joints", mesh)
    bpy.context.collection.objects.link(body)
    # The fitted vertices are in centimetre space. Keep the proven armature
    # auto-bind path here because direct nearest-bone assignment made shoulders
    # and hips collapse in the idle test. Body/sleeve alignment is handled
    # separately by transferring the actual resulting surface weights below.
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    body.rotation_euler.x = math.pi * .5
    body.scale = (.01, .01, .01)
    body.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    if not body.vertex_groups:
        raise RuntimeError("Automatic rig binding produced no vertex groups")
    prune_vertex_weights(body, 4)
    return body


def make_fitted_jersey_from_body(body, armature):
    """Create a close skinned shirt shell from the final body's own surface.

    Reusing the body surface gives the torso and sleeves a matched bind shape
    and identical source weights. The 4.5 mm local-space offset prevents
    z-fighting; this is a static skinned garment, not cloth simulation.
    """
    source_mesh = body.data
    source_mesh.update()

    def torso_limit(y):
        if y < 94.0:
            return 21.0
        if y < 122.0:
            return 22.5
        if y < 138.0:
            return 23.0
        if y < 145.0:
            return 29.0
        if y < 149.0:
            return 27.0
        if y < 152.0:
            return 15.5
        # Keep the neckline covered across the upper chest. The earlier
        # 7 cm cap left isolated skin-coloured gaps at the shoulder join.
        return 12.0

    def torso_center_z(y):
        samples = [(88, 10.0), (96, 9.5), (106, 7.0), (114, 5.4),
                   (122, 4.0), (130, 4.8), (137, 6.7), (147, 8.0)]
        for (y0, z0), (y1, z1) in zip(samples, samples[1:]):
            if y <= y1:
                t = max(0.0, min(1.0, (y - y0) / (y1 - y0)))
                return z0 + (z1 - z0) * t
        return samples[-1][1]

    def expected_outward(point, sleeve):
        if sleeve:
            # Approximate the resting upper/forearm centerline in the fitted
            # body. The garment's radial direction is perpendicular to this
            # line, avoiding the source OBJ's inconsistent normals at seams.
            arm_axis = [(14.0, 143.0, 7.0), (25.0, 146.0, 10.0),
                        (35.0, 144.0, 10.0), (50.0, 141.0, 8.5),
                        (65.0, 140.5, 1.5), (78.0, 138.3, -9.8),
                        (83.0, 137.2, -14.0)]
            distance = abs(point.x)
            y_axis, z_axis = arm_axis[-1][1], arm_axis[-1][2]
            for (x0, y0, z0), (x1, y1, z1) in zip(arm_axis, arm_axis[1:]):
                if distance <= x1:
                    t = max(0.0, min(1.0, (distance - x0) / max(x1 - x0, 1e-4)))
                    y_axis, z_axis = y0 + (y1-y0)*t, z0 + (z1-z0)*t
                    break
            return Vector((0.0, point.y - y_axis, point.z - z_axis)).normalized()
        return Vector((point.x, 0.0, point.z - torso_center_z(point.y))).normalized()

    selected = []
    for polygon in source_mesh.polygons:
        y = polygon.center.y
        x = abs(polygon.center.x)
        torso = 87.0 <= y <= 154.0 and x <= torso_limit(y)
        # Give the torso/shoulder seam a small topology overlap in the shared
        # source surface. Classification is per-face, so this does not create
        # duplicate polygons; it closes the exposed wedges at the armhole.
        sleeve = 126.0 <= y <= 160.0 and 10.0 <= x <= 86.0
        if torso or sleeve:
            selected.append((polygon, sleeve, sleeve and x >= 79.5))
    if not selected:
        raise RuntimeError("No body faces selected for fitted jersey")

    source_indices = sorted({index for polygon, _sleeve, _cuff in selected for index in polygon.vertices})
    remap = {source_index: new_index for new_index, source_index in enumerate(source_indices)}
    sleeve_vertices = {
        index for polygon, is_sleeve, _cuff in selected if is_sleeve
        for index in polygon.vertices
    }
    vertices = []
    for source_index in source_indices:
        source_vertex = source_mesh.vertices[source_index]
        sleeve = source_index in sleeve_vertices
        outward = expected_outward(source_vertex.co, sleeve)
        normal = source_vertex.normal.normalized()
        if normal.dot(outward) < 0.0:
            normal.negate()
        vertices.append(source_vertex.co + normal * 0.55)

    faces = []
    for polygon, is_sleeve, _cuff in selected:
        face_indices = list(polygon.vertices)
        radial = sum((expected_outward(source_mesh.vertices[index].co, is_sleeve)
                      for index in face_indices), Vector()).normalized()
        if polygon.normal.dot(radial) < 0.0:
            face_indices.reverse()
        faces.append([remap[index] for index in face_indices])
    mesh = bpy.data.meshes.new("Shane_FittedJerseyPanels")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(JERSEY)
    mesh.materials.append(BLACK)
    uv = mesh.uv_layers.new(name="JerseyUV")

    def torso_half_width(y):
        samples = [(88, 20.0), (96, 18.0), (106, 17.5), (114, 15.5),
                   (122, 14.5), (130, 16.0), (137, 20.0), (147, 22.0)]
        for (y0, w0), (y1, w1) in zip(samples, samples[1:]):
            if y <= y1:
                t = max(0.0, min(1.0, (y - y0) / (y1 - y0)))
                return max(1.0, w0 + (w1 - w0) * t)
        return samples[-1][1]

    for new_polygon, (source_polygon, is_sleeve, cuff) in zip(mesh.polygons, selected):
        new_polygon.use_smooth = True
        new_polygon.material_index = 1 if cuff else 0
        corner_uvs = []
        face_indices = list(source_polygon.vertices)
        radial = sum((expected_outward(source_mesh.vertices[index].co, is_sleeve)
                      for index in face_indices), Vector()).normalized()
        if source_polygon.normal.dot(radial) < 0.0:
            face_indices.reverse()
        for source_index in face_indices:
            co = source_mesh.vertices[source_index].co
            if is_sleeve:
                # The reference has blue sleeves; map to a clean blue atlas
                # strip and keep the wrist cuff as its own black region.
                u = 0.12
            else:
                width = torso_half_width(co.y)
                side = max(-1.0, min(1.0, co.x / width))
                if co.z < torso_center_z(co.y):
                    # Front: linear panel mapping keeps stripes and chest marks
                    # stable instead of pinching them over the rounded chest.
                    u = 0.5 - 0.25 * side
                elif co.x >= 0.0:
                    u = 0.25 * (1.0 - side)
                else:
                    u = 1.0 - 0.25 * (1.0 - abs(side))
            # Place sponsor/crest higher on the chest as on the supplied kit
            # board. The low/high trim still samples within the shirt atlas.
            v = max(0.0, min(0.82, (co.y - 94.0) / 76.0))
            corner_uvs.append((u, v))
        # Put a face crossing the rear center seam on one continuous side of
        # the atlas. The seam is on the back, away from front chest graphics.
        if max(value[0] for value in corner_uvs) - min(value[0] for value in corner_uvs) > 0.5:
            corner_uvs = [(u + 1.0 if u < 0.5 else u, v) for u, v in corner_uvs]
        for loop_index, value in zip(new_polygon.loop_indices, corner_uvs):
            uv.data[loop_index].uv = value
    mesh.update()

    # Copy the exact body-space object transform and armature modifier, then
    # transfer the source vertex-group memberships to the extracted faces.
    garment = body.copy()
    garment.data = mesh
    garment.name = "YBot_Surface"
    garment.data.name = "Shane_FittedJerseyPanels"
    # The source body has a compensating parent inverse for its centimetre to
    # metre transform. The other kit meshes are authored directly in the
    # armature's local centimetre space, so clear that compensation here before
    # joining them; otherwise the copied shirt is scaled to 1/100 in the scene.
    garment.parent = armature
    garment.matrix_parent_inverse = Matrix.Identity(4)
    garment.location = (0.0, 0.0, 0.0)
    garment.rotation_euler = (0.0, 0.0, 0.0)
    garment.scale = (1.0, 1.0, 1.0)
    bpy.context.collection.objects.link(garment)
    for group in list(garment.vertex_groups):
        garment.vertex_groups.remove(group)
    source_groups = {group.index: group.name for group in body.vertex_groups}
    target_groups = {name: garment.vertex_groups.new(name=name) for name in source_groups.values()}
    for new_index, source_index in enumerate(source_indices):
        for assignment in source_mesh.vertices[source_index].groups:
            name = source_groups.get(assignment.group)
            if name and assignment.weight > 0.0:
                target_groups[name].add([new_index], assignment.weight, "REPLACE")

    print("SHANE_FITTED_JERSEY", "faces", len(selected), "vertices", len(source_indices),
          "torso+sleeves from shared body surface")
    return garment


def make_continuous_skin(parts, armature, donor_cache):
    skin_prefixes = ("Skin_", "RightArmSkin_", "LeftArmSkin_", "RightThigh", "LeftThigh",
                     "RightKnee", "LeftKnee",
                     "RightCalf", "LeftCalf", "RightHand", "LeftHand")
    # Retain the head as a separate UV surface for its own unwrap and material;
    # remeshing it into the body would destroy the head UVs.
    skin_parts = [obj for obj in parts if obj.name.startswith(skin_prefixes)
                  and obj.name != "Skin_Head"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in skin_parts:
        obj.parent = None
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.view_layer.objects.active = skin_parts[0]
    bpy.ops.object.join()
    skin = bpy.context.object
    skin.name = "YBot_Joints"
    skin.data.name = "Shane_ContinuousHumanBody"
    # Voxel union turns the blockout volumes into a single continuous, rounded
    # surface, removing the disconnected capsule seams seen in the first render.
    remesh = skin.modifiers.new("REMESH_ContinuousBody", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 1.05
    remesh.use_smooth_shade = True
    bpy.context.view_layer.objects.active = skin
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = skin.modifiers.new("SMOOTH_OrganicPlanes", "SMOOTH")
    smooth.factor = 1.15
    smooth.iterations = 4
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    # Give the shorts a material region on this same continuous, weighted
    # surface. A separately skinned shorts shell tore away from the thighs in
    # the imported idle action; sharing the body topology and weights removes
    # that seam while retaining a clear kit color block.
    if SHORTS.name not in [mat.name for mat in skin.data.materials]:
        skin.data.materials.append(SHORTS)
    shorts_slot = next(index for index, mat in enumerate(skin.data.materials) if mat == SHORTS)
    for polygon in skin.data.polygons:
        center = polygon.center
        if 69.0 <= center.y <= 105.0 and abs(center.x) <= 25.0:
            polygon.material_index = shorts_slot
    for polygon in skin.data.polygons:
        polygon.use_smooth = True
    # The proxy donor's voxelized weights were producing hip and elbow spikes
    # on the remodeled silhouette. Rebind the continuous body against the
    # actual Mixamo bone segments in the same centimetre-space as the mesh.
    assign_nearest_bone_weights(skin, armature)
    return skin


def merge_kit_and_details(armature):
    """Collapse small kit/face components to one skinned draw object."""
    body = bpy.data.objects.get("YBot_Joints")
    # Keep the uniquely UV-mapped face mesh separate. Blender's join operation
    # can reorder active UV layers when mixing generated clothes and head UVs;
    # one extra small skinned draw is a safer, still cheap tradeoff at 22v22.
    mesh_parts = [obj for obj in bpy.context.scene.objects
                  if obj.type == "MESH" and obj not in {body}
                  and obj.name != "Skin_Head"]
    if not mesh_parts:
        raise RuntimeError("The kit and character detail meshes were not authored")
    jersey = bpy.data.objects.get("YBot_Surface")
    if jersey not in mesh_parts or not mesh_parts:
        raise RuntimeError("The jersey/details meshes were not authored")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in mesh_parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = jersey
    bpy.ops.object.join()
    jersey.name = "YBot_Surface"
    jersey.data.name = "Shane_KitFaceHairCombined"
    jersey.parent = armature
    return jersey


def add_jersey_labels(armature):
    # Sponsor, Uhlsport logo, club crest and back #8 live in the single UV atlas.
    return


def main():
    import sys
    modular = "--modular" in sys.argv
    blend_out = BLEND_OUT if not modular else ROOT / "tools/blender/beechlawn/footballer_shared.blend"
    glb_out = GLB_OUT if not modular else ROOT / "games/beechlawn_rovers/assets/characters/shared/footballer_base.glb"
    if not SOURCE.exists():
        raise FileNotFoundError(SOURCE)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    create_materials()
    armature = bpy.data.objects["YBot_Armature"]
    for obj in list(bpy.context.scene.objects):
        if obj.type == "MESH" and obj.name in {"YBot_Surface", "YBot_Joints"}:
            bpy.data.objects.remove(obj, do_unlink=True)

    # Joint-aware offline fit replaces the rejected threshold-stretched body
    # and the independently placed sleeve/sock/boot primitives. The target
    # skeleton and all existing football actions remain unchanged.
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from shane_anatomical_foundation import build_foundation
    armature.animation_data_create()
    armature.animation_data.action = None
    for bone in armature.pose.bones:
        bone.location = (0.0, 0.0, 0.0)
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        bone.scale = (1.0, 1.0, 1.0)
    fitter, parts = build_foundation(armature, MAKEHUMAN_BASE, {
        "skin": SKIN, "jersey": JERSEY, "shorts": SHORTS,
        "blue": BLUE, "boots": BOOT, "hair": HAIR, "eye": EYE_WHITE,
        "iris": IRIS, "pupil": PUPIL,
    })
    from shane_player_finish import finish_head
    finish_head(fitter, {"skin": SKIN, "hair": HAIR, "iris": IRIS})
    from shane_tailored_kit import build_tailored_kit
    build_tailored_kit(fitter, JERSEY, modular=modular)
    # Cutting covered body faces changes the open boundary's averaged normals.
    # Reconcile again after that edit so the exported head/neck shading agrees.
    from shane_player_finish import reconcile_skin_normals
    reconcile_skin_normals(bpy.data.objects["Skin_Head"], bpy.data.objects["YBot_Joints"], fitter)
    if not modular:
        merge_kit_and_details(armature)
    from shane_leg_retarget import correct_leg_roll
    correct_leg_roll(armature)
    if modular:
        from shared_role_actions import author_role_actions
        author_role_actions(armature)
    # Retain the animation library's authored FPS (currently 60). Forcing 30
    # doubled clip durations relative to their football-contact metadata.
    bpy.context.scene.frame_set(1)
    blend_out.parent.mkdir(parents=True, exist_ok=True)
    glb_out.parent.mkdir(parents=True, exist_ok=True)
    if modular:
        # Shared animation is embedded once in this resource, then reused by
        # actor instances. Mesh parts remain named and independently replaceable.
        from shane_head_variants import write_base_fingerprint
        write_base_fingerprint(bpy.data.objects["Skin_Head"])
        body=bpy.data.objects["YBot_Joints"]
        hands=body.copy();hands.data=body.data.copy();hands.name="Skin_Hands"
        bpy.context.collection.objects.link(hands)
        for obj,keep_hands in ((body,False),(hands,True)):
            bm=bmesh.new();bm.from_mesh(obj.data)
            remove=[f for f in bm.faces if (abs(f.calc_center_median().x)>72.0)!=keep_hands]
            bmesh.ops.delete(bm,geom=remove,context="FACES")
            bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context="VERTS")
            bm.to_mesh(obj.data);bm.free();obj.data.update()
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_out))

    bpy.ops.object.select_all(action="DESELECT")
    export_objects = [armature] + [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    for obj in export_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=str(glb_out), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=True, export_cameras=False,
        export_lights=False, export_animations=True,
        export_animation_mode="ACTIONS", export_skins=True,
        export_influence_nb=4, export_leaf_bone=False,
        export_rest_position_armature=True,
    )
    print("SHANE_DENHAM_EXPORT", glb_out, "actions", len(bpy.data.actions), "meshes", len(export_objects)-1)


if __name__ == "__main__":
    main()
