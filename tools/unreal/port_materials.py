"""Port the Godot build's textures and materials to the Unreal port.

Run inside the UE 5.9 editor of the port project (the editor MCP's
execute_python, or Tools > Execute Python Script). Idempotent: every run
re-imports, rebuilds and reassigns the same things.

Why this exists: the port imported ring.glb, ringside.glb, arena_bowl.glb and
roman_reigns.glb, and none of them carries the textures the Godot game shows.
The environment .glbs hold no images at all -- Godot dresses every surface in
code, through core/materials/material_library.gd (a CC0 scan plus a tint, a
tile size and a roughness per named material). Roman's .glb embeds fourteen
images, but core/match/roman_model.gd replaces most of them with sidecar PNGs
(portrait_color, body_ink, the rebuilt hair masks...), and several of the
embedded ones are wired into the wrong slots (packed hair data as base colour,
a transmission mask on the face).

What it does, in order (set STAGES to run a subset):

  textures   import the PNGs into /Game/AegisTest/Textures/{Env,Roman}, as sRGB
             colour, linear masks, or normal maps (green flipped: every map
             here is OpenGL-convention, Unreal samples DirectX)
  masters    build two master materials in /Game/AegisTest/Materials/Master:
               M_AegisSurface  opaque PBR: colour map x tint, normal with a
                               strength, roughness map x scalar on a chosen
                               channel, AO, metallic, specular; UVs x repeats
               M_AegisCard     masked two-sided card for hair, beard, lashes
  instances  one MaterialInstanceConstant per Godot material, values copied
             from material_library.gd / ring_builder.gd / roman_model.gd
  uvs        box-project 1 UV per metre onto the bowl meshes, which arrived
             with no UVs (Godot shows them as flat colour for the same reason)
  assign     set the instances on the mesh assets' material slots (so every
             actor using a mesh picks them up) and on the canvas actor

Not ported, deliberately: Godot's `house_lit` emission. That is a lighting
device of the Godot hall (it lights surfaces through emission because the hall
had no lights aimed at them); the Unreal level is lit by real lights, so the
maps go into base colour only. Also not ported: the canvas tension normal and
rope-shadow detail layer (both generated at runtime in Godot), the hair's
runtime vertex-colour root shade and anisotropic sheen, and the eye's parallax
and clearcoat.

Optional globals, set before the script body:
    STAGES = ["textures", "masters", "instances", "uvs", "assign"]
    AEGIS = "~/code/aegis"
"""
import json
import os
import struct
import zlib

import unreal

AEGIS = os.path.expanduser(globals().get("AEGIS", "~/code/aegis"))
STAGES = globals().get("STAGES", ["textures", "masters", "instances", "uvs", "assign"])

ENV_SRC = os.path.join(AEGIS, "game/assets/environment/materials")
ROMAN_SRC = os.path.join(AEGIS, "game/assets/characters")
TEX_ENV = "/Game/AegisTest/Textures/Env"
TEX_ROMAN = "/Game/AegisTest/Textures/Roman"
TEX_DEFAULT = "/Game/AegisTest/Textures/Default"
MASTER_DIR = "/Game/AegisTest/Materials/Master"
MI_DIR = "/Game/AegisTest/Materials/Instances"

RING = "/Game/AegisTest/Ring/ring/StaticMeshes/"
RINGSIDE = "/Game/AegisTest/Ringside/ringside/StaticMeshes/"
BOWL = "/Game/AegisTest/Arena/arena_bowl/StaticMeshes/"
ROMAN_MAT = "/Game/AegisTest/Roman/roman_reigns/Materials/"

AT = unreal.AssetToolsHelpers.get_asset_tools()
EAL = unreal.EditorAssetLibrary
MEL = unreal.MaterialEditingLibrary

# ---------------------------------------------------------------------------
# Textures
# ---------------------------------------------------------------------------

# The ambientCG scans the ported materials use. Files are <id>_1K-PNG_<role>.png.
SCANS = ["Fabric030", "Fabric061", "DiamondPlate009", "Leather026", "Plastic011",
         "Carpet012", "Concrete033", "PavingStones150"]
ENV_EXTRA = ["arena_concrete_color", "ring_canvas", "turnbuckle_pad"]
ROMAN_TEX = ["portrait_color", "portrait_rm", "wrinkles_normal", "body_ink", "body_nrm",
             "bottoms_nrm", "l_wrist_nrm", "r_wrist_nrm", "eye_color", "eye_orm",
             "lash_alpha", "hair_alpha", "hair_4_alpha", "beard_detail", "beard_detail_normal"]


