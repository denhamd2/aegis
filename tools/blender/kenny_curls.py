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
from mathutils import Matrix, Vector
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
## The scalp also takes the head's skin this far round (deg) and this high.
NAPE = (110.0, 1.56)

## Colours, sRGB. Measured off the sheet's hair panel (back view, under arena
## light: median (82,67,58), 90th percentile (151,121,103), 97th (187,155,123):
## red over blue 1.4-1.5) and lifted to albedo. The first pass took the tips
## to (206,168,112), red over blue 1.84, and the curls rendered ginger-orange.
ROOT = (70, 48, 32)
## The owner, 9 Nov: "Make it a bit less blonde, just some blonde highlights
## but generally a little more brown, check the references" -- the lengths
## a light brown, the platinum share (PLATINUM_*) carrying the blonde.
TIP = (184, 134, 82)
## The crown, wet and slicked: the sheet's renders at (104,70,58) under arena
## light, ours rendered (197,170,138) -- a pale helmet (the owner, 8 Nov:
## "amazingly lifelike"). The cap and the slicked strands over it are darker
## and warmer than the ringlets, which measured right (114,82,67).
CAP = (88, 64, 46)
SLICK_ROOT = (66, 48, 34)
SLICK_TIP = (150, 112, 74)
## And on top, a share of the slicked strands bleached (the three-view's
## swept-back crown is streaked blond over its dark roots).
SLICK_STREAK = (206, 166, 108)
SLICK_STREAK_SHARE = 0.45
## Per ringlet, the tip colour scaled by this (seeded): some curls dark
## dirty blond, some bright gold.
## 8 Nov, against the owner's studio three-view (gauntlet/refs/characters/
## kenny_3view.jpg): bleached, ash and golden curls over darker roots, so
## the spread is wider -- dark dirty-blond to near platinum.
RINGLET_TONE = (0.60, 1.12)

## CurlCap: off the skin by this much, more on top.
CAP_LIFT = (0.0018, 0.0035)

## CurlSlick: the part, x in metres (+X is his left).
CURL_PART = 0.022
SLICK_COUNT = 260
SLICK_STEPS = 10
SLICK_LENGTH = (0.05, 0.13)
SLICK_HALF_WIDTH = (0.006, 0.011)
## Off the cap: lying flat, wet.
## Lifted off the cap: swept back with body, not plastered (three-view).
SLICK_STANDOFF = (0.004, 0.012)
## Sideways off the part as the strands leave the hairline.
SLICK_SWEEP = 0.35
SLICK_WAVE = 0.003
SLICK_SEED = 271027

