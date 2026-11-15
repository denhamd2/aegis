"""Kenny's closed native authoring pipeline (metres; Blender Z up).

One-time bootstrap captures existing Kenny assets, the historical donor-derived
shape and maps into Kenny.blend. Normal builds read ONLY that packed source.
No Cody identity asset/helper is a normal build input. See packed SeedManifest.

blender -b --factory-startup --python tools/blender/characters/kenny_character.py -- bootstrap
blender -b --factory-startup --python tools/blender/characters/kenny_character.py -- build --round 1
"""
from __future__ import annotations
import argparse, base64, hashlib, io, json, math, pathlib, re, sys, zlib
import bpy
import bmesh
import numpy as np
from mathutils import Vector, kdtree
from mathutils.bvhtree import BVHTree
from PIL import Image, ImageDraw, ImageFilter

ROOT=pathlib.Path(__file__).resolve().parents[3]
NATIVE=pathlib.Path(__file__).with_name('Kenny.blend')
CHAR=ROOT/'game/assets/characters'
SKIN={'xmaterial_c3d4d9e78b44a79':'kenny_head.png',
      'xmaterial_495900de7002683':'kenny_body_abdomen.png',
      'xmaterial_90b39911eb484a2':'kenny_body_arm_r.png',
      'xmaterial_90b2b911eb46cd8':'kenny_body_arm_l.png',
      'xmaterial_5a329cd32db96c3':'kenny_body_chest.png'}
GEAR={'xmaterial_e531cd813705b95':'kenny_gear_tights.png',
      'xmaterial_c7ae1bc9f4b14':'kenny_gear_belt.png',
      'xmaterial_6d1e7e57b971093':'kenny_gear_boot_r.png',
      'xmaterial_6d205e57b97438d':'kenny_gear_boot_l.png',
      'xmaterial_f003af958238385':'kenny_gear_wrist.png'}
EYE='xmaterial_7d08cd4d239faf3'
HEAD='xmaterial_c3d4d9e78b44a79'
MOUTH='head_shared_inside_mouth_iw9'
HAIR=['CurlCap','CurlSlick','CurlRinglets','CurlUndercoat']
AUDIT_OVERRIDE=None

def evidence_dir(round_no=None):
    if AUDIT_OVERRIDE is not None:return pathlib.Path(AUDIT_OVERRIDE)
    number=int(round_no or bpy.context.scene.get('kenny_round',1))
    if number>=4:return ROOT/'gauntlet/refs/kenny_judge_continued_2026_11_14'/('round'+str(number))
    return ROOT/'gauntlet/refs/kenny_judge_2026_11_14'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def text(name,value):
    t=bpy.data.texts.get(name) or bpy.data.texts.new(name);t.clear();t.write(json.dumps(value,separators=(',',':')))
def data(name):return json.loads(bpy.data.texts[name].as_string())
def game(p):return Vector((p.x,p.z,-p.y))
def native(p):return Vector((p.x,-p.z,p.y))
def smooth(t):t=np.clip(t,0,1);return t*t*(3-2*t)
def field(p,rows,mid=.004):
    d=Vector()
    for c,r,v,mirror in rows:
        for side in ([1,-1] if mirror else [1]):
            centre=Vector((mid+side*c[0],c[1],c[2]));q=p-centre
            k=1-Vector(tuple(q[i]/r[i] for i in range(3))).length
            if k>0:d+=Vector((side*v[0],v[1],v[2]))*(k*k*(3-2*k))
    return d
def rows_from_gd(txt,name):
    block=re.search(r'const '+name+r' := \[(.*?)\n\]',txt,re.S).group(1)
    return [([float(x) for x in a.split(',')],[float(x) for x in b.split(',')],
             [float(x) for x in c.split(',')],yes=='true')
            for a,b,c,yes in re.findall(r'\[Vector3\(([^)]*)\), Vector3\(([^)]*)\), Vector3\(([^)]*)\), (true|false)\]',block)]
def floats(txt,name):
    a=[float(x) for x in re.search(name+r' = PackedVector3Array\(([^)]*)\)',txt).group(1).split(',')]
    return [Vector(a[i:i+3]) for i in range(0,len(a),3)]
def packed_array(a):
    a=np.asarray(a,dtype='<f4');return {'shape':list(a.shape),'zlib_base64':base64.b64encode(zlib.compress(a.tobytes(),9)).decode()}
def unpack_array(a):return np.frombuffer(zlib.decompress(base64.b64decode(a['zlib_base64'])),dtype='<f4').reshape(a['shape']).astype(float)

def capture_parity(path):
    """One-time repair of the captured seed; never a normal build dependency."""
    bpy.ops.wm.open_mainfile(filepath=str(NATIVE))
    if 'KennyRawSeed' in bpy.data.texts:raise RuntimeError('Owned raw parity seed is already captured')
    path=pathlib.Path(path);manifest=data('SeedManifest')
    assert sha(path)==manifest['bootstrap_body_sha256'],'Historical owned seed fingerprint differs'
    existing=bpy.data.objects['Seed_Body'];before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    added=set(bpy.data.objects)-before;raw=next(o for o in added if o.type=='MESH' and o.name.startswith('Body'))
    assert len(raw.data.vertices)==len(existing.data.vertices)
    assert [tuple(p.vertices) for p in raw.data.polygons]==[tuple(p.vertices) for p in existing.data.polygons]
    assert max(abs(raw.matrix_world[i][j]-existing.matrix_world[i][j]) for i in range(4) for j in range(4))<1e-7
    fit_path=ROOT/'game/resources/characters/kenny_head_shape.tres'
    assert sha(fit_path)==data('KennyCapturedFace')['fit_sha']
    fit=fit_path.read_text();gd=(ROOT/'game/core/match/kenny_face_shape.gd').read_text()
    def regions(name):
        block=re.search(r'const '+name+r' := \[(.*?)\n\]',gd,re.S).group(1)
        return [([float(x) for x in c.split(',')],[float(x) for x in r.split(',')],float(w))
                for c,r,w in re.findall(r'\[Vector3\(([^)]*)\), Vector3\(([^)]*)\), ([0-9.]+)\]',block)]
    snap={'historical_owned_body_sha256':sha(path),'positions':packed_array([v.co[:] for v in raw.data.vertices]),
          'loop_normals':packed_array([n.vector[:] for n in raw.data.corner_normals]),
          'fit_rest':packed_array(floats(fit,'rest')),'fit_offset':packed_array(floats(fit,'offset')),
          'fit_normal_offset':packed_array(floats(fit,'normal_offset')),
          'relax':regions('RELAX'),'relax_passes':14,'relax_rate':.5,
          'soften':regions('SOFTEN'),'soften_toward':[0,.6,.8],
          'note':'Repair of R1 capture omission; owned historical positions/split normals + full Kenny deformation state. Future builds use this packed block only.'}
    text('KennyRawSeed',snap)
    for obj in added:bpy.data.objects.remove(obj,do_unlink=True)
    for container in [bpy.data.meshes,bpy.data.armatures,bpy.data.materials,bpy.data.images]:
        for item in list(container):
            if not item.users and not item.use_fake_user:container.remove(item)
    manifest['parity_seed_captured']=True;text('SeedManifest',manifest)
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(NATIVE),compress=True)
    print('KENNY_PARITY_CAPTURE',len(snap['loop_normals']['zlib_base64']),NATIVE.stat().st_size)

def clear_normals(obj):
    if obj.data.has_custom_normals:
        with bpy.context.temp_override(object=obj,active_object=obj):bpy.ops.mesh.customdata_custom_splitnormals_clear()
    obj.data.update()

def field_numpy(points,normals,loop_vertex,rows,mid=.004,mask=None):
    """Smooth displacement and inverse-transpose normal transport in game space."""
    disp=np.zeros_like(points);jac=np.broadcast_to(np.eye(3),(len(points),3,3)).copy()
    for c,r,v,mirror in rows:
        r=np.asarray(r)
        for side in ([1,-1] if mirror else [1]):
            centre=np.array([mid+side*c[0],c[1],c[2]]);move=np.array([side*v[0],v[1],v[2]])
            q=(points-centre)/r;length=np.linalg.norm(q,axis=1);k=np.maximum(1-length,0)
            if mask is not None:k*=mask
            value=k*k*(3-2*k);disp+=value[:,None]*move
            grad=(-6*k*(1-k)/np.maximum(length,1e-12))[:,None]*q/r
            jac+=move[None,:,None]*grad[:,None,:]
    points+=disp
    inverse=np.linalg.inv(jac)
    normals=np.einsum('lji,lj->li',inverse[loop_vertex],normals)
    normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-12)
    return points,normals

def brow_return(points,normals,loop_vertex,mask):
    # Measured R4 local profile at x~.034: its lower y1.730 ledge remained
    # forward after the high ridge was retracted. Control that actual return,
    # preserving the upper-lid margin at y1.7235 and the unchanged eyeballs.
    ys=np.array([1.7245,1.730,1.738,1.746,1.762])
    dz=np.array([0,-.0045,-.0035,-.0022,0])
    def delta(p):
        y=p[:,1];value=np.zeros(len(p))
        for k in range(len(ys)-1):
            use=(y>=ys[k])&(y<ys[k+1]);t=smooth((y[use]-ys[k])/(ys[k+1]-ys[k]))
            value[use]=dz[k]+(dz[k+1]-dz[k])*t
        x=np.abs(p[:,0]-.004);lateral=smooth((x-.004)/.017)*(1-smooth((x-.055)/.018))
        front=smooth((p[:,2]+.045)/.015)
        out=np.zeros_like(p);out[:,2]=value*lateral*front*mask;return out
    d=delta(points);jac=np.broadcast_to(np.eye(3),(len(points),3,3)).copy();step=1e-5
    for axis in range(3):
        off=np.zeros(3);off[axis]=step;jac[:,:,axis]+=(delta(points+off)-delta(points-off))/(2*step)
    points+=d;normals=np.einsum('lji,lj->li',np.linalg.inv(jac)[loop_vertex],normals)
    normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-12)
    return points,normals

