"""Original, small oral geometry for the photographed Shane smile.

Neutral head topology/neck remain unchanged. Teeth sit behind closed lips and
are skinned to the existing head bone; no second runtime rig is needed.
"""
import bpy
import bmesh
import heapq
import math
from mathutils import Vector


def upper_lip_weights(head):
    """Geodesic lip membership on the fingerprint-protected production cage.

    Its upper/lower folded contact loops overlap in height. Classifying by Y
    moves both lips together; follow topology around the oral opening instead.
    These centre-line cohorts belong to this 4326-vertex master revision.
    """
    mesh=head.data
    assert len(mesh.vertices)==4326,'Transfer oral landmarks after topology changes'
    upper=(362,455,466,467,509,468,474,520,537,554,571,588)
    lower=(496,495,513,494,493,523,540,557)
    region={v.index for v in mesh.vertices if abs(v.co.x)<5.0 and 157<v.co.y<162.2 and v.co.z>8.4}
    assert set(upper+lower)<=region
    neighbours={i:[] for i in region}
    for edge in mesh.edges:
        a,b=edge.vertices
        if a in region and b in region:
            length=(mesh.vertices[a].co-mesh.vertices[b].co).length
            neighbours[a].append((b,length));neighbours[b].append((a,length))
    def distances(seeds):
        result={i:math.inf for i in region};queue=[]
        for i in seeds:result[i]=0;heapq.heappush(queue,(0,i))
        while queue:
            length,i=heapq.heappop(queue)
            if length>result[i]:continue
            for j,cost in neighbours[i]:
                candidate=length+cost
                if candidate<result[j]:result[j]=candidate;heapq.heappush(queue,(candidate,j))
        return result
    a,b=distances(upper),distances(lower)
    return {i:b[i]/(a[i]+b[i]) for i in region if math.isfinite(a[i]+b[i]) and a[i]+b[i]>1e-8}


def build_upper_teeth(rig, identity='shane_denham'):
    from shane_player_finish import bound_mesh
    name='Mouth_UpperTeeth'
    old=bpy.data.objects.get(name)
    if old:bpy.data.objects.remove(old,do_unlink=True)
    material=bpy.data.materials.new('MAT_NaturalEnamel_'+identity)
    material.use_nodes=True
    shader=material.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value=(.57,.53,.45,1)
    shader.inputs['Roughness'].default_value=.31
    shader.inputs['Specular IOR Level'].default_value=.30
    vertices=[];faces=[]
    # Central/lateral incisors and canines: a gently curved dental arcade,
    # slightly varied heights and warm enamel, rather than a white strip.
    for x,width,height in ((-2.46,.56,.57),(-1.87,.60,.66),(-1.22,.64,.68),(-.44,.80,.73),
                           (.39,.80,.72),(1.17,.64,.67),(1.82,.60,.64),(2.41,.56,.56)):
        mesh=bmesh.new()
        bmesh.ops.create_cube(mesh,size=1)
        for vertex in mesh.verts:
            vertex.co=Vector((vertex.co.x*width,vertex.co.y*height,vertex.co.z*.34))
        bmesh.ops.bevel(mesh,geom=list(mesh.edges),offset=.055,segments=2,affect='EDGES')
        mesh.verts.ensure_lookup_table();mesh.verts.index_update()
        start=len(vertices)
        centre=Vector((x,159.76+(height-.65)*.2,9.70-.045*x*x))
        vertices.extend(vertex.co+centre for vertex in mesh.verts)
        faces.extend(tuple(start+vertex.index for vertex in face.verts) for face in mesh.faces)
        mesh.free()
    result=bound_mesh(name,vertices,faces,rig,material)
    result['oral_policy']='Fitted original upper dental arcade; occluded in neutral, visible with the photographed smile'
    return result
