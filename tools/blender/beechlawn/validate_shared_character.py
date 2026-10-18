"""Inspect the real shared .blend and GLB, including sculpt-delta preservation."""
from pathlib import Path
import sys,json,struct,tempfile
import bpy

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from shane_head_variants import fingerprint,save_delta,apply_delta
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tools/blender/beechlawn/footballer_shared.blend'))
rig=bpy.data.objects['YBot_Armature']
assert len(rig.data.bones)==65
for name in ('Skin_Head','YBot_Joints','Skin_Hands','YBot_Surface','Kit_Shirt_ShortSleeve','Kit_Shorts','Kit_Socks'):
    obj=bpy.data.objects[name]
    assert any(m.type=='ARMATURE' and m.object==rig for m in obj.modifiers),(name,'rig binding')
    for vertex in obj.data.vertices:
        positive=[g.weight for g in vertex.groups if g.weight>1e-6]
        assert len(positive)<=4 and abs(sum(positive)-1)<.002,(name,vertex.index,positive)
head=bpy.data.objects['Skin_Head']
manifest=json.loads((ROOT/'games/beechlawn_rovers/assets/characters/shared/head_topology.json').read_text())
assert fingerprint(head.data)==manifest['topology_sha256']
edited=head.data.copy();edited.vertices[20].co.z+=.05
with tempfile.TemporaryDirectory() as tmp:
    path=Path(tmp)/'test.json';save_delta(head.data,edited,path)
    copy=head.copy();copy.data=head.data.copy();apply_delta(copy,path)
    assert (copy.data.vertices[20].co-edited.vertices[20].co).length<1e-5
    bad=json.loads(path.read_text());bad['topology_sha256']='incompatible';path.write_text(json.dumps(bad))
    try:apply_delta(copy,path)
    except AssertionError:pass
    else:raise AssertionError('Incompatible head topology was accepted')
    mesh_copy=copy.data
    bpy.data.objects.remove(copy,do_unlink=True)
    bpy.data.meshes.remove(mesh_copy)
bpy.data.meshes.remove(edited)
raw=(ROOT/'games/beechlawn_rovers/assets/characters/shared/footballer_base.glb').read_bytes()
size=struct.unpack_from('<I',raw,12)[0];gltf=json.loads(raw[20:20+size])
triangles=sum(p['attributes']['POSITION'] is not None and gltf['accessors'][p['indices']]['count']//3 for mesh in gltf['meshes'] for p in mesh['primitives'])
report={'bones':65,'actions':[a['name'] for a in gltf['animations']],
    'triangles_all_variants':triangles,'mesh_parts':len(gltf['meshes']),'bytes':len(raw),
    'parts':[m['name'] for m in gltf['meshes']],
    'topology_sha256':manifest['topology_sha256'],'sculpt_delta_roundtrip':True,'incompatible_topology_rejected':True,
    'limits':'Includes both sleeve variants. Not an M1 timing result or likeness acceptance.'}
for action in ('AN_Beechlawn_KeeperSet','AN_Beechlawn_KeeperSave','AN_Beechlawn_PassRight'):
    assert action in report['actions']
# Locomotion arms must hang below the shoulder rather than retaining T-pose.
arm_checks={}
for name in ('AN_Beechlawn_Idle','AN_Beechlawn_Jog','AN_Beechlawn_Sprint','AN_Beechlawn_CloseControl'):
    rig.animation_data.action=bpy.data.actions[name]
    bpy.context.scene.frame_set(12)
    upper=rig.pose.bones['mixamorig:LeftArm'].matrix.translation
    elbow=rig.pose.bones['mixamorig:LeftForeArm'].matrix.translation
    drop=float(upper.y-elbow.y)
    assert drop>15,(name,'horizontal/T-pose upper arm',drop)
    arm_checks[name]={'shoulder_to_elbow_drop_cm':round(drop,3)}
report['locomotion_arm_pose_checks']=arm_checks
out=ROOT/'games/beechlawn_rovers/docs/art_briefs/shared_character_validation.json'
out.write_text(json.dumps(report,indent=2)+'\n')
print('SHARED_CHARACTER_VALIDATION',json.dumps(report))