## CurlRinglets.
RINGLET_COUNT = 190
## Rooted behind the ears and round the back: at least this many degrees
## round from the front of the head, and no higher than RINGLET_ROOT_TOP.
RINGLET_ROOT_ANGLE = 104.0
RINGLET_ROOT_TOP = 1.80
RINGLET_ROOT_BOTTOM = 1.55
## And some framing the face: rooted above and just behind the temples, round
## from RINGLET_FRAME_ANGLE, falling past the ears to the shoulders -- the
## sheet's front view has curls down both sides of his face.
RINGLET_FRAME_COUNT = 60
RINGLET_FRAME_ANGLE = (92.0, 108.0)
RINGLET_FRAME_HEIGHT = (1.68, 1.82)
## Length along the fall, metres: longer at the back (onto the top of the
## back) than at the sides (onto the shoulders).
RINGLET_LENGTH_SIDE = (0.15, 0.22)
RINGLET_LENGTH_BACK = (0.16, 0.25)
## And none below this height: the owner, 25 Oct, of the last build, "His
## hair looks too big" -- it reached 1.35 m. The sheet's ends lie on the tops
## of the shoulders and the top of the back.
RINGLET_FLOOR = 1.46
## The three-view's hair stands well off his head, a full mass at the sides
## and back: further out than the first groom (0.010-0.024).
RINGLET_STANDOFF = (0.004, 0.010)
RINGLET_DRAPE = 0.30
## Outward drift per unit of fall: the lengths spread a little as they hang.
RINGLET_DRIFT = 0.05
RINGLET_SIM_STEP = 0.004
## 9-12 samples a turn at the pitch below (loop 2; 0.008 gave 6-8, kinks).
## The art director asked for 0.003; 0.004 holds the hair near 60k triangles.
## The fine path every length is resampled to (loop 9); the cards keep a
## vertex row every CLUMP_ROWS_PER_WAVE-th of their wavelength along it.
RINGLET_STEP = 0.004
CLUMP_ROWS_PER_WAVE = 9.0
CLUMP_TIGHTEN = 0.2
## Loose curls: a helix round the line, small against the clump's width.
## The three-view's are long loose waves, not tight corkscrews: wider and
## longer per turn than the first groom's (0.006-0.011, 0.034-0.055).
RINGLET_RADIUS = (0.009, 0.013)
RINGLET_PITCH = (0.060, 0.080)
RINGLET_EASE = 0.04
RINGLET_WIDTH = ((0.034, 0.046), 0.016)
## Darker where the ringlet leaves the scalp, in the shade of the hair over it.
RINGLET_ROOT_SHADE = 0.45
RINGLET_SEED = 271028
## Clump cards (loop 6): width at the root, at the tip; the S-wave's
## amplitude and wavelength (m); the arc length the atlas's v spans.
CLUMP_WIDTH = (0.017, 0.026)
CLUMP_TIP_WIDTH = 0.010
CLUMP_AMP = (0.003, 0.010)
CLUMP_WAVE = (0.045, 0.070)
CARD_V_LENGTH = 0.25
## The undercoat: wide, close, dark (layer AO 0.45).
UNDERCOAT_COUNT = 40
UNDERCOAT_WIDTH = (0.05, 0.07)
UNDERCOAT_STANDOFF = (0.003, 0.006)
UNDERCOAT_SHADE = 0.7
UNDERCOAT_SEED = 271030
## Loop 8: where a length leaves the scalp (it lifts to its standoff over
## 5 cm); and the flyaways off the outer clumps.
ROOT_LIFT = 0.004
FLYAWAY_PER_CARD = 0.35
FLYAWAY_WIDTH = (0.005, 0.005)
FLYAWAY_LENGTH = (0.08, 0.12)
FLYAWAY_SEGMENTS = 6
FLYAWAY_FLOOR = 1.44
## The lengths beside the face (round less than FRONT_ANGLE): further off the
## head, drifting out, turned toward the front by FRONT_TWIST degrees.
FRONT_ANGLE = 135.0
## The owner, 9 Nov: "make his hair a little less big, like you had it
## previously" -- the front locks stand off less, the curls swing narrower.
FRONT_STANDOFF = (0.006, 0.016)
FRONT_DRIFT = 0.12
FRONT_TWIST = (30.0, 55.0)
## Loop 9 (review 8): the front locks end at the collarbone; the back's held
## inside the shoulders' width.
FRONT_FLOOR = 1.50
BACK_CLAMP_X = 0.15
## A fifth of the clumps platinum at their crests.
PLATINUM_SHARE = 0.30
PLATINUM_TONE = (1.30, 1.50)
## Flyaways: fewer, longer, on the silhouette's sides only.
FLY_ANGLE = (80.0, 150.0)
## The crown: slicked only in front of SLICK_ANGLE; wavy clumps behind it.
SLICK_ANGLE = 70.0
CROWN_ANGLE = (70.0, 104.0)
CROWN_ABOVE = 1.80
CROWN_COUNT = 70
## The cap under it all, decimated to this share: it is hidden.
CAP_DECIMATE = 0.22

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
## Loop 6 (art director, review 5): one strip type per layer, by width
## fraction of the atlas -- the undercoat's mass, three wavy clump strips (the
## lengths: straight strands with coil detail, the S-wave is the cards'
## geometry), two tighter ringlet strips, two crown strips, one of flyaways.
STRIPS = [("mass", 0.20), ("clump", 0.13), ("clump", 0.13), ("clump", 0.13),
          ("ringlet", 0.08), ("ringlet", 0.08), ("slick", 0.07), ("slick", 0.07),
          ("fly", 0.07)]


