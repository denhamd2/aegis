"""Repair the current shared garment in place; never regenerate the player.

blender -b --python tools/blender/beechlawn/repair_shared_kit.py -- --apply
Read-only unless --apply. Keeps head meshes, rig rest and all action curves.
"""
from pathlib import Path
import bpy, bmesh, hashlib, json, math, sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
ROOT=Path(__file__).resolve().parents[3]
SOURCE=ROOT/'tools/blender/beechlawn/footballer_shared.blend'
EXPORT=ROOT/'games/beechlawn_rovers/assets/characters/shared/footballer_base.glb'
REPORT=ROOT/'games/beechlawn_rovers/docs/art_briefs/shared_kit_repair/validation.json'

def export_current(rig):
    rig.animation_data.action=bpy.data.actions['AN_Beechlawn_Idle'];bpy.context.scene.frame_set(1)
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    bpy.ops.object.select_all(action='DESELECT')
    for o in bpy.context.scene.objects:
        if o==rig or o.type=='MESH':o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(EXPORT),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_cameras=False,export_lights=False,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_influence_nb=4,export_leaf_bone=False,export_rest_position_armature=True)

def digest_retained(rig):
    data=[('rest',[(b.name,list(map(list,b.matrix_local))) for b in rig.data.bones])]
    for a in sorted(bpy.data.actions,key=lambda a:a.name):
        data.append((a.name,[(f.data_path,f.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in f.keyframe_points]) for f in a.fcurves]))
    for name in ('Skin_Head','YBot_Joints','Eye_l','Eye_r','Skin_Hands','Kit_Shorts','Kit_Socks'):
        o=bpy.data.objects[name]
        data.append((name,[tuple(v.co) for v in o.data.vertices],[[tuple(o.data.uv_layers.active.data[i].uv) for i in p.loop_indices] for p in o.data.polygons],[[ (o.vertex_groups[g.group].name,g.weight) for g in v.groups] for v in o.data.vertices]))
    return hashlib.sha256(repr(data).encode()).hexdigest()

def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)

def garment_loop(obj):
    bm=bmesh.new();bm.from_mesh(obj.data);bm.verts.ensure_lookup_table()
    es=[e for e in bm.edges if e.is_boundary and all(v.co.y>140 and abs(v.co.x)<14 for v in e.verts)]
    adj={}
    for e in es:
        a,b=[v.index for v in e.verts];adj.setdefault(a,[]).append(b);adj.setdefault(b,[]).append(a)
    start=min(adj);loop=[start];prev=-1;cur=start
    while True:
        nxt=next(i for i in adj[cur] if i!=prev)
        if nxt==start:break
        loop.append(nxt);prev,cur=cur,nxt
    bm.free();assert len(loop)==96,len(loop)
    return loop