def kind_of(name):
    n = name.lower()
    if "normal" in n or n.endswith("_nrm"):
        return "normal"
    if any(k in n for k in ("roughness", "ambientocclusion", "metalness", "_rm", "_orm")):
        return "mask"
    return "color"


def texture_jobs():
    jobs = []
    for f in sorted(os.listdir(ENV_SRC)):
        stem, ext = os.path.splitext(f)
        if ext == ".png" and (stem.split("_1K-PNG_")[0] in SCANS and "_1K-PNG_" in stem or stem in ENV_EXTRA):
            jobs.append((os.path.join(ENV_SRC, f), TEX_ENV, "T_" + stem))
    for t in ROMAN_TEX:
        jobs.append((os.path.join(ROMAN_SRC, "roman_reigns_%s.png" % t), TEX_ROMAN, "T_Roman_" + t))
    return jobs


def _png(path, rgba):
    """A 4x4 solid PNG, for the master materials' default textures."""
    raw = b"".join(b"\x00" + bytes(rgba) * 4 for _ in range(4))
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 4, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def default_jobs():
    d = os.path.join(unreal.Paths.project_saved_dir(), "AegisDefaults")
    os.makedirs(d, exist_ok=True)
    out = []
    for name, rgba in [("T_Default_White", (255, 255, 255, 255)),
                       ("T_Default_Mask", (255, 255, 255, 255)),
                       ("T_Default_Normal", (128, 128, 255, 255))]:
        p = os.path.join(d, name + ".png")
        _png(p, rgba)
        out.append((p, TEX_DEFAULT, name))
    return out


def import_textures():
    jobs = default_jobs() + texture_jobs()
    tasks = []
    for src, dest, name in jobs:
        if not os.path.exists(src):
            raise RuntimeError("missing texture source %s" % src)
        t = unreal.AssetImportTask()
        t.set_editor_property("filename", src)
        t.set_editor_property("destination_path", dest)
        t.set_editor_property("destination_name", name)
        t.set_editor_property("automated", True)
        t.set_editor_property("replace_existing", True)
        t.set_editor_property("save", False)
        tasks.append(t)
    AT.import_asset_tasks(tasks)
    done = 0
    for src, dest, name in jobs:
        tex = unreal.load_asset(dest + "/" + name)
        if not tex:
            raise RuntimeError("import failed: %s" % src)
        kind = "mask" if name == "T_Default_Mask" else ("normal" if name == "T_Default_Normal" else kind_of(name))
        if kind == "normal":
            tex.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_NORMALMAP)
            tex.set_editor_property("srgb", False)
            tex.set_editor_property("flip_green_channel", name != "T_Default_Normal")
        elif kind == "mask":
            tex.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_MASKS)
            tex.set_editor_property("srgb", False)
        else:
            tex.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_DEFAULT)
            tex.set_editor_property("srgb", True)
        EAL.save_loaded_asset(tex, only_if_is_dirty=False)
        done += 1
    return done


def tex(path):
    t = unreal.load_asset(path)
    if not t:
        raise RuntimeError("no texture %s" % path)
    return t


def env(name):
    return tex(TEX_ENV + "/T_" + name)


def roman(name):
    return tex(TEX_ROMAN + "/T_Roman_" + name)


# ---------------------------------------------------------------------------
# Master materials
# ---------------------------------------------------------------------------

def _fresh_material(name):
    path = MASTER_DIR + "/" + name
    if EAL.does_asset_exist(path):
        m = unreal.load_asset(path)
        MEL.delete_all_material_expressions(m)
        return m
    return AT.create_asset(name, MASTER_DIR, unreal.Material, unreal.MaterialFactoryNew())


def _expr(m, cls, x, y, **props):
    e = MEL.create_material_expression(m, cls, x, y)
    for k, v in props.items():
        e.set_editor_property(k, v)
    return e


def _param(m, name, value, x, y, group="Aegis"):
    return _expr(m, unreal.MaterialExpressionScalarParameter, x, y,
                 parameter_name=name, default_value=value, group=group)


def _vparam(m, name, rgba, x, y):
    return _expr(m, unreal.MaterialExpressionVectorParameter, x, y,
                 parameter_name=name, default_value=unreal.LinearColor(*rgba), group="Aegis")


