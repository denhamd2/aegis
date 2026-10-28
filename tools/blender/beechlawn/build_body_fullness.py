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


def athletic_form(point):
    """Reference-led shared body and kit contour in centimetres.

    Apply one continuous field to skin and kit so cuffs, hems and exposed
    joints retain their interfaces. The neutral cage, UVs and weights stay
    untouched; Godot sets this corrective to one for every player.
    """
    x, y, z = point
    ax = abs(x)
    torso = math.exp(-((y-122.)/24.)**4) * math.exp(-(ax/24.)**8)
    # The inherited shirt projected farther forward at the waist (17.6 cm at
    # y=110) than at the chest (15.8 cm at y=130). The original roster sheet
    # has a clear upper-chest plane and a softer, narrower abdominal drape.
    waist = math.exp(-((y-108.)/13.)**4) * math.exp(-(ax/22.)**8)
    chest = math.exp(-((y-130.)/10.)**4) * math.exp(-(ax/22.)**8)
    front = .5 + .5*math.tanh((z-1.)/3.)
    x *= 1. - .085 * torso
    x *= 1. - .035 * waist
    z *= 1. - .045 * torso
    z -= 3.2*waist*front
    z += .6*waist*(1.-front)+.55*chest*front
    thigh = math.exp(-((y-84.)/17.)**4) * math.exp(-((ax-9.)/13.)**6)
    x -= math.copysign(.070 * (ax-9.) * thigh, x)
    z *= 1. - .065 * thigh
    # Taper the long sleeves around the actual arm centre instead of the
    # world origin. Keep the shoulder seam and wrists continuous with skin.
    arm = math.exp(-((ax-42.)/18.)**4) * math.exp(-((y-143.)/13.)**4)
    forearm = math.exp(-((ax-62.)/12.)**4) * math.exp(-((y-143.)/11.)**4)
    y = 143. + (y-143.)*(1. - .065*arm-.055*forearm)
    z = -6. + (z+6.)*(1. - .055*arm-.055*forearm)
    # Footballers' palms and fingers read oversized beside their faces.
    # Fade the reduction in after the wrist to preserve the arm join.
    hand = max(0., min(1., (ax-74.)/12.))
    hand = hand*hand*(3.-2.*hand)
    x -= math.copysign(.20 * max(0., ax-74.) * hand, x)
    y = 143. + (y-143.) * (1. - .08*hand)
    z = -6. + (z+6.)*(1. - .11*hand)
    # Taper boot toes, leaving the ankle/socket unchanged.
    toe = math.exp(-((y-7.)/6.)**4) * math.exp(-((ax-11.)/12.)**6)
    z *= 1. - .07*toe
    return Vector((x,y,z))


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
        if obj.type != 'MESH' or obj.name.startswith(('Hair_', 'Eye_')) or obj.name == 'Skin_Head':
            continue
        has_fullness = any((fullness(v.co)-v.co).length > .0001 for v in obj.data.vertices)
        has_form = any((athletic_form(v.co)-v.co).length > .0001 for v in obj.data.vertices)
        if not (has_fullness or has_form):
            continue
        basis = obj.shape_key_add(name='Basis')
        shape = obj.shape_key_add(name='Fullness')
        for point, base in zip(shape.data, basis.data):
            point.co = fullness(base.co)
        form = obj.shape_key_add(name='AthleticForm')
        for point, base in zip(form.data, basis.data):
            point.co = athletic_form(base.co)
        audit[obj.name] = {'vertices':len(obj.data.vertices),
            'max_fullness_cm':max((p.co-b.co).length for p,b in zip(shape.data,basis.data)),
            'max_athletic_cm':max((p.co-b.co).length for p,b in zip(form.data,basis.data))}
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
        'neutral_source_unchanged':True,'parts':audit,
        'athletic_form':'shared runtime corrective at weight 1.0'},indent=2)+'\n')
    print('BODY_FULLNESS_EXPORT', len(selected), 'shared morph meshes', flush=True)


if __name__ == '__main__': main()