def region_weight(points,regions):
    weight=np.zeros(len(points))
    for c,r,strength in regions:
        for side in [1,-1]:
            centre=np.array([.004+side*c[0],c[1],c[2]])
            t=np.maximum(1-np.linalg.norm((points-centre)/r,axis=1),0)
            weight=np.maximum(weight,strength*t*t*(3-2*t))
    return weight

def owned_baseline(body,round_no=2):
    """Restore all frozen Kenny fit/sculpt/relax/normal stages, not just position fields."""
    snap=data('KennyRawSeed');mesh=body.data;mw=np.array(body.matrix_world);rot=np.array([[1,0,0],[0,0,1],[0,-1,0]])
    raw=unpack_array(snap['positions']);positions=(raw@mw[:3,:3].T+mw[:3,3])@rot.T
    nlocal=unpack_array(snap['loop_normals']);normals=nlocal@np.linalg.inv(mw[:3,:3])@rot.T
    loop_v=np.array([l.vertex_index for l in mesh.loops]);mi={m.name:i for i,m in enumerate(mesh.materials)}
    head_ids=np.array(sorted({v for f in mesh.polygons if f.material_index==mi[HEAD] for v in f.vertices}))
    fit_ids=np.array(sorted(set(head_ids)|{v for f in mesh.polygons if f.material_index==mi[MOUTH] for v in f.vertices}))
    head_mask=np.zeros(len(positions),bool);head_mask[head_ids]=True
    rest=unpack_array(snap['fit_rest']);offset=unpack_array(snap['fit_offset']);noffset=unpack_array(snap['fit_normal_offset'])
    tree=kdtree.KDTree(len(rest))
    for i,p in enumerate(rest):tree.insert(Vector(p),i)
    tree.balance();found=np.full(len(positions),-1,int)
    for i in fit_ids:
        _,j,dist=tree.find(Vector(positions[i]))
        if dist<=.0002:found[i]=j
    chosen=np.flatnonzero(found>=0);positions[chosen]+=offset[found[chosen]]
    affected=found[loop_v]>=0;normals[affected]+=noffset[found[loop_v[affected]]]
    normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-12)
    historical_fields=data('KennyCapturedFace')['field']
    if round_no>=4 and round_no<6:
        # Canonical neutral upper face: remove the old 5 mm accumulated lid
        # closure and compensating ridge/forehead bumps before authoring it.
        historical_fields=[r for r in historical_fields if r[0][1]<1.705]
    positions,normals=field_numpy(positions,normals,loop_v,historical_fields,mask=head_mask)
    # Same welded, synchronised neighbour relaxation used by the historical
    # Kenny face. UV islands share group positions and recomputed smooth normals.
    keys=np.round(positions[head_ids]*50000).astype(np.int64)
    _,first,group=np.unique(keys,axis=0,return_index=True,return_inverse=True)
    gp=positions[head_ids[first]].copy();global_group=np.full(len(positions),-1,int);global_group[head_ids]=group
    tris=np.array([list(p.vertices) for p in mesh.polygons if p.material_index==mi[HEAD]])
    gt=global_group[tris];weight=region_weight(gp,snap['relax'])
    edges=np.unique(np.vstack([gt[:,[0,1]],gt[:,[1,0]],gt[:,[1,2]],gt[:,[2,1]],gt[:,[0,2]],gt[:,[2,0]]]),axis=0)
    count=np.bincount(edges[:,0],minlength=len(gp));active=(weight>0)&(count>0)
    for _ in range(snap['relax_passes']):
        acc=np.zeros_like(gp);np.add.at(acc,edges[:,0],gp[edges[:,1]])
        mean=acc/np.maximum(count[:,None],1);gp[active]+=(mean[active]-gp[active])*(snap['relax_rate']*weight[active,None])
    positions[head_ids]=gp[group]
    keep=np.any(weight[gt]>0,axis=1);a,b,c=gp[gt[keep,0]],gp[gt[keep,1]],gp[gt[keep,2]]
    fn=np.cross(c-a,b-a);acc=np.zeros_like(gp)
    for col in range(3):np.add.at(acc,gt[keep,col],fn)
    groups=global_group[loop_v];loops=np.flatnonzero((groups>=0)&head_mask[loop_v]);gg=groups[loops]
    use=(weight[gg]>0)&(np.linalg.norm(acc[gg],axis=1)>1e-12);loops=loops[use];gg=gg[use]
    built=acc[gg];built/=np.linalg.norm(built,axis=1)[:,None];old=normals[loops]
    dots=np.sum(old*built,axis=1);built[dots<0]*=-1;dots=np.clip(np.sum(old*built,axis=1),-1,1)
    theta=np.arccos(dots);t=np.clip(weight[gg]*1.5,0,1);den=np.sin(theta);small=abs(den)<1e-6
    mixed=old*(1-t[:,None])+built*t[:,None]
    good=~small;mixed[good]=(old[good]*np.sin((1-t[good])*theta[good])[:,None]+built[good]*np.sin(t[good]*theta[good])[:,None])/den[good,None]
    normals[loops]=mixed/np.maximum(np.linalg.norm(mixed,axis=1)[:,None],1e-12)
    w=region_weight(positions,snap['soften']);use=head_mask[loop_v]&(normals[:,2]>=-.2)
    normals[use]+=np.asarray(snap['soften_toward'])[None,:]*w[loop_v[use],None]*1.8
    normals/=np.maximum(np.linalg.norm(normals,axis=1)[:,None],1e-12)
    positions,normals=field_numpy(positions,normals,loop_v,data('KennyCapturedFace')['historical_yoke'],mid=0)
    return positions,normals,loop_v,head_mask,mw,rot

def set_game_geometry(body,positions,normals,mw,rot):
    local=((positions@rot)-mw[:3,3])@np.linalg.inv(mw[:3,:3]).T
    for v,p in zip(body.data.vertices,local):v.co=p
    body.data.update();nlocal=normals@rot@mw[:3,:3]
    nlocal/=np.maximum(np.linalg.norm(nlocal,axis=1)[:,None],1e-12)
    body.data.normals_split_custom_set(nlocal.tolist());body.data.update()

def bake_seed_shape(body):
    # Bootstrap only: capture the existing Kenny-authored field, then freeze it.
    gd=(ROOT/'game/core/match/kenny_face_shape.gd').read_text()
    fit=(ROOT/'game/resources/characters/kenny_head_shape.tres').read_text()
    rests,offsets=floats(fit,'rest'),floats(fit,'offset')
    tree=kdtree.KDTree(len(rests))
    for i,p in enumerate(rests):tree.insert(p,i)
    tree.balance();moves=rows_from_gd(gd,'TABLE');mw=body.matrix_world;inv=mw.inverted()
    head_idx={i for i,m in enumerate(body.data.materials) if m.name==HEAD}
    mouth_idx={i for i,m in enumerate(body.data.materials) if m.name==MOUTH}
    skin={v for f in body.data.polygons if f.material_index in head_idx for v in f.vertices}
    affected=skin|{v for f in body.data.polygons if f.material_index in mouth_idx for v in f.vertices}
    for i in affected:
        p=game(mw@body.data.vertices[i].co);_,j,dist=tree.find(p)
        if dist<.0002:p+=offsets[j]
        if i in skin:p+=field(p,moves)
        body.data.vertices[i].co=inv@native(p)
    # Historical donor yoke correction is copied once as geometry. No script
    # dependency survives into normal builds; BodyBulk.KENNY remains runtime.
    yoke=[([.190,1.590,-.150],[.200,.130,.230],[0,-.034,0],True),
          ([.078,1.615,-.120],[.045,.055,.100],[-.007,0,0],True)]
    for v in body.data.vertices:
        p=game(mw@v.co);v.co=inv@native(p+field(p,yoke,0))
    clear_normals(body)
    text('KennyCapturedFace',{'fit_sha':sha(ROOT/'game/resources/characters/kenny_head_shape.tres'),
         'fitted_vertices':len(rests),'field':moves,'historical_yoke':yoke,
         'note':'Face baked once; runtime BodyBulk.KENNY is NOT baked.'})
    body['kenny_face_baked']=True

def packed_map(path,name,seed=True):
    image=bpy.data.images.load(str(path),check_existing=False);image.name=('SeedMap::' if seed else 'Map::')+name
    image.pack();image.use_fake_user=True;image.filepath='//packed_maps/'+name
    image['output_name']=name
    if any(s in name for s in ['roughness','_wet','_orm','_height']):image.colorspace_settings.name='Non-Color'
    return image
def seed_image(name):return bpy.data.images['SeedMap::'+name]
def pil_seed(name):return Image.open(io.BytesIO(bytes(seed_image(name).packed_file.data))).convert('RGBA')
def store_map(name,pil):
    scratch=pathlib.Path('/tmp/aegis-kenny-author');scratch.mkdir(exist_ok=True)
    path=scratch/name;pil.save(path,optimize=True)
    old=bpy.data.images.get('Map::'+name)
    if old:bpy.data.images.remove(old)
    return packed_map(path,name,False)
def material_image(mat,image):
    nt=mat.node_tree;bsdf=nt.nodes.get('Principled BSDF')
    if not bsdf:return
    for link in list(bsdf.inputs['Base Color'].links):nt.links.remove(link)
    for node in list(nt.nodes):
        if node.type=='TEX_IMAGE':nt.nodes.remove(node)
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=image;nt.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])

