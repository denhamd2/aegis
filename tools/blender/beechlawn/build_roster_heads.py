"""Build the common head and individual sculpts without rebuilding the body.

Normal: blender -b --python-exit-code 1 --python <this-file>
First promotion: append -- --promote
Editable player source: -- --edit-player john_orourke
Capture an edited source: -- --capture-player john_orourke --sculpt /path/to.blend
Compatible common edits are rebased against immutable recorded Basis snapshots.
"""
from pathlib import Path
import argparse
import gzip
import hashlib
import json
import re
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from shane_head_variants import (fingerprint, basis_fingerprint, layout_fingerprint,
                                 delta_data, apply_data, rebase_data, validate_delta)

PROJECT = ROOT / "games/beechlawn_rovers"
PIPE = Path(__file__).parent / "head_pipeline"
SOURCE = Path(__file__).with_name("footballer_head_master.blend")
ASSETS = PROJECT / "assets/characters/shared/heads"
EVIDENCE = PROJECT / "docs/art_briefs/shared_head_evidence"
PARTS = ("Skin_Head", "Eye_l", "Eye_r")


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def open_master():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    rig = bpy.data.objects["YBot_Armature"]
    assert len(rig.data.bones) == 65
    rig.animation_data_clear()
    for name in PARTS:
        keys = bpy.data.objects[name].data.shape_keys
        if keys:
            for key in keys.key_blocks:
                key.value = 0
            assert all((keypoint.co-vertex.co).length < 1e-5
                       for keypoint,vertex in zip(keys.key_blocks[0].data,bpy.data.objects[name].data.vertices)), 'Master mesh and neutral Basis disagree; edit the Basis before rebuilding'
    return rig


def snapshot():
    parts = {}
    for name in PARTS:
        mesh = bpy.data.objects[name].data
        parts[name] = {"topology_sha256": fingerprint(mesh), "basis_sha256": basis_fingerprint(mesh),
                       "layout_sha256": layout_fingerprint(mesh),
                       "coordinates": [list(v.co) for v in mesh.vertices]}
    revision = hashlib.sha256(json.dumps(parts, sort_keys=True).encode()).hexdigest()
    return {"revision": revision, "parts": parts}


def save_snapshot(data):
    path = PIPE / "bases" / (data["revision"] + ".json.gz")
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        # Immutable, reproducible archive rather than a timestamped gzip stream.
        path.write_bytes(gzip.compress(json.dumps(data, sort_keys=True).encode(), mtime=0))


def promote():
    assert not SOURCE.exists(), "Master already exists; edit it in place instead of re-promoting"
    bpy.ops.wm.open_mainfile(filepath=str(Path(__file__).with_name("shane_photo_head.blend")))
    head = bpy.data.objects["Skin_Head"]
    if head.data.shape_keys:
        head.data.shape_keys.key_blocks["Shane_Smile"].name = "Smile"
    for obj in list(bpy.context.scene.objects):
        if obj.name not in (*PARTS, "YBot_Armature"):
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), compress=True)


def bootstrap(current):
    path = PIPE / "roster.json"
    if path.exists():
        return json.loads(path.read_text())
    roster = {}
    for profile in sorted((PROJECT / "data/squads").glob("*.tres")):
        text = profile.read_text()
        identity = re.search(r'player_id = &"([^"]+)"', text)[1]
        name = re.search(r'display_name = "([^"]+)"', text)[1]
        roster[identity] = {"display_name": name, "profiles": [str(profile.relative_to(PROJECT))],
                            "sculpt": "deltas/" + identity + ".json", "hair": "legacy_crop",
                            "likeness": "starting head; individual likeness pending"}
    for profile in sorted((PROJECT / "data/players").glob("*.tres")):
        identity = re.search(r'player_id = &"([^"]+)"', profile.read_text())[1]
        if identity in roster:
            roster[identity]["profiles"].append(str(profile.relative_to(PROJECT)))
        else:
            roster[identity] = {"display_name": identity, "profiles": [str(profile.relative_to(PROJECT))],
                                "identity_source": "bordeaux_09", "hair": "bald",
                                "likeness": "legacy fixture explicitly reuses Des Feeney"}
    roster["shane_denham"]["hair"] = "shane_crop"
    roster["shane_denham"]["likeness"] = "photo-led reconstruction; review in progress"
    for identity in ("bordeaux_09", "bordeaux_01", "paddy_mason"):
        roster[identity]["hair"] = "bald"
    roster["des_feeney_sr"] = {"display_name": "Des Feeney Sr.",
                               "profiles": ["data/officials/referee.tres"],
                               "sculpt": "deltas/des_feeney_sr.json", "hair": "bald",
                               "likeness": "starting head; referee likeness pending"}
    result = {"schema_version": 1, "master_source": str(SOURCE.relative_to(ROOT)), "players": roster}
    write_json(path, result)
    for identity, entry in roster.items():
        if "sculpt" in entry:
            write_json(PIPE / entry["sculpt"], {"player_id": identity, "master_revision": current["revision"],
                        "parts": {name: delta_data(bpy.data.objects[name].data, bpy.data.objects[name].data)
                                  for name in PARTS}})
    return result


