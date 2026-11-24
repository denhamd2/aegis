"""Roman as the game shows him, into the Unreal port.

The port imported roman_reigns.glb as supplied, so Unreal's Roman lacked
everything core/match/roman_model.gd does to it at runtime: his build
(BodyBulk), his face (RomanFaceShape), the trimmed beard and its fibre groom,
the hair's volume and flyaways, the ringlets and the scalp roots.
game/tools/unreal_export/roman_bake.gd runs that headless and writes the
result as two glTFs, one per skeleton; this imports them onto the skeletons
the port already has (so the retargeted clips in RomanRetarget and
RomanClothesRetarget play on them unchanged) and gives every slot its
material: port_materials.py's instances for the slots the supplied model
had, and three new card instances for the parts it did not.

    godot --headless -s res://tools/unreal_export/roman_bake.gd -- /tmp/roman_baked_body.glb body
    godot --headless -s res://tools/unreal_export/roman_bake.gd -- /tmp/roman_baked_clothes.glb clothes
    python3 Tools/MCP/ue.py py ~/code/aegis/tools/unreal/import_roman_baked.py

AAegisWrestlerCharacter::SetupRomanVisual draws /Game/AegisTest/RomanBaked
when it is there. Idempotent: a re-run replaces the meshes in place.
"""
import json
import os
import re
import struct
import unreal

BAKED = os.environ.get("ROMAN_BAKED", "/tmp")
AEGIS = os.path.expanduser("~/code/aegis")
SRC = os.path.join(AEGIS, "game/assets/characters")
DEST = "/Game/AegisTest/RomanBaked"
RAW = "/Game/AegisTest/Roman/roman_reigns/"
SKELETONS = {
    "body": RAW + "SkeletalMeshes/J_Hips_67ba20366b8ebad6c488009f6ec2f619_Skeleton",
    "clothes": RAW + "SkeletalMeshes/roman_ProxyTrueRootJoint_Skeleton",
}
TEX = "/Game/AegisTest/Textures/Roman"
INST = "/Game/AegisTest/Materials/Instances"
CARD = "/Game/AegisTest/Materials/Master/M_AegisCard"
EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary
AT = unreal.AssetToolsHelpers.get_asset_tools()

# roman_model.gd's colours (linear, as port_materials.py passes them).
HAIR_COLOR = (0.045, 0.042, 0.043)
UNDERPAINT = (0.60, 0.65, 0.70)

# The baked slot names (roman_bake.gd: the source material's name, else the
# part's) to the instances that draw them.
SLOTS = {
    "Material": "MI_roman_body",
    "Material_001": "MI_roman_head",
    "Material_004": "MI_roman_bottoms",
    "Material_005": RAW + "Materials/Material_005",   # shoes: the supplied material
    "Material_006": "MI_roman_l_wrist",
    "Material_007": "MI_roman_r_wrist",
    "Material_013": "MI_roman_eye",
    "Material_016": "MI_roman_lash",
    "Material_018": "MI_roman_hair",
    "Material_019": "MI_roman_hair_4",
    "body_skinned2": "MI_roman_tongue",               # M_Tongue: 341 vertices in the mouth
    "mouthbag_skinned2": "MI_roman_mouth",
    "teeth_skinned2": "MI_roman_teeth",
    "Ringlets2": "MI_roman_ringlets",
    "RomanBeardFibres": "MI_roman_beard_groom",
    "RomanHairUnderpaint": "MI_roman_roots",
}

# The new cards, after the Godot materials that draw them.
NEW_TEXTURES = {"ringlets_alpha": "color", "beard_groom": "color", "portrait_roots": "color",
                "hair_4_strands_nrm": "normal"}
NEW_CARDS = {
    # _add_ringlets: the hair's colour, its scissor, the side strands' ridges.
    "MI_roman_ringlets": {"AlphaMap": "ringlets_alpha", "NormalMap": "hair_4_strands_nrm",
                          "Tint": HAIR_COLOR, "Roughness": 0.38, "Specular": 0.26,
                          "OpacityClip": 0.14, "NormalStrength": 1.0},
    # RomanBeardGroom: the atlas's own colour, matte.
    "MI_roman_beard_groom": {"AlphaMap": "beard_groom", "Tint": (1.0, 1.0, 1.0),
                             "Roughness": 0.78, "Specular": 0.10, "OpacityClip": 0.16,
                             "NormalStrength": 0.0},
    # _add_scalp_roots: the underpaint, tinted to black hair's reflectance.
    "MI_roman_roots": {"AlphaMap": "portrait_roots", "Tint": UNDERPAINT, "Roughness": 0.75,
                       "Specular": 0.12, "OpacityClip": 0.2, "NormalStrength": 0.0},
}


RAW_BODY = RAW + "SkeletalMeshes/M_Body_J_Hips_67ba20366b8ebad6c488009f6ec2f619"


def raw_bone_names(path):
    ell = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    a = ell.spawn_actor_from_class(unreal.SkeletalMeshActor, unreal.Vector(0, 0, -5000), unreal.Rotator())
    c = a.skeletal_mesh_component
    c.set_skinned_asset_and_update(unreal.load_asset(path))
    names = [str(c.get_bone_name(i)) for i in range(c.get_num_bones())]
    ell.destroy_actor(a)
    return names


