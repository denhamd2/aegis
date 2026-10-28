"""Four repeatable BR-022 sculpt/finish passes on the live individual sources.

Run stages 1..4 in order. The generated roster sheets guide Robbie and David;
their unseen anatomy is an estimate. No body, rig, UV, weight or action edits.
"""
import argparse
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
from author_four_head_finish import SOURCES as FOUR_SOURCES, render
from build_roster_heads import PARTS, SOURCE, open_master, apply_sculpt_part, write_json
from shane_head_variants import delta_data
from player_head_finish import field, smooth, finish_head

SOURCES = {**FOUR_SOURCES, 'robbie_roden': 'robbie_roden_head.blend',
           'david_murray': 'david_murray_head.blend'}
# Centimetres. The distinct shapes are deliberately bounded: the reference
# photos are low resolution, and two players have generated sheets only.
FORM = {
    'shane_denham': (.10, .16, -.05, -.06, -.10),
    'john_orourke': (.08, .20, .12, -.05, -.08),
    'bordeaux_09': (.10, .13, .13, -.04, -.08),
    'des_feeney_sr': (.11, .28, .25, -.04, -.07),
    'robbie_roden': (.42, .55, .55, -.08, -.12),
    'david_murray': (-.28, -.08, -.12, -.10, -.08),
}


def sculpt(point, identity, stage):
    x, y, z = point
    if y < 154: return point.copy()
    width, cheek, jaw, orbit, lip = FORM[identity]
    front = smooth(3., 8., z)
    neck = smooth(154., 157., y)
    ax = abs(x)
    if stage == 1:
        # Skull width, malar plane and lower jaw are one continuous envelope.
        x += math.copysign(width * field(x,y,6.3,163.,3.3,5.0)*neck, x)
        z += cheek * field(x,y,4.7,161.8,2.7,2.9)*front*neck
        x += math.copysign(jaw * field(x,y,5.4,157.8,3.1,2.1)*neck, x)
        z += .28*jaw * field(x,y,0,156.4,4.2,1.5)*front*neck
        # Shorter, less cylindrical crown on the new roster-sheet heads.
        if identity in ('robbie_roden','david_murray'):
            y -= (.22 if identity=='robbie_roden' else .11)*smooth(170.,176.,y)
    elif stage == 2:
        # Fit lid aperture to a smaller globe; do not paint away large eyes.
        eye = math.exp(-((ax-3.35)/2.25)**4-((y-166.48)/1.7)**4)*front
        y = 166.48+(y-166.48)*(1-.075*eye)
        z += orbit*eye
        z += .10*field(x,y,3.4,165.25,1.8,.53)*front
        z += .09*field(x,y,3.5,167.75,2.0,.55)*front
        if identity == 'des_feeney_sr':
            y -= .12*field(x,y,3.35,167.25,1.9,.48)*front
    elif stage == 3:
        tip = field(x,y,0,162.25,1.45,.9)*front
        alar = field(x,y,1.5,161.75,.85,.65)*front
        # Lower the over-projected triangular tip and soften the nostril wing.
        z -= (.11 if identity=='des_feeney_sr' else .22)*tip
        x += math.copysign(.10*alar,x)
        mouth = field(x,y,0,159.9,3.7,.88)*front
        z += lip*mouth
        x *= 1-.022*mouth
        # Low amplitude asymmetry helps the repeated left/right facial planes.
        z += .045*math.sin(x*.72)*field(x,y,3.8,162.2,3.2,3.2)*front
        if identity == 'des_feeney_sr':
            z += .24*field(x,y,4.5,157.4,2.4,1.7)*front*neck
    return Vector((x,y,z))


