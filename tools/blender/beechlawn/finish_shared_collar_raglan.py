"""Fit the shared V binding and surface-skinned raglan trim in place.

Read-only audit unless --preview PATH or --apply. Existing rig uses cm/Y-up.
"""
from pathlib import Path
import argparse, hashlib, json, math, sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from repair_shared_kit import SOURCE, export_current, garment_loop, smooth
from refine_shared_shoulders import folds, POSES
SHIRTS = ('YBot_Surface', 'Kit_Shirt_ShortSleeve')
BINDING = 'Kit_Shane_ContinuousVBinding'
OUT = ROOT/'games/beechlawn_rovers/docs/art_briefs/shared_collar_raglan'
LAYOUT = json.loads((ROOT/'games/beechlawn_rovers/assets/characters/textures/beechlawn_home_tailored_atlas_layout.json').read_text())['rects']


def protected_state(rig):
    data = [('rig', [(b.name, list(map(list, b.matrix_local))) for b in rig.data.bones])]
    for action in sorted(bpy.data.actions, key=lambda a:a.name):
        data.append((action.name, [(f.data_path, f.array_index, [(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in f.keyframe_points]) for f in action.fcurves]))
    for obj in sorted((o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name != BINDING),key=lambda o:o.name):
        mesh=obj.data
        record=[obj.name,[tuple(p.vertices) for p in mesh.polygons],
                [tuple(v.uv) for v in mesh.uv_layers.active.data],
                [[(obj.vertex_groups[g.group].name,g.weight) for g in v.groups] for v in mesh.vertices]]
        if obj.name not in SHIRTS:
            record += [[tuple(v.co) for v in mesh.vertices],[tuple(n.vector) for n in mesh.corner_normals]]
        data.append(record)
    return hashlib.sha256(repr(data).encode()).hexdigest()


def tree_for(obj):
    mesh=obj.data;mesh.calc_loop_triangles()
    triangles=[tuple(t.vertices) for t in mesh.loop_triangles]
    return BVHTree.FromPolygons([v.co for v in mesh.vertices],triangles,all_triangles=True),triangles


def normalize(values):
    top=sorted(((n,w) for n,w in values.items() if w>1e-8),key=lambda p:p[1],reverse=True)[:4]
    total=sum(w for _,w in top)
    assert total>0
    return {n:w/total for n,w in top}


def weights(obj, ids, factors):
    values={}
    for i,factor in zip(ids,factors):
        for g in obj.data.vertices[i].groups:
            name=obj.vertex_groups[g.group].name
            values[name]=values.get(name,0)+g.weight*max(0,factor)
    return normalize(values)


def nearest_weights(obj, triangles, point, index):
    ids=triangles[index];a,b,c=[obj.data.vertices[i].co for i in ids]
    factors=barycentric_transform(point,a,b,c,Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1)))
    return weights(obj,ids,factors)


def neck_point(angle, distance=0):
    front=smooth(0,.35,math.cos(angle))
    y=152.05*(1-front)+(147.25+4.8*abs(math.sin(angle)))*front
    return Vector(((7.45+.65*distance)*math.sin(angle),y-.75*distance,
                   -1.75+(7.40+.65*distance)*math.cos(angle)))


def fit_neckline(obj):
    loop=garment_loop(obj);mesh=obj.data
    original=[v.co.copy() for v in mesh.vertices]
    moved=0;maximum=0
    # A sewn collar needs a smooth supporting yoke, not just a smooth hole.
    # Loft the first 1.2 cm of cloth from the new opening; blend back to the
    # existing shirt over the next 2 cm. Keep outer shoulders/torso pinned.
    for vertex in mesh.vertices:
        p=original[vertex.index]
        if abs(p.x)>13 or p.y<143 or p.y>155:continue
        distance=min((p-original[i]).length for i in loop)
        blend=1-smooth(1.2,3.2,distance)
        target=neck_point(math.atan2(p.x,p.z+1.75),distance)
        shift=(target-p)*blend
        if shift.length>1e-6:
            vertex.co+=shift;moved+=1;maximum=max(maximum,shift.length)
    mesh.update()
    return loop,{'moved_vertices':moved,'maximum_displacement_cm':round(maximum,5)}


def clear_covered_yoke(obj):
    points=[];triangles=[]
    for name in ('Skin_Head','YBot_Joints'):
        mesh=bpy.data.objects[name].data;mesh.calc_loop_triangles();offset=len(points)
        points += [v.co.copy() for v in mesh.vertices]
        triangles += [tuple(offset+i for i in t.vertices) for t in mesh.loop_triangles]
    skin=BVHTree.FromPolygons(points,triangles,all_triangles=True)
    moved=0;maximum=0
    for v in obj.data.vertices:
        if not(8<abs(v.co.x)<18 and 143<v.co.y<155):continue
        hit,n,_,distance=skin.find_nearest(v.co)
        clearance=(v.co-hit).dot(n)
        if distance<2.5 and clearance<.25:
            shift=n*(.25-clearance)
            v.co+=shift;moved+=1;maximum=max(maximum,shift.length)
    obj.data.update()
    return {'vertices':moved,'maximum_displacement_cm':maximum}


