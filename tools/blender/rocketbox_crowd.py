#!/usr/bin/env python3
"""Real people for the crowd: Microsoft Rocketbox avatars, posed and baked.

Imported by `crowd.py` (the bowl, via `arena_bowl.py`) and by
`floor_crowd.py` (the ringside chairs). It has no `main` of its own.

What this does
--------------
The crowd used to be procedural: tubes and ellipsoids in the shape of a
seated person (`crowd.py`'s `Figure`). This replaces the figures with real
people from the Microsoft Rocketbox library (MIT; see
`game/assets/environment/CREDITS.md`), turned into something a crowd of six
thousand can afford:

  1. Each avatar's FBX is imported with its skeleton (the 3ds Max "Bip01"
     biped every Rocketbox avatar and animation shares).
  2. Its three colour textures (body, head, hair cards) are BAKED INTO
     VERTEX COLOUR at full resolution, before anything is thrown away -- the
     crowd shader (`arena_builder.gd`, `_crowd_material`) reads COLOR, not a
     texture, and six thousand people cannot each carry 3 x 2048^2 textures.
     Hair-card faces that are mostly transparent are dropped; the hair is
     also painted on the scalp, which is what survives at crowd distance.
  3. The upper garment is found from the skin weights (spine, clavicle and
     upper-arm bones, minus anything that is skin-coloured) and stored as a
     MASK with its own fold shading, so `crowd.py` can re-dress every figure
     in a wrestling-crowd tee -- mostly black, some merch colours, some with
     a lighter print on the chest -- without a mesh per shirt.
  4. The mesh is decimated to a level of detail (collapse, which carries the
     baked colour and the skin weights through), then posed from frames of
     Rocketbox's own motion-capture animations: sitting (the `sit_chair`
     clips), and on top of a seated lower body, the upper body of a clap, a
     cheer or somebody taking a picture; standing versions of the same.
  5. The posed, decimated mesh is returned as plain arrays in metres, in the
     GAME's frame (+Y up, facing +Z), with the seat point at the origin.

Nothing here touches the network or the repo's assets: it reads a local
Rocketbox checkout (`fetch_rocketbox.sh` makes one, pinned to a commit) and
hands numbers back. The same checkout and the same tables produce the same
numbers, so the .glb files built from them are byte-identical run to run.
"""

from __future__ import annotations

import math
import os
import pathlib

import bpy  # noqa: I001
import numpy as np
from mathutils import Matrix, Vector

## The commit `fetch_rocketbox.sh` checks out. Recorded in CREDITS.md too.
ROCKETBOX_COMMIT = "0943055db6ec570bcef9f2c8b41c9e5467c808f9"
ROCKETBOX_URL = "https://github.com/microsoft/Microsoft-Rocketbox"


def rocketbox_root() -> pathlib.Path:
    root = pathlib.Path(os.environ.get(
        "ROCKETBOX_DIR", "/tmp/claude-0/rb/repo")).expanduser()
    if not (root / "Assets" / "Avatars" / "Adults").is_dir():
        raise SystemExit(
            "rocketbox_crowd.py: no Rocketbox checkout at %s. Run "
            "tools/blender/fetch_rocketbox.sh (or set ROCKETBOX_DIR)." % root)
    return root


## The people. Twenty adults: thirteen men, seven women, casual clothes --
## the Rocketbox adults in suits, robes or full-length coverings were left
## out because a wrestling crowd is jeans and tees. Order matters (it is the
## index the placement RNG draws), so append, never insert.
AVATARS = (
    "Male_Adult_01", "Male_Adult_04", "Male_Adult_06", "Male_Adult_07",
    "Male_Adult_09", "Male_Adult_10", "Male_Adult_11", "Male_Adult_12",
    "Male_Adult_14", "Male_Adult_16", "Male_Adult_17", "Male_Adult_18",
    "Male_Adult_20",
    "Female_Adult_03", "Female_Adult_07", "Female_Adult_08", "Female_Adult_12",
    "Female_Adult_13", "Female_Adult_17", "Female_Party_02",
)

## The Rocketbox clips used, without their m_/f_ gender prefix. The whole
## list `fetch_rocketbox.sh` pulls; each is read at a single frame.
CLIPS = (
    "sit_chair_idle_neutral_01", "sit_chair_idle_relaxed_01",
    "sit_chair_breathe_01", "claphands_01", "cheer_01", "take_picture",
    "idle_neutral_01",
)

