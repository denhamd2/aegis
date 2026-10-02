"""Kenny Omega, rebuilt to the owner's character sheet
(gauntlet/refs/characters/kenny_omega_sheet.png).

Run with the bpy module (no Blender application required):

    python3 tools/blender/kenny_aaa.py

What it replaces, and why
-------------------------
`kenny_omega.glb` is a photogrammetry scan of a 17.6 cm action figure -- in a
waistcoat and jeans, with a sculpted plastic head, the scanning room's light
baked into one 4K texture and a pointing hand frozen into the mesh
(core/match/kenny_model.gd). The sheet is a different man to look at:
shirtless, in white tights with a gold-and-black filigree, black-and-gold
kneepads and knee boots, white wrist tape, shoulder-length curly blond hair
and stubble.

The path is Aubrey's (tools/blender/aubrey_aaa.py, character_aaa_plan.md
section 3), which is proven in the game:

* KEEP THE SKELETON. The scan was rigged on the base rig's 65 bones
  (tools/assets/rig_static_wrestler.py); every clip, paired move, grip and
  collision test reads those bones. This script imports `kenny_omega.glb`,
  throws its mesh away and keeps its armature byte for byte -- its rest pose is
  near a T with a wide stance, which is what the new body is fitted to.
* A NEW BODY: MPFB's human (CC0), male, ~40, a heavyweight wrestler's build,
  fitted to that skeleton -- MPFB's game-engine rig is pinned joint for joint
  onto his and aimed bone for bone, the deformation applied, and MPFB's
  weights carried over onto his bone names (they are the same UE-style names
  bar `Head`).

This is stage 1 (the body). Later stages add the gear, the likeness and hair,
the skin and the in-game wiring; see README's work log.
"""

from __future__ import annotations

import importlib
import math
import pathlib
import sys

import bpy  # noqa: E402  (first: it provides bmesh and mathutils)
import addon_utils
import bmesh
from mathutils import Vector

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import bpy_exit  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "game/assets/characters/kenny_omega.glb"
OUT = ROOT / "game/assets/characters/kenny_aaa.glb"
MPFB = "bl_ext.user_default.mpfb"
BODY_NAME = "Kenny_Body"
## The base rig, whose mannequin is skinned to these exact 65 bones by the
## rig's author.
BASE_RIG = ROOT / "game/assets/characters/wrestler_base.glb"
## Weight smoothing after the transfer (rig_static_wrestler.py's numbers).
WEIGHT_SMOOTH_PASSES = 6
WEIGHT_SMOOTH_FACTOR = 0.5