def build_trim(obj,loop):
    tree,triangles=tree_for(obj)
    points=[obj.data.vertices[i].co.copy() for i in loop]
    lengths=[0.0]
    for i,p in enumerate(points):lengths.append(lengths[-1]+(points[(i+1)%len(points)]-p).length)
    vertices=[];faces=[];swatches=[];deform=[];normals=[]
    def add(point,normal,groups):
        vertices.append(point);normals.append(normal);deform.append(groups)
        return len(vertices)-1
    def quad(ids,region):
        faces.append(ids);swatches.append(region)
    samples=96;rows=(0,.08,.22,.88,1)
    angles=[]
    for sample in range(samples):
        distance=lengths[-1]*sample/samples
        j=next(j for j in range(len(points)) if lengths[j+1]>=distance)
        t=(distance-lengths[j])/(lengths[j+1]-lengths[j])
        point=points[j].lerp(points[(j+1)%len(points)],t)
        angles.append(math.atan2(point.x,point.z+1.75))
    maximum_gap=0
    for row,t in enumerate(rows):
        for j,angle in enumerate(angles):
            point=neck_point(angle,1.05*t)
            tangent=(neck_point(angle+.002,1.05*t)-neck_point(angle-.002,1.05*t)).normalized()
            across=Vector((.65*math.sin(angle),-.75,.65*math.cos(angle))).normalized()
            normal=tangent.cross(across).normalized()
            if normal.dot(Vector((math.sin(angle),0,math.cos(angle))))<0:normal=-normal
            hit,n,tri,gap=tree.find_nearest(point)
            maximum_gap=max(maximum_gap,gap)
            add(point+normal*(.10+.04*math.sin(math.pi*t)),normal,nearest_weights(obj,triangles,hit,tri))
    for row,region in enumerate(('black','blue','black','black')):
        for j in range(samples):
            quad((row*samples+j,row*samples+(j+1)%samples,(row+1)*samples+(j+1)%samples,(row+1)*samples+j),region)
    collar_vertices=len(vertices)
    # Four raglan strips: front/back of both shoulders, projected onto cloth.
    # The same surface coordinates exist in the long and short shirt variants.
    for front in (True,False):
        for side in (-1,1):
            start=len(vertices);steps=32
            for j in range(steps+1):
                t=j/steps
                x=side*(8.55+13.7*t)
                y=150.25-13.85*t+.5*math.sin(math.pi*t)
                tangent=Vector((side*13.7,-13.85+.5*math.pi*math.cos(math.pi*t),0)).normalized()
                across=Vector((-tangent.y,tangent.x,0))
                for offset in (-.27,-.19,.19,.27):
                    p=Vector((x,y,0))+across*offset
                    origin=Vector((p.x,p.y,40 if front else -40))
                    hit,normal,index,_=tree.ray_cast(origin,Vector((0,0,-1 if front else 1)),80)
                    assert hit is not None,('Missing raglan cloth surface',front,side,j,tuple(p))
                    add(hit+normal*.11,normal,nearest_weights(obj,triangles,hit,index))
            for j in range(steps):
                for row,region in enumerate(('black','blue','black')):
                    a=start+j*4+row
                    quad((a,a+1,a+5,a+4),region)
    binding=bpy.data.objects[BINDING]
    mesh=bpy.data.meshes.new('Shared_Fitted_VBinding_And_Raglan')
    # Keep each face oriented towards the sampled garment surface normal.
    for i,ids in enumerate(faces):
        a,b,c=[vertices[j] for j in ids[:3]]
        if (b-a).cross(c-a).dot(sum((normals[j] for j in ids),Vector()))<0:
            faces[i]=tuple(reversed(ids))
    mesh.from_pydata(vertices,[],faces);mesh.materials.append(binding.data.materials[0]);mesh.update()
    binding.data=mesh
    binding['collar_vertex_count']=collar_vertices
    layer=mesh.uv_layers.new(name='JerseyUV')
    for poly,region in zip(mesh.polygons,swatches):
        x0,y0,x1,y1=LAYOUT[region]
        coords=[((x0+u*(x1-x0))/2048,1-(y1-v*(y1-y0))/2048) for u,v in ((.25,.25),(.75,.25),(.75,.75),(.25,.75))]
        poly.use_smooth=True
        for li,uv in zip(poly.loop_indices,coords):layer.data[li].uv=uv
    for i,values in enumerate(deform):
        for name,value in values.items():
            group=binding.vertex_groups.get(name) or binding.vertex_groups.new(name=name)
            group.add([i],value,'REPLACE')
    mesh.update();mesh.calc_loop_triangles()
    bad=[(t.index,tuple(t.vertices),t.area) for t in mesh.loop_triangles if t.area<=1e-7]
    assert not bad,('Collapsed trim faces',bad[:12],[(i,tuple(vertices[i])) for i in sorted({i for _,ids,_ in bad for i in ids})])
    return {'collar_samples':samples,'collar_width_cm':1.05,'maximum_collar_surface_gap_cm':maximum_gap,'collar_vertices':collar_vertices,
            'raglan_strips':4,'raglan_steps':32,'raglan_width_cm':.54,
            'trim_triangles':len(mesh.loop_triangles),'minimum_triangle_area_cm2':min(t.area for t in mesh.loop_triangles)}


