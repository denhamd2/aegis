#!/usr/bin/env python3
"""Kenny Omega's hair, on Cody's head: a slicked crown and curly lengths.

Kenny is built on Cody's model (KennyModel extends CodyModel), so his hair is
grown on Cody's scalp. The owner's sheet (gauntlet/refs/characters/
kenny_omega_sheet.png, HAIR REFERENCES) has it wet and slicked straight back
off a receding forehead, flat over the crown, tucked behind the ears, and
falling from there in loose, separate curly ringlets onto the shoulders and
the top of the back: dark dirty-blond underneath, bright gold curls on top.

Run:  python3 tools/blender/kenny_curls.py
Writes game/assets/characters/kenny_curls.glb and kenny_curl_cards.png.

Three meshes, all skinned to Cody's own bones (KennyModel puts them under his
skeleton, as RomanModel does its ringlets):
* CurlCap: the scalp -- the head faces whose UVs land in the head texture's
  painted hair, found as cody_hair.py finds them -- lifted a few millimetres,
  opaque, so no skin shows between the cards.
* CurlSlick: the slicked crown. Cards lying on the cap from the hairline back
  over the crown and down the back of the skull, swept off a part left of
  centre (CURL_PART). Each card follows the scalp step by step (cody_groom.py's
  construction).
* CurlRinglets: the lengths. Each ringlet roots on the scalp behind the ears
  or round the back of the head and FALLS: stepped down under gravity with a
  little outward drift, pushed off whatever it would pass into (head, neck,
  shoulders, back) to a standoff of its own, and never drawn in toward the
  neck faster than RINGLET_DRAPE -- hair falls from the bulge of the skull,
  not into the hollow of the nape. Then it is a coiling clump of two crossed
  cards round that line (roman_ringlets.py's construction), the curl painted
  into the strand atlas.
Weights: the head above the jaw, then by height to neck_01 and spine_03, and
on the shoulders a share to the clavicle under them, so the lengths ride the
body instead of swinging through it.

Colour: the atlas carries the strands (white-to-grey tone in RGB, coverage in
alpha); the vertex colours carry the hair's colour, dark dirty blond at the
root to gold at the tips, per ringlet a little lighter or darker -- the sheet's
mix of dark underneath and bright curls on top. KennyModel's materials are
white so these are the colour.

Deterministic: same inputs, byte-identical outputs.
"""

from __future__ import annotations

import math
import pathlib
import sys

import bpy  # noqa: E402  (first: it provides bmesh and mathutils)
import bmesh  # noqa: E402
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import bpy_exit  # noqa: E402
import cody_hair as scalp  # noqa: E402
import importlib.util  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[2]
SOURCE = REPO / "game/assets/characters/cody_rhodes.glb"
OUT = REPO / "game/assets/characters/kenny_curls.glb"
CARDS = REPO / "game/assets/characters/kenny_curl_cards.png"
# His hairline is the head texture's (build_kenny_textures.HAIRLINE): the
# scalp below it is bared forehead there, so no hair grows from it here.
_spec = importlib.util.spec_from_file_location(
    "kenny_tex", REPO / "tools/assets/build_kenny_textures.py")
kenny_tex = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(kenny_tex)

## Blender space (Z up, -Y forward). Cody's skull: its vertical axis passes
## through (0, AXIS_Y); the face is toward -Y, the back of the head at +Y 0.205.
AXIS_Y = 0.095

## Colours, sRGB. Measured off the sheet's hair panel (back view, under arena
## light: median (82,67,58), 90th percentile (151,121,103), 97th (187,155,123):
## red over blue 1.4-1.5) and lifted to albedo. The first pass took the tips
## to (206,168,112), red over blue 1.84, and the curls rendered ginger-orange.
ROOT = (98, 80, 60)
TIP = (208, 180, 132)
CAP = (150, 124, 88)
## Per ringlet, the tip colour scaled by this (seeded): some curls dark
## dirty blond, some bright gold.
RINGLET_TONE = (0.62, 1.08)

## CurlCap: off the skin by this much, more on top.
CAP_LIFT = (0.0018, 0.0035)

## CurlSlick: the part, x in metres (+X is his left).
CURL_PART = 0.022
SLICK_COUNT = 520
SLICK_STEPS = 6
SLICK_LENGTH = (0.05, 0.13)
SLICK_HALF_WIDTH = (0.0035, 0.0065)
## Off the cap: lying flat, wet.
SLICK_STANDOFF = (0.0022, 0.0055)
## Sideways off the part as the strands leave the hairline.
SLICK_SWEEP = 0.35
SLICK_SEED = 271027

