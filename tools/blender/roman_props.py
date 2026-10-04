#!/usr/bin/env python3
"""Build Roman Reigns' entrance props in Blender, export as glTF.

Run:  tools/blender/build_venue.sh roman

Two files:

  game/assets/props/ula_fala.glb      the Samoan chief's necklace he wears to
                                      the ring (gauntlet/refs/entrances.md)
  game/assets/props/aew_title.glb     the AEW World Championship, in two
                                      shapes: Title* worn round his waist,
                                      Held* straight in the hand

The belt is authored in the WRESTLER'S OWN FRAME, game axes: +Y up, forward -Z
(the controller's convention, WrestlerController._turn_toward_opponent), so +X
is his RIGHT and his left shoulder is at -X. Its origin is the point it hangs
from, and core/match/entrance_props.gd puts it there at runtime:

  worn       his hips bone (the belt is authored at his measured waist)
  held       the left hand's grip (hand_l)

The ula fala is different: it is SKINNED, built on his own body in his own
skeleton's coordinates (see "The ula fala" below). It needs roman_reigns.glb
and tools/blender/data/roman_fala_pose.json, which the game dumps with
`godot4 --headless --path game tools/probe/fala_pose_dump.tscn -- <abs path>`
whenever his standing pose changes.

Materials are placeholders, as everywhere in the venue: the game dresses each
part by name (EntranceProps.MATERIALS), because gold metal under this hall's
light is a solved value, not a Blender colour.

Deterministic: same code in, byte-identical .glb out.
"""

from __future__ import annotations

import argparse
import json
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import venue  # noqa: E402  (first: it provides bpy, bmesh and mathutils)
from venue import Part  # noqa: E402
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

import bpy_exit  # noqa: E402

PROP_DIR = venue.REPO / "game" / "assets" / "props"

## Measured shoulder span (upperarm_l to upperarm_r heads) of the base rig the
## props are authored against. EntranceProps scales by model span / this.
BASE_SHOULDER_SPAN = 0.384

TITLE_COLORS = {
    "TitleArt": (1.0, 0.77, 0.34, 1.0),
    "TitleGold": (1.0, 0.77, 0.34, 1.0),
    "TitleStrap": (0.03, 0.03, 0.03, 1.0),
    "TitleSnap": (0.8, 0.62, 0.3, 1.0),
    "HeldArt": (1.0, 0.77, 0.34, 1.0),
    "HeldGold": (1.0, 0.77, 0.34, 1.0),
    "HeldStrap": (0.03, 0.03, 0.03, 1.0),
    "HeldSnap": (0.8, 0.62, 0.3, 1.0),
}


