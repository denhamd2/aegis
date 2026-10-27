"""Re-export an existing supporter blend with the garment UV mask.

Run: blender -b supporter_00.blend --python export_supporter_garment_mask.py -- --index 0
The source blend keeps its photo material; the GLB uses the same compact
vertex-colour export material as author_supporter.py.
"""
import argparse
from pathlib import Path
import sys
import bpy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
from supporter_garment_uv import ensure_mask_uv

parser = argparse.ArgumentParser()
parser.add_argument('--index', type=int, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
index = args.index
assert 0 <= index < 12
meshes = [obj for obj in bpy.data.objects if obj.type == 'MESH']
assert len(meshes) == 1
mesh = meshes[0]
loops, retained = ensure_mask_uv(mesh.data)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / f'supporter_{index:02d}.blend'), compress=True)

material = mesh.data.materials[0]
nodes = material.node_tree.nodes
links = material.node_tree.links
bs = nodes.get('Principled BSDF')
assert bs is not None
for link in list(bs.inputs['Base Color'].links):
    links.remove(link)
colour = nodes.new('ShaderNodeVertexColor')
colour.layer_name = 'Col'
links.new(colour.outputs['Color'], bs.inputs['Base Color'])
output = ROOT / f'games/beechlawn_rovers/assets/characters/supporters/fan_{index:02d}.glb'
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', export_yup=True,
                          export_animations=True, export_animation_mode='ACTIONS',
                          export_anim_slide_to_zero=True, export_rest_position_armature=True,
                          export_leaf_bone=False)
print('SUPPORTER_GARMENT_EXPORT', index, loops, retained, output.stat().st_size, flush=True)