## CurlRinglets.
RINGLET_COUNT = 120
## Rooted behind the ears and round the back: at least this many degrees
## round from the front of the head, and no higher than RINGLET_ROOT_TOP.
RINGLET_ROOT_ANGLE = 104.0
RINGLET_ROOT_TOP = 1.80
RINGLET_ROOT_BOTTOM = 1.60
## And some framing the face: rooted above and just behind the temples, round
## from RINGLET_FRAME_ANGLE, falling past the ears to the shoulders -- the
## sheet's front view has curls down both sides of his face.
RINGLET_FRAME_COUNT = 24
RINGLET_FRAME_ANGLE = (78.0, 104.0)
RINGLET_FRAME_HEIGHT = (1.72, 1.80)
## Length along the fall, metres: longer at the back (onto the top of the
## back) than at the sides (onto the shoulders).
RINGLET_LENGTH_SIDE = (0.14, 0.22)
RINGLET_LENGTH_BACK = (0.20, 0.30)
## And none below this height: the owner, 25 Oct, of the last build, "His
## hair looks too big" -- it reached 1.35 m. The sheet's ends lie on the tops
## of the shoulders and the top of the back.
RINGLET_FLOOR = 1.43
RINGLET_STANDOFF = (0.010, 0.024)
RINGLET_DRAPE = 0.30
## Outward drift per unit of fall: the lengths spread a little as they hang.
RINGLET_DRIFT = 0.12
RINGLET_SIM_STEP = 0.004
RINGLET_STEP = 0.008
## Loose curls: a helix round the line, small against the clump's width.
RINGLET_RADIUS = (0.006, 0.011)
RINGLET_PITCH = (0.034, 0.055)
RINGLET_EASE = 0.04
RINGLET_WIDTH = ((0.020, 0.030), 0.008)
## Darker where the ringlet leaves the scalp, in the shade of the hair over it.
RINGLET_ROOT_SHADE = 0.7
RINGLET_SEED = 271028

## Weights by height (Blender z = Godot y): all Head above HEAD_Y[0], all
## neck_01 by HEAD_Y[1]; neck_01 to spine_03 over NECK_Y.
HEAD_Y = (1.60, 1.52)
NECK_Y = (1.50, 1.40)
## On the shoulders, a share to the clavicle under the hair, by |x|.
CLAVICLE_X = (0.07, 0.16)
CLAVICLE_SHARE = 0.45

## The strand atlas: CURL_COLUMNS curly clumps, then SLICK_COLUMNS gently
## waved ones for the crown.
CURL_COLUMNS = 4
SLICK_COLUMNS = 2
ATLAS = (1024, 2048)
ATLAS_STRANDS = 70
ATLAS_SEED = 271029
## The RGB under the strands: what the opaque cap shows between them. At
## 120 (linear 0.19) it took the cap to near black.
ATLAS_GROUND = 170


def smooth(a: float, b: float, x: float) -> float:
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def linear(c) -> tuple:
    """sRGB 0-255 -> linear 0-1 (glTF vertex colours are linear)."""
    out = []
    for v in c:
        v = v / 255.0
        out.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def paint_atlas(target: pathlib.Path) -> None:
    """RGB strand tone over ATLAS_GROUND, coverage in alpha. Curl columns: a
    clump of strands sharing one curl (so it reads as a ringlet, not frizz),
    each strand's phase and amplitude a little off the clump's, converging
    toward the tip and thinning over the last quarter. Slick columns: long
    strands with a slow wave."""
    rng = np.random.default_rng(ATLAS_SEED)
    ss = 2
    w, h = ATLAS[0] * ss, ATLAS[1] * ss
    tone = Image.new("L", (w, h), ATLAS_GROUND)
    alpha = Image.new("L", (w, h), 0)
    dt, da = ImageDraw.Draw(tone), ImageDraw.Draw(alpha)
    columns = CURL_COLUMNS + SLICK_COLUMNS
    col = w / columns
    for c in range(columns):
        curly = c < CURL_COLUMNS
        centre = c * col + col * 0.5
        waves = float(rng.uniform(5.0, 7.5)) if curly else float(rng.uniform(1.2, 2.2))
        amp = col * (float(rng.uniform(0.18, 0.26)) if curly else 0.06)
        phase = float(rng.uniform(0.0, 2.0 * math.pi))
        for _ in range(ATLAS_STRANDS):
            x0 = centre + col * 0.40 * float(np.clip(rng.normal(0.0, 0.45), -1.0, 1.0))
            length = h * float(rng.uniform(0.70, 1.0))
            a = amp * float(rng.uniform(0.7, 1.25))
            ph = phase + float(rng.normal(0.0, 0.35))
            pts = []
            for t in np.linspace(0.0, 1.0, 160):
                x = x0 + (centre - x0) * 0.6 * t * t + a * math.sin(ph + waves * 2.0 * math.pi * t)
                pts.append((x, t * length))
            width = max(1, round(float(rng.uniform(1.4, 2.6)) * ss))
            # Most strands bright, a few dark ones through the clump.
            shade = int(rng.integers(205, 256)) if rng.random() < 0.8 else int(rng.integers(150, 200))
            dt.line(pts, fill=shade, width=width)
            da.line(pts, fill=int(rng.integers(170, 256)), width=width)
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.6 * ss)).resize(ATLAS, Image.LANCZOS)
    tone = tone.filter(ImageFilter.GaussianBlur(0.5 * ss)).resize(ATLAS, Image.LANCZOS)
    out = Image.merge("RGBA", (tone, tone, tone, alpha))
    out.save(target, optimize=True)


