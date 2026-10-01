#!/usr/bin/env python3
"""Roman Reigns's hanging hair, as wet ringlets on his own hair chains.

The supplied model's hair hangs as one layered sheet of cards. In the owner's
photos of him (Oct 2026) his hair, wet and slicked off the face, falls past
the shoulders as SEPARATE ringlets -- corkscrew clumps with gaps between them
-- and no edit of the supplied cards (lift, thinning, wave) separated the
sheet: they are overlapping layers. So the hanging lengths are rebuilt here
as new geometry (character_aaa_plan.md R1b), and RomanModel cuts the supplied
sheet away below the nape for them.

Run:  python3 tools/blender/roman_ringlets.py
Writes game/assets/characters/roman_ringlets.glb and roman_reigns_ringlets_alpha.png.

How:
* WHERE a ringlet hangs comes from his body, not the rig: it starts at
  RINGLET_TOP (just above the nape, under the slicked crown cards) and falls
  down the back of his head and neck onto his upper back at a standoff of its
  own, found by casting rays at the head and body meshes. Hair does not
  follow the hollow of the nape -- it falls from the bulge of the skull -- so
  the line may come back toward the body only RINGLET_DRAPE metres per metre
  of fall. (The first build hung them along the hair bone chains themselves,
  which sit ~17 cm behind his head: they plumed out behind him.)
* HOW it moves comes from the rig: the 18 hair bone chains (Hair_b00..b17)
  that RomanModel's SpringBoneSimulator3D drives. Each ringlet belongs to a
  chain, and each cross-section is weighted to that chain's bones by height,
  blended between neighbours; lower down, a share goes to J_Chest
  (RINGLET_BODY_SHARE), so the lengths lying on his back follow his torso and
  the springs cannot swing them through it.
* Each ringlet is a clump that coils: its centre winds round its line on a
  helix (radius, pitch and phase per ringlet, easing in from straight over
  RINGLET_EASE so it leaves the slick smoothly), and its cross-section is two
  crossed strand cards -- reading as a round clump from any side, the
  standard game construction for a curl. The cards keep their facing; only
  the centre coils.
* Skinned to the chain's own bones by where each cross-section falls along
  the chain (blended between neighbouring bones), and to the chain's last
  bone past its end, so the springs swing the ringlets with no new rig.
* The strand texture is painted here: clumps of fine strands that converge
  toward the tip, as a wet ringlet does, in RINGLET_COLUMNS variants; the two
  cards of a ringlet use different columns.

Deterministic: same inputs, byte-identical outputs.
"""

from __future__ import annotations

import math
import os
import pathlib
import sys

import bpy  # noqa: E402  (first: it provides mathutils)
import numpy as np
from mathutils import Vector
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import bpy_exit  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[2]
SOURCE = REPO / "game/assets/characters/roman_reigns.glb"
OUT = REPO / "game/assets/characters/roman_ringlets.glb"
STRANDS = REPO / "game/assets/characters/roman_reigns_ringlets_alpha.png"
ARMATURE = "roman"
CHAINS = ["Hair_b%02d" % i for i in range(18)]