def colours(obj):
    attr=obj.data.color_attributes.active_color
    if not attr:return np.ones((len(obj.data.vertices),4))
    if attr.domain=='POINT':return np.array([c.color[:] for c in attr.data])
    out=np.ones((len(obj.data.vertices),4))
    for l in obj.data.loops:out[l.vertex_index]=attr.data[l.index].color
    return out

def capture_guides(obj):
    """Freeze current native strand paths, independent of any donor scalp tool."""
    mesh=obj.data;parent=list(range(len(mesh.vertices)))
    def root(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    for e in mesh.edges:
        a,b=(root(x) for x in e.vertices)
        if a!=b:parent[b]=a
    comps={}
    for i in range(len(parent)):comps.setdefault(root(i),[]).append(i)
    cs=colours(obj);guides=[]
    for vs in comps.values():
        rows={}
        for i in vs:rows.setdefault(round(float(cs[i,3]),5),[]).append(i)
        if len(rows)<3:continue
        path=[]
        for t,ids in sorted(rows.items()):
            ps=[obj.matrix_world@mesh.vertices[i].co for i in ids]
            c=sum(ps,Vector())/len(ps)
            width=max((p-c).length for p in ps)*2
            path.append([t,list(c),max(width,.001)])
        guides.append(path)
    return guides

def bootstrap():
    if NATIVE.exists():raise RuntimeError('Native source already exists; bootstrap cannot overwrite it')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(CHAR/'kenny_body.glb'))
    body=bpy.data.objects['Body'];arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    bake_seed_shape(body)
    manifest={'historical_donor':'Supplied Cody rig/mesh copied to kenny_body.glb on 12 Nov 2026; donor-derived, not an original scan/sculpt.',
              'bootstrap_body_sha256':sha(CHAR/'kenny_body.glb'),'bootstrap_groom_sha256':sha(CHAR/'kenny_curls.glb'),
              'note':'All future rebuilds read this packed native source, not game outputs or donor files.', 'maps':{}}
    names=list(SKIN.values())+list(GEAR.values())+['kenny_eye_color.png','kenny_eye_orm.png','kenny_eye_height.png','kenny_curl_cards.png','kenny_face_projected.png']
    for name in names:
        packed_map(CHAR/name,name);manifest['maps'][name]=sha(CHAR/name)
    # Explicit one-time pattern snapshots; no future donor file reads.
    for tail in ['roughness','wet']:
        origin=CHAR/('cody_skin_head_'+tail+'.png');name='kenny_skin_head_'+tail+'.png'
        packed_map(origin,name);manifest['maps'][name]={'historical_pattern_sha256':sha(origin),'donor_pattern_snapshot':True}
    for source in (ROOT/'tools/assets/sources').glob('kenny_*_owner.*'):
        im=bpy.data.images.load(str(source),check_existing=False);im.name='OwnerReference::'+source.name;im.pack();im.use_fake_user=True;im.filepath='//owner_inputs/'+source.name
    for m in body.data.materials:
        name=SKIN.get(m.name,GEAR.get(m.name,'kenny_eye_color.png' if m.name==EYE else ''))
        if name:material_image(m,seed_image(name))
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(CHAR/'kenny_curls.glb'))
    new=set(bpy.data.objects)-before;hair_arm=next(o for o in new if o.type=='ARMATURE')
    assert set(arm.data.bones.keys())==set(hair_arm.data.bones.keys())
    for b in arm.data.bones:
        assert max(abs(b.matrix_local[i][j]-hair_arm.data.bones[b.name].matrix_local[i][j]) for i in range(4) for j in range(4))<1e-5,b.name
    guides={}
    for name in HAIR:
        obj=next(o for o in new if o.name==name);world=obj.matrix_world.copy();obj.parent=arm;obj.matrix_world=world
        for mod in obj.modifiers:
            if mod.type=='ARMATURE':mod.object=arm
        if name!='CurlCap':guides[name]=capture_guides(obj)
    for o in list(new):
        if o.type=='ARMATURE':bpy.data.objects.remove(o,do_unlink=True)
    archive=bpy.data.collections.new('COL_Kenny_Seed');bpy.context.scene.collection.children.link(archive)
    for name in ['Body']+HAIR:
        obj=bpy.data.objects[name];seed=obj.copy();seed.data=obj.data.copy();seed.name='Seed_'+name;archive.objects.link(seed)
        seed.hide_render=True;seed.hide_set(True)
    text('KennyGuideSeed',guides);text('SeedManifest',manifest)
    text('KennyBind',{'bones':[{'name':b.name,'parent':b.parent.name if b.parent else None,'matrix':[list(r) for r in b.matrix_local]} for b in arm.data.bones],
                     'body_vertices':len(body.data.vertices),'no_runtime_bulk_bake':True,'no_exported_morphs':True})
    for im in bpy.data.images:
        if im.source=='FILE' and im.has_data:
            im.pack();im.filepath='//packed_maps/'+im.name
    # Remove unused donor image datablocks after material rebinding. Mouth map
    # remains owned in the native file, with honest captured donor provenance.
    for im in list(bpy.data.images):
        if not im.users and not im.use_fake_user:bpy.data.images.remove(im)
    bpy.context.scene['kenny_round']=0;bpy.context.scene['kenny_face_baked']=True
    NATIVE.parent.mkdir(parents=True,exist_ok=True);bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(NATIVE),compress=True)
    print('KENNY_SEED',NATIVE,'bytes',NATIVE.stat().st_size,'bones',len(arm.data.bones),'guides',{k:len(v) for k,v in guides.items()})

def art_body(round_no):
    body=bpy.data.objects['Body'];seed=bpy.data.objects['Seed_Body']
    previous=body.data;body.data=seed.data.copy()
    if previous.users==0:bpy.data.meshes.remove(previous)
    body.data.name='KennyBodyMesh';mw=body.matrix_world;inv=mw.inverted()
    if round_no>=7:
        source_directory=str(pathlib.Path(__file__).resolve().parent)
        if source_directory not in sys.path:sys.path.insert(0,source_directory)
        import kenny_reference_fit
        report=kenny_reference_fit.fit(sys.modules[__name__],body,round_no)
        body['kenny_face_baked']=True
        text('KennyAuthoredSculpt',{'round':round_no,'method':'Canonical measured RAW head fit, clay gate first.','runtime_bulk_baked':False})
        return
    # Bounded first sculpt: orbital transition and straighter bridge, not a
    # global head scale. Eyes, mouth interior, neck and bones stay anchored.
    fields=[([.030,1.737,-.002],[.043,.022,.035],[0,.0015,-.0040],True),
            ([.008,1.701,.016],[.018,.032,.024],[0,0,.0028],True),
            ([.010,1.675,.037],[.018,.017,.022],[0,-.0010,.0010],True),
            ([.025,1.613,-.004],[.030,.018,.035],[.0015,.0010,.0030],True),
            ([.055,1.643,-.031],[.026,.027,.035],[.0018,0,.0012],True)]
    if round_no>=3:
        fields[0]=([.030,1.737,-.002],[.043,.022,.035],[0,-.0006,-.0048],True)
        fields += [([.013,1.737,.000],[.020,.018,.025],[0,.0008,-.0015],True),
                   ([.031,1.723,-.014],[.017,.006,.015],[0,-.0005,.0008],True),
                   ([.031,1.708,-.010],[.016,.005,.018],[0,-.0006,-.0008],True),
                   ([.046,1.663,-.020],[.025,.025,.034],[.0010,0,.0010],True),
                   ([.027,1.612,-.007],[.024,.015,.027],[.0008,0,.0008],True)]
    if round_no>=4 and round_no<6:
        # One reference-led upper-face target replaces the historical stack.
        # The brow return stops above the eyeball pole; the lid margins move
        # gently down/forward on the unchanged eye sphere, not into it.
        fields=[([.030,1.741,-.005],[.047,.016,.039],[0,-.0010,-.0080],True),
                ([.032,1.7235,-.012],[.017,.006,.016],[0,-.0012,.0006],True),
                ([.032,1.7085,-.015],[.015,.005,.014],[0,.0006,.0003],True),
                ([.009,1.704,.014],[.018,.033,.025],[0,0,.0040],True),
                ([.010,1.674,.037],[.018,.016,.023],[0,-.0010,.0005],True),
                ([.027,1.608,-.005],[.030,.025,.034],[.0035,.0010,.0015],True),
                ([.050,1.660,-.025],[.027,.026,.036],[.0015,0,.0015],True)]
    idx={i for i,m in enumerate(body.data.materials) if m.name==HEAD}
    ids={v for f in body.data.polygons if f.material_index in idx for v in f.vertices}
    if round_no>=2:
        positions,normals,loop_v,mask,world,rot=owned_baseline(body,3 if round_no>=6 else round_no)
        positions,normals=field_numpy(positions,normals,loop_v,fields,mask=mask)
        if round_no==5:positions,normals=brow_return(positions,normals,loop_v,mask)
        set_game_geometry(body,positions,normals,world,rot)
    else:
        for i in ids:
            v=body.data.vertices[i];p=game(mw@v.co);v.co=inv@native(p+field(p,fields))
        clear_normals(body)
    body['kenny_face_baked']=True
    text('KennyAuthoredSculpt',{'round':round_no,'fields':fields,'runtime_bulk_baked':False})

