"""Derive smooth close-up heads/eyes while retaining the editable low cage.

Subdivision is evaluated identically for Basis and each expression. Bindings,
UVs and materials come from the current saved sources; no body/actions change.
"""
import json
from pathlib import Path
import sys
import bpy

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
PROJECT=ROOT/'games/beechlawn_rovers'
sys.path.insert(0,str(HERE))
from author_four_head_finish import SOURCES
from build_roster_heads import export,PARTS


def smooth_part(obj):
    names=[]
    if obj.data.shape_keys:
        names=[key.name for key in obj.data.shape_keys.key_blocks[1:]]
        for key in obj.data.shape_keys.key_blocks: key.value=0
    modifier=obj.modifiers.new('Closeup surface refinement','SUBSURF')
    modifier.levels=modifier.render_levels=1
    modifier.subdivision_type='CATMULL_CLARK'
    graph=bpy.context.evaluated_depsgraph_get()
    graph.update()
    neutral=bpy.data.meshes.new_from_object(obj.evaluated_get(graph),preserve_all_data_layers=True,depsgraph=graph)
    shapes={}
    for name in names:
        obj.data.shape_keys.key_blocks[name].value=1
        graph.update()
        mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(graph),preserve_all_data_layers=True,depsgraph=graph)
        assert len(mesh.vertices)==len(neutral.vertices)
        shapes[name]=[v.co.copy() for v in mesh.vertices]
        bpy.data.meshes.remove(mesh)
        obj.data.shape_keys.key_blocks[name].value=0
    groups=[group.name for group in obj.vertex_groups]
    weights=[[(g.group,g.weight) for g in vertex.groups] for vertex in neutral.vertices]
    obj.modifiers.remove(modifier)
    # Modifier evaluation happened at the reset/rest pose. Keep only the
    # original Armature modifier so runtime skinning applies exactly once.
    obj.data=neutral
    obj.vertex_groups.clear()
    for name in groups: obj.vertex_groups.new(name=name)
    for index,values in enumerate(weights):
        for group,weight in values: obj.vertex_groups[group].add([index],weight,'REPLACE')
    if names:
        obj.shape_key_add(name='Basis')
        for name in names:
            shape=obj.shape_key_add(name=name)
            for point,value in zip(shape.data,shapes[name]): point.co=value
    for face in neutral.polygons: face.use_smooth=True
    return len(neutral.vertices)


report={}
for identity,filename in SOURCES.items():
    bpy.ops.wm.open_mainfile(filepath=str(HERE/filename))
    rig=bpy.data.objects['YBot_Armature']
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        bone.location=(0,0,0);bone.rotation_mode='QUATERNION'
        bone.rotation_quaternion=(1,0,0,0);bone.scale=(1,1,1)
    report[identity]={name:smooth_part(bpy.data.objects[name]) for name in PARTS}
    # All LODs use the normal package's runtime material resources. Embedding
    # four duplicate atlases per near head wastes GPU memory and repeats slow
    # platform texture compression during import.
    for name in PARTS:
        obj=bpy.data.objects[name]
        obj.data.materials.clear()
        obj.data.materials.append(bpy.data.materials.new('SharedRuntimeHeadMaterial'))
    export(PROJECT/f'assets/characters/shared/heads/near/{identity}.glb',PARTS)
    print('CLOSEUP_HEAD',identity,report[identity],flush=True)
(PROJECT/'docs/art_briefs/realism_finish/near_heads.json').write_text(json.dumps(report,indent=2)+'\n')