## His height is left to MPFB (crown 1.733 m, hair excluded): his legs are
## pinned to the skeleton's joints, and raising MPFB's height macro grew him
## soft and wide and opened creases at the elbows and knees. The game scales
## every wrestler to his billed height off his model's crown
## (roster.gd, model_height_m), so it is the crown that is recorded there.
## His build (the sheet's turnaround): a heavyweight in his early forties --
## broad shoulders and lats, big arms and chest, a lean waist with the abs
## showing, thick thighs. MPFB macros first, then targets for what they do not
## reach.
MACROS = {
    "gender": 1.0, "age": 0.6, "muscle": 1.0, "weight": 0.62,
    "proportions": 0.75, "african": 0.0, "asian": 0.0, "caucasian": 1.0,
}
## Measured (tools: girth bands at chest, waist, hips, thigh and upper arm,
## rest pose): the macros alone gave a 0.31 x 0.20 m chest and a 0.10 m upper
## arm -- an ordinary fit man, smaller than the scan he replaces (0.37 m deep
## at the chest) and than Cody (0.20 m arm). Targets build him out toward the
## sheet's, inside what the scan already occupied, so the paired moves keep
## the clearances they were tuned on.
BODY = {
    "torso-vshape-incr": 0.6,
    "torso-scale-depth-incr": 0.2,
    "torso-scale-horiz-incr": 0.35,
    "torso-muscle-dorsi-incr": 1.0,
    "torso-muscle-pectoral-incr": 0.5,
    "measure-shoulder-dist-incr": 0.2,
    "measure-waist-circ-decr": 0.15,
    "stomach-tone-incr": 0.8,
    "upperarm-muscle-incr": 1.0,
    "upperarm-shoulder-muscle-incr": 0.9,
    "upperarm-scale-horiz-incr": 0.5,
    "upperarm-scale-depth-incr": 0.5,
    "lowerarm-muscle-incr": 0.6,
    "upperleg-muscle-incr": 0.6,
    "upperleg-scale-horiz-incr": 0.3,
    "lowerleg-muscle-incr": 0.4,
    "neck-scale-horiz-incr": 0.4,
    "neck-scale-depth-incr": 0.3,
}
## His likeness as MPFB face targets, set against the sheet's head references
## (front, 3/4, the hair side view) on clay renders: a broad square jaw and
## chin, a strong brow ridge with the brows set low over deep, narrowed
## eyes with heavy lids and bags, high cheekbones, a broad nose with a full
## rounded tip, a thin upper lip, a high forehead. Polished in game: the
## first pass read narrow and long, so the head is wider and shorter.
FACE = {
    # head and forehead
    "head-square": 0.5, "head-scale-horiz-incr": 0.5, "head-scale-vert-decr": 0.25, "head-age-incr": 0.3,
    "head-fat-incr": 0.35,
    "forehead-scale-vert-incr": 0.15, "forehead-nubian-incr": 0.3,
    # brows and eyes
    "eyebrows-trans-forward": 0.6, "eyebrows-trans-down": 0.3, "eyebrows-angle-down": 0.3,
    "eye-scale-decr": 0.35, "eye-height2-decr": 0.4, "eye-bag-incr": 0.4,
    "eye-push1-in": 0.3, "eye-eyefold-down": 0.4, "eye-corner2-down": 0.2,
    # nose
    "nose-scale-horiz-incr": 0.35, "nose-point-width-incr": 0.5, "nose-volume-incr": 0.4,
    "nose-width2-incr": 0.3, "nose-scale-vert-incr": 0.15,
    # mouth
    "mouth-upperlip-volume-decr": 0.4, "mouth-scale-horiz-incr": 0.3,
    "mouth-lowerlip-volume-incr": 0.2,
    # jaw, chin and cheeks
    "chin-width-incr": 0.8, "chin-bones-incr": 0.7, "chin-prominent-incr": 0.3,
    "cheek-bones-incr": 0.6,
}
## MPFB bone -> his bone, where the names differ.
BONE_NAMES = {"head": "Head"}
## Bones that take his bone's direction but keep their own position.
## Measured, MPFB's joint against his, before fitting: the base rig's spine
## is a different anatomy from MPFB's -- spine_03 at 1.315 m against MPFB's
## 1.152 (16 cm), spine_02 8 cm, the clavicles starting 5-6 cm higher and
## further forward. Pinned, those joints dragged his whole upper chest up into
## a fold that read as a hump round his neck once the arms came down. The
## torso keeps MPFB's shape; his weights come from the base rig's mannequin
## (transfer_weights), which is skinned to these bones where they are. The
## head rides MPFB's own neck, as Aubrey's does. The limbs stay pinned: an
## arm must turn about his shoulder joint, not 8 cm in front of it.
FREE_JOINTS = {"head", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"}

# --- Gear (stage 2) ----------------------------------------------------------
## His ring gear (the sheet's turnaround, pants and boot references): white
## tights with a gold-and-black filigree, a black-and-gold waistband with
## white tabs, black-and-gold kneepads, knee boots in black leather with a gold
## front panel and two gold stripes up the back (white piping on both), and
## white wrist tape. One shell, grown off his own skin -- the body's faces
## from the waistband down and at the wrists, pushed out along the normal by
## how thick each piece is -- painted in the body's own UV space from 3D
## position, as Aubrey's make-up is (position_map).
GEAR = "Kenny_Gear"
GEAR_OUT = ROOT / "game/assets/characters/kenny_aaa_gear.png"
GEAR_ORM_OUT = ROOT / "game/assets/characters/kenny_aaa_gear_orm.png"
GEAR_SIZE = 4096
GEAR_SEED = 2299
## Heights (m, his rest pose): the waistband's top and depth.
WAIST_TOP = 1.035
BAND_DEPTH = 0.05
## Along each leg (m from the hip joint, down the thigh, calf and foot): the
## kneepad's span about the knee, and where the boot takes over under it.
PAD_ABOVE = 0.085
PAD_BELOW = 0.075
## Standoffs (m): the tights hug; the band, tape and boots stand off a little;
## the pad bulges over the kneecap.
OFF_TIGHTS = 0.003
OFF_BAND = 0.006
OFF_BOOT = 0.007
OFF_PAD = (0.010, 0.012)    # base, and extra at the kneecap
OFF_TAPE = 0.004
## Wrist tape: this far up the forearm from the wrist joint.
TAPE_LEN = 0.075
## The boot's foot: smoothed over the toes (a boot has none), and its sole
## flat this high off the floor.
## The grown shell ends this high (m); the modelled boot foot takes over.
BOOT_CUT = 0.20
## The boot foot (m, in the foot's frame from the ankle joint): rings from
## the cut down and forward to the toe, each (forward, up, half width,
## height); the lower half of each ring flattens to the sole. Profiled off the
## sheet's boot side view: a straight shaft down to the instep, a long low
## vamp to a rounded toe, a heel standing a little behind the shaft.
BOOT_RINGS = [
    (-0.010, 0.240, 0.050, 0.000),
    (-0.012, 0.190, 0.049, 0.000),
    (-0.022, 0.090, 0.048, 0.000),
    (-0.020, 0.000, 0.048, 0.110),
    (0.040, 0.000, 0.050, 0.095),
    (0.100, 0.000, 0.051, 0.075),
    (0.150, 0.000, 0.049, 0.058),
    (0.185, 0.000, 0.044, 0.047),
    (0.208, 0.000, 0.034, 0.038),
    (0.220, 0.000, 0.018, 0.028),
]
BOOT_SIDES = 24
SOLE_THICK = 0.018
SOLE_Z = 0.004
## Colours (sRGB, 0-255): the sheet's white satin, gold, black.
WHITE = (228, 224, 214)
GOLD = (200, 172, 112)
GOLD_DEEP = (152, 120, 66)
BLACK = (24, 23, 25)
LEATHER = (30, 29, 31)
PIPING = (236, 233, 224)
TAPE = (238, 236, 229)

# --- Head (stage 3) ----------------------------------------------------------
MPFB_ASSETS = pathlib.Path.home() / ".cache/aegis_assets/mpfb"
## His eyes: spheres at MPFB's eye helpers, front-projected with
## tools/assets/build_eyes.py's KENNY spec (blue-grey, 30 mm per UV unit).
EYE_RADIUS = 0.0122
EYE_SEGMENTS = (32, 16)
EYE_MM_PER_UV = 30.0
EYE_COLOR = ROOT / "game/assets/characters/kenny_eye_color.png"
## Brow and lash cards: MakeHuman's own (CC0), fitted to his face by MPFB --
## heavy straight brows, a darker dirty blond than his hair; plain lashes.
BROWS = "eyebrow001"
LASHES = "eyelashes01"
CARD_TEXTURES = {
    BROWS: (ROOT / "game/assets/characters/kenny_aaa_brows.png", (104, 78, 50), 1.6),
    LASHES: (ROOT / "game/assets/characters/kenny_aaa_lashes.png", (60, 44, 32), 1.0),
}
## His skin: a CC0 MakeHuman skin with stubble -- jartur69's middle-aged
## Slavic male with beard -- graded from its pale beige toward the sheet's
## sun-warmed, ruddy tan.
SKIN_SOURCE = (MPFB_ASSETS / "unpacked_skins02/skins/jartur69_middleage_slavic_male_with_genitals_and_beard"
               / "Jartur_mid_old_Slavic_Male_with_Genitals_and_Beard_lsdif_lighter.png")
SKIN_OUT = ROOT / "game/assets/characters/kenny_aaa_skin.jpg"
SKIN_GRADE = (0.94, 0.64, 0.50)
SKIN_QUALITY = 92
## His beard (the sheet's head references): a short, full, ginger-brown
## beard and moustache, painted from 3D position relative to his eyes (m):
## down to the top of the neck, back to just in front of the ears.
BEARD = dict(color=(104, 66, 36), strength=0.85, neck=-0.155, behind=0.045, seed=1974)

# --- Hair (stage 3) ----------------------------------------------------------
## His hair (the sheet's head and hair references): shoulder length, a mass of
## tight curls, dirty blond with darker brown roots and lighter ends, pushed
## back off a high forehead, falling over his ears and onto his shoulders and
## upper back. Two parts: a CAP grown off his scalp with volume, and CURL
## clumps hanging from under it -- each two crossed strand cards round a tight
## helix (roman_ringlets.py's construction), draped down over his head, neck
## and shoulders by pushing each sample out of the body.
HAIR_CAP = "Kenny_HairCap"
HAIR_CURLS = "Kenny_Curls"
HAIR_TEX = ROOT / "game/assets/characters/kenny_aaa_hair.png"
CAP_TEX = ROOT / "game/assets/characters/kenny_aaa_hair_cap.png"
## The hairline: height above the eyes (m) by the angle round the head from
## straight ahead -- a high forehead receding at the temples, over the ears,
## down the back to the nape.
HAIRLINE = [(0.0, 0.088), (25.0, 0.084), (42.0, 0.070), (60.0, 0.052),
            (80.0, 0.036), (100.0, 0.000), (130.0, -0.060), (180.0, -0.085)]
HAIRLINE_FEATHER = 0.018
## The cap's standoff: its root, and the volume it gains back from the
## hairline over the crown and the back (curly hair stands off the skull).
CAP_OFF = (0.004, 0.028)
CAP_RAMP = 0.035
## The cap's strand direction: combed back from a pole over the forehead.
CAP_AXIS = Vector((0.0, -0.75, 0.66)).normalized()
CAP_E1 = Vector((0.0, 0.66, 0.75)).normalized()
CAP_E2 = CAP_AXIS.cross(CAP_E1)
CAP_U_TILES = 5
## (Polished in game: they hung close to his face, where the sheet's mass
## stands well out from it, so wider cards, more standoff, more flare and an
## upper layer reaching round to the sides.)
## Curls: how many; where they start (angle round the head, from in front of
## the ears round the back); start height under the cap (m above the eyes) by
## angle; their ends (m, world height); their standoff off whatever they fall
## over; and their coil.
CURL_COUNT = 120
## A second layer over the crown and the back, starting higher up the cap,
## so the curls cover it from behind as the sheet's back view shows.
CURL_UPPER = (80, (95.0, 180.0), 0.05)
CURL_ANGLES = (72.0, 180.0)
CURL_TOP = [(62.0, 0.035), (90.0, 0.025), (120.0, 0.010), (180.0, -0.010)]
CURL_END = (1.36, 1.50)
CURL_STANDOFF = (0.022, 0.055)
CURL_RADIUS = (0.005, 0.011)
CURL_PITCH = (0.034, 0.060)
CURL_WIDTH = ((0.028, 0.044), 0.011)
CURL_STEP = 0.006
## How far each curl drifts out from the head per metre of fall: the
## sheet's hair flares out over the shoulders rather than hanging plumb.
CURL_FLARE = 0.42
CURL_SEED = 1012
CURL_COLUMNS = 4
CURL_TEX = (512, 2048)
CURL_STRANDS = 70
## Colours (sRGB): roots, lengths, the light ends.
HAIR_ROOT = (72, 52, 34)
HAIR_MID = (150, 114, 70)
HAIR_TIP = (214, 182, 124)
## The curls follow his head down to HAIR_BODY_Z[0], then hand over to his
## upper chest (spine_03) by HAIR_BODY_Z[1], up to HAIR_BODY_SHARE of it.
HAIR_BODY_Z = (1.58, 1.44)
HAIR_BODY_SHARE = 0.7


def mpfb(module: str, name: str):
    return getattr(importlib.import_module(f"{MPFB}.{module}"), name)


def image_material(name: str, path: pathlib.Path, roughness: float, alpha: bool = False):
    """A Principled material on one image (its alpha too, if asked)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(path))
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if alpha:
        mat.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        mat.blend_method = "BLEND"
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def rigid_on_head(obj, old_arm) -> None:
    """Parent obj to her skeleton, every vertex on the Head bone."""
    from mathutils import Matrix
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.data.transform(world)
    obj.matrix_world = Matrix.Identity(4)
    obj.vertex_groups.clear()
    group = obj.vertex_groups.new(name="Head")
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    obj.parent = old_arm
    obj.matrix_parent_inverse = old_arm.matrix_world.inverted()
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = old_arm


def make_eyes(old_arm, eyes):
    """Both eyeballs in one mesh (Kenny_Eyes), front-projected UVs centred on
    each line of sight, rigid on his Head bone. The spheres are written out
    vertex by vertex: as two objects the glTF exporter shared (or not) one
    index buffer between them run to run, joined they came out in selection
    order, and bmesh's create_uvsphere orders its faces differently each run
    -- any of which kept the file from being byte-identical."""
    import math
    seg_u, seg_v = EYE_SEGMENTS
    verts, faces, uvs = [], [], []
    for side in ("l", "r"):
        centre, forward = eyes[side]
        rot = Vector((0.0, 0.0, 1.0)).rotation_difference(forward).to_matrix()
        right = Vector((1.0, 0.0, 0.0))
        up = forward.cross(right).normalized()
        right = up.cross(forward).normalized()
        base = len(verts)
        # Poles at the local z ends, seg_v - 1 rings between them.
        local = [Vector((0.0, 0.0, EYE_RADIUS))]
        for ring in range(1, seg_v):
            th = math.pi * ring / seg_v
            for k in range(seg_u):
                ph = 2.0 * math.pi * k / seg_u
                local.append(Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph),
                                     math.cos(th))) * EYE_RADIUS)
        local.append(Vector((0.0, 0.0, -EYE_RADIUS)))
        verts += [centre + rot @ v for v in local]
        ring_at = lambda ring, k: base + 1 + (ring - 1) * seg_u + k % seg_u
        bottom = base + len(local) - 1
        for k in range(seg_u):
            faces.append((base, ring_at(1, k), ring_at(1, k + 1)))
            for ring in range(1, seg_v - 1):
                faces.append((ring_at(ring, k), ring_at(ring + 1, k),
                              ring_at(ring + 1, k + 1), ring_at(ring, k + 1)))
            faces.append((ring_at(seg_v - 1, k), bottom, ring_at(seg_v - 1, k + 1)))
        for i in range(base, len(verts)):
            p = verts[i] - centre
            uvs.append((0.5 + p.dot(right) * 1000.0 / EYE_MM_PER_UV,
                        0.5 - p.dot(up) * 1000.0 / EYE_MM_PER_UV))
    mesh = bpy.data.meshes.new("Kenny_Eyes")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        layer.data[loop.index].uv = uvs[loop.vertex_index]
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.materials.append(image_material("MI_KennyEyes", EYE_COLOR, roughness=0.05))
    mesh.update()
    eye = bpy.data.objects.new("Kenny_Eyes", mesh)
    bpy.context.scene.collection.objects.link(eye)
    group = eye.vertex_groups.new(name="Head")
    group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
    eye.parent = old_arm
    eye.matrix_parent_inverse = old_arm.matrix_world.inverted()
    mod = eye.modifiers.new("Armature", "ARMATURE")
    mod.object = old_arm
    return [eye]


def make_cards(human):
    """MakeHuman's brow and lash cards fitted to his face (MPFB fits them to
    the basemesh as it stands, so after the targets and the fitting pose),
    their strand textures recoloured; returns the two objects."""
    import numpy as np
    from PIL import Image
    HumanService = mpfb("services.humanservice", "HumanService")
    cards = []
    for kind, name, obj_name in (("eyebrows", BROWS, "Kenny_Brows"),
                                 ("eyelashes", LASHES, "Kenny_Lashes")):
        source = MPFB_ASSETS / "unpacked_makehuman_system_assets" / kind / name
        obj = HumanService.add_mhclo_asset(str(source / f"{name}.mhclo"), human,
                                           asset_type=kind.capitalize(), subdiv_levels=0,
                                           set_up_rigging=False)
        for mod in list(obj.modifiers):
            obj.modifiers.remove(mod)
        if obj.data.shape_keys:
            obj.shape_key_clear()
        obj.name = obj.data.name = obj_name
        out, rgb, gain = CARD_TEXTURES[name]
        strands = np.asarray(Image.open(source / f"{name}.png").convert("RGBA"), np.float32)
        card = np.zeros_like(strands)
        card[..., :3] = rgb
        card[..., 3] = np.clip(strands[..., 3] * gain, 0.0, 255.0)
        Image.fromarray(np.round(card).astype(np.uint8), "RGBA").save(out, optimize=True)
        obj.data.materials.clear()
        mat_name = "M_KennyBrows" if kind == "eyebrows" else "M_KennyLashes"
        obj.data.materials.append(image_material(mat_name, out, roughness=0.6, alpha=True))
        for poly in obj.data.polygons:
            poly.use_smooth = True
        cards.append(obj)
    # MPFB adds a delete group per card to the basemesh; it masks nothing here.
    for vg in list(human.vertex_groups):
        if vg.name.startswith("Delete."):
            human.vertex_groups.remove(vg)
    return cards


def _smooth(a, b, x):
    import numpy as np
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def position_map(body, size: int, z_min: float, group: str | None = "lips"):
    """A mesh rasterised into UV space (faces wholly above z_min): for every
    texel, the point on it that texel covers (world, metres), its weight in
    `group`, and whether it is covered."""
    import numpy as np
    mesh = body.data
    pos = np.zeros((size, size, 3), np.float32)
    lips = np.zeros((size, size), np.float32)
    hit = np.zeros((size, size), bool)
    uvs = mesh.uv_layers["UVMap"].data
    co = np.array([body.matrix_world @ v.co for v in mesh.vertices], np.float32)
    lip_w = np.zeros(len(co), np.float32)
    if group is not None:
        lip_group = body.vertex_groups[group].index
        for v in mesh.vertices:
            for g in v.groups:
                if g.group == lip_group:
                    lip_w[v.index] = g.weight
    mesh.calc_loop_triangles()
    for tri in mesh.loop_triangles:
        vi = list(tri.vertices)
        if co[vi, 2].min() < z_min:
            continue
        uv = np.array([uvs[i].uv for i in tri.loops], np.float32)
        px = np.stack([uv[:, 0] * size - 0.5, (1.0 - uv[:, 1]) * size - 0.5], 1)
        x0, y0 = np.maximum(np.floor(px.min(0)).astype(int), 0)
        x1, y1 = np.minimum(np.ceil(px.max(0)).astype(int), size - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = px
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        w0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
        w1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not inside.any():
            continue
        weights = np.stack([w0, w1, w2], -1)[inside]
        yy, xx = ys[inside], xs[inside]
        pos[yy, xx] = weights @ co[vi]
        lips[yy, xx] = weights @ lip_w[vi]
        hit[yy, xx] = True
    return pos, lips, hit


def paint_skin(body, eyes) -> None:
    """His skin texture: the graded CC0 skin with his beard painted on
    (BEARD), in UV space from 3D position, written to SKIN_OUT and put on the
    body."""
    import numpy as np
    from PIL import Image, ImageFilter
    base = np.asarray(Image.open(SKIN_SOURCE).convert("RGB"), np.float32) * np.array(SKIN_GRADE, np.float32)
    size = base.shape[0]
    e = (eyes["l"][0] + eyes["r"][0]) / 2.0
    pos, lips, hit = position_map(body, size, e.z - 0.25)
    d = pos - np.array(tuple(e), np.float32)
    x, y, z = np.abs(d[..., 0]), d[..., 1], d[..., 2]
    # The beard: from the sideburns in front of the ears down the jaw, round
    # the chin and over the upper lip; not the lips, the nose or the cheeks
    # above the line from the sideburn to the mouth's corner; under the jaw
    # to the top of the neck.
    cheek_line = np.clip(-0.072 + (x - 0.028) * 1.6, -0.072, -0.004)
    beard = (_smooth(cheek_line + 0.012, cheek_line - 0.006, z)
             * (1.0 - _smooth(BEARD["neck"] + 0.02, BEARD["neck"], z))
             * (1.0 - _smooth(BEARD["behind"] - 0.012, BEARD["behind"], y))
             * hit)
    nose = (x < 0.026) & (z > -0.058) & (y < -0.05)
    beard *= ~nose
    beard *= 1.0 - _smooth(0.55, 0.85, lips)
    grain = np.asarray(Image.fromarray((np.random.default_rng(BEARD["seed"]).random((size, size)) * 255)
                                       .astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)), np.float32) / 255.0
    k = (np.clip(beard, 0, 1) * (BEARD["strength"] * (0.25 + 1.5 * grain ** 1.5)))[..., None]
    k = np.clip(k, 0.0, 0.95)
    img = base * (1.0 - k) + np.array(BEARD["color"], np.float32) * k
    Image.fromarray(np.clip(np.round(img), 0, 255).astype(np.uint8), "RGB").save(
        SKIN_OUT, quality=SKIN_QUALITY, optimize=True)
    body.data.materials.clear()
    body.data.materials.append(image_material("M_KennySkin", SKIN_OUT, roughness=0.5))


def make_body(old_arm):
    """MPFB's human, shaped to him and fitted to his skeleton, weights on his
    bone names; returns (body object, {"l"/"r": (eye centre, eye forward)})."""
    HumanService = mpfb("services.humanservice", "HumanService")
    TargetService = mpfb("services.targetservice", "TargetService")
    Props = mpfb("entities.objectproperties", "HumanObjectProperties")
    human = HumanService.create_human()
    human.name = BODY_NAME
    for key, value in MACROS.items():
        Props.set_value(key, value, entity_reference=human)
    TargetService.reapply_macro_details(human)
    for name, weight in sorted({**FACE, **BODY}.items()):
        sided = TargetService.target_full_path(name) is None
        for full in ([f"l-{name}", f"r-{name}"] if sided else [name]):
            path = TargetService.target_full_path(full)
            if path is None or not pathlib.Path(path).name.startswith(full + "."):
                raise SystemExit(f"kenny_aaa: no MPFB target {full}")
            TargetService.load_target(human, path, weight=weight, name=full)
    rig = HumanService.add_builtin_rig(human, "game_engine")
    # Pin every MPFB bone onto his. Disconnected first: Blender ignores Copy
    # Location on a bone connected to its parent (aubrey_aaa.py).
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in rig.data.edit_bones:
        eb.use_connect = False
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        target = BONE_NAMES.get(pb.name, pb.name)
        if target not in old_arm.data.bones:
            continue
        if pb.name not in FREE_JOINTS:
            loc = pb.constraints.new("COPY_LOCATION")
            loc.target, loc.subtarget = old_arm, target
        aim = pb.constraints.new("DAMPED_TRACK")
        aim.target, aim.subtarget = old_arm, target
        aim.head_tail = 1.0
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    bpy.context.view_layer.objects.active = human
    for o in bpy.context.selected_objects:
        o.select_set(False)
    human.select_set(True)
    for mod in list(human.modifiers):
        if mod.type == "MASK":
            human.modifiers.remove(mod)
    if human.data.shape_keys:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    for mod in list(human.modifiers):
        if mod.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=mod.name)
    eyes = {}
    for side in ("l", "r"):
        group = human.vertex_groups[f"helper-{side}-eye"].index
        pts = [human.matrix_world @ v.co for v in human.data.vertices
               if any(g.group == group and g.weight > 0.5 for g in v.groups)]
        centre = sum(pts, Vector()) / len(pts)
        front = min(pts, key=lambda p: p.y)          # he faces -Y
        eyes[side] = (centre, (front - centre).normalized())
    cards = make_cards(human)
    body_group = human.vertex_groups["body"].index
    bm = bmesh.new()
    bm.from_mesh(human.data)
    deform = bm.verts.layers.deform.active
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if body_group not in v[deform]],
                     context="VERTS")
    bm.to_mesh(human.data)
    bm.free()
    # While MPFB's own "lips" group is still on him.
    paint_skin(human, eyes)
    for vg in list(human.vertex_groups):
        name = BONE_NAMES.get(vg.name, vg.name)
        if name in old_arm.data.bones:
            vg.name = name
        else:
            human.vertex_groups.remove(vg)
    bpy.data.objects.remove(rig, do_unlink=True)
    human.parent = old_arm
    human.matrix_parent_inverse = old_arm.matrix_world.inverted()
    human.modifiers.new("Armature", "ARMATURE").object = old_arm
    for card in cards:
        rigid_on_head(card, old_arm)
    return human, eyes


def transfer_weights(body, old_arm) -> None:
    """His skin weights from the base rig's mannequin, not MPFB's.

    MPFB's weights are authored for MPFB's A-pose. Bound at this skeleton's
    T-pose, every arms-down clip swings the arm 60-80 degrees from bind, and
    MPFB gives the upper arm the side of the chest and the lats below the
    armpit: rotated that far, that skin swung up and in, a slab down his back
    and a hump round his neck (Roman_Stand, Cody_Stand). Bone-heat weights did
    the same. The mannequin's weights were authored on this rig in this pose,
    and are what the scan was rigged with (tools/assets/rig_static_wrestler.py):
    the mannequin is posed into his rest (his wide stance), snapshotted, and its
    weights carried over by nearest surface, then smoothed.
    """
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(BASE_RIG))
    new = [o for o in bpy.data.objects if o not in before]
    base_arm = next(o for o in new if o.type == "ARMATURE")
    mannequin = max((o for o in new if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    bpy.context.view_layer.objects.active = base_arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in base_arm.pose.bones:
        if pb.name in old_arm.data.bones:
            c = pb.constraints.new("COPY_TRANSFORMS")
            c.target, c.subtarget = old_arm, pb.name
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    for o in bpy.context.selected_objects:
        o.select_set(False)
    mannequin.select_set(True)
    bpy.context.view_layer.objects.active = mannequin
    for mod in list(mannequin.modifiers):
        if mod.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=mod.name)
    # Clear his MPFB weights, keeping one empty group per bone.
    for vg in list(body.vertex_groups):
        body.vertex_groups.remove(vg)
    for vg in mannequin.vertex_groups:
        body.vertex_groups.new(name=vg.name)
    for o in bpy.context.selected_objects:
        o.select_set(False)
    body.select_set(True)
    mannequin.select_set(True)
    bpy.context.view_layer.objects.active = mannequin
    bpy.ops.object.data_transfer(data_type="VGROUP_WEIGHTS", vert_mapping="POLY_NEAREST",
                                 layers_select_src="ALL", layers_select_dst="NAME",
                                 mix_mode="REPLACE")
    for o in bpy.context.selected_objects:
        o.select_set(False)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=WEIGHT_SMOOTH_FACTOR,
                                       repeat=WEIGHT_SMOOTH_PASSES)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for vg in list(body.vertex_groups):
        if vg.name not in old_arm.data.bones:
            body.vertex_groups.remove(vg)
    weighted = sum(1 for v in body.data.vertices if v.groups)
    print(f"transfer_weights: {weighted}/{len(body.data.vertices)} vertices weighted")
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)


# --- Gear (stage 2) ----------------------------------------------------------

def leg_chain(old_arm, side):
    """His leg's joints, hip to toe tip, in world space."""
    b = old_arm.data.bones
    mw = old_arm.matrix_world
    return [mw @ b[f"thigh_{side}"].head_local, mw @ b[f"calf_{side}"].head_local,
            mw @ b[f"foot_{side}"].head_local, mw @ b[f"ball_{side}"].tail_local]


