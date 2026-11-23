"""Bring the venue pieces Godot builds in code into the Unreal port.

Run inside the UE 5.9 editor of the port project, after port_materials.py
(it reuses that script's M_AegisSurface master and its imported scans).
Idempotent.

Input: tools/unreal/venue/venue_generated.{glb,json}, written by
tools/unreal/export_venue.gd from the running Godot match. That covers what
no Blender .glb carries: the entrance set (stage deck and ramp, backdrop,
drape, truss, the curved video wall and its side screens, wing and centre
screens, floor cans), the barricade LED faces, AEW corner logos and blank
panels, the overhead rig's cans, and the runtime LED materials of the ribbon
boards and stair nosings.

Stages (set STAGES to run a subset):

  textures  import the art and scans the JSON names that port_materials.py
            did not (LED art, screen stills, Metal032, Fabric063)
  master    M_AegisEmissive: base colour, and an emissive map x colour x
            strength on UV x UVScale + UVOffset (Godot's uv1_scale/offset)
  meshes    import the .glb into /Game/AegisTest/Venue/
  media     MP_AegisStage (a looping media player), a FileMediaSource per
            clip in Content/Movies, and MT_AegisStage, the texture it plays to
  materials an instance per exported Godot material, from the JSON:
              emission ADD, or a screen   -> M_AegisEmissive
              everything else             -> M_AegisSurface (Godot's
                                             house-lit emission is not
                                             ported: the level has lights)
            The two video screens take MT_AegisStage instead of the still.
  place     a StaticMeshActor per mesh at the ring centre, labelled
            Aegis_Venue_<name>, and the ribbon/nosing materials on the bowl

The level's actors are placed with the scene origin at the ring centre on the
mat, which is where Godot's origin is.
"""
import json
import os

import unreal

AEGIS = os.path.expanduser(globals().get("AEGIS", "~/code/aegis"))
STAGES = globals().get("STAGES", ["textures", "master", "meshes", "media", "materials", "place"])
VENUE = os.path.join(AEGIS, "tools/unreal/venue/venue_generated")
GODOT_RES = os.path.join(AEGIS, "game")
RING_CENTRE = unreal.Vector(5694.8, 14654.5, 0.0)
## Godot's emission energies are relative to its own exposure; this maps them
## onto the Unreal level's. Solved on screenshots against the Godot frames.
EMISSIVE_GAIN = globals().get("EMISSIVE_GAIN", 4.0)

TEX_ENV = "/Game/AegisTest/Textures/Env"
TEX_DEFAULT = "/Game/AegisTest/Textures/Default"
MASTER_DIR = "/Game/AegisTest/Materials/Master"
MI_DIR = "/Game/AegisTest/Materials/Venue"
MESH_DIR = "/Game/AegisTest/Venue"
MEDIA_DIR = "/Game/AegisTest/Media"
BOWL = "/Game/AegisTest/Arena/arena_bowl/StaticMeshes/"
## The clips in Content/Movies (converted from game/assets/environment/video).
CLIPS = ["dynamite_tron", "roman_entrance", "cody_entrance", "kenny_entrance"]
VIDEO_SLOTS = ["VM_StageScreen", "VM_StageSideScreens"]

AT = unreal.AssetToolsHelpers.get_asset_tools()
EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary


def spec():
    with open(VENUE + ".json") as f:
        return json.load(f)


def tex_name(res_path):
    return "T_" + os.path.splitext(os.path.basename(res_path))[0]


def is_normal(res_path):
    n = res_path.lower()
    return "normal" in n or n.endswith("_nrm.png")


# ---------------------------------------------------------------------------

def import_textures():
    wanted = set()
    for m in spec()["materials"].values():
        for k in ("albedo_texture", "emission_texture", "normal_texture", "roughness_texture", "ao_texture"):
            p = m.get(k) or ""
            if p.startswith("res://"):
                wanted.add(p)
    jobs = [p for p in sorted(wanted) if not EAL.does_asset_exist(TEX_ENV + "/" + tex_name(p))]
    tasks = []
    for p in jobs:
        t = unreal.AssetImportTask()
        t.set_editor_property("filename", os.path.join(GODOT_RES, p[len("res://"):]))
        t.set_editor_property("destination_path", TEX_ENV)
        t.set_editor_property("destination_name", tex_name(p))
        t.set_editor_property("automated", True)
        t.set_editor_property("replace_existing", True)
        tasks.append(t)
    AT.import_asset_tasks(tasks)
    for p in jobs:
        tex = unreal.load_asset(TEX_ENV + "/" + tex_name(p))
        if is_normal(p):
            tex.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_NORMALMAP)
            tex.set_editor_property("srgb", False)
            tex.set_editor_property("flip_green_channel", True)
        elif any(k in p for k in ("Roughness", "AmbientOcclusion", "Metalness")):
            tex.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_MASKS)
            tex.set_editor_property("srgb", False)
        EAL.save_loaded_asset(tex, only_if_is_dirty=False)
    return len(jobs)


