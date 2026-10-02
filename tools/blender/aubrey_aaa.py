#!/usr/bin/env python3
"""The referee, Aubrey Edwards, rebuilt to a AAA standard (character_aaa_plan.md
A1-A3) on a realistic human body, on her existing skeleton.

    python3 tools/blender/aubrey_aaa.py

Reads   game/assets/characters/aubrey_edwards.glb   (the kit build: skeleton,
                                                    uniform, hair)
Writes  game/assets/characters/aubrey_aaa.glb

Why: her kit body (Quaternius' Superhero_Female) is a cartoon -- 17 mm eyes,
painted lids, a toy's face -- and the owner's character sheet is a real woman.
The body is now MPFB's (MakeHuman for Blender, CC0 code and assets), shaped to
her, and everything the game relies on is kept:

* THE SKELETON is hers, untouched: the same 70 bones, names and rest pose, so
  every clip, paired move and the referee's own logic play on her as before
  (the plan's rule 1). MPFB's game-engine rig uses the same bone names (its
  "head" is her "Head"), so the body is FITTED to her skeleton rather than
  the other way round: each MPFB bone is pinned to her bone of the same name
  (Copy Location to its head, Damped Track to its tail) and that pose is
  baked into the mesh. Her joints then bend exactly where the clips bend
  them. Joints move and bones only aim -- no Stretch To, which would scale
  each bone's own region (her kit head bone is 20 cm to MPFB's 15) -- so the
  mesh between joints stretches through its blended weights while a head or
  a hand keeps its size.
* THE WEIGHTS are MPFB's own -- complete and smooth, fingers included --
  renamed onto her bones; her kit body cannot supply them (the skin under
  her uniform was deleted when the uniform was cut).
* HER UNIFORM AND HAIR (cut for the kit body) are REFITTED to the new one.
  Each garment conforms by its own standoff: fabric inside or nearer the skin
  than its minimum is pushed out to it, fabric hanging further than its
  maximum is pulled in, and everything between keeps its drape; the
  corrections are smoothed across the cloth (GARMENT_SMOOTH) so nothing
  kinks, then the minimum is enforced again. Each garment then takes its
  weights from the new body, so cloth and skin move as one, and the skin
  under the cloth is deleted -- bar the ring at each opening -- so nothing
  can poke through in a pose. The ponytail, its tie and the ponytail spring
  bones move to the new skull where the tie sits.
* HER COLLAR is new: the kit shirt's neckline zig-zagged from 1.39 to 1.53 m
  and stood up round her neck in shards. Now the shirt is trimmed below the
  collar line and a polo collar is built round her actual neck -- rays
  inward at COLLAR_STEPS angles find the surface -- as a stand and a
  fold-over flap (COLLAR_PROFILE), open at the front with the points angled
  down, and a zip placket down the front, in the shirt's own black trim.
* HER HAIR CAP is new: the kit's was cut for the cartoon skull and on a real
  head covered a strip over the crown with bare sides. It is grown from the
  new head's own scalp faces inside a hairline traced off the owner's sheet
  (HAIRLINE: high at the forehead, down past the temples, over and behind
  the ears to the nape), lifted CAP_OFF, feathered over its last
  centimetre by vertex alpha, and UV'd so the strands run from the hairline
  back to the ponytail tie -- slicked hair, combed back. Its strand texture
  (aubrey_hair_strands.png) is painted here.
* Helpers (MakeHuman's joint cubes, tights, skirt, eye and teeth proxies) are
  measured and then deleted; the eyes are rebuilt as eyeballs where MPFB's
  eye helpers sit, for the head kit's eye texture (build_eyes.py, EyeKit).

Requires MPFB installed as a Blender extension (bl_ext.user_default.mpfb) and
its MakeHuman system assets and skin packs under ~/.cache/aegis_assets/mpfb;
see gauntlet/refs/character_aaa_plan.md. Deterministic.
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
SOURCE = ROOT / "game/assets/characters/aubrey_edwards.glb"
OUT = ROOT / "game/assets/characters/aubrey_aaa.glb"
MPFB = "bl_ext.user_default.mpfb"

## MPFB's macro sliders for her: a woman (MakeHuman's gender runs 0 female
## to 1 male -- the first build at 1.0 was a heavyset man) of about forty
## (age 0.5 is 25 and 1.0 is 90), lean and athletic -- she runs a ring for a
## living -- with idealised rather than average proportions.
MACROS = {
    "gender": 0.0, "age": 0.62, "muscle": 0.62, "weight": 0.42,
    "proportions": 0.75, "african": 0.0, "asian": 0.0, "caucasian": 1.0,
}
## Her likeness (stage 3): MPFB face targets, set against the owner's
## character sheet (front, 3/4 and profile) on a clay render. A long face,
## high cheekbones over slightly hollow cheeks, a slim jaw tapering to a
## narrow, defined chin with a clean line into the neck; a long straight nose
## with a softly rounded tip; a wide mouth with a full lower lip carried
## forward; large, open almond eyes under a raised brow; a slim neck. A name
## without a side (e.g. "cheek-bones-incr") is applied to both l- and r-.
FACE = {
    # head
    "forehead-scale-vert-incr": 0.2,
    "forehead-temple-decr": 0.3,
    "forehead-trans-backward": 0.25,
    "head-oval": 0.5,
    "head-scale-horiz-decr": 0.1,
    # chin and jaw
    "chin-bones-incr": 0.4,
    "chin-height-incr": 0.35,
    "chin-jaw-drop-incr": 0.3,
    "chin-prominent-incr": 0.75,
    "chin-triangle": 0.3,
    "chin-width-decr": 0.5,
    "neck-double-decr": 0.6,
    "neck-scale-horiz-decr": 0.4,
    # cheeks
    "cheek-bones-incr": 1.26,
    "cheek-inner-decr": 0.7,
    "cheek-volume-decr": 0.6,
    # nose
    "nose-flaring-decr": 0.3,
    "nose-point-down": 0.15,
    "nose-point-width-decr": 0.15,
    "nose-scale-depth-incr": 0.85,
    "nose-scale-vert-incr": 0.45,
    "nose-width1-decr": 0.3,
    "nose-width2-decr": 0.3,
    # mouth
    "mouth-cupidsbow-incr": 0.6,
    "mouth-lowerlip-volume-incr": 0.55,
    "mouth-scale-horiz-incr": 0.3,
    "mouth-trans-forward": 0.49,
    "mouth-upperlip-volume-incr": 0.15,
    # eyes and brows
    "eye-corner2-up": 0.2,
    "eye-height2-incr": 0.2,
    "eye-scale-incr": 0.5,
    "eyebrows-trans-forward": 0.3,
    "eyebrows-trans-up": 0.1,
}
## MPFB bone -> her bone, where the names differ.
BONE_NAMES = {"head": "Head"}
## Bones that take her bone's direction but keep their own position. Her kit
## skeleton is a stylised one with a big head: its head joint sits 21.7 cm
## under the crown, where a real head's is ~15. Pinned there, a real head
## sank 8 cm onto a stub of a neck (eyes at 1.58 against 1.66). Left free, it
## rides MPFB's own neck; the head turns about her Head bone, ~3.5 cm lower
## in the neck, which no clip's head rotation shows.
FREE_JOINTS = {"head"}
## Garment -> (minimum, maximum) standoff off the new body, metres. The
## minimums are the kit build's own offsets (referee_aubrey.py SHIRT_OFF,
## TROUSER_OFF, SHOE_OFF); the maximums let a shirt drape but not tent.
GARMENTS = {
    "Aubrey_Shirt": (0.022, 0.055),
    "Aubrey_Trousers": (0.012, 0.040),
    "Aubrey_Shoes": (0.011, 0.030),
}
## Riding on the shirt: moved with the nearest shirt vertex.
SHIRT_RIDERS = ("Aubrey_Patch",)
GARMENT_SMOOTH = 6
## The hair cap's standoff: slicked tight to the skull.
CAP = "Aubrey_HairCap"
CAP_OFF = 0.004
## Her hairline: height above the eyes (m) by the angle round the head from
## straight ahead (degrees) -- a high forehead, the temples, over the ear,
## behind it, the nape.
HAIRLINE = [(0.0, 0.072), (35.0, 0.062), (60.0, 0.042), (82.0, 0.030),
            (100.0, 0.010), (125.0, -0.040), (180.0, -0.070)]
## The cap feathers out over this much of its edge.
HAIRLINE_FEATHER = 0.012
## Her ears: never under the cap. Out from the head's centre line beyond
## EAR_X, within EAR_Z of eye height, the cap's margin goes negative.
EAR_X = 0.064
EAR_Z = (-0.040, 0.022)
## Strand repeats round the head.
CAP_U_TILES = 6
HAIR_STRANDS = ROOT / "game/assets/characters/aubrey_hair_strands.png"
HAIR_SIZE = 1024
HAIR_SEED = 47
## Her hair (the owner's sheet): mid brown, slicked wet, with lighter
## caramel strands through it.
HAIR_BASE = (74, 52, 36)
HAIR_LIGHT = (142, 104, 70)
PONYTAIL = ("Aubrey_Ponytail", "Aubrey_HairTie")
TIE = "Aubrey_HairTie"
PONYTAIL_BONES = ("ponytail_1", "ponytail_2", "ponytail_3", "ponytail_4", "ponytail_5")
## The collar: where it sits (its base, m), how many angles round the neck,
## the gap at the front (degrees either side of straight ahead), and its
## profile as (height above the base, standoff off the neck) from the stand's
## foot up and over the fold to the flap's edge.
## The base is tilted, as a collar sits: COLLAR_Z at the sides, COLLAR_TILT
## lower at the front (over the notch between the collarbones) and higher at
## the back. Flat at 1.47 the inward rays met the slope of her trapezius and
## the collar sat round her shoulders.
COLLAR_Z = 1.478
COLLAR_TILT = 0.024
## The neck is sampled this far up from the base, and no wider than this.
COLLAR_SAMPLE_UP = 0.022
COLLAR_MAX_R = 0.072
COLLAR_STEPS = 48
## Narrow: on the owner's sheet she is zipped up to the collar.
COLLAR_GAP = 6.0
COLLAR_PROFILE = [(0.000, 0.004), (0.014, 0.004), (0.027, 0.004), (0.033, 0.008),
                  (0.031, 0.012), (0.020, 0.016), (0.008, 0.021), (-0.004, 0.025)]
## The collar's points drop by this at the front edges.
COLLAR_POINT_DROP = 0.022
## Shirt faces above the collar's (tilted) base plus COLLAR_TRIM_UP, within
## COLLAR_TRIM_R of the neck's axis, go: the collar's flap covers the cut.
COLLAR_TRIM_UP = 0.012
COLLAR_TRIM_R = 0.105
## The placket: from the collar's gap down to PLACKET_BOTTOM, this wide.
PLACKET_BOTTOM = 1.355
PLACKET_HALF_W = 0.016
TRIM_MATERIAL = "M_RefTrim"
## Skin is deleted where a ray out along its normal meets cloth within this.
COVER_REACH = 0.08
## Eyeball radius over MPFB's eye helper's: the helper is the eye's visible
## front; a real eyeball is ~12 mm.
EYE_RADIUS = 0.0118
EYE_SEGMENTS = (32, 16)
## The eyes' front projection (build_eyes.py AUBREY_AAA): mm per UV unit.
EYE_MM_PER_UV = 30.0
EYE_COLOR = ROOT / "game/assets/characters/aubrey_aaa_eye_color.png"

## Her skin (stage 4): a CC0 MakeHuman skin with no make-up painted on --
## toigo's young light-skinned female, bronze -- graded from its orange
## toward the sheet's rosier beige, then her make-up painted over it in UV
## space from 3D positions (paint_skin): the head's triangles are
## rasterised into a map of where each texel sits on her, and each layer of
## make-up is a function of that position, so it lands on her actual lids
## and lips whatever the targets did to them.
MPFB_ASSETS = pathlib.Path.home() / ".cache/aegis_assets/mpfb"
SKIN_SOURCE = (MPFB_ASSETS / "unpacked_skins01/skins/toigo_light_skin_female_bronze"
               / "young_lightskinned_female_diffuse_Bronze.png")
SKIN_OUT = ROOT / "game/assets/characters/aubrey_aaa_skin.jpg"
SKIN_GRADE = (0.88, 0.90, 1.04)
SKIN_QUALITY = 92
## Smoky eyes (the sheet's make-up close-up): a soft dark plum-brown shadow
## in an ellipse round each eye (mm: wider to the outer corner, higher over
## the lid than under it), pulled 2 mm outward into a wing, lighter on the
## lower lid; and a liner along the lid margin -- where the lids meet the
## eyeball, the body's socket being closed behind it.
SMOKE = dict(shift=2.0, a_out=19.0, a_in=15.0, b_up=17.0, b_down=9.0,
             e0=0.45, e1=1.15, lower=0.7, color=(66, 42, 44), strength=0.85)
LINER = dict(near=0.8, far=3.0, color=(28, 20, 20), strength=0.85, lower=0.6,
             margin_slack=0.0012)
## Red lips, off MPFB's own "lips" vertex group, the texture's shading kept.
LIPS = dict(lo=0.2, hi=0.8, blur=2.0, color=(128, 14, 28), strength=0.9)
## Brow and lash cards: MakeHuman's own (CC0), fitted to her face by MPFB.
## The brow strands go her brown and denser than drawn (the sheet's brows
## are full and groomed); the lashes near-black with mascara.
BROWS = "eyebrow010"
LASHES = "eyelashes02"
CARD_TEXTURES = {
    BROWS: (ROOT / "game/assets/characters/aubrey_aaa_brows.png", (72, 48, 34), 1.8),
    LASHES: (ROOT / "game/assets/characters/aubrey_aaa_lashes.png", (22, 17, 16), 1.3),
}
## Stud earrings in each lobe (the sheet's ear close-up): a small brilliant,
## 2.2 mm across the girdle, set 1 mm proud of the lobe's outer face.
STUD_RADIUS = 0.0022
STUD_PROUD = 0.001


def mpfb(module: str, name: str):
    return getattr(importlib.import_module(f"{MPFB}.{module}"), name)


def make_body(old_arm):
    """MPFB's human, shaped to her and fitted to her skeleton, weights on her
    bone names; returns (body object, {"l"/"r": (eye centre, eye forward)})."""
    HumanService = mpfb("services.humanservice", "HumanService")
    TargetService = mpfb("services.targetservice", "TargetService")
    Props = mpfb("entities.objectproperties", "HumanObjectProperties")
    human = HumanService.create_human()
    human.name = "Aubrey_Body"
    for key, value in MACROS.items():
        Props.set_value(key, value, entity_reference=human)
    TargetService.reapply_macro_details(human)
    for name, weight in sorted(FACE.items()):
        sided = TargetService.target_full_path(name) is None
        for full in ([f"l-{name}", f"r-{name}"] if sided else [name]):
            path = TargetService.target_full_path(full)
            if path is None or not pathlib.Path(path).name.startswith(full + "."):
                raise SystemExit(f"aubrey_aaa: no MPFB target {full}")
            TargetService.load_target(human, path, weight=weight, name=full)
    rig = HumanService.add_builtin_rig(human, "game_engine")
    # Pin every MPFB bone onto hers. Disconnected first: Blender ignores Copy
    # Location on a bone connected to its parent, and the first build kept
    # MPFB's own (shorter) spine -- her head 8 cm low.
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
    # Bake: shape keys (the macro targets), then the fitting pose.
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
    # The eyes, from MPFB's eye helpers, before the helpers go.
    eyes = {}
    for side in ("l", "r"):
        group = human.vertex_groups[f"helper-{side}-eye"].index
        pts = [human.matrix_world @ v.co for v in human.data.vertices
               if any(g.group == group and g.weight > 0.5 for g in v.groups)]
        centre = sum(pts, Vector()) / len(pts)
        front = min(pts, key=lambda p: p.y)          # she faces -Y
        eyes[side] = (centre, (front - centre).normalized())
    cards = make_cards(human)
    lobes = ear_lobes(human)
    # Keep only the body.
    body_group = human.vertex_groups["body"].index
    bm = bmesh.new()
    bm.from_mesh(human.data)
    deform = bm.verts.layers.deform.active
    doomed = [v for v in bm.verts if body_group not in v[deform]]
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(human.data)
    bm.free()
    paint_skin(human, eyes)
    # Weights onto her bones: rename, and drop every group that is not one
    # of her bones (MPFB's own helper and joint groups).
    for vg in list(human.vertex_groups):
        name = BONE_NAMES.get(vg.name, vg.name)
        if name in old_arm.data.bones:
            vg.name = name
        else:
            human.vertex_groups.remove(vg)
    bpy.data.objects.remove(rig, do_unlink=True)
    human.parent = old_arm
    human.matrix_parent_inverse = old_arm.matrix_world.inverted()
    arm_mod = human.modifiers.new("Armature", "ARMATURE")
    arm_mod.object = old_arm
    for card in cards:
        rigid_on_head(card, old_arm)
    return human, eyes, lobes


def world_bvh(objs):
    from mathutils.bvhtree import BVHTree
    verts, polys = [], []
    for o in objs:
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in o.data.vertices]
        polys += [[base + i for i in p.vertices] for p in o.data.polygons]
    return BVHTree.FromPolygons(verts, polys)


def conform(obj, bvh, t_min: float, t_max: float):
    """Pushes `obj` out to t_min off the surface in `bvh` and in to t_max,
    leaves what is between, smooths the corrections, enforces t_min again.
    Returns each vertex's world displacement."""
    mw = obj.matrix_world
    inv = mw.inverted()
    me = obj.data
    n = len(me.vertices)
    pos = [mw @ v.co for v in me.vertices]
    disp = [Vector() for _ in range(n)]
    for i, p in enumerate(pos):
        loc, nor, _, _ = bvh.find_nearest(p)
        if loc is None:
            continue
        d = (p - loc).dot(nor)
        if d < t_min:
            disp[i] = nor * (t_min - d)
        elif d > t_max:
            disp[i] = nor * (t_max - d)
    nbr = [[] for _ in range(n)]
    for e in me.edges:
        a, b = e.vertices
        nbr[a].append(b)
        nbr[b].append(a)
    for _ in range(GARMENT_SMOOTH):
        disp = [disp[i] * 0.5 + sum((disp[j] for j in nbr[i]), Vector()) * (0.5 / len(nbr[i]))
                if nbr[i] else disp[i] for i in range(n)]
    for i in range(n):
        p = pos[i] + disp[i]
        loc, nor, _, _ = bvh.find_nearest(p)
        if loc is not None:
            d = (p - loc).dot(nor)
            if d < t_min:
                disp[i] += nor * (t_min - d)
    for i, v in enumerate(me.vertices):
        v.co = inv @ (pos[i] + disp[i])
    me.update()
    return pos, disp


