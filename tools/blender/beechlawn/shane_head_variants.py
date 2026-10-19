"""Versioned sparse sculpt deltas, applied offline to the shared head.

In Blender, edit a copy of Skin_Head's Basis coordinates without changing
topology. Save offsets with save_delta(base_mesh, edited_mesh, path), and
reapply to a rebuilt base with apply_delta(head_object, path). The neck seam
should remain fixed. This module never changes the common rig or animations.
"""
import hashlib,json,struct,math
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
MANIFEST=ROOT/'games/beechlawn_rovers/assets/characters/shared/head_topology.json'

def fingerprint(mesh):
    topology=[list(p.vertices) for p in mesh.polygons]
    return hashlib.sha256(json.dumps([len(mesh.vertices),topology],separators=(',',':')).encode()).hexdigest()

def basis_fingerprint(mesh):
    """Topology alone cannot distinguish two different compatible sculpts."""
    return hashlib.sha256(b''.join(struct.pack('<3f',*v.co) for v in mesh.vertices)).hexdigest()

def layout_fingerprint(mesh):
    """UVs and indexed skin weights must survive an automatic Basis rebase."""
    uv=[tuple(round(c,7) for c in item.uv) for item in mesh.uv_layers.active.data]
    weights=[[(g.group,round(g.weight,7)) for g in v.groups] for v in mesh.vertices]
    return hashlib.sha256(json.dumps([uv,weights],separators=(',',':')).encode()).hexdigest()

def delta_data(base,edited):
    assert fingerprint(base)==fingerprint(edited),'Head topology changed; transfer sculpt explicitly before export'
    assert layout_fingerprint(base)==layout_fingerprint(edited),'UVs or weights changed; transfer explicitly'
    offsets={str(i):list(b.co-a.co) for i,(a,b) in enumerate(zip(base.vertices,edited.vertices)) if (b.co-a.co).length>1e-6}
    return {'schema_version':2,'topology_sha256':fingerprint(base),
            'basis_sha256':basis_fingerprint(base),'layout_sha256':layout_fingerprint(base),'offsets':offsets}

def rebase_data(data,old_base,new_base):
    """Keep personal offsets while applying a known compatible common edit."""
    validate_delta(data,old_base)
    assert fingerprint(old_base)==fingerprint(new_base),'Topology transfer required'
    assert layout_fingerprint(old_base)==layout_fingerprint(new_base),'UV/weight transfer required'
    rebased=dict(data)
    rebased['rebased_from']=data['basis_sha256']
    rebased['basis_sha256']=basis_fingerprint(new_base)
    return rebased

def validate_delta(data,base):
    assert data.get('schema_version')==2,'Legacy delta has no Basis identity; migrate it explicitly'
    assert data['topology_sha256']==fingerprint(base),'Incompatible head topology; sculpt was not applied'
    assert data['basis_sha256']==basis_fingerprint(base),'Stale Basis; rebase against the recorded master first'
    assert data['layout_sha256']==layout_fingerprint(base),'UVs or weights changed; transfer explicitly'
    for key,value in data['offsets'].items():
        assert 0<=int(key)<len(base.vertices) and len(value)==3 and all(math.isfinite(c) for c in value),'Invalid sculpt offset'

def apply_data(head,data):
    validate_delta(data,head.data)
    for index,offset in data['offsets'].items():
        index=int(index);offset=Vector(offset)
        target=head.data.vertices[index].co+offset
        # Identity changes translate every expression by the same offset;
        # changing only mesh.vertices leaves a shape-key Basis behind.
        if head.data.shape_keys:
            for key in head.data.shape_keys.key_blocks:
                key.data[index].co+=offset
        head.data.vertices[index].co=target
    head.data.update()

def write_base_fingerprint(head):
    MANIFEST.parent.mkdir(parents=True,exist_ok=True)
    MANIFEST.write_text(json.dumps({'mesh':head.name,'vertices':len(head.data.vertices),
        'topology_sha256':fingerprint(head.data),'units':'armature-local centimetres',
        'source':'tools/blender/beechlawn/footballer_shared.blend'},indent=2)+'\n')

def save_delta(base,edited,path):
    Path(path).write_text(json.dumps(delta_data(base,edited),indent=2)+'\n')

def apply_delta(head,path):
    apply_data(head,json.loads(Path(path).read_text()))