def _tparam(m, name, texture, sampler, x, y, uv=None):
    e = _expr(m, unreal.MaterialExpressionTextureSampleParameter2D, x, y,
              parameter_name=name, texture=texture, sampler_type=sampler, group="Aegis")
    if uv is not None:
        MEL.connect_material_expressions(uv, "", e, "UVs")
    return e


def _op(m, cls, a, b, x, y, a_out="", b_out=""):
    e = _expr(m, cls, x, y)
    MEL.connect_material_expressions(a, a_out, e, "A")
    MEL.connect_material_expressions(b, b_out, e, "B")
    return e


def _lerp(m, a, b, alpha, x, y, a_out="", b_out="", alpha_out=""):
    e = _expr(m, unreal.MaterialExpressionLinearInterpolate, x, y)
    MEL.connect_material_expressions(a, a_out, e, "A")
    MEL.connect_material_expressions(b, b_out, e, "B")
    MEL.connect_material_expressions(alpha, alpha_out, e, "Alpha")
    return e


def _const(m, v, x, y):
    return _expr(m, unreal.MaterialExpressionConstant, x, y, r=v)


def _const3(m, v, x, y):
    return _expr(m, unreal.MaterialExpressionConstant3Vector, x, y, constant=unreal.LinearColor(*v, 1.0))


def _uvs(m):
    """TexCoord(0) x Repeats x UVScale.rg -- Godot's uv1_scale = 1 / tile_metres."""
    tc = _expr(m, unreal.MaterialExpressionTextureCoordinate, -1800, 0)
    rep = _param(m, "Repeats", 1.0, -1800, 120)
    scale = _vparam(m, "UVScale", (1, 1, 0, 0), -1800, 240)
    rg = _expr(m, unreal.MaterialExpressionComponentMask, -1600, 240, r=True, g=True, b=False, a=False)
    MEL.connect_material_expressions(scale, "", rg, "")
    k = _op(m, unreal.MaterialExpressionMultiply, rg, rep, -1450, 200)
    return _op(m, unreal.MaterialExpressionMultiply, tc, k, -1300, 80)


def _normal(m, uv, x, y):
    """Normal map pulled toward flat by NormalStrength (Godot's normal_scale)."""
    n = _tparam(m, "NormalMap", tex(TEX_DEFAULT + "/T_Default_Normal"),
                unreal.MaterialSamplerType.SAMPLERTYPE_NORMAL, x, y, uv)
    s = _param(m, "NormalStrength", 1.0, x, y + 220)
    flat = _const3(m, (0, 0, 1), x + 220, y + 220)
    mix = _lerp(m, flat, n, s, x + 400, y, b_out="RGB")
    return _expr_norm(m, mix, x + 560, y)


def _expr_norm(m, v, x, y):
    e = _expr(m, unreal.MaterialExpressionNormalize, x, y)
    MEL.connect_material_expressions(v, "", e, "")
    return e


