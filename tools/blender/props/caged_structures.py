"""Blender-authored steel cage / Hell in a Cell visuals, in game metres.
Runtime owns collisions, lowering, door swing and roof-panel release.
Run: blender -b --factory-startup --python tools/blender/props/caged_structures.py
"""
from pathlib import Path
import sys, math, json
import bpy
import numpy as np
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
from match_containers import kit, box, tube
OUT = Path(__file__).resolve().parents[3] / 'game/assets/props'
TEX = OUT / 'textures'


def materials(cell_visuals=False):
    rng = np.random.RandomState(114)
    n = 256
    noise = rng.uniform(-1, 1, (n,n))
    base = np.ones((n,n,3)) * np.array([.55,.58,.61] if cell_visuals else [.69,.72,.75])
    base += noise[...,None] * .014
    orm = np.ones_like(base); orm[...,1] = (.30 if cell_visuals else .38) + noise*(.025 if cell_visuals else .035); orm[...,2] = .80 if cell_visuals else .45
    prefix='cell_steel' if cell_visuals else 'cage_steel'
    kit.save_rgb(base,TEX/(prefix+'_base.png'));kit.save_rgb(orm,TEX/(prefix+'_orm.png'))
    steel=kit.pbr_material('cell_galvanised' if cell_visuals else 'cage_galvanised',TEX/(prefix+'_base.png'),TEX/(prefix+'_orm.png'),None)
    # Round shaded crossed wires, transparent holes; preserve physical repeat.
    from PIL import Image
    yy,xx=np.mgrid[:512,:512]
    # Five whole periods tile cleanly; a96px period in512px would leave seams.
    cell=512. / (5 if cell_visuals else 8)
    profile=.09 if cell_visuals else .19
    du=np.abs(np.mod((xx+yy)/cell,1)-.5)*2
    dv=np.abs(np.mod((xx-yy+2048)/cell,1)-.5)*2
    w=np.maximum(1-(1-du)/profile,1-(1-dv)/profile)
    alpha=np.clip(w*2.2,0,1)
    crown=.75+.25*np.sin(np.clip(w,0,1)*np.pi*.5)
    rgba=np.empty((512,512,4))
    rgba[...,:3]=np.array([.50,.53,.56]) if cell_visuals else np.array([.84,.86,.88])*crown[...,None]
    rgba[...,3]=alpha
    path=TEX/('cell_chainlink.png' if cell_visuals else 'cage_chainlink.png');Image.fromarray((np.clip(rgba,0,1)*255).astype('uint8'),'RGBA').save(path)
    normal_path=None;orm_path=None
    if cell_visuals:
        # Cylindrical strand response in aligned tangent-space normals; no
        # extra wire geometry or baked white shading on the strand bodies.
        height=np.sqrt(np.maximum(0,1-(1-np.clip(w,0,1))**2))
        normal_path=TEX/'cell_wire_normal.png';orm_path=TEX/'cell_wire_orm.png'
        kit.save_rgb(kit.normal_from_height(height,3.0),normal_path)
        packed=np.ones((512,512,3));packed[...,1]=.32+.012*np.cos((xx*16+yy*11)*math.tau/512);packed[...,2]=.65
        kit.save_rgb(packed,orm_path)
    wire=kit.pbr_material('cage_chainlink',path,orm_path,normal_path,normal_strength=.7,
                          roughness=.32 if cell_visuals else .38,metallic=.65 if cell_visuals else .3)
    bs=wire.node_tree.nodes['Principled BSDF'];tex=next(n for n in wire.node_tree.nodes if n.type=='TEX_IMAGE')
    wire.node_tree.links.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
    wire.surface_render_method='DITHERED';wire.use_backface_culling=False
    return steel,wire


def mesh_part(root,part,mat):
    obj=kit.add_mesh(root,part,mat,smooth=True,uv_scale=1.,auto_smooth_deg=50)
    if mat.name=='cell_galvanised':
        weighted=obj.modifiers.new('Manufactured face normals','WEIGHTED_NORMAL')
        weighted.keep_sharp=True;weighted.weight=50
    return obj


