"""Reference-led shared shoulder/underarm fit; preserve rig, clips and UV panels.

Read-only audit by default. --preview=/tmp/test.blend writes a review copy.
--apply saves and exports the production source after its preservation gates.
"""
from pathlib import Path
import sys,math,json,hashlib
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from repair_shared_kit import SOURCE,export_current,smooth
OUT=ROOT/'games/beechlawn_rovers/docs/art_briefs/shared_shoulder_fit'
EDITED=('YBot_Surface','Kit_Shirt_ShortSleeve')
POSES=(('Idle',2),('Sprint',10),('PassRight',18),('ShotRight',18),('GroundedSlideTackle',22),('GetUpFromProne',20),('KeeperSet',10),('KeeperSave',18),('Turn90Right',19))

def preserved_rig_and_heads(rig):
    # The covered trapezius on YBot_Joints is the sole skin-body edit;
    # identities, the neck interface and all other anatomy remain protected.
    items=[('rest',[(b.name,list(map(list,b.matrix_local))) for b in rig.data.bones])]
    for a in sorted(bpy.data.actions,key=lambda a:a.name):
        items.append((a.name,[(f.data_path,f.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in f.keyframe_points]) for f in a.fcurves]))
    for o in sorted((o for o in bpy.context.scene.objects if o.type=='MESH' and o.name not in EDITED and o.name!='YBot_Joints'),key=lambda o:o.name):
        items.append((o.name,[tuple(v.co) for v in o.data.vertices],[[tuple(o.data.uv_layers.active.data[i].uv) for i in p.loop_indices] for p in o.data.polygons],[[ (o.vertex_groups[g.group].name,g.weight) for g in v.groups] for v in o.data.vertices]))
    return hashlib.sha256(repr(items).encode()).hexdigest()

def fit_covered_trapezius():
    obj=bpy.data.objects['YBot_Joints'];mesh=obj.data
    seam_coords={tuple(round(c,4) for c in v.co) for v in bpy.data.objects['Skin_Head'].data.vertices if v.co.y<154}
    seam={v.index for v in mesh.vertices if tuple(round(c,4) for c in v.co) in seam_coords}
    assert len(seam)>=30,len(seam)
    retained={i:(tuple(mesh.vertices[i].co),[(g.group,g.weight) for g in mesh.vertices[i].groups]) for i in seam}
    normals=[n.vector.copy() for n in mesh.corner_normals]
    moved=[]
    for v in mesh.vertices:
        ax=abs(v.co.x);y=v.co.y
        if v.index in seam or not (8<ax<36 and 143<y<154):continue
        shift=2.3*math.exp(-((ax-11.5)/8)**2)*smooth(7.8,10.3,ax)*smooth(143,151,y)
        if shift>.0001:v.co.y-=shift;moved.append(v.index)
    mesh.update()
    # Preserve the exact seam shading used by the independent runtime head.
    moved_set=set(moved)
    mesh.normals_split_custom_set([Vector() if loop.vertex_index in moved_set else normals[i] for i,loop in enumerate(mesh.loops)])
    mesh.update()
    seam_error=max((mesh.corner_normals[i].vector-normals[i]).length for i,loop in enumerate(mesh.loops) if loop.vertex_index in seam)
    assert seam_error<.0002,seam_error
    for i,state in retained.items():assert (tuple(mesh.vertices[i].co),[(g.group,g.weight) for g in mesh.vertices[i].groups])==state
    return {'covered_skin_vertices_adjusted':len(moved),'seam_vertices_preserved':len(seam),'maximum_seam_normal_error':seam_error}

def keep_neck_clearance():
    points=[];faces=[]
    for name in ('Skin_Head','YBot_Joints'):
        mesh=bpy.data.objects[name].data;offset=len(points)
        points += [v.co.copy() for v in mesh.vertices]
        mesh.calc_loop_triangles()
        faces += [tuple(offset+i for i in t.vertices) for t in mesh.loop_triangles if all(140<mesh.vertices[i].co.y<155 for i in t.vertices)]
    tree=BVHTree.FromPolygons(points,faces,all_triangles=True);counts={}
    for name in EDITED:
        mesh=bpy.data.objects[name].data;count=0
        for v in mesh.vertices:
            if not (8<abs(v.co.x)<14 and 143<v.co.y<154):continue
            near,normal,index,distance=tree.find_nearest(v.co)
            if near is not None and distance<3.5:
                clearance=(v.co-near).dot(normal)
                if clearance<.3:v.co+=normal*(.3-clearance);count+=1
        mesh.update();counts[name]=count
    return counts


