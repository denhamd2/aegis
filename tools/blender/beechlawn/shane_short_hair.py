"""Offline short-crop cards and root coverage; one glTF MASK material.

The alpha threshold is expressed in nodes so Blender's glTF exporter detects
MASK directly. No post-export JSON patch, blended sorting or runtime groom.
"""
import math
import random
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from shane_player_finish import bound_mesh, hairline, image_from_array, image_node, smoothstep


def hair_atlas(material):
    rng=np.random.default_rng(218)
    yy,xx=np.mgrid[0:512,0:512]
    atlas=np.ones((512,512,4),dtype=np.float32)
    variation=(np.sin(xx*2.1+np.sin(yy*.09))* .008+rng.normal(0,.003,(512,512)))
    for c,base in enumerate((.12,.064,.032)):
        atlas[:,:,c]=np.clip(base+variation,0,1)
    atlas[:256,:,3]=0
    for slot in range(8):
        for strand in range(28):
            root=6+strand*52/27+rng.uniform(-.7,.7)
            length=rng.uniform(.66,1.0)
            phase=rng.uniform(0,math.tau)
            pigment=rng.uniform(.9,1.1)
            for y in range(int(255*length)):
                t=y/255
                centre=slot*64+root+math.sin(t*3.5+phase)*1.4+(31-root)*t*t*.28
                width=(.9-.45*t)*min(1,(length-t)*35)
                lo=max(slot*64,int(centre-width-1)); hi=min((slot+1)*64,int(centre+width+2))
                for x in range(lo,hi):
                    alpha=max(0,min(1,width+.5-abs(x-centre)))
                    if alpha>atlas[y,x,3]:
                        atlas[y,x,:3]=np.array([.12,.064,.032])*pigment
                        atlas[y,x,3]=alpha
    tex=image_node(material,image_from_array("shane_short_crop_cards_rgba",atlas),"Base Color")
    bsdf=material.node_tree.nodes["Principled BSDF"]
    threshold=material.node_tree.nodes.new("ShaderNodeMath")
    threshold.operation="GREATER_THAN"; threshold.inputs[1].default_value=.35
    material.node_tree.links.new(tex.outputs["Alpha"],threshold.inputs[0])
    material.node_tree.links.new(threshold.outputs[0],bsdf.inputs["Alpha"])
    material.surface_render_method="DITHERED"
    bsdf.inputs["Roughness"].default_value=.76
    bsdf.inputs["Specular IOR Level"].default_value=.18
    # The opaque root half receives only very fine directional relief.
    normal=np.stack((.5+np.sin(xx*1.8+np.sin(yy*.07))*.02,
                     .5+np.cos(xx*.5+yy*.12)*.008,np.ones_like(xx)),axis=2)
    nt=material.node_tree.nodes.new("ShaderNodeTexImage")
    nt.image=image_from_array("shane_crop_strand_normal",normal,"Non-Color")
    node=material.node_tree.nodes.new("ShaderNodeNormalMap");node.inputs["Strength"].default_value=.3
    material.node_tree.links.new(nt.outputs["Color"],node.inputs["Color"])
    material.node_tree.links.new(node.outputs["Normal"],bsdf.inputs["Normal"])


def build_short_crop(head,rig,material):
    for obj in list(bpy.data.objects):
        if obj.name.startswith("Hair_Crop_Fit"):
            bpy.data.objects.remove(obj,do_unlink=True)
    source=head.data
    polygons=[list(p.vertices) for p in source.polygons if p.center.y>=hairline(p.center)-.35
              and (abs(p.center.x)<8.2 or p.center.y>171)]
    ids=sorted({i for face in polygons for i in face}); remap={v:i for i,v in enumerate(ids)}
    surface=BVHTree.FromPolygons([v.co for v in source.vertices],[list(p.vertices) for p in source.polygons])
    edges={}
    for face in polygons:
        for a,b in zip(face,face[1:]+face[:1]):
            key=tuple(sorted((a,b)));edges[key]=edges.get(key,0)+1
    boundary={i for edge,n in edges.items() if n==1 for i in edge}
    vertices=[]
    for i in ids:
        p=source.vertices[i].co.copy()
        if i in boundary:
            p.y=hairline(p)
            near,_,_,_=surface.find_nearest(p)
            if near is not None:p=near
        p+=source.vertices[i].normal*(.09+.22*smoothstep(169,178,p.y))
        vertices.append(p)
    uv=[(.5+math.atan2(p.x,p.z+1)/math.tau,.52+.46*max(0,min(1,(p.y-160)/20))) for p in vertices]
    cap=bound_mesh("Hair_Shane_ShortCropRoots",vertices,[[remap[i] for i in f] for f in polygons],rig,material,uvs=uv)
    cap.data.calc_loop_triangles(); triangles=list(cap.data.loop_triangles)
    top=[t for t in triangles if sum(cap.data.vertices[i].co.y for i in t.vertices)/3>171]
    sides=[t for t in triangles if t not in top]
    rng=random.Random(218);vertices=[];faces=[];uvs=[]
    for index in range(168):
        tri=rng.choice(top if index<120 or not sides else sides)
        a,b,c=[cap.data.vertices[i].co for i in tri.vertices]
        r=math.sqrt(rng.random());t=rng.random();root=a*(1-r)+b*(r*(1-t))+c*r*t
        _,normal,_,_=surface.find_nearest(root)
        is_top=root.y>171
        flow=Vector((-.7,.16,.85)) if is_top else Vector((-.1*root.x,-.85,-.35))
        tangent=(flow-normal*flow.dot(normal)).normalized()
        across=normal.cross(tangent).normalized()
        length=rng.uniform(1.15,2.1) if is_top else rng.uniform(.45,.85)
        width=rng.uniform(.33,.62) if is_top else rng.uniform(.2,.38)
        slot=index%8;start=len(vertices)
        for row in range(7):
            f=row/6
            # Bury roots in the opaque scalp so rectangular card bases do not
            # sit on top like patches; only curved strand tips emerge.
            centre=root+tangent*length*f+normal*(-.12*(1-f)+.18*math.sin(math.pi*f))
            for column in (-1,0,1):
                vertices.append(centre+across*width*.5*column+normal*width*.06*(1-abs(column)))
                uvs.append(((slot*64+2+(column+1)*.5*60)/512,.003+f*.491))
        for row in range(6):
            for column in range(2):
                n=start+row*3+column;faces.append((n+3,n+4,n+1,n))
    cards=bound_mesh("Hair_Shane_ShortCropCards",vertices,faces,rig,material,uvs=uvs)
    # Share the scalp's shading direction instead of lighting every strip as
    # a separate flat plate. Geometry, pigment and alpha still define strands.
    normals=[]
    for p in vertices:
        _,normal,_,_=surface.find_nearest(p);normals.append(normal)
    cards.data.normals_split_custom_set_from_vertices(normals)
    hair_atlas(material)
    print("SHANE_SHORT_CROP",168,"alpha_test_cards",len(faces)*2,"card_triangles")
    return cap,cards