def follow(obj, anchor_pos, anchor_disp):
    """Moves `obj` with the displacement of the nearest anchor vertex."""
    from mathutils.kdtree import KDTree
    tree = KDTree(len(anchor_pos))
    for i, p in enumerate(anchor_pos):
        tree.insert(p, i)
    tree.balance()
    mw = obj.matrix_world
    inv = mw.inverted()
    for v in obj.data.vertices:
        p = mw @ v.co
        _, i, _ = tree.find(p)
        v.co = inv @ (p + anchor_disp[i])
    obj.data.update()


def take_weights(obj, body) -> None:
    """Replaces `obj`'s skin weights with the new body's, by nearest face."""
    for vg in list(obj.vertex_groups):
        obj.vertex_groups.remove(vg)
    mod = obj.modifiers.new("Weights", "DATA_TRANSFER")
    mod.object = body
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    mod.layers_vgroup_select_src = "ALL"
    mod.layers_vgroup_select_dst = "NAME"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.datalayout_transfer(modifier=mod.name)
    # Applied ahead of the armature, which must stay last.
    while obj.modifiers[0] != mod:
        bpy.ops.object.modifier_move_up(modifier=mod.name)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def refit(old_arm, body):
    objects = bpy.data.objects
    body_bvh = world_bvh([body])
    shirt_pos = shirt_disp = None
    for name, (t_min, t_max) in GARMENTS.items():
        pos, disp = conform(objects[name], body_bvh, t_min, t_max)
        if name == "Aubrey_Shirt":
            shirt_pos, shirt_disp = pos, disp
    for name in SHIRT_RIDERS:
        follow(objects[name], shirt_pos, shirt_disp)
    # The hair: the cap onto the new skull; the ponytail with the cap where
    # the tie sits.
    tie = objects[TIE]
    tie_centre = sum((tie.matrix_world @ v.co for v in tie.data.vertices), Vector()) / len(tie.data.vertices)
    cap_pos, cap_disp = conform(objects[CAP], body_bvh, CAP_OFF, CAP_OFF)
    near = [d for p, d in zip(cap_pos, cap_disp) if (p - tie_centre).length < 0.05]
    delta = sum(near, Vector()) / len(near) if near else Vector()
    for name in PONYTAIL:
        o = objects[name]
        for v in o.data.vertices:
            v.co = o.matrix_world.inverted() @ (o.matrix_world @ v.co + delta)
        o.data.update()
    bpy.context.view_layer.objects.active = old_arm
    bpy.ops.object.mode_set(mode="EDIT")
    local = old_arm.matrix_world.inverted().to_3x3() @ delta
    for name in PONYTAIL_BONES:
        eb = old_arm.data.edit_bones.get(name)
        if eb:
            eb.head += local
            eb.tail += local
    bpy.ops.object.mode_set(mode="OBJECT")
    for name in list(GARMENTS) + list(SHIRT_RIDERS):
        take_weights(objects[name], body)
    print(f"refit: ponytail moved {delta.length * 1000:.0f} mm")
    return tie_centre + delta


