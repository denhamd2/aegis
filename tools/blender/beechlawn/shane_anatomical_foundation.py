"""Offline, joint-landmark fitting of the licensed MakeHuman mesh to Y-Bot.

All calculations use the existing armature's local centimetres, +Y up and
+Z forward. Nothing here runs during gameplay or changes the production rig.
"""
from pathlib import Path
import math
import bpy
import bmesh
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
from collections import Counter


def read_source(path):
    vertices, uvs, groups = [], [], {}
    group = ""
    for line in Path(path).read_text().splitlines():
        if line.startswith("v "):
            x, y, z = map(float, line.split()[1:4])
            vertices.append(Vector((x * 10.6, y * 10.6 + 89.5, z * 10.6)))
        elif line.startswith("vt "):
            uvs.append(tuple(map(float, line.split()[1:3])))
        elif line.startswith("g "):
            group = line.split(maxsplit=1)[1]
            groups.setdefault(group, [])
        elif line.startswith("f "):
            corners = []
            for token in line.split()[1:]:
                fields = token.split("/")
                corners.append((int(fields[0]) - 1,
                                int(fields[1]) - 1 if len(fields) > 1 and fields[1] else 0))
            groups.setdefault(group, []).append(corners)
    # The OBJ is a neutral macro base. Apply MakeHuman's equal adult-male
    # macro blend before locating its joints; all files are archived CC0 data.
    directory = Path(path).parent / "morphs"
    for prefix in ("african", "asian", "caucasian"):
        target = directory / (prefix + "-male-young.target")
        for line in target.read_text().splitlines():
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            index, dx, dy, dz = line.split()
            vertices[int(index)] += Vector((float(dx), float(dy), float(dz))) * (10.6 / 3.0)
    # Small, individually recorded CC0 feature edits; no portrait projection.
    import json
    feature_dir = directory / "shane"
    if (feature_dir / "provenance.json").exists():
        for entry in json.loads((feature_dir / "provenance.json").read_text())["targets"]:
            for line in (feature_dir / entry["file"]).read_text().splitlines():
                if not line.strip() or line.lstrip().startswith("#"):
                    continue
                index, dx, dy, dz = line.split()
                vertices[int(index)] += Vector((float(dx), float(dy), float(dz))) * (10.6 * entry["weight"])
    return vertices, uvs, groups


def joint_centres(vertices, groups):
    result = {}
    for name, faces in groups.items():
        if name.startswith("joint-"):
            ids = {v for face in faces for v, _ in face}
            result[name[6:]] = sum((vertices[i] for i in ids), Vector()) / len(ids)
    return result


def reference_shape(point, joints):
    """Small continuous shape changes, never the old limb coordinate cutoffs."""
    x, y, z = point
    pelvis_y = joints["pelvis"].y
    torso = math.exp(-((y - pelvis_y - 21.8) / 18.0) ** 4) * math.exp(-(x / 17.0) ** 8)
    x *= 1.0 + .14 * torso
    # The official male morph establishes anatomy. Add modest, continuous
    # reference-specific waist/belly mass without a guessed gender correction.
    front = max(0.0, min(1.0, (z - 2.0) / 7.0))
    belly = math.exp(-(x / 10.0) ** 2 - ((y - pelvis_y - 15.8) / 9.0) ** 2)
    z += front * .8 * belly
    face_y = y - (joints["head"].y - 163.43)
    cheek = math.exp(-((abs(x) - 4.2) / 2.2) ** 2 - ((face_y - 166.5) / 3.0) ** 2)
    jaw = math.exp(-((abs(x) - 5.0) / 2.2) ** 2 - ((face_y - 160.0) / 3.0) ** 2)
    x += math.copysign(.22 * cheek + .35 * jaw, x) if abs(x) > .001 else 0.0
    return Vector((x, y, z))