def resolve_sculpt(entry, current):
    data = json.loads((PIPE / entry["sculpt"]).read_text())
    if data["master_revision"] != current["revision"]:
        old_path = PIPE / "bases" / (data["master_revision"] + ".json.gz")
        assert old_path.exists(), "Unknown Basis revision; restore its recorded snapshot before rebasing"
        old = json.loads(gzip.decompress(old_path.read_bytes()))
        for name in PARTS:
            info = old["parts"][name]
            mesh = bpy.data.objects[name].data
            assert info["topology_sha256"] == fingerprint(mesh), "Topology changed; explicit sculpt transfer required"
            assert info["layout_sha256"] == layout_fingerprint(mesh), "UVs/weights changed; explicit transfer required"
            old_mesh = mesh.copy()
            for vertex, point in zip(old_mesh.vertices, info["coordinates"]):
                vertex.co = point
            data["parts"][name] = rebase_data(data["parts"][name], old_mesh, mesh)
            bpy.data.meshes.remove(old_mesh)
        data["rebased_from"] = data["master_revision"]
        data["master_revision"] = current["revision"]
    for name in PARTS:
        validate_delta(data["parts"][name], bpy.data.objects[name].data)
    for index, offset in data["parts"]["Skin_Head"]["offsets"].items():
        assert bpy.data.objects["Skin_Head"].data.vertices[int(index)].co.y >= 154 or Vector(offset).length < 1e-5, "Individual sculpt moved the shared neck seam"
    return data


def apply_sculpt_part(obj, data, protect_neck=False):
    mesh = obj.data
    # Custom split normals live on corners, not vertex.normal. Retain the
    # actual seam shading before editing/recalculating the facial surface.
    original = [normal.vector.copy() for normal in mesh.corner_normals]
    apply_data(obj, data)
    if data['offsets']:
        if mesh.has_custom_normals:
            with bpy.context.temp_override(object=obj, active_object=obj):
                bpy.ops.mesh.customdata_custom_splitnormals_clear()
        mesh.update()
        normals = [normal.vector.copy() for normal in mesh.corner_normals]
        if protect_neck:
            for index, loop in enumerate(mesh.loops):
                if mesh.vertices[loop.vertex_index].co.y < 154:
                    normals[index] = original[index]
        mesh.normals_split_custom_set(normals)


def apply_sculpt(data):
    for name in PARTS:
        apply_sculpt_part(bpy.data.objects[name], data['parts'][name], name == 'Skin_Head')