def neutral_brow_map(image,round_no):
    """Replace the broad painted arches with fine, lower, almost level brows."""
    a=np.array(image);h,w=a.shape[:2];yy,xx=np.mgrid[:h,:w]
    source_y=np.clip(np.rint((.245+(yy/h-.30)*.35)*h).astype(int),0,h-1)
    clone=a[source_y,xx].copy();mask=Image.new('L',(w,h),0);draw=ImageDraw.Draw(mask)
    for x0,x1 in [(.302,.477),(.523,.698)]:draw.rounded_rectangle((int(x0*w),int(.272*h),int(x1*w),int(.331*h)),radius=12,fill=255)
    m=np.array(mask.filter(ImageFilter.GaussianBlur(5)),dtype=float)/255
    out=a.astype(float)*(1-m[:,:,None])+clone.astype(float)*m[:,:,None]
    base=Image.fromarray(np.uint8(np.clip(out,0,255)),'RGBA');layer=Image.new('RGBA',(w,h),(0,0,0,0));d=ImageDraw.Draw(layer)
    rng=np.random.default_rng(140411)
    if round_no>=5:
        body=bpy.data.objects['Body'];mesh=body.data;mw=body.matrix_world
        polygons=[p for p in mesh.polygons if mesh.materials[p.material_index].name==HEAD]
        points=[mw@v.co for v in mesh.vertices];bvh=BVHTree.FromPolygons(points,[list(p.vertices) for p in polygons],all_triangles=True)
        uv=mesh.uv_layers.active.data;registered=[]
        def project(x,y):
            hit,normal,index,distance=bvh.ray_cast(Vector((x,-.30,y)),Vector((0,1,0)),.5)
            if hit is None:return None
            p=polygons[index];a,b,c=(points[i] for i in p.vertices);v0=b-a;v1=c-a;v2=hit-a
            den=v0.dot(v0)*v1.dot(v1)-v0.dot(v1)**2
            if abs(den)<1e-16:return None
            vb=(v1.dot(v1)*v2.dot(v0)-v0.dot(v1)*v2.dot(v1))/den
            vc=(v0.dot(v0)*v2.dot(v1)-v0.dot(v1)*v2.dot(v0))/den;va=1-vb-vc
            u=uv[p.loop_start].uv*va+uv[p.loop_start+1].uv*vb+uv[p.loop_start+2].uv*vc
            return (float(u.x*w),float((1-u.y)*h))
        for side in [-1,1]:
            line=[]
            for t in np.linspace(0,1,65):
                x=.004+side*(.012+.056*t)
                y=(1.7275+.0007*math.sin(math.pi*t)+.0004*t) if round_no>=6 else 1.735+.0016*math.sin(math.pi*t)-.0008*t
                q=project(x,y)
                if q:line.append(q)
            if len(line)>2:d.line(line,fill=(74,56,42,48),width=4)
            for _ in range(230):
                t=float(rng.uniform(0,1));x=.004+side*(.012+.056*t)
                y=((1.7275+.0007*math.sin(math.pi*t)+.0004*t) if round_no>=6 else 1.735+.0016*math.sin(math.pi*t)-.0008*t)+float(rng.normal(0,.00024))
                a=project(x,y);b=project(x+side*float(rng.uniform(.00015,.0010)),y+float(rng.uniform(.0011,.0023)))
                if a and b:d.line([a,b],fill=(59,45,34,int(rng.integers(100,185))),width=1 if rng.random()<.75 else 2)
            registered.append({'side':side,'path_px':line})
        text('KennyRegisteredBrows',{'round':round_no,'world_y':1.7275 if round_no>=6 else 1.735,'method':'Skin raycast + triangle barycentric UV, not a horizontal atlas guess.','paths':registered})
        return Image.alpha_composite(base,layer)
    for side in [-1,1]:
        for _ in range(165):
            t=float(rng.uniform(0,1));u=.314+.148*t;v=.311+.002*t-.0035*math.sin(math.pi*t)
            x=(u if side==-1 else 1-u)*w;y=v*h+float(rng.normal(0,3))
            dx=(float(rng.uniform(-5,1)) if side==-1 else float(rng.uniform(-1,5)))
            dy=-float(rng.uniform(7,15));alpha=int(rng.integers(90,185))
            d.line([(x,y),(x+dx*.45,y+dy*.5),(x+dx,y+dy)],fill=(67,51,40,alpha),width=1 if rng.random()<.8 else 2)
    return Image.alpha_composite(base,layer)

def art_maps(round_no):
    outputs={}
    for name in data('SeedManifest')['maps']:
        src=pil_seed(name)
        changed=False
        if name=='kenny_head.png':
            changed=True
            rgb=np.asarray(src,dtype=np.float32);blur=np.asarray(src.filter(ImageFilter.GaussianBlur(1.5)),dtype=np.float32)
            yy,xx=np.mgrid[:src.height,:src.width];u=xx/src.width;v=yy/src.height
            face=np.clip(1-np.abs(u-.5)/.31,0,1)*smooth((v-.2)/.15)*(1-smooth((v-.76)/.12))
            rgb=rgb*(1-face[:,:,None]*.30)+blur*(face[:,:,None]*.30)
            # Lighten dense dark beard pigment slightly while retaining natural
            # strand/skin variation; no uniform painted-on replacement beard.
            beard=face*smooth((v-.48)/.10)*(1-smooth((v-.78)/.06))
            rgb[:,:,:3]+=beard[:,:,None]*np.array([7,8,8])
            if round_no>=3:
                brow=np.maximum(np.exp(-((u-.385)/.060)**2-((v-.304)/.016)**2),
                                np.exp(-((u-.615)/.060)**2-((v-.304)/.016)**2))
                fine=np.asarray(src.filter(ImageFilter.GaussianBlur(2.0)),dtype=np.float32)
                soften=np.clip(beard*.35+brow*.35,0,.5)
                rgb=rgb*(1-soften[:,:,None])+fine*soften[:,:,None]
                lum=rgb[:,:,:3].mean(axis=2)/255
                dark=np.clip((.66-lum)/.30,0,1)
                rgb[:,:,:3]+=beard[:,:,None]*dark[:,:,None]*np.array([9,11,12])
            src=Image.fromarray(np.uint8(np.clip(rgb,0,255)),'RGBA')
            if round_no>=4 and round_no<6:
                # The seed's opaque beard reads as a full beard. Blend a share
                # of nearby own skin into it to keep short stubble contrast.
                a=np.array(src,dtype=float);clean=np.mean(a[int(.41*src.height):int(.45*src.height),:,:3],axis=0)
                blend=beard*.23;a[:,:,:3]=a[:,:,:3]*(1-blend[:,:,None])+clean[None,:,:]*blend[:,:,None]
                src=neutral_brow_map(Image.fromarray(np.uint8(np.clip(a,0,255)),'RGBA'),round_no)
            elif round_no>=6:
                # Actual front draft rejected the new projected brow tracks.
                # Keep the validated R3 pigment rather than publish a misplaced
                # cosmetic change. A new landmark fit is separate future work.
                text('KennyRegisteredBrows',{'round':round_no,'fallback':'Validated R3 pigment retained after actual runtime draft rejected projected forehead tracks.','improvement_claim':False})
        elif name in ['kenny_body_chest.png','kenny_body_arm_l.png','kenny_body_arm_r.png']:
            changed=True
            src=Image.blend(src,src.filter(ImageFilter.GaussianBlur(1.7 if round_no>=3 else 1.4)),.42 if round_no>=3 else .27)
        elif name.endswith('_roughness.png'):
            changed=True
            a=np.array(src);a[:,:,:3]=np.clip(a[:,:,:3].astype(float)*.90+20,0,255);src=Image.fromarray(a)
        elif name.endswith('_wet.png'):
            changed=True;src=Image.blend(src,src.filter(ImageFilter.GaussianBlur(2)),.35)
        if round_no>=3 and name in SKIN.values():
            a=np.asarray(src,dtype=float);rgb=a[:,:,:3];weights=np.array([.2126,.7152,.0722])
            luminance=rgb@weights;balanced=rgb*np.array([.96,1.008,1.06])
            balanced*=luminance[:,:,None]/np.maximum((balanced@weights)[:,:,None],1)
            a[:,:,:3]=balanced;src=Image.fromarray(np.uint8(np.clip(a,0,255)),'RGBA');changed=True
        if name!='kenny_curl_cards.png':
            outputs[name]=(store_map(name,src) if changed else seed_image(name)).name
    # Eight independent thin-strand strips. No opaque black background sampled
    # through the card; coherent strand alpha tapers at roots and tips.
    size=1024;cols=8;rng=np.random.default_rng(140114)
    rgb=Image.new('RGB',(size,size),(174,174,174));alpha=Image.new('L',(size,size),0)
    dr,da=ImageDraw.Draw(rgb),ImageDraw.Draw(alpha);cw=size//cols
    for col in range(cols):
        for s in range(26):
            root=float(rng.uniform(.08,.92));phase=float(rng.uniform(0,6.28));amp=float(rng.uniform(.012,.055))
            pts=[]
            for k in range(81):
                t=k/80;x=(col+root+amp*math.sin(t*math.pi*2+phase))*cw
                pts.append((x,(1-t)*1023))
            width=int(rng.integers(1,3));tone=int(rng.integers(190,256))
            for k in range(80):
                t=k/80;av=int(235*min(1,t/.035)*min(1,(1-t)/.10))
                da.line(pts[k:k+2],fill=av,width=width);dr.line(pts[k:k+2],fill=(tone,)*3,width=width)
    alpha=alpha.filter(ImageFilter.GaussianBlur(.25))
    if (round_no>=2 and round_no<4) or round_no>=6:
        # Retain a coherent curved clump core after minification, with fine
        # interrupted edges. Sparse individual strand alpha alone vanished at
        # the renderer's effective alpha-to-coverage threshold.
        yy,xx=np.mgrid[:size,:size];u=(xx%cw)/(cw-1);v=1-yy/(size-1)
        envelope=smooth((u-.07)/.19)*(1-smooth((u-.73)/.20))
        taper=smooth(v/.035)*(1-smooth((v-.88)/.12))
        fibre=.90+.10*np.sin(xx*.61+np.sin(yy*.027)*2.2)
        core=envelope*taper*fibre*.78
        if round_no>=6:
            # Recover R3's minification-safe primary mass with fine internal
            # breaks; broad root coverage takes priority over isolated alpha.
            gaps=(np.sin(xx*math.pi*.70+np.sin(yy*.018))>.88)
            core*=np.where(gaps,.62,1)
        arr=np.maximum(np.asarray(alpha)/255,core)
        alpha=Image.fromarray(np.uint8(np.clip(arr*255,0,255)),'L')
    elif round_no>=4:
        # Several separated fibre bundles replace the single opaque 90px band.
        yy,xx=np.mgrid[:size,:size];u=(xx%cw)/(cw-1);v=1-yy/(size-1);bundle=np.zeros_like(u,dtype=float)
        for k,centre in enumerate([.15,.32,.50,.69,.86]):
            wave=.010*np.sin(v*math.pi*(2.0+k*.15)+k*1.7)
            fibre=np.exp(-((u-centre-wave)/(.030 if k%2 else .035))**4)
            bundle=np.maximum(bundle,fibre*.96)
        taper=smooth(v/.025)*(1-smooth((v-.90)/.10))
        arr=np.maximum(np.array(alpha)/255,bundle*taper)
        alpha=Image.fromarray(np.uint8(np.clip(arr*255,0,255)),'L')
    out=rgb.convert('RGBA');out.putalpha(alpha);store_map('kenny_curl_cards.png',out)
    outputs['kenny_curl_cards.png']='Map::kenny_curl_cards.png';text('KennyOutputMaps',outputs)