def reviewed_fourth_pass(point, identity):
    """Visible identity correction after comparing the first native portraits."""
    x,y,z=point
    if y<154 or identity not in ('robbie_roden','david_murray'):
        return point.copy()
    front=smooth(3.,8.,z);neck=smooth(154.,157.,y)
    if identity=='robbie_roden':
        x+=math.copysign(1.15*field(x,y,5.6,162.,3.8,5.2)*neck,x)
        x+=math.copysign(.90*field(x,y,5.2,158.0,3.4,2.2)*neck,x)
        z+=.62*field(x,y,4.6,161.3,3.0,2.7)*front*neck
        x*=1+.060*field(x,y,0,159.9,4.1,.85)*front
    else:
        x-=math.copysign(1.25*field(x,y,5.8,162.,3.8,5.2)*neck,x)
        x-=math.copysign(.58*field(x,y,5.0,157.8,3.2,2.1)*neck,x)
        z+=.30*field(x,y,0,162.3,1.5,1.1)*front
        y+=.28*smooth(170.,176.,y)
    return Vector((x,y,z))


def mouth_review(point):
    x,y,z=point
    if y<154: return point.copy()
    front=smooth(3.,8.,z)
    lip=math.exp(-(x/5.4)**6-((y-159.85)/.92)**4)*front
    x*=1-.18*lip
    z-=.14*lip
    y+=.07*lip*smooth(2.3,4.6,abs(x))
    return Vector((x,y,z))


def robbie_lip_review(point):
    # The first native close-up still showed a wide, projecting inherited
    # oral silhouette. Include the full corner loops, not only the centre.
    x,y,z=point
    if y<154: return point.copy()
    lip=math.exp(-(x/7.0)**6-((y-159.85)/1.55)**4)*smooth(3.,8.,z)
    x*=1-.26*lip
    z-=.22*lip
    return Vector((x,y,z))


