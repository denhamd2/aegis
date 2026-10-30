"""Experimental actual lip opening on Robbie's saved source mesh.

The prototype retains vertex order, UVs, weights and shape keys while removing
only selected front-facing bridge faces. It writes solely to ignored build.
"""
from pathlib import Path
import math
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE))
import shane_player_finish
from shane_player_finish import bound_mesh
from pilot_br022_oral_v2 import fit_smile,build_crowns,build_cavity,ease
from player_head_groom import build_groom
from author_four_head_finish import render


def build_lips(head, rig):
    """An anatomical two-lip strip covers the cut edge and deforms with Smile."""
    mesh=head.data
    mesh.calc_loop_triangles()
    positions=[v.co.copy() for v in mesh.vertices]
    surface=BVHTree.FromPolygons(positions,[list(poly.vertices) for poly in mesh.polygons])
    triangles={}
    for tri in mesh.loop_triangles:
        triangles.setdefault(tri.polygon_index,[]).append(tri)

    def skin_at(x,y):
        hit,_,poly_index,_=surface.ray_cast(Vector((x,y,30)),Vector((0,0,-1)))
        if hit is None:return 9.8,(.5,.5)
        triangle=min(triangles[poly_index],key=lambda tri:
                     (sum((positions[i] for i in tri.vertices),Vector())/3-hit).length)
        a,b,c=(positions[i] for i in triangle.vertices)
        v0=b-a;v1=c-a;v2=hit-a
        d00=v0.dot(v0);d01=v0.dot(v1);d11=v1.dot(v1)
        d20=v2.dot(v0);d21=v2.dot(v1);den=d00*d11-d01*d01
        if abs(den)<1e-10:return hit.z,(.5,.5)
        wb=(d11*d20-d01*d21)/den;wc=(d00*d21-d01*d20)/den;wa=1-wb-wc
        uv=[mesh.uv_layers.active.data[i].uv for i in triangle.loops]
        value=uv[0]*wa+uv[1]*wb+uv[2]*wc
        return hit.z,tuple(value)

    columns=29;rows=4;vertices=[];faces=[];uvs=[];smile=[]
    for upper in (True,False):
        start=len(vertices)
        for col in range(columns):
            fraction=col/(columns-1)
            x=-3.35+6.70*fraction
            ax=abs(x)
            envelope=max(0,math.sin(math.pi*fraction))**.55
            rise=.10*(ax/3.35)**2
            for row in range(rows):
                t=row/(rows-1)
                if upper:
                    y=(159.72+rise)*(1-t)+(159.14+rise)*t
                    smile_y=y+(.08+.30*t)*envelope+.28*(ax/3.35)**3
                else:
                    y=(159.10+rise)*(1-t)+(158.55+rise)*t
                    smile_y=y-(.19-.08*t)*envelope+.28*(ax/3.35)**3
                z,uv=skin_at(x,y)
                lift=(.025+.10*math.sin(math.pi*t))*envelope
                vertices.append(Vector((x,y,z+lift)))
                uvs.append(uv)
                new_z,_=skin_at(x,smile_y)
                smile.append(Vector((x,smile_y,new_z+lift+.035*envelope)))
        for col in range(columns-1):
            for row in range(rows-1):
                a=start+col*rows+row
                b=start+(col+1)*rows+row
                faces.append((a,a+1,b+1,b))
    obj=bound_mesh('Mouth_Lips',vertices,faces,rig,mesh.materials[0],uvs=uvs)
    obj.shape_key_add(name='Basis')
    key=obj.shape_key_add(name='Smile')
    for point,value in zip(key.data,smile):point.co=value
    return obj


def open_mouth(head):
    old=head.data
    keys=old.shape_keys.key_blocks
    old.calc_loop_triangles()
    verts=[v.co.copy() for v in old.vertices]
    group_names=[group.name for group in head.vertex_groups]
    weights=[[(g.group,g.weight) for g in v.groups] for v in old.vertices]
    retained=[];removed=[]
    for poly in old.polygons:
        centre=poly.center
        if (abs(centre.x)<3.1 and 158.94<centre.y<159.35
                and centre.z>9.48 and poly.normal.z>.04):
            removed.append(poly.index)
        else:retained.append(poly.index)
    assert 15<len(removed)<250,('Unexpected mouth face selection',len(removed))
    new=bpy.data.meshes.new('Skin_Head_OralTopology')
    new.from_pydata(verts,[],[list(old.polygons[i].vertices) for i in retained])
    new.update()
    for material in old.materials:new.materials.append(material)
    source_uv=old.uv_layers.active
    target_uv=new.uv_layers.new(name=source_uv.name)
    for new_poly,old_i in zip(new.polygons,retained):
        source_poly=old.polygons[old_i]
        new_poly.use_smooth=source_poly.use_smooth
        new_poly.material_index=source_poly.material_index
        for new_loop,source_loop in zip(new_poly.loop_indices,source_poly.loop_indices):
            target_uv.data[new_loop].uv=source_uv.data[source_loop].uv
    values={key.name:[p.co.copy() for p in key.data] for key in keys}
    head.data=new
    head.vertex_groups.clear()
    for name in group_names:head.vertex_groups.new(name=name)
    for index,groups in enumerate(weights):
        for group,weight in groups:
            head.vertex_groups[group].add([index],weight,'REPLACE')
    for name,positions in values.items():
        shape=head.shape_key_add(name=name)
        for p,value in zip(shape.data,positions):p.co=value
    bm=bmesh.new();bm.from_mesh(new)
    boundary=[e for e in bm.edges if e.is_boundary and all(abs(v.co.x)<4.5 and 158<v.co.y<161 for v in e.verts)]
    mouth_vertices={v.index for edge in boundary for v in edge.verts}
    bm.free()
    shape_keys=new.shape_keys.key_blocks
    for index in mouth_vertices:
        basis=shape_keys['Basis'].data[index].co
        ax=abs(basis.x)
        upper=basis.y>=159.14
        centre_y=159.11+.08*(ax/3.2)**2
        half_gap=.025*(1-ease(2.45,3.2,ax))
        target=centre_y+(half_gap if upper else -half_gap)
        shift=target-basis.y
        for name in ('Basis','Blink','Fullness'):
            shape_keys[name].data[index].co.y+=shift
        new.vertices[index].co=shape_keys['Basis'].data[index].co
    new.update()
    print('ORAL_CUT',len(removed),'faces',len(boundary),'mouth boundary edges',flush=True)
    return len(removed),len(boundary)


def main():
    identity='robbie_roden'
    bpy.ops.wm.open_mainfile(filepath=str(HERE/(identity+'_head.blend')))
    head=bpy.data.objects['Skin_Head'];rig=bpy.data.objects['YBot_Armature']
    fit_smile(head,identity,recess_depth=0)
    lips=build_lips(head,rig)
    open_mouth(head)
    build_crowns(rig,identity)
    build_cavity(rig,identity)
    output=ROOT/'games/beechlawn_rovers/build/br022_topology_mouth'/identity
    shane_player_finish.TEXTURES=output/'temporary_textures'
    shane_player_finish.TEXTURES.mkdir(parents=True,exist_ok=True)
    build_groom(head,rig,identity)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(output/'topology_mouth.blend'),compress=True)
    render(head,output/'neutral',views=('front','threequarter'))
    head.data.shape_keys.key_blocks['Smile'].value=1
    lips.data.shape_keys.key_blocks['Smile'].value=1
    render(head,output/'smile',views=('front','threequarter'))


if __name__=='__main__':main()