def linear(c):
    return [(v/255/12.92 if v/255<=.04045 else ((v/255+.055)/1.055)**2.4) for v in c]
def hair_weights(p):
    neck=float(smooth((1.60-p.z)/.08));spine=float(smooth((1.50-p.z)/.10))
    return [('Head',1-neck),('neck_01',neck*(1-spine)),('spine_03',neck*spine)]
def make_hair(name,guides,arm,round_no):
    if round_no>=6:return make_curled_hair(name,guides,arm,round_no)
    if round_no>=4:return make_grouped_hair(name,guides,arm,round_no)
    if round_no>=3:return make_curled_hair(name,guides,arm)
    rng=np.random.default_rng(140114+HAIR.index(name));verts=[];faces=[];uvs=[];colors=[]
    for gi,guide in enumerate(guides):
        raw=np.array([r[1] for r in guide]);width=np.array([r[2] for r in guide]);ts=np.array([r[0] for r in guide])
        if len(raw)<3:continue
        # Smooth native centre paths rather than retaining the zigzag ribbon
        # edges. Two finer overlapping strips replace each broad length card.
        sm=raw.copy()
        for k in range(1,len(raw)-1):sm[k]=raw[k]*.5+(raw[k-1]+raw[k+1])*.25
        n=(min(max(len(raw),14),18) if name!='CurlSlick' else 18) if round_no>=2 else min(len(raw),16 if name!='CurlSlick' else 15)
        tt=np.linspace(0,1,n)
        dist=np.linalg.norm(np.diff(sm,axis=0),axis=1);arc=np.r_[0,np.cumsum(dist)];arc/=max(arc[-1],1e-8)
        path=np.array([np.interp(tt,arc,sm[:,a]) for a in range(3)]).T
        widths=np.interp(tt,arc,width)
        copies=2 if name=='CurlRinglets' or (round_no>=2 and name=='CurlUndercoat') else 1
        tone=float(rng.uniform(.82,1.10));bright=rng.random()<(.38 if round_no>=2 else .28)
        tip=linear((203,178,134) if bright and round_no>=2 else ((190,166,124) if bright else (143,111,76)));root=linear((67,49,34))
        if name=='CurlUndercoat':tip=linear((91,68,47))
        for copy in range(copies):
            start=len(verts);column=int(rng.integers(0,8));phase=float(rng.uniform(0,6.28))
            for k,p0 in enumerate(path):
                t=k/(n-1);p=Vector(p0);tan=Vector(path[min(k+1,n-1)]-path[max(k-1,0)]).normalized()
                if round_no>=2:
                    if p.z<1.68 and p.y>.18:
                        p.y=min(p.y,.29+(p.z-1.50)*.10)
                    if name=='CurlUndercoat':p.z=max(1.52,p.z);p.y=min(p.y,.285)
                out=Vector((p.x-.004,p.y-.095,max(.025,p.z-1.72) if round_no>=2 else .04)).normalized()
                out=(out-tan*out.dot(tan)).normalized();across=tan.cross(out).normalized()
                if across.length<.1:across=Vector((1,0,0))
                # Mild independent roll/wave gives loose irregular clumps.
                shift=(copy-.5)*widths[k]*.20 if copies==2 else 0
                p+=across*(shift+.0015*math.sin(t*math.pi*3+phase))*float(smooth(t/.08))
                half=widths[k]*((.31 if copies==2 else .34) if round_no>=2 else (.23 if copies==2 else .31))*(.88-.38*t*t)
                if round_no>=2:
                    lift=.007 if name=='CurlSlick' else .003
                    p+=out*(lift*math.sin(math.pi*t))
                    p+=across*(.003*math.sin(2.6*math.pi*t+phase)*math.sin(math.pi*t))
                    # Crossing ribbons and a gentle roll make a rounded curled
                    # clump instead of two parallel thin curtain strips.
                    roll=(copy-.5)*1.45 if copies==2 else .3*math.sin(t*math.pi*2+phase)
                    across=(across*math.cos(roll)+out*math.sin(roll)).normalized()
                elif name=='CurlSlick':p+=out*(.0015*math.sin(math.pi*t))
                color=[min(1,(a+(b*tone-a)*float(smooth((t-.1)/.75)))) for a,b in zip(root,tip)]
                for side in [-1,1]:
                    verts.append(tuple(p+across*half*side));uvs.append(((column+.5+.44*side)/8,1-t));colors.append(color+[t])
                if k:
                    a=start+(k-1)*2;faces.append((a,a+1,a+3,a+2))
    return hair_mesh(name,verts,faces,uvs,colors,arm)

def hair_mesh(name,verts,faces,uvs,colors,arm):
    old=bpy.data.objects.get(name)
    if old:
        previous=old.data;bpy.data.objects.remove(old,do_unlink=True)
        if previous.users==0:bpy.data.meshes.remove(previous)
    mesh=bpy.data.meshes.new('Kenny'+name+'Mesh');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.parent=arm
    obj.matrix_parent_inverse=arm.matrix_world.inverted();mod=obj.modifiers.new('Armature','ARMATURE');mod.object=arm
    uv=mesh.uv_layers.new(name='UVMap');col=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
    for i,c in enumerate(colors):col.data[i].color=c
    for f in mesh.polygons:
        f.use_smooth=True
        for li in f.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
    groups={}
    for i,p in enumerate(verts):
        for bone,w in hair_weights(Vector(p)):
            if w>.00001:
                if bone not in groups:groups[bone]=obj.vertex_groups.new(name=bone)
                groups[bone].add([i],w,'REPLACE')
    return obj

