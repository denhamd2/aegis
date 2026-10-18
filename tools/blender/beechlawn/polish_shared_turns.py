"""Audit, optionally polish/export the existing shared pivot arm tracks.

blender -b --python tools/blender/beechlawn/polish_shared_turns.py -- --apply --render
Default is read-only. No gameplay, foot, root, rig-rest or mesh edits.
"""
from pathlib import Path
import argparse
import hashlib
import json
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from shared_role_actions import polish_turn_arms

SOURCE = ROOT / 'tools/blender/beechlawn/footballer_shared.blend'
EXPORT = ROOT / 'games/beechlawn_rovers/assets/characters/shared/footballer_base.glb'
EVIDENCE = ROOT / 'games/beechlawn_rovers/docs/art_briefs'
CLIPS = ('AN_Beechlawn_Turn90Left', 'AN_Beechlawn_Turn90Right')
ARM_PATHS = {'pose.bones["mixamorig:'+side+part+'"].rotation_quaternion'
             for side in ('Left','Right') for part in ('Arm','ForeArm')}


def retained_curve_digest():
    values=[]
    for action in sorted(bpy.data.actions, key=lambda a:a.name):
        for curve in sorted(action.fcurves,key=lambda f:(f.data_path,f.array_index)):
            if action.name in CLIPS and curve.data_path in ARM_PATHS:
                continue
            values.append((action.name,curve.data_path,curve.array_index,
                           [(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation)
                            for k in curve.keyframe_points]))
    return hashlib.sha256(repr(values).encode()).hexdigest()


def sample(rig):
    result={}
    for name in CLIPS:
        action=bpy.data.actions[name]
        rig.animation_data.action=action
        lo,hi=action.frame_range
        drops=[]
        for fraction in (0,.25,.5,.75,1):
            frame=lo+(hi-lo)*fraction
            bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame))
            bpy.context.view_layer.update()
            for side in ('Left','Right'):
                shoulder=rig.matrix_world@rig.pose.bones['mixamorig:'+side+'Arm'].matrix.translation
                elbow=rig.matrix_world@rig.pose.bones['mixamorig:'+side+'ForeArm'].matrix.translation
                drops.append(round(shoulder.z-elbow.z,6))
        result[name]={'seconds':round((hi-lo)/bpy.context.scene.render.fps,6),
                      'minimum_shoulder_elbow_drop_m':min(drops)}
    rig.animation_data.action=bpy.data.actions[CLIPS[1]]
    bpy.context.scene.frame_set(19)
    bpy.context.view_layer.update()
    points={name:tuple(rig.matrix_world@bone.matrix.translation)
            for name,bone in rig.pose.bones.items()}
    return result,points


def render_proxies(before,after):
    scene=bpy.data.scenes.new('Pivot_QA_Only')
    bpy.context.window.scene=scene
    def material(name,color):
        mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1)
        return mat
    gray=material('Before',(0.34,0.38,0.4));blue=material('After',(0.08,0.34,0.58))
    def rod(a,b,radius,mat):
        a,b=Vector(a),Vector(b)
        bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=radius,depth=(b-a).length,location=(a+b)/2)
        obj=bpy.context.object;obj.rotation_mode='QUATERNION'
        obj.rotation_quaternion=(b-a).to_track_quat('Z','Y');obj.data.materials.append(mat)
    limbs=[('Hips','Spine2',.1),('Spine2','Head',.065)]
    for side in ('Left','Right'):
        limbs += [(side+'Arm',side+'ForeArm',.045),(side+'ForeArm',side+'Hand',.035),
                  ('Hips',side+'UpLeg',.065),(side+'UpLeg',side+'Leg',.065),
                  (side+'Leg',side+'Foot',.045),(side+'Foot',side+'ToeBase',.045)]
    for data,offset,mat in [(before,-.9,gray),(after,.9,blue)]:
        points={name:Vector(value)+Vector((offset,0,0)) for name,value in data.items()}
        for a,b,radius in limbs:rod(points['mixamorig:'+a],points['mixamorig:'+b],radius,mat)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.12,
                                           location=points['mixamorig:Head']+Vector((0,0,.06)))
        bpy.context.object.data.materials.append(mat)
    bpy.ops.mesh.primitive_plane_add(size=200)
    bpy.context.object.data.materials.append(material('Floor',(.09,.1,.12)))
    bpy.ops.object.camera_add(location=(0,-6,2.5))
    camera=bpy.context.object;camera.rotation_euler=(Vector((0,0,1))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=4.3;scene.camera=camera
    for label,x in [('BEFORE',-.9),('AFTER',.9)]:
        bpy.ops.object.text_add(location=(x-.3,0,2.05))
        text=bpy.context.object;text.data.body=label;text.data.size=.13
        text.rotation_euler=camera.rotation_euler
    bpy.ops.object.light_add(type='AREA',location=(1,-3,5))
    bpy.context.object.data.energy=500;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=5
    scene.world=bpy.data.worlds.new('QA_World');scene.world.color=(.35,.35,.35)
    # The cloud Blender build has no OpenImageDenoise. A small proxy scene
    # renders cheaply on CPU without that optional dependency.
    scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False
    scene.render.resolution_x=960;scene.render.resolution_y=540;scene.render.resolution_percentage=100
    scene.render.filepath=str(EVIDENCE/'shared_turn_proxy_before_after.png')
    bpy.ops.render.render(write_still=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply',action='store_true');parser.add_argument('--render',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    rig=bpy.data.objects['YBot_Armature']
    before,proxy_before=sample(rig)
    report={'applied':False,'bones':len(rig.data.bones),'before':before}
    if args.apply:
        retained=retained_curve_digest()
        polish_turn_arms(rig)
        assert retained_curve_digest()==retained,'A non-arm or other-action curve changed'
        after,proxy_after=sample(rig)
        assert all(v['minimum_shoulder_elbow_drop_m']>.15 for v in after.values()),after
        assert all(after[n]['seconds']==before[n]['seconds'] for n in CLIPS)
        report.update(applied=True,after=after,retained_curves_sha256=retained,
                      preserved='All other curves, action durations, foot/root tracks and rig rest preserved')
        rig.animation_data.action=bpy.data.actions['AN_Beechlawn_Idle']
        bpy.context.scene.frame_set(1)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
        bpy.ops.object.select_all(action='DESELECT')
        for obj in bpy.context.scene.objects:
            if obj==rig or obj.type=='MESH':obj.select_set(True)
        bpy.context.view_layer.objects.active=rig
        bpy.ops.export_scene.gltf(filepath=str(EXPORT),export_format='GLB',use_selection=True,
            export_yup=True,export_apply=True,export_cameras=False,export_lights=False,
            export_animations=True,export_animation_mode='ACTIONS',export_skins=True,
            export_influence_nb=4,export_leaf_bone=False,export_rest_position_armature=True)
        (EVIDENCE/'shared_turn_polish.json').write_text(json.dumps(report,indent=2)+'\n')
        if args.render:render_proxies(proxy_before,proxy_after)
    print('SHARED_TURN_POLISH '+json.dumps(report))


if __name__=='__main__':main()