def tex(res_path):
    return unreal.load_asset(TEX_ENV + "/" + tex_name(res_path))


# ---------------------------------------------------------------------------

def _expr(m, cls, x, y, **props):
    e = MEL.create_material_expression(m, cls, x, y)
    for k, v in props.items():
        e.set_editor_property(k, v)
    return e


def _connect(m, a, b, cls, x, y, a_out="", b_out=""):
    e = _expr(m, cls, x, y)
    MEL.connect_material_expressions(a, a_out, e, "A")
    MEL.connect_material_expressions(b, b_out, e, "B")
    return e


def build_emissive():
    path = MASTER_DIR + "/M_AegisEmissive"
    if EAL.does_asset_exist(path):
        m = unreal.load_asset(path)
        MEL.delete_all_material_expressions(m)
    else:
        m = AT.create_asset("M_AegisEmissive", MASTER_DIR, unreal.Material, unreal.MaterialFactoryNew())
    white = unreal.load_asset(TEX_DEFAULT + "/T_Default_White")
    tc = _expr(m, unreal.MaterialExpressionTextureCoordinate, -1500, 0)
    sc = _expr(m, unreal.MaterialExpressionVectorParameter, -1500, 120, parameter_name="UVScale",
               default_value=unreal.LinearColor(1, 1, 0, 0))
    of = _expr(m, unreal.MaterialExpressionVectorParameter, -1500, 320, parameter_name="UVOffset",
               default_value=unreal.LinearColor(0, 0, 0, 0))
    sc2 = _expr(m, unreal.MaterialExpressionComponentMask, -1300, 120, r=True, g=True, b=False, a=False)
    of2 = _expr(m, unreal.MaterialExpressionComponentMask, -1300, 320, r=True, g=True, b=False, a=False)
    MEL.connect_material_expressions(sc, "", sc2, "")
    MEL.connect_material_expressions(of, "", of2, "")
    uv = _connect(m, _connect(m, tc, sc2, unreal.MaterialExpressionMultiply, -1150, 60), of2,
                  unreal.MaterialExpressionAdd, -1000, 100)
    # Base colour: Tint x lerp(1, ColorMap, ColorMapAmount), as M_AegisSurface.
    cmap = _expr(m, unreal.MaterialExpressionTextureSampleParameter2D, -800, -400, parameter_name="ColorMap",
                 texture=white, sampler_type=unreal.MaterialSamplerType.SAMPLERTYPE_COLOR)
    MEL.connect_material_expressions(uv, "", cmap, "UVs")
    camt = _expr(m, unreal.MaterialExpressionScalarParameter, -800, -180, parameter_name="ColorMapAmount", default_value=0.0)
    one = _expr(m, unreal.MaterialExpressionConstant, -600, -260, r=1.0)
    lerp = _expr(m, unreal.MaterialExpressionLinearInterpolate, -500, -400)
    MEL.connect_material_expressions(one, "", lerp, "A")
    MEL.connect_material_expressions(cmap, "RGB", lerp, "B")
    MEL.connect_material_expressions(camt, "", lerp, "Alpha")
    tint = _expr(m, unreal.MaterialExpressionVectorParameter, -500, -200, parameter_name="Tint",
                 default_value=unreal.LinearColor(0.02, 0.02, 0.025, 1))
    MEL.connect_material_property(_connect(m, lerp, tint, unreal.MaterialExpressionMultiply, -300, -350),
                                  "", unreal.MaterialProperty.MP_BASE_COLOR)
    # Emissive: EmissiveMap x EmissiveColor x EmissiveStrength.
    emap = _expr(m, unreal.MaterialExpressionTextureSampleParameter2D, -800, 100, parameter_name="EmissiveMap",
                 texture=white, sampler_type=unreal.MaterialSamplerType.SAMPLERTYPE_COLOR)
    MEL.connect_material_expressions(uv, "", emap, "UVs")
    ecol = _expr(m, unreal.MaterialExpressionVectorParameter, -800, 320, parameter_name="EmissiveColor",
                 default_value=unreal.LinearColor(1, 1, 1, 1))
    estr = _expr(m, unreal.MaterialExpressionScalarParameter, -600, 420, parameter_name="EmissiveStrength", default_value=1.0)
    e1 = _connect(m, emap, ecol, unreal.MaterialExpressionMultiply, -500, 150, a_out="RGB")
    MEL.connect_material_property(_connect(m, e1, estr, unreal.MaterialExpressionMultiply, -300, 200),
                                  "", unreal.MaterialProperty.MP_EMISSIVE_COLOR)
    MEL.connect_material_property(_expr(m, unreal.MaterialExpressionScalarParameter, -300, 400,
                                        parameter_name="Roughness", default_value=1.0),
                                  "", unreal.MaterialProperty.MP_ROUGHNESS)
    MEL.connect_material_property(_expr(m, unreal.MaterialExpressionScalarParameter, -300, 500,
                                        parameter_name="Specular", default_value=0.5),
                                  "", unreal.MaterialProperty.MP_SPECULAR)
    MEL.recompile_material(m)
    EAL.save_loaded_asset(m, only_if_is_dirty=False)
    return m


