"""Isolated smaller oral opening and fitted crowns for Robbie and David.

This study saves no production source or export. Inspect neutral and Smile
before using any part of it in the shared-head pipeline.
"""
import argparse
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
import shane_player_finish
from shane_player_finish import bound_mesh
from player_oral_geometry import upper_lip_weights
from player_head_groom import build_groom
from author_four_head_finish import render


def ease(a, b, v):
    u = max(0.0, min(1.0, (v-a)/(b-a)))
    return u*u*(3-2*u)


def fit_smile(head, identity, recess_depth=.50, recess_width=.85,
              recess_x=3.3, recess_power=2, recess_profile='plateau'):
    weights = upper_lip_weights(head)
    keys = head.data.shape_keys.key_blocks
    basis, smile = keys['Basis'], keys['Smile']
    for i, item in enumerate(smile.data):
        x,y,z = basis.data[i].co
        if y<154: continue
        ax=abs(x)
        frontal=ease(7.7,9.35,z)
        centre=math.exp(-(x/3.6)**6)
        oral=centre*math.exp(-((y-159.25)/1.10)**4)*frontal
        w=weights.get(i)
        if w is not None:
            upper=max(0.,min(1.,w))
            lower=1-upper
            item.co.y += oral*(.34*upper-.12*lower)
            item.co.z += oral*(-.07*upper+.025*lower)
        # This inherited head is a closed continuous mesh: there is no mouth
        # boundary edge. Recess only the central seam in Smile, behind the
        # dental and mucosal surfaces. Neutral remains completely sealed.
        if recess_profile=='plateau':
            recess=(1-ease(2.55,4.1,ax))*(1-ease(.4,1.5,abs(y-159.13)))
            recess*=ease(9.0,9.75,z)
        else:
            recess=math.exp(-(x/recess_x)**4-abs((y-159.13)/recess_width)**recess_power)
            recess*=ease(9.15,9.90,z)
        item.co.z-=recess_depth*recess
        corner=math.exp(-((ax-3.2)/1.15)**4-((y-159.6)/.95)**4)*frontal
        cheek=math.exp(-((ax-4.55)/2.25)**2-((y-162.)/2.)**2)*frontal
        item.co.x += math.copysign(.13*corner,x)
        item.co.y += .34*corner+.13*cheek
        item.co.z += .04*corner+.10*cheek
    return len(weights)


def build_crowns(rig, identity):
    material=bpy.data.materials.new('MAT_WarmEnamel_'+identity)
    material.use_nodes=True
    bsdf=material.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value=(.64,.60,.53,1)
    bsdf.inputs['Roughness'].default_value=.43
    bsdf.inputs['Specular IOR Level'].default_value=.22
    vertices=[];faces=[]
    teeth=((-2.36,.52,.48),(-1.78,.59,.56),(-1.13,.66,.60),(-.38,.74,.65),
           (.38,.74,.64),(1.12,.65,.59),(1.77,.59,.54),(2.34,.52,.47))
    for index,(x,width,height) in enumerate(teeth):
        mesh=bmesh.new()
        bmesh.ops.create_cube(mesh,size=1)
        for vertex in mesh.verts:
            u=vertex.co.x
            # Crown is subtly tapered at its gum edge and bulges forward.
            vertical=vertex.co.y
            vertex.co=Vector((u*width*(1+.06*vertical),vertical*height,
                              vertex.co.z*.22+.05*(1-u*u)))
        bmesh.ops.bevel(mesh,geom=list(mesh.edges),offset=.075,segments=3,
                        affect='EDGES')
        mesh.verts.ensure_lookup_table();mesh.verts.index_update()
        start=len(vertices)
        centre=Vector((x,159.44+.035*x*x+.018*math.sin(index*.9),
                       9.76-.04*x*x))
        vertices.extend(v.co+centre for v in mesh.verts)
        faces.extend(tuple(start+v.index for v in face.verts) for face in mesh.faces)
        mesh.free()
    return bound_mesh('Mouth_UpperTeeth',vertices,faces,rig,material)


def build_cavity(rig, identity):
    material=bpy.data.materials.new('MAT_OralMucosa_'+identity)
    material.use_nodes=True
    bsdf=material.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value=(.115,.026,.032,1)
    bsdf.inputs['Roughness'].default_value=.82
    vertices=[Vector((0,159.10,9.43))]
    for i in range(40):
        angle=2*math.pi*i/40
        x=3.15*math.cos(angle)
        y=159.10+.55*math.sin(angle)
        vertices.append(Vector((x,y,9.43-.035*x*x)))
    faces=[(0,1+i,1+(i+1)%40) for i in range(40)]
    return bound_mesh('Mouth_Cavity',vertices,faces,rig,material)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--players',nargs='+',default=['robbie_roden','david_murray'],
                        choices=['robbie_roden','david_murray'])
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for identity in args.players:
        source=HERE/(identity+'_head.blend')
        bpy.ops.wm.open_mainfile(filepath=str(source))
        head=bpy.data.objects['Skin_Head']
        rig=bpy.data.objects['YBot_Armature']
        count=fit_smile(head,identity)
        build_crowns(rig,identity)
        build_cavity(rig,identity)
        output=ROOT/'games/beechlawn_rovers/build/br022_oral_v2'/identity
        shane_player_finish.TEXTURES=output/'temporary_textures'
        shane_player_finish.TEXTURES.mkdir(parents=True,exist_ok=True)
        build_groom(head,rig,identity)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(output/'oral_v2.blend'),compress=True)
        render(head,output/'neutral',views=('front','threequarter'))
        head.data.shape_keys.key_blocks['Smile'].value=1
        render(head,output/'smile',views=('front','threequarter'))
        print('ORAL_V2_PREVIEW',identity,count,flush=True)


if __name__=='__main__':
    main()