def build_surface():
    m = _fresh_material("M_AegisSurface")
    uv = _uvs(m)
    white = tex(TEX_DEFAULT + "/T_Default_White")
    mask = tex(TEX_DEFAULT + "/T_Default_Mask")
    # Base colour: Tint x lerp(1, ColorMap, ColorMapAmount). Amount 0 is
    # Godot's `albedo_map: false` -- the scan's structure without its colour.
    cmap = _tparam(m, "ColorMap", white, unreal.MaterialSamplerType.SAMPLERTYPE_COLOR, -1100, -400, uv)
    camt = _param(m, "ColorMapAmount", 1.0, -1100, -180)
    one = _const(m, 1.0, -900, -260)
    cmix = _lerp(m, one, cmap, camt, -800, -400, b_out="RGB")
    tint = _vparam(m, "Tint", (1, 1, 1, 1), -800, -200)
    base = _op(m, unreal.MaterialExpressionMultiply, cmix, tint, -550, -400)
    MEL.connect_material_property(base, "", unreal.MaterialProperty.MP_BASE_COLOR)
    # Roughness: Roughness x lerp(1, dot(RoughnessMap, RoughnessChannel), amount).
    rmap = _tparam(m, "RoughnessMap", mask, unreal.MaterialSamplerType.SAMPLERTYPE_MASKS, -1100, 0, uv)
    chan = _vparam(m, "RoughnessChannel", (1, 0, 0, 0), -1100, 220)
    chan3 = _expr(m, unreal.MaterialExpressionComponentMask, -900, 220, r=True, g=True, b=True, a=False)
    MEL.connect_material_expressions(chan, "", chan3, "")
    rdot = _op(m, unreal.MaterialExpressionDotProduct, rmap, chan3, -800, 0, a_out="RGB")
    ramt = _param(m, "RoughnessMapAmount", 1.0, -800, 140)
    rmix = _lerp(m, _const(m, 1.0, -700, -60), rdot, ramt, -600, 0)
    rough = _op(m, unreal.MaterialExpressionMultiply, rmix, _param(m, "Roughness", 1.0, -600, 140), -400, 0)
    MEL.connect_material_property(rough, "", unreal.MaterialProperty.MP_ROUGHNESS)
    MEL.connect_material_property(_param(m, "Metallic", 0.0, -400, 160), "", unreal.MaterialProperty.MP_METALLIC)
    MEL.connect_material_property(_param(m, "Specular", 0.5, -400, 260), "", unreal.MaterialProperty.MP_SPECULAR)
    # AO, red channel, as Godot's ao_texture_channel.
    ao = _tparam(m, "AOMap", mask, unreal.MaterialSamplerType.SAMPLERTYPE_MASKS, -1100, 380, uv)
    aoamt = _param(m, "AOAmount", 1.0, -900, 560)
    aomix = _lerp(m, _const(m, 1.0, -800, 500), ao, aoamt, -650, 380, b_out="R")
    MEL.connect_material_property(aomix, "", unreal.MaterialProperty.MP_AMBIENT_OCCLUSION)
    nrm = _normal(m, uv, -1100, 700)
    MEL.connect_material_property(nrm, "", unreal.MaterialProperty.MP_NORMAL)
    m.set_editor_property("used_with_skeletal_mesh", True)
    MEL.recompile_material(m)
    EAL.save_loaded_asset(m, only_if_is_dirty=False)
    return m


def build_card():
    """Hair, beard and lash cards: masked, two-sided, colour from a tint.

    The PNGs are white RGB with the strand mask in alpha (build_roman_hair_
    alpha.py); the beard's detail map carries some colour, so the map still
    multiplies. Godot's per-material alpha_scissor_threshold becomes
    OpacityClip: the mask is shifted so the material's fixed 0.3333 clip
    lands where Godot's threshold did.
    """
    m = _fresh_material("M_AegisCard")
    uv = _expr(m, unreal.MaterialExpressionTextureCoordinate, -1300, 0)
    amap = _tparam(m, "AlphaMap", tex(TEX_DEFAULT + "/T_Default_White"),
                   unreal.MaterialSamplerType.SAMPLERTYPE_COLOR, -1100, -300, uv)
    base = _op(m, unreal.MaterialExpressionMultiply, amap, _vparam(m, "Tint", (0.05, 0.05, 0.05, 1), -1100, -60),
               -700, -300, a_out="RGB")
    MEL.connect_material_property(base, "", unreal.MaterialProperty.MP_BASE_COLOR)
    shift = _op(m, unreal.MaterialExpressionSubtract, _const(m, 0.3333, -1000, 120),
                _param(m, "OpacityClip", 0.3, -1000, 220), -800, 140)
    op = _op(m, unreal.MaterialExpressionAdd, amap, shift, -600, 100, a_out="A")
    MEL.connect_material_property(op, "", unreal.MaterialProperty.MP_OPACITY_MASK)
    MEL.connect_material_property(_param(m, "Roughness", 0.5, -400, 200), "", unreal.MaterialProperty.MP_ROUGHNESS)
    MEL.connect_material_property(_param(m, "Specular", 0.5, -400, 300), "", unreal.MaterialProperty.MP_SPECULAR)
    MEL.connect_material_property(_normal(m, uv, -1100, 500), "", unreal.MaterialProperty.MP_NORMAL)
    m.set_editor_property("blend_mode", unreal.BlendMode.BLEND_MASKED)
    m.set_editor_property("two_sided", True)
    m.set_editor_property("used_with_skeletal_mesh", True)
    MEL.recompile_material(m)
    EAL.save_loaded_asset(m, only_if_is_dirty=False)
    return m


# ---------------------------------------------------------------------------
# Instances: the Godot materials, by name
# ---------------------------------------------------------------------------

