"""Original shared walk/jog presentation clips and restrained braking arms.

blender -b --python tools/blender/beechlawn/presentation_actions.py -- --apply
Uses the existing deform skeleton; no geometry, rest pose or contact edits.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from shane_leg_retarget import reset_pose, minimum_roll_pose, local_rotation
from shared_role_actions import polish_turn_arms

SOURCE = ROOT / 'tools/blender/beechlawn/footballer_shared.blend'
EXPORT = ROOT / 'games/beechlawn_rovers/assets/characters/shared/footballer_base.glb'
REPORT = ROOT / 'games/beechlawn_rovers/docs/art_briefs/presentation_source_audit.json'
NEW_CLIPS = ('AN_Beechlawn_WalkOn', 'AN_Beechlawn_WarmupJog')
ARM_PATHS = {'pose.bones["mixamorig:' + side + part + '"].rotation_quaternion'
             for side in ('Left', 'Right') for part in ('Arm', 'ForeArm')}


def retained_digest():
    data = []
    for action in sorted(bpy.data.actions, key=lambda item: item.name):
        if action.name in NEW_CLIPS:
            continue
        for curve in sorted(action.fcurves, key=lambda item: (item.data_path, item.array_index)):
            if action.name == 'AN_Beechlawn_StopFromRun' and curve.data_path in ARM_PATHS:
                continue
            data.append((action.name, curve.data_path, curve.array_index,
                         [(tuple(k.co), tuple(k.handle_left), tuple(k.handle_right), k.interpolation)
                          for k in curve.keyframe_points]))
    return hashlib.sha256(repr(data).encode()).hexdigest()


def solve_limb(rig, side, parts, target, bend_direction, end_basis):
    upper, lower, end = [rig.pose.bones['mixamorig:' + side + part] for part in parts]
    start = upper.matrix.translation.copy()
    length_a = (lower.matrix.translation - start).length
    length_b = (end.matrix.translation - lower.matrix.translation).length
    offset = target - start
    distance = min(offset.length, length_a + length_b - 0.15)
    direction = offset.normalized()
    along = (length_a**2 - length_b**2 + distance**2) / (2 * distance)
    height = math.sqrt(max(0.0, length_a**2 - along**2))
    bend = (bend_direction - direction * bend_direction.dot(direction)).normalized()
    knee = start + direction * along + bend * height
    # Imported children need not sit exactly on their parent's local Y axis.
    # Rotate the actual child-head vector, preserving the limb's axial roll.
    align = (lower.matrix.translation - start).rotation_difference(knee - start)
    desired = (align @ upper.matrix.to_quaternion()).to_matrix().to_4x4()
    desired.translation = start
    upper.rotation_quaternion, _ = local_rotation(upper, desired, upper.parent.matrix)
    bpy.context.view_layer.update()
    align = (end.matrix.translation - lower.matrix.translation).rotation_difference(target - lower.matrix.translation)
    desired = (align @ lower.matrix.to_quaternion()).to_matrix().to_4x4()
    desired.translation = lower.matrix.translation
    lower.rotation_quaternion, _ = local_rotation(lower, desired, lower.parent.matrix)
    bpy.context.view_layer.update()
    desired = end_basis.copy()
    desired.translation = end.matrix.translation
    end.rotation_quaternion, _ = local_rotation(end, desired, end.parent.matrix)
    bpy.context.view_layer.update()
    error = (end.matrix.translation - target).length
    return error


def author_stride(rig, name, frames, speed, duty, lift, hip_drop):
    scene = bpy.context.scene
    reset_pose(rig)
    rig.animation_data.action = bpy.data.actions['AN_Beechlawn_Idle']
    scene.frame_set(2)
    bpy.context.view_layer.update()
    # The imported action has baked translation on leg/toe bones. New FK
    # strides need a connected chain, rather than inheriting those IK offsets.
    for side in ('Left', 'Right'):
        for part in ('UpLeg', 'Leg', 'Foot', 'ToeBase', 'Toe_End'):
            bone = rig.pose.bones.get('mixamorig:' + side + part)
            if bone:
                bone.location = (0, 0, 0)
                bone.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    baseline = {bone.name: (bone.location.copy(), bone.rotation_quaternion.copy(), bone.scale.copy())
                for bone in rig.pose.bones}
    matrices = {bone.name: bone.matrix.copy() for bone in rig.pose.bones}
    unit = 1.0 / rig.matrix_world.to_scale().x
    up = (rig.matrix_world.inverted().to_3x3() @ Vector((0, 0, 1))).normalized()
    forward = sum((rig.data.bones['mixamorig:' + side + 'ToeBase'].matrix_local.translation
                   - rig.data.bones['mixamorig:' + side + 'Foot'].matrix_local.translation
                   for side in ('Left', 'Right')), Vector())
    forward = (forward - up * forward.dot(up)).normalized()
    right = forward.cross(up).normalized()
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    rig.animation_data.action = None
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    seconds = frames / 60.0
    amplitude = speed * seconds * duty * 0.5
    max_error = 0.0
    previous = {}
    for frame in range(frames + 1):
        scene.frame_set(frame + 1)
        phase = frame / frames
        for bone in rig.pose.bones:
            loc, rotation, scale = baseline[bone.name]
            bone.location = loc
            bone.rotation_quaternion = rotation
            bone.scale = scale
        bpy.context.view_layer.update()
        hips = rig.pose.bones['mixamorig:Hips']
        pose = matrices[hips.name].copy()
        pose.translation += up * unit * (-hip_drop + 0.008 * (1 - math.cos(4 * math.pi * phase)))
        pose.translation += right * unit * 0.008 * math.sin(2 * math.pi * phase)
        hips.matrix = pose
        bpy.context.view_layer.update()
        for side, shift in [('Left', 0.0), ('Right', 0.5)]:
            foot_phase = (phase + shift) % 1.0
            if foot_phase < duty:
                travel = amplitude - 2 * amplitude * foot_phase / duty
                height = 0.0
            else:
                t = (foot_phase - duty) / (1 - duty)
                # Hermite endpoints retain stance velocity through toe-off and
                # heel strike instead of stopping abruptly at each arc end.
                tangent = -speed * seconds * (1 - duty)
                travel = ((2*t**3-3*t**2+1)*-amplitude + (t**3-2*t**2+t)*tangent
                          + (-2*t**3+3*t**2)*amplitude + (t**3-t**2)*tangent)
                height = lift * math.sin(math.pi * t)**1.4
            foot_matrix = rig.data.bones['mixamorig:' + side + 'Foot'].matrix_local
            target = foot_matrix.translation + forward * travel * unit + up * height * unit
            error = solve_limb(rig, side, ('UpLeg', 'Leg', 'Foot'), target, forward, foot_matrix)
            max_error = max(max_error, error / unit)
            swing = math.sin(2 * math.pi * (phase + shift))
            for part, direction in [('Arm', -up + forward * swing * 0.25 + right * (0.12 if side == 'Left' else -0.12)),
                                    ('ForeArm', -up * 0.75 + forward * 0.35)]:
                bone = rig.pose.bones['mixamorig:' + side + part]
                target_pose = minimum_roll_pose(bone, bone.parent.matrix, direction, bone.matrix.translation)
                bone.rotation_quaternion, _ = local_rotation(bone, target_pose, bone.parent.matrix)
                bpy.context.view_layer.update()
        for bone in rig.pose.bones:
            q = bone.rotation_quaternion.copy()
            if bone.name in previous and previous[bone.name].dot(q) < 0:
                q.negate()
                bone.rotation_quaternion = q
            previous[bone.name] = q.copy()
            for channel in ('location', 'rotation_quaternion', 'scale'):
                bone.keyframe_insert(channel, frame=frame + 1, group=bone.name)
    loop_error = max(abs(curve.keyframe_points[0].co.y - curve.keyframe_points[-1].co.y)
                     for curve in action.fcurves)
    assert loop_error < 0.0001, (name, 'loop seam', loop_error)
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = 'LINEAR'
    action['nominal_speed_mps'] = speed
    action['root_motion'] = 'in_place'
    return {'seconds': seconds, 'nominal_speed_mps': speed, 'maximum_ankle_target_error_m': max_error,
            'stance_fraction': duty, 'swing_clearance_m': lift, 'frames': frames + 1,
            'maximum_loop_channel_delta': loop_error}


def author_presentation_actions(rig):
    polish_turn_arms(rig, clips=('AN_Beechlawn_StopFromRun',))
    report = {}
    report[NEW_CLIPS[0]] = author_stride(rig, NEW_CLIPS[0], 60, 1.2, 0.55, 0.065, 0.10)
    report[NEW_CLIPS[1]] = author_stride(rig, NEW_CLIPS[1], 45, 2.2, 0.40, 0.12, 0.11)
    assert all(item['maximum_ankle_target_error_m'] < 0.015 for item in report.values()), report
    reset_pose(rig)
    rig.animation_data.action = bpy.data.actions['AN_Beechlawn_Idle']
    bpy.context.scene.frame_set(2)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--validate', action='store_true', help='Author/audit in memory without exporting')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    rig = bpy.data.objects['YBot_Armature']
    if not args.apply and not args.validate:
        print('PRESENTATION_SOURCE audit_only bones=', len(rig.data.bones))
        return
    digest = retained_digest()
    report = author_presentation_actions(rig)
    assert retained_digest() == digest, 'An original non-supporting-arm curve changed'
    assert len(rig.data.bones) == 65
    report.update(preserved_original_curves_sha256=digest, fps=60, bones=65,
                  scope='Stop arm quaternion tracks and two new in-place clips; original contacts/rest/meshes preserved')
    if not args.apply:
        REPORT.write_text(json.dumps(report, indent=2) + '\n')
        print('PRESENTATION_VALIDATED ' + json.dumps(report))
        return
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.context.scene.objects:
        if obj == rig or obj.type == 'MESH':
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format='GLB', use_selection=True,
        export_yup=True, export_apply=True, export_cameras=False, export_lights=False,
        export_animations=True, export_animation_mode='ACTIONS', export_skins=True,
        export_influence_nb=4, export_leaf_bone=False, export_rest_position_armature=True)
    REPORT.write_text(json.dumps(report, indent=2) + '\n')
    print('PRESENTATION_SOURCE ' + json.dumps(report))


if __name__ == '__main__':
    main()
