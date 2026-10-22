"""Original overhead throw and referee card gesture on the unchanged shared rig.
Exports an animation-only library; never rewrites the production body/kit/head.
"""
import bpy, math, sys, json
from pathlib import Path
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
from shane_leg_retarget import minimum_roll_pose, local_rotation, reset_pose
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'games/beechlawn_rovers/assets/characters/shared'
bpy.ops.wm.open_mainfile(filepath=str(Path(__file__).with_name('footballer_shared.blend')))
scene=bpy.context.scene
scene.render.fps=60
rig=next(o for o in scene.objects if o.type=='ARMATURE')
rig.animation_data.action=bpy.data.actions['AN_Beechlawn_Idle'];scene.frame_set(1)
baseline={b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones}
def restore():
    for b in rig.pose.bones: b.location,b.rotation_quaternion,b.scale=baseline[b.name]
    bpy.context.view_layer.update()
def arm(side, elbow, hand):
    for suffix,target in [('Arm',Vector(elbow)),('ForeArm',Vector(hand))]:
        b=rig.pose.bones['mixamorig:'+side+suffix]
        mat=minimum_roll_pose(b,b.parent.matrix,target-b.matrix.translation,b.matrix.translation)
        b.rotation_quaternion=local_rotation(b,mat,b.parent.matrix)[0]
        bpy.context.view_layer.update()
new=[]
for name,frames in [('AN_Beechlawn_ThrowIn',[1,13,27,39,49,67]),('AN_Beechlawn_ShowCard',[1,13,25,91,115])]:
    rig.animation_data.action=None
    action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
    for frame in frames:
        scene.frame_set(frame);restore()
        if 'ThrowIn' in name:
            # Both hands travel from behind the head, over it, then forward.
            poses={1:(184,-9,165,0),13:(192,-14,176,-9),27:(194,-10,187,-2),39:(182,22,203,28),49:(157,27,160,55),67:(132,12,110,23)}
            ey,ez,hy,hz=poses[frame]
            for side,sign in [('Left',1),('Right',-1)]: arm(side,(sign*26,ey,ez),(sign*9,hy,hz))
        else:
            amount=0 if frame in (1,115) else (0.65 if frame==13 else 1)
            arm('Right',(-25,132+51*amount,10),(-17,110+99*amount,20))
        for b in rig.pose.bones:
            for prop in ('location','rotation_quaternion','scale'):b.keyframe_insert(prop,frame=frame,group=b.name)
    for fc in action.fcurves:
        for k in fc.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
    new.append(action)
# Retain only the original new actions and the exact current rig/rest transform.
rig.animation_data.action=new[0]
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
    if action not in new:bpy.data.actions.remove(action,do_unlink=True)
for obj in list(bpy.data.objects):
    if obj!=rig:bpy.data.objects.remove(obj,do_unlink=True)
scene.frame_set(1);bpy.context.view_layer.objects.active=rig;rig.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name('football_restart_actions.blend')),compress=True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'restart_actions.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_leaf_bone=False,export_rest_position_armature=True)
(OUT/'throw_contact.json').write_text(json.dumps({'clip':'AN_Beechlawn_ThrowIn','event':'ball_contact','frame':39-1,'fps':60,'time_seconds':38/60},indent=2)+'\n')
print('RESTART_ANIMATIONS_EXPORTED',[(a.name, list(a.frame_range)) for a in new])