## Blender space (Z up, -Y forward): the head's back is +Y.
## Ringlets start where their chain passes this height -- above the nape,
## under the slicked crown cards, so they emerge from the hair rather than
## starting on an edge. RomanModel.RINGLET_SHEET_CUT (1.58) cuts the supplied
## sheet a little lower, so the two overlap and no seam shows.
RINGLET_TOP = 1.64
## Ringlet length: down to this height (Godot y), seeded per ringlet. The
## photos have his ends on the upper back and the tops of the shoulders.
RINGLET_END = (1.18, 1.32)
## Off the skin, per ringlet: the hair lies in a few layers, not one.
RINGLET_STANDOFF = (0.010, 0.030)
## How fast (metres per metre of fall) the line may come back toward the
## body: it falls from the skull's bulge instead of into the nape's hollow.
RINGLET_DRAPE = 0.35
## The share of J_Chest in the weights, rising from 0 at RINGLET_BODY_Y[0]
## to RINGLET_BODY_SHARE at [1] (Godot y).
RINGLET_BODY_SHARE = 0.6
RINGLET_BODY_Y = (1.50, 1.36)
## How many, and where across his back: spread evenly over RINGLET_ACROSS
## at the top (jittered by RINGLET_SPREAD), fanning out by RINGLET_FAN per
## metre of fall over the trapezius. Placed by the chains' own positions they
## bunched into two strips (the chains converge behind the skull); 45 read as
## chain-link. Each takes its weights from the chain nearest it at the top.
RINGLET_COUNT = 30
RINGLET_ACROSS = (-0.11, 0.11)
RINGLET_SPREAD = 0.008
RINGLET_FAN = 0.9
## A wet ringlet is a dense clump with a wave in it, not a wire spring: the
## coil is small against the card's width. At radius 8-12 mm on 18-26 mm
## cards the second build read as springs.
RINGLET_RADIUS = (0.006, 0.010)
RINGLET_PITCH = (0.050, 0.070)
RINGLET_EASE = 0.06
## Card width at the top and at the tip; the clump tapers to a point.
RINGLET_WIDTH = ((0.022, 0.030), 0.007)
RINGLET_STEP = 0.007
RINGLET_SEED = 29
RINGLET_ROOT_SHADE = 0.6

RINGLET_COLUMNS = 4
RINGLET_TEX = (512, 2048)
RINGLET_TEX_STRANDS = 90
RINGLET_TEX_SEED = 23


def smooth(a: float, b: float, x: float) -> float:
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def paint_strands(target: pathlib.Path) -> None:
    """White RGB, strands in alpha: RINGLET_COLUMNS clumps, each of fine wavy
    strands drawn from the top (root) down, converging toward the column's
    centre at the tip and thinning out over the last quarter."""
    rng = np.random.default_rng(RINGLET_TEX_SEED)
    ss = 2
    w, h = RINGLET_TEX[0] * ss, RINGLET_TEX[1] * ss
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    col = w // RINGLET_COLUMNS
    for c in range(RINGLET_COLUMNS):
        centre = c * col + col * 0.5
        for _ in range(RINGLET_TEX_STRANDS):
            x0 = centre + col * 0.42 * float(np.clip(rng.normal(0.0, 0.45), -1.0, 1.0))
            length = h * float(rng.uniform(0.72, 1.0))
            amp = float(rng.uniform(1.5, 5.0)) * ss
            phase = float(rng.uniform(0.0, 2.0 * math.pi))
            freq = float(rng.uniform(3.0, 6.0))
            pts = []
            for t in np.linspace(0.0, 1.0, 72):
                x = x0 + (centre - x0) * 0.65 * t * t + amp * math.sin(phase + freq * 2.0 * math.pi * t)
                pts.append((x, t * length))
            draw.line(pts, fill=int(rng.integers(170, 256)),
                      width=max(1, round(float(rng.uniform(1.5, 2.6)) * ss)))
    mask = mask.filter(ImageFilter.GaussianBlur(0.6 * ss)).resize(RINGLET_TEX, Image.LANCZOS)
    out = Image.new("RGBA", RINGLET_TEX, (255, 255, 255, 0))
    out.putalpha(mask)
    out.save(target, optimize=True)


def chain_path(arm, name: str):
    """Points down the chain (bone heads, then the last tail), world space,
    and the bone names: bone i spans points i..i+1."""
    bones = [arm.data.bones[name]]
    while bones[-1].children:
        bones.append(sorted(bones[-1].children, key=lambda b: b.name)[0])
    pts = [arm.matrix_world @ b.head_local for b in bones]
    pts.append(arm.matrix_world @ bones[-1].tail_local)
    return pts, [b.name for b in bones]