class Scalp:
    """Cody's scalp (head faces in the texture's hair region), world space,
    with smooth normals and a BVH to walk cards over."""

    def __init__(self, body):
        bm = bmesh.new()
        bm.from_mesh(body.data)
        uv = bm.loops.layers.uv.active
        head = next(i for i, mat in enumerate(body.data.materials)
                    if mat.name == scalp.HEAD_MATERIAL)
        remove = []
        mw = body.matrix_world
        for face in bm.faces:
            centre = sum((loop[uv].uv for loop in face.loops), Vector((0, 0))) / len(face.loops)
            if face.material_index != head or not scalp.is_hair(*centre):
                remove.append(face)
                continue
            # Below his receding hairline: forehead, not scalp.
            c = mw @ face.calc_center_median()
            angle = round_from_front(c)
            if angle < kenny_tex.HAIRLINE_REACH and c.z < float(kenny_tex.hairline_at(angle)):
                remove.append(face)
        bmesh.ops.delete(bm, geom=remove, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0008)
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bm.normal_update()
        bm.verts.ensure_lookup_table()
        bm.verts.index_update()
        nw = mw.to_3x3().inverted().transposed()
        self.points = [mw @ v.co for v in bm.verts]
        self.normals = [(nw @ v.normal).normalized() for v in bm.verts]
        self.faces = [tuple(v.index for v in f.verts) for f in bm.faces]
        bm.free()
        self.bvh = BVHTree.FromPolygons(self.points, self.faces, all_triangles=True)
        self.low = min(p.z for p in self.points)
        self.high = max(p.z for p in self.points)
        self.front = min(p.y for p in self.points)

    def sample(self, p):
        """The nearest scalp point and its interpolated normal."""
        hit, normal, idx, _ = self.bvh.find_nearest(p)
        a, b, c = (self.points[i] for i in self.faces[idx])
        v0, v1, v2 = b - a, c - a, hit - a
        d00, d01, d11 = v0.dot(v0), v0.dot(v1), v1.dot(v1)
        denom = d00 * d11 - d01 * d01
        if abs(denom) > 1e-16:
            v = (d11 * v2.dot(v0) - d01 * v2.dot(v1)) / denom
            w = (d00 * v2.dot(v1) - d01 * v2.dot(v0)) / denom
            n = self.normals
            f = self.faces[idx]
            normal = (n[f[0]] * (1 - v - w) + n[f[1]] * v + n[f[2]] * w).normalized()
        return hit, normal

    def topness(self, p, n) -> float:
        return smooth(0.0, 1.0, (p.z - self.low) / (self.high - self.low)) * smooth(-0.15, 0.8, n.z)

    def area_choice(self, rng, keep, count):
        """`count` (point, normal) roots, area-weighted over the faces whose
        centre passes `keep(centre, normal)`."""
        weights = []
        for f in self.faces:
            a, b, c = (self.points[i] for i in f)
            centre = (a + b + c) / 3.0
            n = (self.normals[f[0]] + self.normals[f[1]] + self.normals[f[2]]).normalized()
            weights.append((b - a).cross(c - a).length if keep(centre, n) else 0.0)
        weights = np.array(weights)
        roots = []
        for _ in range(count):
            f = self.faces[int(rng.choice(len(self.faces), p=weights / weights.sum()))]
            u, v = rng.random(2)
            u = math.sqrt(u)
            p = self.points[f[0]] * (1 - u) + self.points[f[1]] * (u * (1 - v)) + self.points[f[2]] * (u * v)
            roots.append(self.sample(p))
        return roots


