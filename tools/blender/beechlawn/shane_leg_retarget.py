"""Remove imported axial leg roll while retaining the existing contact paths.

Offline FK retarget on the prototype's copies of the existing actions. Hip,
knee, ankle positions and foot orientations remain source-controlled. The
shared production animation-library .blend is never saved or modified here.
"""
import json
import math
from pathlib import Path
import bpy
from mathutils import Matrix,Vector

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'games/beechlawn_rovers/docs/art_briefs/br022_shane_leg_retarget.json'
NAMES=["mixamorig:"+side+part for side in ("Left","Right") for part in ("UpLeg","Leg","Foot")]


def reset_pose(rig):
    rig.animation_data.action=None
    for bone in rig.pose.bones:
        bone.location=(0,0,0);bone.rotation_mode='QUATERNION';bone.rotation_quaternion=(1,0,0,0);bone.scale=(1,1,1)


def minimum_roll_pose(bone,parent_matrix,direction,head):
    base=parent_matrix @ bone.bone.parent.matrix_local.inverted() @ bone.bone.matrix_local
    axis=base.to_3x3().col[1].normalized()
    rotation=axis.rotation_difference(direction.normalized()) @ base.to_quaternion()
    matrix=rotation.to_matrix().to_4x4();matrix.translation=head
    return matrix


def local_rotation(bone,desired,parent_matrix):
    basis=bone.bone.convert_local_to_pose(desired,bone.bone.matrix_local,
        parent_matrix=parent_matrix,parent_matrix_local=bone.bone.parent.matrix_local,invert=True)
    q=basis.to_quaternion().normalized()
    # Keep the original local translations/scales. Reconstruct the actual FK
    # matrix for the next bone rather than accumulating idealized matrices.
    actual_basis=Matrix.LocRotScale(bone.location,q,bone.scale)
    actual=bone.bone.convert_local_to_pose(actual_basis,bone.bone.matrix_local,
        parent_matrix=parent_matrix,parent_matrix_local=bone.bone.parent.matrix_local)
    return q,actual


def correct_leg_roll(rig):
    scene=bpy.context.scene;report={"scope":"prototype only","fps":scene.render.fps,
        "changed_rotation_bones":NAMES,"preserved":"all other curves; original joint paths and foot orientation",
        "actions":{}}
    actions=list(bpy.data.actions)
    for action in actions:
        # Partial upper-body actions must keep their lower body unkeyed so
        # AnimationTree can layer them over the running/standing pose.
        active_sides=[side for side in ('Left','Right') if any(
            f.data_path=='pose.bones["mixamorig:'+side+'UpLeg"].rotation_quaternion'
            for f in action.fcurves)]
        lo,hi=action.frame_range
        frames=sorted({float(lo),float(hi),*map(float,range(math.ceil(lo),math.floor(hi)+1))})
        reset_pose(rig);rig.animation_data.action=action
        curves={name:[] for name in NAMES if any(side in name for side in active_sides)}
        targets=[];before_roll=0.0
        for frame in frames:
            scene.frame_set(math.floor(frame),subframe=frame%1)
            original={name:rig.pose.bones[name].matrix.copy() for name in NAMES}
            targets.append(original)
            for side in active_sides:
                upper,shin,foot=[rig.pose.bones['mixamorig:'+side+part] for part in ("UpLeg","Leg","Foot")]
                before_roll=max(before_roll,abs(math.degrees(upper.rotation_quaternion.to_swing_twist('Y')[1])))
                upper_pose=minimum_roll_pose(upper,upper.parent.matrix,
                    original[shin.name].translation-original[upper.name].translation,original[upper.name].translation)
                uq,up=local_rotation(upper,upper_pose,upper.parent.matrix)
                shin_pose=minimum_roll_pose(shin,up,
                    original[foot.name].translation-original[shin.name].translation,original[shin.name].translation)
                lq,lp=local_rotation(shin,shin_pose,up)
                fq,fp=local_rotation(foot,original[foot.name],lp)
                for name,q in ((upper.name,uq),(shin.name,lq),(foot.name,fq)):
                    if curves[name] and curves[name][-1].dot(q)<0:q.negate()
                    curves[name].append(q.copy())
        for name,quats in curves.items():
            path='pose.bones["'+name+'"].rotation_quaternion'
            for curve in list(action.fcurves):
                if curve.data_path==path:action.fcurves.remove(curve)
            for index in range(4):
                curve=action.fcurves.new(path,index=index,action_group=name)
                curve.keyframe_points.add(len(frames))
                curve.keyframe_points.foreach_set('co',[v for f,q in zip(frames,quats) for v in (f,q[index])])
                for point in curve.keyframe_points:point.interpolation='LINEAR'
                curve.update()
        action.update_tag();scene.frame_set(0)
        position_error=0.0;foot_error=0.0;after_roll=0.0
        for frame,target in zip(frames,targets):
            scene.frame_set(math.floor(frame),subframe=frame%1)
            for name in NAMES:
                pose=rig.pose.bones[name]
                position_error=max(position_error,(pose.matrix.translation-target[name].translation).length)
                if name.endswith('Foot'):
                    dot=abs(pose.matrix.to_quaternion().normalized().dot(target[name].to_quaternion().normalized()))
                    foot_error=max(foot_error,math.degrees(2*math.acos(min(1,dot))))
                if name.endswith('UpLeg'):
                    after_roll=max(after_roll,abs(math.degrees(pose.rotation_quaternion.to_swing_twist('Y')[1])))
        assert position_error<.025,(action.name,'joint path changed',position_error)
        assert foot_error<.1,(action.name,'foot orientation changed',foot_error)
        report['actions'][action.name]={"frames":len(frames),"joint_path_max_error_cm":position_error,
            "foot_orientation_max_error_degrees":foot_error,"thigh_twist_before_degrees":before_roll,
            "thigh_twist_after_degrees":after_roll,"retargeted_sides":active_sides}
    reset_pose(rig)
    scene.frame_set(1)
    OUT.write_text(json.dumps(report,indent=2)+'\n')
    print('SHANE_LEG_RETARGET',len(actions),'actions','max_joint_error_cm',
          max(x['joint_path_max_error_cm'] for x in report['actions'].values()))