def strip_span(kind: str, k: int) -> tuple:
    """(u0, u1) of the k-th strip of `kind` (wrapping), in atlas u."""
    total = sum(w for _, w in STRIPS)
    spans, u = [], 0.0
    for name, w in STRIPS:
        if name == kind:
            spans.append((u / total, (u + w) / total))
        u += w
    return spans[k % len(spans)]
ATLAS = (1024, 2048)
ATLAS_STRANDS = 140
ATLAS_SEED = 271029
## A share of each clump's strands are thin flyaways off its edge.
ATLAS_FLYAWAY = 0.12
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
    """The cards' atlas, rendered strip by strip (STRIPS) from 3D strands.

    Each strip is a clump of ATLAS_STRANDS strands built in 3D -- straight
    with a small coil (clump), a tighter coil (ringlet), a slow wave (slick),
    near-straight and dense (mass), sparse and thin (fly) -- projected and
    shaded per segment: Kajiya-Kay (bright where a strand runs across the
    light) and depth (the clump's back half in its own shade), drawn back to
    front. Value runs the reference's range, dark core to near-white crest.
    Alpha ramps in over the root's first 4% (no hard comb edge) and the
    strands gather into two or three tapered tips past 70%. Grey tone, the
    hue from the vertex colour; root at the top. numpy and PIL only:
    byte-identical on rebuild."""
    rng = np.random.default_rng(ATLAS_SEED)
    ss = 4
    w, h = ATLAS[0] * ss, ATLAS[1] * ss
    tone = Image.new("L", (w, h), ATLAS_GROUND)
    alpha = Image.new("L", (w, h), 0)
    dt, da = ImageDraw.Draw(tone), ImageDraw.Draw(alpha)
    light = np.array([0.45, -0.62, 0.64])
    light /= np.linalg.norm(light)
    n = 120
    total = sum(wd for _, wd in STRIPS)
    u = 0.0
    for kind, frac in STRIPS:
        x0s, width_px = u / total * w, frac / total * w
        u += frac
        centre = x0s + width_px * 0.5
        # Loop 7: the clumps' strands carry only a fine coil -- the cards'
        # geometry carries the wave, and a texture wave fought it.
        coil = {"mass": 0.04, "clump": 0.035, "ringlet": 0.08, "slick": 0.05, "fly": 0.10}[kind]
        turns = {"mass": 0.8, "clump": 9.0, "ringlet": 2.4, "slick": 1.2, "fly": 2.0}[kind]
        count = {"mass": 420, "clump": 340, "ringlet": 260, "slick": 220, "fly": 26}[kind]
        spread = width_px * (0.42 if kind in ("clump", "mass") else 0.30)
        radius = width_px * coil
        phase = float(rng.uniform(0.0, 2.0 * math.pi))
        tips = [centre + width_px * o for o in (-0.18, 0.0, 0.18)]
        segments = []
        for _ in range(count):
            dx = float(np.clip(rng.normal(0.0, 0.5), -1.0, 1.0)) * spread
            dz = float(np.clip(rng.normal(0.0, 0.5), -1.0, 1.0)) * spread * 0.6
            length = h * float(rng.uniform(0.80, 1.0) if kind != "fly" else rng.uniform(0.4, 0.9))
            ph = phase + float(rng.normal(0.0, 0.5))
            tip = tips[int(rng.integers(0, 3))]
            t = np.linspace(0.0, 1.0, n)
            ang = ph + turns * 2.0 * math.pi * t
            gather = np.clip((t - 0.85) / 0.15, 0.0, 1.0) ** 1.5 if kind != "fly" else 0.0 * t
            base = centre + dx
            x = base + (tip - base) * gather + radius * np.cos(ang)
            z = dz + radius * np.sin(ang)
            y = t * length
            if kind == "fly":
                x = x + np.cumsum(rng.normal(0.0, 0.8 * ss, n))
            pts = np.stack([x, y, z], 1)
            tan = np.gradient(pts, axis=0)
            tan /= np.maximum(np.linalg.norm(tan, axis=1, keepdims=True), 1e-6)
            kk = np.sqrt(np.clip(1.0 - (tan @ light) ** 2, 0.0, 1.0))
            depth = 0.5 + 0.5 * np.clip(z / (spread * 0.6 + radius + 1e-6), -1.0, 1.0)
            spec = (kk ** 30) * depth
            shade = np.clip(45 + 210 * kk * (0.2 + 0.8 * depth) + 40 * spec, 0, 255)
            lw = max(1, round(float(rng.uniform(0.6, 1.2) if kind != "mass" else rng.uniform(1.0, 1.8)) * ss))
            a_top = int(rng.integers(90, 150)) if kind == "fly" else int(rng.integers(200, 256))
            ramp = np.clip(t / 0.04, 0.0, 1.0) * np.clip((1.0 - t) / 0.08, 0.15, 1.0)
            for m in range(n - 1):
                segments.append((float(z[m] + z[m + 1]), (x[m], y[m], x[m + 1], y[m + 1]),
                                 int(shade[m]), lw, int(a_top * ramp[m])))
        segments.sort(key=lambda sgm: sgm[0])
        for _, (xa, ya, xb, yb), sh, wd, av in segments:
            dt.line((xa, ya, xb, yb), fill=sh, width=wd)
            da.line((xa, ya, xb, yb), fill=av, width=wd)
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.4 * ss)).resize(ATLAS, Image.LANCZOS)
    tone = tone.filter(ImageFilter.GaussianBlur(0.3 * ss)).resize(ATLAS, Image.LANCZOS)
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
            if face.material_index != head:
                remove.append(face)
                continue
            c = mw @ face.calc_center_median()
            # Loop 4: the back of the skull down to the nape too -- Cody's
            # short-hair mask stops above it, and skin showed behind the curls.
            nape = round_from_front(c) >= NAPE[0] and c.z >= NAPE[1]
            if not (scalp.is_hair(*centre) or nape):
                remove.append(face)
                continue
            # Below his receding hairline: forehead, not scalp.
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
        # Alpha: how far down its length a vertex is (0 root, 1 tip), the
        # sway's weight in hair_card.gdshader (loop 7) -- 1 where not given.
        col.data[i].color = (c[0], c[1], c[2], c[3] if len(c) > 3 else 1.0)
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
    obj, _ = mesh_object("CurlCap", arm, verts, s.faces, uvs, colours, weights)
    # Loop 9: an opaque shell under the hair needs few triangles.
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = CAP_DECIMATE
    with bpy.context.temp_override(object=obj, active_object=obj):
        bpy.ops.object.modifier_move_to_index(modifier="Decimate", index=0)
        bpy.ops.object.modifier_apply(modifier="Decimate")
    return obj, sum(len(poly.vertices) - 2 for poly in obj.data.polygons)


