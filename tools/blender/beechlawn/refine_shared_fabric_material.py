"""Update only the current source material, retaining every mesh/rig/clip.

Read-only unless --apply. Requires build_shared_fabric_maps.py first.
"""
from pathlib import Path
import hashlib
import json
import sys
import bpy

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from repair_shared_kit import SOURCE, export_current


def geometry_state(rig):
    state = [('rig', [(b.name, tuple(v for row in b.matrix_local for v in row)) for b in rig.data.bones])]
    for action in sorted(bpy.data.actions, key=lambda a: a.name):
        state.append((action.name, [(f.data_path, f.array_index, [(tuple(k.co), tuple(k.handle_left), tuple(k.handle_right), k.interpolation) for k in f.keyframe_points]) for f in action.fcurves]))
    for obj in sorted((o for o in bpy.context.scene.objects if o.type == 'MESH'), key=lambda o:o.name):
        state.append((obj.name, tuple(v for row in obj.matrix_world for v in row),
            [tuple(v.co) for v in obj.data.vertices], [tuple(p.vertices) for p in obj.data.polygons],
            [(uv.name, [tuple(v.uv) for v in uv.data]) for uv in obj.data.uv_layers],
            [[(obj.vertex_groups[g.group].name, g.weight) for g in v.groups] for v in obj.data.vertices],
            [tuple(n.vector) for n in obj.data.corner_normals]))
    return hashlib.sha256(repr(state).encode()).hexdigest()


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    rig = bpy.data.objects['YBot_Armature']
    before = geometry_state(rig)
    material = bpy.data.materials['MAT_Beechlawn_HomeKit_Atlas']
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes['Principled BSDF']
    if '--apply' in sys.argv:
        textures = ROOT/'games/beechlawn_rovers/assets/characters/textures/shared'
        for socket, filename in (('Roughness', 'beechlawn_outfield_roughness.png'), ('Normal', 'fabric_knit_normal.png')):
            incoming = bsdf.inputs[socket].links[0].from_node
            tex = incoming.inputs['Color'].links[0].from_node if socket == 'Normal' else incoming
            assert tex.type == 'TEX_IMAGE', (socket, tex.type)
            image = bpy.data.images.load(str(textures/filename), check_existing=True)
            image.colorspace_settings.name = 'Non-Color'
            image.pack()
            tex.image = image
            if socket == 'Normal':
                incoming.inputs['Strength'].default_value = .35
        # Godot StandardMaterial3D has no equivalent cloth sheen lobe. Keep
        # both source and live review on portable metallic/roughness response.
        bsdf.inputs['Sheen Weight'].default_value = 0
        bsdf.inputs['Metallic'].default_value = 0
        bsdf.inputs['Specular IOR Level'].default_value = .5
        rig['fabric_response_revision'] = 1
        assert before == geometry_state(rig), 'Material work changed protected geometry/animation'
        export_current(rig)
    report = {'protected_geometry_rig_animation_before': before,
              'protected_geometry_rig_animation_after': geometry_state(rig),
              'same_geometry_rig_animation': before == geometry_state(rig),
              'bones': len(rig.data.bones), 'clips': len(bpy.data.actions),
              'source': str(SOURCE.relative_to(ROOT)), 'applied': '--apply' in sys.argv}
    out = ROOT/'games/beechlawn_rovers/docs/art_briefs/shared_fabric_response/source_validation.json'
    out.write_text(json.dumps(report, indent=2)+'\n')
    print('SHARED_FABRIC_SOURCE', json.dumps(report))


if __name__ == '__main__':
    main()
