"""Bounded shared shirt silhouette refinement; preserve topology, UVs and rig.

Audit by default. --preview writes a disposable source, --apply exports live.
Source coordinates are the existing rig-local centimetres, Y-up/Z-forward.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from repair_shared_kit import SOURCE, export_current, smooth
from refine_shared_shoulders import folds, POSES

SHIRTS = ('YBot_Surface', 'Kit_Shirt_ShortSleeve')
OUT = ROOT / 'games/beechlawn_rovers/docs/art_briefs/shared_sleeve_fit'


def digest(value):
    return hashlib.sha256(repr(value).encode()).hexdigest()


def protected_state(rig):
    """Only the two shirts' positions may change; even their weights stay fixed."""
    state = [('rig', [(b.name, list(map(list, b.matrix_local))) for b in rig.data.bones])]
    for action in sorted(bpy.data.actions, key=lambda a: a.name):
        state.append((action.name, [(f.data_path, f.array_index, [(tuple(k.co), tuple(k.handle_left), tuple(k.handle_right), k.interpolation) for k in f.keyframe_points]) for f in action.fcurves]))
    for obj in sorted((o for o in bpy.context.scene.objects if o.type == 'MESH'), key=lambda o: o.name):
        mesh = obj.data
        item = [obj.name, [tuple(p.vertices) for p in mesh.polygons],
                [tuple(uv.uv) for uv in mesh.uv_layers.active.data],
                [[(obj.vertex_groups[g.group].name, g.weight) for g in v.groups] for v in mesh.vertices]]
        if obj.name not in SHIRTS:
            item += [[tuple(v.co) for v in mesh.vertices], [tuple(n.vector) for n in mesh.corner_normals]]
        state.append(item)
    return digest(state)


def cloth_contour(obj, skin):
    original = [v.co.copy() for v in obj.data.vertices]
    back_count = sleeve_count = 0
    max_back = max_sleeve = 0.0
    # Fill the anatomical central hollow with a broad, continuous cloth envelope.
    # Pin collar, axilla, sleeves, sides and lower torso with smooth falloffs.
    for v in obj.data.vertices:
        x, y, z = v.co
        ax = abs(x)
        if ax < 24 and 126 < y < 151 and z < -3:
            blend = (1-smooth(17, 24, ax))*smooth(126, 131, y)*(1-smooth(145, 151, y))*smooth(3, 6, -z)
            target = -10.4+.003*x*x+.012*(y-141)**2
            shift = min(0, target-z)*blend
            if shift < -.00001:
                v.co.z += shift
                back_count += 1
                max_back = max(max_back, -shift)
        # Long sleeve only: preserve the wrist/cuff join and upper-arm cap.
        # Never shrink through the restored underlying arm skin.
        if obj.name == 'YBot_Surface' and 40 < ax < 73:
            blend = smooth(40, 50, ax)*(1-smooth(68, 73, ax))
            centre = Vector((x, 143.57, -6.17))
            radial = v.co-centre
            radius = radial.length
            if radius > .01:
                direction = radial/radius
                requested = radius*(1-.10*blend)
                hit, _, _, distance = skin.ray_cast(centre, direction, 15)
                minimum = distance+.35 if hit is not None else requested
                new_radius = min(radius, max(requested, minimum))
                shift = radius-new_radius
                if shift > .00001:
                    v.co = centre+direction*new_radius
                    sleeve_count += 1
                    max_sleeve = max(max_sleeve, shift)
    obj.data.update()
    return {'back_vertices': back_count, 'maximum_back_fill_cm': round(max_back, 5),
            'sleeve_vertices': sleeve_count, 'maximum_sleeve_taper_cm': round(max_sleeve, 5),
            'moved_vertices': sum((v.co-p).length > .00001 for v, p in zip(obj.data.vertices, original))}


def back_profile(mesh):
    # Centred rear cloth must span the scapular ridge rather than dip inward.
    result = []
    for y in (132, 134, 136, 138):
        central = [v.co.z for v in mesh.vertices if abs(v.co.x) < 1 and abs(v.co.y-y) < 1 and v.co.z < -3]
        lateral = [v.co.z for v in mesh.vertices if abs(abs(v.co.x)-10) < 1 and abs(v.co.y-y) < 1 and v.co.z < -3]
        if central and lateral:
            result.append({'height_cm': y, 'central_recess_cm': round(sum(central)/len(central)-sum(lateral)/len(lateral), 5)})
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', default=str(SOURCE))
    p.add_argument('--preview')
    p.add_argument('--apply', action='store_true')
    args = p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    assert not (args.preview and args.apply)
    bpy.ops.wm.open_mainfile(filepath=str(Path(args.source).resolve()))
    rig = bpy.data.objects['YBot_Armature']
    if rig.get('sleeve_fit_revision') == 1:
        print('SLEEVE_FIT already applied')
        return
    assert rig.get('cloth_finish_revision') == 1
    assert len(rig.data.bones) == 65 and len(bpy.data.actions) == 19
    protected = protected_state(rig)
    shirt = bpy.data.objects[SHIRTS[0]]
    shirt.data.calc_loop_triangles()
    cohort = [t.vertices[:] for t in shirt.data.loop_triangles if 118 < sum(shirt.data.vertices[i].co.y for i in t.vertices)/3 < 151 and max(abs(shirt.data.vertices[i].co.x) for i in t.vertices) < 32]
    report = {'baseline': '1c48ba9', 'before': folds(rig, shirt, cohort), 'back_before': back_profile(shirt.data)}
    rig.animation_data.action = None
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    body = bpy.data.objects['YBot_Joints'].data
    body.calc_loop_triangles()
    skin = BVHTree.FromPolygons([v.co for v in body.vertices], [t.vertices for t in body.loop_triangles], all_triangles=True)
    report['changes'] = {name: cloth_contour(bpy.data.objects[name], skin) for name in SHIRTS}
    report['after'] = folds(rig, shirt, cohort)
    report['back_after'] = back_profile(shirt.data)
    assert protected == protected_state(rig), 'Protected mesh, UVs, weights, rests or clips changed'
    # Geometry diagnostics supplement the matched render review; allow no
    # increase in aggregate fold count and no >5% regression in any fixed pose.
    before_total = sum(v['inverted_triangles'] for v in report['before'].values())
    after_total = sum(v['inverted_triangles'] for v in report['after'].values())
    assert after_total <= before_total, (before_total, after_total)
    assert all(report['after'][n]['inverted_triangles'] <= report['before'][n]['inverted_triangles']*1.05 for n, _ in POSES)
    assert max(v['central_recess_cm'] for v in report['back_after']) < .25
    report['protected_sha256'] = protected
    report['atlas_sha256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'games/beechlawn_rovers/assets/characters/textures/shared').glob('*.png')}
    report['bones'] = 65
    report['clips'] = 19
    print('SLEEVE_FIT '+json.dumps({'changes': report['changes'], 'back': report['back_after'], 'fold_totals': [before_total, after_total], 'folds': {n: [report['before'][n]['inverted_triangles'], report['after'][n]['inverted_triangles']] for n, _ in POSES}}), flush=True)
    rig.animation_data.action = bpy.data.actions['AN_Beechlawn_Idle']
    bpy.context.scene.frame_set(1)
    if args.preview or args.apply:
        rig['sleeve_fit_revision'] = 1
    if args.preview:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(Path(args.preview).resolve()))
        Path(args.preview+'.json').write_text(json.dumps(report, indent=2)+'\n')
    elif args.apply:
        export_current(rig)
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT/'validation.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    main()