def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE));rig=bpy.data.objects['YBot_Armature']
    if rig.get('kit_repair_revision')==1:
        if '--export-only' in sys.argv:
            bpy.data.objects['Kit_Shane_ContinuousVBinding'].data.uv_layers[0].name='JerseyUV'
            export_current(rig)
        print('KIT_REPAIR already applied');return
    retained=digest_retained(rig)
    rig.animation_data.action=None
    for p in rig.pose.bones:p.matrix_basis.identity()
    bpy.context.view_layer.update()
    # A single skin reference for the exposed neck. It is inspected, never edited.
    points=[];faces=[];weights=[]
    for name in ('Skin_Head','YBot_Joints'):
        o=bpy.data.objects[name];offset=len(points)
        points += [v.co.copy() for v in o.data.vertices]
        weights += [{o.vertex_groups[g.group].name:g.weight for g in v.groups} for v in o.data.vertices]
        for p in o.data.polygons:
            if all(138<v.co.y<155 for v in [o.data.vertices[i] for i in p.vertices]):
                ids=list(p.vertices)
                faces += [(offset+ids[0],offset+ids[j],offset+ids[j+1]) for j in range(1,len(ids)-1)]
    tree=BVHTree.FromPolygons(points,faces,all_triangles=True)
    report={'preserved_sha256':retained,'bones':len(rig.data.bones),'clips':len(bpy.data.actions),'garments':{}}
    for name in ('YBot_Surface','Kit_Shirt_ShortSleeve'):
        o=bpy.data.objects[name];bm=bmesh.new();bm.from_mesh(o.data)
        # The old neck cut left a disconnected 33-vertex throat scrap. Its
        # extra collar ring intersected the neck and made a dark triangular tab.
        left=set(bm.verts);small=[]
        while left:
            q=[left.pop()];part=[]
            while q:
                v=q.pop();part.append(v)
                for e in v.link_edges:
                    w=e.other_vert(v)
                    if w in left:left.remove(w);q.append(w)
            if len(part)<100:small+=part
        assert len(small)==33,len(small)
        bmesh.ops.delete(bm,geom=small,context='VERTS')
        # Relax the inflated deltoid caps locally; preserve panel UV corners,
        # cuffs, torso graphics and the actual neckline boundary.
        for _ in range(7):
            positions={v:sum((e.other_vert(v).co for e in v.link_edges),Vector())/len(v.link_edges) for v in bm.verts if v.link_edges and not v.is_boundary and 12<abs(v.co.x)<31 and v.co.y>137}
            for v,average in positions.items():
                strength=.35*smooth(137,144,v.co.y)*(1-smooth(27,31,abs(v.co.x)))
                v.co=v.co.lerp(average,strength)
        bm.to_mesh(o.data);bm.free();o.data.update()
        changed=0;max_shift=0
        for v in o.data.vertices:
            x,y,z=v.co
            if y<142 or abs(x)>15:continue
            near,normal,index,distance=tree.find_nearest(v.co)
            if near is None:continue
            influence=smooth(142,146,y)*(1-smooth(10,15,abs(x)))
            # Keep at least 3 mm of actual cloth clearance at the neck sides.
            clearance=(v.co-near).dot(normal)
            if clearance<.3 and distance<3.5:
                shift=normal*(.3-clearance)*influence
                v.co+=shift;max_shift=max(max_shift,shift.length);changed+=1
            if distance<4 and influence>.01:
                ids=faces[index];a,b,c=[points[i] for i in ids]
                bary=barycentric_transform(near,a,b,c,Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1)))
                skin={}
                for j,factor in zip(ids,bary):
                    for n,w in weights[j].items():skin[n]=skin.get(n,0)+w*max(0,factor)
                current={o.vertex_groups[g.group].name:g.weight for g in v.groups}
                merged={n:current.get(n,0)*(1-influence)+skin.get(n,0)*influence for n in current.keys()|skin.keys()}
                top=sorted(merged.items(),key=lambda p:p[1],reverse=True)[:4];total=sum(w for _,w in top)
                for group in o.vertex_groups:group.remove([v.index])
                for n,w in top:
                    if w>1e-6:o.vertex_groups[n].add([v.index],w/total,'REPLACE')
        o.data.update()
        report['garments'][name]={'removed_throat_scrap_vertices':33,'clearance_vertices':changed,'max_clearance_shift_cm':round(max_shift,4)}
    # Rebuild the narrow black/blue binding only on the real neckline. Reuse
    # atlas patches and the garment's exact boundary weights for coherent bends.
    shirt=bpy.data.objects['YBot_Surface'];binding=bpy.data.objects['Kit_Shane_ContinuousVBinding']
    loop=garment_loop(shirt);count=len(loop);verts=[];quads=[];uvs=[]
    layout=json.loads((ROOT/'games/beechlawn_rovers/assets/characters/textures/beechlawn_home_tailored_atlas_layout.json').read_text())['rects']
    patches=[]
    for region in ('black','blue','black'):
        x0,y0,x1,y1=layout[region]
        patches.append([((x0+u*(x1-x0))/2048,1-(y1-v*(y1-y0))/2048) for u,v in ((.2,.2),(.8,.2),(.8,.8),(.2,.8))])
    for ring,t in enumerate((0,.17,.34,1)):
        for i in loop:
            p=shirt.data.vertices[i].co.copy();radial=Vector((p.x,0,p.z+2.72)).normalized()
            # Inner edge meets the cloth, outer edge sinks into its surface.
            p+=radial*(.08+.57*t)+Vector((0,-.65*t,0));verts.append(p)
    for ring in range(3):
        for j in range(count):quads.append((ring*count+j,ring*count+(j+1)%count,(ring+1)*count+(j+1)%count,(ring+1)*count+j));uvs.append(patches[ring])
    mesh=bpy.data.meshes.new('Shared_Collar_Continuous_Repair');mesh.from_pydata(verts,[],quads);mesh.materials.append(binding.data.materials[0]);mesh.update();binding.data=mesh
    layer=mesh.uv_layers.new(name='JerseyUV')
    for poly,coords in zip(mesh.polygons,uvs):
        poly.use_smooth=True
        for li,uv in zip(poly.loop_indices,coords):layer.data[li].uv=uv
    for ring in range(4):
        for j,i in enumerate(loop):
            for g in shirt.data.vertices[i].groups:
                n=shirt.vertex_groups[g.group].name
                group=binding.vertex_groups.get(n) or binding.vertex_groups.new(name=n)
                group.add([ring*count+j],g.weight,'REPLACE')
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    # Prefer outward radial normals on the neckline, not a double-sided patch.
    if sum(f.normal.dot(Vector((f.calc_center_median().x,0,f.calc_center_median().z+2.72))) for f in bm.faces)<0:
        bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
    bm.to_mesh(mesh);bm.free();mesh.update()
    assert digest_retained(rig)==retained,'Protected skin, rig or action changed'
    rig.animation_data.action=bpy.data.actions['AN_Beechlawn_Idle'];bpy.context.scene.frame_set(1)
    report['applied']='--apply' in sys.argv
    if report['applied']:
        rig['kit_repair_revision']=1
        export_current(rig)
        REPORT.parent.mkdir(parents=True,exist_ok=True);REPORT.write_text(json.dumps(report,indent=2)+'\n')
    print('KIT_REPAIR '+json.dumps(report))
if __name__=='__main__':main()
