"""Compare the shipped Des #9 head geometry with its editable Blender source.

Run with Blender --python-exit-code 1 --python <this-file>. This catches stale
captured deltas even when the roster happens to point to a valid GLB package.
"""
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import bpy
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

ROOT=Path(__file__).resolve().parents[3]
ASSET=ROOT/'games/beechlawn_rovers/assets/characters/shared/heads/players/bordeaux_09.glb'
SOURCE=Path(__file__).with_name('des_feeney_head.blend')
OUT=ROOT/'games/beechlawn_rovers/docs/art_briefs/des_feeney_player_likeness/export_audit.json'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
raw=ASSET.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
document=json.loads(raw[20:20+length]);binary=raw[28+length:]


def array(index):
    accessor=document['accessors'][index];view=document['bufferViews'][accessor['bufferView']]
    assert accessor['componentType']==5126 and accessor['type']=='VEC3'
    return np.ndarray((accessor['count'],3),dtype='<f4',buffer=binary,
                      offset=view.get('byteOffset',0)+accessor.get('byteOffset',0),
                      strides=(view.get('byteStride',12),4))


parts={}
for name in ('Skin_Head','Eye_l','Eye_r'):
    mesh=next(m for m in document['meshes'] if m['name']==name)
    actual=np.concatenate([array(p['attributes']['POSITION']) for p in mesh['primitives']])
    expected=[v.co*.01 for v in bpy.data.objects[name].data.vertices]
    expected_tree=KDTree(len(expected))
    for index,point in enumerate(expected):expected_tree.insert(point,index)
    expected_tree.balance()
    actual_tree=KDTree(len(actual))
    for index,point in enumerate(actual):actual_tree.insert(Vector(point),index)
    actual_tree.balance()
    error=max(max(expected_tree.find(Vector(p))[2] for p in actual),
              max(actual_tree.find(p)[2] for p in expected))
    assert error<2e-6, f'{name}: shipped geometry does not match the editable source ({error}m)'
    if name=='Skin_Head':
        assert all(not any(k.startswith('COLOR_') for k in p['attributes']) for p in mesh['primitives']), 'Legacy vertex tint remained in the exported head'
    parts[name]={'source_vertices':len(expected),'exported_vertices':len(actual),
                 'max_source_difference_m':error,'bounds_m':[actual.min(0).tolist(),actual.max(0).tolist()]}
image_names=[image['name'] for image in document.get('images',[])]
assert len(image_names)==4 and all(name.startswith('bordeaux_09_finish_') for name in image_names), image_names
textures=[]
for image in document['images']:
    view=document['bufferViews'][image['bufferView']];offset=view.get('byteOffset',0)
    width,height=struct.unpack_from('>II',binary,offset+16)
    textures.append({'name':image['name'],'width':width,'height':height})
with bpy.data.libraries.load(str(Path(__file__).with_name('footballer_head_master.blend')),link=False) as (library, loaded):
    loaded.images=[name for name in library.images if 'head' in name and 'albedo' in name]
assert len(loaded.images)==1, 'Resolve the common head albedo before auditing the neck join'
shared=loaded.images[0]
image=next(i for i in document['images'] if 'anatomical_albedo' in i['name'])
view=document['bufferViews'][image['bufferView']];offset=view.get('byteOffset',0)
with tempfile.NamedTemporaryFile(suffix='.png') as temporary:
    temporary.write(binary[offset:offset+view['byteLength']]);temporary.flush()
    exported=bpy.data.images.load(temporary.name,check_existing=False)
    pixels=[]
    for image in (shared,exported):
        assert tuple(image.size)==(2048,2048)
        data=np.empty(2048*2048*4,dtype=np.float32);image.pixels.foreach_get(data)
        pixels.append(data.reshape(2048,2048,4)[:,:,:3])
    mesh=bpy.data.objects['Skin_Head'].data
    differences=[]
    for loop in mesh.loops:
        vertex=mesh.vertices[loop.vertex_index]
        if vertex.co.y>=154.0 or vertex.co.z<0:continue
        u,v=mesh.uv_layers.active.data[loop.index].uv
        x,y=min(2047,int(u*2047)),min(2047,int(v*2047))
        differences.append(np.abs(pixels[0][y,x]-pixels[1][y,x]))
    differences=np.asarray(differences)
    neck={'samples':len(differences),'median_linear_difference':float(np.median(differences)),
          'p99_linear_difference':float(np.quantile(differences,.99))}
    assert neck['median_linear_difference']<.008 and neck['p99_linear_difference']<.025, f'Head/body neck pigment discontinuity: {neck}'
    bpy.data.images.remove(exported)
report={'result':'PASS','player':'Boardeaux Des Feeney #9','source':str(SOURCE.relative_to(ROOT)),
        'asset':str(ASSET.relative_to(ROOT)),'asset_sha256':hashlib.sha256(raw).hexdigest(),
        'parts':parts,'embedded_textures':textures,'shared_neck_albedo':neck,'scope':'Neutral source/export geometry, direct player-only textures and preserved neck pigment; runtime skin binds and poses checked separately'}
OUT.write_text(json.dumps(report,indent=2)+'\n')
print('DES_SOURCE_EXPORT_AUDIT',json.dumps(report))
