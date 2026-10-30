"""Measure isolated BR-022 mouth study visibility and lip winding."""
import argparse
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
PREVIEW=ROOT/'games/beechlawn_rovers/build/br022_oral_v2'


def tree(mesh, positions):
    return BVHTree.FromPolygons(positions,[list(poly.vertices) for poly in mesh.polygons])


def report(identity):
    bpy.ops.wm.open_mainfile(filepath=str(PREVIEW/identity/'oral_v2.blend'))
    head=bpy.data.objects['Skin_Head']
    dental=bpy.data.objects['Mouth_UpperTeeth']
    cavity=bpy.data.objects['Mouth_Cavity']
    mesh=head.data
    mesh.calc_loop_triangles()
    basis=[p.co.copy() for p in mesh.shape_keys.key_blocks['Basis'].data]
    smile=[p.co.copy() for p in mesh.shape_keys.key_blocks['Smile'].data]
    lip_triangles=[]
    for tri in mesh.loop_triangles:
        a,b,c=(basis[i] for i in tri.vertices)
        centre=(a+b+c)/3
        if abs(centre.x)<3.5 and 158.3<centre.y<160.7 and centre.z>8.8:
            lip_triangles.append(tuple(tri.vertices))
    flips=0
    for a,b,c in lip_triangles:
        normal0=(basis[b]-basis[a]).cross(basis[c]-basis[a])
        normal1=(smile[b]-smile[a]).cross(smile[c]-smile[a])
        flips+=int(normal0.dot(normal1)<0)
    mouth_tree=tree(dental.data,[v.co.copy() for v in dental.data.vertices])
    cavity_tree=tree(cavity.data,[v.co.copy() for v in cavity.data.vertices])
    counts={}
    positions_by_name=[('Basis',basis)]
    for name,amount in [('Quarter',.25),('Half',.5),('ThreeQuarter',.75)]:
        positions_by_name.append((name,[a.lerp(b,amount) for a,b in zip(basis,smile)]))
    positions_by_name.append(('Smile',smile))
    for name,positions in positions_by_name:
        skin=tree(mesh,positions)
        dental_visible=cavity_visible=0
        for i in range(161):
            for j in range(61):
                origin=Vector((-3.2+i*.04,158.3+j*.04,30))
                h,_,_,_=skin.ray_cast(origin,Vector((0,0,-1)))
                t,_,_,_=mouth_tree.ray_cast(origin,Vector((0,0,-1)))
                c,_,_,_=cavity_tree.ray_cast(origin,Vector((0,0,-1)))
                dental_visible+=int(t is not None and (h is None or t.z>h.z+.005))
                cavity_visible+=int(c is not None and (h is None or c.z>h.z+.005))
        counts[name]={'teeth':dental_visible,'cavity':cavity_visible}
    return {'identity':identity,'frontal_lip_triangles':len(lip_triangles),
            'inverted_smile_lip_triangles':flips,'visibility_samples':counts}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--players',nargs='+',default=['robbie_roden','david_murray'],
                        choices=['robbie_roden','david_murray'])
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for identity in args.players:
        result=report(identity)
        assert result['inverted_smile_lip_triangles']==0,result
        samples=result['visibility_samples']
        assert samples['Basis']['teeth']==0 and samples['Basis']['cavity']<=1,result
        assert samples['Smile']['teeth']>100 and samples['Smile']['cavity']>100,result
        print('ORAL_V2_AUDIT',json.dumps(result),flush=True)


if __name__=='__main__':main()
