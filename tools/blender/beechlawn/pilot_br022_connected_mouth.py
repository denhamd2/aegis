"""Connected lip-loop prototype on the saved Robbie/David sources.

Writes disposable editable sources and renders only. It does not modify a
shipping head. The new annular lip surface shares vertices with the face.
"""
import argparse
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE))
import shane_player_finish
from pilot_br022_oral_v2 import fit_smile,build_crowns,build_cavity
from pilot_br022_topology_mouth import open_mouth
from player_head_groom import build_groom
from author_four_head_finish import render


def lip_loops(head):
    old=head.data
    bm=bmesh.new();bm.from_mesh(old)
    edges=[e for e in bm.edges if e.is_boundary and all(abs(v.co.x)<4.5 and 158<v.co.y<161 for v in e.verts)]
    adjacency={}
    for edge in edges:
        a,b=(v.index for v in edge.verts)
        adjacency.setdefault(a,[]).append(b)
        adjacency.setdefault(b,[]).append(a)
    assert len(edges)==len(adjacency) and all(len(v)==2 for v in adjacency.values())
    first=min(adjacency,key=lambda i:old.vertices[i].co.x)
    ring=[first]
    previous=-1
    while True:
        choices=[i for i in adjacency[ring[-1]] if i!=previous]
        following=choices[0]
        if following==first:break
        assert following not in ring
        previous,following=ring[-1],following
        ring.append(following)
    if len(ring)!=len(edges):
        print('BOUNDARY_COMPONENT',len(ring),len(edges),flush=True)
    assert len(ring)==len(edges)
    area=sum(old.vertices[a].co.x*old.vertices[b].co.y-old.vertices[b].co.x*old.vertices[a].co.y
             for a,b in zip(ring,ring[1:]+ring[:1]))
    if area<0:ring.reverse()
    bm.free()

    source_keys=old.shape_keys.key_blocks
    original={key.name:[p.co.copy() for p in key.data] for key in source_keys}
    key_names=list(original)
    old_vertices=[v.co.copy() for v in old.vertices]
    old_faces=[tuple(poly.vertices) for poly in old.polygons]
    old_smooth=[poly.use_smooth for poly in old.polygons]
    old_material=[poly.material_index for poly in old.polygons]
    old_uv=old.uv_layers.active
    uv_per_face=[[old_uv.data[loop].uv.copy() for loop in poly.loop_indices] for poly in old.polygons]
    uv_vertex={}
    for poly,uvs in zip(old.polygons,uv_per_face):
        for index,uv in zip(poly.vertices,uvs):uv_vertex.setdefault(index,uv)
    centre_uv=sum((uv_vertex[i] for i in ring),Vector((0,0)))/len(ring)
    groups=[[(g.group,g.weight) for g in v.groups] for v in old.vertices]
    group_names=[g.name for g in head.vertex_groups]
    materials=list(old.materials)

    center=159.17
    max_x=max(abs(old_vertices[i].x) for i in ring)
    ring_count=4
    positions={name:[p.copy() for p in values] for name,values in original.items()}
    ring_indices=[]
    ring_uv=[]
    for level in range(1,ring_count+1):
        t=level/ring_count
        indices=[];uvs=[]
        for index in ring:
            source=original['Basis'][index]
            sign=1 if source.y>=center else -1
            x_norm=min(1,abs(source.x)/max_x)
            envelope=max(0,1-x_norm*x_norm)**.58
            x=source.x*(1-.05*t)
            slit=center+sign*.018*envelope
            basis=Vector((x,source.y*(1-t)+slit*t,
                          source.z+(.14*math.sin(math.pi*t)-.16*t)))
            smile_center=center+.25*x_norm**3
            smile_gap=(.51 if sign>0 else .32)*envelope
            target=smile_center+sign*smile_gap
            source_smile=original['Smile'][index]
            smile=Vector((x+(source_smile.x-source.x)*(1-t),
                          source_smile.y*(1-t)+target*t,
                          source_smile.z+(.14*math.sin(math.pi*t)-.16*t)))
            indices.append(len(positions['Basis']))
            for name in key_names:
                if name=='Basis':value=basis
                elif name=='Smile':value=smile
                else:value=basis+(original[name][index]-source)*(1-t)
                positions[name].append(value)
            groups.append(groups[index][:])
            uvs.append(uv_vertex[index].lerp(centre_uv,.45*t))
        ring_indices.append(indices)
        ring_uv.append(uvs)

    faces=old_faces[:]
    face_uv=uv_per_face[:]
    previous=ring
    previous_uv=[uv_vertex[index] for index in ring]
    for current,current_uv in zip(ring_indices,ring_uv):
        for j in range(len(ring)):
            next_j=(j+1)%len(ring)
            faces.append((previous[j],previous[next_j],current[next_j],current[j]))
            face_uv.append([previous_uv[j],previous_uv[next_j],current_uv[next_j],current_uv[j]])
        previous=current;previous_uv=current_uv

    mesh=bpy.data.meshes.new('Skin_Head_ConnectedMouth')
    mesh.from_pydata(positions['Basis'],[],faces)
    mesh.update()
    for material in materials:mesh.materials.append(material)
    uv=mesh.uv_layers.new(name=old_uv.name)
    for p,coords in zip(mesh.polygons,face_uv):
        for loop,point in zip(p.loop_indices,coords):uv.data[loop].uv=point
    for poly,smooth,material in zip(mesh.polygons,old_smooth,old_material):
        poly.use_smooth=smooth;poly.material_index=material
    for poly in list(mesh.polygons)[len(old_faces):]:poly.use_smooth=True
    head.data=mesh
    head.vertex_groups.clear()
    for name in group_names:head.vertex_groups.new(name=name)
    for index,weights in enumerate(groups):
        for group,weight in weights:head.vertex_groups[group].add([index],weight,'REPLACE')
    for name in key_names:
        key=head.shape_key_add(name=name)
        for item,value in zip(key.data,positions[name]):item.co=value
    for v,p in zip(mesh.vertices,positions['Basis']):v.co=p
    mesh.update()
    assert len(mesh.vertices)==len(old_vertices)+ring_count*len(ring)
    assert len(mesh.polygons)==len(old_faces)+ring_count*len(ring)
    bm=bmesh.new();bm.from_mesh(mesh)
    lip_boundary=[e for e in bm.edges if e.is_boundary and all(abs(v.co.x)<4.5 and 158<v.co.y<161 for v in e.verts)]
    assert len(lip_boundary)==len(ring)
    bm.free()
    print('CONNECTED_MOUTH',len(ring),'boundary vertices',len(mesh.vertices),'total vertices',flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--players',nargs='+',default=['robbie_roden','david_murray'])
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for identity in args.players:
        assert identity in ('robbie_roden','david_murray')
        bpy.ops.wm.open_mainfile(filepath=str(HERE/(identity+'_head.blend')))
        head=bpy.data.objects['Skin_Head'];rig=bpy.data.objects['YBot_Armature']
        fit_smile(head,identity,recess_depth=0)
        open_mouth(head,collapse_boundary=False,broad=True)
        lip_loops(head)
        build_crowns(rig,identity)
        build_cavity(rig,identity)
        out=ROOT/'games/beechlawn_rovers/build/br022_connected_mouth'/identity
        out.mkdir(parents=True,exist_ok=True)
        shane_player_finish.TEXTURES=out/'temporary_textures'
        shane_player_finish.TEXTURES.mkdir(parents=True,exist_ok=True)
        build_groom(head,rig,identity)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(out/'connected_mouth.blend'),compress=True)
        render(head,out/'neutral',views=('front','threequarter'))
        head.data.shape_keys.key_blocks['Smile'].value=1
        render(head,out/'smile',views=('front','threequarter'))


if __name__=='__main__':main()