## Roles, as crowd.py and the shader know them (UV.y).
ROLE_SIT, ROLE_CLAP, ROLE_WAVE, ROLE_JUMP = 0.0, 0.25, 0.5, 0.75

## The poses: (name, lower-body clip, upper-body clip, how to pick the frame,
## seated, role, prop). The upper body is the clip's spine-and-up taken
## RELATIVE TO ITS PELVIS and put on the lower clip's pelvis, which is how a
## standing clap becomes a seated one. Frame pickers are deterministic: a
## fixed fraction of the clip, or the frame where the hands are highest /
## closest together.
POSES = (
    ("sit_a", "sit_chair_idle_neutral_01", None, 0.30, True, ROLE_SIT, None),
    ("sit_b", "sit_chair_idle_relaxed_01", None, 0.55, True, ROLE_SIT, None),
    ("sit_c", "sit_chair_breathe_01", None, 0.15, True, ROLE_SIT, None),
    ("sit_clap", "sit_chair_idle_neutral_01", "claphands_01", "hands_close", True, ROLE_CLAP, None),
    ("sit_cheer", "sit_chair_idle_neutral_01", "cheer_01", "hands_high", True, ROLE_WAVE, None),
    ("sit_phone", "sit_chair_idle_neutral_01", "take_picture", "hands_high", True, ROLE_SIT, "phone"),
    ("sit_sign", "sit_chair_idle_neutral_01", "cheer_01", "hands_high", True, ROLE_WAVE, "sign"),
    ("stand", "idle_neutral_01", None, 0.25, False, ROLE_JUMP, None),
    ("stand_clap", "idle_neutral_01", "claphands_01", "hands_close", False, ROLE_JUMP, None),
    ("stand_cheer", "idle_neutral_01", "cheer_01", "hands_high", False, ROLE_JUMP, None),
    ("stand_phone", "idle_neutral_01", "take_picture", "hands_high", False, ROLE_JUMP, "phone"),
    ("stand_sign", "idle_neutral_01", "cheer_01", "hands_high", False, ROLE_JUMP, "sign"),
)
POSE_NAMES = tuple(p[0] for p in POSES)

UPPER_ROOT = "Bip01 Spine"
## Bones whose skin is the upper garment.
SHIRT_BONES = ("Bip01 Spine", "Bip01 Spine1", "Bip01 Spine2",
               "Bip01 L Clavicle", "Bip01 R Clavicle",
               "Bip01 L UpperArm", "Bip01 R UpperArm")
## Bones that are face, for the avatar's own skin tone.
FACE_BONES = ("Bip01 MNose", "Bip01 RCheek", "Bip01 LCheek",
              "Bip01 MMiddleEyebrow")
## Inside-the-mouth bones: their faces are never seen and are dropped.
HIDDEN_BONES = ("Bip01 MTongue",)


# ---------------------------------------------------------------------------
# Textures
# ---------------------------------------------------------------------------

_TEX_CACHE: dict = {}


## The level the textures are baked at. Rocketbox's colour maps are
## photo-sourced and carry their studio's light: taken at face value the
## stands measured top-of-frame linear luminance 0.059 on the gameplay camera
## against 0.034 for the procedural crowd they replace and 0.024-0.034 on the
## owner's 2K26 frames (cody_roman_2k26.md). The tees come from crowd.py's
## palette and are not scaled by this.
TEXTURE_LEVEL = 0.45


def _texture(path: pathlib.Path, size: int = 512) -> np.ndarray:
    """A colour texture as linear float RGBA, box-filtered down to `size`.

    Box-filtered because a vertex samples one point of a 2048 map, and at
    crowd distances what it should carry is the average of the patch of cloth
    it stands for, not one thread of denim."""
    key = (str(path), size)
    if key not in _TEX_CACHE:
        from PIL import Image
        im = Image.open(path).convert("RGBA")
        im = im.resize((size, size), Image.Resampling.BOX)
        a = np.asarray(im, dtype=np.float64) / 255.0
        rgb = a[..., :3]
        lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
        _TEX_CACHE[key] = np.concatenate([lin * TEXTURE_LEVEL, a[..., 3:]], axis=-1)
    return _TEX_CACHE[key]