def body_path(chain: list, x_top: float, end_z: float, standoff: float, bvh):
    """The ringlet's line, top to bottom: (point, tangent, z) samples every
    RINGLET_STEP of height from RINGLET_TOP to end_z, fanning out from x_top,
    behind the body (+Y) at `standoff` off whatever the ray from behind hits
    first."""
    zs = []
    z = RINGLET_TOP
    while z >= end_z:
        zs.append(z)
        z -= RINGLET_STEP
    ys = []
    last = None
    xs = [x_top * (1.0 + RINGLET_FAN * (RINGLET_TOP - z)) for z in zs]
    for x, z in zip(xs, zs):
        hit = bvh.ray_cast(Vector((x, 0.6, z)), Vector((0.0, -1.0, 0.0)))[0]
        y = hit.y + standoff if hit is not None else last
        if y is None:
            # Nothing behind him at this x yet (wide of the head): start at
            # the chain's own depth.
            y = chain_y(chain, z)
        if last is not None:
            y = max(y, last - RINGLET_DRAPE * RINGLET_STEP)
        ys.append(y)
        last = y
    pts = [Vector((x, y, z)) for x, y, z in zip(xs, ys, zs)]
    out = []
    for i, p in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        out.append((p, (b - a).normalized(), p.z))
    return out


def chain_y(chain: list, z: float) -> float:
    for a, b in zip(chain, chain[1:]):
        if a.z >= z >= b.z and a.z > b.z:
            return a.y + (b.y - a.y) * (a.z - z) / (a.z - b.z)
    return chain[-1].y


def chain_weights(chain: list, bones: list, z: float) -> list:
    """[(bone, weight)] for a cross-section at height z: the chain's bones by
    height, blended between neighbours, the last bone past its end, and
    J_Chest's share lower down."""
    wts = [(bones[-1], 1.0)]
    for i, (a, b) in enumerate(zip(chain, chain[1:])):
        if a.z >= z >= b.z and a.z > b.z:
            t = (a.z - z) / (a.z - b.z)
            here = bones[i]
            nxt = bones[i + 1] if i + 1 < len(bones) else here
            wts = [(here, 1.0 - t), (nxt, t)] if nxt != here else [(here, 1.0)]
            break
        if z > chain[0].z:
            wts = [(bones[0], 1.0)]
            break
    body = RINGLET_BODY_SHARE * (1.0 - smooth(RINGLET_BODY_Y[1], RINGLET_BODY_Y[0], z))
    out = [(name, w * (1.0 - body)) for name, w in wts]
    if body > 0.0:
        out.append(("J_Chest", body))
    return out


def build_ringlet(samples, chain: list, bones: list, rng, column: int):
    """Vertices, faces, uvs, shades and per-vertex [(bone, weight)] of one
    ringlet: two crossed cards twisting round a helix about the samples."""
    verts, faces, uvs, shades, weights = [], [], [], [], []
    radius = float(rng.uniform(*RINGLET_RADIUS))
    pitch = float(rng.uniform(*RINGLET_PITCH))
    phase = float(rng.uniform(0.0, 2.0 * math.pi))
    w_top = float(rng.uniform(*RINGLET_WIDTH[0]))
    total = (len(samples) - 1) * RINGLET_STEP
    t0 = samples[0][1]
    n1 = Vector((1.0, 0.0, 0.0))
    n1 = (n1 - t0 * n1.dot(t0)).normalized()
    cols = (column, (column + 1) % RINGLET_COLUMNS)
    for k, (p, tan, z) in enumerate(samples):
        n1 = (n1 - tan * n1.dot(tan)).normalized()
        n2 = tan.cross(n1)
        s = k * RINGLET_STEP
        rel = s / total if total > 0 else 0.0
        phi = 2.0 * math.pi * s / pitch + phase
        radial = n1 * math.cos(phi) + n2 * math.sin(phi)
        centre = p + radial * (radius * smooth(0.0, RINGLET_EASE, s))
        width = (w_top + (RINGLET_WIDTH[1] - w_top) * rel ** 1.5) * (0.5 + 0.5 * smooth(0.0, 0.03, s))
        shade = RINGLET_ROOT_SHADE + (1.0 - RINGLET_ROOT_SHADE) * smooth(0.0, 0.15, rel)
        wts = chain_weights(chain, bones, z)
        # The cards keep their facing down the length; only the centre
        # coils. Twisting them with the coil turned each card edge-on every
        # half pitch and the clump read as a diamond-chain of flickers.
        for card, direction in enumerate((n1, n2)):
            for side in (-0.5, 0.5):
                verts.append(centre + direction * (width * side))
                u = (cols[card] + side + 0.5) / RINGLET_COLUMNS
                uvs.append((u, 1.0 - rel))
                shades.append(shade)
                weights.append(wts)
    per = 4
    for k in range(len(samples) - 1):
        for card in range(2):
            a = k * per + card * 2
            b = (k + 1) * per + card * 2
            faces.append((a, a + 1, b + 1, b))
    return verts, faces, uvs, shades, weights