def folds(rig,obj,cohort):
    mesh=obj.data;mesh.calc_loop_triangles()
    triangles=[]
    for ids in cohort:
        a,b,c=[mesh.vertices[i].co for i in ids]
        triangles.append((ids,(b-a).cross(c-a).normalized()))
    result={}
    for clip,frame in POSES:
        rig.animation_data.action=bpy.data.actions['AN_Beechlawn_'+clip];bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());deformed=evaluated.to_mesh()
        transforms={g.index:(rig.pose.bones[g.name].matrix@rig.data.bones[g.name].matrix_local.inverted()).to_3x3() for g in obj.vertex_groups if g.name in rig.pose.bones};bad=0;regions={}
        for ids,normal in triangles:
            a,b,c=[deformed.vertices[i].co for i in ids];actual=(b-a).cross(c-a);expected=Vector()
            for i in ids:
                for g in mesh.vertices[i].groups:
                    if g.group in transforms:expected+=transforms[g.group]@normal*g.weight/3
            if actual.length>1e-7 and expected.length>1e-7 and actual.normalized().dot(expected.normalized())<-.1:
                bad+=1
                centre=sum((mesh.vertices[i].co for i in ids),Vector())/3
                key='%d,%d,%s'%(round(abs(centre.x)/2)*2,round(centre.y/2)*2,'front' if centre.z>0 else 'back')
                regions[key]=regions.get(key,0)+1
        result[clip]={'inverted_triangles':bad,'sampled_triangles':len(triangles),'largest_fold_regions':sorted(regions.items(),key=lambda p:p[1],reverse=True)[:12]}
        evaluated.to_mesh_clear()
    return result

def retune(obj):
    original=[v.co.copy() for v in obj.data.vertices]
    # The old body-derived chest retained a nipple fold under the fabric.
    # Relax its small connected patch in XYZ, with a pinned falloff, so the
    # existing panel maps sit on continuous cloth rather than a body detail.
    bm=bmesh.new();bm.from_mesh(obj.data)
    targets={v:(1-((abs(v.co.x)-12)/4.7)**2-((v.co.y-134)/3.6)**2) for v in bm.verts if v.co.z>7}
    targets={v:max(0,min(1,k)) for v,k in targets.items() if k>0 and not v.is_boundary}
    for _ in range(40):
        averages={v:sum((e.other_vert(v).co for e in v.link_edges),Vector())/len(v.link_edges) for v in targets if v.link_edges}
        for v,average in averages.items():v.co=v.co.lerp(average,.55*targets[v])
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    # Fabric spans the scapulae instead of copying their deep anatomical
    # hollows/bulges. Keep the spine, neck and sleeve tube pinned by falloff.
    for v in obj.data.vertices:
        ax=abs(v.co.x);y=v.co.y
        if not (1<ax<28 and 127<y<154 and v.co.z< -6):continue
        amount=smooth(1,4,ax)*(1-smooth(22,28,ax))*smooth(127,135,y)*(1-smooth(150,154,y))
        envelope=-9.9-.015*(y-138)+.005*ax*ax
        v.co.z+=max(0,envelope-v.co.z)*amount
    count=0;max_shift=0
    for v in obj.data.vertices:
        x,y,z=v.co;ax=abs(x)
        if not (8<ax<36 and 124<y<154):continue
        side='Left' if x>0 else 'Right';arm='mixamorig:'+side+'Arm'
        influence=smooth(10,14,ax)*(1-smooth(30,36,ax))*smooth(124,131,y)
        current={obj.vertex_groups[g.group].name:g.weight for g in v.groups if g.weight>1e-7}
        outer=smooth(15,30,ax)
        cap=.28*smooth(141,149,y)*smooth(10,19,ax)*(1-smooth(26,32,ax))
        arm_weight=max(smooth(20,29,ax)*smooth(131,137,y),min(1,outer+cap)*smooth(130,142,y))
        # Preserve the existing torso/forearm distribution, while replacing
        # the abrupt axilla cutoff with a continuous upper-arm envelope.
        other={n:w for n,w in current.items() if n!=arm}
        total=sum(other.values())
        if total<1e-6:other={'mixamorig:'+side+'Shoulder':1};total=1
        proposed={n:w/total*(1-arm_weight) for n,w in other.items()}
        proposed[arm]=arm_weight
        values={n:current.get(n,0)*(1-influence)+proposed.get(n,0)*influence for n in current.keys()|proposed.keys()}
        top=sorted(values.items(),key=lambda p:p[1],reverse=True)[:4];total=sum(w for _,w in top)
        for group in obj.vertex_groups:group.remove([v.index])
        for n,w in top:
            if w>1e-7:
                group=obj.vertex_groups.get(n) or obj.vertex_groups.new(name=n);group.add([v.index],w/total,'REPLACE')
        # Reduce the remaining inflated yoke contour without touching the
        # collar or underlying anatomy. Units here are rig-local centimetres.
        shift=2.3*math.exp(-((ax-11.5)/8)**2)*smooth(7.8,10.3,ax)*smooth(143,151,y)
        v.co.y-=shift;max_shift=max(max_shift,shift);count+=1
    obj.data.update()
    # Re-register only the relaxed chest patch to the original front chart.
    # Existing edge-on UV repairs otherwise become scalloped stripe borders
    # when their tiny anatomical folds are flattened. No image is repainted.
    rects=json.loads((ROOT/'games/beechlawn_rovers/assets/characters/textures/beechlawn_home_tailored_atlas_layout.json').read_text())['rects']
    x0,y0,x1,y1=rects['front'];layer=obj.data.uv_layers.active
    repaired=[]
    for poly in obj.data.polygons:
        centre=sum((obj.data.vertices[i].co for i in poly.vertices),Vector())/len(poly.vertices)
        if centre.z<5 or not (7<abs(centre.x)<18 and 129<centre.y<139):continue
        for li in poly.loop_indices:
            p=obj.data.vertices[obj.data.loops[li].vertex_index].co
            u=max(.002,min(.998,.5+p.x/46));v=max(.002,min(.998,(p.y-100.5)/50))
            layer.data[li].uv=((x0+u*(x1-x0))/2048,1-(y1-v*(y1-y0))/2048);repaired.append(li)
    obj.data.update()
    obj['shoulder_uv_patch_loops']=len(repaired)
    return {'weighted_vertices':count,'geometry_vertices':sum((v.co-p).length>1e-5 for v,p in zip(obj.data.vertices,original)),'max_yoke_drop_cm':round(max_shift,4),'max_vertex_displacement_cm':round(max((v.co-p).length for v,p in zip(obj.data.vertices,original)),4),'front_uv_patch_loops':len(repaired)}

