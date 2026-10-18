"""Small baked role layers on the existing rig; no runtime IK or new bones."""
import bpy,math
from mathutils import Vector
from shane_leg_retarget import minimum_roll_pose,local_rotation,reset_pose

def polish_idle_arms(rig):
    """Relax the shared idle's exaggerated arm silhouettes, preserving legs/root."""
    scene=bpy.context.scene;action=bpy.data.actions['AN_Beechlawn_Idle']
    names=['mixamorig:'+side+part for side in ('Left','Right') for part in ('Arm','ForeArm')]
    tracks={name:[] for name in names}
    lo,hi=map(int,action.frame_range)
    reset_pose(rig);rig.animation_data.action=action
    for frame in range(lo,hi+1):
        scene.frame_set(frame)
        for side in ('Left','Right'):
            sign=1 if side=='Left' else -1
            for part,direction in [('Arm',Vector((sign*.16,-1,.08))),('ForeArm',Vector((sign*.04,-1,.18)))]:
                bone=rig.pose.bones['mixamorig:'+side+part]
                desired=minimum_roll_pose(bone,bone.parent.matrix,direction,bone.matrix.translation)
                q,_=local_rotation(bone,desired,bone.parent.matrix)
                if tracks[bone.name] and tracks[bone.name][-1].dot(q)<0:q.negate()
                tracks[bone.name].append(q.copy());bone.rotation_quaternion=q
                bpy.context.view_layer.update()
    for name,quats in tracks.items():
        path='pose.bones["'+name+'"].rotation_quaternion'
        for curve in list(action.fcurves):
            if curve.data_path==path:action.fcurves.remove(curve)
        for component in range(4):
            curve=action.fcurves.new(path,index=component,action_group=name)
            curve.keyframe_points.add(len(quats))
            curve.keyframe_points.foreach_set('co',[v for f,q in enumerate(quats,lo) for v in (f,q[component])])
            for point in curve.keyframe_points:point.interpolation='LINEAR'
            curve.update()
    action.update_tag()

def author_role_actions(rig):
    scene=bpy.context.scene
    polish_idle_arms(rig)
    polish_locomotion_arms(rig)
    reset_pose(rig);rig.animation_data.action=bpy.data.actions['AN_Beechlawn_Idle'];scene.frame_set(1)
    baseline={b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones}
    def pose_reach(side,amount):
        upper=rig.pose.bones['mixamorig:'+side+'Arm']
        lower=rig.pose.bones['mixamorig:'+side+'ForeArm']
        sign=1 if side=='Left' else -1
        elbow=Vector((sign*25,133,16));hand=Vector((sign*12,135,29))
        upper_target=minimum_roll_pose(upper,upper.parent.matrix,elbow-upper.matrix.translation,upper.matrix.translation)
        uq,_=local_rotation(upper,upper_target,upper.parent.matrix)
        upper.rotation_quaternion=baseline[upper.name][1].slerp(uq,amount)
        bpy.context.view_layer.update()
        lower_target=minimum_roll_pose(lower,lower.parent.matrix,hand-lower.matrix.translation,lower.matrix.translation)
        lq,_=local_rotation(lower,lower_target,lower.parent.matrix)
        lower.rotation_quaternion=baseline[lower.name][1].slerp(lq,amount)
        bpy.context.view_layer.update()
    for name,keys,loop in [
        ('AN_Beechlawn_KeeperSet',[(1,.55),(31,.58),(61,.55)],True),
        ('AN_Beechlawn_KeeperSave',[(1,.55),(7,.42),(13,1.0),(22,1.0),(43,.55)],False),
    ]:
        rig.animation_data.action=None
        action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
        for frame,amount in keys:
            scene.frame_set(frame)
            for bone in rig.pose.bones:
                loc,rot,scale=baseline[bone.name]
                bone.location=loc;bone.rotation_quaternion=rot;bone.scale=scale
            bpy.context.view_layer.update()
            for side in ('Left','Right'):pose_reach(side,amount)
            for bone in rig.pose.bones:
                for path in ('location','rotation_quaternion','scale'):bone.keyframe_insert(path,frame=frame,group=bone.name)
        for curve in action.fcurves:
            for point in curve.keyframe_points:
                point.interpolation='BEZIER';point.handle_left_type='AUTO_CLAMPED';point.handle_right_type='AUTO_CLAMPED'
        if loop:
            for curve in action.fcurves:curve.modifiers.new('CYCLES')
    reset_pose(rig);rig.animation_data.action=bpy.data.actions['AN_Beechlawn_Idle'];scene.frame_set(1)
    print('SHARED_ROLE_ACTIONS', 'keeper set and standing save; 65 bones retained')

def polish_locomotion_arms(rig):
    """Correct near-horizontal source arms; preserve every leg/root contact track.

    Reuse the existing foot cycle as the phase source so the opposite arm leads.
    Only eight quaternion tracks are baked, once offline, per existing clip.
    """
    scene=bpy.context.scene
    names=['mixamorig:'+side+part for side in ('Left','Right') for part in ('Arm','ForeArm')]
    for clip in ('AN_Beechlawn_Jog','AN_Beechlawn_Sprint','AN_Beechlawn_CloseControl'):
        action=bpy.data.actions[clip]
        tracks={name:[] for name in names}
        lo,hi=map(int,action.frame_range)
        reset_pose(rig);rig.animation_data.action=action
        sprint=clip.endswith('Sprint');close=clip.endswith('CloseControl')
        for frame in range(lo,hi+1):
            scene.frame_set(frame)
            feet={side:rig.pose.bones['mixamorig:'+side+'Foot'].matrix.translation.z for side in ('Left','Right')}
            for side,other in [('Left','Right'),('Right','Left')]:
                sign=1 if side=='Left' else -1
                swing=max(-1,min(1,(feet[other]-feet[side])/65))
                upper=Vector((sign*.14,-.88,swing*(.9 if sprint else .62)))
                lower=Vector((sign*.04,-.55 if close else (.25 if sprint else .08),-.85))
                for part,direction in [('Arm',upper),('ForeArm',lower)]:
                    bone=rig.pose.bones['mixamorig:'+side+part]
                    desired=minimum_roll_pose(bone,bone.parent.matrix,direction,bone.matrix.translation)
                    q,_=local_rotation(bone,desired,bone.parent.matrix)
                    if tracks[bone.name] and tracks[bone.name][-1].dot(q)<0:q.negate()
                    tracks[bone.name].append(q.copy());bone.rotation_quaternion=q
                    bpy.context.view_layer.update()
        for name,quats in tracks.items():
            path='pose.bones["'+name+'"].rotation_quaternion'
            for curve in list(action.fcurves):
                if curve.data_path==path:action.fcurves.remove(curve)
            for component in range(4):
                curve=action.fcurves.new(path,index=component,action_group=name)
                curve.keyframe_points.add(len(quats))
                curve.keyframe_points.foreach_set('co',[v for f,q in enumerate(quats,lo) for v in (f,q[component])])
                for point in curve.keyframe_points:point.interpolation='LINEAR'
                curve.update()
        action.update_tag()
    reset_pose(rig);rig.animation_data.action=bpy.data.actions['AN_Beechlawn_Idle'];scene.frame_set(1)
    print('SHARED_LOCOMOTION_ARMS: jog/sprint/close control, existing legs/root unchanged')