def chain_x(chain: list) -> float:
    """The chain's side-to-side position where the ringlet starts."""
    for a, b in zip(chain, chain[1:]):
        if a.z >= RINGLET_TOP >= b.z and a.z > b.z:
            return a.x + (b.x - a.x) * (a.z - RINGLET_TOP) / (a.z - b.z)
    return chain[-1].x


def body_bvh():
    """A BVH of the head and body meshes as posed in the file (bind pose), in
    world space -- what the ringlets fall against."""
    from mathutils.bvhtree import BVHTree
    verts, polys = [], []
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.data.name not in ("M_Head", "M_Body"):
            continue
        base = len(verts)
        verts += [obj.matrix_world @ v.co for v in obj.data.vertices]
        polys += [[base + i for i in p.vertices] for p in obj.data.polygons]
    return BVHTree.FromPolygons(verts, polys)


def main() -> int:
    paint_strands(STRANDS)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    arm = bpy.data.objects[ARMATURE]
    for obj in list(bpy.data.objects):
        if obj != arm and obj.type == "MESH" and obj.data.name not in ("M_Head", "M_Body"):
            bpy.data.objects.remove(obj, do_unlink=True)
    bvh = body_bvh()
    rng = np.random.default_rng(RINGLET_SEED)
    verts, faces, uvs, shades, weights = [], [], [], [], []
    count = 0
    chains = [chain_path(arm, name) for name in CHAINS]
    for i in range(RINGLET_COUNT):
        x = RINGLET_ACROSS[0] + (RINGLET_ACROSS[1] - RINGLET_ACROSS[0]) * (i + 0.5) / RINGLET_COUNT
        x += float(rng.uniform(-RINGLET_SPREAD, RINGLET_SPREAD))
        chain, bones = min(chains, key=lambda cb: abs(chain_x(cb[0]) - x))
        end_z = float(rng.uniform(*RINGLET_END))
        standoff = float(rng.uniform(*RINGLET_STANDOFF))
        samples = body_path(chain, x, end_z, standoff, bvh)
        if len(samples) < 4:
            continue
        v, f, uv, sh, wt = build_ringlet(samples, chain, bones, rng,
                                         int(rng.integers(0, RINGLET_COLUMNS)))
        base = len(verts)
        verts += v
        faces += [tuple(i + base for i in face) for face in f]
        uvs += uv
        shades += sh
        weights += wt
        count += 1
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    mesh = bpy.data.meshes.new("RomanRinglets")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            uv_layer.data[li].uv = uvs[mesh.loops[li].vertex_index]
    shade = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, s in enumerate(shades):
        shade.data[i].color = (s, s, s, 1.0)
    mesh.materials.append(bpy.data.materials.new("RomanRinglets"))
    obj = bpy.data.objects.new("RomanRinglets", mesh)
    bpy.context.scene.collection.objects.link(obj)
    groups = {}
    for i, wts in enumerate(weights):
        for bone, w in wts:
            if w <= 0.0:
                continue
            if bone not in groups:
                groups[bone] = obj.vertex_groups.new(name=bone)
            groups[bone].add([i], w, "REPLACE")
    # The armature carries a scale (1.035); the vertices are already in world
    # space, so parent without letting it apply twice.
    obj.parent = arm
    obj.matrix_parent_inverse = arm.matrix_world.inverted()
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    for o in bpy.context.scene.objects:
        o.select_set(o in (obj, arm) or o.type == "EMPTY")
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB",
                              use_selection=True, export_skins=True,
                              export_animations=False, export_materials="PLACEHOLDER",
                              export_vertex_color="ACTIVE", export_yup=True)
    print("roman_ringlets: %d ringlets, %d triangles -> %s" % (count, 2 * len(faces), OUT))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main())