def _sample(tex: np.ndarray, uv: np.ndarray) -> np.ndarray:
    """Bilinear lookup of `tex` at UVs (n, 2); V up, wrapped."""
    h, w = tex.shape[:2]
    x = (uv[:, 0] % 1.0) * w - 0.5
    y = (1.0 - (uv[:, 1] % 1.0)) * h - 0.5
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx = (x - x0)[:, None]
    fy = (y - y0)[:, None]
    x0 %= w
    y0 %= h
    x1 = (x0 + 1) % w
    y1 = (y0 + 1) % h
    return ((tex[y0, x0] * (1 - fx) + tex[y0, x1] * fx) * (1 - fy)
            + (tex[y1, x0] * (1 - fx) + tex[y1, x1] * fx) * fy)


# ---------------------------------------------------------------------------
# Import, bake, pose
# ---------------------------------------------------------------------------

def _import_fbx(path: pathlib.Path) -> list:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(path))
    return [o for o in bpy.data.objects if o not in before]


def _gender(avatar: str) -> str:
    return "f" if avatar.startswith("Female") else "m"


_CLIP_CACHE: dict = {}


def _clip_armature(name: str):
    """The armature of a Rocketbox clip, imported once and kept hidden."""
    if name not in _CLIP_CACHE:
        path = (rocketbox_root() / "Assets" / "Animations"
                / "all_animations_max_motextr_static" / (name + ".max.fbx"))
        objs = _import_fbx(path)
        arm = next(o for o in objs if o.type == "ARMATURE")
        start, end = (int(v) for v in arm.animation_data.action.frame_range)
        _CLIP_CACHE[name] = (arm, start, end)
    return _CLIP_CACHE[name]


def _bone_world(arm, frame: int) -> dict:
    bpy.context.scene.frame_set(frame)
    world = arm.matrix_world
    return {pb.name: world @ pb.matrix for pb in arm.pose.bones}


def _pick_frame(arm, start: int, end: int, rule) -> int:
    """A deterministic frame of the clip: a fraction of its length, or the
    frame (of 24 evenly spaced) where the hands are highest / closest."""
    if isinstance(rule, float):
        return start + int(round((end - start) * rule))
    best, best_score = start, -math.inf
    for k in range(24):
        f = start + int(round((end - start) * (k + 0.5) / 24.0))
        bones = _bone_world(arm, f)
        lh = bones["Bip01 L Hand"].translation
        rh = bones["Bip01 R Hand"].translation
        head = bones["Bip01 Head"].translation
        if rule == "hands_high":
            score = min(lh.z, rh.z) - head.z
        else:  # hands_close, and in front of the chest
            score = -(lh - rh).length + 0.2 * min(lh.z, rh.z)
        if score > best_score + 1e-9:
            best, best_score = f, score
    return best


def _descendants(arm, root: str) -> set:
    bone = arm.data.bones[root]
    return {root} | {b.name for b in bone.children_recursive}


def _upper_body(arm) -> set:
    """Spine and everything above it. In a 3ds Max biped the THIGHS are
    children of the spine, not of the pelvis, so they are taken back out --
    without that a seated clap comes out standing."""
    legs = (_descendants(arm, "Bip01 L Thigh")
            | _descendants(arm, "Bip01 R Thigh"))
    return _descendants(arm, UPPER_ROOT) - legs


_SOURCE_CACHE: dict = {}


def _pose_source(lower: str, upper: str | None, rule) -> dict:
    """World matrices of every bone for a pose, read off the clip(s) once."""
    key = (lower, upper, rule)
    if key in _SOURCE_CACHE:
        return _SOURCE_CACHE[key]
    low_arm, ls, le = _clip_armature(lower)
    if upper is None:
        frame = _pick_frame(low_arm, ls, le, rule)
        src = _bone_world(low_arm, frame)
    else:
        up_arm, us, ue = _clip_armature(upper)
        src = _bone_world(low_arm, ls + int(round((le - ls) * 0.3)))
        up = _bone_world(up_arm, _pick_frame(up_arm, us, ue, rule))
        anchor = src["Bip01 Pelvis"] @ up["Bip01 Pelvis"].inverted()
        for name in sorted(_upper_body(up_arm)):
            if name in up:
                src[name] = anchor @ up[name]
    _SOURCE_CACHE[key] = src
    return src


