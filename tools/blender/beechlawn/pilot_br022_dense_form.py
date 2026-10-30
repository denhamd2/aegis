"""Bounded bilateral landmark form study on the six current saved heads.

The portrait and model are eye-line normalised first. Matched left/right
landmarks are averaged to avoid baking photo yaw into a symmetric neutral
head. Smiling-photo mouth landmarks are excluded from neutral anatomy.
This script only writes isolated editable previews under ignored build/.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
PROJECT=ROOT/'games/beechlawn_rovers'
sys.path.insert(0,str(HERE))
from author_four_head_finish import SOURCES as FOUR_SOURCES,render
from player_head_groom import build_groom
import shane_player_finish

SOURCES={**FOUR_SOURCES,'robbie_roden':'robbie_roden_head.blend',
         'david_murray':'david_murray_head.blend'}
MEASUREMENT=PROJECT/'build/br022_dense_fit/landmarks.json'
OUTPUT=PROJECT/'build/br022_dense_fit'
EYE_DISTANCE_CM=6.694
EYE_HEIGHT_CM=166.526
PAIRS={
    'contour':[(234,454),(93,323),(132,361),(172,397),(150,379),
               (149,378),(176,400),(148,377)],
    'brow':[(70,300),(63,293),(105,334),(66,296),(107,336)],
    'eye':[(33,263),(133,362),(159,386),(145,374)],
    'nose':[(98,327),(97,326)],
    'mouth':[(61,291),(78,308),(82,312)],
}
CENTRES={'contour':[152], 'brow':[9], 'nose':[1,4,168], 'mouth':[13,14,0,17]}
LIMITS={'contour':.88,'brow':.45,'eye':.34,'nose':.50,'mouth':.38}


def smooth(a,b,value):
    t=np.clip((value-a)/(b-a),0,1)
    return t*t*(3-2*t)


def controls(record,identity):
    photo=np.asarray(record['reference']['normalized_points'])[:,:2]
    model=np.asarray(record['model']['normalized_points'])[:,:2]
    points=[];deltas=[];groups=[]
    for group,pairs in PAIRS.items():
        if group=='mouth' and identity in ('robbie_roden','david_murray'):continue
        for left,right in pairs:
            old_x=np.mean(np.abs(model[[left,right],0]))*EYE_DISTANCE_CM
            new_x=np.mean(np.abs(photo[[left,right],0]))*EYE_DISTANCE_CM
            old_y=np.mean(model[[left,right],1])*EYE_DISTANCE_CM+EYE_HEIGHT_CM
            new_y=np.mean(photo[[left,right],1])*EYE_DISTANCE_CM+EYE_HEIGHT_CM
            dx=np.clip(new_x-old_x,-LIMITS[group],LIMITS[group])
            dy=np.clip(new_y-old_y,-LIMITS[group],LIMITS[group])
            for sign in (-1,1):
                points.append((sign*old_x,old_y))
                deltas.append((sign*dx,dy))
                groups.append(group)
    for group,indices in CENTRES.items():
        if group=='mouth' and identity in ('robbie_roden','david_murray'):continue
        for index in indices:
            old_y=model[index,1]*EYE_DISTANCE_CM+EYE_HEIGHT_CM
            new_y=photo[index,1]*EYE_DISTANCE_CM+EYE_HEIGHT_CM
            points.append((0,old_y))
            deltas.append((0,np.clip(new_y-old_y,-LIMITS[group],LIMITS[group])))
            groups.append(group)
    return np.asarray(points),np.asarray(deltas),groups


def displace(coords,points,deltas,strength,gain):
    coords=np.asarray(coords,dtype=np.float64)
    xy=coords[:,:2]
    distance=np.sum((xy[:,None,:]-points[None,:,:])**2,axis=2)
    kernel=np.exp(-distance/(2*1.25**2))
    delta=(kernel@deltas)/(kernel.sum(axis=1)[:,None]+.45)
    delta*=gain
    lengths=np.linalg.norm(delta,axis=1)
    delta*=np.minimum(1,1.25/np.maximum(lengths,1e-6))[:,None]
    front=smooth(2.8,8.0,coords[:,2])
    neck=smooth(154.0,157.0,coords[:,1])
    delta*=front[:,None]*neck[:,None]*strength
    result=coords.copy()
    result[:,:2]+=delta
    return result


def apply(head,eyes,points,deltas,strength,gain):
    before=[v.co.copy() for v in head.data.vertices]
    groups=[tuple((g.group,round(g.weight,6)) for g in v.groups) for v in head.data.vertices]
    uv_count=len(head.data.uv_layers.active.data)
    for obj in (head,*eyes):
        if obj.data.shape_keys:
            for key in obj.data.shape_keys.key_blocks:
                coords=np.asarray([tuple(p.co) for p in key.data])
                moved=displace(coords,points,deltas,strength,gain)
                for p,value in zip(key.data,moved):p.co=value
                key.value=0
            neutral=obj.data.shape_keys.key_blocks['Basis'].data
            for vertex,point in zip(obj.data.vertices,neutral):vertex.co=point.co
        else:
            coords=np.asarray([tuple(v.co) for v in obj.data.vertices])
            moved=displace(coords,points,deltas,strength,gain)
            for v,value in zip(obj.data.vertices,moved):v.co=value
        obj.data.update()
    assert len(head.data.uv_layers.active.data)==uv_count
    for vertex,old,weights in zip(head.data.vertices,before,groups):
        assert tuple((g.group,round(g.weight,6)) for g in vertex.groups)==weights
        if old.y<154:assert (vertex.co-old).length<1e-5
    return max((vertex.co-old).length for vertex,old in zip(head.data.vertices,before))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--players',nargs='+',choices=list(SOURCES))
    parser.add_argument('--strength',type=float,default=.85)
    parser.add_argument('--gain',type=float,default=1.0)
    parser.add_argument('--views',nargs='+',default=['front','threequarter','profile'])
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    assert 0<args.strength<=1
    measurements=json.loads(MEASUREMENT.read_text())['players']
    for identity in args.players or SOURCES:
        bpy.ops.wm.open_mainfile(filepath=str(HERE/SOURCES[identity]))
        head=bpy.data.objects['Skin_Head']
        eyes=[bpy.data.objects['Eye_l'],bpy.data.objects['Eye_r']]
        control,delta,groups=controls(measurements[identity],identity)
        moved=apply(head,eyes,control,delta,args.strength,args.gain)
        output=OUTPUT/f'preview_{args.strength:.2f}_gain_{args.gain:.2f}'/identity
        output.mkdir(parents=True,exist_ok=True)
        shane_player_finish.TEXTURES=output/'temporary_textures'
        shane_player_finish.TEXTURES.mkdir(parents=True,exist_ok=True)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(output/(identity+'_head.blend')),compress=True)
        build_groom(head,bpy.data.objects['YBot_Armature'],identity)
        render(head,output,views=tuple(args.views))
        print('DENSE_FORM_PREVIEW',identity,len(control),round(moved,4),flush=True)


if __name__=='__main__':main()