def framed_box(part: Part, center: Vector, ax: Vector, ay: Vector, az: Vector,
               size: Vector) -> None:
    """A box on an arbitrary orthonormal frame -- a necklace segment lies on
    a curve that tilts every way, which an upright oriented_box cannot."""
    ex, ey, ez = ax * (size.x * 0.5), ay * (size.y * 0.5), az * (size.z * 0.5)
    corners = [center + ex * a + ey * b + ez * c
               for a, b, c in ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1),
                               (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1))]
    v = [part.vert(c) for c in corners]
    for face in ((0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4),
                 (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        part.quad(*[v[i] for i in face])


# ---------------------------------------------------------------------------
# The ula fala
# ---------------------------------------------------------------------------
#
# A chief's necklace of red pandanus keys -- the photograph shows a dense,
# glossy collar of curved, tooth-like spikes strung on a cord. It rides the
# trapezius at his back and sides, and in front hangs in a U to the upper
# chest, below the collarbones. The keys are 6-8 cm long and 2.5 cm across at
# the root, packed two rows deep, pointing away from the neck and lifting a
# little off the skin at their tips.
#
# It is SKINNED to his own rig (EntranceProps drives its copy of the skeleton
# from his), because every earlier build was a rigid mesh re-placed from one
# bone each frame and so floated off the shoulders the moment the chest or the
# arms moved (README: "floating" three times, then "inside his neck").
#
# So this is built ON HIS BODY, in the coordinates of his own skeleton (the
# armature-local frame of roman_reigns.glb, Z up in Blender = +Y up in game,
# his front at -Y Blender = +Z glTF):
#
#   1. the cord's route is a loop of control points; each is snapped to the
#      nearest point of his skin (body + head meshes) and lifted by the
#      cord's radius, then the loop is smoothed and re-snapped, so it lies ON
#      the trapezius and chest rather than near them;
#   2. the keys are swept tapered tubes standing off that cord on the skin's
#      own frame (normal, and "away from the neck" projected onto the skin);
#   3. every vertex is checked against the skin and pushed out of it;
#   4. each key takes the skin weights of the skin under its root, so it moves
#      as that patch of skin does -- the clavicles, the chest, the neck --
#      and the cord takes them point by point.
#
# Only the bones the weights use (and their parents) are kept in the exported
# armature. Deterministic: seeded jitter, sorted bone sets, no clock.

ROMAN_GLB = venue.REPO / "game" / "assets" / "characters" / "roman_reigns.glb"
FALA_ARMATURE = "roman reigns"
FALA_SKIN_MESHES = ("Default_Material", "head:skinned")

## The cord's route, his RIGHT half (+X), front to back, in armature-local
## metres (Blender axes: Y negative is his front). Measured off his skin
## (see the table in the commit message): the chest front is y -0.13 at
## z 1.36, the neck's base ring 0.085 across, the trapezius ridge z 1.49 out
## to x 0.21. These are rough: each point is snapped to the skin.
FALA_ROUTE = [
    (0.000, -0.205, 1.375),
    (0.040, -0.200, 1.383),
    (0.080, -0.180, 1.410),
    (0.110, -0.140, 1.445),
    (0.130, -0.095, 1.470),
    (0.140, -0.045, 1.482),
    (0.130, 0.000, 1.488),
    (0.100, 0.034, 1.470),
    (0.055, 0.040, 1.466),
    (0.000, 0.034, 1.462),
]
## The pose he is built against: his skinning matrices standing (roman_stand,
## frame 45), dumped from the running game by tools/probe/fala_pose_dump.tscn --
## RomanHeadShape's neck widening included. The necklace is laid on THAT body
## and then carried back to his bind pose through its own weights, so in the
## game it sits on him as he stands and the skin carries it from there.
## (Built on the T-posed bind pose it came out with every key aimed at the
## ceiling: with the arms down the trapezius is not where it was.)
POSE_JSON = venue.REPO / "tools" / "blender" / "data" / "roman_fala_pose.json"
FALA_NECK_AXIS = Vector((0.0, -0.055, 0.0))
FALA_CORD_RADIUS = 0.0038
FALA_SKIN_GAP = 0.0035
FALA_SEED = 11
## Two rows of keys on the one cord, interleaved: long, lying close to the
## skin, and shorter and more lifted so they show between the long ones.
FALA_ROWS = (
    {"count": 52, "length": 0.066, "width": 0.0160, "lift": 0.34, "phase": 0.0},
    {"count": 52, "length": 0.052, "width": 0.0140, "lift": 0.62, "phase": 0.5},
)
## Rings along a key (fraction of its length); the tip is a single vertex.
FALA_RINGS = (0.0, 0.16, 0.34, 0.54, 0.74, 0.90)
FALA_SIDES = 6
## Colour along a key: a deep crimson root to a brighter, slightly orange tip.
FALA_RAMP = ((0.0, (0.07, 0.002, 0.004)), (0.55, (0.20, 0.005, 0.008)),
             (1.0, (0.40, 0.028, 0.016)))
## Each key starts this far back toward the neck, over the cord, so the cord
## is hidden under the roots and not a black line along the collar.
FALA_ROOT_BACK = 0.012


def to_game(v: Vector) -> Vector:
    """Armature-local Blender (Z up, front -Y) to glTF/Godot skeleton space."""
    return Vector((v.x, v.z, -v.y))


def from_game(v: Vector) -> Vector:
    return Vector((v.x, -v.z, v.y))


def load_pose() -> dict[str, Matrix]:
    data = json.loads(POSE_JSON.read_text())["skinning"]
    return {n: Matrix(((r[0], r[1], r[2], r[3]), (r[4], r[5], r[6], r[7]),
                       (r[8], r[9], r[10], r[11]), (0.0, 0.0, 0.0, 1.0)))
            for n, r in data.items()}


def blend_matrix(pose: dict[str, Matrix], weights: dict[str, float]) -> Matrix:
    total = sum(weights.values()) or 1.0
    m = Matrix(((0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0)))
    for g, w in weights.items():
        if g in pose:
            m += pose[g] * (w / total)
        else:
            m += Matrix.Identity(4) * (w / total)
    return m


class Skin:
    """His skin (body and head meshes), POSED by `pose`, in armature-local
    space, with its own weights for nearest-point snapping and weight lookup."""

    def __init__(self, arm, pose: dict[str, Matrix]) -> None:
        inv = arm.matrix_world.inverted()
        self.verts: list[Vector] = []
        self.weights: list[dict[str, float]] = []
        self.polys: list[tuple[int, ...]] = []
        for name in FALA_SKIN_MESHES:
            ob = bpy.data.objects[name]
            m = inv @ ob.matrix_world
            groups = {g.index: g.name for g in ob.vertex_groups}
            off = len(self.verts)
            for v in ob.data.vertices:
                w = {groups[g.group]: g.weight for g in v.groups}
                self.verts.append(from_game(blend_matrix(pose, w) @ to_game(m @ v.co)))
                self.weights.append(w)
            for p in ob.data.polygons:
                self.polys.append(tuple(off + i for i in p.vertices))
        self.tree = BVHTree.FromPolygons(self.verts, self.polys)

    def nearest(self, p: Vector):
        loc, nor, idx, _ = self.tree.find_nearest(p)
        return loc, nor.normalized(), idx

    def weights_at(self, p: Vector) -> dict[str, float]:
        loc, _, idx = self.nearest(p)
        blend: dict[str, float] = {}
        total = 0.0
        for vi in self.polys[idx]:
            k = 1.0 / ((self.verts[vi] - loc).length + 1e-4)
            total += k
            for g, w in self.weights[vi].items():
                blend[g] = blend.get(g, 0.0) + w * k
        top = sorted(blend.items(), key=lambda kv: (-kv[1], kv[0]))[:4]
        s = sum(w for _, w in top) or 1.0
        return {g: w / s for g, w in top}


def _catmull_closed(points: list[Vector], per_seg: int) -> list[Vector]:
    n = len(points)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % n], points[(i + 2) % n]
        for s in range(per_seg):
            t = s / per_seg
            out.append(0.5 * ((2 * p1) + (p2 - p0) * t
                              + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
    return out


def _resample_closed(points: list[Vector], count: int) -> list[Vector]:
    n = len(points)
    cum = [0.0]
    for i in range(n):
        cum.append(cum[-1] + (points[(i + 1) % n] - points[i]).length)
    total = cum[-1]
    out, j = [], 0
    for k in range(count):
        s = total * k / count
        while cum[j + 1] < s:
            j += 1
        f = (s - cum[j]) / max(cum[j + 1] - cum[j], 1e-9)
        out.append(points[j].lerp(points[(j + 1) % n], f))
    return out


def fala_cord(skin: Skin, count: int = 240) -> tuple[list[Vector], list[Vector]]:
    """The cord's centre line and the skin normal along it, `count` samples
    round the closed loop (index 0 is the front, the first half his right)."""
    right = [Vector(p) for p in FALA_ROUTE]
    left = [Vector((-p.x, p.y, p.z)) for p in reversed(right[1:-1])]
    route = right + left
    dense = _resample_closed(_catmull_closed(route, 12), count)
    lift = FALA_CORD_RADIUS + 0.0015
    for _ in range(3):
        snapped = []
        for p in dense:
            loc, nor, _ = skin.nearest(p)
            snapped.append(loc + nor * lift)
        dense = [(snapped[i - 1] + snapped[i] * 2.0 + snapped[(i + 1) % count]) * 0.25
                 for i in range(count)]
    pts, nors = [], []
    for p in dense:
        loc, nor, _ = skin.nearest(p)
        pts.append(loc + nor * lift)
        nors.append(nor)
    smooth = []
    for i in range(count):
        a = sum((nors[(i + k) % count] for k in range(-3, 4)), Vector())
        smooth.append(a.normalized())
    return pts, smooth


def _ramp(t: float) -> tuple[float, float, float]:
    for (t0, c0), (t1, c1) in zip(FALA_RAMP, FALA_RAMP[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0)
            return tuple(c0[i] + (c1[i] - c0[i]) * f for i in range(3))
    return FALA_RAMP[-1][1]


def _rotate_about(v: Vector, axis: Vector, ang: float) -> Vector:
    c, s = math.cos(ang), math.sin(ang)
    return v * c + axis.cross(v) * s + axis * axis.dot(v) * (1.0 - c)


def _clear_of_skin(skin: Skin, p: Vector) -> Vector:
    loc, nor, _ = skin.nearest(p)
    gap = (p - loc).dot(nor)
    if gap < FALA_SKIN_GAP:
        return p + nor * (FALA_SKIN_GAP - gap)
    return p


def build_ula_fala_skinned(skin: Skin) -> dict:
    """Returns {"spikes": (verts, faces, colours, weights),
    "cord": (...)} for fala_export to turn into objects."""
    import random
    rng = random.Random(FALA_SEED)
    cord, nors = fala_cord(skin)
    n = len(cord)

    def at(frac: float):
        x = (frac % 1.0) * n
        i = int(x)
        f = x - i
        p = cord[i % n].lerp(cord[(i + 1) % n], f)
        nr = nors[i % n].lerp(nors[(i + 1) % n], f).normalized()
        tg = (cord[(i + 1) % n] - cord[i % n]).normalized()
        return p, nr, tg

    sv, sf, sc, sw = [], [], [], []
    for row_i, row in enumerate(FALA_ROWS):
        for k in range(row["count"]):
            frac = (k + row["phase"]) / row["count"]
            p, nr, tg = at(frac)
            length = row["length"] * (1.0 + rng.uniform(-0.12, 0.12))
            width = row["width"] * (1.0 + rng.uniform(-0.10, 0.10))
            radial = Vector((p.x - FALA_NECK_AXIS.x, p.y - FALA_NECK_AXIS.y, 0.0))
            radial = radial.normalized() if radial.length > 1e-6 else Vector((0, -1, 0))
            away = radial * 0.3 + Vector((0.0, 0.0, -0.7))
            d = away - nr * away.dot(nr)
            d = d.normalized() if d.length > 1e-4 else tg.cross(nr).normalized()
            d = _rotate_about(d, nr, rng.uniform(-0.20, 0.20) + (0.10 if k % 2 else -0.10))
            d = (d - nr * d.dot(nr)).normalized()
            # Droop: on the trapezius the skin is level and a key lies out
            # flat like a wing; hung on a cord it falls down and outward.
            d = (d + Vector((0.0, 0.0, -0.45 * max(nr.z, 0.0)))).normalized()
            side = nr.cross(d).normalized()
            base = p - d * FALA_ROOT_BACK + nr * 0.0015
            lift = row["lift"] * (0.5 if nr.z > 0.5 else 1.0)
            weights = skin.weights_at(base - nr * 0.01)
            rings = []
            for t in FALA_RINGS:
                c = base + (d * t + nr * (lift * t * t)) * (length + FALA_ROOT_BACK)
                tan = (d + nr * (2.0 * lift * t)).normalized()
                up = tan.cross(side).normalized()
                a = width * (1.0 - t ** 2.0) ** 0.55
                b = a * 0.85
                ring = []
                for s in range(FALA_SIDES):
                    th = 2.0 * math.pi * s / FALA_SIDES
                    v = c + side * (math.cos(th) * a) + up * (math.sin(th) * b)
                    sv.append(_clear_of_skin(skin, v))
                    sc.append(_ramp(t))
                    sw.append(weights)
                    ring.append(len(sv) - 1)
                rings.append(ring)
            tip = base + (d + nr * lift) * (length + FALA_ROOT_BACK)
            sv.append(_clear_of_skin(skin, tip))
            sc.append(_ramp(1.0))
            sw.append(weights)
            tip_i = len(sv) - 1
            for r in range(len(rings) - 1):
                for s in range(FALA_SIDES):
                    s2 = (s + 1) % FALA_SIDES
                    sf.append((rings[r][s], rings[r][s2], rings[r + 1][s2], rings[r + 1][s]))
            for s in range(FALA_SIDES):
                sf.append((rings[-1][s], rings[-1][(s + 1) % FALA_SIDES], tip_i))
    cv, cf, cc, cw = [], [], [], []
    sides = 8
    for i in range(n):
        p = cord[i]
        tg = (cord[(i + 1) % n] - cord[i - 1]).normalized()
        nr = nors[i]
        side = tg.cross(nr).normalized()
        w = skin.weights_at(p - nr * 0.01)
        for s in range(sides):
            th = 2.0 * math.pi * s / sides
            cv.append(p + (side * math.cos(th) + nr * math.sin(th)) * FALA_CORD_RADIUS)
            cc.append((0.10, 0.07, 0.05))
            cw.append(w)
    for i in range(n):
        for s in range(sides):
            a, b = i * sides + s, i * sides + (s + 1) % sides
            c, d2 = ((i + 1) % n) * sides + (s + 1) % sides, ((i + 1) % n) * sides + s
            cf.append((a, d2, c, b))
    return {"FalaRed": (sv, sf, sc, sw), "FalaCord": (cv, cf, cc, cw)}


def fala_export(out: pathlib.Path) -> int:
    """Import his skeleton and skin, build the necklace on it, weight it, cut
    the armature down to the bones the weights name, and export."""
    venue.reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(ROMAN_GLB))
    arm = bpy.data.objects[FALA_ARMATURE]
    pose = load_pose()
    skin = Skin(arm, pose)
    built = build_ula_fala_skinned(skin)
    # Back to the bind pose through each vertex's own weights.
    for name, (verts, faces, colours, weights) in list(built.items()):
        rest = []
        for v, w in zip(verts, weights):
            rest.append(from_game(blend_matrix(pose, w).inverted() @ to_game(v)))
        built[name] = (rest, faces, colours, weights)

    keep: set[str] = set()
    objects = []
    for name in sorted(built):
        verts, faces, colours, weights = built[name]
        mesh = bpy.data.meshes.new(name)
        bm = bmesh.new()
        bverts = [bm.verts.new(v) for v in verts]
        for f in faces:
            bm.faces.new([bverts[i] for i in f])
        layer = bm.loops.layers.color.new("Col")
        for face in bm.faces:
            for loop in face.loops:
                c = colours[loop.vert.index]
                loop[layer] = (c[0], c[1], c[2], 1.0)
        bm.normal_update()
        bm.to_mesh(mesh)
        bm.free()
        for poly in mesh.polygons:
            poly.use_smooth = True
        mat = bpy.data.materials.new("M_" + name)
        mat.use_nodes = True
        tree = mat.node_tree
        bsdf = tree.nodes["Principled BSDF"]
        col = tree.nodes.new("ShaderNodeVertexColor")
        col.layer_name = "Col"
        tree.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.3
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        groups = {}
        for i, w in enumerate(weights):
            for g, val in w.items():
                if g not in groups:
                    groups[g] = obj.vertex_groups.new(name=g)
                groups[g].add([i], val, "REPLACE")
                keep.add(g)
        obj.parent = arm
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        objects.append(obj)

    # Everything else goes: his meshes, his hair skeleton, and every bone the
    # weights do not name (a bone's parents stay, so the chain is whole).
    for o in list(bpy.data.objects):
        if o is not arm and o not in objects:
            bpy.data.objects.remove(o, do_unlink=True)
    for b in sorted(keep):
        p = arm.data.bones[b].parent
        while p is not None:
            keep.add(p.name)
            p = p.parent
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in [e for e in arm.data.edit_bones if e.name not in keep]:
        arm.data.edit_bones.remove(eb)
    bpy.ops.object.mode_set(mode="OBJECT")

    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for o in objects:
        o.select_set(True)
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out), export_format="GLB", use_selection=True,
        export_skins=True, export_animations=False, export_yup=True,
        export_materials="EXPORT", export_vertex_color="ACTIVE",
        export_all_vertex_colors=False, export_apply=False,
        export_cameras=False, export_lights=False)
    tris = sum(len(f) - 2 for _, (_, faces, _, _) in built.items() for f in faces)
    print("ula_fala: %d triangles, %d bones -> %s" % (tris, len(keep), out))
    return tris



# ---------------------------------------------------------------------------
# The AEW World Championship
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# The belt, laid out off the owner's texture atlas
# ---------------------------------------------------------------------------
#
# tools/assets/build_title_textures.py measures the atlas and writes
# aew_title_layout.json: each plate's pixel box in the belt band, the centre
# column, the strap's rows, and the metres per pixel. Every plate here is
# placed and sized from that, and its front face is UV-mapped to exactly its
# own box -- so the artwork lands on the plate it was drawn for, unstretched,
# and the leather between plates is real strap, not a picture of one.
#
# Atlas x runs across the belt as a viewer sees it: the viewer's LEFT is the
# wearer's RIGHT (+X), so a belt coordinate `s` (metres along the belt from
# the centre plate, + toward +X) is (centre_x - px) * metres_per_px.

LAYOUT = json.loads((pathlib.Path(__file__).resolve().parent
                     / "aew_title_layout.json").read_text())
MPP = LAYOUT["metres_per_px"]
BAND_W, BAND_H = LAYOUT["band"]
CENTRE_PX = LAYOUT["centre_x"]
STRAP_TOP, STRAP_BOTTOM = LAYOUT["strap_y"]
STRAP_MID = 0.5 * (STRAP_TOP + STRAP_BOTTOM)
STRAP_HEIGHT = (STRAP_BOTTOM - STRAP_TOP) * MPP
## How far each plate stands off the strap: the centre plate is the deepest.
PLATE_DEPTH = {"centre": 0.009, "inner_l": 0.007, "inner_r": 0.007}
PLATE_DEPTH_DEFAULT = 0.005
## Snaps: two columns of three at each end of the band, as the atlas has
## them (and as its snap swatch draws them: brass rings).
SNAP_COLS_PX = (29, 80)
SNAP_ROWS_PX = (190, 272, 355)


def _s(px: float) -> float:
    return (CENTRE_PX - px) * MPP


def _y(py: float) -> float:
    return (STRAP_MID - py) * MPP


def _uv(px: float, py: float) -> tuple[float, float]:
    return (px / BAND_W, 1.0 - py / BAND_H)


def build_belt(parts: dict[str, Part], prefix: str, frame) -> None:
    """The whole belt along a path. `frame(s)` gives (point, along, out) for
    belt coordinate s: the strap's centre line and its outward face."""
    art, gold, strap, snap = (parts[prefix + k] for k in ("Art", "Gold", "Strap", "Snap"))
    s_end = _s(0.0)
    # The strap: a band STRAP_HEIGHT tall, 8 mm thick, following the path.
    steps = 64
    for i in range(steps):
        s0 = -s_end + 2.0 * s_end * i / steps
        s1 = -s_end + 2.0 * s_end * (i + 1) / steps
        p0, _, _ = frame(s0)
        p1, _, _ = frame(s1)
        pm, along, out = frame(0.5 * (s0 + s1))
        up = out.cross(along).normalized()
        framed_box(strap, pm, along, up, out,
                   Vector(((p1 - p0).length + 0.001, STRAP_HEIGHT, 0.008)))
    # The plates: a raised slab each, bent along the path in columns, with
    # the art on its face.
    for name, (x0, y0, x1, y1) in sorted(LAYOUT["plates"].items()):
        depth = PLATE_DEPTH.get(name, PLATE_DEPTH_DEFAULT)
        cols = max(2, int(round((x1 - x0) / LAYOUT["column_px"])))
        slabs = LAYOUT["slabs"][name]
        for c in range(cols):
            pa = x0 + (x1 - x0) * c / cols
            pb = x0 + (x1 - x0) * (c + 1) / cols
            sa, sb = _s(pa), _s(pb)
            qa, _, oa = frame(sa)
            qb, _, ob = frame(sb)
            face = 0.004 + depth
            top, bottom = _y(y0), _y(y1)
            corners = [qa + oa * face + Vector((0, bottom, 0)),
                       qb + ob * face + Vector((0, bottom, 0)),
                       qb + ob * face + Vector((0, top, 0)),
                       qa + oa * face + Vector((0, top, 0))]
            art.quad_at(*corners, uvs=[_uv(pa, y1), _uv(pb, y1), _uv(pb, y0), _uv(pa, y0)])
            # The slab behind the art gives the plate its depth from the
            # side. Built to the rows that are solid plate in this column
            # (measured off the cut-out art, build_title_textures.py) and a
            # little inside them, so no edge of it shows past the outline.
            span = slabs[c]
            if span is None:
                continue
            pm, along, out = frame(0.5 * (sa + sb))
            up = out.cross(along).normalized()
            s_top, s_bottom = _y(span[0]) - 0.007, _y(span[1]) + 0.007
            if s_top <= s_bottom:
                continue
            # Its front face 1.5 mm behind the art's, or the two z-fight
            # and the slab's flat gold wins over the artwork.
            framed_box(gold, pm + out * (0.004 + depth * 0.5 - 0.0015)
                       + Vector((0, 0.5 * (s_top + s_bottom), 0)), along, up, out,
                       Vector((abs(sb - sa) * 0.9, s_top - s_bottom, depth)))
    # Snaps at both ends.
    for px in SNAP_COLS_PX:
        for end in (px, BAND_W - px):
            for py in SNAP_ROWS_PX:
                p, along, out = frame(_s(end))
                centre = p + out * 0.004 + Vector((0, _y(py), 0))
                # A brass grommet: a ring, the leather showing through it.
                ring = []
                for k in range(11):
                    ang = 2.0 * math.pi * k / 10.0
                    ring.append(centre + along * (0.0085 * math.cos(ang))
                                + Vector((0, 0.0085 * math.sin(ang), 0)))
                snap.tube(ring, 0.0032, sides=5, caps=False)


## Roman's waist, as the belt must clear it. The first cut was one rest-pose
## ellipse (0.19 x 0.14 m, centre 2.4 cm forward), and in the owner's video
## the plates sat inside his stomach. tools/probe/wear_clearance.tscn then
## measured every torso vertex in the belt's height band (the centre plate
## runs from 4 cm under the hips bone to 20 cm over it, up onto his belly)
## on every fifth frame of his entrance: his belly stands 0.21 m in front of
## the hips bone and his seat 0.15 m behind, and he is 0.21 m to a side.
## So the belt line is two half-ellipses -- a deeper one in front -- fitted
## to clear 99.9% of those points by 17 mm (the strap's inner face is 4 mm
## inside the line); the rest come within 2 mm of it, on single frames.
WAIST_HALF_X = 0.225
WAIST_FRONT = 0.225
WAIST_BACK = 0.165
WAIST_LIFT = 0.075


def _waist_point(t: float) -> Vector:
    """A point on the belt line, t in [0, 1): 0 at the buckle (front, -Z),
    going round his RIGHT (+X) side."""
    a = 2.0 * math.pi * t
    depth = WAIST_FRONT if math.cos(a) > 0.0 else WAIST_BACK
    return Vector((WAIST_HALF_X * math.sin(a), 0.0, -depth * math.cos(a)))


def build_title_waist(parts: dict[str, Part]) -> None:
    """Worn round his waist: the belt path is his measured waist, the centre
    plate at the front, the ends meeting at his back. Authored for Roman at
    his measured size -- EntranceProps puts it on at 1:1 -- origin at his
    hips bone, the belt line WAIST_LIFT above it."""
    count = 720
    pts = [_waist_point(i / count) for i in range(count + 1)]
    arc = [0.0]
    for a, b in zip(pts, pts[1:]):
        arc.append(arc[-1] + (b - a).length)
    perimeter = arc[-1]

    def frame(s: float):
        # s along the belt from the front centre, + round his right (+X).
        u = (s % perimeter)
        lo, hi = 0, len(arc) - 1
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if arc[mid] <= u:
                lo = mid
            else:
                hi = mid
        k = (u - arc[lo]) / max(arc[hi] - arc[lo], 1e-9)
        p = pts[lo].lerp(pts[hi], k) + Vector((0.0, WAIST_LIFT, 0.0))
        along = (pts[hi] - pts[lo]).normalized()
        # The line's outward normal: along perpendicular to up.
        out = along.cross(Vector((0.0, 1.0, 0.0))).normalized()
        if out.dot(Vector((p.x, 0.0, p.z))) < 0.0:
            out = -out
        return p, along, out
    build_belt(parts, "Title", frame)


def build_title_held(parts: dict[str, Part]) -> None:
    """Held overhead: the belt straight across, plates facing forward (-Z),
    gripped at the middle of the strap just above the centre plate."""
    grip = Vector((0.0, -0.08, -0.02))

    def frame(s: float):
        return grip + Vector((s, 0.0, 0.0)), Vector((1.0, 0.0, 0.0)), Vector((0.0, 0.0, -1.0))
    build_belt(parts, "Held", frame)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args(argv)
    PROP_DIR.mkdir(parents=True, exist_ok=True)

    fala_export(PROP_DIR / "ula_fala.glb")

    venue.reset_scene()
    parts = {name: Part(name) for name in TITLE_COLORS}
    build_title_waist(parts)
    build_title_held(parts)
    venue.finish(parts, TITLE_COLORS, projected=frozenset({"TitleStrap", "HeldStrap"}))
    venue.export_glb(PROP_DIR / "aew_title.glb")
    print("aew_title: %d triangles" % venue.triangle_count())
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main(sys.argv[1:]))
