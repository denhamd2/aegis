"""Export reusable body/kit morphs from the current production source.

The source, neutral body, 65-bone rig and shipping actions are never rewritten.
Godot instances share these meshes and set Fullness independently.
"""
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PROJECT = ROOT/'games/beechlawn_rovers'


def fullness(point):
    x, y, z = point
    # A soft abdomen/waist, rather than scaling the skeleton, head or boots.
    torso = math.exp(-((y-114.)/20.)**4) * math.exp(-(x/25.)**8)
    waist = math.exp(-((y-105.)/13.)**2) * math.exp(-(x/23.)**8)
    chest = math.exp(-((y-132.)/9.)**2) * math.exp(-(x/24.)**8)
    lateral = min(1., abs(x)/14.)
    dx = math.copysign(lateral*(2.7*torso+1.3*waist+.9*chest), x)
    front = .5+.5*math.tanh(z/4.)
    dz = (3.8*torso+1.1*waist)*front-(1.1*torso+.5*waist)*(1-front)
    # Thigh mass fades out before the knees. The leg centre and foot stay put.
    thigh = math.exp(-((y-83.)/13.)**4) * math.exp(-((abs(x)-8.)/11.)**6)
    thigh_x = x-math.copysign(8., x)
    dx += 1.3*thigh*max(-1., min(1., thigh_x/6.))
    dz += 1.4*thigh*math.tanh(z/6.)
    neck = math.exp(-((y-151.5)/6.0)**4) * math.exp(-(x/11.)**8)
    dx += x*.22*neck
    dz += (z+1.5)*.18*neck
    return Vector((x+dx, y, z+dz))


def main():
    source = HERE/'footballer_shared.blend'
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(source))
    rig = bpy.data.objects['YBot_Armature']
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        bone.location = (0,0,0)
        bone.rotation_mode = 'QUATERNION'
        bone.rotation_quaternion = (1,0,0,0)
        bone.scale = (1,1,1)
    selected = []
    audit = {}
    for obj in list(bpy.data.objects):
        if obj.type != 'MESH' or obj.name.startswith(('Hair_', 'Eye_')) or obj.name in ('Skin_Head','Skin_Hands','Kit_Boots'):
            continue
        if not any((fullness(v.co)-v.co).length > .0001 for v in obj.data.vertices):
            continue
        basis = obj.shape_key_add(name='Basis')
        shape = obj.shape_key_add(name='Fullness')
        for point, base in zip(shape.data, basis.data):
            point.co = fullness(base.co)
        audit[obj.name] = {'vertices':len(obj.data.vertices),
            'max_delta_cm':max((p.co-b.co).length for p,b in zip(shape.data,basis.data))}
        selected.append(obj)
    assert len(rig.data.bones) == 65 and len(selected) >= 6
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [rig,*selected]: obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.context.preferences.filepaths.save_version = 0
    bpy.context.scene['body_fullness_source_sha256'] = before
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'footballer_body_shapes.blend'), compress=True)
    # Geometry package only: runtime keeps the shared base body's materials.
    # Preserve material-slot order without duplicating its atlases/VRAM.
    for obj in selected:
        slots=len(obj.data.materials)
        obj.data.materials.clear()
        for index in range(slots):
            obj.data.materials.append(bpy.data.materials.new(f'BodyShape_{obj.name}_{index}'))
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/characters/shared/body_shapes.glb'),
        export_format='GLB',use_selection=True,export_yup=True,export_apply=False,
        export_cameras=False,export_lights=False,export_animations=False,export_skins=True,
        export_influence_nb=4,export_leaf_bone=False,export_rest_position_armature=True,export_morph=True)
    assert hashlib.sha256(source.read_bytes()).hexdigest() == before
    out = PROJECT/'docs/art_briefs/realism_finish'
    out.mkdir(parents=True,exist_ok=True)
    (out/'body_shapes.json').write_text(json.dumps({'source_sha256':before,'rig_bones':65,
        'neutral_source_unchanged':True,'parts':audit},indent=2)+'\n')
    print('BODY_FULLNESS_EXPORT', len(selected), 'shared morph meshes', flush=True)


if __name__ == '__main__': main()
