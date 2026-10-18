"""Versioned sparse sculpt deltas, applied offline to the shared head.

In Blender, edit a copy of Skin_Head's Basis coordinates without changing
topology. Save offsets with save_delta(base_mesh, edited_mesh, path), and
reapply to a rebuilt base with apply_delta(head_object, path). The neck seam
should remain fixed. This module never changes the common rig or animations.
"""
import hashlib,json
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
MANIFEST=ROOT/'games/beechlawn_rovers/assets/characters/shared/head_topology.json'

def fingerprint(mesh):
    topology=[list(p.vertices) for p in mesh.polygons]
    return hashlib.sha256(json.dumps([len(mesh.vertices),topology],separators=(',',':')).encode()).hexdigest()

def write_base_fingerprint(head):
    MANIFEST.parent.mkdir(parents=True,exist_ok=True)
    MANIFEST.write_text(json.dumps({'mesh':head.name,'vertices':len(head.data.vertices),
        'topology_sha256':fingerprint(head.data),'units':'armature-local centimetres',
        'source':'tools/blender/beechlawn/footballer_shared.blend'},indent=2)+'\n')

def save_delta(base,edited,path):
    assert fingerprint(base)==fingerprint(edited),'Head topology changed; transfer sculpt explicitly before export'
    offsets={str(i):list(b.co-a.co) for i,(a,b) in enumerate(zip(base.vertices,edited.vertices)) if (b.co-a.co).length>1e-6}
    Path(path).write_text(json.dumps({'topology_sha256':fingerprint(base),'offsets':offsets},indent=2)+'\n')

def apply_delta(head,path):
    data=json.loads(Path(path).read_text())
    assert data['topology_sha256']==fingerprint(head.data),'Incompatible head topology; sculpt was not applied'
    for index,offset in data['offsets'].items():head.data.vertices[int(index)].co+=Vector(offset)
    head.data.update()
