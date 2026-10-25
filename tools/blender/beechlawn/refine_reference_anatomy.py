"""Refine the saved individual sculpts, preserving topology/UVs/neck/rig.

Preview first: --player bordeaux_09 --preview --render. Apply only after clay
review; capture the new delta before the normal head export. This edits current
production sources rather than rebuilding an older whole-character generator.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PROJECT = ROOT/'games/beechlawn_rovers'
sys.path.insert(0,str(HERE))
from author_four_head_finish import SOURCES, render
from build_roster_heads import PARTS, SOURCE, apply_sculpt_part, write_json
from shane_head_variants import delta_data
from player_head_finish import smooth, field, finish_head

REVISION = 'individual-anatomy-v3'


def interpolate(y, values):
    for (a,va),(b,vb) in zip(values,values[1:]):
        if y <= b:
            return va+(vb-va)*smooth(a,b,y)
    return values[-1][1]


def refine(p, identity):
    x,y,z = p
    if y < 154: return p.copy()
    front = smooth(3.0,7.0,z)
    neck = smooth(154,157,y)
    width, flesh, chin = {
        'bordeaux_09': (1.12,.88,.95),
        'john_orourke': (.86,.80,.64),
        'shane_denham': (.57,.65,.38),
        'des_feeney_sr': (1.04,.80,.96),
    }[identity]
    # A continuous cheek/muzzle envelope removes the inherited medial hollow
    # and inflated malar ridge. Avoid treating each feature as an isolated bump.
    cheek_zone = smooth(1.8,3.0,abs(x))*(1-smooth(6.0,7.3,abs(x)))
    cheek_zone *= smooth(156.,158.,y)*(1-smooth(164.0,165.4,y))*front*neck
    depth = interpolate(y,[(154.,8.2),(156.,9.4),(158.,10.1),(160.,10.35),(162.,10.75),(164.,10.1),(166.,9.0)])
    envelope = depth*math.sqrt(max(.15,1-(x/10.)**2))
    z += (envelope-z)*cheek_zone*flesh
    lower = field(x,y,5.3,159.0,2.4,3.6)*smooth(-2,5,z)*neck
    x += math.copysign(width*lower,x)
    # Rounded lower cheeks and submental soft tissue, with an unchanged seam.
    z += chin*.65*field(x,y,0,155.9,4.8,1.6)*front*neck
    z += chin*.28*field(x,y,3.9,156.8,2.8,1.9)*front*neck
    if identity in ('bordeaux_09','john_orourke'):
        x += math.copysign(.72*field(x,y,5.8,162.5,1.8,2.0)*front,x)
    # The lower jaw must taper below the fuller cheeks. Widening the whole
    # lower face creates a square mannequin instead of a rounded human face.
    jaw = field(x,y,5.6,157.5,2.3,1.9)*smooth(-1,4,z)*neck
    x *= 1-{'bordeaux_09':.12,'john_orourke':.09,'shane_denham':.055,'des_feeney_sr':.10}[identity]*jaw
    y += .62*jaw*smooth(2.8,5.4,abs(x))
    # Round the exposed crown without shifting eyes or shortening the face.
    crown = smooth(169.4,172.8,y)
    centre = Vector((0,167.4,-.5))
    radius = Vector((8.25,8.7,10.7))
    v = Vector((x,y,z))-centre
    shell = math.sqrt(sum((v[i]/radius[i])**2 for i in range(3)))
    if shell > .01:
        target=centre+v/shell
        x,y,z = Vector((x,y,z)).lerp(target,crown*.55)
    # Integrate lips into the muzzle rather than leaving a projecting shelf.
    lip = field(x,y,0,159.9,3.8,.90)*front
    z -= (.44 if identity != 'shane_denham' else .28)*lip
    # Individual nasal tissue: player Des has a shorter, broad round tip;
    # John a compact tip; Shane a stronger bridge; referee a fleshy alar base.
    tip = field(x,y,0,162.1,1.3,.85)*front
    ala = field(x,y,1.5,161.7,.8,.65)*front
    nose = {'bordeaux_09':(-.47,.17),'john_orourke':(-.30,.08),
            'shane_denham':(-.12,.12),'des_feeney_sr':(.04,.24)}[identity]
    z += nose[0]*tip
    x += math.copysign(nose[1]*ala,x)
    # Older soft tissue is geometry; finer creases are a separate normal bake.
    if identity == 'des_feeney_sr':
        z += .40*field(x,y,3.7,164.9,2.0,.65)*front
        y -= .20*field(x,y,3.5,167.2,1.9,.55)*front
        z += .35*field(x,y,4.3,157.0,2.7,1.7)*front*neck
        crease = 2.1+.45*(162-y)
        z -= .13*math.exp(-((abs(x)-crease)/.40)**2-((y-160.1)/1.8)**4)*front
    # Recessed lids and natural facial asymmetry are retained, never painted.
    z += .05*math.sin(x*.7)*field(x,y,3.4,163.,3.0,3.2)*front
    return Vector((x,y,z))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--player', choices=SOURCES, required=True)
    parser.add_argument('--preview', action='store_true')
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--surfaces-only', action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    identity=args.player
    source=HERE/SOURCES[identity]
    bpy.ops.wm.open_mainfile(filepath=str(source))
    if args.surfaces_only:
        finish_head(bpy.data.objects['Skin_Head'],identity)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
        print('REFERENCE_SURFACES',identity,flush=True)
        return
    assert bpy.context.scene.get('anatomy_revision') != REVISION, 'Already refined; open the saved sculpt instead of applying twice'
    head=bpy.data.objects['Skin_Head']
    old=head.data.copy()
    edited=old.copy()
    for vertex in edited.vertices: vertex.co=refine(vertex.co,identity)
    change=delta_data(old,edited)
    apply_sculpt_part(head,change,True)
    bpy.data.meshes.remove(old);bpy.data.meshes.remove(edited)
    bpy.context.scene['anatomy_revision']=REVISION
    if args.preview:
        path=PROJECT/'build/realism_finish'/f'{identity}_preview.blend'
    else:
        path=source
        # Capture against the immutable master before finish/expressions bake.
        with bpy.data.libraries.load(str(SOURCE),link=False) as (_,target): target.objects=list(PARTS)
        parts={name:delta_data(base.data,bpy.data.objects[name].data) for name,base in zip(PARTS,target.objects)}
        write_json(HERE/'head_pipeline/deltas'/f'{identity}.json',{
            'player_id':identity,'master_revision':bpy.context.scene['head_master_revision'],'parts':parts})
        for obj in target.objects: bpy.data.objects.remove(obj,do_unlink=True)
        finish_head(head,identity)
    path.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
    if args.render:
        out=PROJECT/('build/realism_finish/clay' if args.preview else 'docs/art_briefs/realism_finish/clay')/identity
        render(head,out,clay=True)
    print('REFERENCE_ANATOMY',identity,'preview' if args.preview else 'applied', flush=True)


if __name__=='__main__':main()
