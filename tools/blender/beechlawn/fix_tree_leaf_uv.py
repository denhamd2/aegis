"""Restore leaf-card UV0 after joining bark/leaf meshes with different UV names.

Run with Blender -b --python. Only the two tree modules and their source UVs
change; preserve all geometry, materials and the module preview placement.
"""
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[3]
SOURCE=ROOT/'tools/blender/beechlawn/kilmore_park_modules.blend'
OUT=ROOT/'games/beechlawn_rovers/assets/environment/kilmore'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
for suffix in ('A','B'):
    root=bpy.data.objects['SM_Kilmore_ParkTree_'+suffix]
    meshes=[o for o in root.children_recursive if o.type=='MESH']
    repaired=0
    for obj in meshes:
        mesh=obj.data
        leaves=mesh.uv_layers.get('LeafUV')
        if leaves is None:
            continue
        uv=mesh.uv_layers[0]
        for polygon in mesh.polygons:
            material=mesh.materials[polygon.material_index]
            if material and material.name=='MAT_Kilmore_LeafCards':
                for loop in polygon.loop_indices:
                    uv.data[loop].uv=leaves.data[loop].uv
                repaired+=1
        mesh.uv_layers.active_index=0
        uv.active_render=True
        mesh.update()
    assert repaired>0,(suffix,'no leaf polygons found')
    position=root.location.copy()
    root.location=(0,0,0)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [root]+list(root.children_recursive):obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(OUT/('kilmore_tree_'+suffix.lower()+'.glb')),
        export_format='GLB',use_selection=True,export_apply=True,export_yup=True,
        export_cameras=False,export_lights=False,export_animations=False)
    root.location=position
    print('TREE_LEAF_UV0_REPAIRED',suffix,'polygons',repaired)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