def runtime_pigment():
    material=bpy.data.objects[SHIRTS[0]].data.materials[0]
    bsdf=material.node_tree.nodes.get('Principled BSDF')
    node=bsdf.inputs['Base Color'].links[0].from_node
    assert node.type=='TEX_IMAGE'
    image=bpy.data.images.load(str(ROOT/'games/beechlawn_rovers/assets/characters/textures/shared/beechlawn_outfield.png'),check_existing=True)
    image.colorspace_settings.name='sRGB';image.pack();node.image=image


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',default=str(SOURCE));p.add_argument('--preview');p.add_argument('--apply',action='store_true')
    args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    assert not(args.preview and args.apply)
    bpy.ops.wm.open_mainfile(filepath=str(Path(args.source).resolve()))
    rig=bpy.data.objects['YBot_Armature']
    if rig.get('collar_raglan_revision')==1:
        print('COLLAR_RAGLAN already applied');return
    assert rig.get('sleeve_fit_revision')==1
    protected=protected_state(rig)
    shirt=bpy.data.objects[SHIRTS[0]];shirt.data.calc_loop_triangles()
    cohort=[t.vertices[:] for t in shirt.data.loop_triangles if 118<sum(shirt.data.vertices[i].co.y for i in t.vertices)/3<151 and max(abs(shirt.data.vertices[i].co.x) for i in t.vertices)<32]
    report={'baseline':'e3f3d12','before':folds(rig,shirt,cohort),'neck_fit':{}}
    rig.animation_data.action=None
    for bone in rig.pose.bones:bone.matrix_basis.identity()
    for name in SHIRTS:
        loop,report['neck_fit'][name]=fit_neckline(bpy.data.objects[name])
        report['neck_fit'][name]['covered_yoke_clearance']=clear_covered_yoke(bpy.data.objects[name])
        if name==SHIRTS[0]:long_loop=loop
    report['trim']=build_trim(shirt,long_loop)
    runtime_pigment()
    report['after']=folds(rig,shirt,cohort)
    trim=bpy.data.objects[BINDING];trim.data.calc_loop_triangles()
    report['trim_poses']=folds(rig,trim,[tuple(t.vertices) for t in trim.data.loop_triangles])
    assert all(v['inverted_triangles']==0 for v in report['trim_poses'].values()),'Trim inverts during fixed poses'
    assert report['trim']['maximum_collar_surface_gap_cm']<.25,'Collar lifts away from supporting cloth'
    assert protected==protected_state(rig),'Protected geometry, skin normals, UVs, weights, rig or clips changed'
    assert sum(v['inverted_triangles'] for v in report['after'].values())<=sum(v['inverted_triangles'] for v in report['before'].values()),'Cloth inversion diagnostic regressed'
    report['protected_sha256']=protected
    report['atlas_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'games/beechlawn_rovers/assets/characters/textures/shared').glob('*.png')}
    report['bones']=len(rig.data.bones);report['clips']=len(bpy.data.actions)
    print('COLLAR_RAGLAN '+json.dumps({'neck_fit':report['neck_fit'],'trim':report['trim'],'folds':{n:[report['before'][n]['inverted_triangles'],report['after'][n]['inverted_triangles']] for n,_ in POSES}}),flush=True)
    rig.animation_data.action=bpy.data.actions['AN_Beechlawn_Idle'];bpy.context.scene.frame_set(1)
    if args.preview or args.apply:rig['collar_raglan_revision']=1
    if args.preview:
        bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(Path(args.preview).resolve()))
        Path(args.preview+'.json').write_text(json.dumps(report,indent=2)+'\n')
    elif args.apply:
        export_current(rig);OUT.mkdir(parents=True,exist_ok=True);(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')

if __name__=='__main__':main()