def scan(asset, color=True, rough=True):
    """The maps material_library.gd's _build plugs in for an ambientCG asset."""
    out = {"NormalMap": env(asset + "_1K-PNG_NormalGL")}
    if color:
        out["ColorMap"] = env(asset + "_1K-PNG_Color")
    if rough:
        for role in ("RoughnessBand", "Roughness"):   # the rebanded scan wins
            p = TEX_ENV + "/T_%s_1K-PNG_%s" % (asset, role)
            if EAL.does_asset_exist(p):
                out["RoughnessMap"] = tex(p)
                break
    p = TEX_ENV + "/T_%s_1K-PNG_AmbientOcclusion" % asset
    if EAL.does_asset_exist(p):
        out["AOMap"] = tex(p)
    return out


def lib(asset, tint, tile, rough, normal=1.0, metallic=0.0, color=True, rough_map=True, color_path=None):
    """One material_library.gd SPECS entry, as instance parameters."""
    texs = scan(asset, color and not color_path, rough_map) if asset else {}
    if color_path:
        texs["ColorMap"] = env(color_path)
    return {"master": "surface", "tex": texs,
            "vec": {"Tint": tint},
            "scal": {"Repeats": 1.0 / tile, "Roughness": rough, "Metallic": metallic,
                     "NormalStrength": normal,
                     "ColorMapAmount": 1.0 if "ColorMap" in texs else 0.0,
                     "RoughnessMapAmount": 1.0 if "RoughnessMap" in texs else 0.0,
                     "AOAmount": 1.0 if "AOMap" in texs else 0.0}}


def flat(tint, rough, metallic=0.0, specular=0.5):
    return {
        "master": "surface", "tex": {}, "vec": {"Tint": tint},
        "scal": {"Roughness": rough, "Metallic": metallic, "Specular": specular,
                 "ColorMapAmount": 0.0, "RoughnessMapAmount": 0.0, "AOAmount": 0.0}}


SKIN_TINT = (0.80, 0.86, 0.90)
HAIR_COLOR = (0.045, 0.042, 0.043)
BEARD_COLOR = (0.070, 0.051, 0.039)
LASH_COLOR = (0.030, 0.024, 0.021)


