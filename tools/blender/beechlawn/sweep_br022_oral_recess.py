"""Find an oral recess that exposes teeth without inverted lip triangles."""
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE))
from pilot_br022_oral_v2 import fit_smile,build_crowns

bpy.ops.wm.open_mainfile(filepath=str(HERE/'robbie_roden_head.blend'))
head=bpy.data.objects['Skin_Head'];mesh=head.data
keys=mesh.shape_keys.key_blocks
original=[p.co.copy() for p in keys['Smile'].data]
basis=[p.co.copy() for p in keys['Basis'].data]
mesh.calc_loop_triangles()
faces=[tuple(p.vertices) for p in mesh.polygons]
tris=[]
for tri in mesh.loop_triangles:
    a,b,c=(basis[i] for i in tri.vertices)
    centre=(a+b+c)/3
    if abs(centre.x)<3.5 and 158.3<centre.y<160.7 and centre.z>8.8:
        tris.append(tuple(tri.vertices))
dental=build_crowns(bpy.data.objects['YBot_Armature'],'robbie_roden')
teeth=BVHTree.FromPolygons([v.co.copy() for v in dental.data.vertices],
                           [list(p.vertices) for p in dental.data.polygons])
samples=[]
for i in range(81):
    for j in range(41):
        origin=Vector((-3.2+i*.08,158.3+j*.06,30))
        t,_,_,_=teeth.ray_cast(origin,Vector((0,0,-1)))
        if t is not None:samples.append((origin,t.z))
result=[]
for depth in (.50,.60,.70,.80,.90,1.0):
    for width in (1.0,):
        for point,value in zip(keys['Smile'].data,original):point.co=value
        fit_smile(head,'robbie_roden',recess_depth=depth,recess_width=width,
                  recess_x=3.3,recess_power=2,recess_profile='plateau')
        points=[p.co.copy() for p in keys['Smile'].data]
        flips=0
        for a,b,c in tris:
            normal0=(basis[b]-basis[a]).cross(basis[c]-basis[a])
            normal1=(points[b]-points[a]).cross(points[c]-points[a])
            flips+=int(normal0.dot(normal1)<0)
        skin=BVHTree.FromPolygons(points,faces)
        visible=0
        for origin,z in samples:
            h,_,_,_=skin.ray_cast(origin,Vector((0,0,-1)))
            visible+=int(h is None or z>h.z+.005)
        entry={'depth':depth,'width':width,'flips':flips,'teeth_visible':visible}
        result.append(entry);print('SWEEP',entry,flush=True)
out=ROOT/'games/beechlawn_rovers/build/br022_oral_v2/sweep.json'
out.write_text(json.dumps(result,indent=2)+'\n')