def leg_coords(pts, chain, side):
    """For points (N, 3): distance down the leg from the hip (negative above
    it, along the thigh's line), the angle round the leg (degrees, 0 to the
    front, +90 to the outside) and the distance from its axis."""
    import numpy as np
    joints = np.array([tuple(j) for j in chain], np.float64)
    best = np.full(len(pts), 1e9)
    s_out = np.zeros(len(pts))
    th_out = np.zeros(len(pts))
    r_out = np.zeros(len(pts))
    start = 0.0
    sign = 1.0 if side == "l" else -1.0
    for k in range(len(joints) - 1):
        a, b = joints[k], joints[k + 1]
        d = b - a
        length = np.linalg.norm(d)
        d = d / length
        t = (pts - a) @ d
        tc = np.clip(t, -10.0 if k == 0 else 0.0, length)
        foot = a + tc[:, None] * d
        rel = pts - foot
        dist = np.linalg.norm(rel, axis=1)
        out = np.array([sign, 0.0, 0.0]) - d * d[0] * sign
        out /= np.linalg.norm(out)
        fwd = np.array([0.0, -1.0, 0.0]) - d * (-d[1]) - out * (-out[1])
        fwd /= np.linalg.norm(fwd)
        better = dist < best
        best = np.where(better, dist, best)
        s_out = np.where(better, start + tc, s_out)
        th_out = np.where(better, np.degrees(np.arctan2(rel @ out, rel @ fwd)), th_out)
        r_out = np.where(better, dist, r_out)
        start += length
    return s_out, th_out, r_out