def saved_finish(identity):
    """Use the current artist's materials/expressions after proving the cage.

    Rebuilding geometry must not discard newer painted skin or regenerate all
    atlases. Source/delta disagreement is an error requiring explicit capture.
    """
    from author_four_head_finish import SOURCES
    sources = {**SOURCES, 'robbie_roden':'robbie_roden_head.blend',
               'david_murray':'david_murray_head.blend'}
    source = Path(__file__).parent/sources[identity]
    if not source.exists():
        from player_head_finish import finish_head
        finish_head(bpy.data.objects['Skin_Head'],identity)
        return [obj.name for obj in bpy.context.scene.objects if obj.name.startswith('Mouth_')]
    with bpy.data.libraries.load(str(source),link=False) as (available,target):
        target.objects=list(PARTS)+[name for name in available.objects if name.startswith('Mouth_')]
    for name,original in zip(PARTS,target.objects[:len(PARTS)]):
        obj=bpy.data.objects[name]
        assert layout_fingerprint(obj.data)==layout_fingerprint(original.data), 'Capture/transfer source layout before export: '+identity
        assert len(obj.data.vertices)==len(original.data.vertices)
        assert max((a.co-b.co).length for a,b in zip(obj.data.vertices,original.data.vertices))<1e-5, 'Capture the newer source sculpt before export: '+identity
        obj.data.materials.clear()
        for material in original.data.materials: obj.data.materials.append(material)
        if original.data.shape_keys:
            if not obj.data.shape_keys: obj.shape_key_add(name='Basis')
            for shape in original.data.shape_keys.key_blocks:
                key=obj.data.shape_keys.key_blocks.get(shape.name) or obj.shape_key_add(name=shape.name)
                for point,value in zip(key.data,shape.data): point.co=value.co
                key.value=0
    supplemental=[]
    from shane_anatomical_foundation import attach
    for obj in target.objects[len(PARTS):]:
        attach(obj,bpy.data.objects['YBot_Armature'])
        bpy.context.collection.objects.link(obj)
        supplemental.append(obj.name)
    for obj in target.objects[:len(PARTS)]: bpy.data.objects.remove(obj,do_unlink=True)
    return supplemental


def export(path, names):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for name in ("YBot_Armature", *names):
        bpy.data.objects[name].select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects["YBot_Armature"]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=True, export_cameras=False, export_lights=False,
        export_animations=False, export_skins=True, export_influence_nb=4,
        export_leaf_bone=False, export_rest_position_armature=True, export_morph=True)