def source_segments(joints, target):
    j = joints
    pairs = {
        "Hips": (j["pelvis"], j["spine-3"]),
        "Spine": (j["spine-3"], j["spine-2"]),
        "Spine1": (j["spine-2"], j["spine-1"]),
        "Spine2": (j["spine-1"], j["neck"]),
        "Neck": (j["neck"], j["head"]),
        "Head": (j["head"], j["head-2"]),
    }
    for side, tag in (("Left", "l"), ("Right", "r")):
        pairs.update({
            side + "Shoulder": (j[tag + "-clavicle"], j[tag + "-shoulder"]),
            side + "Arm": (j[tag + "-shoulder"], j[tag + "-elbow"]),
            side + "ForeArm": (j[tag + "-elbow"], j[tag + "-hand"]),
            side + "Hand": (j[tag + "-hand"], j[tag + "-finger-3-1"]),
            side + "UpLeg": (j[tag + "-upper-leg"], j[tag + "-knee"]),
            side + "Leg": (j[tag + "-knee"], j[tag + "-ankle"]),
            side + "Foot": (j[tag + "-ankle"], j[tag + "-foot-1"]),
            side + "ToeBase": (j[tag + "-foot-1"], j[tag + "-foot-2"]),
        })
        for finger, number in (("Thumb", 1), ("Index", 2), ("Middle", 3), ("Ring", 4), ("Pinky", 5)):
            for phalanx in (1, 2, 3):
                pairs[side + "Hand" + finger + str(phalanx)] = (
                    j[f"{tag}-finger-{number}-{phalanx}"],
                    j[f"{tag}-finger-{number}-{phalanx + 1}"])
    return {"mixamorig:" + name: (head.copy(), tail.copy())
            for name, (head, tail) in pairs.items()
            if "mixamorig:" + name in target.data.bones}


def segment_matrix(source_head, source_tail, target_head, target_tail):
    source_axis = source_tail - source_head
    target_axis = target_tail - target_head
    direction = source_axis.normalized()
    stretch = Matrix.Identity(3)
    ratio = target_axis.length / source_axis.length
    for row in range(3):
        for col in range(3):
            stretch[row][col] += (ratio - 1.0) * direction[row] * direction[col]
    linear = source_axis.rotation_difference(target_axis).to_matrix() @ stretch
    result = linear.to_4x4()
    result.translation = target_head - linear @ source_head
    return result


def normalize_weights(obj, limit=4):
    """Snapshot RNA values before edits; removal invalidates live RNA slots."""
    for vertex in obj.data.vertices:
        values = sorted(((g.group, float(g.weight)) for g in vertex.groups if g.weight > 1e-7),
                        key=lambda item: item[1], reverse=True)
        kept = values[:limit]
        total = sum(value for _, value in kept)
        keep_ids = {index for index, _ in kept}
        for index, _ in values:
            if index not in keep_ids:
                obj.vertex_groups[index].remove([vertex.index])
        if total <= 1e-8:
            raise RuntimeError(f"Unweighted source vertex {vertex.index} in {obj.name}")
        for index, value in kept:
            obj.vertex_groups[index].add([vertex.index], value / total, "REPLACE")


def attach(obj, rig):
    obj.parent = rig
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_basis = Matrix.Identity(4)
    for modifier in list(obj.modifiers):
        if modifier.type == "ARMATURE":
            obj.modifiers.remove(modifier)
    modifier = obj.modifiers.new("ARM_GameRig", "ARMATURE")
    modifier.object = rig
    modifier.use_deform_preserve_volume = False  # Match Godot's linear skinning.


def mesh_from_source(name, faces, positions, uvs):
    ids = sorted({v for face in faces for v, _ in face})
    remap = {source: i for i, source in enumerate(ids)}
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([positions[i] for i in ids], [],
                     [[remap[v] for v, _ in face] for face in faces])
    mesh.update()
    uv = mesh.uv_layers.new(name="JerseyUV")
    for polygon, corners in zip(mesh.polygons, faces):
        polygon.use_smooth = True
        for li, (_, ti) in zip(polygon.loop_indices, corners):
            uv.data[li].uv = uvs[ti]
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj, ids