def instances():
    """Name -> spec. Values and their reasons are in the Godot files cited."""
    return {
        # --- material_library.gd SPECS ---------------------------------------
        "MI_ring_post": lib(None, (0.075, 0.075, 0.080), 1.0, 0.94),
        "MI_ring_fittings": lib(None, (0.11, 0.11, 0.115), 1.0, 0.94),
        "MI_ring_rope": flat((0.88, 0.88, 0.87), 0.45),
        "MI_ring_turnbuckle_pad": lib("Fabric061", (0.055, 0.055, 0.060), 0.30, 0.9, normal=1.2, color=False),
        "MI_ring_apron_rail": lib("Fabric030", (0.105, 0.105, 0.112), 0.45, 0.95, color=False),
        "MI_ring_steps": lib("DiamondPlate009", (0.64, 0.65, 0.67), 0.35, 0.62, normal=0.65, metallic=1.0, color=False),
        "MI_ring_steps_tread": lib("DiamondPlate009", (0.50, 0.51, 0.52), 0.35, 0.70, normal=0.8, metallic=1.0, color=False),
        "MI_arena_floor": lib("Concrete033", (0.0826, 0.1000, 0.1283), 2.0, 1.0, color_path="arena_concrete_color"),
        "MI_arena_barricade_pad": lib("Leather026", (0.055, 0.055, 0.060), 0.5, 0.85, color=False),
        "MI_arena_desk_chair": lib("Leather026", (0.050, 0.050, 0.054), 0.35, 0.8, color=False),
        "MI_arena_desk_top": lib("Plastic011", (0.520, 0.520, 0.540), 0.8, 0.6),
        "MI_arena_desk_plastic": lib("Plastic011", (0.330, 0.330, 0.345), 0.4, 0.75),
        "MI_arena_bowl": lib("Carpet012", (0.230, 0.305, 0.430), 3.0, 1.0),
        "MI_arena_shell": lib("Concrete033", (0.098, 0.130, 0.185), 4.5, 1.0),
        "MI_arena_seat": flat((0.10, 0.10, 0.105), 0.90),
        "MI_arena_suite_glass": flat((0.030, 0.038, 0.055), 0.18),
        "MI_arena_rink": lib("PavingStones150", (0.1050, 0.1270, 0.1600), 2.4, 1.0),
        "MI_arena_board_cap": flat((0.520, 0.420, 0.110), 0.60),
        # --- ring_builder.gd --------------------------------------------------
        # _canvas_material: the supplied canvas art, 1:1 over the mat, x CANVAS_WHITE.
        "MI_ring_canvas": {"master": "surface", "tex": {"ColorMap": env("ring_canvas")},
                           "vec": {"Tint": (0.66, 0.66, 0.66)},
                           "scal": {"Roughness": 0.84, "ColorMapAmount": 1.0,
                                    "RoughnessMapAmount": 0.0, "AOAmount": 0.0}},
        # _pad_face_material: the printed turnbuckle cover.
        "MI_ring_pad_face": {"master": "surface", "tex": {"ColorMap": env("turnbuckle_pad")},
                             "vec": {"Tint": (1, 1, 1)},
                             "scal": {"Roughness": 0.68, "ColorMapAmount": 1.0,
                                      "RoughnessMapAmount": 0.0, "AOAmount": 0.0}},
        # --- roman_model.gd ---------------------------------------------------
        # Material (body): body_ink albedo, body_nrm, roughness 0.50, SKIN_TINT.
        "MI_roman_body": {"master": "surface",
                          "tex": {"ColorMap": roman("body_ink"), "NormalMap": roman("body_nrm")},
                          "vec": {"Tint": SKIN_TINT},
                          "scal": {"Roughness": 0.50, "ColorMapAmount": 1.0, "RoughnessMapAmount": 0.0,
                                   "AOAmount": 0.0, "NormalStrength": 1.0}},
        # Material.001 (head): portrait_color, wrinkles at FACE_NORMAL_STRENGTH,
        # roughness from portrait_rm's red channel.
        "MI_roman_head": {"master": "surface",
                          "tex": {"ColorMap": roman("portrait_color"), "NormalMap": roman("wrinkles_normal"),
                                  "RoughnessMap": roman("portrait_rm")},
                          "vec": {"Tint": SKIN_TINT},
                          "scal": {"Roughness": 1.0, "ColorMapAmount": 1.0, "RoughnessMapAmount": 1.0,
                                   "AOAmount": 0.0, "NormalStrength": 0.65}},
        # ALBEDO_FIXES: gear with only a normal map, given a flat colour.
        "MI_roman_bottoms": {"master": "surface", "tex": {"NormalMap": roman("bottoms_nrm")},
                             "vec": {"Tint": (0.045, 0.045, 0.052)},
                             "scal": {"Roughness": 0.5, "ColorMapAmount": 0.0, "RoughnessMapAmount": 0.0, "AOAmount": 0.0}},
        "MI_roman_l_wrist": {"master": "surface", "tex": {"NormalMap": roman("l_wrist_nrm")},
                             "vec": {"Tint": (0.82, 0.80, 0.76)},
                             "scal": {"Roughness": 0.5, "ColorMapAmount": 0.0, "RoughnessMapAmount": 0.0, "AOAmount": 0.0}},
        "MI_roman_r_wrist": {"master": "surface", "tex": {"NormalMap": roman("r_wrist_nrm")},
                             "vec": {"Tint": (0.82, 0.80, 0.76)},
                             "scal": {"Roughness": 0.5, "ColorMapAmount": 0.0, "RoughnessMapAmount": 0.0, "AOAmount": 0.0}},
        # EyeKit.eye_material: eye_color; ORM with AO in R, roughness in G.
        "MI_roman_eye": {"master": "surface",
                         "tex": {"ColorMap": roman("eye_color"), "RoughnessMap": roman("eye_orm"), "AOMap": roman("eye_orm")},
                         "vec": {"Tint": (1, 1, 1), "RoughnessChannel": (0, 1, 0)},
                         "scal": {"Roughness": 1.0, "Specular": 0.30, "ColorMapAmount": 1.0,
                                  "RoughnessMapAmount": 1.0, "AOAmount": 1.0}},
        # The mouth parts shipped with no material at all (WorldGridMaterial).
        "MI_roman_mouth": flat((0.16, 0.05, 0.05), 0.6),
        "MI_roman_teeth": flat((0.72, 0.69, 0.62), 0.4),
        "MI_roman_tongue": flat((0.42, 0.16, 0.16), 0.5),
        # HAIR_FIXES and the scissor thresholds.
        "MI_roman_hair": {"master": "card", "tex": {"AlphaMap": roman("hair_alpha")},
                          "vec": {"Tint": HAIR_COLOR},
                          "scal": {"Roughness": 0.38, "Specular": 0.26, "OpacityClip": 0.14, "NormalStrength": 0.0}},
        "MI_roman_hair_4": {"master": "card", "tex": {"AlphaMap": roman("hair_4_alpha")},
                            "vec": {"Tint": HAIR_COLOR},
                            "scal": {"Roughness": 0.38, "Specular": 0.26, "OpacityClip": 0.14, "NormalStrength": 0.0}},
        "MI_roman_beard": {"master": "card",
                           "tex": {"AlphaMap": roman("beard_detail"), "NormalMap": roman("beard_detail_normal")},
                           "vec": {"Tint": BEARD_COLOR},
                           "scal": {"Roughness": 0.68, "Specular": 0.25, "OpacityClip": 0.16, "NormalStrength": 0.4}},
        "MI_roman_lash": {"master": "card", "tex": {"AlphaMap": roman("lash_alpha")},
                          "vec": {"Tint": LASH_COLOR},
                          "scal": {"Roughness": 0.85, "Specular": 0.1, "OpacityClip": 0.3, "NormalStrength": 0.0}},
    }