def build_slick(s: Scalp, arm):
    rng = np.random.default_rng(SLICK_SEED)
    verts, faces, uvs, colours, weights, normals = [], [], [], [], [], []
    # Loop 9: slicked back only over the front of the crown; behind, the
    # crown is wavy clumps (build_ringlets' CROWN roots).
    roots = s.area_choice(rng, lambda c, n: round_from_front(c) < SLICK_ANGLE, SLICK_COUNT)
    root_c, tip_c = linear(SLICK_ROOT), linear(SLICK_TIP)
    streak_c = linear(SLICK_STREAK)
    for p, n in roots:
        side = -1.0 if p.x < CURL_PART else 1.0
        length = float(rng.uniform(*SLICK_LENGTH)) * (0.6 + 0.4 * s.topness(p, n))
        half = float(rng.uniform(*SLICK_HALF_WIDTH))
        standoff = float(rng.uniform(*SLICK_STANDOFF))
        su0, su1 = strip_span("slick", int(rng.integers(0, 2)))
        tone = float(rng.uniform(*RINGLET_TONE))
        strand_tip = streak_c if rng.random() < SLICK_STREAK_SHARE else tip_c
        sweep = SLICK_SWEEP * side * float(rng.uniform(0.5, 1.2))
        wave_phase = float(rng.uniform(0.0, 2.0 * math.pi))
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
            # Loop 2: each strand S-waves sideways as it goes back (the
            # top-down reference), not a straight plank.
            centre = q + nq * standoff + across * SLICK_WAVE * t * math.sin(2.0 * math.pi * 1.5 * t + wave_phase)
            width = half * (1.0 - 0.6 * t * t)
            for k in (-1.0, 1.0):
                verts.append(centre + across * width * k)
                uvs.append((su0 + (su1 - su0) * (0.5 + 0.45 * k), 1.0 - t * 0.55))
                c = [r + (tc * tone - r) * smooth(0.0, 0.5, t) for r, tc in zip(root_c, strand_tip)] + [t]
                colours.append(c)
                weights.append(weights_at(centre))
                normals.append(nq.copy())
            q = q + d * (length / SLICK_STEPS)
        for step in range(SLICK_STEPS):
            a = start + step * 2
            faces.append((a, a + 1, a + 3, a + 2))
    return mesh_object("CurlSlick", arm, verts, faces, uvs, colours, weights, normals)


