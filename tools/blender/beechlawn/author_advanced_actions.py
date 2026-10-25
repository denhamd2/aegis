"""Original volley and half-volley actions; animation-only delivery.

Run: blender -b --python-exit-code 1 --python tools/blender/beechlawn/author_advanced_actions.py
Add -- --render-review for CPU pose stills.

Preserves the shared production source, rig/rest transforms, meshes and kits.
A real CharacterBody jump supplies vertical root motion in Godot. These clips
only pose the body; no horizontal root motion or airborne ball attachment.
"""
import bpy, math, sys, json, hashlib
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from shane_leg_retarget import minimum_roll_pose, local_rotation
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'games/beechlawn_rovers/assets/characters/shared'
OUT.mkdir(parents=True,exist_ok=True)
(ROOT/'build/beechlawn-advanced').mkdir(parents=True,exist_ok=True)
SOURCE=Path(__file__).with_name('footballer_shared.blend')
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene=bpy.context.scene;scene.render.fps=60;scene.render.fps_base=1.0
rig=next(o for o in scene.objects if o.type=='ARMATURE')
rig.animation_data.action=bpy.data.actions['AN_Beechlawn_Idle'];scene.frame_set(1)
base={b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones}
feet={side:rig.pose.bones['mixamorig:'+side+'Foot'].matrix.copy() for side in ['Left','Right']}
rest_digest=hashlib.sha256(repr([(b.name,list(b.matrix_local)) for b in rig.data.bones]).encode()).hexdigest()

def restore():
    for bone in rig.pose.bones:bone.location,bone.rotation_quaternion,bone.scale=base[bone.name]
    bpy.context.view_layer.update()

def point_bone(name,target):
    bone=rig.pose.bones['mixamorig:'+name]
    mat=minimum_roll_pose(bone,bone.parent.matrix,Vector(target)-bone.matrix.translation,bone.matrix.translation)
    bone.rotation_quaternion=local_rotation(bone,mat,bone.parent.matrix)[0]
    bpy.context.view_layer.update()

def tilt(name,degrees):
    bone=rig.pose.bones['mixamorig:'+name]
    matrix=(Quaternion(Vector((1,0,0)),math.radians(degrees))@bone.matrix.to_quaternion()).to_matrix().to_4x4()
    matrix.translation=bone.matrix.translation
    bone.rotation_quaternion=local_rotation(bone,matrix,bone.parent.matrix)[0]
    bpy.context.view_layer.update()

def leg(side,lift=0):
    upper=rig.pose.bones['mixamorig:'+side+'UpLeg'];shin=rig.pose.bones['mixamorig:'+side+'Leg'];foot=rig.pose.bones['mixamorig:'+side+'Foot']
    hip=upper.matrix.translation.copy()
    ankle=Vector((11 if side=='Left' else -11,13+lift,2))
    delta=ankle-hip;distance=delta.length;axis=delta.normalized()
    a=upper.bone.length;b=shin.bone.length
    along=(a*a-b*b+distance*distance)/(2*distance)
    bend=Vector((0,0,1));bend=(bend-axis*bend.dot(axis)).normalized()
    knee=hip+axis*along+bend*math.sqrt(max(0,a*a-along*along))
    point_bone(side+'UpLeg',knee);point_bone(side+'Leg',ankle)
    target=feet[side].copy();target.translation=foot.matrix.translation
    foot.rotation_quaternion=local_rotation(foot,target,foot.parent.matrix)[0]
    bpy.context.view_layer.update()

def arms(amount):
    for side,sign in [('Left',1),('Right',-1)]:
        point_bone(side+'Arm',(sign*(29+9*amount),128,13+5*amount))
        point_bone(side+'ForeArm',(sign*(25+6*amount),109+38*amount,22+25*amount))


def place_leg(side, toe_target):
    foot=rig.pose.bones['mixamorig:'+side+'Foot']
    toe=rig.pose.bones['mixamorig:'+side+'Toe_End']
    # The preserved foot orientation fixes toe offset relative to ankle.
    offset=toe.matrix.translation-foot.matrix.translation
    ankle=Vector(toe_target)-offset
    upper=rig.pose.bones['mixamorig:'+side+'UpLeg'];shin=rig.pose.bones['mixamorig:'+side+'Leg']
    hip=upper.matrix.translation.copy();delta=ankle-hip;distance=delta.length;axis=delta.normalized()
    a=upper.bone.length;b=shin.bone.length
    assert abs(a-b)<distance<a+b, (side,distance,a,b)
    along=(a*a-b*b+distance*distance)/(2*distance)
    pole=Vector((0,0,1));pole=(pole-axis*pole.dot(axis)).normalized()
    knee=hip+axis*along+pole*math.sqrt(max(0,a*a-along*along))
    point_bone(side+'UpLeg',knee);point_bone(side+'Leg',ankle)
    target=feet[side].copy();target.translation=foot.matrix.translation
    foot.rotation_quaternion=local_rotation(foot,target,foot.parent.matrix)[0]
    bpy.context.view_layer.update()