class AnatomicalFit:
    def __init__(self, path, rig, skin):
        self.positions, self.uvs, self.groups = read_source(path)
        self.joints = joint_centres(self.positions, self.groups)
        self.positions = [reference_shape(p, self.joints) for p in self.positions]
        self.rig = rig
        self.segments = source_segments(self.joints, rig)
        self.transforms = {}
        self.joint_error_cm = 0.0
        for name, (head, tail) in self.segments.items():
            target = rig.data.bones[name]
            matrix = segment_matrix(head, tail, target.head_local, target.tail_local)
            self.transforms[name] = matrix
            self.joint_error_cm = max(self.joint_error_cm,
                (matrix @ head - target.head_local).length,
                (matrix @ tail - target.tail_local).length)
        body, self.body_ids = mesh_from_source("WORK_SourceAnatomy", self.groups["body"],
                                               self.positions, self.uvs)
        body.data.materials.append(skin)
        temporary_data = bpy.data.armatures.new("WORK_SourceLandmarkRig")
        temporary_rig = bpy.data.objects.new("WORK_SourceLandmarkRig", temporary_data)
        bpy.context.collection.objects.link(temporary_rig)
        temporary_rig.matrix_world = rig.matrix_world.copy()
        body.matrix_world = rig.matrix_world.copy()
        bpy.ops.object.select_all(action="DESELECT")
        temporary_rig.select_set(True)
        bpy.context.view_layer.objects.active = temporary_rig
        bpy.ops.object.mode_set(mode="EDIT")
        for name, (head, tail) in self.segments.items():
            bone = temporary_data.edit_bones.new(name)
            bone.head, bone.tail = head, tail
        for bone in temporary_data.edit_bones:
            parent = rig.data.bones[bone.name].parent
            if parent and parent.name in temporary_data.edit_bones:
                bone.parent = temporary_data.edit_bones[parent.name]
        bpy.ops.object.mode_set(mode="OBJECT")
        body.select_set(True)
        bpy.context.view_layer.objects.active = temporary_rig
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        normalize_weights(body)
        names = {g.index: g.name for g in body.vertex_groups}
        self.weights = {}
        self.tree = KDTree(len(self.body_ids))
        for vertex, source_id in zip(body.data.vertices, self.body_ids):
            weights = {names[g.group]: g.weight for g in vertex.groups if g.weight > 1e-7}
            self.weights[source_id] = weights
            self.tree.insert(self.positions[source_id], source_id)
            vertex.co = self.fit_point(self.positions[source_id], weights)
        self.tree.balance()
        body.data.calc_loop_triangles()
        self.target_positions = [vertex.co.copy() for vertex in body.data.vertices]
        self.target_triangles = [tuple(triangle.vertices) for triangle in body.data.loop_triangles]
        self.target_surface = BVHTree.FromPolygons(
            self.target_positions, self.target_triangles, all_triangles=True)
        attach(body, rig)
        bpy.data.objects.remove(temporary_rig, do_unlink=True)
        bpy.data.armatures.remove(temporary_data)
        self.body = body
        print("ANATOMICAL_JOINT_FIT", "segments", len(self.segments),
              "max_endpoint_error_cm", self.joint_error_cm)

    def weights_at(self, point):
        values = {}
        for _, index, distance in self.tree.find_n(point, 4):
            factor = 1.0 / max(distance, .02) ** 2
            for name, weight in self.weights[index].items():
                values[name] = values.get(name, 0.0) + factor * weight
        kept = sorted(values.items(), key=lambda item: item[1], reverse=True)[:4]
        total = sum(value for _, value in kept)
        return {name: value / total for name, value in kept}

    def fit_point(self, point, weights):
        result = sum(((self.transforms[name] @ point) * value for name, value in weights.items()), Vector())
        from shane_player_finish import reference_proportions
        return reference_proportions(result)

    def target_weights(self, point, triangle_index):
        indices = self.target_triangles[triangle_index]
        a, b, c = (self.target_positions[index] for index in indices)
        barycentric = barycentric_transform(point, a, b, c,
            Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
        values = {}
        for index, factor in zip(indices, barycentric):
            for name, value in self.weights[self.body_ids[index]].items():
                values[name] = values.get(name, 0.0) + max(0.0, factor) * value
        kept = sorted(values.items(), key=lambda item: item[1], reverse=True)[:4]
        total = sum(value for _, value in kept)
        return {name: value / total for name, value in kept if value > 1e-8}

    def piece(self, name, faces, material, clearance=0.0, uv_function=None, boundary_y=None):
        obj, ids = mesh_from_source(name, faces, self.positions, self.uvs)
        obj.data.materials.append(material)
        if uv_function:
            uv = obj.data.uv_layers.active
            for polygon in obj.data.polygons:
                for li in polygon.loop_indices:
                    vertex = obj.data.vertices[obj.data.loops[li].vertex_index]
                    uv.data[li].uv = uv_function(vertex.co)
        # Compute normals from the original licensed source, before fitting.
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        if clearance and name != "Hair_Crop_Fit":
            # Refine offline so garment chords follow the curved skin during
            # bends; this adds no runtime modifier or per-frame calculation.
            bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=1, use_grid_fill=True)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        edges = Counter(tuple(sorted(edge)) for polygon in obj.data.polygons
                        for edge in polygon.edge_keys)
        boundary = {index for edge, count in edges.items() if count == 1 for index in edge}
        groups = {}
        for vertex in obj.data.vertices:
            source = vertex.co.copy()
            cuff = False
            if name == "YBot_Surface" and vertex.index in boundary:
                wrist_x = abs(self.joints["l-hand"].x)
                hem_y = self.joints["pelvis"].y + .8
                collar_y = self.joints["neck"].y - 1.0
                if abs(source.x) > wrist_x - 6.0:
                    side = "Left" if source.x > 0 else "Right"
                    a, wrist = self.segments["mixamorig:" + side + "ForeArm"]
                    axis = (wrist - a).normalized()
                    source -= axis * (source - wrist).dot(axis)
                    cuff = True
                elif source.y < hem_y + 6.0:
                    source.y = hem_y
                elif source.y > collar_y - 4.5:
                    source.y = collar_y
            if boundary_y and vertex.index in boundary:
                source.y = min(boundary_y, key=lambda y: abs(source.y - y))
            weights = (self.weights.get(ids[vertex.index]) if not clearance else None) or self.weights_at(source)
            point = self.fit_point(source, weights)
            if clearance:
                # Fit against the actual target body, not an independently
                # scaled helper. This removes rest-pose body/sleeve z-fighting.
                nearest, normal, triangle_index, distance = self.target_surface.find_nearest(point)
                point = nearest + normal * clearance
                weights = self.target_weights(nearest, triangle_index)
                if name == "YBot_Surface" and cuff:
                    point.x = math.copysign(72.5, source.x)
                elif name == "Kit_Socks" and vertex.index in boundary:
                    point.y = 44.5 if source.y > 30.0 else 8.0
            vertex.co = point
            for bone, value in weights.items():
                vg = groups.get(bone)
                if vg is None:
                    vg = obj.vertex_groups.new(name=bone)
                    groups[bone] = vg
                vg.add([vertex.index], value, "REPLACE")
        if name == "Kit_Boots":
            sole_offset = min(v.co.y for v in obj.data.vertices) - .15
            for vertex in obj.data.vertices:
                t = max(0.0, min(1.0, (8.0 - vertex.co.y) / 6.0))
                vertex.co.y -= sole_offset * t * t * (3.0 - 2.0 * t)
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        attach(obj, self.rig)
        normalize_weights(obj)
        return obj


