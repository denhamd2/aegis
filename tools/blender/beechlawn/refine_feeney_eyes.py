"""Round the two Feeney eye apertures on their current saved sculpts.

Preview: blender -b --python-exit-code 1 --python <file> -- --render
Apply after review: append --apply. Preserves the common body/neck/rig.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
PROJECT=ROOT/'games/beechlawn_rovers'
sys.path.insert(0,str(HERE))
from author_four_head_finish import SOURCES,render
from build_roster_heads import PARTS,SOURCE,apply_sculpt_part,write_json
from shane_head_variants import delta_data
from player_head_finish import smooth,finish_head,facial_shapes
from player_head_groom import build_groom

REVISION='feeney-rounded-apertures-v1'


def centre(obj):
    return sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)


def surface(mesh,positions=None):
    return BVHTree.FromPolygons(positions if positions is not None else [v.co for v in mesh.vertices],[list(p.vertices) for p in mesh.polygons])


def aperture(head,eye,positions=None,allow_closed=False):
    """Front orthographic visibility, not globe size or a texture measurement."""
    skin,globe=surface(head.data,positions),surface(eye.data)
    c=centre(eye)
    visible=[]
    for row in range(101):
        y=c.y-1.5+row*.03
        for column in range(121):
            x=c.x-1.8+column*.03
            origin=Vector((x,y,30))
            e,_,_,_=globe.ray_cast(origin,Vector((0,0,-1)))
            if e is None: continue
            h,_,_,_=skin.ray_cast(origin,Vector((0,0,-1)))
            if h is None or e.z>h.z+.005: visible.append((x,y))
    if not visible and allow_closed:
        return {'width_cm':0,'height_cm':0,'height_width':0,'visible_samples':0}
    assert visible,'Eye is completely hidden'
    width=max(p[0] for p in visible)-min(p[0] for p in visible)
    height=max(p[1] for p in visible)-min(p[1] for p in visible)
    # A fully closed lid can leave a single sub-sample of globe visibility.
    # Its measured width is zero; retain that result instead of dividing by it.
    return {'width_cm':round(width,3),'height_cm':round(height,3),
            'height_width':round(height/width,4) if width > 1e-8 else 0,
            'visible_samples':len(visible)}


def round_lid(point,centres,identity):
    x,y,z=point
    c=min(centres,key=lambda p:abs(p.x-x))
    dx,dy=x-c.x,y-c.y
    weight=math.exp(-(dx/2.0)**6-(dy/1.05)**6)*smooth(5.8,7.5,z)
    # Rounder aperture, not an enlarged eyeball pushed through the face.
    # The narrow support fades before the eyebrows/aged orbital folds.
    vertical=.24 if identity=='bordeaux_09' else .22
    return Vector((x-.035*dx*weight,y+vertical*dy*weight,z))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply',action='store_true')
    parser.add_argument('--render',action='store_true')
    parser.add_argument('--blink-only',action='store_true')
    parser.add_argument('--player',choices=('bordeaux_09','des_feeney_sr'))
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    output=PROJECT/('docs/art_briefs/realism_finish/round_eyes' if args.apply else 'build/realism_finish/round_eye_preview')
    reports={}
    for identity in ([args.player] if args.player else ('bordeaux_09','des_feeney_sr')):
        path=HERE/SOURCES[identity]
        bpy.ops.wm.open_mainfile(filepath=str(path))
        print('FEENEY_EYE_BEGIN',identity,flush=True)
        head=bpy.data.objects['Skin_Head']
        original_materials=list(head.data.materials)
        eyes=[bpy.data.objects['Eye_'+side] for side in ('l','r')]
        if args.blink_only:
            assert args.apply and bpy.context.scene.get('eye_roundness_revision')==REVISION
            facial_shapes(head)
            closed=[p.co.copy() for p in head.data.shape_keys.key_blocks['Blink'].data]
            opened={eye.name:aperture(head,eye) for eye in eyes}
            shut={eye.name:aperture(head,eye,closed,True) for eye in eyes}
            for name in shut:
                assert shut[name]['visible_samples']<opened[name]['visible_samples']*.05,(identity,name,shut)
            bpy.context.preferences.filepaths.save_version=0
            bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
            report_path=output/'apertures.json'
            existing=json.loads(report_path.read_text())
            existing[identity]['blink']=shut
            existing[identity]['source_after_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
            write_json(report_path,existing)
            print('FEENEY_BLINK_FIT',identity,json.dumps(shut),flush=True)
            continue
        assert bpy.context.scene.get('eye_roundness_revision')!=REVISION,'Already applied: inspect current sculpt instead of applying twice'
        centres=[centre(eye) for eye in eyes]
        before={eye.name:aperture(head,eye) for eye in eyes}
        if args.render: render(head,output/identity/'before',clay=True,views=('front',))
        base=head.data.copy();edited=base.copy()
        for vertex in edited.vertices: vertex.co=round_lid(vertex.co,centres,identity)
        apply_sculpt_part(head,delta_data(base,edited),True)
        bpy.data.meshes.remove(base);bpy.data.meshes.remove(edited)
        # Rebalance the existing slightly oval globe toward round while
        # retaining centre, corneal depth, iris UVs and gaze direction.
        for eye,c in zip(eyes,centres):
            base=eye.data.copy();edited=base.copy()
            for vertex in edited.vertices:
                p=vertex.co-c
                vertex.co=c+Vector((p.x*.985,p.y*1.055,p.z))
            apply_sculpt_part(eye,delta_data(base,edited))
            bpy.data.meshes.remove(base);bpy.data.meshes.remove(edited)
        after={eye.name:aperture(head,eye) for eye in eyes}
        for name in before:
            assert after[name]['height_width']>before[name]['height_width']*1.04,(identity,name,before,after)
        reports[identity]={'before':before,'after':after,'revision':REVISION,'source_before_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'limits':'Front aperture measurement; native likeness and blink review remain separate gates.'}
        report_path=output/'apertures.json'
        existing=json.loads(report_path.read_text()) if report_path.exists() else {}
        existing[identity]=reports[identity]
        write_json(report_path,existing)
        if args.apply:
            # Retain live materials before clay review. Appending from the
            # currently open .blend can crash Blender's library loader.
            head.data.materials.clear()
            for material in original_materials: head.data.materials.append(material)
            with bpy.data.libraries.load(str(SOURCE),link=False) as (_,target): target.objects=list(PARTS)
            parts={name:delta_data(original.data,bpy.data.objects[name].data) for name,original in zip(PARTS,target.objects)}
            for original in target.objects: bpy.data.objects.remove(original,do_unlink=True)
            finish_head(head,identity)
            closed=[p.co.copy() for p in head.data.shape_keys.key_blocks['Blink'].data]
            reports[identity]['blink']={eye.name:aperture(head,eye,closed,True) for eye in eyes}
            build_groom(head,bpy.data.objects['YBot_Armature'],identity)
            bpy.context.scene['eye_roundness_revision']=REVISION
            bpy.context.preferences.filepaths.save_version=0
            bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
            write_json(HERE/'head_pipeline/deltas'/f'{identity}.json',{
                'player_id':identity,'master_revision':bpy.context.scene['head_master_revision'],'parts':parts})
            reports[identity]['source_after_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
            existing[identity]=reports[identity]
            write_json(report_path,existing)
        if args.render: render(head,output/identity/'after',clay=True,views=('front',))
        print('FEENEY_EYE_APERTURE',identity,json.dumps(reports[identity]),flush=True)


if __name__=='__main__': main()
