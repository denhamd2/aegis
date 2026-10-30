"""Audit the two disposable connected-mouth sources; production is untouched."""
import json
from pathlib import Path

import bmesh
import bpy

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
OUT=ROOT/'games/beechlawn_rovers/build/br022_connected_mouth'
report={}
for name in ('robbie_roden','david_murray'):
    bpy.ops.wm.open_mainfile(filepath=str(HERE/(name+'_head.blend')))
    base=bpy.data.objects['Skin_Head']
    base_coords=[v.co.copy() for v in base.data.vertices]
    base_weights=[[(g.group,round(g.weight,6)) for g in v.groups] for v in base.data.vertices]
    base_keys=[key.name for key in base.data.shape_keys.key_blocks]
    base_bones=len(bpy.data.objects['YBot_Armature'].data.bones)
    bpy.ops.wm.open_mainfile(filepath=str(OUT/name/'connected_mouth.blend'))
    head=bpy.data.objects['Skin_Head']
    assert len(bpy.data.objects['YBot_Armature'].data.bones)==base_bones==65
    assert [key.name for key in head.data.shape_keys.key_blocks]==base_keys
    assert len(head.data.vertices)>len(base_coords)
    for index,(original,weights) in enumerate(zip(base_coords,base_weights)):
        vertex=head.data.vertices[index]
        assert (vertex.co-original).length<1e-5
        assert [(g.group,round(g.weight,6)) for g in vertex.groups]==weights
    assert all(vertex.groups for vertex in head.data.vertices[len(base_coords):])
    assert head.data.uv_layers.active is not None
    bm=bmesh.new();bm.from_mesh(head.data)
    aperture=[edge for edge in bm.edges if edge.is_boundary and
              all(abs(v.co.x)<5 and 157.5<v.co.y<161 for v in edge.verts)]
    assert len(aperture)>50
    bm.free()
    report[name]={'base_vertices':len(base_coords),'pilot_vertices':len(head.data.vertices),
                  'bones':base_bones,'shape_keys':base_keys,
                  'aperture_edges':len(aperture),
                  'original_vertices_and_weights_preserved':True}
print('CONNECTED_MOUTH_AUDIT',json.dumps(report,sort_keys=True),flush=True)