def make_curled_hair(name,guides,arm,round_no=3):
    """Root-anchored loose three-dimensional curls, not crimped donor ribbons."""
    rng=np.random.default_rng(140317+HAIR.index(name));verts=[];faces=[];uvs=[];colors=[]
    # Main card roots have sway alpha zero. Legacy flyaways start at .6 and
    # were incorrectly expanded into long bright horizontal R1/R2 whiskers.
    primary=[g for g in guides if g[0][0]<.12 and len(g)>3]
    limit={'CurlRinglets':220,'CurlSlick':216 if round_no>=6 else 220,'CurlUndercoat':24}[name]
    if len(primary)>limit:primary=[primary[i] for i in np.linspace(0,len(primary)-1,limit,dtype=int)]
    cap_bvh=None;head_bvh=None
    if round_no>=6 and name=='CurlSlick':
        cap=bpy.data.objects['Seed_CurlCap'];cap_bvh=BVHTree.FromPolygons([cap.matrix_world@v.co for v in cap.data.vertices],[list(p.vertices) for p in cap.data.polygons],all_triangles=True)
        body=bpy.data.objects['Body'];head_bvh=BVHTree.FromPolygons([body.matrix_world@v.co for v in body.data.vertices],
            [list(p.vertices) for p in body.data.polygons if body.data.materials[p.material_index].name==HEAD],all_triangles=True)
    def close_to(p,bvh,offset):
        q,n,index,distance=bvh.find_nearest(Vector(p))
        if q is None:return p
        if n.dot(q-Vector((.004,.095,1.70)))<0:n=-n
        return np.array(q+n*offset)
    def append_path(path,radius,column,tip,profile=3,wisp=False):
        start=len(verts);n=len(path);root=np.array(linear((65,49,36)))
        for k,point in enumerate(path):
            t=k/(n-1);p=Vector(point);tan=Vector(path[min(k+1,n-1)]-path[max(k-1,0)]).normalized()
            out=Vector((p.x-.004,p.y-.095,max(.02,p.z-1.72))).normalized()
            out=(out-tan*out.dot(tan)).normalized();across=tan.cross(out).normalized()
            if across.length<.1:across=Vector((1,0,0))
            r=radius*(.72+.28*math.sin(math.pi*t))*(1-.78*float(smooth((t-.70)/.30)))
            color=np.clip(root+(np.array(tip)-root)*float(smooth((t-.12)/.72)),0,1)
            for c in range(profile):
                u=c/(profile-1);angle=(u-.5)*math.pi
                q=p+across*(r*math.sin(angle))+out*(r*.65*math.cos(angle) if profile==3 else 0)
                # Actual prior-owner silhouette bounds, applied to physical hair
                # geometry rather than relaxing the acceptance test.
                q.x=max(-.128,min(.128,q.x));q.z=max(1.435,q.z)
                verts.append(tuple(q));uvs.append(((column+.07+.86*u)/8,1-t));colors.append(list(color)+[t])
            if k:
                a=start+(k-1)*profile;b=a+profile
                for c in range(profile-1):faces.append((a+c,a+c+1,b+c+1,b+c))
    for gi,guide in enumerate(primary):
        raw=np.array([r[1] for r in guide]);arc=np.r_[0,np.cumsum(np.linalg.norm(np.diff(raw,axis=0),axis=1))]
        length=arc[-1]
        if length<.025:continue
        arc/=length
        # Cubic primary mass removes the old faceted wave. A new smooth
        # irregular elliptical curl is authored about the falling guide.
        controls=np.array([[np.interp(t,arc,raw[:,a]) for a in range(3)] for t in [0,.33,.67,1]])
        for p in controls[1:]:
            p[0]=np.clip(p[0],-.119,.119);p[1]=min(p[1],.267)
        if name=='CurlUndercoat':controls[1:,2]=np.maximum(controls[1:,2],1.53);controls[1:,1]=np.minimum(controls[1:,1],.258)
        crown=name=='CurlSlick';n=20 if crown else (25 if name=='CurlRinglets' else 18)
        tt=np.linspace(0,1,n);path=[];phase=float(rng.uniform(0,math.tau))
        turns=float(rng.uniform(.65,1.15) if crown else rng.uniform(1.20,2.15))
        amplitude=float(rng.uniform(.0035,.0070) if crown else rng.uniform(.0045,.0085))
        radial=Vector((controls[0,0]-.004,controls[0,1]-.095,.0)).normalized()
        side=Vector((radial.y,-radial.x,0));out=np.array(radial)
        if crown:out=np.array([radial.x*.35,radial.y*.35,.9]);out/=np.linalg.norm(out)
        side=np.array(side)
        for t in tt:
            p=(1-t)**3*controls[0]+3*(1-t)**2*t*controls[1]+3*(1-t)*t*t*controls[2]+t**3*controls[3]
            angle=phase+math.tau*turns*(t+.035*math.sin(math.pi*t))
            ease=float(smooth(t/.11));amp=amplitude*(.85+.15*math.sin(math.pi*t))*ease
            p+=side*amp*(math.sin(angle)-math.sin(phase))
            p+=out*amp*.65*(math.cos(angle)-math.cos(phase))
            if crown:p+=out*.007*math.sin(math.pi*t)
            if round_no>=6 and crown:p=close_to(p,cap_bvh,.003+.003*math.sin(math.pi*t))
            p[0]=np.clip(p[0],-.123,.123);p[1]=min(p[1],.274);p[2]=max(1.445,p[2]);path.append(p)
        path=np.array(path);bright=rng.random()<.38;tone=float(rng.uniform(.86,1.08))
        tip=np.array(linear((201,181,145) if bright else (147,121,93)))*tone
        if name=='CurlUndercoat':tip=np.array(linear((94,72,51)))
        radius=float(rng.uniform(.0035,.0050) if not crown else rng.uniform(.0025,.0043))
        profile=3 if not crown or gi<140 else 2
        append_path(path,radius,int(rng.integers(0,8)),tip,profile)
        # A handful of short downward wisps from real clumps; no regularly
        # spaced lateral extension. They share the primary curl, not a straight
        # outward ray, and occupy a small fraction of the geometry budget.
        if name=='CurlRinglets' and gi%20==0:
            wisp=path[len(path)//3:].copy();wisp[:,0]+=.002*math.sin(phase)
            append_path(wisp,.00065,int(rng.integers(0,8)),tip*1.04,2,True)
    if round_no>=6 and name=='CurlSlick':
        roots=np.array([g[0][1] for g in primary]);near=np.argsort(np.linalg.norm(roots-np.array([-.040,.025,1.815]),axis=1))[:3]
        for j,index in enumerate(near):
            ctrl=np.array([roots[index],[-.062+(j-1)*.002,.018,1.818],[-.095+(j-1)*.002,.010,1.780],[-.084+(j-1)*.002,.008,1.748]])
            for f in range(2):
                path=[]
                for t in np.linspace(0,1,22):
                    p=(1-t)**3*ctrl[0]+3*(1-t)**2*t*ctrl[1]+3*(1-t)*t*t*ctrl[2]+t**3*ctrl[3]
                    p+=np.array([.0015*math.sin(t*math.pi*2+j+f),0,0])*math.sin(math.pi*t)
                    path.append(close_to(p,head_bvh,.0035))
                append_path(np.array(path),.0015,int(rng.integers(0,8)),linear((173,149,115)),2)
    return hair_mesh(name,verts,faces,uvs,colors,arm)

def make_grouped_hair(name,guides,arm,round_no):
    """Fine separated bundles on grouped curls with continuous transport frames."""
    rng=np.random.default_rng(140421+HAIR.index(name));verts=[];faces=[];uvs=[];colors=[]
    candidates=[g for g in guides if g[0][0]<.12 and len(g)>3]
    roots=np.array([g[0][1] for g in candidates]);selected=[]
    limit={'CurlSlick':28,'CurlRinglets':140 if round_no>=5 else 160,'CurlUndercoat':16}[name]
    cap_bvh=None;head_bvh=None
    if name=='CurlSlick' and round_no>=5:
        cap=bpy.data.objects['Seed_CurlCap'];cap_bvh=BVHTree.FromPolygons([cap.matrix_world@v.co for v in cap.data.vertices],[list(p.vertices) for p in cap.data.polygons],all_triangles=True)
        body=bpy.data.objects['Body'];head_bvh=BVHTree.FromPolygons([body.matrix_world@v.co for v in body.data.vertices],
            [list(p.vertices) for p in body.data.polygons if body.data.materials[p.material_index].name==HEAD],all_triangles=True)
    def on_surface(p,bvh,height):
        q,n,index,distance=bvh.find_nearest(Vector(p))
        if q is None:return p
        outward=q-Vector((.004,.095,1.70))
        if n.dot(outward)<0:n=-n
        return np.array(q+n*height)
    if name=='CurlSlick':
        selected=[int(np.argmin(np.linalg.norm(roots-np.array([-.020,.035,1.815]),axis=1)))]
        while len(selected)<min(limit,len(candidates)):
            distance=np.min(np.linalg.norm(roots[:,None,:]-roots[selected][None,:,:],axis=2),axis=1)
            distance[selected]=-1;selected.append(int(np.argmax(distance)))
    else:selected=list(np.linspace(0,len(candidates)-1,min(limit,len(candidates)),dtype=int))

    def ribbon(path,half,column,tip,phase):
        n=len(path);start=len(verts);last=None
        for k,p0 in enumerate(path):
            t=k/(n-1);p=Vector(p0);tan=Vector(path[min(k+1,n-1)]-path[max(k-1,0)]).normalized()
            if last is None:last=Vector((p.x-.004,p.y-.095,max(.03,p.z-1.72))).normalized()
            out=last-tan*last.dot(tan)
            if out.length<.01:out=tan.cross(Vector((1,0,0)))
            out.normalize();last=out;across=tan.cross(out).normalized()
            roll=.18*math.sin(t*math.pi*1.3+phase);across=(across*math.cos(roll)+out*math.sin(roll)).normalized()
            width=half*(.78+.22*math.sin(math.pi*t))*(1-.72*float(smooth((t-.72)/.28)))
            mix=float(smooth((t-.26)/.66));root=np.array(linear((62,47,35)));color=root+(np.array(tip)-root)*mix
            for side in [-1,1]:
                q=p+across*width*side;q.x=np.clip(q.x,-.128,.128);q.z=max(1.435,q.z)
                verts.append(tuple(q));uvs.append(((column+.5+.45*side)/8,1-t));colors.append(list(np.clip(color,0,1))+[t])
            if k:
                a=start+(k-1)*2;faces.append((a,a+1,a+3,a+2))

    def bundle(controls,kind,fibres,steps,phase,amp,turns,tip):
        tt=np.linspace(0,1,steps);path=[];axis=Vector((controls[0,0]-.004,controls[0,1]-.095,.02)).normalized()
        side=np.array([axis.y,-axis.x,0]);out=np.array(axis)
        if kind=='crown':out=np.array([axis.x*.25,axis.y*.25,.94]);out/=np.linalg.norm(out)
        for t in tt:
            p=(1-t)**3*controls[0]+3*(1-t)**2*t*controls[1]+3*(1-t)*t*t*controls[2]+t**3*controls[3]
            angle=phase+math.tau*turns*(t+.055*math.sin(math.pi*t));ease=float(smooth(t/.12))
            p+=side*amp*(math.sin(angle)-math.sin(phase))*ease
            p+=out*amp*.65*(math.cos(angle)-math.cos(phase))*ease
            if round_no>=5 and kind=='crown':p=on_surface(p,cap_bvh,.0025+.0035*math.sin(math.pi*t))
            if round_no>=5 and kind=='forelock':p=on_surface(p,head_bvh,.003+.002*math.sin(math.pi*t))
            p[0]=np.clip(p[0],-.123,.123);p[1]=min(p[1],.273);p[2]=max(1.445,p[2]);path.append(p)
        path=np.array(path)
        for f in range(fibres):
            angle=phase+f*math.tau/fibres;offset=side*math.sin(angle)+out*math.cos(angle)
            perturb=np.sin(tt*math.pi)[:,None]*offset[None,:]*float(rng.uniform(.0007,.0020))
            fibre_path=path+perturb
            if round_no>=5 and kind=='crown':
                fibre_path=np.array([on_surface(p,cap_bvh,.0025+.0035*math.sin(math.pi*t)) for p,t in zip(fibre_path,tt)])
            ribbon(fibre_path,float(rng.uniform(.0009,.0017)),int(rng.integers(0,8)),np.array(tip)*float(rng.uniform(.90,1.06)),phase+f)

    for gi,index in enumerate(selected):
        raw=np.array([r[1] for r in candidates[index]]);arc=np.r_[0,np.cumsum(np.linalg.norm(np.diff(raw,axis=0),axis=1))];arc/=max(arc[-1],1e-8)
        ctrl=np.array([[np.interp(t,arc,raw[:,a]) for a in range(3)] for t in [0,.33,.67,1]])
        for p in ctrl[1:]:p[0]=np.clip(p[0],-.117,.117);p[1]=min(p[1],.265)
        crown=name=='CurlSlick';kind='crown' if crown else 'falling'
        if crown:
            side=-1 if ctrl[0,0]<-.015 else 1
            ctrl[1]=ctrl[0]+np.array([side*.018,.025,.013]);ctrl[2]=(ctrl[1]+ctrl[3])*.5+np.array([0,.006,.008])
        if name=='CurlUndercoat':ctrl[1:,2]=np.maximum(ctrl[1:,2],1.53)
        bright=rng.random()<.33;tip=linear((188,169,137) if bright else (141,116,90))
        if name=='CurlUndercoat':tip=linear((86,66,48))
        bundle(ctrl,kind,6 if crown else (3 if name=='CurlRinglets' else 2),22 if crown else (30 if name=='CurlRinglets' else 19),
               float(rng.uniform(0,math.tau)),float(rng.uniform(.007,.013)),float(rng.uniform(.45,1.55) if crown else rng.uniform(.8,2.65)),tip)
    if name=='CurlSlick':
        if round_no>=5:
            # A distinct near-scalp coverage layer, spread between hero groups.
            # It follows the owned growth paths and has its own dark-root tone.
            for j,index in enumerate(np.linspace(0,len(candidates)-1,95,dtype=int)):
                raw=np.array([r[1] for r in candidates[index]]);arc=np.r_[0,np.cumsum(np.linalg.norm(np.diff(raw,axis=0),axis=1))];arc/=max(arc[-1],1e-8)
                path=[]
                for t in np.linspace(0,1,14):
                    p=np.array([np.interp(t,arc,raw[:,a]) for a in range(3)])
                    path.append(on_surface(p,cap_bvh,.0015+.0010*math.sin(math.pi*t)))
                ribbon(np.array(path),float(rng.uniform(.0018,.0028)),int(rng.integers(0,8)),linear((97,75,53)),j*.77)
        # The reference's asymmetric loose forelock is a deliberate guide group,
        # not a second even comb row around the hairline.
        near=sorted(range(len(candidates)),key=lambda i:np.linalg.norm(roots[i]-np.array([-.040,.025,1.815])))[:5]
        for j,index in enumerate(near):
            root=roots[index];shift=(j-2)*.0025
            ctrl=np.array([root,[-.067+shift,-.009,1.839],[-.103+shift,-.022,1.787],[-.078+shift,-.017,1.743]])
            if round_no>=5:ctrl=np.array([root,[-.062+shift,.018,1.818],[-.095+shift,.010,1.780],[-.084+shift,.008,1.748]])
            bundle(ctrl,'forelock',3,22,1.3+j*.8,.0055,.85+j*.07,linear((178,153,119)))
        text('KennyGroomRound'+str(round_no),{'crown_groups':selected,'forelock_root_indices':near,
             'design':'Grouped dark-root fibres, internal strand gaps, continuous transport frames and asymmetric forelock.'})
    return hair_mesh(name,verts,faces,uvs,colors,arm)

def restore_cap(round_no):
    obj=bpy.data.objects['CurlCap'];previous=obj.data;obj.data=bpy.data.objects['Seed_CurlCap'].data.copy()
    if previous.users==0:bpy.data.meshes.remove(previous)
    obj.data.name='KennyCurlCapMesh'
    if round_no>=2:
        # Opaque coverage belongs to the skull, not a broad sheet at the nape.
        # The shortened base is covered by layered alpha clumps down to shoulders.
        bm=bmesh.new();bm.from_mesh(obj.data)
        remove=[f for f in bm.faces if (obj.matrix_world@f.calc_center_median()).z<1.595 and (obj.matrix_world@f.calc_center_median()).y>.14]
        bmesh.ops.delete(bm,geom=remove,context='FACES')
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS');bm.to_mesh(obj.data);bm.free();obj.data.update()
    if round_no>=5:
        attr=obj.data.color_attributes.active_color;base=np.array(linear((66,50,36)))
        for i,item in enumerate(attr.data):
            vi=i if attr.domain=='POINT' else obj.data.loops[i].vertex_index;p=obj.data.vertices[vi].co
            variation=1+.045*math.sin(p.x*63+p.y*21+p.z*37)
            item.color=list(base*variation)+[1]

def hair_material(obj):
    mat=bpy.data.materials.get('Kenny_'+obj.name) or bpy.data.materials.new('Kenny_'+obj.name);mat.use_nodes=True
    nt=mat.node_tree;nt.nodes.clear();out=nt.nodes.new('ShaderNodeOutputMaterial');bsdf=nt.nodes.new('ShaderNodeBsdfPrincipled')
    vc=nt.nodes.new('ShaderNodeVertexColor');vc.layer_name=obj.data.color_attributes.active_color.name
    if obj.name=='CurlCap' and int(bpy.context.scene.get('kenny_round',0))>=5:
        nt.links.new(vc.outputs['Color'],bsdf.inputs['Base Color']);bsdf.inputs['Roughness'].default_value=.85;bsdf.inputs['Specular IOR Level'].default_value=.04
        nt.links.new(bsdf.outputs[0],out.inputs[0]);obj.data.materials.clear();obj.data.materials.append(mat);return
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images['Map::kenny_curl_cards.png']
    mul=nt.nodes.new('ShaderNodeMixRGB');mul.blend_type='MULTIPLY';mul.inputs[0].default_value=1
    nt.links.new(tex.outputs['Color'],mul.inputs[1]);nt.links.new(vc.outputs['Color'],mul.inputs[2]);nt.links.new(mul.outputs[0],bsdf.inputs['Base Color'])
    if obj.name!='CurlCap':nt.links.new(tex.outputs['Alpha'],bsdf.inputs['Alpha'])
    bsdf.inputs['Roughness'].default_value=.75;bsdf.inputs['Specular IOR Level'].default_value=.12
    nt.links.new(bsdf.outputs[0],out.inputs[0]);mat.surface_render_method='DITHERED';mat.use_backface_culling=False
    obj.data.materials.clear();obj.data.materials.append(mat)

def audit():
    body=bpy.data.objects['Body'];arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    bind=data('KennyBind');assert len(arm.data.bones)==len(bind['bones'])==67
    assert len(body.data.vertices)==bind['body_vertices'];assert not body.data.shape_keys
    meshes=[body]+[bpy.data.objects[n] for n in HAIR]
    counts={o.name:sum(len(f.vertices)-2 for f in o.data.polygons) for o in meshes}
    assert sum(counts.values())<=112714,counts
    for o in meshes:
        assert all(v.groups for v in o.data.vertices),o.name
    hair_points=np.array([game(o.matrix_world@v.co)[:] for o in meshes if o.name in ['CurlSlick','CurlRinglets'] for v in o.data.vertices])
    xs=np.sort(hair_points[(hair_points[:,1]>1.62)&(hair_points[:,1]<1.72),0]);width=float(xs[int(len(xs)*.98)]-xs[int(len(xs)*.02)])
    lowest=float(hair_points[:,1].min())
    if int(bpy.context.scene.get('kenny_round',0))>=3:
        assert width<.27,('hair width',width)
        assert lowest>1.40,('hair floor',lowest)
    print('KENNY_AUDIT',json.dumps({'triangles':counts,'total':sum(counts.values()),'bones':67,'body_materials':len(body.data.materials),'face_baked':True,'bulk_baked':False,'hair_ear_width_p02_p98_m':width,'lowest_hair_m':lowest,'native_bytes':NATIVE.stat().st_size if NATIVE.exists() else 0}))
    return counts

def identity_audit(path):
    body=bpy.data.objects['Body'];seed=bpy.data.objects['Seed_Body'];arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    own=data('KennyBind');mw=body.matrix_world;sw=seed.matrix_world
    now=np.array([game(mw@v.co)[:] for v in body.data.vertices]);old=np.array([game(sw@v.co)[:] for v in seed.data.vertices])
    delta=np.linalg.norm(now-old,axis=1)
    def ids(mat):return sorted({v for f in body.data.polygons if body.data.materials[f.material_index].name==mat for v in f.vertices})
    head=ids(HEAD);eyes=ids(EYE);neck=[i for i in head if old[i,1]<1.575]
    def stats(which):
        a=delta[which]
        return {'vertices':len(which),'changed_vertices':int(np.count_nonzero(a>1e-7)),
                'maximum_delta_m':float(a.max()) if len(a) else 0,'rms_delta_m':float(np.sqrt(np.mean(a*a))) if len(a) else 0}
    bone_delta=max(abs(arm.data.bones[b['name']].matrix_local[i][j]-b['matrix'][i][j]) for b in own['bones'] for i in range(4) for j in range(4))
    parent_ok=all((arm.data.bones[b['name']].parent.name if arm.data.bones[b['name']].parent else None)==b['parent'] for b in own['bones'])
    def weights(o):return [[(g.group,round(float(g.weight),8)) for g in v.groups] for v in o.data.vertices]
    result={'authority':'tools/blender/characters/Kenny.blend','round':int(bpy.context.scene['kenny_round']),
            'comparison':'Current native Body against frozen owned Seed_Body; no donor file input.',
            'historical_provenance':data('SeedManifest')['historical_donor'],
            'body_vertices':len(now),'face':stats(head),'protected_neck_below_y_m':1.575,'protected_neck':stats(neck),
            'eye_geometry':stats(eyes),'bones':len(own['bones']),'bone_bind_max_delta':bone_delta,'bone_parent_identity':parent_ok,
            'body_weight_identity':weights(body)==weights(seed),'exported_face_baked':True,'runtime_bulk_baked':False,
            'canonical_seed_maps_packed':all(seed_image(n).packed_file is not None for n in data('SeedManifest')['maps']),
            'material_keys':[m.name for m in body.data.materials]}
    path=pathlib.Path(path);path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(result,indent=2)+'\n')
    print('KENNY_IDENTITY_AUDIT',json.dumps(result))