def _apply_pose(avatar_arm, lower: str, upper: str | None, rule) -> None:
    """Pose `avatar_arm` from a frame of `lower` (and `upper` above the
    spine). Rotations are copied in world space -- every Rocketbox skeleton
    is the same biped with the same bone axes -- and positions are left to
    the avatar's own bone lengths, except the pelvis, which takes the clip's."""
    src = _pose_source(lower, upper, rule)
    world_inv = avatar_arm.matrix_world.inverted()
    pose = avatar_arm.pose
    for pb in pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    by_depth: dict[int, list] = {}
    for pb in pose.bones:
        depth = len(pb.parent_recursive)
        by_depth.setdefault(depth, []).append(pb)
    for depth in sorted(by_depth):
        for pb in by_depth[depth]:
            if pb.name not in src:
                continue
            target = world_inv @ src[pb.name]
            rot = target.to_quaternion()
            loc = target.translation if pb.parent is None else pb.head.copy()
            pb.matrix = Matrix.LocRotScale(loc, rot, None)
        bpy.context.view_layer.update()


def _clean_triangles(tris: np.ndarray) -> np.ndarray:
    """Drop degenerate triangles and all but the first of any set sharing the
    same three vertices. Collapse decimation leaves both behind where a thin
    sheet folds onto itself, and Blender's mesh validation then removes one
    of a duplicate pair in an order that is not stable run to run -- which
    flipped a handful of triangles' winding between two otherwise identical
    builds of the bowl."""
    ok = (tris[:, 0] != tris[:, 1]) & (tris[:, 1] != tris[:, 2]) & \
        (tris[:, 0] != tris[:, 2])
    tris = tris[ok]
    key = np.sort(tris, axis=1)
    _, first = np.unique(key, axis=0, return_index=True)
    return tris[np.sort(first)]