def fall(root, normal, length, standoff, bvh, drift=None, z_floor=None, clamp_x=None):
    """The ringlet's line from its root, resampled every RINGLET_STEP."""
    # Loop 8: rooted on the scalp, lifting to its standoff over 5 cm -- a
    # root set off the scalp read as a floating flap.
    p = root + normal * ROOT_LIFT
    pts = [p]
    total = 0.0
    still = 0
    slide = None
    for _ in range(4000):
        h = Vector((p.x, p.y - AXIS_Y, 0.0))
        r = h.length
        out = h / r if r > 1e-6 else Vector((0.0, 1.0, 0.0))
        off = ROOT_LIFT + (standoff - ROOT_LIFT) * smooth(0.0, 0.05, total)
        if slide is not None:
            # Pushed below the neck's top: slide down the body, no drift.
            d = Vector((0.0, 0.0, -1.0)) - slide * (-slide.z)
            d = d.normalized() if d.length > 1e-6 else Vector((0.0, 0.0, -1.0))
        else:
            d = (Vector((0.0, 0.0, -1.0)) + out * (RINGLET_DRIFT if drift is None else drift)).normalized()
        q = p + d * RINGLET_SIM_STEP
        loc, nrm, _, _ = bvh.find_nearest(q)
        if loc is not None and (q - loc).dot(nrm) < off:
            q = loc + nrm * off
            # Loop 8: an end stops only on the flat top of a shoulder, out
            # past the neck; on the traps' slope it slides on down (loop 7's
            # stop at nrm.z 0.4 caught the trapezius: a bob).
            if nrm.z > 0.75 and abs(q.x) > 0.10:
                pts.append(q)
                break
            # Loop 9: on the upper back with most of its length done, it
            # ends there, hanging, not sliding on down the back.
            if nrm.z > 0.4 and q.z < 1.52 and total >= 0.65 * length:
                pts.append(q)
                break
            if q.z < 1.60:
                slide = nrm.copy()
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
        if clamp_x is not None and abs(p.x) > clamp_x:
            p = Vector((math.copysign(clamp_x, p.x), p.y, p.z))
            pts[-1] = p
        # (z_floor: not `floor`, which the drape below reuses for a radius --
        # the shadowing let every length run past its floor.)
        if total >= length or p.z <= (RINGLET_FLOOR if z_floor is None else z_floor):
            break
        # (Loop 4 tried stopping any strand once pushed and below 1.56: the
        # push fires on the skull, so every length ended at the neck -- a bob.
        # RINGLET_FLOOR keeps the ends off the traps.)
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