def round_from_front(p) -> float:
    """Degrees round the skull's axis from straight ahead (0) to the back (180)."""
    return math.degrees(math.atan2(abs(p.x), -(p.y - AXIS_Y)))


def weights_at(p) -> list:
    """[(bone, weight)] for a point of hair at p (Blender world)."""
    z = p.z
    neck = smooth(HEAD_Y[0], HEAD_Y[1], z)
    spine = smooth(NECK_Y[0], NECK_Y[1], z)
    out = [("Head", 1.0 - neck), ("neck_01", neck * (1.0 - spine)), ("spine_03", neck * spine)]
    share = CLAVICLE_SHARE * smooth(CLAVICLE_X[0], CLAVICLE_X[1], abs(p.x)) * spine
    if share > 0.0:
        out = [(b, w * (1.0 - share)) for b, w in out]
        out.append(("clavicle_l" if p.x > 0 else "clavicle_r", share))
    return [(b, w) for b, w in out if w > 1e-4]


def mesh_object(name, arm, verts, faces, uvs, colours, weights, normals=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        poly.use_smooth = True
        for li in poly.loop_indices:
            layer.data[li].uv = uvs[mesh.loops[li].vertex_index]
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, c in enumerate(colours):
        col.data[i].color = (c[0], c[1], c[2], 1.0)
    if normals is not None:
        # Cards take the scalp's normal: lit as one volume of hair, not as
        # separate leaves (cody_groom.py).
        mesh.normals_split_custom_set_from_vertices([tuple(n) for n in normals])
    mesh.materials.append(bpy.data.materials.new(name))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    groups = {}
    for i, wts in enumerate(weights):
        for bone, w in wts:
            if bone not in groups:
                groups[bone] = obj.vertex_groups.new(name=bone)
            groups[bone].add([i], w, "REPLACE")
    # The vertices are already in world space: parent without letting the
    # armature's own transform apply twice (roman_ringlets.py).
    obj.parent = arm
    obj.matrix_parent_inverse = arm.matrix_world.inverted()
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return obj, 2 * len(faces) if all(len(f) == 4 for f in faces) else len(faces)


def build_cap(s: Scalp, arm):
    verts, uvs, colours, weights = [], [], [], []
    cap = linear(CAP)
    for p, n in zip(s.points, s.normals):
        q = p + n * (CAP_LIFT[0] + (CAP_LIFT[1] - CAP_LIFT[0]) * s.topness(p, n))
        verts.append(q)
        # Strands front to back over the top and down the back: u across,
        # v along, tiled.
        uvs.append(((q.x + 0.5) * 6.0, (q.y - s.front) * 5.0 + (s.high - q.z) * 5.0))
        colours.append(cap)
        weights.append(weights_at(q))
    return mesh_object("CurlCap", arm, verts, s.faces, uvs, colours, weights)


def build_slick(s: Scalp, arm):
    rng = np.random.default_rng(SLICK_SEED)
    verts, faces, uvs, colours, weights, normals = [], [], [], [], [], []
    roots = s.area_choice(rng, lambda c, n: True, SLICK_COUNT)
    root_c, tip_c = linear(ROOT), linear(TIP)
    for p, n in roots:
        side = -1.0 if p.x < CURL_PART else 1.0
        length = float(rng.uniform(*SLICK_LENGTH)) * (0.6 + 0.4 * s.topness(p, n))
        half = float(rng.uniform(*SLICK_HALF_WIDTH))
        standoff = float(rng.uniform(*SLICK_STANDOFF))
        column = CURL_COLUMNS + int(rng.integers(0, SLICK_COLUMNS))
        tone = float(rng.uniform(*RINGLET_TONE))
        sweep = SLICK_SWEEP * side * float(rng.uniform(0.5, 1.2))
        start = len(verts)
        q = p.copy()
        for step in range(SLICK_STEPS + 1):
            t = step / SLICK_STEPS
            q, nq = s.sample(q)
            # Back over the top; over the back of the skull, down it; the
            # sweep off the part fades as the strands go back.
            back = max(0.0, nq.y)
            wanted = Vector((sweep * (1.0 - t), 1.0, -0.35 - 1.6 * back))
            d = wanted - nq * wanted.dot(nq)
            if d.length_squared < 1e-6:
                d = Vector((0.0, 0.0, -1.0)) - nq * (-nq.z)
            d.normalize()
            across = d.cross(nq).normalized()
            centre = q + nq * standoff
            width = half * (1.0 - 0.6 * t * t)
            for k in (-1.0, 1.0):
                verts.append(centre + across * width * k)
                uvs.append(((column + 0.5 + 0.45 * k) / (CURL_COLUMNS + SLICK_COLUMNS), 1.0 - t * 0.55))
                c = [r + (tc * tone - r) * smooth(0.0, 0.5, t) for r, tc in zip(root_c, tip_c)]
                colours.append(c)
                weights.append(weights_at(centre))
                normals.append(nq.copy())
            q = q + d * (length / SLICK_STEPS)
        for step in range(SLICK_STEPS):
            a = start + step * 2
            faces.append((a, a + 1, a + 3, a + 2))
    return mesh_object("CurlSlick", arm, verts, faces, uvs, colours, weights, normals)


def fall(root, normal, length, standoff, bvh):
    """The ringlet's line from its root, resampled every RINGLET_STEP."""
    p = root + normal * standoff
    pts = [p]
    total = 0.0
    still = 0
    for _ in range(4000):
        h = Vector((p.x, p.y - AXIS_Y, 0.0))
        r = h.length
        out = h / r if r > 1e-6 else Vector((0.0, 1.0, 0.0))
        q = p + (Vector((0.0, 0.0, -1.0)) + out * RINGLET_DRIFT).normalized() * RINGLET_SIM_STEP
        loc, nrm, _, _ = bvh.find_nearest(q)
        if loc is not None and (q - loc).dot(nrm) < standoff:
            q = loc + nrm * standoff
        # Not drawn in toward the neck faster than RINGLET_DRAPE per unit of fall.
        hq = Vector((q.x, q.y - AXIS_Y, 0.0))
        floor = r - RINGLET_DRAPE * max(p.z - q.z, 0.0)
        if hq.length < floor and hq.length > 1e-6:
            hq = hq * (floor / hq.length)
            q = Vector((hq.x, hq.y + AXIS_Y, q.z))
        moved = (q - p).length
        still = still + 1 if moved < RINGLET_SIM_STEP * 0.1 else 0
        if still > 20:
            break
        total += moved
        pts.append(q)
        p = q
        if total >= length or p.z <= RINGLET_FLOOR:
            break
    # Resample at even spacing along the line.
    out, acc = [pts[0]], 0.0
    target = RINGLET_STEP
    for a, b in zip(pts, pts[1:]):
        seg = (b - a).length
        while acc + seg >= target and seg > 0:
            t = (target - acc) / seg
            out.append(a + (b - a) * t)
            target += RINGLET_STEP
        acc += seg
    samples = []
    for i, q in enumerate(out):
        a = out[max(i - 1, 0)]
        b = out[min(i + 1, len(out) - 1)]
        samples.append((q, (b - a).normalized()))
    return samples


def build_ringlet(samples, rng, column, tone):
    """Two crossed cards round a helix about the line (roman_ringlets.py):
    one facing out from the head, one edge-on to it."""
    verts, faces, uvs, colours, weights = [], [], [], [], []
    radius = float(rng.uniform(*RINGLET_RADIUS))
    pitch = float(rng.uniform(*RINGLET_PITCH))
    phase = float(rng.uniform(0.0, 2.0 * math.pi))
    w_top = float(rng.uniform(*RINGLET_WIDTH[0]))
    total = (len(samples) - 1) * RINGLET_STEP
    p0, t0 = samples[0]
    out = Vector((p0.x, p0.y - AXIS_Y, 0.0)).normalized()
    n1 = Vector((0.0, 0.0, 1.0)).cross(out)
    n1 = (n1 - t0 * n1.dot(t0)).normalized()
    cols = (column, (column + 1) % CURL_COLUMNS)
    root_c, tip_c = linear(ROOT), linear(TIP)
    columns = CURL_COLUMNS + SLICK_COLUMNS
    for k, (p, tan) in enumerate(samples):
        n1 = (n1 - tan * n1.dot(tan)).normalized()
        n2 = tan.cross(n1)
        s = k * RINGLET_STEP
        rel = s / total if total > 0 else 0.0
        phi = 2.0 * math.pi * s / pitch + phase
        radial = n1 * math.cos(phi) + n2 * math.sin(phi)
        centre = p + radial * (radius * smooth(0.0, RINGLET_EASE, s))
        width = (w_top + (RINGLET_WIDTH[1] - w_top) * rel ** 1.5) * (0.5 + 0.5 * smooth(0.0, 0.03, s))
        shade = RINGLET_ROOT_SHADE + (1.0 - RINGLET_ROOT_SHADE) * smooth(0.0, 0.2, rel)
        c = [min((r + (tc * tone - r) * smooth(0.0, 0.6, rel)) * shade, 1.0)
             for r, tc in zip(root_c, tip_c)]
        wts = weights_at(centre)
        for card, direction in enumerate((n1, n2)):
            for side in (-0.5, 0.5):
                verts.append(centre + direction * (width * side))
                uvs.append(((cols[card] + side * 0.9 + 0.5) / columns, 1.0 - rel))
                colours.append(c)
                weights.append(wts)
    per = 4
    for k in range(len(samples) - 1):
        for card in range(2):
            a = k * per + card * 2
            b = (k + 1) * per + card * 2
            faces.append((a, a + 1, b + 1, b))
    return verts, faces, uvs, colours, weights


def build_ringlets(s: Scalp, body, arm):
    rng = np.random.default_rng(RINGLET_SEED)
    mw = body.matrix_world
    bvh = BVHTree.FromPolygons([mw @ v.co for v in body.data.vertices],
                               [list(p.vertices) for p in body.data.polygons])

    def keep(c, n):
        return (round_from_front(c) >= RINGLET_ROOT_ANGLE
                and RINGLET_ROOT_BOTTOM <= c.z <= RINGLET_ROOT_TOP)

    def frame(c, n):
        return (RINGLET_FRAME_ANGLE[0] <= round_from_front(c) < RINGLET_FRAME_ANGLE[1]
                and RINGLET_FRAME_HEIGHT[0] <= c.z <= RINGLET_FRAME_HEIGHT[1])

    roots = s.area_choice(rng, keep, RINGLET_COUNT) + s.area_choice(rng, frame, RINGLET_FRAME_COUNT)
    verts, faces, uvs, colours, weights = [], [], [], [], []
    count = 0
    for p, n in roots:
        back = smooth(RINGLET_ROOT_ANGLE, 170.0, round_from_front(p))
        lo = RINGLET_LENGTH_SIDE[0] + (RINGLET_LENGTH_BACK[0] - RINGLET_LENGTH_SIDE[0]) * back
        hi = RINGLET_LENGTH_SIDE[1] + (RINGLET_LENGTH_BACK[1] - RINGLET_LENGTH_SIDE[1]) * back
        length = float(rng.uniform(lo, hi))
        standoff = float(rng.uniform(*RINGLET_STANDOFF))
        column = int(rng.integers(0, CURL_COLUMNS))
        tone = float(rng.uniform(*RINGLET_TONE))
        samples = fall(p, n, length, standoff, bvh)
        if len(samples) < 4:
            continue
        v, f, uv, c, w = build_ringlet(samples, rng, column, tone)
        base = len(verts)
        verts += v
        faces += [tuple(i + base for i in face) for face in f]
        uvs += uv
        colours += c
        weights += w
        count += 1
    obj, tris = mesh_object("CurlRinglets", arm, verts, faces, uvs, colours, weights)
    return obj, tris, count


def main() -> int:
    paint_atlas(CARDS)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = bpy.data.objects["Body"]
    s = Scalp(body)
    cap, cap_tris = build_cap(s, arm)
    slick, slick_tris = build_slick(s, arm)
    ringlets, ringlet_tris, count = build_ringlets(s, body, arm)
    keep = (arm, cap, slick, ringlets)
    for obj in list(bpy.data.objects):
        if obj not in keep and obj.type != "EMPTY":
            bpy.data.objects.remove(obj, do_unlink=True)
    for o in bpy.context.scene.objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB",
                              use_selection=True, export_skins=True,
                              export_animations=False, export_materials="PLACEHOLDER",
                              export_vertex_color="ACTIVE", export_yup=True)
    print("kenny_curls: cap %d, slick %d, %d ringlets %d -> %d triangles, %s"
          % (cap_tris, slick_tris, count, ringlet_tris, cap_tris + slick_tris + ringlet_tris, OUT))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main())