def main():
    source_override=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--source=')),str(SOURCE))
    bpy.ops.wm.open_mainfile(filepath=str(Path(source_override).resolve()));rig=bpy.data.objects['YBot_Armature']
    if rig.get('shoulder_fit_revision')==1:
        print('SHOULDER_FIT already applied');return
    body=bpy.data.objects['YBot_Joints'];body_uv_weights=repr(([tuple(v.uv) for v in body.data.uv_layers.active.data],[[(g.group,g.weight) for g in v.groups] for v in body.data.vertices]))
    atlases={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'games/beechlawn_rovers/assets/characters/textures/shared').glob('*.png')}
    protected=preserved_rig_and_heads(rig);uvs={n:[tuple(v.uv) for v in bpy.data.objects[n].data.uv_layers.active.data] for n in EDITED}
    # Collar and cuffs are distinct parts and must remain byte-for-byte stable.
    interfaces={n:repr([(tuple(v.co),[(g.group,g.weight) for g in v.groups]) for v in bpy.data.objects[n].data.vertices]) for n in ('Kit_Shane_ContinuousVBinding','Kit_shirt_BoundHems')}
    mesh=bpy.data.objects[EDITED[0]].data;mesh.calc_loop_triangles()
    cohort=[t.vertices[:] for t in mesh.loop_triangles if 118<sum(mesh.vertices[i].co.y for i in t.vertices)/3<151 and max(abs(mesh.vertices[i].co.x) for i in t.vertices)<32]
    before=folds(rig,bpy.data.objects[EDITED[0]],cohort)
    rig.animation_data.action=None
    for p in rig.pose.bones:p.matrix_basis.identity()
    changes={n:retune(bpy.data.objects[n]) for n in EDITED}
    skin=fit_covered_trapezius()
    clearance=keep_neck_clearance()
    after=folds(rig,bpy.data.objects[EDITED[0]],cohort)
    assert preserved_rig_and_heads(rig)==protected,'Rig, clips or protected body changed'
    assert repr(([tuple(v.uv) for v in body.data.uv_layers.active.data],[[(g.group,g.weight) for g in v.groups] for v in body.data.vertices]))==body_uv_weights,'Skin UV/weights changed'
    for name in EDITED:
        obj=bpy.data.objects[name];allowed=set()
        for p in obj.data.polygons:
            centre=sum((obj.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
            if centre.z>=5 and 7<abs(centre.x)<18 and 129<centre.y<139:allowed.update(p.loop_indices)
        assert all(tuple(uv.uv)==uvs[name][i] for i,uv in enumerate(obj.data.uv_layers.active.data) if i not in allowed),'UV changed outside the corrected chest patch' 
    for n,state in interfaces.items():assert repr([(tuple(v.co),[(g.group,g.weight) for g in v.groups]) for v in bpy.data.objects[n].data.vertices])==state,n
    report={'protected_sha256':protected,'bones':len(rig.data.bones),'clips':len(bpy.data.actions),'changes':changes,'before':before,'after':after,'unchanged_uvs_outside_chest_patch':True,'atlas_sha256':atlases,'skin_uv_weights_preserved':True,'covered_skin_fit':skin,'neck_clearance_vertices':clearance,'collar_cuffs_unchanged':True}
    print('SHOULDER_FIT '+json.dumps({'bones':65,'clips':19,'folds':{n:[before[n]['inverted_triangles'],after[n]['inverted_triangles']] for n,_ in POSES},'covered_skin':skin,'changes':changes}),flush=True)
    preview=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--preview=')),None)
    if preview or '--apply' in sys.argv:
        rig.animation_data.action=bpy.data.actions['AN_Beechlawn_Idle'];bpy.context.scene.frame_set(1)
        if preview:
            bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=preview)
            Path(preview+'.json').write_text(json.dumps(report,indent=2)+'\n')
        else:
            assert all(after[n]['inverted_triangles']<before[n]['inverted_triangles'] for n,_ in POSES),'Pose-fold gate did not improve'
            rig['shoulder_fit_revision']=1;export_current(rig)
            OUT.mkdir(parents=True,exist_ok=True);(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