class Avatar:
    """One Rocketbox avatar in the scene, its colours baked, ready to pose."""

    def __init__(self, name: str) -> None:
        self.name = name
        folder = rocketbox_root() / "Assets" / "Avatars" / "Adults" / name
        objs = _import_fbx(folder / "Export" / (name + ".fbx"))
        self.arm = next(o for o in objs if o.type == "ARMATURE")
        self.mesh_obj = next(o for o in objs if o.type == "MESH")
        for o in objs:
            if o.type not in ("ARMATURE", "MESH"):
                bpy.data.objects.remove(o)
        textures = {}
        for path in sorted((folder / "Textures").glob("*_color.tga")):
            kind = path.stem.split("_")[1]  # body / head / opacity
            textures[kind] = _texture(path)
        self._bake(textures)

    def _bake(self, textures: dict) -> None:
        """Texture colour into a point colour attribute, plus the shirt mask
        and its shading, then drop the faces nobody sees."""
        me = self.mesh_obj.data
        nv = len(me.vertices)
        nl = len(me.loops)
        uv = np.empty(nl * 2)
        me.uv_layers.active.data.foreach_get("uv", uv)
        uv = uv.reshape(-1, 2)
        loop_vert = np.empty(nl, dtype=np.int64)
        me.loops.foreach_get("vertex_index", loop_vert)
        loop_poly = np.empty(nl, dtype=np.int64)
        poly_start = np.empty(len(me.polygons), dtype=np.int64)
        poly_total = np.empty(len(me.polygons), dtype=np.int64)
        me.polygons.foreach_get("loop_start", poly_start)
        me.polygons.foreach_get("loop_total", poly_total)
        for i, (s, t) in enumerate(zip(poly_start, poly_total)):
            loop_poly[s:s + t] = i
        poly_mat = np.empty(len(me.polygons), dtype=np.int64)
        me.polygons.foreach_get("material_index", poly_mat)
        kinds = [m.name.split("_")[-1] if m else "body" for m in me.materials]

        loop_rgba = np.zeros((nl, 4))
        for mi, kind in enumerate(kinds):
            tex = textures[kind] if kind in textures else textures["body"]
            sel = poly_mat[loop_poly] == mi
            loop_rgba[sel] = _sample(tex, uv[sel])

        # Hair cards: a face whose loops are mostly transparent is dropped.
        drop = np.zeros(len(me.polygons), dtype=bool)
        if "opacity" in kinds:
            mi = kinds.index("opacity")
            alpha = np.bincount(loop_poly, weights=loop_rgba[:, 3],
                                minlength=len(me.polygons)) / poly_total
            drop |= (poly_mat == mi) & (alpha < 0.45)

        colour = np.zeros((nv, 3))
        weight = np.zeros(nv)
        keep_loop = ~drop[loop_poly]
        w = np.where(keep_loop, 1.0, 1e-6)
        np.add.at(colour, loop_vert, loop_rgba[:, :3] * w[:, None])
        np.add.at(weight, loop_vert, w)
        colour /= np.maximum(weight, 1e-9)[:, None]

        # Dominant bone per vertex, from the skin weights.
        groups = {g.index: g.name for g in self.mesh_obj.vertex_groups}
        dominant = []
        for v in me.vertices:
            best = max(v.groups, key=lambda g: g.weight, default=None)
            dominant.append(groups[best.group] if best else "")
        dominant = np.array(dominant)

        vert_body = np.zeros(nv, dtype=bool)
        if "body" in kinds:
            bi = kinds.index("body")
            vert_body[loop_vert[poly_mat[loop_poly] == bi]] = True

        face = np.isin(dominant, FACE_BONES)
        skin = np.median(colour[face], axis=0) if face.any() else np.array([0.3, 0.2, 0.15])
        self.skin = skin
        # Skin-coloured: close to the face's tone in chromaticity and level.
        lum = colour @ np.array([0.2126, 0.7152, 0.0722])
        slum = float(skin @ np.array([0.2126, 0.7152, 0.0722]))
        chroma = colour / np.maximum(colour.sum(1, keepdims=True), 1e-6)
        schroma = skin / max(skin.sum(), 1e-6)
        skinlike = (np.abs(chroma - schroma).sum(1) < 0.09) & \
            (lum > slum * 0.45) & (lum < slum * 1.9)
        shirt = vert_body & np.isin(dominant, SHIRT_BONES) & ~skinlike
        # Fold shading: the shirt's own value against its median, softened.
        med = float(np.median(lum[shirt])) if shirt.any() else 1.0
        fold = np.clip((lum / max(med, 1e-4)) ** 0.5, 0.6, 1.45)

        # Rest-pose chest front, for a print: in the armature's frame the
        # avatar faces -Y (Rocketbox / 3ds Max), +Z up.
        co = np.empty(nv * 3)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        world = np.array(self.mesh_obj.matrix_world)
        wco = co @ world[:3, :3].T + world[:3, 3]
        nrm = np.empty(nv * 3)
        me.vertices.foreach_get("normal", nrm)
        nrm = nrm.reshape(-1, 3) @ world[:3, :3].T
        nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)
        spine2 = self._bone_head("Bip01 Spine2")
        spine = self._bone_head("Bip01 Spine")
        front_axis = self._front()
        facing = nrm @ front_axis > 0.35
        height = (wco[:, 2] - spine.z) / max(spine2.z - spine.z, 1e-3)
        lateral = wco - np.array(spine2)
        side = np.cross(front_axis, np.array([0.0, 0.0, 1.0]))
        across = np.abs(lateral @ side)
        chest = shirt & facing & (height > 0.75) & (height < 1.25) & (across < 0.075)

        # Store: colour as a point attribute; mask/fold/print in a second.
        attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        rgba = np.concatenate([colour, np.ones((nv, 1))], axis=1)
        attr.data.foreach_set("color", rgba.ravel())
        info = me.color_attributes.new("Info", "FLOAT_COLOR", "POINT")
        data = np.stack([shirt.astype(float), fold, chest.astype(float),
                         np.ones(nv)], axis=1)
        info.data.foreach_set("color", data.ravel())
        me.color_attributes.active_color = attr

        hidden = np.isin(dominant, HIDDEN_BONES)
        poly_hidden = np.zeros(len(me.polygons), dtype=bool)
        np.logical_or.at(poly_hidden, loop_poly, hidden[loop_vert])
        drop |= poly_hidden
        if drop.any():
            import bmesh
            bm = bmesh.new()
            bm.from_mesh(me)
            bm.faces.ensure_lookup_table()
            bmesh.ops.delete(bm, geom=[bm.faces[i] for i in np.nonzero(drop)[0]],
                             context="FACES")
            loose = [v for v in bm.verts if not v.link_faces]
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
            bm.to_mesh(me)
            bm.free()
        self.full_tris = sum(len(p.vertices) - 2 for p in me.polygons)
        # The surviving hair cards, as a vertex group a Mask modifier can
        # drop: a decimated card is a shard floating off the scalp, so only
        # the ringside level of detail keeps them.
        if "opacity" in kinds:
            mi = kinds.index("opacity")
            cards = sorted({v for p in me.polygons if p.material_index == mi
                            for v in p.vertices})
            if cards:
                group = self.mesh_obj.vertex_groups.new(name="HairCards")
                group.add(cards, 1.0, "REPLACE")
                self.card_tris = sum(len(p.vertices) - 2 for p in me.polygons
                                     if p.material_index == mi)
        self.card_tris = getattr(self, "card_tris", 0)

    def _bone_head(self, name: str) -> Vector:
        return self.arm.matrix_world @ self.arm.data.bones[name].head_local

    def _front(self) -> np.ndarray:
        """Which way the avatar faces in Blender's world, from its nose."""
        nose = self._bone_head("Bip01 MNose")
        head = self._bone_head("Bip01 Head")
        d = np.array(nose - head)
        d[2] = 0.0
        return d / max(np.linalg.norm(d), 1e-9)

    def pose(self, pose: str) -> None:
        """Put the avatar in `pose` (one of POSE_NAMES)."""
        spec = POSES[POSE_NAMES.index(pose)]
        _, lower, upper, rule = spec[:4]
        g = _gender(self.name)
        _apply_pose(self.arm, "%s_%s" % (g, lower),
                    None if upper is None else "%s_%s" % (g, upper), rule)
        self.current = spec

    def extract(self, target_tris: int, cards: bool) -> dict:
        """The posed avatar decimated to ~`target_tris`, as arrays in the
        GAME frame, metres, facing +Z, seat point at the origin."""
        name, _, _, _, seated, role, prop = self.current
        pose = name
        obj = self.mesh_obj
        for m in list(obj.modifiers):
            if m.type in ("DECIMATE", "MASK"):
                obj.modifiers.remove(m)
        budget = self.full_tris
        masked = False
        if not cards and self.card_tris:
            mask = obj.modifiers.new("NoCards", "MASK")
            mask.vertex_group = "HairCards"
            mask.invert_vertex_group = True
            obj.modifiers.move(obj.modifiers.find(mask.name), 0)
            budget -= self.card_tris
            masked = True
        dec = obj.modifiers.new("Decimate", "DECIMATE")
        dec.decimate_type = "COLLAPSE"
        dec.ratio = min(1.0, target_tris / max(budget, 1))
        dec.use_collapse_triangulate = True
        # Decimate the REST mesh, then deform it: the armature modifier the
        # FBX importer added must run after the decimate.
        obj.modifiers.move(obj.modifiers.find(dec.name), 1 if masked else 0)
        dg = bpy.context.evaluated_depsgraph_get()
        ev = obj.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        nv = len(me.vertices)
        co = np.empty(nv * 3)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        world = np.array(obj.matrix_world)
        co = co @ world[:3, :3].T + world[:3, 3]
        col = np.empty(nv * 4)
        me.color_attributes["Col"].data.foreach_get("color", col)
        info = np.empty(nv * 4)
        me.color_attributes["Info"].data.foreach_get("color", info)
        tris = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
        me.loop_triangles.foreach_get("vertices", tris)
        ev.to_mesh_clear()
        tris = _clean_triangles(tris.reshape(-1, 3))

        bones = {pb.name: self.arm.matrix_world @ pb.head
                 for pb in self.arm.pose.bones}
        bones.update({pb.name + ".tail": self.arm.matrix_world @ pb.tail
                      for pb in self.arm.pose.bones})
        front = self._posed_front(bones)
        # Blender world -> game frame: rotate so the avatar faces +Z, and
        # swap to +Y up. Seat point: under the pelvis (seated) or between
        # the feet (standing); height zero is the floor the feet are on.
        yaw = math.atan2(front[0], front[1])  # angle of front from +Y
        c, s = math.cos(-yaw), math.sin(-yaw)
        rot = np.array([[c, -s, 0], [s, c, 0], [0, 0, 1.0]])
        local = co @ rot.T
        pelvis = rot @ np.array(bones["Bip01 Pelvis"])
        feet = local[:, 2].min()
        if seated:
            origin = np.array([pelvis[0], pelvis[1], feet])
        else:
            lf = rot @ np.array(bones["Bip01 L Foot"])
            rf = rot @ np.array(bones["Bip01 R Foot"])
            mid = (lf + rf) * 0.5
            origin = np.array([mid[0], mid[1], feet])
        local -= origin
        # Blender (x, y, z) facing +Y  ->  game (x', y', z') facing +Z:
        # z' = y (forward), y' = z (up), x' = -x keeps it a rotation.
        game = np.stack([-local[:, 0], local[:, 2], local[:, 1]], axis=1)
        out = {
            "co": game, "tris": tris.reshape(-1, 3),
            "colour": col.reshape(-1, 4)[:, :3].copy(),
            "shirt": info.reshape(-1, 4)[:, 0] > 0.5,
            "fold": info.reshape(-1, 4)[:, 1].copy(),
            "chest": info.reshape(-1, 4)[:, 2] > 0.5,
            "role": role, "seated": seated, "pose": pose, "avatar": self.name,
            "hip_height": float(pelvis[2] - feet),
        }
        def to_game(p):
            q = rot @ np.array(p) - origin
            return np.array([-q[0], q[2], q[1]])
        out["hands"] = (to_game(bones["Bip01 L Hand"]), to_game(bones["Bip01 R Hand"]),
                        to_game(bones["Bip01 L Finger2"]), to_game(bones["Bip01 R Finger2"]))
        out["head"] = to_game(bones["Bip01 Head"])
        if prop:
            _add_prop(out, prop)
        return out

    def _posed_front(self, bones: dict) -> np.ndarray:
        """Facing, from the posed pelvis: perpendicular to the hip line."""
        l = np.array(bones["Bip01 L Thigh"])
        r = np.array(bones["Bip01 R Thigh"])
        across = l - r
        across[2] = 0.0
        f = np.cross(np.array([0.0, 0.0, 1.0]), across)
        n = np.linalg.norm(f)
        f = f / max(n, 1e-9)
        # The front is where the nose is.
        nose = np.array(bones["Bip01 MNose"]) - np.array(bones["Bip01 Head"])
        if f @ nose < 0.0:
            f = -f
        return f

    def remove(self) -> None:
        for o in (self.mesh_obj, self.arm):
            data = o.data
            bpy.data.objects.remove(o)
            if isinstance(data, bpy.types.Mesh):
                bpy.data.meshes.remove(data)


# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------

def _box(centre, ax, ay, az):
    """8 corners and 12 triangles of a box with half-axis vectors."""
    corners = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                corners.append(centre + ax * sx + ay * sy + az * sz)
    q = ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6),
         (0, 2, 6, 4), (1, 5, 7, 3))
    tris = []
    for a, b, c, d in q:
        tris += [(a, b, c), (a, c, d)]
    return np.array(corners), np.array(tris)


## Prop colours, linear. The sign boards' faces are three of them; the
## picture itself is what the dark bands suggest at the distance they are seen.
SIGN_BOARDS = ((0.45, 0.44, 0.40), (0.45, 0.44, 0.40), (0.50, 0.38, 0.04),
               (0.34, 0.03, 0.02), (0.40, 0.40, 0.40), (0.04, 0.04, 0.05))
## And their lettering.
SIGN_INKS = ((0.015, 0.015, 0.02), (0.015, 0.015, 0.02), (0.30, 0.02, 0.02),
             (0.03, 0.05, 0.22), (0.45, 0.42, 0.36))
PHONE = (0.02, 0.02, 0.025)
PHONE_SCREEN = (0.55, 0.62, 0.75)


def _append(out: dict, co, tris, colour) -> None:
    base = len(out["co"])
    out["co"] = np.concatenate([out["co"], co])
    out["tris"] = np.concatenate([out["tris"], tris + base])
    out["colour"] = np.concatenate([out["colour"], np.tile(colour, (len(co), 1))])
    n = len(co)
    out["shirt"] = np.concatenate([out["shirt"], np.zeros(n, bool)])
    out["fold"] = np.concatenate([out["fold"], np.ones(n)])
    out["chest"] = np.concatenate([out["chest"], np.zeros(n, bool)])
    out.setdefault("prop", np.zeros(base, bool))
    out["prop"] = np.concatenate([out["prop"], np.ones(n, bool)])