def normal_audit(path):
    body=bpy.data.objects['Body'];mesh=body.data;vn=np.zeros((len(mesh.vertices),3));count=np.zeros(len(vn))
    for l,n in zip(mesh.loops,mesh.corner_normals):vn[l.vertex_index]+=n.vector;count[l.vertex_index]+=1
    vn/=np.maximum(np.linalg.norm(vn,axis=1)[:,None],1e-12)
    positions=np.array([game(body.matrix_world@v.co)[:] for v in mesh.vertices]);report={}
    for name in [HEAD,'xmaterial_5a329cd32db96c3','xmaterial_90b39911eb484a2','xmaterial_90b2b911eb46cd8']:
        ids={v for f in mesh.polygons if mesh.materials[f.material_index].name==name for v in f.vertices};groups={}
        for i in ids:groups.setdefault(tuple(np.round(positions[i],5)),[]).append(i)
        dots=[float(np.min(vn[g]@vn[g].T)) for g in groups.values() if len(g)>1]
        report[name]={'duplicate_groups':len(dots),'divergent_over_20_degrees':sum(x<math.cos(math.radians(20)) for x in dots),
                      'divergent_over_45_degrees':sum(x<math.cos(math.radians(45)) for x in dots),'minimum_dot':min(dots) if dots else 1}
    report['has_authored_split_normals']=mesh.has_custom_normals
    path=pathlib.Path(path);path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(report,indent=2)+'\n');print('KENNY_NORMAL_AUDIT',json.dumps(report))