def gear_regions(pts, old_arm):
    """Which piece of gear each point (N, 3) is under: 0 none, 1 tights,
    2 band, 3 pad, 4 boot, 5 tape; and its (s, theta, side, knee_s)."""
    import numpy as np
    region = np.zeros(len(pts), np.int8)
    s = np.zeros(len(pts))
    th = np.zeros(len(pts))
    knee = {}
    for side in ("l", "r"):
        chain = leg_chain(old_arm, side)
        knee[side] = (chain[1] - chain[0]).length
        mask = (pts[:, 0] >= 0.0) if side == "l" else (pts[:, 0] < 0.0)
        ss, tt, _ = leg_coords(pts[mask], chain, side)
        s[mask], th[mask] = ss, tt
        kn = knee[side]
        legs = mask & (pts[:, 2] <= WAIST_TOP)
        r = np.where(s < kn - PAD_ABOVE, 1, np.where(s <= kn + PAD_BELOW, 3, 4))
        region[legs] = r[legs]
    band = (region == 1) & (pts[:, 2] > WAIST_TOP - BAND_DEPTH)
    region[band] = 2
    b = old_arm.data.bones
    mw = old_arm.matrix_world
    for side in ("l", "r"):
        hand = np.array(tuple(mw @ b[f"hand_{side}"].head_local))
        elbow = np.array(tuple(mw @ b[f"lowerarm_{side}"].head_local))
        d = (elbow - hand) / np.linalg.norm(elbow - hand)
        u = (pts - hand) @ d
        radial = np.linalg.norm((pts - hand) - u[:, None] * d, axis=1)
        tape = (u > -0.005) & (u < TAPE_LEN) & (radial < 0.07)
        region[tape] = 5
    side_l = pts[:, 0] >= 0.0
    knee_s = np.where(side_l, knee["l"], knee["r"])
    return region, s, th, knee_s