def _add_prop(out: dict, prop: str) -> None:
    lh, rh, lf, rf = out["hands"]
    up = np.array([0.0, 1.0, 0.0])
    if prop in ("phone", "phone_low"):
        at = (lf + rf) * 0.5
        toward = np.array([0.0, 0.0, 1.0])
        across = np.array([1.0, 0.0, 0.0])
        co, tris = _box(at, across * 0.036, up * 0.072, toward * 0.006)
        _append(out, co, tris, PHONE)
        # The screen, toward the owner (and lit, so it reads as a phone).
        screen_at = at - toward * 0.0075
        co, tris = _box(screen_at, across * 0.031, up * 0.064, toward * 0.0015)
        _append(out, co, tris, PHONE_SCREEN)
        out["screen"] = screen_at
    elif prop == "sign":
        # A board held overhead between the two hands, facing the ring.
        mid = (lf + rf) * 0.5
        width = max(np.linalg.norm((lf - rf) * np.array([1, 0, 1])) + 0.18, 0.62)
        # Bottom edge at the hands or just over the head, whichever is
        # higher: a sign held in front of a face is a face nobody sees.
        bottom = max(mid[1] - 0.06, out["head"][1] + 0.14)
        centre = np.array([mid[0], bottom + 0.22, mid[2] + 0.04])
        across = np.array([1.0, 0.0, 0.0])
        co, tris = _box(centre, across * width * 0.5, up * 0.22,
                        np.array([0.0, 0.0, 0.006]))
        _append(out, co, tris, (1.0, 1.0, 1.0))
        # 1 marks the board and 2 its lettering, which crowd.py colours per
        # person: one sign repeated two hundred times is a pattern, not a
        # crowd.
        out["sign_mask"] = np.zeros(len(out["co"]), np.int8)
        out["sign_mask"][-len(co):] = 1
        # Lettering on the face toward the ring: a big word and a smaller
        # line under it, off-centre so no two read as one stencil.
        for dx, dy, w, h in ((-0.04, 0.07, 0.78, 0.065), (0.06, -0.09, 0.50, 0.035)):
            co, tris = _box(centre + across * (width * dx) + up * dy
                            + np.array([0.0, 0.0, 0.008]),
                            across * width * 0.5 * w, up * h,
                            np.array([0.0, 0.0, 0.002]))
            _append(out, co, tris, (0.02, 0.02, 0.025))
            out["sign_mask"] = np.concatenate([out["sign_mask"],
                                               np.full(len(co), 2, np.int8)])
        out["sign"] = (centre, width)


