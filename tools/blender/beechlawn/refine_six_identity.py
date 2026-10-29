"""Reference-led form pass on the six current production heads.

Run without --apply to save previews. --apply captures each neutral head and
eyes against the unchanged shared master, then saves the artist source. This
does not rebuild the body or change the 65-bone bind.
"""
import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE))
from author_four_head_finish import SOURCES as FOUR_SOURCES, render
from build_roster_heads import PARTS, SOURCE, apply_sculpt_part, write_json
from shane_head_variants import delta_data
from player_head_finish import facial_shapes, finish_head, smooth
from player_oral_geometry import build_upper_teeth
from player_head_groom import build_groom

SOURCES={**FOUR_SOURCES,'robbie_roden':'robbie_roden_head.blend',
         'david_murray':'david_murray_head.blend'}
# Saved sources carry this revision tag from the first form trial. The oral
# trial was rejected; the final exports retain the earlier restrained smile.
REVISION='six-portrait-form-and-oral-v1'


def patch(x,y,cx,cy,sx,sy):
    return math.exp(-((abs(x)-cx)/sx)**4-((y-cy)/sy)**4)


def sculpt(p,identity,eye_centres):
    x,y,z=p
    if y<154:return p.copy()
    front=smooth(4.6,8.0,z)*smooth(154,157,y)
    edge=smooth(3.5,6.4,abs(x))*smooth(154,157,y)
    # First pass: individual skull, cheek and jaw envelopes. These are
    # intentionally broad; local pigment must not substitute for facial form.
    if identity=='shane_denham':
        x-=math.copysign(.29*patch(x,y,6.6,167.0,2.1,3.3)*edge,x)
        z+=.22*patch(x,y,4.2,162.2,2.6,2.6)*front
        z+=.10*patch(x,y,.0,163.2,1.1,1.6)*front
    elif identity=='john_orourke':
        x-=math.copysign(.36*patch(x,y,6.5,165.3,2.4,4.0)*edge,x)
        z+=.22*patch(x,y,4.4,162.2,2.5,2.8)*front
        z-=.30*patch(x,y,0,162.2,1.35,1.25)*front
        x-=math.copysign(.12*patch(x,y,1.35,162.0,.9,1.1)*front,x)
    elif identity=='bordeaux_09':
        x-=math.copysign(.25*patch(x,y,5.55,158.7,2.9,3.1)*edge,x)
        z+=.25*patch(x,y,4.3,159.2,2.5,2.4)*front
        z+=.21*patch(x,y,3.35,165.25,2.1,.62)*front
    elif identity=='des_feeney_sr':
        x-=math.copysign(.16*patch(x,y,5.9,162.5,2.4,4.2)*edge,x)
        z-=.10*patch(x,y,3.7,162.1,2.0,3.0)*front
        z+=.16*patch(x,y,0,162.0,1.45,1.35)*front
        z+=.10*patch(x,y,3.4,165.15,2.0,.68)*front
        z+=.10*patch(x,y,4.6,158.3,1.9,1.6)*front
        x+=math.copysign(.06*patch(x,y,5.1,158.3,1.8,1.8)*edge,x)
        fold=2.2+.41*(162-y)
        z-=.08*math.exp(-((abs(x)-fold)/.50)**2-((y-160.2)/2.2)**4)*front
        z-=.04*patch(x,y,5.1,164.9,1.0,.22)*front
        for cy,depth in ((170.55,.025),(171.50,.022),(172.35,.015)):
            z-=depth*math.exp(-((y-cy-.08*math.cos(x*.5))/.17)**2-(x/5.2)**6)*front
    elif identity=='robbie_roden':
        x+=math.copysign(.10*patch(x,y,5.0,162.5,2.4,2.5)*edge,x)
        x-=math.copysign(.36*patch(x,y,5.6,157.3,2.4,1.9)*edge,x)
        z+=.38*patch(x,y,4.4,161.5,2.5,2.6)*front
        z+=.24*patch(x,y,3.1,156.4,3.5,1.5)*front
        z+=.13*patch(x,y,0,162.0,1.25,1.25)*front
    elif identity=='david_murray':
        x+=math.copysign(.06*patch(x,y,5.2,159.1,2.7,3.0)*edge,x)
        z+=.43*patch(x,y,4.5,161.7,2.5,2.8)*front
        z+=.29*patch(x,y,3.0,156.3,3.3,1.5)*front
        z-=.12*patch(x,y,0,162.2,1.3,1.1)*front
    # Second pass: fit the neutral visible eyelid apertures while retaining
    # the existing eyeball centres and independent fitted Blink morph.
    amount={'shane_denham':.03,'john_orourke':.10,'bordeaux_09':.15,
            'des_feeney_sr':-.03,'robbie_roden':.06,'david_murray':.09}[identity]
    if identity=='bordeaux_09':amount=.30
    centre=min(eye_centres,key=lambda c:abs(c.x-x))
    dx,dy=x-centre.x,y-centre.y
    eye=math.exp(-(dx/1.82)**6-(dy/1.08)**6)*smooth(6.8,8.4,z)
    y+=amount*dy*eye
    # Eye-line-normalised comparisons show the inherited lower third is too
    # short, especially for the referee and the two smiling portraits. Fade
    # the change above the mouth and into the protected neck band.
    lower_drop={'shane_denham':.35,'john_orourke':.32,'bordeaux_09':.56,
                'des_feeney_sr':.48,'robbie_roden':.82,'david_murray':.85}[identity]
    y-=lower_drop*math.exp(-((y-157.2)/2.85)**4)*smooth(154,156,y)*smooth(2.0,6.0,z)
    # A trace of natural asymmetry prevents identical mirrored cheek planes.
    z+=.035*math.sin(x*.77)*patch(x,y,3.9,162.8,3.0,3.6)*front
    return Vector((x,y,z))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply',action='store_true')
    parser.add_argument('--player',choices=tuple(SOURCES))
    parser.add_argument('--render',action='store_true')
    parser.add_argument('--expressions-only',action='store_true',help='Refresh the saved expression meshes without changing the sculpt')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    identities=(args.player,) if args.player else tuple(SOURCES)
    for identity in identities:
        source=HERE/SOURCES[identity]
        bpy.ops.wm.open_mainfile(filepath=str(source))
        if args.expressions_only:
            if not args.apply:raise ValueError('--expressions-only requires --apply')
            head=bpy.data.objects['Skin_Head']
            for obj in list(bpy.data.objects):
                if obj.name.startswith('Mouth_'):bpy.data.objects.remove(obj,do_unlink=True)
            facial_shapes(head)
            if identity=='shane_denham':
                build_upper_teeth(bpy.data.objects['YBot_Armature'],identity)
            bpy.ops.outliner.orphans_purge(do_recursive=True)
            bpy.context.preferences.filepaths.save_version=0
            bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
            print('IDENTITY_EXPRESSIONS',identity,flush=True)
            continue
        if bpy.context.scene.get('identity_revision')==REVISION:
            raise RuntimeError('The identity pass is already applied: '+identity)
        head=bpy.data.objects['Skin_Head']
        eye_centres=[sum((v.co for v in bpy.data.objects['Eye_'+side].data.vertices),Vector())/
                     len(bpy.data.objects['Eye_'+side].data.vertices) for side in ('l','r')]
        old=head.data.copy();edited=old.copy()
        for vertex in edited.vertices:
            vertex.co=sculpt(vertex.co,identity,eye_centres)
        change=delta_data(old,edited)
        apply_sculpt_part(head,change,True)
        bpy.data.meshes.remove(old);bpy.data.meshes.remove(edited)
        bpy.context.scene['identity_revision']=REVISION
        facial_shapes(head)
        if identity=='shane_denham':
            build_upper_teeth(bpy.data.objects['YBot_Armature'],identity)
        if args.apply:
            with bpy.data.libraries.load(str(SOURCE),link=False) as (_,target):
                target.objects=list(PARTS)
            parts={name:delta_data(base.data,bpy.data.objects[name].data)
                   for name,base in zip(PARTS,target.objects)}
            write_json(HERE/'head_pipeline/deltas'/f'{identity}.json',{
                'player_id':identity,'master_revision':bpy.context.scene['head_master_revision'],
                'parts':parts})
            for obj in target.objects:bpy.data.objects.remove(obj,do_unlink=True)
            finish_head(head,identity)
            output=source
        else:
            output=ROOT/'games/beechlawn_rovers/build/likeness_preview'/source.name
            output.parent.mkdir(parents=True,exist_ok=True)
        bpy.context.preferences.filepaths.save_version=0
        if args.apply:bpy.ops.outliner.orphans_purge(do_recursive=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(output),compress=True)
        if args.render:
            build_groom(head,bpy.data.objects['YBot_Armature'],identity)
            folder=ROOT/'games/beechlawn_rovers/build/likeness_preview'/identity
            render(head,folder,views=('front','threequarter','profile'))
            head.data.shape_keys.key_blocks['Smile'].value=1
            for name in ('Mouth_UpperTeeth',):
                part=bpy.data.objects.get(name)
                if part and part.data.shape_keys:part.data.shape_keys.key_blocks['Smile'].value=1
            render(head,folder/'smile',views=('front',))
        print('IDENTITY_REFINEMENT',identity,'applied' if args.apply else 'preview',
              'vertices',len(change['offsets']),flush=True)


if __name__=='__main__':main()