def build_clump_card(samples, rng, kind, tone, shade_layer=1.0, width=None, twist=0.0):
    """A clump card on the hair's mass (art director, review 5): facing out
    from the skull's axis, tangent to the mass, its large S-wave in its own
    plane as geometry -- the coil detail is the atlas strip's. Three
    vertices across, the middle pushed out a quarter-width so it reads round.
    v by arc length (CARD_V_LENGTH), so the curl scale is the same on every
    card. Returns (verts, faces, uvs, colours, weights, normals)."""
    verts, faces, uvs, colours, weights, normals = [], [], [], [], [], []
    amp = float(rng.uniform(*CLUMP_AMP))
    wave = float(rng.uniform(*CLUMP_WAVE))
    phase = float(rng.uniform(0.0, 2.0 * math.pi))
    w0 = width if width is not None else float(rng.uniform(*CLUMP_WIDTH)) * float(rng.uniform(0.7, 1.3))
    wave_phase = phase
    u0, u1 = strip_span(kind, int(rng.integers(0, 3)))
    total = (len(samples) - 1) * RINGLET_STEP
    root_c, tip_c = linear(ROOT), linear(TIP)
    kept = 0
    last = -1.0
    for k, (p, tan) in enumerate(samples):
        s_len = k * RINGLET_STEP
        rel = s_len / total if total > 0 else 0.0
        # The curl tightens toward the ends (loop 8; a fifth, loop 9): the
        # wave's phase run up over every step of the fine path...
        local = wave * (1.0 - CLUMP_TIGHTEN * rel)
        if k:
            wave_phase += 2.0 * math.pi * RINGLET_STEP / local
        # ...and a vertex row kept every ninth of the local wavelength
        # (review 8: 2.8 rows a wave drew a sawtooth -- crimping).
        if 0 < k < len(samples) - 1 and s_len - last < local / CLUMP_ROWS_PER_WAVE:
            continue
        last = s_len
        out = Vector((p.x, p.y - AXIS_Y, 0.0))
        out = (out - tan * out.dot(tan)).normalized()
        side = tan.cross(out).normalized()
        if twist:
            # Turned about its own line (loop 7): the cards beside the face
            # show their face toward the front, not their edge -- easing in
            # over 4 cm, so the root lies on the scalp (loop 8).
            rot = Matrix.Rotation(twist * smooth(0.0, 0.04, s_len), 3, tan)
            out, side = rot @ out, rot @ side
        a = wave_phase
        ease = smooth(0.0, 0.04, s_len)
        centre = p + (side * amp * math.sin(a) + out * 0.3 * amp * math.cos(a)) * ease
        wdt = (w0 + (CLUMP_TIP_WIDTH - w0) * rel) * (0.4 + 0.6 * smooth(0.0, 0.03, s_len))
        # Loop 9: the upper third stays dark (the reference's crown and upper
        # back), the crests bright below.
        shade = (RINGLET_ROOT_SHADE + (1.0 - RINGLET_ROOT_SHADE) * smooth(0.0, 0.35, rel)) * shade_layer
        c = [min((r + (tc * tone - r) * smooth(0.10, 0.70, rel)) * shade, 1.0)
             for r, tc in zip(root_c, tip_c)] + [rel]
        wts = weights_at(centre)
        # Loop 7: the tip lands at v 0 on every card, however long (its
        # taper and gathered tips), the root wherever its length puts it.
        v = min(1.0, (total - s_len) / CARD_V_LENGTH)
        for f in (-0.5, 0.0, 0.5):
            verts.append(centre + side * (wdt * f) + out * (0.25 * wdt if f == 0.0 else 0.0))
            uvs.append((u0 + (u1 - u0) * (0.5 + f * 0.95), v))
            colours.append(c)
            weights.append(wts)
            normals.append((out + Vector((0.0, 0.0, 0.15))).normalized())
        kept += 1
    for k in range(kept - 1):
        a0, b0 = k * 3, (k + 1) * 3
        faces.append((a0, a0 + 1, b0 + 1, b0))
        faces.append((a0 + 1, a0 + 2, b0 + 2, b0 + 1))
    return verts, faces, uvs, colours, weights, normals


