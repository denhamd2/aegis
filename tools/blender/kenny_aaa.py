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
    "measure-shoulder-dist-incr": 0.4,
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
FACE: dict[str, float] = {}
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


def mpfb(module: str, name: str):
    return getattr(importlib.import_module(f"{MPFB}.{module}"), name)


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
    body_group = human.vertex_groups["body"].index
    bm = bmesh.new()
    bm.from_mesh(human.data)
    deform = bm.verts.layers.deform.active
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if body_group not in v[deform]],
                     context="VERTS")
    bm.to_mesh(human.data)
    bm.free()
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
    # A plain skin tone until stage 4 paints his skin, so the forms read.
    skin = bpy.data.materials.new("M_KennySkin")
    skin.use_nodes = True
    bsdf = skin.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.62, 0.40, 0.30, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.5
    body.data.materials.clear()
    body.data.materials.append(skin)
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
