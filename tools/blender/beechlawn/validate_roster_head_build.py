"""Exercise actual mesh regeneration with two independent sculpts and a master edit."""
from pathlib import Path
import json
import sys
import tempfile

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from shane_head_variants import (delta_data, apply_data, rebase_data, basis_fingerprint,
                                 layout_fingerprint, fingerprint)
from build_roster_heads import open_master

open_master()
head=bpy.data.objects['Skin_Head']
base=head.data
original=basis_fingerprint(base)
indices=sorted((v.index for v in base.vertices if v.co.y>158 and v.co.z>8),
               key=lambda i:(base.vertices[i].co-Vector((3,163,9))).length)
a,b=indices[:2]
edited_a=base.copy();edited_a.vertices[a].co.z+=.24
edited_b=base.copy();edited_b.vertices[a].co.x-=.11;edited_b.vertices[b].co.z+=.13
first=delta_data(base,edited_a);second=delta_data(base,edited_b)
new_base=base.copy()
# A valid common identity edit moves Basis and expressions together, just as
# the production sculpt applicator does. Editing mesh.vertices alone leaves
# an unrelated stale shape-key Basis and is not a valid master fixture.
for index,offset in [(a,Vector((0,.31,0))),(b,Vector((0,0,.08)))]:
    target=new_base.vertices[index].co+offset
    for key in new_base.shape_keys.key_blocks:
        key.data[index].co+=offset
    new_base.vertices[index].co=target
assert fingerprint(base)==fingerprint(new_base) and basis_fingerprint(base)!=basis_fingerprint(new_base)
rejected=[]
def must_reject(label,callback):
    try:callback()
    except AssertionError:rejected.append(label)
    else:raise AssertionError('Unsafe sculpt accepted: '+label)
new=head.copy();new.data=new_base.copy()
must_reject('stale same-topology Basis',lambda:apply_data(new,first))
bad=dict(first);bad['topology_sha256']='changed'
must_reject('different topology',lambda:apply_data(new,bad))
bad=dict(first);bad.pop('basis_sha256');bad['schema_version']=1
must_reject('legacy Basis-free delta',lambda:apply_data(head,bad))
bad_layout=new_base.copy();bad_layout.uv_layers.active.data[0].uv.x+=.02
must_reject('changed UV registration',lambda:rebase_data(first,base,bad_layout))

results=[]
for identity,data in [('first',first),('second',second)]:
    rebased=rebase_data(data,base,new_base)
    obj=head.copy();obj.data=new_base.copy()
    expression_before=[key.data[a].co-obj.data.shape_keys.key_blocks['Basis'].data[a].co
                       for key in obj.data.shape_keys.key_blocks]
    apply_data(obj,rebased)
    for vertex in obj.data.vertices:
        expected=new_base.vertices[vertex.index].co+Vector(data['offsets'].get(str(vertex.index),(0,0,0)))
        assert (vertex.co-expected).length<1e-5
        if vertex.co.y<154:
            assert (vertex.co-base.vertices[vertex.index].co).length<1e-5
    keys=obj.data.shape_keys.key_blocks
    assert (keys['Basis'].data[a].co-obj.data.vertices[a].co).length<1e-5
    for before,key in zip(expression_before,keys):
        assert (before-(key.data[a].co-keys['Basis'].data[a].co)).length<1e-5, 'Identity edit distorted an expression'
    assert layout_fingerprint(obj.data)==layout_fingerprint(base)
    results.append({'identity':identity,'common_edit_propagated':True,'personal_offsets_retained':True,
                    'neck_uv_weights_and_expression_offsets_preserved':True})
assert basis_fingerprint(base)==original,'Regeneration changed the authoritative master'

# Compare the promoted neutral to Shane's actually shipped sculpt, not a new fit.
with bpy.data.libraries.load(str(Path(__file__).with_name('shane_photo_head.blend')),link=False) as (source,target):
    target.objects=['Skin_Head']
assert basis_fingerprint(target.objects[0].data)==original,'Promotion altered Shane neutral geometry'
report={'result':'PASS','regenerated_variants':results,'rejected':rejected,
        'promoted_neutral_matches_shane':True,'master_unchanged':True,
        'limits':'Structural regeneration tests; not individual likeness or native performance approval'}
path=ROOT/'games/beechlawn_rovers/docs/art_briefs/shared_head_evidence/regeneration.json'
path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(report,indent=2)+'\n')
print('ROSTER_HEAD_REGENERATION',json.dumps(report))