def patch_profile(path, head_path, hair):
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('[gd_resource type="Resource" script_class="FootballerProfile" load_steps=3 format=3]\n'
            '[ext_resource type="Script" path="res://scripts/data/footballer_profile.gd" id="1"]\n'
            '[ext_resource type="Script" path="res://scripts/data/football_appearance.gd" id="3"]\n'
            '[sub_resource type="Resource" id="Appearance"]\nscript = ExtResource("3")\nkit = "referee"\n'
            '[resource]\nscript = ExtResource("1")\nplayer_id = &"des_feeney_sr"\ndisplay_name = "Des Feeney Sr."\nappearance = SubResource("Appearance")\n')
    text = path.read_text()
    text = re.sub(r'^\[ext_resource[^\n]*(?:id="head_pipeline_(?:head|hair|skin)"|path="res://assets/characters/(?:shane/shane_photo_head|shared/heads/des_side_hair)\.glb")[^\n]*\]\n', '', text, flags=re.M)
    text = re.sub(r'^(?:head_variant|hair_variant|hair_style) = .*\n', '', text, flags=re.M)
    text = re.sub(r'^head_albedo = ExtResource\("head_pipeline_skin"\)\n', '', text, flags=re.M)
    match = re.search(r'appearance = SubResource\("([^"]+)"\)', text)
    if match:
        appearance = match[1]
    else:
        appearance = "HeadAppearance"
        text = text.replace('[resource]', '[sub_resource type="Resource" id="HeadAppearance"]\n'
            'script = ExtResource("head_pipeline_appearance")\nkit = "' +
            ('bordeaux_keeper' if 'bordeaux_goalkeeper' in path.name else 'bordeaux_outfield' if 'bordeaux' in path.name else 'beechlawn_keeper' if 'john_orourke' in path.name else 'beechlawn_outfield') + '"\n\n[resource]')
        text += '\nappearance = SubResource("HeadAppearance")\n'
        text = text.replace('[sub_resource', '[ext_resource type="Script" path="res://scripts/data/football_appearance.gd" id="head_pipeline_appearance"]\n[sub_resource', 1)
    declarations = '[ext_resource type="PackedScene" path="res://' + str(head_path.relative_to(PROJECT)) + '" id="head_pipeline_head"]\n'
    hair_packages = {"shane_crop": "shane_crop.glb", "des_side_hair": "des_side_hair.glb",
                     "john_swept": "john_swept.glb", "referee_grey": "referee_grey.glb",
                     "robbie_crop": "robbie_crop.glb", "david_crop": "david_crop.glb"}
    if hair in hair_packages:
        declarations += '[ext_resource type="PackedScene" path="res://assets/characters/shared/heads/' + hair_packages[hair] + '" id="head_pipeline_hair"]\n'
    text = text.replace('[sub_resource', declarations + '[sub_resource', 1)
    fields = '\nhead_variant = ExtResource("head_pipeline_head")\nhair_style = "' + ('custom' if hair in hair_packages else hair) + '"\n'
    if hair in hair_packages:
        fields += 'hair_variant = ExtResource("head_pipeline_hair")\n'
    pattern = r'(\[sub_resource[^\n]*id="' + re.escape(appearance) + r'"\][\s\S]*?)(?=\n\[|\Z)'
    text, count = re.subn(pattern, lambda m: m[1].rstrip() + fields + '\n', text, count=1)
    assert count == 1, path
    steps = len(re.findall(r'^\[(?:ext_resource|sub_resource) ', text, re.M)) + 1
    text = re.sub(r'load_steps=\d+', 'load_steps=' + str(steps), text, count=1)
    if text != path.read_text():
        path.write_text(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--promote', action='store_true')
    parser.add_argument('--edit-player')
    parser.add_argument('--capture-player')
    parser.add_argument('--sculpt', type=Path)
    parser.add_argument('--only-player', nargs='+', help='Export only these individual packages on the unchanged common master')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    if args.promote:
        promote()
    open_master()
    current = snapshot()
    previous = PIPE / 'master.json'
    if previous.exists():
        old_revision = json.loads(previous.read_text())['revision']
        old_path = PIPE / 'bases' / (old_revision + '.json.gz')
        assert old_path.exists(), 'Restore the recorded master snapshot before rebuilding'
        old = json.loads(gzip.decompress(old_path.read_bytes()))
        for name in PARTS:
            assert old['parts'][name]['topology_sha256'] == current['parts'][name]['topology_sha256'], 'Master topology transfer required'
            assert old['parts'][name]['layout_sha256'] == current['parts'][name]['layout_sha256'], 'Master UV/weight transfer required'
        # Common head updates must also preserve the body's neck interface.
        for i, point in enumerate(old['parts']['Skin_Head']['coordinates']):
            if point[1] < 154:
                assert (Vector(point)-bpy.data.objects['Skin_Head'].data.vertices[i].co).length < 1e-5, 'Common neck seam moved'
    roster = bootstrap(current)
    entries = roster['players']
    sculpts = {identity: resolve_sculpt(entry, current) for identity, entry in entries.items() if 'sculpt' in entry}
    if args.only_player:
        assert set(args.only_player) <= set(sculpts), 'Unknown individual sculpt'
        assert previous.exists() and json.loads(previous.read_text())['revision']==current['revision'], 'A changed common master requires a complete roster build'
    assert snapshot()['revision'] == current['revision'], 'Resolving deltas mutated the common master'
    if args.capture_player:
        assert args.sculpt and args.capture_player in sculpts
        bpy.ops.wm.open_mainfile(filepath=str(args.sculpt.resolve()))
        assert bpy.context.scene.get('head_master_revision') == current['revision'], 'Editable source is stale; regenerate it before capture'
        assert bpy.context.scene.get('head_player_id') == args.capture_player, 'Editable source belongs to a different player'
        assert bpy.data.objects['Skin_Head'].active_shape_key_index == 0, 'Capture the neutral Basis, not an expression key'
        # Cross-file mesh data is removed on open_mainfile: retain reference
        # coordinates/layout by appending the authoritative master instead.
        with bpy.data.libraries.load(str(SOURCE), link=False) as (source, target):
            target.objects = list(PARTS)
        base_objects = target.objects
        parts = {name: delta_data(base.data, bpy.data.objects[name].data) for name, base in zip(PARTS, base_objects)}
        data = {'player_id': args.capture_player, 'master_revision': current['revision'], 'parts': parts}
        # Validate seam changes before persisting any captured sculpt.
        open_master()
        for index, offset in parts['Skin_Head']['offsets'].items():
            assert bpy.data.objects['Skin_Head'].data.vertices[int(index)].co.y >= 154 or Vector(offset).length < 1e-5, 'Sculpt moved neck seam'
        write_json(PIPE / entries[args.capture_player]['sculpt'], data)
        sculpts[args.capture_player] = data
    if args.edit_player:
        assert args.edit_player in sculpts
        apply_sculpt(sculpts[args.edit_player])
        bpy.context.scene['head_master_revision'] = current['revision']
        bpy.context.scene['head_player_id'] = args.edit_player
        path = PIPE / 'work' / (args.edit_player + '.blend')
        path.parent.mkdir(parents=True, exist_ok=True)
        assert not path.exists(), 'Editable source exists; open it instead of overwriting your sculpt'
        bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)
        print('EDIT_PLAYER_HEAD', path)
        return
    # All recipes were validated before overwriting any runtime export.
    if not args.only_player:
        export(ASSETS / 'master.glb', PARTS)
    outputs = {}
    for identity, data in sculpts.items():
        changed = any(part['offsets'] for part in data['parts'].values())
        outputs[identity] = ASSETS / 'master.glb'
        if changed:
            outputs[identity] = ASSETS / 'players' / (identity + '.glb')
            if not args.only_player or identity in args.only_player:
                open_master();apply_sculpt(data)
                from player_head_finish import IDENTITIES
                supplemental=[]
                if identity in (*IDENTITIES,'robbie_roden','david_murray'):
                    supplemental=saved_finish(identity)
                export(outputs[identity], (*PARTS,*supplemental))
            else:
                assert outputs[identity].exists(), 'Unselected package is missing; run a full build'
        write_json(PIPE / entries[identity]['sculpt'], data)
    # Hair uses the same master/identity build, but remains a separate selection.
    from player_head_groom import build_groom
    for identity, filename in (('shane_denham', 'shane_crop.glb'),
                               ('bordeaux_09', 'des_side_hair.glb'),
                               ('john_orourke', 'john_swept.glb'),
                               ('des_feeney_sr', 'referee_grey.glb')):
        if args.only_player and identity not in args.only_player:
            continue
        open_master();apply_sculpt(sculpts[identity])
        build_groom(bpy.data.objects['Skin_Head'], bpy.data.objects['YBot_Armature'], identity)
        export(ASSETS / filename, ('Hair_Shane_ShortCropRoots', 'Hair_Shane_ShortCropCards'))
    # New identities use short crops and their own scalp fields/pigment.
    for identity, filename in (
            ('robbie_roden','robbie_crop.glb'),
            ('david_murray','david_crop.glb')):
        if args.only_player and identity not in args.only_player:
            continue
        open_master();apply_sculpt(sculpts[identity])
        build_groom(bpy.data.objects['Skin_Head'],bpy.data.objects['YBot_Armature'],identity)
        export(ASSETS/filename,('Hair_Shane_ShortCropRoots','Hair_Shane_ShortCropCards'))
    for identity, entry in entries.items():
        output = outputs[entry.get('identity_source', identity)]
        for profile in entry['profiles']:
            patch_profile(PROJECT / profile, output, entry['hair'])
    save_snapshot(current)
    write_json(previous, {'schema_version': 1, 'revision': current['revision'],
                         'snapshot': 'bases/' + current['revision'] + '.json.gz'})
    report = {'master_revision': current['revision'], 'recipe_count': len(entries),
              'independent_sculpt_slots': len(sculpts),
              'nonempty_sculpts': [identity for identity,data in sculpts.items() if any(p['offsets'] for p in data['parts'].values())],
              'rebased_sculpts': [identity for identity,data in sculpts.items() if data.get('rebased_from')],
              'shared_output': 'res://assets/characters/shared/heads/master.glb',
              'hair': {identity:entry['hair'] for identity,entry in entries.items()},
              'limits': 'Unfinished identities still share a starting head; no native M1 performance claim'}
    write_json(EVIDENCE / 'build.json', report)
    print('ROSTER_HEAD_BUILD', json.dumps(report))


if __name__ == '__main__':
    main()
