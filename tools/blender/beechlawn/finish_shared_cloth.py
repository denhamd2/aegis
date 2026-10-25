"""Finish local garment construction on the live shared source.

Read-only unless --preview=/tmp/review.blend or --apply. The licensed anatomical donor
supplies only the missing arm faces, not an older body, rig or animation set.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import sys

import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from repair_shared_kit import SOURCE, export_current, smooth
from refine_shared_shoulders import folds, POSES

OUT = ROOT / 'games/beechlawn_rovers/docs/art_briefs/shared_cloth_finish'
SHIRTS = ('YBot_Surface', 'Kit_Shirt_ShortSleeve')
DONOR = ROOT / 'games/beechlawn_rovers/references/third_party/makehuman/base.obj'
RECTS = json.loads((ROOT / 'games/beechlawn_rovers/assets/characters/textures/beechlawn_home_tailored_atlas_layout.json').read_text())['rects']


def key(point):
    return tuple(round(c, 5) for c in point)


def integrity(rig):
    data = [('rest', [(b.name, list(map(list, b.matrix_local))) for b in rig.data.bones])]
    for action in sorted(bpy.data.actions, key=lambda a: a.name):
        data.append((action.name, [(f.data_path, f.array_index, [(tuple(k.co), tuple(k.handle_left), tuple(k.handle_right), k.interpolation) for k in f.keyframe_points]) for f in action.fcurves]))
    for obj in sorted((o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name not in (*SHIRTS, 'YBot_Joints', 'Kit_shirt_BoundHems')), key=lambda o: o.name):
        data.append((obj.name, [tuple(v.co) for v in obj.data.vertices], [tuple(uv.uv) for uv in obj.data.uv_layers.active.data], [[(obj.vertex_groups[g.group].name, g.weight) for g in v.groups] for v in obj.data.vertices]))
    return hashlib.sha256(repr(data).encode()).hexdigest()


def arm_coverage(mesh):
    mesh.calc_loop_triangles()
    tree = BVHTree.FromPolygons([v.co for v in mesh.vertices], [t.vertices for t in mesh.loop_triangles], all_triangles=True)
    missing = []
    for side in (-1, 1):
        for x in (42, 48, 54, 60, 66, 70):
            if tree.ray_cast(Vector((side*x, 143, 30)), Vector((0, 0, -1)), 80)[0] is None:
                missing.append(side*x)
    return missing


def restore_arm_skin():
    body = bpy.data.objects['YBot_Joints']
    old = body.data
    original_objects = set(bpy.data.objects)
    original_actions = set(bpy.data.actions)
    from shane_anatomical_foundation import AnatomicalFit
    fitter = AnatomicalFit(DONOR, bpy.data.objects['YBot_Armature'], old.materials[0])
    donor = fitter.body
    donor.data.update()
    lookup = {key(v.co): v.index for v in old.vertices}
    vertices = [v.co.copy() for v in old.vertices]
    weights = [[(body.vertex_groups[g.group].name, g.weight) for g in v.groups] for v in old.vertices]
    faces = [tuple(p.vertices) for p in old.polygons]
    existing = {tuple(sorted(key(old.vertices[i].co) for i in p.vertices)) for p in old.polygons}
    uvs = [tuple(v.uv) for v in old.uv_layers.active.data]
    normals = [n.vector.copy() for n in old.corner_normals]
    old_loop_count = len(normals)
    added = 0
    for poly in donor.data.polygons:
        if not (34 < abs(poly.center.x) < 72.4 and 128 < poly.center.y < 154):
            continue
        signature = tuple(sorted(key(donor.data.vertices[i].co) for i in poly.vertices))
        if signature in existing:
            continue
        ids = []
        for i in poly.vertices:
            v = donor.data.vertices[i]
            if key(v.co) not in lookup:
                lookup[key(v.co)] = len(vertices)
                vertices.append(v.co.copy())
                weights.append([(donor.vertex_groups[g.group].name, g.weight) for g in v.groups])
            ids.append(lookup[key(v.co)])
        faces.append(ids)
        uvs.extend(tuple(donor.data.uv_layers.active.data[li].uv) for li in poly.loop_indices)
        normals.extend(donor.data.corner_normals[li].vector.copy() for li in poly.loop_indices)
        added += 1
    mesh = bpy.data.meshes.new('Shared_Skin_With_Continuous_Arms')
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.clear()
    for material in old.materials:
        mesh.materials.append(material)
    layer = mesh.uv_layers.new(name=old.uv_layers.active.name)
    for corner, uv in zip(layer.data, uvs):
        corner.uv = uv
    for p in mesh.polygons:
        p.use_smooth = True
    body.data = mesh
    for i, values in enumerate(weights):
        for name, value in values:
            group = body.vertex_groups.get(name) or body.vertex_groups.new(name=name)
            group.add([i], value, 'REPLACE')
    mesh.normals_split_custom_set(normals)
    mesh.update()
    # Adding the custom-normal attribute invalidates cached UV-layer RNA.
    layer = mesh.uv_layers.active
    # Existing vertices, UVs, weights and corner normals survive, including
    # the independent-head neck interface. No old source replaces that skin.
    assert all(tuple(v.co) == tuple(old.vertices[i].co) for i, v in enumerate(mesh.vertices[:len(old.vertices)]))
    errors = [(i, tuple(layer.data[i].uv), tuple(old.uv_layers.active.data[i].uv)) for i in range(old_loop_count) if tuple(layer.data[i].uv) != tuple(old.uv_layers.active.data[i].uv)]
    assert not errors, errors[:4]
    error = max((mesh.corner_normals[i].vector-normals[i]).length for i in range(old_loop_count))
    assert error < .0002, error
    for i, values in enumerate(weights[:len(old.vertices)]):
        current = sorted((body.vertex_groups[g.group].name, g.weight) for g in mesh.vertices[i].groups)
        assert current == sorted(values), ('Retained skin weights changed', i)
    for imported in set(bpy.data.objects)-original_objects:
        bpy.data.objects.remove(imported, do_unlink=True)
    for imported in set(bpy.data.actions)-original_actions:
        bpy.data.actions.remove(imported, do_unlink=True)
    return {'added_faces': added, 'added_vertices': len(vertices)-len(old.vertices), 'preserved_skin_vertices': len(old.vertices), 'maximum_retained_normal_error': error, 'donor_sha256': hashlib.sha256(DONOR.read_bytes()).hexdigest()}


def ordered_boundary(edges):
    adjacency = {}
    for edge in edges:
        a, b = edge.verts
        adjacency.setdefault(a, []).append(b)
        adjacency.setdefault(b, []).append(a)
    assert adjacency and all(len(v) == 2 for v in adjacency.values()), 'Expected one closed cut ring'
    start = min(adjacency, key=lambda v: (v.co.x, v.co.z))
    ring = [start]
    previous = None
    current = start
    while True:
        nxt = next(v for v in adjacency[current] if v != previous)
        if nxt == start:
            break
        ring.append(nxt)
        previous, current = current, nxt
        assert len(ring) <= len(adjacency)
    assert len(ring) == len(adjacency), 'Unexpected multiple hem loops'
    return ring


def panel_uv(point, front):
    x0, y0, x1, y1 = RECTS['front' if front else 'back']
    u = max(.002, min(.998, .5+(point.x if front else -point.x)/46))
    v = max(.002, min(.998, (point.y-100.5)/50))
    return ((x0+u*(x1-x0))/2048, 1-(y1-v*(y1-y0))/2048)


def clean_hem(obj):
    mesh = obj.data
    shorts = bpy.data.objects['Kit_Shorts'].data
    shorts.calc_loop_triangles()
    waist_surface = BVHTree.FromPolygons([v.co for v in shorts.vertices], [t.vertices for t in shorts.loop_triangles], all_triangles=True)
    clearance_adjustments = 0
    maximum_clearance_shift = 0
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    source_ids = bm.verts.layers.int.new('cloth_source_vertex')
    for v in bm.verts:
        v[source_ids] = v.index
    deform = bm.verts.layers.deform.verify()
    uv_layer = bm.loops.layers.uv.active
    bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces), dist=.00001, plane_co=Vector((0, 112, 0)), plane_no=Vector((0, 1, 0)))
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y < 111.999], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    top = ordered_boundary([e for e in bm.edges if e.is_boundary and all(abs(v.co.y-112) < .001 for v in e.verts)])
    # Original boundary ordering is retained, rather than bridging nearest
    # points across the body. Six clean quad rows replace the folded strip.
    angles = [math.atan2(v.co.x/17.6, (v.co.z-5.9)/11.7) for v in top]
    previous = top
    new_faces = []
    hip = obj.vertex_groups['mixamorig:Hips'].index
    spine = obj.vertex_groups['mixamorig:Spine'].index
    for row in range(1, 7):
        t = row/6
        y = 112-11.5*t
        ring = []
        for original, angle in zip(top, angles):
            target = Vector((18.5*math.sin(angle), y, 4.6+12.6*math.cos(angle)))
            p = original.co.lerp(target, smooth(0, 1, t))
            p.y = y
            # Keep the sewn shirt outside the shorts waistband. The old
            # overlap appeared as a black tear in actual Web close-ups.
            if y < 108:
                near, normal, _, distance = waist_surface.find_nearest(p)
                if near is not None and distance < 3.5:
                    outward = Vector((normal.x, 0, normal.z)).normalized()
                    clearance = (p-near).dot(outward)
                    if clearance < .65:
                        shift = outward*(.65-clearance)*(1-smooth(104, 108, y))
                        p += shift
                        clearance_adjustments += 1
                        maximum_clearance_shift = max(maximum_clearance_shift, shift.length)
            v = bm.verts.new(p)
            v[source_ids] = -1
            # The lower edge follows the pelvis, with a gradual spine blend.
            upper = .30*smooth(101, 112, y)
            v[deform][hip] = 1-upper
            v[deform][spine] = upper
            ring.append(v)
        for i in range(len(ring)):
            j = (i+1) % len(ring)
            new_faces.append(bm.faces.new((previous[i], previous[j], ring[j], ring[i])))
        previous = ring
    # Folded 2 mm edge with an upward inner return, not disconnected ribbons.
    inner = []
    for v, angle in zip(previous, angles):
        p = v.co+Vector((-.20*math.sin(angle), .8, -.20*math.cos(angle)))
        n = bm.verts.new(p)
        n[source_ids] = -1
        n[deform][hip] = 1
        inner.append(n)
    for i in range(len(inner)):
        j = (i+1) % len(inner)
        new_faces.append(bm.faces.new((previous[i], previous[j], inner[j], inner[i])))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    # Recalculation on an open shell can choose either orientation.
    score = sum(f.normal.z*f.calc_area() for f in bm.faces if f.calc_center_median().z > 10 and abs(f.calc_center_median().x) < 12)
    if score < 0:
        for face in bm.faces:
            face.normal_flip()
    for face in new_faces:
        front = face.calc_center_median().z > -2
        face.smooth = True
        for loop in face.loops:
            loop[uv_layer].uv = panel_uv(loop.vert.co, front)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return {'cut_height_cm': 112, 'hem_height_cm': 100.5, 'ring_vertices': len(top), 'new_quads': len(new_faces), 'waist_clearance_vertices': clearance_adjustments, 'maximum_clearance_shift_cm': round(maximum_clearance_shift, 4)}


def soften_rear_armhole(obj):
    # Reshape the underarm gusset rather than relaxing the whole sleeve tube.
    # The extracted anatomy had a low/recessed rear axilla that collapsed
    # during arm-down poses. Keep chest, collar and sleeve endpoints pinned.
    count = 0
    maximum = 0
    for vertex in obj.data.vertices:
        x, y, z = vertex.co
        ax = abs(x)
        if not (15 < ax < 34 and 126 < y < 148 and z < -2):
            continue
        influence = math.exp(-((ax-24)/5)**2-((y-136)/4)**2)*smooth(2, 5, -z)
        shift = Vector((-math.copysign(1, x), 4, -3))*influence
        vertex.co += shift
        maximum = max(maximum, shift.length)
        count += 1
    obj.data.update()
    return {'vertices': count, 'maximum_displacement_cm': round(maximum, 4)}


def remove_old_hem_ribbons():
    obj = bpy.data.objects['Kit_shirt_BoundHems']
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    faces = [f for f in bm.faces if f.calc_center_median().y < 112 and abs(f.calc_center_median().x) < 30]
    count = len(faces)
    bmesh.ops.delete(bm, geom=faces, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', default=str(SOURCE))
    parser.add_argument('--preview')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    assert not (args.preview and args.apply)
    bpy.ops.wm.open_mainfile(filepath=str(Path(args.source).resolve()))
    rig = bpy.data.objects['YBot_Armature']
    if rig.get('cloth_finish_revision') == 1:
        print('CLOTH_FINISH already applied')
        return
    assert len(rig.data.bones) == 65 and len(bpy.data.actions) == 19
    protected = integrity(rig)
    shirt = bpy.data.objects[SHIRTS[0]]
    shirt.data.calc_loop_triangles()
    cohort = [t.vertices[:] for t in shirt.data.loop_triangles if 118 < sum(shirt.data.vertices[i].co.y for i in t.vertices)/3 < 151 and max(abs(shirt.data.vertices[i].co.x) for i in t.vertices) < 32]
    before = folds(rig, shirt, cohort)
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    report = {'baseline': '39ba9fd0d5c48c371ac00c79299df40c48382ff0', 'missing_arm_samples_before': arm_coverage(bpy.data.objects['YBot_Joints'].data), 'before': before, 'protected_sha256': protected}
    report['skin'] = restore_arm_skin()
    report['garments'] = {}
    for name in SHIRTS:
        obj = bpy.data.objects[name]
        report['garments'][name] = clean_hem(obj)
        report['garments'][name]['rear_gusset'] = soften_rear_armhole(obj)
    report['removed_hem_ribbons'] = remove_old_hem_ribbons()
    remap = {a.value: i for i, a in enumerate(shirt.data.attributes['cloth_source_vertex'].data) if shirt.data.vertices[i].co.y > 116}
    after_cohort = [tuple(remap[i] for i in ids) for ids in cohort]
    report['after'] = folds(rig, shirt, after_cohort)
    report['missing_arm_samples_after'] = arm_coverage(bpy.data.objects['YBot_Joints'].data)
    assert not report['missing_arm_samples_after'], report['missing_arm_samples_after']
    assert protected == integrity(rig), 'Protected rig, actions or anatomy changed'
    report['bones'] = len(rig.data.bones)
    report['clips'] = len(bpy.data.actions)
    assert all(report['after'][name]['inverted_triangles'] < before[name]['inverted_triangles'] for name, _ in POSES), 'Pose-fold gate did not improve'
    report['atlas_sha256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'games/beechlawn_rovers/assets/characters/textures/shared').glob('*.png')}
    print('CLOTH_FINISH '+json.dumps({'skin': report['skin'], 'missing_arm_samples': report['missing_arm_samples_after'], 'folds': {n: [before[n]['inverted_triangles'], report['after'][n]['inverted_triangles']] for n, _ in POSES}}), flush=True)
    rig.animation_data.action = bpy.data.actions['AN_Beechlawn_Idle']
    bpy.context.scene.frame_set(1)
    if args.preview or args.apply:
        rig['cloth_finish_revision'] = 1
    if args.preview:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(Path(args.preview).resolve()))
        Path(args.preview+'.json').write_text(json.dumps(report, indent=2)+'\n')
    elif args.apply:
        rig['cloth_finish_revision'] = 1
        export_current(rig)
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT/'validation.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    main()