# ---------------------------------------------------------------------------

def import_meshes():
    t = unreal.AssetImportTask()
    t.set_editor_property("filename", VENUE + ".glb")
    t.set_editor_property("destination_path", MESH_DIR)
    t.set_editor_property("automated", True)
    t.set_editor_property("replace_existing", True)
    t.set_editor_property("save", True)
    AT.import_asset_tasks([t])
    return sorted(str(a.asset_name) for a in unreal.AssetRegistryHelpers.get_asset_registry()
                  .get_assets_by_path(MESH_DIR, recursive=True)
                  if str(a.asset_class_path.asset_name) == "StaticMesh")


def build_media():
    player_path = MEDIA_DIR + "/MP_AegisStage"
    player = unreal.load_asset(player_path) if EAL.does_asset_exist(player_path) else \
        AT.create_asset("MP_AegisStage", MEDIA_DIR, unreal.MediaPlayer, unreal.MediaPlayerFactoryNew())
    player.set_editor_property("play_on_open", True)
    player.set_looping(True)
    EAL.save_loaded_asset(player, only_if_is_dirty=False)
    for clip in CLIPS:
        p = MEDIA_DIR + "/FMS_" + clip
        src = unreal.load_asset(p) if EAL.does_asset_exist(p) else \
            AT.create_asset("FMS_" + clip, MEDIA_DIR, unreal.FileMediaSource, unreal.FileMediaSourceFactoryNew())
        src.set_file_path("./Movies/%s.mp4" % clip)
        EAL.save_loaded_asset(src, only_if_is_dirty=False)
    tp = MEDIA_DIR + "/MT_AegisStage"
    mt = unreal.load_asset(tp) if EAL.does_asset_exist(tp) else \
        AT.create_asset("MT_AegisStage", MEDIA_DIR, unreal.MediaTexture, unreal.MediaTextureFactoryNew())
    mt.set_editor_property("media_player", player)
    mt.set_editor_property("srgb", True)
    EAL.save_loaded_asset(mt, only_if_is_dirty=False)
    return [player_path, tp] + ["FMS_" + c for c in CLIPS]


# ---------------------------------------------------------------------------

def _set(mi, scal=None, vec=None, texs=None):
    MEL.clear_all_material_instance_parameters(mi)
    for k, v in (scal or {}).items():
        MEL.set_material_instance_scalar_parameter_value(mi, k, float(v))
    for k, v in (vec or {}).items():
        MEL.set_material_instance_vector_parameter_value(mi, k, unreal.LinearColor(v[0], v[1], v[2], 1.0))
    for k, v in (texs or {}).items():
        MEL.set_material_instance_texture_parameter_value(mi, k, v)