def make_gear(body, old_arm):
    """The gear shell (see GEAR), off the body's own faces; and the skin
    wholly under it removed."""
    import numpy as np
    mw = body.matrix_world
    co = np.array([tuple(mw @ v.co) for v in body.data.vertices])
    nrm = np.array([tuple((mw.to_3x3() @ v.normal).normalized()) for v in body.data.vertices])
    region, s, th, knee_s = gear_regions(co, old_arm)
    bump = np.exp(-((s - knee_s) / 0.05) ** 2) * np.clip(np.cos(np.radians(th)), 0.0, 1.0) ** 0.5
    off = np.select([region == 1, region == 2, region == 3, region == 4, region == 5],
                    [OFF_TIGHTS, OFF_BAND, OFF_PAD[0] + OFF_PAD[1] * bump, OFF_BOOT, OFF_TAPE], 0.0)
    gear = body.copy()
    gear.data = body.data.copy()
    gear.name = GEAR
    gear.data.name = GEAR
    bpy.context.scene.collection.objects.link(gear)
    bm = bmesh.new()
    bm.from_mesh(gear.data)
    # Each vertex's index in the body, carried through the deletes (which
    # renumber the survivors).
    orig = bm.verts.layers.int.new("orig")
    for v in bm.verts:
        v[orig] = v.index
    on = region > 0
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not all(on[v[orig]] for v in f.verts)],
                     context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    inv = mw.inverted()
    keep = {}
    for v in bm.verts:
        i = v[orig]
        keep[v] = i
        v.co = inv @ Vector(tuple(co[i] + nrm[i] * off[i]))
    # The boot's foot is modelled (make_boot_feet), not grown: off the skin it
    # kept his toes. The grown shell stops at BOOT_CUT over the ankle.
    cut = [f for f in bm.faces if all((mw @ v.co).z < BOOT_CUT for v in f.verts)
           and all(region[keep[v]] == 4 for v in f.verts)]
    bmesh.ops.delete(bm, geom=cut, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.verts.layers.int.remove(orig)
    bm.to_mesh(gear.data)
    bm.free()
    gear.data.materials.clear()
    print(f"make_gear: {len(gear.data.polygons)} faces; "
          + ", ".join(f"{n} {int((region == k).sum())}" for k, n in
                      ((1, "tights"), (2, "band"), (3, "pads"), (4, "boots"), (5, "tape"))))
    # The skin under it: faces whose every vertex is inside the gear and off
    # its edge (an edge vertex keeps its faces, so no gap opens at a hem).
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    bm.verts.index_update()
    edge = {v.index for v in bm.verts if on[v.index]
            and any(not on[n.index] for f in v.link_faces for n in f.verts)}
    inner = [f for f in bm.faces if all(on[v.index] and v.index not in edge for v in f.verts)]
    bmesh.ops.delete(bm, geom=inner, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(body.data)
    bm.free()
    print(f"make_gear: {len(inner)} skin faces under the gear removed")
    return gear, (co, region, s, th, knee_s)


def make_boot_feet(old_arm, gear):
    """Each boot's foot, joined to the gear: rings (BOOT_RINGS) round the
    foot's centre line, a closed toe, a sole and a heel; skinned to the calf,
    foot and ball as the foot is."""
    mesh_bm = bmesh.new()
    mesh_bm.from_mesh(gear.data)
    deform = mesh_bm.verts.layers.deform.verify()
    uv = mesh_bm.loops.layers.uv.verify()
    gi = {g.name: g.index for g in gear.vertex_groups}
    inv = gear.matrix_world.inverted()
    for side in ("l", "r"):
        chain = leg_chain(old_arm, side)
        ankle, toe = chain[2], chain[3]
        fwd = Vector((toe.x - ankle.x, toe.y - ankle.y, 0.0)).normalized()
        sign = 1.0 if side == "l" else -1.0
        across = Vector((fwd.y, -fwd.x, 0.0)) if fwd.y < 0 else Vector((-fwd.y, fwd.x, 0.0))
        if across.x * sign < 0:
            across = -across
        base = Vector((ankle.x, ankle.y, SOLE_Z))
        rings = []
        for k, (t, up, hw, height) in enumerate(BOOT_RINGS):
            ring = []
            for j in range(BOOT_SIDES):
                a = 2.0 * math.pi * j / BOOT_SIDES
                c, sn = math.cos(a), math.sin(a)
                if height == 0.0:
                    # The shaft: an ellipse round the leg at this height.
                    p = base + fwd * (t + sn * hw * 0.9) + across * (c * hw) + Vector((0, 0, up))
                else:
                    # The foot: an upper arched over a flat sole, as wide at
                    # the sole as at the widest line.
                    if sn >= 0.0:
                        x, z = c * hw, height * 0.5 * (1.0 + sn)
                    else:
                        x = math.copysign(abs(c) ** 0.5, c) * hw
                        z = height * 0.5 * (1.0 - (-sn) ** 0.35)
                    p = base + fwd * t + across * x + Vector((0, 0, z))
                v = mesh_bm.verts.new(inv @ p)
                # Weights: the foot, handing over to the ball at the toe.
                f = min(max(t / 0.2, 0.0), 1.0)
                if up > 0.12:
                    v[deform][gi[f"calf_{side}"]] = 0.6
                    v[deform][gi[f"foot_{side}"]] = 0.4
                else:
                    v[deform][gi[f"foot_{side}"]] = 1.0 - 0.7 * f
                    v[deform][gi[f"ball_{side}"]] = 0.7 * f
                ring.append(v)
            rings.append(ring)
        for k in range(len(rings) - 1):
            for j in range(BOOT_SIDES):
                jj = (j + 1) % BOOT_SIDES
                face = mesh_bm.faces.new((rings[k][j], rings[k][jj], rings[k + 1][jj], rings[k + 1][j]))
                face.smooth = True
                for loop in face.loops:
                    loop[uv].uv = (0.999, 0.001)
        toe_cap = mesh_bm.faces.new(rings[-1][::-1])
        for loop in toe_cap.loops:
            loop[uv].uv = (0.999, 0.001)
    bmesh.ops.recalc_face_normals(mesh_bm, faces=mesh_bm.faces[:])
    mesh_bm.to_mesh(gear.data)
    mesh_bm.free()


def _noise3(pts, freq, seed, octaves=3):
    """Deterministic fractal value noise at points (N, 3), in [0, 1]."""
    import numpy as np
    rng = np.random.default_rng(seed)
    lat = rng.random((64, 64, 64)).astype(np.float32)
    total = np.zeros(len(pts), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        q = pts * (freq * 2 ** o) + o * 17.3
        i = np.floor(q).astype(np.int64)
        f = (q - i).astype(np.float32)
        f = f * f * (3.0 - 2.0 * f)
        acc = np.zeros(len(pts), np.float32)
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) \
                        * (f[:, 2] if dz else 1 - f[:, 2])
                    acc += w * lat[(i[:, 0] + dx) % 64, (i[:, 1] + dy) % 64, (i[:, 2] + dz) % 64]
        total += amp * acc
        norm += amp
        amp *= 0.5
    return total / norm


def _stroke(u, v, path, width):
    """Distance from (u, v) to a polyline, minus half its width (< 0 on it)."""
    import numpy as np
    best = np.full(u.shape, 1e9)
    for (au, av), (bu, bv) in zip(path, path[1:]):
        du, dv = bu - au, bv - av
        t = np.clip(((u - au) * du + (v - av) * dv) / (du * du + dv * dv), 0.0, 1.0)
        best = np.minimum(best, np.hypot(u - au - t * du, v - av - t * dv))
    return best - width * 0.5


def numeral_two(cu, cv, size):
    """The sheet's "2" as a polyline in a flat frame (u right, v down): an
    arc over the top, a diagonal down to the left, a foot to the right."""
    import math
    r = size * 0.38
    arc = [(cu + r * math.cos(a), cv - size * 0.12 + r * math.sin(a))
           for a in [math.radians(d) for d in range(190, 391, 20)]]
    return arc + [(cu - size * 0.40, cv + size * 0.5), (cu + size * 0.42, cv + size * 0.5)]


def _ring(u, v, cu, cv, radius, width):
    """Mask of a ring (and its distance outside it) in a flat (u, v) frame."""
    import numpy as np
    d = np.abs(np.hypot(u - cu, v - cv) - radius)
    return d < width * 0.5, d - width * 0.5


def paint_gear(gear, old_arm) -> None:
    """The gear's albedo and ORM (occlusion, roughness, metal) in the body's
    UV space, written to GEAR_OUT and GEAR_ORM_OUT; the albedo put on it."""
    import numpy as np
    from PIL import Image
    size = GEAR_SIZE
    mesh = gear.data
    mw = gear.matrix_world
    co = np.array([tuple(mw @ v.co) for v in mesh.vertices], np.float32)
    uvs = mesh.uv_layers["UVMap"].data
    pos = np.zeros((size, size, 3), np.float32)
    hit = np.zeros((size, size), bool)
    mesh.calc_loop_triangles()
    for tri in mesh.loop_triangles:
        vi = list(tri.vertices)
        uv = np.array([uvs[i].uv for i in tri.loops], np.float32)
        px = np.stack([uv[:, 0] * size - 0.5, (1.0 - uv[:, 1]) * size - 0.5], 1)
        x0, y0 = np.maximum(np.floor(px.min(0)).astype(int) - 1, 0)
        x1, y1 = np.minimum(np.ceil(px.max(0)).astype(int) + 1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = px
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        w0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
        w1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        w2 = 1.0 - w0 - w1
        # A little past each edge, so the texture bleeds across UV seams.
        inside = (w0 >= -0.08) & (w1 >= -0.08) & (w2 >= -0.08)
        new = inside & ~hit[ys, xs] | inside & (np.minimum(np.minimum(w0, w1), w2) >= 0)
        if not new.any():
            continue
        weights = np.stack([w0, w1, w2], -1)[new]
        pos[ys[new], xs[new]] = weights @ co[vi]
        hit[ys[new], xs[new]] = True
    pts = pos[hit].astype(np.float64)
    region, s, th, knee_s = gear_regions(pts, old_arm)
    out_of = region == 0
    region[out_of] = 1
    n = len(pts)
    col = np.zeros((n, 3), np.float32)
    rough = np.full(n, 0.45, np.float32)
    metal = np.zeros(n, np.float32)
    flecks = _noise3(pts, 38.0, GEAR_SEED, 3)
    # Fine speckle, the sheet's gold-leaf grain on the pads and boots.
    grain = _noise3(pts, 140.0, GEAR_SEED + 4, 2)
    marble = _noise3(pts, 9.0, GEAR_SEED + 1, 4)
    crumple = _noise3(pts, 22.0, GEAR_SEED + 2, 3)
    fil = _noise3(pts, 6.0, GEAR_SEED + 3, 3)
    sgn = np.where(pts[:, 0] >= 0.0, 1.0, -1.0)

    def put(mask, rgb, r, m):
        col[mask] = np.array(rgb, np.float32)
        rough[mask] = r
        metal[mask] = m

    def gold(mask, specks=0.6):
        """Gold leaf with black flecks through it."""
        put(mask, GOLD, 0.32, 0.8)
        deep = mask & (marble > 0.55)
        col[deep] = col[deep] * 0.75 + np.array(GOLD_DEEP, np.float32) * 0.25
        dark = mask & (flecks > specks)
        put(dark, BLACK, 0.4, 0.0)

    # Tights: white satin, crumpled, with gold flecks marbled through.
    t = region == 1
    put(t, WHITE, 0.42, 0.0)
    col[t] *= (0.9 + 0.1 * crumple[t])[:, None]
    fleck = t & (flecks * (0.6 + 0.8 * marble) > 0.78)
    put(fleck, GOLD, 0.32, 0.8)
    # The ornate panel down the outside of each thigh: gold under black
    # filigree, edged in black, wavering down the leg.
    kn = knee_s
    edge = 46.0 + 10.0 * np.sin(s * 16.0 + sgn) + 6.0 * np.sin(s * 37.0)
    dist = np.abs(th - 95.0) - edge
    panel = t & (dist < 0.0) & (s < kn - 0.03)
    gold(panel, 0.66)
    swirl = panel & ((np.abs(np.sin(th * 0.13 + s * 40.0 + 11.0 * fil)) < 0.2)
                     | (np.abs(np.sin(th * 0.07 - s * 55.0 + 8.0 * marble)) < 0.12))
    put(swirl, BLACK, 0.4, 0.0)
    outline = t & (np.abs(dist) < 4.0) & (s < kn - 0.03)
    put(outline, BLACK, 0.4, 0.0)
    # The "2" on the front of his right thigh: gold, outlined in black. Flat
    # frame on the leg: u across it as seen from the front (his right leg's
    # outside is screen-left, so u runs the other way to theta), v down it.
    right = t & (sgn < 0)
    u = -np.radians(th) * 0.085
    two = _stroke(u, s, numeral_two(-0.06, 0.19, 0.14), 0.024)
    gold(right & (two < 0.0), 0.75)
    put(right & (np.abs(two) < 0.004), BLACK, 0.4, 0.0)
    # Waistband: black, gold through it, white tabs at the front and hips.
    b = region == 2
    put(b, BLACK, 0.4, 0.0)
    put(b & (grain + 0.3 * marble > 0.82), GOLD, 0.32, 0.8)
    tab = b & ((np.abs(pts[:, 0]) < 0.014) & (pts[:, 1] < 0.0)
               | (np.abs(np.abs(pts[:, 0]) - 0.135) < 0.012) & (pts[:, 1] < 0.03))
    put(tab, PIPING, 0.5, 0.0)
    # Kneepads: black, dense gold, a gold scroll on the right knee's front.
    p = region == 3
    put(p, BLACK, 0.5, 0.0)
    put(p & (grain + 0.35 * marble > 0.86), GOLD, 0.32, 0.8)
    ktwo = _stroke(-np.radians(th) * 0.07, s - kn, numeral_two(0.0, -0.01, 0.11), 0.018)
    put(p & (sgn < 0) & (ktwo < 0.0), GOLD, 0.32, 0.8)
    # Boots: black leather; a gold panel up the front and outside, two gold
    # stripes up the back, white piping round both; the foot black.
    bt = region == 4
    put(bt, LEATHER, 0.33, 0.0)
    col[bt] *= (0.85 + 0.3 * crumple[bt])[:, None]
    shin = bt & (s < kn + 0.40)
    pedge = 50.0 + 8.0 * np.sin(s * 21.0 + sgn * 2.0)
    pdist = np.abs(th - 25.0) - pedge
    front = shin & (pdist < 0.0)
    put(front, GOLD, 0.32, 0.8)
    put(front & (grain > 0.64), BLACK, 0.4, 0.0)
    put(shin & ~front & (grain + 0.3 * marble > 0.9), GOLD, 0.32, 0.8)
    put(shin & (np.abs(pdist) < 4.5), PIPING, 0.45, 0.0)
    for c in (165.0, -165.0):
        sd = np.abs(((th - c + 180.0) % 360.0) - 180.0) - 6.0
        put(shin & (sd < 0.0), GOLD, 0.32, 0.8)
        put(shin & (np.abs(sd) < 2.5), PIPING, 0.45, 0.0)
    sole = bt & (pts[:, 2] < SOLE_Z + 0.025)
    put(sole, (14, 14, 15), 0.7, 0.0)
    # Wrist tape: white, with the weave.
    w = region == 5
    put(w, TAPE, 0.85, 0.0)
    col[w] *= (0.92 + 0.08 * crumple[w])[:, None]
    albedo = np.zeros((size, size, 3), np.float32)
    orm = np.zeros((size, size, 3), np.float32)
    albedo[...] = WHITE
    albedo[hit] = col
    orm[..., 0] = 255.0
    orm[..., 1] = 0.45 * 255.0
    orm[hit, 1] = rough * 255.0
    orm[hit, 2] = metal * 255.0
    # The modelled boot feet sample one corner of the map (make_boot_feet):
    # black leather.
    albedo[-48:, -48:] = LEATHER
    orm[-48:, -48:, 1] = 0.33 * 255.0
    orm[-48:, -48:, 2] = 0.0
    Image.fromarray(np.clip(np.round(albedo), 0, 255).astype(np.uint8), "RGB").save(GEAR_OUT, optimize=True)
    Image.fromarray(np.clip(np.round(orm), 0, 255).astype(np.uint8), "RGB").save(GEAR_ORM_OUT, optimize=True)
    mat = bpy.data.materials.new("M_KennyGear")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(GEAR_OUT))
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.45
    gear.data.materials.clear()
    gear.data.materials.append(mat)
    print(f"paint_gear: {n} texels")


def _lerp_table(table, x):
    xs, ys = zip(*table)
    if x <= xs[0]:
        return ys[0]
    for (x0, y0), (x1, y1) in zip(table, table[1:]):
        if x0 <= x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return ys[-1]


def _s01(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def paint_hair_textures() -> None:
    """The curl cards' strands (RGBA: colour root to tip, alpha the strands)
    in CURL_COLUMNS clumps, and the cap's tile of tight curls."""
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter
    rng = np.random.default_rng(CURL_SEED + 1)
    ss = 2
    w, h = CURL_TEX[0] * ss, CURL_TEX[1] * ss
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    col = w // CURL_COLUMNS
    for c in range(CURL_COLUMNS):
        centre = c * col + col * 0.5
        for _ in range(CURL_STRANDS):
            x0 = centre + col * 0.42 * float(np.clip(rng.normal(0.0, 0.45), -1.0, 1.0))
            length = h * float(rng.uniform(0.75, 1.0))
            amp = float(rng.uniform(6.0, 14.0)) * ss
            phase = float(rng.uniform(0.0, 2.0 * math.pi))
            freq = float(rng.uniform(10.0, 16.0))
            pts = []
            for t in np.linspace(0.0, 1.0, 160):
                x = x0 + (centre - x0) * 0.5 * t * t + amp * math.sin(phase + freq * 2.0 * math.pi * t)
                pts.append((x, t * length))
            draw.line(pts, fill=int(rng.integers(160, 256)),
                      width=max(1, round(float(rng.uniform(1.8, 3.0)) * ss)))
    mask = mask.filter(ImageFilter.GaussianBlur(0.6 * ss)).resize(CURL_TEX, Image.LANCZOS)
    t = np.linspace(0.0, 1.0, CURL_TEX[1])[:, None, None]
    root, mid, tip = (np.array(c, np.float32) for c in (HAIR_ROOT, HAIR_MID, HAIR_TIP))
    rgb = np.where(t < 0.35, root + (mid - root) * (t / 0.35), mid + (tip - mid) * ((t - 0.35) / 0.65))
    streak = rng.random(CURL_TEX[0]).astype(np.float32)
    streak = np.convolve(streak, np.ones(9) / 9, "same")[None, :, None]
    rgb = rgb * (0.8 + 0.4 * streak)
    rgba = np.concatenate([np.broadcast_to(rgb, (CURL_TEX[1], CURL_TEX[0], 3)),
                           np.asarray(mask, np.float32)[..., None]], -1)
    Image.fromarray(np.clip(np.round(rgba), 0, 255).astype(np.uint8), "RGBA").save(HAIR_TEX, optimize=True)
    # The cap: wavy strands combed back (v), colour only, darker at the
    # roots over the front.
    size = 1024
    img = Image.new("RGB", (size, size), tuple(int(c * 0.9) for c in HAIR_ROOT))
    draw = ImageDraw.Draw(img)
    for _ in range(1500):
        x0 = float(rng.uniform(0, size))
        y0 = float(rng.uniform(-0.2, 0.9)) * size
        length = float(rng.uniform(0.15, 0.5)) * size
        amp = float(rng.uniform(2.0, 7.0))
        freq = float(rng.uniform(3.0, 7.0))
        phase = float(rng.uniform(0, 6.28))
        mix = float(rng.beta(1.6, 2.6))
        colr = tuple(int(HAIR_ROOT[k] + (HAIR_TIP[k] - HAIR_ROOT[k]) * mix) for k in range(3))
        pts = [((x0 + amp * math.sin(phase + freq * 6.28 * t)) % size, y0 + t * length)
               for t in np.linspace(0, 1, 40)]
        for a_, b_ in zip(pts, pts[1:]):
            if abs(a_[0] - b_[0]) < size / 2:
                draw.line([a_, b_], fill=colr, width=2)
    img.filter(ImageFilter.GaussianBlur(0.6)).save(CAP_TEX, optimize=True)


def make_hair_cap(old_arm, body, eyes):
    """His scalp's skin, above the hairline (HAIRLINE), lifted off it with
    volume (CAP_OFF), feathered at the hairline by vertex alpha."""
    e = (eyes["l"][0] + eyes["r"][0]) / 2.0
    centre = e + Vector((0.0, 0.08, 0.02))
    mw = body.matrix_world
    head = {body.vertex_groups[n].index for n in ("Head", "neck_01") if n in body.vertex_groups}
    margin = {}
    for v in body.data.vertices:
        if sum(g.weight for g in v.groups if g.group in head) <= 0.5:
            continue
        p = mw @ v.co
        r = p - centre
        angle = math.degrees(math.atan2(abs(r.x), -r.y))
        margin[v.index] = (p.z - e.z) - _lerp_table(HAIRLINE, angle)
    faces = [f for f in body.data.polygons
             if all(i in margin for i in f.vertices) and max(margin[i] for i in f.vertices) > 0.0]
    used = sorted({i for f in faces for i in f.vertices})
    remap = {o: n for n, o in enumerate(used)}
    verts, uvs, alpha = [], [], []
    for i in used:
        v = body.data.vertices[i]
        p = mw @ v.co
        n = (mw.to_3x3() @ v.normal).normalized()
        off = CAP_OFF[0] + CAP_OFF[1] * _s01(0.0, CAP_RAMP, margin[i])
        verts.append(p + n * off)
        # Strands comb back over the head: v runs from the front pole (over
        # the forehead) to the back, u round that axis.
        r = (p - centre).normalized()
        phi = math.acos(max(-1.0, min(1.0, r.dot(CAP_AXIS))))
        az = math.atan2(r.dot(CAP_E2), r.dot(CAP_E1))
        uvs.append(((az / (2.0 * math.pi) + 0.5) * CAP_U_TILES, phi / math.pi * 1.6))
        alpha.append(_s01(0.0, HAIRLINE_FEATHER, margin[i]))
    mesh = bpy.data.meshes.new(HAIR_CAP)
    mesh.from_pydata([tuple(v) for v in verts], [], [[remap[i] for i in f.vertices] for f in faces])
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            uv.data[li].uv = uvs[mesh.loops[li].vertex_index]
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for k, a in enumerate(alpha):
        col.data[k].color = (1.0, 1.0, 1.0, a)
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.materials.append(image_material("M_KennyHairCap", CAP_TEX, roughness=0.55))
    cap = bpy.data.objects.new(HAIR_CAP, mesh)
    bpy.context.scene.collection.objects.link(cap)
    cap.vertex_groups.new(name="Head").add(list(range(len(verts))), 1.0, "REPLACE")
    cap.parent = old_arm
    cap.matrix_parent_inverse = old_arm.matrix_world.inverted()
    cap.modifiers.new("Armature", "ARMATURE").object = old_arm
    print(f"make_hair_cap: {len(faces)} faces")
    return cap


def make_curls(old_arm, body, cap, eyes):
    """CURL_COUNT curl clumps (see the HAIR note) hanging from under the cap
    over his head, neck and shoulders."""
    import numpy as np
    from mathutils.bvhtree import BVHTree
    rng = np.random.default_rng(CURL_SEED)
    dg = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(body, dg)
    cap_bvh = BVHTree.FromObject(cap, dg)
    e = (eyes["l"][0] + eyes["r"][0]) / 2.0
    centre = e + Vector((0.0, 0.08, 0.02))
    verts, faces, uvs, weights = [], [], [], []
    plan = [(CURL_COUNT, CURL_ANGLES, 0.0), CURL_UPPER]
    jobs = [(n, k, angles, lift) for n, angles, lift in plan for k in range(n)]
    for count, i, angles, lift in jobs:
        side = 1.0 if i % 2 == 0 else -1.0
        frac = (i // 2 + float(rng.uniform(0.0, 1.0))) / (count / 2)
        ang = angles[0] + (angles[1] - angles[0]) * frac
        a = math.radians(ang)
        top = e.z + _lerp_table(CURL_TOP, ang) + lift + float(rng.uniform(-0.01, 0.03))
        d = Vector((side * math.sin(a), -math.cos(a), 0.0))
        hit = cap_bvh.ray_cast(Vector((centre.x, centre.y, top)) + d * 0.3, -d, 0.4)[0]
        if hit is None:
            continue
        standoff = float(rng.uniform(*CURL_STANDOFF))
        start = hit + d * 0.012
        end_z = float(rng.uniform(*CURL_END))
        # The line: down, pushed out of the body to its standoff, and never
        # back in toward it faster than a drape.
        pts = [start]
        p = start.copy()
        out_dir = d.copy()
        while p.z > end_z:
            p = p + Vector((0.0, 0.0, -CURL_STEP)) + out_dir * (CURL_STEP * CURL_FLARE)
            near = bvh.find_nearest(p)
            if near[0] is not None:
                gap = (p - near[0]).length
                n = (p - near[0]).normalized() if gap > 1e-6 else near[1]
                if gap < standoff:
                    # Out of the body, but never back up: on top of his
                    # shoulders the push is upward, and the line stalled.
                    z_next = p.z
                    p = near[0] + n * standoff
                    p.z = min(p.z, z_next)
            pts.append(p.copy())
        for _ in range(3):
            pts = [pts[0]] + [(pts[k - 1] + pts[k] * 2 + pts[k + 1]) / 4 for k in range(1, len(pts) - 1)] + [pts[-1]]
        if len(pts) < 5:
            continue
        radius = float(rng.uniform(*CURL_RADIUS))
        pitch = float(rng.uniform(*CURL_PITCH))
        phase = float(rng.uniform(0.0, 2.0 * math.pi))
        w_top = float(rng.uniform(*CURL_WIDTH[0]))
        column = int(rng.integers(0, CURL_COLUMNS))
        cols = (column, (column + 1) % CURL_COLUMNS)
        total = (len(pts) - 1) * CURL_STEP
        tan0 = (pts[1] - pts[0]).normalized()
        n1 = (d - tan0 * d.dot(tan0)).normalized()
        base = len(verts)
        for k, c in enumerate(pts):
            tan = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
            n1 = (n1 - tan * n1.dot(tan)).normalized()
            n2 = tan.cross(n1)
            s_ = k * CURL_STEP
            rel = s_ / total
            phi = 2.0 * math.pi * s_ / pitch + phase
            ctr = c + (n1 * math.cos(phi) + n2 * math.sin(phi)) * radius * _s01(0.0, 0.03, s_)
            width = (w_top + (CURL_WIDTH[1] - w_top) * rel ** 1.5) * (0.5 + 0.5 * _s01(0.0, 0.02, s_))
            body_w = HAIR_BODY_SHARE * (1.0 - _s01(HAIR_BODY_Z[1], HAIR_BODY_Z[0], c.z))
            wts = [("Head", 1.0 - body_w)] + ([("spine_03", body_w)] if body_w > 0 else [])
            for card, direction in enumerate((n1, n2)):
                for sd in (-0.5, 0.5):
                    verts.append(ctr + direction * (width * sd))
                    uvs.append(((cols[card] + sd + 0.5) / CURL_COLUMNS, 1.0 - rel))
                    weights.append(wts)
        for k in range(len(pts) - 1):
            for card in range(2):
                q = base + k * 4 + card * 2
                r_ = base + (k + 1) * 4 + card * 2
                faces.append((q, q + 1, r_ + 1, r_))
    mesh = bpy.data.meshes.new(HAIR_CURLS)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            uv.data[li].uv = uvs[mesh.loops[li].vertex_index]
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.materials.append(image_material("M_KennyHair", HAIR_TEX, roughness=0.45, alpha=True))
    obj = bpy.data.objects.new(HAIR_CURLS, mesh)
    bpy.context.scene.collection.objects.link(obj)
    groups = {}
    for k, wts in enumerate(weights):
        for bone, w in wts:
            if bone not in groups:
                groups[bone] = obj.vertex_groups.new(name=bone)
            groups[bone].add([k], w, "REPLACE")
    obj.parent = old_arm
    obj.matrix_parent_inverse = old_arm.matrix_world.inverted()
    obj.modifiers.new("Armature", "ARMATURE").object = old_arm
    print(f"make_curls: {len(faces) // 2} card quads pairs, {2 * len(faces)} triangles")
    return obj


def main() -> int:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    addon_utils.enable(MPFB, default_set=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    old_arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    # The scan goes; only its skeleton is kept.
    for o in list(bpy.data.objects):
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    body, eyes = make_body(old_arm)
    transfer_weights(body, old_arm)
    gear, _ = make_gear(body, old_arm)
    make_boot_feet(old_arm, gear)
    paint_gear(gear, old_arm)
    make_eyes(old_arm, eyes)
    paint_hair_textures()
    cap = make_hair_cap(old_arm, body, eyes)
    make_curls(old_arm, body, cap, eyes)
    for o in bpy.context.scene.objects:
        o.select_set(o == old_arm or o.parent == old_arm)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                              export_yup=True, export_animations=False, export_skins=True,
                              export_apply=False, export_image_format="AUTO")
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"kenny_aaa: body {tris} triangles, eyes at "
          f"{tuple(round(c, 3) for c in eyes['l'][0])} -> {OUT}")
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main())