def build_flyaways(samples, rng, tone):
    """Loop 8 (review 7): thin stray strands off a clump -- rooted 30-90%
    down it, a centimetre out, bending away from it, on the atlas's fly
    strip. The silhouette's broken edge."""
    verts, faces, uvs, colours, weights, normals = [], [], [], [], [], []
    n = 1 if rng.random() < FLYAWAY_PER_CARD else 0
    u0, u1 = strip_span("fly", 0)
    tip_c = linear(TIP)
    for _ in range(n):
        k0 = int(len(samples) * float(rng.uniform(0.3, 0.9)))
        p, tan = samples[min(k0, len(samples) - 1)]
        out = Vector((p.x, p.y - AXIS_Y, 0.0)).normalized()
        start = p + out * 0.01
        bend = float(rng.uniform(0.4, 0.8))
        length = float(rng.uniform(*FLYAWAY_LENGTH))
        width = float(rng.uniform(*FLYAWAY_WIDTH))
        side = tan.cross(out).normalized()
        base = len(verts)
        q = start
        for j in range(FLYAWAY_SEGMENTS + 1):
            t = j / FLYAWAY_SEGMENTS
            d = (tan * (1.0 - bend * t) + out * bend * t
                 + side * float(rng.normal(0.0, 0.15))).normalized()
            if j:
                q = q + d * (length / FLYAWAY_SEGMENTS)
                # Never below his shoulders (the owner, 25 Oct: "His hair
                # looks too big"; test_kenny_model's floor).
                q = Vector((q.x, q.y, max(q.z, FLYAWAY_FLOOR)))
            c = [min(tc * tone, 1.0) for tc in tip_c] + [0.6 + 0.4 * t]
            for f in (-0.5, 0.5):
                verts.append(q + side * width * f)
                uvs.append((u0 + (u1 - u0) * (0.5 + f * 0.9), 1.0 - t * 0.6))
                colours.append(c)
                weights.append(weights_at(q))
                normals.append(out)
        for j in range(FLYAWAY_SEGMENTS):
            a0 = base + j * 2
            faces.append((a0, a0 + 1, a0 + 3, a0 + 2))
    return verts, faces, uvs, colours, weights, normals


