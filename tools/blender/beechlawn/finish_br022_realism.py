"""Rebake saved individual heads and optionally apply one bounded form review.

The current source/delta pair is authoritative. The optional geometry pass
updates the source and its revisioned delta together; UVs, skin weights, neck,
rig and football actions remain unchanged. Run with Blender --python-exit-code 1.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from author_four_head_finish import SOURCES as FOUR_SOURCES
from build_roster_heads import PARTS,SOURCE,apply_sculpt_part,write_json
from shane_head_variants import delta_data
from player_head_finish import finish_head,smooth

SOURCES={**FOUR_SOURCES,'robbie_roden':'robbie_roden_head.blend',
         'david_murray':'david_murray_head.blend'}


def form_review(point,identity,eye_y):
    """Millimetre-scale eye and muzzle work in the existing centimetre cage."""
    x,y,z=point
    if y<154: return point.copy()
    front=smooth(6.2,8.7,z)
    eye_x=abs(x)-3.35
    eye=math.exp(-(eye_x/2.0)**4-((y-eye_y)/1.55)**4)*front
    upper={'shane_denham':.24,'john_orourke':.23,'bordeaux_09':.17,
           'des_feeney_sr':.14,'robbie_roden':.19,'david_murray':.18}[identity]
    if y>eye_y+.07:
        y-=upper*eye*smooth(eye_y+.07,eye_y+.32,y)
    elif y<eye_y-.06:
        y+=.07*eye*(1.-smooth(eye_y-.32,eye_y-.06,y))
    # Keep the oral loops in order. The inherited corners are wider than the
    # supplied neutral portraits, especially Robbie's starting head.
    width={'shane_denham':.075,'john_orourke':.07,'bordeaux_09':.07,
           'des_feeney_sr':.04,'robbie_roden':.12,'david_murray':0.}[identity]
    lip=math.exp(-(x/5.8)**6-((y-159.85)/1.18)**4)*front
    x*=1.-width*lip
    z-=.07*lip
    # A shallow malar-to-oral transition prevents a perfectly planar cheek.
    cheek=math.exp(-((abs(x)-4.25)/1.6)**4-((y-161.5)/2.)**4)*front
    z+=.08*cheek
    if identity=='david_murray':
        # The owner portrait has full lower cheeks and a rounded jaw. The
        # generated roster sheet had made this face conspicuously too narrow.
        lower=smooth(154.3,157.0,y)*(1.-smooth(164.0,167.0,y))
        outer=smooth(2.0,4.5,abs(x))
        x*=1.+.095*lower*outer
        z+=.16*math.exp(-((abs(x)-4.8)/2.2)**4-((y-160.4)/2.4)**4)*front
    elif identity=='robbie_roden':
        # A softer, fuller jaw matches the confirmed original smile photo.
        jaw=smooth(154.4,157.5,y)*(1.-smooth(161.3,164.0,y))
        x+=math.copysign(.16*jaw*smooth(2.2,4.5,abs(x)),x)
        z+=.13*math.exp(-((abs(x)-4.4)/2.3)**4-((y-160.3)/2.2)**4)*front
    return Vector((x,y,z))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--players',nargs='+',choices=tuple(SOURCES),default=list(SOURCES))
    parser.add_argument('--geometry-review',action='store_true',
                        help='Apply one bounded lid/mouth/cheek correction')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for identity in args.players:
        path=HERE/SOURCES[identity]
        bpy.ops.wm.open_mainfile(filepath=str(path))
        head=bpy.data.objects['Skin_Head']
        assert bpy.context.scene.get('head_player_id')==identity,(identity,'wrong saved source')
        assert len(bpy.data.objects['YBot_Armature'].data.bones)==65
        if args.geometry_review:
            assert not bpy.context.scene.get('br022_followup_form',False),(identity,'form already applied')
            eye_y=sum(sum(v.co.y for v in bpy.data.objects['Eye_'+side].data.vertices)/
                      len(bpy.data.objects['Eye_'+side].data.vertices) for side in ('l','r'))/2
            old=head.data.copy();edited=old.copy()
            for vertex in edited.vertices:
                vertex.co=form_review(vertex.co,identity,eye_y)
            apply_sculpt_part(head,delta_data(old,edited),True)
            bpy.data.meshes.remove(old);bpy.data.meshes.remove(edited)
            bpy.context.scene['br022_followup_form']=True
        finish_head(head,identity)
        with bpy.data.libraries.load(str(SOURCE),link=False) as (_,target):
            target.objects=list(PARTS)
        bases={name:obj.data for name,obj in zip(PARTS,target.objects)}
        parts={name:delta_data(bases[name],bpy.data.objects[name].data) for name in PARTS}
        for index,offset in parts['Skin_Head']['offsets'].items():
            assert bases['Skin_Head'].vertices[int(index)].co.y>=154 or Vector(offset).length<1e-5
        write_json(HERE/'head_pipeline/deltas'/f'{identity}.json',{
            'player_id':identity,
            'master_revision':bpy.context.scene['head_master_revision'],
            'parts':parts})
        for obj in target.objects: bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.orphans_purge(do_recursive=True)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
        print('BR022_REALISM_FINISH',identity,len(parts['Skin_Head']['offsets']),flush=True)


if __name__=='__main__':main()