def build_instances():
    masters = {"surface": unreal.load_asset(MASTER_DIR + "/M_AegisSurface"),
               "card": unreal.load_asset(MASTER_DIR + "/M_AegisCard")}
    made = []
    for name, spec in instances().items():
        path = MI_DIR + "/" + name
        mi = unreal.load_asset(path) if EAL.does_asset_exist(path) else \
            AT.create_asset(name, MI_DIR, unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
        MEL.clear_all_material_instance_parameters(mi)
        MEL.set_material_instance_parent(mi, masters[spec["master"]])
        for k, v in spec.get("scal", {}).items():
            MEL.set_material_instance_scalar_parameter_value(mi, k, float(v))
        for k, v in spec.get("vec", {}).items():
            MEL.set_material_instance_vector_parameter_value(mi, k, unreal.LinearColor(v[0], v[1], v[2], 1.0))
        for k, v in spec.get("tex", {}).items():
            MEL.set_material_instance_texture_parameter_value(mi, k, v)
        MEL.update_material_instance(mi)
        EAL.save_loaded_asset(mi, only_if_is_dirty=False)
        made.append(name)
    return made


def mi(name):
    return unreal.load_asset(MI_DIR + "/" + name)


# ---------------------------------------------------------------------------
# UVs and assignment
# ---------------------------------------------------------------------------

# Meshes from arena_bowl.glb arrive with no UVs; box-project one per metre.
NO_UV_MESHES = [BOWL + n for n in ("BowlSteps", "Shell", "SuiteFascia", "RinkDeck")]


def uv_per_metre(mesh):
    md = mesh.get_static_mesh_description(0)
    tris = md.get_triangle_count()
    wa = ua = 0.0
    for t in range(0, tris, max(1, tris // 400)):
        vis = md.get_triangle_vertex_instances(unreal.TriangleID(t))
        P = [md.get_vertex_position(md.get_vertex_instance_vertex(v)) for v in vis]
        U = [md.get_vertex_instance_uv(v, 0) for v in vis]
        wa += (P[1] - P[0]).cross(P[2] - P[0]).length() / 2 / 10000.0
        ua += abs((U[1].x - U[0].x) * (U[2].y - U[0].y) - (U[2].x - U[0].x) * (U[1].y - U[0].y)) / 2
    return round((ua / wa) ** 0.5, 3) if wa else 0.0


def box_uvs():
    sub = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    out = {}
    for p in NO_UV_MESHES:
        mesh = unreal.load_asset(p)
        if uv_per_metre(mesh) < 0.5:
            sub.generate_box_uv_channel(mesh, 0, 0, unreal.Vector(0, 0, 0), unreal.Rotator(0, 0, 0),
                                        unreal.Vector(100, 100, 100))
            EAL.save_loaded_asset(mesh, only_if_is_dirty=False)
        out[p.split("/")[-1]] = uv_per_metre(mesh)
    return out


# Mesh asset -> instance. Godot's mapping: ring_builder.gd _model_materials,
# arena_builder.gd's RINGSIDE and BOWL_MODEL_MATERIALS tables.
MESH_MATERIALS = {
    RING + "PostMesh": "MI_ring_post",
    RING + "TurnbuckleFittings": "MI_ring_fittings",
    RING + "TurnbucklePads": "MI_ring_turnbuckle_pad",
    RING + "TurnbuckleFaces": "MI_ring_pad_face",
    RING + "RopeMesh": "MI_ring_rope",
    RING + "ApronRail": "MI_ring_apron_rail",
    RING + "StepsMesh": "MI_ring_steps",
    RING + "StepTreads": "MI_ring_steps_tread",
    RINGSIDE + "Floor": "MI_arena_floor",
    RINGSIDE + "FloorSeams": "MI_arena_floor",
    RINGSIDE + "CommentaryRiser": "MI_arena_floor",
    RINGSIDE + "Barricades": "MI_arena_barricade_pad",
    RINGSIDE + "CommentaryDesk": "MI_arena_barricade_pad",
    RINGSIDE + "CommentaryDeskTop": "MI_arena_desk_top",
    RINGSIDE + "CommentaryKit": "MI_arena_desk_plastic",
    RINGSIDE + "CommentaryChairs": "MI_arena_desk_chair",
    BOWL + "BowlSteps": "MI_arena_bowl",
    BOWL + "BowlSeats": "MI_arena_seat",
    BOWL + "SuiteFascia": "MI_arena_shell",
    BOWL + "SuiteGlass": "MI_arena_suite_glass",
    BOWL + "Shell": "MI_arena_shell",
    BOWL + "RinkDeck": "MI_arena_rink",
    BOWL + "RinkCap": "MI_arena_board_cap",
}

# Roman's material slots, by the imported material's name.
ROMAN_SLOTS = {
    "Material": "MI_roman_body",
    "Material_001": "MI_roman_head",
    "Material_004": "MI_roman_bottoms",
    "Material_006": "MI_roman_l_wrist",
    "Material_007": "MI_roman_r_wrist",
    "Material_013": "MI_roman_eye",
    "Material_016": "MI_roman_lash",
    "Material_018": "MI_roman_hair",
    "Material_019": "MI_roman_hair_4",
    "beard": "MI_roman_beard",
}
# The untextured mouth parts, by skeletal mesh name prefix.
ROMAN_MESH_SLOTS = {"M_MouthBag_": "MI_roman_mouth", "M_Teeth_": "MI_roman_teeth", "M_Tongue_": "MI_roman_tongue"}


def assign():
    out = {"static": 0, "roman_slots": 0, "canvas": False}
    for path, name in MESH_MATERIALS.items():
        mesh = unreal.load_asset(path)
        if not mesh:
            raise RuntimeError("no mesh %s" % path)
        for i in range(mesh.get_num_sections(0)):
            mesh.set_material(i, mi(name))
        EAL.save_loaded_asset(mesh, only_if_is_dirty=False)
        out["static"] += 1
    ar = unreal.AssetRegistryHelpers.get_asset_registry()
    for a in ar.get_assets_by_path("/Game/AegisTest/Roman", recursive=True):
        if str(a.asset_class_path.asset_name) != "SkeletalMesh":
            continue
        sk = a.get_asset()
        # Elements of the array are temporaries: copy each slot out, edit it,
        # and put it back, or the change is silently dropped.
        mats = list(sk.get_editor_property("materials"))
        changed = False
        for i, slot in enumerate(mats):
            sm = slot.copy()
            cur = slot.get_editor_property("material_interface")
            key = cur.get_name() if cur else None
            new = ROMAN_SLOTS.get(key)
            for prefix, name in ROMAN_MESH_SLOTS.items():
                if str(a.asset_name).startswith(prefix):
                    new = name
            sm.set_editor_property("material_interface", mi(new) if new else cur)
            if new and cur != mi(new):
                changed = True
            mats[i] = sm
        if changed:
            sk.set_editor_property("materials", mats)
            EAL.save_loaded_asset(sk, only_if_is_dirty=False)
            out["roman_slots"] += 1
    # The canvas is an engine cube; its top face carries a 0..1 UV, which is
    # the 1:1 mapping the canvas art is drawn for.
    es = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    for actor in es.get_all_level_actors():
        if actor.get_actor_label() == "Aegis_Canvas":
            actor.get_component_by_class(unreal.StaticMeshComponent).set_material(0, mi("MI_ring_canvas"))
            out["canvas"] = True
    return out


report = {}
if "textures" in STAGES:
    report["textures"] = import_textures()
if "masters" in STAGES:
    build_surface()
    build_card()
    report["masters"] = ["M_AegisSurface", "M_AegisCard"]
if "instances" in STAGES:
    report["instances"] = len(build_instances())
if "uvs" in STAGES:
    report["uvs"] = box_uvs()
if "assign" in STAGES:
    report["assign"] = assign()
json.dumps(report)