new=[];report={'fps':60,'export_time_origin':'first source frame maps to 0 seconds','source_sha256':source_hash,'rest_sha256':rest_digest,'root_motion':'in-place; grounded strikes','clips':{}}
for name,height in [('Volley',78),('HalfVolley',20)]:
    rig.animation_data.action=None
    action=bpy.data.actions.new('AN_Beechlawn_'+name);action.use_fake_user=True;rig.animation_data.action=action
    contact=19;end=49
    poses=[(1,0,0,None),(7,-3,-6,(18,-12)),(13,-3,-3,(height*.65,12)),(19,-2,6,(height,60)),(25,-3,10,(height+7,69)),(34,-3,4,(20,32)),(43,-1,0,(9,18)),(49,0,0,None)]
    for frame,drop,lean,boot in poses:
        scene.frame_set(frame);restore()
        if boot is not None:
            rig.pose.bones['mixamorig:Hips'].location.y+=drop
            bpy.context.view_layer.update();tilt('Spine',lean*.6);tilt('Spine1',lean*.4)
            place_leg('Left',(11,3.5,13))
            place_leg('Right',(-9,boot[0],boot[1]))
            arms(.30 if frame<contact else .45)
        for bone in rig.pose.bones:
            for prop in ['location','rotation_quaternion']:bone.keyframe_insert(prop,frame=frame,group=bone.name)
    for curve in action.fcurves:
        for key in curve.keyframe_points:key.interpolation='BEZIER';key.handle_left_type='AUTO_CLAMPED';key.handle_right_type='AUTO_CLAMPED'
    new.append(action)
    key='volley' if name=='Volley' else 'half_volley'
    metadata={'clip':action.name,'event':'ball_contact','frame':contact-1,'fps':60,'time_seconds':(contact-1)/60,'contact_height_m':height/100,'forward_m':.60,'lateral_m':.09}
    (OUT/(key+'_contact.json')).write_text(json.dumps(metadata,indent=2)+'\n')
    report['clips'][action.name]={'frames':[1,end],'contact_seconds':.3,'joints':[]}
    for frame in range(1,end+1):
        scene.frame_set(frame)
        report['clips'][action.name]['joints'].append({n:list(rig.matrix_world@rig.pose.bones['mixamorig:'+n].matrix.translation) for n in ['Hips','Head','LeftFoot','RightFoot','RightToe_End']})
if '--render-review' in sys.argv:
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=12;scene.cycles.use_denoising=False
    scene.render.resolution_x=480;scene.render.resolution_y=480;scene.render.resolution_percentage=100
    world=bpy.data.worlds.new('AdvancedReviewWorld');world.use_nodes=True;scene.world=world
    world.node_tree.nodes['Background'].inputs['Color'].default_value=(.55,.65,.78,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
    cd=bpy.data.cameras.new('AdvancedReviewCamera');cam=bpy.data.objects.new('AdvancedReviewCamera',cd);scene.collection.objects.link(cam);scene.camera=cam
    cam.location=(3,-5,2);cam.rotation_euler=(Vector((0,0,.95))-cam.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=2.25
    ld=bpy.data.lights.new('AdvancedReviewSun','SUN');ld.energy=2;ld.angle=math.radians(8)
    light=bpy.data.objects.new('AdvancedReviewSun',ld);scene.collection.objects.link(light);light.rotation_euler=(.6,-.4,-.7)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.01))
    for action in new:
        rig.animation_data.action=action;scene.frame_set(19)
        scene.render.filepath=str(ROOT/'build/beechlawn-advanced'/(action.name+'_blender.png'));bpy.ops.render.render(write_still=True)
rig.animation_data.action=new[0]
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
    if action not in new:bpy.data.actions.remove(action,do_unlink=True)
for obj in list(bpy.data.objects):
    if obj!=rig:bpy.data.objects.remove(obj,do_unlink=True)
scene.frame_set(1);bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name('football_advanced_actions.blend')),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'advanced_actions.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,export_skins=True,export_leaf_bone=False,export_rest_position_armature=True)
# Validate the actual GLB timeline, not only authoring FPS or process exit.
import struct
raw=(OUT/'advanced_actions.glb').read_bytes();size=struct.unpack_from('<I',raw,12)[0]
gltf=json.loads(raw[20:20+size]);report['exported_times']={}
for animation in gltf['animations']:
    inputs=[gltf['accessors'][sample['input']] for sample in animation['samplers']]
    start=min(a['min'][0] for a in inputs);end=max(a['max'][0] for a in inputs)
    assert abs(start)<1e-7 and abs(end-.8)<1e-6,(animation['name'],start,end)
    report['exported_times'][animation['name']]={'first_key':start,'last_key':end}
assert source_hash==hashlib.sha256(SOURCE.read_bytes()).hexdigest()
(ROOT/'build/beechlawn-advanced/animation_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('ADVANCED_ANIMATIONS_EXPORTED',[(a.name,list(a.frame_range)) for a in new])