def select_faces(fitter, group, predicate):
    return [face for face in fitter.groups[group]
            if predicate(sum((fitter.positions[i] for i, _ in face), Vector()) / len(face))]


def eye_detail(fitter, side, material, radius, depth, forward):
    ids = {i for face in fitter.groups[f"helper-{side}-eye"] for i, _ in face}
    points = [fitter.positions[i] for i in ids]
    centre = sum(points, Vector()) / len(points)
    centre.z = max(p.z for p in points) + forward
    mesh = bpy.data.meshes.new("EyeDetail_" + side)
    bm = bmesh.new()
    result = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=radius)
    for vertex in result["verts"]:
        vertex.co.z *= depth / radius
        vertex.co += centre
        vertex.co = fitter.fit_point(vertex.co, {"mixamorig:Head": 1.0})
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new("EyeDetail_" + side + "_" + material.name, mesh)
    bpy.context.collection.objects.link(obj)
    group = obj.vertex_groups.new(name="mixamorig:Head")
    group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
    attach(obj, fitter.rig)
    return obj


def build_foundation(rig, source, materials):
    """Create a coherent base and fit-test kit, preserving the production rig."""
    fit = AnatomicalFit(source, rig, materials["skin"])
    neck_y = fit.joints["neck"].y
    pelvis_y = fit.joints["pelvis"].y
    knee_y = fit.joints["l-knee"].y
    ankle_y = fit.joints["l-ankle"].y
    shoulder_x = abs(fit.joints["l-shoulder"].x)
    wrist_x = abs(fit.joints["l-hand"].x)
    hem_y = pelvis_y + .8
    collar_y = neck_y - 1.0
    shorts_low = knee_y + .54 * (fit.joints["l-upper-leg"].y - knee_y)
    shorts_high = pelvis_y + 8.8
    sock_low, sock_high = ankle_y - 3.0, ankle_y + .82 * (knee_y - ankle_y)
    head_faces = select_faces(fit, "body", lambda p: p.y > neck_y - 1.8)
    def covered(p):
        # Only deep interior skin is removed. Keep overlap margins at collar,
        # cuffs and hems; retain the untouched source mesh for regeneration.
        return ((hem_y + 6.0 < p.y < neck_y - 6.0 and abs(p.x) < wrist_x - 3.0)
                or (shorts_low + 4.0 < p.y < shorts_high - 4.0 and abs(p.x) < 28.0)
                or p.y < sock_high - 4.0)
    body_faces = select_faces(fit, "body", lambda p: p.y <= neck_y - 1.8 and not covered(p))
    head = fit.piece("Skin_Head", head_faces, materials["skin"])
    body = fit.piece("YBot_Joints", body_faces, materials["skin"])
    bpy.data.objects.remove(fit.body, do_unlink=True)

    def shirt_uv(p):
        # Temporary existing atlas registration, pending the full panel unwrap.
        front = p.z > fit.joints["spine-2"].z + 2.0
        if abs(p.x) > shoulder_x + 2.3:
            side = "Left" if p.x > 0 else "Right"
            candidates = []
            for suffix in ("Arm", "ForeArm"):
                a, b = fit.segments["mixamorig:" + side + suffix]
                axis = b - a
                t = max(0.0, min(1.0, (p - a).dot(axis) / axis.length_squared))
                centre = a + axis * t
                candidates.append(((p - centre).length, centre))
            radial = p - min(candidates, key=lambda item: item[0])[1]
            # A sleeve needs two independent UV axes even while sampling a
            # plain-blue strip. A collapsed UV point makes tangent-space bump
            # undefined and caused the previous white-speckled sleeve render.
            # Use an undecorated blue stripe, away from back name/number art.
            u = .79 + .03 * math.atan2(radial.z, radial.y) / math.pi
            v = .12 + .75 * max(0.0, min(1.0, (abs(p.x) - shoulder_x) / (wrist_x - shoulder_x)))
            return (u, v)
        width = shoulder_x
        # Keep back UVs continuous through zero: wrapping each vertex to 0..1
        # made seam-crossing faces interpolate through the front of the atlas,
        # cutting a stripe through the number. REPEAT sampling wraps the image.
        u = .5 + .25 * max(-1.0, min(1.0, p.x / width)) if front else -.25 * p.x / width
        return (u, max(.02, min(.96, (p.y - hem_y) / (collar_y - hem_y))))

    shirt_faces = select_faces(fit, "helper-tights", lambda p:
                               hem_y < p.y < collar_y and abs(p.x) < wrist_x - .7)
    shirt = fit.piece("YBot_Surface", shirt_faces, materials["jersey"], 1.0, shirt_uv)
    shorts_faces = select_faces(fit, "helper-tights", lambda p: shorts_low < p.y < shorts_high and abs(p.x) < 28.0)
    shorts = fit.piece("Kit_Shorts", shorts_faces, materials["shorts"], 2.0, boundary_y=(shorts_low, shorts_high))
    socks_faces = select_faces(fit, "helper-tights", lambda p: sock_low < p.y < sock_high)
    socks = fit.piece("Kit_Socks", socks_faces, materials["blue"], .50, boundary_y=(sock_low, sock_high))
    boots_faces = select_faces(fit, "helper-tights", lambda p: p.y < ankle_y + 1.5)
    boots = fit.piece("Kit_Boots", boots_faces, materials["boots"], .75)
    head_y = fit.joints["head"].y
    hair_faces = select_faces(fit, "body", lambda p:
        p.y > head_y + (9.6 if p.z > fit.joints["head"].z + 3.0 else 5.6 if abs(p.x) > 5.0 else 4.0))
    hair = fit.piece("Hair_Crop_Fit", hair_faces, materials["hair"], .30)
    eyes = []
    for side in ("l", "r"):
        eyes.append(fit.piece("Eye_" + side, fit.groups[f"helper-{side}-eye"], materials["eye"]))
        eyes.append(eye_detail(fit, side, materials["iris"], .55, .16, .03))
        eyes.append(eye_detail(fit, side, materials["pupil"], .245, .10, .17))
    rig["anatomical_fit_max_endpoint_error_cm"] = fit.joint_error_cm
    rig["anatomical_fit_segments"] = len(fit.segments)
    rig["anatomical_fit_forward"] = "+Z local, matching foot/toe bones"
    return fit, [head, body, shirt, shorts, socks, boots, hair] + eyes