def export():
    arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    for name,key in data('KennyOutputMaps').items():(CHAR/name).write_bytes(bytes(bpy.data.images[key].packed_file.data))
    for names,path,mats in [(['Body'],'kenny_body.glb','EXPORT'),(HAIR,'kenny_curls.glb','PLACEHOLDER')]:
        bpy.ops.object.select_all(action='DESELECT');arm.select_set(True)
        for name in names:bpy.data.objects[name].select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(CHAR/path),export_format='GLB',use_selection=True,export_skins=True,
            export_animations=False,export_morph=False,export_materials=mats,export_vertex_color='ACTIVE',export_yup=True,
            export_tangents=True)

def build(round_no):
    bpy.ops.wm.open_mainfile(filepath=str(NATIVE));round_no=round_no or int(bpy.context.scene.get('kenny_round',1))
    art_body(round_no)
    # R7 is a geometry-only clay stage. Existing packed R6 pigment and groom
    # remain unchanged until the neutral head's shape passes the visual gate.
    if round_no<7:art_maps(round_no)
    elif bpy.data.texts.get('KennySurfaceSource'):
        # The optional photo-authoring recipe creates this packed owned map.
        # Normal regeneration never reopens the reference photo or game output.
        outputs=data('KennyOutputMaps');outputs['kenny_head.png']=data('KennySurfaceSource')['packed_head_map'];text('KennyOutputMaps',outputs)
    bpy.context.scene['kenny_round']=round_no
    arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    if round_no<=7:
        # R7 is the canonical head + retained R6 groom. Reconstruct that owned
        # comparison explicitly even after the editable R8 groom was authored.
        for name,guides in data('KennyGuideSeed').items():make_hair(name,guides,arm,min(round_no,6))
        restore_cap(round_no)
        if round_no==7:
            outputs=data('KennyOutputMaps');outputs['kenny_curl_cards.png']='Map::kenny_curl_cards.png';text('KennyOutputMaps',outputs)
    elif round_no>=8:
        source_directory=str(pathlib.Path(__file__).resolve().parent)
        if source_directory not in sys.path:sys.path.insert(0,source_directory)
        import kenny_hero_groom
        restore_cap(round_no);kenny_hero_groom.build(sys.modules[__name__])
    for mat in bpy.data.objects['Body'].data.materials:
        name=SKIN.get(mat.name,GEAR.get(mat.name,'kenny_eye_color.png' if mat.name==EYE else ''))
        if name:material_image(mat,bpy.data.images[data('KennyOutputMaps')[name]])
    for name in HAIR:hair_material(bpy.data.objects[name])
    if round_no>=8:
        for name in ['CurlSlick','CurlRinglets','CurlUndercoat']:
            for node in bpy.data.objects[name].data.materials[0].node_tree.nodes:
                if node.type=='TEX_IMAGE':node.image=bpy.data.images[data('KennyHeroGroom')['atlas']]
    bpy.context.scene['kenny_round']=round_no;bpy.context.scene['kenny_face_baked']=True
    audit();identity_audit(evidence_dir(round_no)/'source_identity_audit.json')
    normal_audit(evidence_dir(round_no)/'source_normal_audit.json')
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(NATIVE),compress=True)
    export();audit()
    outputs=[CHAR/'kenny_body.glb',CHAR/'kenny_curls.glb']+[CHAR/n for n in data('KennyOutputMaps')]
    text_report={'round':round_no,'expected_game_outputs':{str(p.relative_to(ROOT)):sha(p) for p in outputs}}
    (evidence_dir(round_no)/'source_rebuild_fingerprints.json').write_text(json.dumps(text_report,indent=2)+'\n')

def review(out_dir):
    # Native preview only; game captures remain the acceptance evidence. Apply
    # live skin tint for this unsaved scene, never to exported pixels/factors.
    bpy.ops.wm.open_mainfile(filepath=str(NATIVE));out_dir=pathlib.Path(out_dir);out_dir.mkdir(parents=True,exist_ok=True)
    for mat in bpy.data.objects['Body'].data.materials:
        if mat.name not in SKIN:continue
        nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF');link=bs.inputs['Base Color'].links[0];source=link.from_socket;nt.links.remove(link)
        mul=nt.nodes.new('ShaderNodeMixRGB');mul.blend_type='MULTIPLY';mul.inputs[0].default_value=1;mul.inputs[2].default_value=(.73,.65,.59,1)
        nt.links.new(source,mul.inputs[1]);nt.links.new(mul.outputs[0],bs.inputs['Base Color']);bs.inputs['Roughness'].default_value=.5
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.render.resolution_x=scene.render.resolution_y=720;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
    world=bpy.data.worlds.new('KennyReviewWorld');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.035,.04,1);scene.world=world
    for name,loc,power,size in [('Key',(-1,-1.5,2.4),350,1.2),('Fill',(1,-1,1.8),150,1.4),('Rim',(0,1,2.1),180,1)]:
        light=bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size
        obj=bpy.data.objects.new(name,light);scene.collection.objects.link(obj);obj.location=loc;obj.rotation_euler=(Vector((0,0,1.7))-obj.location).to_track_quat('-Z','Y').to_euler()
    cam=bpy.data.objects.new('KennyReviewCamera',bpy.data.cameras.new('KennyReviewCamera'));scene.collection.objects.link(cam);scene.camera=cam;cam.data.lens=85
    for label,yaw in [('front',0),('three_quarter',40),('profile',90)]:
        a=math.radians(yaw);target=Vector((.004,-.02,1.70));cam.location=target+Vector((math.sin(a),-math.cos(a),0))*.95
        cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out_dir/('kenny_'+label+'.png'));bpy.ops.render.render(write_still=True)

def main():
    global AUDIT_OVERRIDE
    p=argparse.ArgumentParser();p.add_argument('action',choices=['bootstrap','capture-parity','validate-parity','build','groom-author','surface-author','surface-boundary','audit','identity-audit','export','review']);p.add_argument('--round',type=int);p.add_argument('--out',default='/tmp/kenny-owned-review');p.add_argument('--owned-baseline',default='/tmp/kenny-owned-baseline.glb');p.add_argument('--audit-out')
    a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    AUDIT_OVERRIDE=a.audit_out
    if a.action=='bootstrap':bootstrap()
    elif a.action=='capture-parity':capture_parity(a.owned_baseline)
    elif a.action=='validate-parity':
        bpy.ops.wm.open_mainfile(filepath=str(NATIVE));art_body(2)
        normal_audit('/tmp/kenny-parity-normal-audit.json');identity_audit('/tmp/kenny-parity-identity-audit.json')
    elif a.action=='build':build(a.round)
    elif a.action=='groom-author':
        bpy.ops.wm.open_mainfile(filepath=str(NATIVE))
        source_directory=str(pathlib.Path(__file__).resolve().parent)
        if source_directory not in sys.path:sys.path.insert(0,source_directory)
        import kenny_hero_groom
        kenny_hero_groom.author(sys.modules[__name__])
        bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(NATIVE),compress=True)
        build(a.round or 8)
    elif a.action in ['surface-author','surface-boundary']:
        bpy.ops.wm.open_mainfile(filepath=str(NATIVE))
        source_directory=str(pathlib.Path(__file__).resolve().parent)
        if source_directory not in sys.path:sys.path.insert(0,source_directory)
        import kenny_reference_surface
        (kenny_reference_surface.author if a.action=='surface-author' else kenny_reference_surface.boundaries)(sys.modules[__name__])
        bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(NATIVE),compress=True)
        build(a.round or 7)
    elif a.action=='review':review(a.out)
    elif a.action=='identity-audit':bpy.ops.wm.open_mainfile(filepath=str(NATIVE));identity_audit(evidence_dir()/'source_identity_audit.json')
    elif a.action=='export':bpy.ops.wm.open_mainfile(filepath=str(NATIVE));audit();export()
    else:bpy.ops.wm.open_mainfile(filepath=str(NATIVE));audit()
if __name__=='__main__':main()