def panel(root,name,verts,uv,mat):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([kit.to_blender(Vector(v)) for v in verts],[],[(0,1,2,3)])
    mesh.materials.append(mat);layer=mesh.uv_layers.new(name='UVMap')
    for poly in mesh.polygons:
        for idx in poly.loop_indices:layer.data[idx].uv=uv[mesh.loops[idx].vertex_index]
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.parent=root
    return obj


def build(name,half,base,top,rails,door_axis,dw,dh,roof):
    kit.reset();steel,wire=materials(cell_visuals=roof);scale=2.4 if roof else 1.
    axes=[('PX',Vector((1,0,0))),('NX',Vector((-1,0,0))),('PZ',Vector((0,0,1))),('NZ',Vector((0,0,-1)))]
    h=top-base;span=2*half; roots=[]
    def beam(part,a,b,width):
        a,b=Vector(a),Vector(b);v=b-a
        # Beveled box members, with manufactured junction collars.
        if sum(abs(c)>1e-5 for c in v)==1:
            box(part,(a+b)/2,tuple(abs(c)+width for c in v),min(.005,width*.12))
        else:tube(part,[a,b],width*.5,6)
    def roof_truss(part,a,b):
        a,b=Vector(a),Vector(b);direction=(b-a).normalized()
        side=Vector((0,1,0)).cross(direction);length=(b-a).length
        # Open triangular web under the walking plane, not a solid square bar.
        for off in [-.08,.08]:
            for y in [-.025,-.30]:
                tube(part,[a+side*off+Vector((0,y,0)),b+side*off+Vector((0,y,0))],.022,8)
        count=math.ceil(length/.45)
        for k in range(count):
            for off in [-.08,.08]:
                y0,y1=(-.045,-.28) if k%2==0 else (-.28,-.045)
                tube(part,[a+direction*(length*k/count)+side*off+Vector((0,y0,0)),
                           a+direction*(length*(k+1)/count)+side*off+Vector((0,y1,0))],.010,6)
        size=Vector((abs(direction.x)*length+abs(side.x)*.12,.012,
                     abs(direction.z)*length+abs(side.z)*.12))
        box(part,(a+b)/2+Vector((0,.004,0)),size,.002)
    def wall_rail(part,a,b):
        a,b=Vector(a),Vector(b);direction=(b-a).normalized()
        side=Vector((0,1,0)).cross(direction);length=(b-a).length
        for off in [-.06,.06]:
            for y in [-.04,.04]:
                tube(part,[a+side*off+Vector((0,y,0)),b+side*off+Vector((0,y,0))],.018,8)
        count=math.ceil(length/.6)
        for k in range(count):
            y0,y1=(-.04,.04) if k%2==0 else (.04,-.04)
            for off in [-.06,.06]:
                tube(part,[a+direction*(length*k/count)+side*off+Vector((0,y0,0)),
                           a+direction*(length*(k+1)/count)+side*off+Vector((0,y1,0))],.009,6)
    def upright(part,at,width,axis):
        at=Vector(at)
        if roof:
            # Built-up paired channels and restrained cross ties, matching the
            # wall references rather than copying roof lattice onto posts.
            lat=Vector((abs(axis.z),0,abs(axis.x)))
            normal=Vector((abs(axis.x),0,abs(axis.z)))
            up=Vector((0,1,0));mid=(base+top)/2
            gap=width*.42;depth=width*.72;flange=width*.23
            for side in [-1,1]:
                part.box(at+lat*(side*gap)+up*mid,
                         lat*.012+normal*depth+up*h,bevel=.002,bevel_segments=1)
                for face in [-1,1]:
                    part.box(at+lat*(side*(gap-flange*.4))+axis*(face*depth*.5)+up*mid,
                             lat*flange+normal*.012+up*h,bevel=.002,bevel_segments=1)
            count=math.ceil(h/.6)
            for k in range(1,count):
                y=base+h*k/count
                if any(abs(y-(base+f*h))<.12 for f in rails):continue
                for face in [-1,1]:
                    part.box(at+axis*(face*depth*.5)+up*y,
                             lat*(gap*2+.025)+normal*.014+up*.04)
        else:beam(part,at+Vector((0,base,0)),at+Vector((0,top,0)),width)
        box(part,at+Vector((0,base+.02,0)),(width*1.6,.04,width*1.6),.005)
    for label,axis in axes:
        root=kit.state_root('Wall_'+label);roots.append(root);part=kit.WeaponPart(label+'_frame')
        lat=Vector((abs(axis.z),0,abs(axis.x)));isdoor=tuple(axis)==tuple(door_axis)
        def point(along,y):return axis*half+lat*along+Vector((0,y,0))
        for f in rails:
            if roof and f == 1:continue # Roof truss supplies the perimeter.
            y=base+f*h
            spans=[(-half,-dw/2),(dw/2,half)] if isdoor and y<base+dh-.01 else [(-half,half)]
            for a,b in spans:
                if roof:wall_rail(part,point(a,y),point(b,y))
                else:beam(part,point(a,y),point(b,y),.065*scale)
        for i in range(5):
            along=-half+span*i/4
            if i in (0,4) and axis.z != 0:continue
            if isdoor and abs(along)<dw/2+.15:continue
            upright(part,axis*half+lat*along,.10*scale if i in (0,4) else .08*scale,axis)
            if roof:
                for fraction in rails[1:-1]:
                    centre=axis*half+lat*along+Vector((0,base+fraction*h,0))
                    for face in [-1,1]:
                        size=lat*.26+Vector((abs(axis.x),0,abs(axis.z)))*.014
                        size.y=.08
                        part.box(centre+axis*(face*.108),size,bevel=.003,bevel_segments=1)
        def wall_panel(a,b,y0,y1,tag):
            verts=[point(a,y0),point(b,y0),point(b,y1),point(a,y1)]
            panel(root,tag,verts,[(a*2,-y0*2),(b*2,-y0*2),(b*2,-y1*2),(a*2,-y1*2)],wire)
        if isdoor:
            for a,b,y0,y1,tag in [(-half,-dw/2,base,top,'MeshLeft'),(dw/2,half,base,top,'MeshRight'),(-dw/2,dw/2,base+dh,top,'MeshAbove')]:wall_panel(a,b,y0,y1,tag)
            for a in [-dw/2,dw/2]:beam(part,point(a,base),point(a,top),.075*scale)
            beam(part,point(-dw/2,base+dh),point(dw/2,base+dh),.065*scale)
            pivot=kit.state_root('DoorPivot');pivot.parent=root;pivot.location=kit.to_blender(axis*half-lat*dw/2)
            leaf=kit.WeaponPart('DoorFrame');inset=.075*scale*.5;w=dw-.075*scale
            for y in [base+.06,base+dh*.5,base+dh-.06]:beam(leaf,lat*inset+Vector((0,y,0)),lat*(inset+w)+Vector((0,y,0)),.052*scale)
            for a in [inset+.02,inset+w-.02]:beam(leaf,lat*a+Vector((0,base,0)),lat*a+Vector((0,base+dh,0)),.052*scale)
            for y in [base+.35,base+dh-.35]:
                tube(leaf,[lat*inset+Vector((0,y-.08,0)),lat*inset+Vector((0,y+.08,0))],.032,10)
            box(leaf,lat*(inset+w-.08)+axis*.05+Vector((0,base+1.05,0)),(.06,.12,.06),.008)
            mesh_part(pivot,leaf,steel)
            verts=[lat*inset+Vector((0,base,0)),lat*(inset+w)+Vector((0,base,0)),lat*(inset+w)+Vector((0,base+dh,0)),lat*inset+Vector((0,base+dh,0))]
            panel(pivot,'DoorMesh',verts,[(0,0),(w*2,0),(w*2,-dh*2),(0,-dh*2)],wire)
        else:wall_panel(-half,half,base,top,'Mesh')
        mesh_part(root,part,steel)
    top_root=kit.state_root('RoofFrame' if roof else 'TopLip');part=kit.WeaponPart('TopFrame')
    if roof:
        bay=span/4
        for i in range(5):
            v=-half+span*i/4
            roof_truss(part,(v,top,-half),(v,top,half))
            roof_truss(part,(-half,top,v),(half,top,v))
        # Local splice plates and low fasteners punctuate truss crossings;
        # remain under the existing roof standing clearance (+.03m).
        for i in range(5):
            for j in range(5):
                x=-half+span*i/4;z=-half+span*j/4
                part.box(Vector((x,top+.018,z)),Vector((.18,.008,.18)),bevel=.002,bevel_segments=1)
                for dx,dz in [(-.06,-.06),(-.06,.06),(.06,-.06),(.06,.06)]:
                    tube(part,[(x+dx,top+.022,z+dz),(x+dx,top+.027,z+dz)],.007,6)
        for i in range(4):
            for j in range(4):
                centre=Vector((-half+bay*(i+.5),top,-half+bay*(j+.5)))
                root=kit.state_root(f'RoofPanel_{i}_{j}');root.location=kit.to_blender(centre)
                # A single mesh node is needed by the runtime's sag/break animation.
                b=bay/2
                obj=panel(root,'Surface',[(-b,0,-b),(b,0,-b),(b,0,b),(-b,0,b)],[((centre.x-b)*2,(centre.z-b)*2),((centre.x+b)*2,(centre.z-b)*2),((centre.x+b)*2,(centre.z+b)*2),((centre.x-b)*2,(centre.z+b)*2)],wire)
    else:
        inner=half-.32
        for label,axis in axes:
            lat=Vector((abs(axis.z),0,abs(axis.x)))
            beam(part,axis*inner-lat*inner+Vector((0,top,0)),axis*inner+lat*inner+Vector((0,top,0)),.065)
            for k in range(1,math.floor(span/.42)):
                a=-half+span*k/math.floor(span/.42)
                if abs(a)>inner:continue
                beam(part,axis*inner+lat*a+Vector((0,top,0)),axis*half+lat*a+Vector((0,top,0)),.045)
            verts=[axis*inner-lat*inner+Vector((0,top,0)),axis*half-lat*inner+Vector((0,top,0)),axis*half+lat*inner+Vector((0,top,0)),axis*inner+lat*inner+Vector((0,top,0))]
            panel(top_root,'Lip_'+label,verts,[(v.x*2,v.z*2) for v in verts],wire)
    mesh_part(top_root,part,steel)
    bpy.context.preferences.filepaths.save_version=0
    source=Path(__file__).resolve().parent/(name+'.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True);bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_apply=True,export_yup=True,export_cameras=False,export_lights=False)
    tris=sum(len(o.data.polygons) for o in bpy.data.objects if o.type=='MESH')
    print('CAGED_EXPORT',name,'polygons',tris,flush=True)


def hardware():
    kit.reset();steel,_=materials()
    brass=kit.flat_material('cage_padlock_brass',(.78,.60,.28),.3,.9)
    root=kit.state_root('PadlockVisual');links=kit.WeaponPart('PadlockChain')
    for k in range(9):
        a=math.tau*k/9;at=Vector((math.cos(a)*.09,math.sin(a)*.11,0))
        points=[]
        for j in range(13):
            t=math.tau*j/12
            q=Vector((math.cos(t)*.019,math.sin(t)*.019,0))
            if k%2:q=Vector((q.x,0,q.y))
            points.append(at+q)
        tube(links,points,.006,6)
    tube(links,[(math.cos(math.tau*j/16)*.026,-.10+math.sin(math.tau*j/16)*.026,.02) for j in range(17)],.004,6)
    mesh_part(root,links,steel)
    body=kit.WeaponPart('LockBody');box(body,(0,-.15,.02),(.07,.08,.035),.005);mesh_part(root,body,brass)
    cable=kit.state_root('HoistCable');part=kit.WeaponPart('Cable')
    tube(part,[(0,-.5,0),(0,.5,0)],.035,8);mesh_part(cable,part,steel)
    bpy.context.preferences.filepaths.save_version=0
    source=Path(__file__).resolve().parent/'cage_hardware.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True);bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/'cage_hardware.glb'),export_format='GLB',export_apply=True,export_yup=True,export_cameras=False,export_lights=False)


if __name__=='__main__':
    TEX.mkdir(parents=True,exist_ok=True)
    only=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else ''
    if not only or only=='steel_cage':
        build('steel_cage',3.26,-.12,4.,[0,.5,1],Vector((-1,0,0)),1.1,2.05,False)
    if not only or only=='hell_in_a_cell':
        build('hell_in_a_cell',4.7,-1.1,5.,[0,.5,1],Vector((0,0,-1)),1.4,2.3,True)
    if not only or only=='cage_hardware':hardware()
