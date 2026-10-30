"""Export an isolated BR-022 oral study into a disposable football project."""
import argparse
from pathlib import Path
import sys

import bpy

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE))
from build_roster_heads import export


def smooth_part(obj):
    """Match build_near_heads.py without writing into production assets."""
    names=[]
    if obj.data.shape_keys:
        names=[key.name for key in obj.data.shape_keys.key_blocks[1:]]
        for key in obj.data.shape_keys.key_blocks:key.value=0
    modifier=obj.modifiers.new('Closeup surface refinement','SUBSURF')
    modifier.levels=modifier.render_levels=1
    modifier.subdivision_type='CATMULL_CLARK'
    graph=bpy.context.evaluated_depsgraph_get();graph.update()
    neutral=bpy.data.meshes.new_from_object(obj.evaluated_get(graph),
                preserve_all_data_layers=True,depsgraph=graph)
    shapes={}
    for name in names:
        obj.data.shape_keys.key_blocks[name].value=1
        graph.update()
        mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(graph),
                    preserve_all_data_layers=True,depsgraph=graph)
        assert len(mesh.vertices)==len(neutral.vertices)
        shapes[name]=[v.co.copy() for v in mesh.vertices]
        bpy.data.meshes.remove(mesh)
        obj.data.shape_keys.key_blocks[name].value=0
    groups=[group.name for group in obj.vertex_groups]
    weights=[[(g.group,g.weight) for g in vertex.groups] for vertex in neutral.vertices]
    obj.modifiers.remove(modifier)
    obj.data=neutral
    obj.vertex_groups.clear()
    for name in groups:obj.vertex_groups.new(name=name)
    for index,values in enumerate(weights):
        for group,weight in values:obj.vertex_groups[group].add([index],weight,'REPLACE')
    if names:
        obj.shape_key_add(name='Basis')
        for name in names:
            shape=obj.shape_key_add(name=name)
            for point,value in zip(shape.data,shapes[name]):point.co=value
    for face in neutral.polygons:face.use_smooth=True

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--player',required=True,choices=['robbie_roden','david_murray'])
parser.add_argument('--project',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
source=ROOT/'games/beechlawn_rovers/build/br022_oral_v2'/args.player/'oral_v2.blend'
assert source.is_file(),source
assert (args.project/'project.godot').is_file(),args.project
assert args.project.resolve().is_relative_to(
    (ROOT/'games/beechlawn_rovers/build').resolve()), \
    'Pilot exports must stay inside ignored football build storage'
output=args.project/'assets/characters/shared/heads/players'/(args.player+'.glb')
bpy.ops.wm.open_mainfile(filepath=str(source))
assert bpy.context.scene.get('head_player_id')==args.player
assert all(key.value==0 for key in bpy.data.objects['Skin_Head'].data.shape_keys.key_blocks)
export(output,('Skin_Head','Eye_l','Eye_r','Mouth_UpperTeeth','Mouth_Cavity'))
print('ORAL_PILOT_EXPORT',args.player,output,output.stat().st_size,flush=True)
for name in ('Skin_Head','Eye_l','Eye_r'):
    obj=bpy.data.objects[name]
    smooth_part(obj)
    obj.data.materials.clear()
    obj.data.materials.append(bpy.data.materials.new('SharedRuntimeHeadMaterial'))
near=args.project/'assets/characters/shared/heads/near'/(args.player+'.glb')
export(near,('Skin_Head','Eye_l','Eye_r'))
print('ORAL_PILOT_NEAR_EXPORT',args.player,near,near.stat().st_size,flush=True)