def cover_skin(body, cloth) -> None:
    """Deletes the body's faces that are wholly under cloth."""
    bvh = world_bvh(cloth)
    mw = body.matrix_world
    covered = []
    for v in body.data.vertices:
        p = mw @ v.co
        n = (mw.to_3x3() @ v.normal).normalized()
        hit = bvh.ray_cast(p + n * 0.001, n, COVER_REACH)[0]
        covered.append(hit is not None)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.faces.ensure_lookup_table()
    doomed = [f for f in bm.faces if all(covered[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(body.data)
    bm.free()
    print(f"cover_skin: {len(doomed)} faces under cloth removed")


def paint_strands() -> None:
    """Slick hair, strands along v: dense fine parallel strands in clumps,
    lighter caramel ones through them, a wispy fringe of loose ends at v 1
    (the hairline). RGB is the colour; alpha the coverage."""
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter
    rng = np.random.default_rng(HAIR_SEED)
    w = h = HAIR_SIZE
    base = np.zeros((h, w, 3), dtype=np.float32)
    base[:] = HAIR_BASE
    light = Image.new("L", (w, h), 0)
    dark = Image.new("L", (w, h), 0)
    alpha = Image.new("L", (w, h), 255)
    dl, dd = ImageDraw.Draw(light), ImageDraw.Draw(dark)
    for _ in range(900):
        x = rng.uniform(0, w)
        wobble = rng.uniform(0.5, 2.5)
        pts = [(x + wobble * math.sin(t * 6.0 + x), t * h) for t in np.linspace(0, 1, 40)]
        (dl if rng.random() < 0.35 else dd).line(pts, fill=int(rng.integers(60, 200)), width=1)
    light = np.asarray(light.filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float32)[..., None] / 255.0
    dark = np.asarray(dark.filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float32)[..., None] / 255.0
    rgb = base * (1.0 - 0.45 * dark) + (np.array(HAIR_LIGHT, dtype=np.float32) - base) * light * 0.8
    # The hairline fringe: the last 8% thins into separate tapering ends.
    da = ImageDraw.Draw(alpha)
    da.rectangle([0, int(h * 0.92), w, h], fill=0)
    for _ in range(1400):
        x = rng.uniform(0, w)
        end = h * rng.uniform(0.93, 1.0)
        da.line([(x, h * 0.90), (x + rng.normal(0, 1.5), end)], fill=int(rng.integers(140, 255)), width=1)
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.5))
    out = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")
    out.putalpha(alpha)
    out.save(HAIR_STRANDS, optimize=True)


def hairline(angle: float) -> float:
    a, z = zip(*HAIRLINE)
    for i in range(len(a) - 1):
        if a[i] <= angle <= a[i + 1]:
            t = (angle - a[i]) / (a[i + 1] - a[i])
            return z[i] + (z[i + 1] - z[i]) * t
    return z[-1]


def make_cap(old_arm, body, eyes, tie_centre):
    """The slicked cap, grown from the new head's scalp (see HAIRLINE)."""
    eye_z = (eyes["l"][0].z + eyes["r"][0].z) / 2.0
    centre = (eyes["l"][0] + eyes["r"][0]) / 2.0 + Vector((0.0, 0.075, 0.01))
    mw = body.matrix_world
    head = old_arm.data.bones["Head"]
    head_group = body.vertex_groups["Head"].index
    margin = {}
    for v in body.data.vertices:
        if not any(g.group == head_group and g.weight > 0.5 for g in v.groups):
            continue
        p = mw @ v.co
        r = p - centre
        angle = math.degrees(math.atan2(abs(r.x), -r.y))
        m = (p.z - eye_z) - hairline(angle)
        # The ear: a negative margin, so the cap feathers round it rather
        # than stopping on whole faces.
        if EAR_Z[0] < p.z - eye_z < EAR_Z[1]:
            m = min(m, EAR_X - abs(r.x))
        margin[v.index] = m
    faces = [f for f in body.data.polygons
             if all(i in margin for i in f.vertices) and max(margin[i] for i in f.vertices) > 0.0]
    used = sorted({i for f in faces for i in f.vertices})
    remap = {old: new for new, old in enumerate(used)}
    axis = (tie_centre - centre).normalized()
    e1 = (Vector((0.0, 0.0, 1.0)) - axis * axis.z).normalized()
    e2 = axis.cross(e1)
    verts, uvs, alpha = [], [], []
    for i in used:
        v = body.data.vertices[i]
        p = mw @ v.co
        n = (mw.to_3x3() @ v.normal).normalized()
        verts.append(p + n * CAP_OFF)
        r = (p - centre).normalized()
        phi = math.acos(max(-1.0, min(1.0, r.dot(axis))))
        az = math.atan2(r.dot(e2), r.dot(e1))
        uvs.append(((az / (2.0 * math.pi) + 0.5) * CAP_U_TILES, phi / 2.4))
        t = max(0.0, min(1.0, margin[i] / HAIRLINE_FEATHER))
        alpha.append(t * t * (3.0 - 2.0 * t))
    mesh = bpy.data.meshes.new(CAP)
    mesh.from_pydata(verts, [], [[remap[i] for i in f.vertices] for f in faces])
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        us = [uvs[mesh.loops[li].vertex_index] for li in poly.loop_indices]
        # Faces straddling the wrap of the azimuth: lift the low side.
        lift = CAP_U_TILES if max(u for u, _ in us) - min(u for u, _ in us) > CAP_U_TILES / 2 else 0.0
        for li, (u, vv) in zip(poly.loop_indices, us):
            uv.data[li].uv = (u + lift if u < CAP_U_TILES / 2 and lift else u, 1.0 - vv)
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, a in enumerate(alpha):
        col.data[i].color = (1.0, 1.0, 1.0, a)
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mat = bpy.data.materials.new("M_AubreyHair")
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(HAIR_STRANDS))
    bsdf = nt.nodes["Principled BSDF"]
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    mat.blend_method = "CLIP"
    mesh.materials.append(mat)
    cap = bpy.data.objects.new(CAP, mesh)
    bpy.context.scene.collection.objects.link(cap)
    group = cap.vertex_groups.new(name="Head")
    group.add(list(range(len(verts))), 1.0, "REPLACE")
    cap.parent = old_arm
    cap.matrix_parent_inverse = old_arm.matrix_world.inverted()
    mod = cap.modifiers.new("Armature", "ARMATURE")
    mod.object = old_arm
    print(f"make_cap: {len(faces)} faces")
    return cap


