"""Original header and chest-control actions; animation-only delivery.

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
(ROOT/'build/beechlawn-aerial').mkdir(parents=True,exist_ok=True)
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

new=[];report={'fps':60,'root_motion':'in-place; CharacterBody header jump at 0.10 s','source_sha256':source_hash,'rest_sha256':rest_digest,'clips':{}}
for name,poses,contact in [
    ('AN_Beechlawn_Header',[(1,0,0,0),(7,-7,-7,0),(13,-2,-9,5),(19,-1,9,8),(25,-3,17,4),(33,-6,6,0),(45,0,0,0)],19),
    ('AN_Beechlawn_ChestControl',[(1,0,0,0),(7,-2,3,0),(14,-3,-9,0),(22,-5,-4,0),(34,-2,0,0),(43,0,0,0)],14)]:
    rig.animation_data.action=None
    action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
    for frame,drop,lean,foot_lift in poses:
        scene.frame_set(frame);restore()
        hips=rig.pose.bones['mixamorig:Hips'];hips.location.y+=drop
        bpy.context.view_layer.update();tilt('Spine',lean*.6);tilt('Spine1',lean*.4)
        if 'Header' in name:tilt('Head',-5 if frame<=13 else (8 if frame<=25 else 0))
        if frame not in [1,poses[-1][0]]:
            leg('Left',foot_lift);leg('Right',foot_lift*.65)
            arms(.8 if frame<=contact else .5)
        for bone in rig.pose.bones:
            for prop in ['location','rotation_quaternion']:bone.keyframe_insert(prop,frame=frame,group=bone.name)
    for curve in action.fcurves:
        for key in curve.keyframe_points:key.interpolation='BEZIER';key.handle_left_type='AUTO_CLAMPED';key.handle_right_type='AUTO_CLAMPED'
    new.append(action)
    metadata={'clip':name,'event':'ball_contact','frame':contact-1,'fps':60,'time_seconds':(contact-1)/60}
    (OUT/('header_contact.json' if 'Header' in name else 'chest_contact.json')).write_text(json.dumps(metadata,indent=2)+'\n')
    report['clips'][name]={'frames':list(action.frame_range),'contact_seconds':metadata['time_seconds'],'joints':[]}
    for frame in range(1,poses[-1][0]+1):
        scene.frame_set(frame)
        record={n:list(rig.matrix_world@rig.pose.bones['mixamorig:'+n].matrix.translation) for n in ['Head','HeadTop_End','Spine2','LeftFoot','RightFoot']}
        report['clips'][name]['joints'].append(record)
# Retain mesh-bearing memory temporarily for a reproducible optional pose review.
if '--render-review' in sys.argv:
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=12;scene.cycles.use_denoising=False
    scene.render.resolution_x=480;scene.render.resolution_y=480;scene.render.resolution_percentage=100
    world=bpy.data.worlds.new('AerialReviewWorld');world.use_nodes=True;scene.world=world
    world.node_tree.nodes['Background'].inputs['Color'].default_value=(.55,.65,.78,1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
    cam_data=bpy.data.cameras.new('AerialReviewCamera');cam=bpy.data.objects.new('AerialReviewCamera',cam_data);scene.collection.objects.link(cam);scene.camera=cam
    cam.location=(3,-5,2.0);cam.rotation_euler=(Vector((0,0,.95))-cam.location).to_track_quat('-Z','Y').to_euler();cam_data.type='ORTHO';cam_data.ortho_scale=2.25
    light_data=bpy.data.lights.new('AerialReviewSun','SUN');light_data.energy=2;light_data.angle=math.radians(8)
    light=bpy.data.objects.new('AerialReviewSun',light_data);scene.collection.objects.link(light);light.rotation_euler=(.6,-.4,-.7)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.01))
    for action,frame in [(new[0],19),(new[1],14)]:
        rig.animation_data.action=action;scene.frame_set(frame)
        scene.render.filepath=str(ROOT/'build/beechlawn-aerial'/('header_blender.png' if frame==19 else 'chest_blender.png'))
        bpy.ops.render.render(write_still=True)
rig.animation_data.action=new[0]
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
    if action not in new:bpy.data.actions.remove(action,do_unlink=True)
for obj in list(bpy.data.objects):
    if obj!=rig:bpy.data.objects.remove(obj,do_unlink=True)
scene.frame_set(1);bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name('football_aerial_actions.blend')),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'aerial_actions.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_leaf_bone=False,export_rest_position_armature=True)
assert source_hash==hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'Shared source was changed'
(ROOT/'build/beechlawn-aerial/animation_audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('AERIAL_ANIMATIONS_EXPORTED',[(a.name,list(a.frame_range)) for a in new])