# ---------------------------------------------------------------------------
# The library: every avatar in every pose at every level of detail
# ---------------------------------------------------------------------------

## Levels of detail: target triangles, and whether hair cards survive.
## `near` is the bowl's first four rows, `mid` the rest of the lower tier,
## `far` the upper tier -- sized so the whole bowl stays a committable .glb
## (~1.1M crowd triangles; see crowd.py). `floor` is the ringside fans, a
## few metres from the gameplay camera and instanced, so they can afford
## ten times the bowl's nearest rows.
LODS = {
    "near": (520, False),
    "mid": (190, False),
    "far": (130, False),
    "floor": (1100, True),
}


def _cache_key() -> str:
    import hashlib
    h = hashlib.sha256()
    h.update(pathlib.Path(__file__).read_bytes())
    h.update(ROCKETBOX_COMMIT.encode())
    h.update(bpy.app.version_string.encode())
    return h.hexdigest()[:16]


def library(lods: tuple = tuple(LODS)) -> dict:
    """{(avatar, pose, lod): figure arrays} for every avatar, pose and lod.

    Building it is a few minutes of FBX import and decimation, so the result
    is cached (ROCKETBOX_CACHE, default ~/.cache/aegis-rocketbox) under a key
    that changes with this file, the Rocketbox commit and the Blender
    version. The cache is an optimisation only: deleting it rebuilds the same
    numbers, because every step above is deterministic."""
    import pickle
    cache_dir = pathlib.Path(os.environ.get(
        "ROCKETBOX_CACHE", "~/.cache/aegis-rocketbox")).expanduser()
    path = cache_dir / ("library_%s_%s.pkl" % (_cache_key(), "-".join(lods)))
    if path.is_file():
        with path.open("rb") as handle:
            return pickle.load(handle)
    rocketbox_root()
    # Built in a scratch scene, which is thrown away afterwards: the clips'
    # armatures and the avatars must not end up in whatever the caller
    # exports. The caller's bmesh parts are not in the scene, so they
    # survive the reset.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    out = {}
    for avatar_name in AVATARS:
        avatar = Avatar(avatar_name)
        for pose in POSE_NAMES:
            avatar.pose(pose)
            for lod in lods:
                tris, cards = LODS[lod]
                fig = avatar.extract(tris, cards)
                for k in ("hands", "head"):
                    fig.pop(k, None)
                out[(avatar_name, pose, lod)] = fig
        avatar.remove()
        print("rocketbox_crowd: %s posed" % avatar_name, flush=True)
    _CLIP_CACHE.clear()
    _SOURCE_CACHE.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cache_dir.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    with tmp.open("wb") as handle:
        pickle.dump(out, handle, protocol=4)
    tmp.replace(path)
    return out