def build_undercoat(s: Scalp, body, arm):
    """The dark undercoat under the lengths (review 5): wide mass cards close
    on the skull and neck, so no skin or ground shows between the curls, and
    the dark between them."""
    rng = np.random.default_rng(UNDERCOAT_SEED)
    mw = body.matrix_world
    bvh = BVHTree.FromPolygons([mw @ v.co for v in body.data.vertices],
                               [list(p.vertices) for p in body.data.polygons])

    def keep(c, n):
        return (round_from_front(c) >= RINGLET_ROOT_ANGLE - 6.0
                and RINGLET_ROOT_BOTTOM <= c.z <= RINGLET_ROOT_TOP)
    roots = s.area_choice(rng, keep, UNDERCOAT_COUNT)
    verts, faces, uvs, colours, weights, normals = [], [], [], [], [], []
    for p, n in roots:
        back = smooth(RINGLET_ROOT_ANGLE, 170.0, round_from_front(p))
        length = 0.85 * (RINGLET_LENGTH_SIDE[1] + (RINGLET_LENGTH_BACK[1] - RINGLET_LENGTH_SIDE[1]) * back)
        samples = fall(p, n, length, float(rng.uniform(*UNDERCOAT_STANDOFF)), bvh)
        if len(samples) < 4:
            continue
        v, f, uv, c, w, nm = build_clump_card(samples, rng, "mass", 0.62, UNDERCOAT_SHADE,
                                              float(rng.uniform(*UNDERCOAT_WIDTH)))
        base = len(verts)
        verts += v
        faces += [tuple(i + base for i in face) for face in f]
        uvs += uv
        colours += c
        weights += w
        normals += nm
    return mesh_object("CurlUndercoat", arm, verts, faces, uvs, colours, weights, normals)


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

    def crown(c, n):
        return CROWN_ANGLE[0] <= round_from_front(c) < CROWN_ANGLE[1] and c.z > CROWN_ABOVE

    roots = s.area_choice(rng, keep, RINGLET_COUNT) + s.area_choice(rng, frame, RINGLET_FRAME_COUNT) \
        + s.area_choice(rng, crown, CROWN_COUNT)
    verts, faces, uvs, colours, weights, normals = [], [], [], [], [], []
    count = 0
    for p, n in roots:
        back = smooth(RINGLET_ROOT_ANGLE, 170.0, round_from_front(p))
        lo = RINGLET_LENGTH_SIDE[0] + (RINGLET_LENGTH_BACK[0] - RINGLET_LENGTH_SIDE[0]) * back
        hi = RINGLET_LENGTH_SIDE[1] + (RINGLET_LENGTH_BACK[1] - RINGLET_LENGTH_SIDE[1]) * back
        length = float(rng.uniform(lo, hi))
        standoff = float(rng.uniform(*RINGLET_STANDOFF))
        column = int(rng.integers(0, CURL_COLUMNS))
        tone = float(rng.uniform(*RINGLET_TONE))
        if rng.random() < PLATINUM_SHARE:
            tone = float(rng.uniform(*PLATINUM_TONE))
        angle = round_from_front(p)
        front = angle < FRONT_ANGLE
        if front:
            # Loop 7: the reference's width at the jaw -- the lengths by the
            # face stand off and spread, and turn their faces forward.
            standoff = float(rng.uniform(*FRONT_STANDOFF))
        samples = fall(p, n, length, standoff, bvh, FRONT_DRIFT if front else None,
                       FRONT_FLOOR if front else None, None if front else BACK_CLAMP_X)
        if len(samples) < 4:
            continue
        twist = 0.0
        if front:
            twist = math.radians(float(rng.uniform(*FRONT_TWIST))) * (1.0 if p.x > 0.0 else -1.0)
        v, f, uv, c, w, nm = build_clump_card(samples, rng, "clump" if count % 5 else "ringlet",
                                              tone, twist=twist)
        fv, ff, fuv, fc, fw, fnm = build_flyaways(samples, rng, tone) \
            if FLY_ANGLE[0] <= angle < FLY_ANGLE[1] else ([], [], [], [], [], [])
        off_v = len(v)
        v += fv
        f += [tuple(i + off_v for i in face) for face in ff]
        uv += fuv
        c += fc
        w += fw
        nm += fnm
        base = len(verts)
        verts += v
        faces += [tuple(i + base for i in face) for face in f]
        uvs += uv
        colours += c
        weights += w
        normals += nm
        count += 1
    obj, tris = mesh_object("CurlRinglets", arm, verts, faces, uvs, colours, weights, normals)
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
    under, under_tris = build_undercoat(s, body, arm)
    keep = (arm, cap, slick, ringlets, under)
    for obj in list(bpy.data.objects):
        if obj not in keep and obj.type != "EMPTY":
            bpy.data.objects.remove(obj, do_unlink=True)
    for o in bpy.context.scene.objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB",
                              use_selection=True, export_skins=True,
                              export_animations=False, export_materials="PLACEHOLDER",
                              export_vertex_color="ACTIVE", export_yup=True)
    print("kenny_curls: cap %d, slick %d, undercoat %d, %d clumps %d -> %d triangles, %s"
          % (cap_tris, slick_tris, under_tris, count, ringlet_tris,
             cap_tris + slick_tris + under_tris + ringlet_tris, OUT))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main())