def build_materials():
    surface = unreal.load_asset(MASTER_DIR + "/M_AegisSurface")
    emissive = unreal.load_asset(MASTER_DIR + "/M_AegisEmissive")
    video = unreal.load_asset(MEDIA_DIR + "/MT_AegisStage")
    made = {}
    for slot, m in sorted(spec()["materials"].items()):
        name = "MI_" + slot[3:]
        path = MI_DIR + "/" + name
        mi = unreal.load_asset(path) if EAL.does_asset_exist(path) else \
            AT.create_asset(name, MI_DIR, unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
        if m.get("kind") != "standard":
            # ParLenses: a shader in Godot (lit lens faces); a warm glow here.
            MEL.set_material_instance_parent(mi, emissive)
            _set(mi, {"EmissiveStrength": 2.0 * EMISSIVE_GAIN}, {"EmissiveColor": (1.0, 0.85, 0.6), "Tint": (0.02, 0.02, 0.02)})
        elif slot in VIDEO_SLOTS or (m["emission_enabled"] and m["emission_operator"] == "add"):
            MEL.set_material_instance_parent(mi, emissive)
            etex = video if slot in VIDEO_SLOTS else (tex(m["emission_texture"]) if m["emission_texture"] else None)
            texs = {"EmissiveMap": etex} if etex else {}
            if m["albedo_texture"] and slot not in VIDEO_SLOTS:
                texs["ColorMap"] = tex(m["albedo_texture"])
            # Godot: ADD = (emission + map) x energy with a black emission
            # colour whenever there is a map; MULTIPLY = emission x map x energy.
            ecol = m["emission"][:3] if not etex or m["emission_operator"] == "multiply" else (1, 1, 1)
            _set(mi,
                 {"EmissiveStrength": m["emission_energy"] * EMISSIVE_GAIN, "Roughness": m["roughness"],
                  "Specular": m["specular"], "ColorMapAmount": 1.0 if "ColorMap" in texs else 0.0},
                 {"Tint": m["albedo"][:3], "EmissiveColor": ecol,
                  "UVScale": (m["uv1_scale"][0], m["uv1_scale"][1], 0), "UVOffset": (m["uv1_offset"][0], m["uv1_offset"][1], 0)},
                 texs)
        else:
            MEL.set_material_instance_parent(mi, surface)
            texs = {}
            for key, param in (("albedo_texture", "ColorMap"), ("normal_texture", "NormalMap"),
                               ("roughness_texture", "RoughnessMap"), ("ao_texture", "AOMap")):
                if m.get(key):
                    texs[param] = tex(m[key])
            _set(mi,
                 {"Repeats": m["uv1_scale"][0], "Roughness": m["roughness"], "Metallic": m["metallic"],
                  "Specular": m["specular"], "NormalStrength": m["normal_scale"],
                  "ColorMapAmount": 1.0 if "ColorMap" in texs else 0.0,
                  "RoughnessMapAmount": 1.0 if "RoughnessMap" in texs else 0.0,
                  "AOAmount": 1.0 if "AOMap" in texs else 0.0},
                 {"Tint": m["albedo"][:3]}, texs)
        MEL.update_material_instance(mi)
        EAL.save_loaded_asset(mi, only_if_is_dirty=False)
        made[slot] = name
    return made


def place():
    es = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    for a in es.get_all_level_actors():
        if a.get_actor_label().startswith("Aegis_Venue_"):
            es.destroy_actor(a)
    placed = []
    for a in unreal.AssetRegistryHelpers.get_asset_registry().get_assets_by_path(MESH_DIR, recursive=True):
        if str(a.asset_class_path.asset_name) != "StaticMesh":
            continue
        mesh = a.get_asset()
        name = str(a.asset_name)
        mi = unreal.load_asset(MI_DIR + "/MI_" + name)
        if mi:
            for i in range(mesh.get_num_sections(0)):
                mesh.set_material(i, mi)
            EAL.save_loaded_asset(mesh, only_if_is_dirty=False)
        actor = es.spawn_actor_from_object(mesh, RING_CENTRE, unreal.Rotator(0, 0, 0))
        actor.set_actor_label("Aegis_Venue_" + name)
        actor.set_folder_path("Aegis/Venue")
        placed.append(name)
    # The runtime LED materials of meshes the bowl .glb already brought in.
    for mesh_name in ("RibbonBoards", "StairNosing"):
        mesh = unreal.load_asset(BOWL + mesh_name)
        for i in range(mesh.get_num_sections(0)):
            mesh.set_material(i, unreal.load_asset(MI_DIR + "/MI_" + mesh_name))
        EAL.save_loaded_asset(mesh, only_if_is_dirty=False)
    for a in es.get_all_level_actors():
        if a.get_actor_label() in ("Aegis_Arena_RibbonBoards", "Aegis_Arena_StairNosing"):
            c = a.get_component_by_class(unreal.StaticMeshComponent)
            for i in range(c.get_num_materials()):
                c.set_material(i, None)   # drop any per-actor override; the asset's slot wins
    unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).save_current_level()
    return placed


report = {}
if "textures" in STAGES:
    report["textures"] = import_textures()
if "master" in STAGES:
    build_emissive()
    report["master"] = "M_AegisEmissive"
if "meshes" in STAGES:
    report["meshes"] = import_meshes()
if "media" in STAGES:
    report["media"] = build_media()
if "materials" in STAGES:
    report["materials"] = len(build_materials())
if "place" in STAGES:
    report["placed"] = place()
json.dumps(report)