def robbie_profile_review(point):
    # Native comparison showed that the broad fourth-pass cheek/jaw revision
    # flattened Robbie into a cartoon mask. Restore the slimmer planes while
    # retaining his individual skin, crop, eyes and revised oral loops.
    x,y,z=point
    if y<154: return point.copy()
    front=smooth(3.,8.,z);neck=smooth(154.,157.,y)
    x-=math.copysign(1.08*field(x,y,5.6,162.,3.8,5.2)*neck,x)
    x-=math.copysign(.82*field(x,y,5.2,158.,3.4,2.2)*neck,x)
    z-=.55*field(x,y,4.6,161.3,3.,2.7)*front*neck
    return Vector((x,y,z))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pass',type=int,choices=(1,2,3,4),required=True,dest='stage')
    parser.add_argument('--players',nargs='+',choices=tuple(SOURCES),default=list(SOURCES))
    parser.add_argument('--render',action='store_true')
    parser.add_argument('--review-correction',action='store_true',
                        help='Revise the fourth pass after native identity review')
    parser.add_argument('--mouth-correction',action='store_true',
                        help='Finish the fourth-pass lip review on the new heads')
    parser.add_argument('--lip-final-correction',action='store_true',
                        help='Narrow Robbie oral corner loops after native review')
    parser.add_argument('--profile-final-correction',action='store_true',
                        help='Restore Robbie natural cheek/jaw planes after native review')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for identity in args.players:
        source=HERE/SOURCES[identity]
        new_source=not source.exists()
        if source.exists():
            bpy.ops.wm.open_mainfile(filepath=str(source))
        else:
            assert args.stage==1 and identity in ('robbie_roden','david_murray')
            open_master()
            import json
            revision=json.loads((HERE/'head_pipeline/master.json').read_text())['revision']
            bpy.context.scene['head_master_revision']=revision
            bpy.context.scene['head_player_id']=identity
        master_meshes={name:bpy.data.objects[name].data.copy() for name in PARTS} if new_source else {}
        expected=args.stage if (args.review_correction or args.mouth_correction or args.lip_final_correction or args.profile_final_correction) else args.stage-1
        assert int(bpy.context.scene.get('br022_pass',0))==expected, (identity,'wrong pass order')
        assert not args.review_correction or (args.stage==4 and identity in ('robbie_roden','david_murray')
            and not bpy.context.scene.get('br022_review_correction',False))
        assert not args.mouth_correction or (args.stage==4 and identity in ('robbie_roden','david_murray')
            and bpy.context.scene.get('br022_review_correction',False)
            and not bpy.context.scene.get('br022_mouth_review',False))
        assert not args.lip_final_correction or (args.stage==4 and identity=='robbie_roden'
            and bpy.context.scene.get('br022_mouth_review',False)
            and not bpy.context.scene.get('br022_lip_final_review',False))
        assert not args.profile_final_correction or (args.stage==4 and identity=='robbie_roden'
            and bpy.context.scene.get('br022_lip_final_review',False)
            and not bpy.context.scene.get('br022_profile_final_review',False))
        head=bpy.data.objects['Skin_Head']
        if args.stage <= 3:
            old=head.data.copy();edited=old.copy()
            for vertex in edited.vertices:
                vertex.co=sculpt(vertex.co,identity,args.stage)
            apply_sculpt_part(head,delta_data(old,edited),True)
            bpy.data.meshes.remove(old);bpy.data.meshes.remove(edited)
            if args.stage==2:
                for side in ('l','r'):
                    eye=bpy.data.objects['Eye_'+side]
                    centre=sum((v.co for v in eye.data.vertices),Vector())/len(eye.data.vertices)
                    for vertex in eye.data.vertices:
                        p=vertex.co-centre
                        vertex.co=centre+Vector((p.x*.96,p.y*.925,p.z*.96-.035))
        else:
            if args.review_correction:
                old=head.data.copy();edited=old.copy()
                for vertex in edited.vertices:
                    vertex.co=reviewed_fourth_pass(vertex.co,identity)
                apply_sculpt_part(head,delta_data(old,edited),True)
                bpy.data.meshes.remove(old);bpy.data.meshes.remove(edited)
            if args.mouth_correction:
                old=head.data.copy();edited=old.copy()
                for vertex in edited.vertices: vertex.co=mouth_review(vertex.co)
                apply_sculpt_part(head,delta_data(old,edited),True)
                bpy.data.meshes.remove(old);bpy.data.meshes.remove(edited)
            if args.lip_final_correction:
                old=head.data.copy();edited=old.copy()
                for vertex in edited.vertices: vertex.co=robbie_lip_review(vertex.co)
                apply_sculpt_part(head,delta_data(old,edited),True)
                bpy.data.meshes.remove(old);bpy.data.meshes.remove(edited)
            if args.profile_final_correction:
                old=head.data.copy();edited=old.copy()
                for vertex in edited.vertices: vertex.co=robbie_profile_review(vertex.co)
                apply_sculpt_part(head,delta_data(old,edited),True)
                bpy.data.meshes.remove(old);bpy.data.meshes.remove(edited)
            finish_head(head,identity)
        if new_source:
            bases=master_meshes
        else:
            with bpy.data.libraries.load(str(SOURCE),link=False) as (_,target):
                target.objects=list(PARTS)
            bases={name:base.data for name,base in zip(PARTS,target.objects)}
        parts={name:delta_data(bases[name],bpy.data.objects[name].data)
               for name in PARTS}
        for index,offset in parts['Skin_Head']['offsets'].items():
            assert bases['Skin_Head'].vertices[int(index)].co.y>=154 or Vector(offset).length<1e-5
        write_json(HERE/'head_pipeline/deltas'/f'{identity}.json',{
            'player_id':identity,'master_revision':bpy.context.scene['head_master_revision'],
            'parts':parts})
        if not new_source:
            for obj in target.objects: bpy.data.objects.remove(obj,do_unlink=True)
        else:
            for mesh in master_meshes.values(): bpy.data.meshes.remove(mesh)
        bpy.context.scene['br022_pass']=args.stage
        if args.review_correction: bpy.context.scene['br022_review_correction']=True
        if args.mouth_correction: bpy.context.scene['br022_mouth_review']=True
        if args.lip_final_correction: bpy.context.scene['br022_lip_final_review']=True
        if args.profile_final_correction: bpy.context.scene['br022_profile_final_review']=True
        bpy.data.orphans_purge(do_recursive=True)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
        if args.render:
            out=ROOT/'games/beechlawn_rovers/docs/art_briefs/br022_realism_2026_10_28'/f'pass_{args.stage}'/identity
            render(head,out,clay=args.stage<4,views=('front',))
        print('BR022_FACE_PASS',args.stage,identity,len(parts['Skin_Head']['offsets']),flush=True)


if __name__=='__main__': main()