def make_collar(old_arm, body, shirt):
    """Trims the shirt's ragged neckline and builds a polo collar and a zip
    placket round her neck (see COLLAR_PROFILE)."""
    from mathutils.bvhtree import BVHTree
    trim = next(m for m in shirt.data.materials if m and m.name.startswith(TRIM_MATERIAL))
    body_bvh = world_bvh([body])
    # The neck's axis at the collar's base: rays inward, averaged.
    def neck_radius(theta, z, centre):
        d = Vector((math.sin(theta), -math.cos(theta), 0.0))
        hit = body_bvh.ray_cast(Vector((centre.x, centre.y, z)) + d * 0.3, -d, 0.3)[0]
        return (hit - Vector((centre.x, centre.y, z))).length if hit else None
    def base_z(theta):
        return COLLAR_Z - COLLAR_TILT * math.cos(theta)

    def radius(theta, centre):
        r = neck_radius(theta, base_z(theta) + COLLAR_SAMPLE_UP, centre)
        return min(r, COLLAR_MAX_R) if r else COLLAR_MAX_R

    centre = Vector((0.0, 0.0, COLLAR_Z))
    for _ in range(3):
        pts = []
        for k in range(COLLAR_STEPS):
            th = 2.0 * math.pi * k / COLLAR_STEPS
            r = radius(th, centre)
            pts.append(Vector((centre.x + math.sin(th) * r, centre.y - math.cos(th) * r, COLLAR_Z)))
        centre = sum(pts, Vector()) / len(pts)
    # Trim the shirt.
    bm = bmesh.new()
    bm.from_mesh(shirt.data)
    mw = shirt.matrix_world
    def above(p):
        rel = p.xy - centre.xy
        th = math.atan2(rel.x, -rel.y)
        return p.z > base_z(th) + COLLAR_TRIM_UP and rel.length < COLLAR_TRIM_R
    doomed = [f for f in bm.faces if any(above(mw @ v.co) for v in f.verts)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(shirt.data)
    bm.free()
    # The collar. Its flap rests ON the shirt: at the back the shirt sits
    # further out over her trapezius than a neck-hugging flap, which ended
    # up inside it.
    shirt_bvh = world_bvh([shirt])

    def shirt_r(theta, z):
        d = Vector((math.sin(theta), -math.cos(theta), 0.0))
        o = Vector((centre.x, centre.y, z))
        hit = shirt_bvh.ray_cast(o + d * 0.3, -d, 0.3)[0]
        return (hit - o).length if hit else 0.0
    gap = math.radians(COLLAR_GAP)
    thetas = [gap + (2.0 * math.pi - 2.0 * gap) * k / (COLLAR_STEPS - 1) for k in range(COLLAR_STEPS)]
    verts, faces = [], []
    for k, th in enumerate(thetas):
        r = radius(th, centre)
        d = Vector((math.sin(th), -math.cos(th), 0.0))
        z0 = base_z(th)
        # The points: the flap's front ends drop.
        edge = 1.0 - min(1.0, min(th - gap, 2.0 * math.pi - gap - th) / math.radians(30.0))
        for j, (h, off) in enumerate(COLLAR_PROFILE):
            drop = COLLAR_POINT_DROP * edge * (j / (len(COLLAR_PROFILE) - 1)) if j >= 4 else 0.0
            z = z0 + h - drop
            if j < 4:
                # The stand hugs the neck at its own height: one radius for
                # the whole band put it inside the skin where the neck
                # flares into the trapezius at the back.
                reach = (neck_radius(th, z, centre) or r) + off
            else:
                # 5 mm proud: at 3 the shirt's stripes flickered through.
                reach = max(r + off, shirt_r(th, z) + 0.005)
            verts.append(Vector((centre.x, centre.y, z0 + h - drop)) + d * reach)
    rows = len(COLLAR_PROFILE)
    for k in range(COLLAR_STEPS - 1):
        for j in range(rows - 1):
            a = k * rows + j
            faces.append((a, a + rows, a + rows + 1, a + 1))
    # The placket: a strip down the front of the shirt, just proud of it.
    top = base_z(0.0) + 0.030
    z = top
    strip = []
    while z >= PLACKET_BOTTOM:
        row = []
        for x in (-PLACKET_HALF_W, PLACKET_HALF_W):
            hit, nor, _, _ = shirt_bvh.ray_cast(Vector((centre.x + x, -0.5, z)), Vector((0.0, 1.0, 0.0)), 1.0)
            row.append(hit + nor * 0.002 if hit else Vector((centre.x + x, centre.y - 0.07, z)))
        strip.append(row)
        z -= 0.01
    base = len(verts)
    for row in strip:
        verts += row
    for i in range(len(strip) - 1):
        a = base + 2 * i
        faces.append((a, a + 1, a + 3, a + 2))
    mesh = bpy.data.meshes.new("Aubrey_Collar")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.uv_layers.new(name="UVMap")
    mesh.materials.append(trim)
    collar = bpy.data.objects.new("Aubrey_Collar", mesh)
    bpy.context.scene.collection.objects.link(collar)
    collar.parent = old_arm
    collar.matrix_parent_inverse = old_arm.matrix_world.inverted()
    mod = collar.modifiers.new("Armature", "ARMATURE")
    mod.object = old_arm
    take_weights(collar, body)
    print(f"make_collar: neck at {tuple(round(c, 3) for c in centre)}, {len(faces)} faces")
    return collar


def make_eyes(old_arm, eyes):
    """Both eyeballs in one mesh (Aubrey_Eyes), front-projected UVs centred on
    each line of sight, rigid on her Head bone. The spheres are written out
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
    mesh = bpy.data.meshes.new("Aubrey_Eyes")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        layer.data[loop.index].uv = uvs[loop.vertex_index]
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.materials.append(image_material("MI_AubreyEyes", EYE_COLOR, roughness=0.05))
    mesh.update()
    eye = bpy.data.objects.new("Aubrey_Eyes", mesh)
    bpy.context.scene.collection.objects.link(eye)
    group = eye.vertex_groups.new(name="Head")
    group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
    eye.parent = old_arm
    eye.matrix_parent_inverse = old_arm.matrix_world.inverted()
    mod = eye.modifiers.new("Armature", "ARMATURE")
    mod.object = old_arm
    return [eye]


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


def make_cards(human):
    """MakeHuman's brow and lash cards fitted to her face (MPFB fits them to
    the basemesh as it stands, so after the targets and the fitting pose),
    their strand textures recoloured; returns the two objects."""
    import numpy as np
    from PIL import Image
    HumanService = mpfb("services.humanservice", "HumanService")
    cards = []
    for kind, name, obj_name in (("eyebrows", BROWS, "Aubrey_Brows"),
                                 ("eyelashes", LASHES, "Aubrey_Lashes")):
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
        mat_name = "M_AubreyBrows" if kind == "eyebrows" else "M_AubreyLashes"
        obj.data.materials.append(image_material(mat_name, out, roughness=0.6, alpha=True))
        for poly in obj.data.polygons:
            poly.use_smooth = True
        cards.append(obj)
    # MPFB adds a delete group per card to the basemesh; it masks nothing here.
    for vg in list(human.vertex_groups):
        if vg.name.startswith("Delete."):
            human.vertex_groups.remove(vg)
    return cards


def ear_lobes(human):
    """Each earlobe's outer face, from MPFB's "ears" group: the lowest
    centimetre of each ear, its outermost point there; ({"l"/"r": point},
    outward normal)."""
    group = human.vertex_groups["ears"].index
    lobes = {}
    for side, sign in (("l", 1.0), ("r", -1.0)):
        pts = [human.matrix_world @ v.co for v in human.data.vertices
               if v.co.x * sign > 0 and any(g.group == group and g.weight > 0.5 for g in v.groups)]
        bottom = min(p.z for p in pts)
        low = [p for p in pts if p.z < bottom + 0.006]
        outer = max(low, key=lambda p: p.x * sign)
        centre = sum(low, Vector()) / len(low)
        lobes[side] = (Vector((outer.x, centre.y, bottom + 0.004)), Vector((sign, 0.0, 0.0)))
    return lobes


def make_studs(old_arm, lobes):
    """A small brilliant in each lobe: an eight-sided crown and pavilion,
    written out vertex by vertex (deterministic), facing outward."""
    import math
    verts, faces = [], []
    n = 8
    for side in ("l", "r"):
        point, normal = lobes[side]
        centre = point + normal * STUD_PROUD
        base = len(verts)
        up = Vector((0.0, 0.0, 1.0))
        side_axis = normal.cross(up).normalized()
        r = STUD_RADIUS
        verts.append(centre + normal * r * 0.55)                 # table centre
        for k in range(n):                                         # table ring
            a = 2.0 * math.pi * k / n
            verts.append(centre + normal * r * 0.55
                         + (up * math.cos(a) + side_axis * math.sin(a)) * r * 0.55)
        for k in range(n):                                         # girdle
            a = 2.0 * math.pi * (k + 0.5) / n
            verts.append(centre + (up * math.cos(a) + side_axis * math.sin(a)) * r)
        verts.append(centre - normal * r * 0.7)                   # culet
        table = lambda k: base + 1 + k % n
        girdle = lambda k: base + 1 + n + k % n
        for k in range(n):
            faces.append((base, table(k), table(k + 1)))
            faces.append((table(k), girdle(k), table(k + 1)))
            faces.append((table(k + 1), girdle(k), girdle(k + 1)))
            faces.append((girdle(k), base + 1 + 2 * n, girdle(k + 1)))
    mesh = bpy.data.meshes.new("Aubrey_Studs")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mat = bpy.data.materials.new("M_Stud")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.92, 0.93, 0.96, 1.0)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.08
    mesh.materials.append(mat)
    mesh.update()
    stud = bpy.data.objects.new("Aubrey_Studs", mesh)
    bpy.context.scene.collection.objects.link(stud)
    rigid_on_head(stud, old_arm)
    return stud


def _smooth(a, b, x):
    import numpy as np
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def position_map(body, size: int, z_min: float):
    """Her head rasterised into UV space: for every texel, the point on her it
    covers (world, metres), its "lips" weight, and whether it is covered."""
    import numpy as np
    mesh = body.data
    pos = np.zeros((size, size, 3), np.float32)
    lips = np.zeros((size, size), np.float32)
    hit = np.zeros((size, size), bool)
    uvs = mesh.uv_layers["UVMap"].data
    co = np.array([body.matrix_world @ v.co for v in mesh.vertices], np.float32)
    lip_group = body.vertex_groups["lips"].index
    lip_w = np.zeros(len(co), np.float32)
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
    """Her skin texture: the graded CC0 skin with her make-up painted on
    (SMOKE, LINER, LIPS), written to SKIN_OUT and put on the body."""
    import numpy as np
    from PIL import Image, ImageFilter
    base = np.asarray(Image.open(SKIN_SOURCE).convert("RGB"), np.float32) * np.array(SKIN_GRADE, np.float32)
    size = base.shape[0]
    z_min = min(c.z for c, _ in eyes.values()) - 0.20
    pos, lips, hit = position_map(body, size, z_min)
    lum = base.mean(-1)
    smoke = np.zeros(lum.shape, np.float32)
    liner = np.zeros(lum.shape, np.float32)
    verts = [body.matrix_world @ v.co for v in body.data.vertices]
    for side in ("l", "r"):
        centre, forward = eyes[side]
        up = Vector((0.0, 0.0, 1.0))
        up = (up - forward * up.dot(forward)).normalized()
        out = up.cross(forward)
        if out.x * centre.x < 0:
            out = -out
        c, f, u_ax, o_ax = (np.array(tuple(x), np.float32) for x in (centre, forward, up, out))
        d = pos - c
        u = d @ o_ax * 1000.0 - SMOKE["shift"]
        v = d @ u_ax * 1000.0
        w = d @ f * 1000.0
        a = np.where(u > 0, SMOKE["a_out"], SMOKE["a_in"])
        b = np.where(v > 0, SMOKE["b_up"], SMOKE["b_down"])
        shade = (1.0 - _smooth(SMOKE["e0"], SMOKE["e1"], np.sqrt((u / a) ** 2 + (v / b) ** 2)))
        shade *= (w > -2.0) * hit * np.where(v < 0, SMOKE["lower"], 1.0)
        smoke = np.maximum(smoke, shade)
        margin = np.array([tuple(p) for p in verts
                           if (p - centre).length < EYE_RADIUS + LINER["margin_slack"]
                           and (p - centre).dot(forward) > 0.3 * EYE_RADIUS], np.float32)
        flat = pos.reshape(-1, 3)
        dist = np.full(len(flat), 1e9, np.float32)
        for p in margin:
            dist = np.minimum(dist, np.linalg.norm(flat - p, axis=1))
        dist = dist.reshape(lum.shape) * 1000.0
        line = (1.0 - _smooth(LINER["near"], LINER["far"], dist)) * hit * (np.abs(u) < 20.0)
        liner = np.maximum(liner, line * np.where(v < 0, LINER["lower"], 1.0))
    img = base.copy()
    k = (smoke * SMOKE["strength"])[..., None]
    tone = (lum / lum[hit].mean())[..., None] ** 0.5
    img = img * (1.0 - k) + np.array(SMOKE["color"], np.float32) * tone * k
    k = (liner * LINER["strength"])[..., None]
    img = img * (1.0 - k) + np.array(LINER["color"], np.float32) * k
    mask = Image.fromarray(np.round(_smooth(LIPS["lo"], LIPS["hi"], lips) * 255).astype(np.uint8))
    lip = np.asarray(mask.filter(ImageFilter.GaussianBlur(LIPS["blur"])), np.float32) / 255.0
    lip_tone = (lum / np.median(lum[lip > 0.9]))[..., None] ** 0.7
    k = (lip * LIPS["strength"])[..., None]
    img = img * (1.0 - k) + np.array(LIPS["color"], np.float32) * lip_tone * k
    Image.fromarray(np.clip(np.round(img), 0, 255).astype(np.uint8), "RGB").save(
        SKIN_OUT, quality=SKIN_QUALITY, optimize=True)
    body.data.materials.clear()
    body.data.materials.append(image_material("M_AubreySkin", SKIN_OUT, roughness=0.5))


def main() -> int:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    addon_utils.enable(MPFB, default_set=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    old_arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for name in ("Aubrey_Body", "Eyes", "Eyebrows"):
        if name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    body, eyes, lobes = make_body(old_arm)
    make_eyes(old_arm, eyes)
    make_studs(old_arm, lobes)
    tie_centre = refit(old_arm, body)
    collar = make_collar(old_arm, body, bpy.data.objects["Aubrey_Shirt"])
    # The skin under the cloth goes last, once the collar has trimmed the
    # shirt: deleted first, the trim opened holes onto nothing.
    # Not the collar: rays up from under her jaw met it, and the skin there
    # was deleted -- black slivers under the chin.
    cover_skin(body, [bpy.data.objects[n] for n in GARMENTS])
    bpy.data.objects.remove(bpy.data.objects[CAP], do_unlink=True)
    paint_strands()
    make_cap(old_arm, body, eyes, tie_centre)
    for o in bpy.context.scene.objects:
        o.select_set(o == old_arm or o.parent == old_arm)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                              export_yup=True, export_animations=False, export_skins=True,
                              export_apply=False, export_image_format="AUTO",
                              # The hair cap's feather is in its vertex alpha;
                              # by default only colours a material uses go out.
                              export_vertex_color="ACTIVE")
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"aubrey_aaa: body {tris} triangles -> {OUT}")
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main())