def hashed_body(src_file):
    """The body's bones under the names the port's skeleton gave them.

    The port's first import kept the two skeletons apart by suffixing the
    body's bones with a 32-digit hash (J_Hips_67ba...), where Godot -- and
    so the bake -- has them plain. Unmatched, no clip track drives a bone and
    he stands in his bind pose. Renamed from the raw body mesh's own list.
    """
    to_hashed = {}
    for name in raw_bone_names(RAW_BODY):
        m = re.match(r"^(.*)_[0-9a-f]{32}$", name)
        to_hashed[m.group(1) if m else name] = name
    data = open(src_file, "rb").read()
    n = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + n])
    for node in doc["nodes"]:
        if node.get("name") in to_hashed:
            node["name"] = to_hashed[node["name"]]
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    rest = data[20 + n:]
    body = struct.pack("<I", len(text)) + b"JSON" + text + rest
    out = src_file.replace(".glb", "_ue.glb")
    with open(out, "wb") as f:
        f.write(data[:8] + struct.pack("<I", 12 + len(body)) + body)
    return out


def import_textures():
    tasks = []
    for name in NEW_TEXTURES:
        t = unreal.AssetImportTask()
        t.set_editor_property("filename", os.path.join(SRC, "roman_reigns_%s.png" % name))
        t.set_editor_property("destination_path", TEX)
        t.set_editor_property("destination_name", "T_Roman_" + name)
        t.set_editor_property("automated", True)
        t.set_editor_property("replace_existing", True)
        tasks.append(t)
    AT.import_asset_tasks(tasks)
    for name, kind in NEW_TEXTURES.items():
        tex = unreal.load_asset(TEX + "/T_Roman_" + name)
        if kind == "normal":
            tex.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_NORMALMAP)
            tex.set_editor_property("srgb", False)
            tex.set_editor_property("flip_green_channel", True)
        EAL.save_loaded_asset(tex, only_if_is_dirty=False)


def build_cards():
    for name, spec in NEW_CARDS.items():
        path = INST + "/" + name
        mi = unreal.load_asset(path) if EAL.does_asset_exist(path) else AT.create_asset(
            name, INST, unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
        MEL.set_material_instance_parent(mi, unreal.load_asset(CARD))
        for k, v in spec.items():
            if k in ("AlphaMap", "NormalMap"):
                MEL.set_material_instance_texture_parameter_value(mi, k, unreal.load_asset(TEX + "/T_Roman_" + v))
            elif isinstance(v, tuple):
                MEL.set_material_instance_vector_parameter_value(mi, k, unreal.LinearColor(v[0], v[1], v[2], 1.0))
            else:
                MEL.set_material_instance_scalar_parameter_value(mi, k, float(v))
        MEL.update_material_instance(mi)
        EAL.save_loaded_asset(mi, only_if_is_dirty=False)


def import_half(half):
    src_file = os.path.join(BAKED, "roman_baked_%s.glb" % half)
    if not os.path.exists(src_file):
        raise RuntimeError("no bake at %s: run roman_bake.gd first" % src_file)
    if half == "body":
        src_file = hashed_body(src_file)
    p = unreal.InterchangeGenericAssetsPipeline()
    cs = p.get_editor_property("common_skeletal_meshes_and_animations_properties")
    cs.set_editor_property("skeleton", unreal.load_asset(SKELETONS[half]))
    cs.set_editor_property("import_only_animations", False)
    mp = p.get_editor_property("mesh_pipeline")
    mp.set_editor_property("import_static_meshes", False)
    mp.set_editor_property("import_skeletal_meshes", True)
    mp.set_editor_property("create_physics_asset", False)
    mp.set_editor_property("import_morph_targets", False)
    p.get_editor_property("animation_pipeline").set_editor_property("import_animations", False)
    p.get_editor_property("material_pipeline").set_editor_property("import_materials", False)
    params = unreal.ImportAssetParameters()
    params.is_automated = True
    params.replace_existing = True
    params.override_pipelines = [unreal.SoftObjectPath(p.get_path_name())]
    mgr = unreal.InterchangeManager.get_interchange_manager_scripted()
    mgr.import_asset(DEST + "/" + half, unreal.InterchangeManager.create_source_data(src_file), params)


def assign(half):
    out = {}
    for a in EAL.list_assets(DEST + "/" + half, recursive=True, include_folder=False):
        mesh = unreal.load_asset(a)
        if not isinstance(mesh, unreal.SkeletalMesh):
            continue
        mats = mesh.get_editor_property("materials")
        names = []
        for i, slot in enumerate(mats):
            sm = slot.copy()
            key = str(sm.get_editor_property("material_slot_name"))
            want = SLOTS.get(key)
            if want:
                mi = unreal.load_asset(want if want.startswith("/") else INST + "/" + want)
                sm.set_editor_property("material_interface", mi)
                mats[i] = sm
            names.append((key, want))
        mesh.set_editor_property("materials", mats)
        EAL.save_loaded_asset(mesh, only_if_is_dirty=False)
        b = mesh.get_bounds()
        out[mesh.get_name()] = {"skeleton": mesh.get_editor_property("skeleton").get_name(),
                                "slots": names, "extent": [round(x, 1) for x in (b.box_extent.x, b.box_extent.y, b.box_extent.z)]}
    return out


import_textures()
build_cards()
result = {}
for half in ("body", "clothes"):
    import_half(half)
    result[half] = assign(half)
result
