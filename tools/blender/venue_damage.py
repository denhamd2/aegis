#!/usr/bin/env python3
"""Damaged versions of the venue, for the rocket launcher (the owner, 19 Oct:
"The rocket launcher should cause permanent damage to whatever it hits ...
create damaged model versions of each of these").

Run:  python3 tools/blender/venue_damage.py

  game/assets/environment/venue_damage.glb, one root per piece:

  BarricadePanel_Damaged  one ringside panel (BARRICADE_PANEL wide, as
                          ringside.py builds them) blown open in the middle:
                          two halves torn and bent away from the blast, the
                          cap rail snapped, the brace buckled, shards at its
                          foot. Origin on the floor at the panel's centre,
                          +X along it, +Z out (toward the crowd).
  CommentaryDesk_Damaged  the announce desk (DESK_*) broken in the middle:
                          the worktop snapped into a V, the body caved in,
                          the LED face shattered, a monitor knocked flat and
                          one hanging off the front. Origin on the riser at
                          the desk's centre, +X along it, +Z its back.
  RingPost_Damaged        a corner after a hit: the post scorched and
                          leaning out a few degrees -- the ropes stay tied to
                          it -- its three pads blown off (one hanging by its
                          strap, two on the floor), the turnbuckle rods bare.
                          Origin at the post's foot, +Z out along the corner
                          diagonal.
  RingApron_Damaged       a section of apron skirt with a hole blown through
                          it: ragged charred edges, flaps hanging, the ring's
                          steel frame dark behind. Laid over the skirt; origin
                          on the floor at the section's centre, +Z out.
  RingSteps_Damaged       a set of steel steps crushed and twisted, a tread
                          torn away. Origin on the floor at the footprint's
                          centre, +Z along the run, out from the ring.
  LedWall_Smashed         a patch of LED wall where a rocket went in: the
                          middle tiles gone to the black cabinet behind (its
                          frame bars and hanging cables), a ring of cracked,
                          dead, skewed tiles, scorch round it. Laid over the
                          screen; origin on the screen's face at the impact,
                          +Z out of the screen.
  Rubble                  broken plates and chunks to scatter where a blast
                          lands. Origin on the floor at the centre.

Sizes are read out of arena_builder.gd / ring_builder.gd (venue.read_constants)
so a damaged piece fits the place of the one it replaces. Deterministic: every
irregularity comes from a seeded RandomState, no clock.
"""

from __future__ import annotations

import math
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "weapons"))
import venue  # noqa: E402
import weapon_kit as kit  # noqa: E402
from weapon_kit import Vector  # noqa: E402

import bpy  # noqa: E402
import numpy as np  # noqa: E402

OUT = venue.ASSET_DIR / "venue_damage.glb"
TEX = venue.ASSET_DIR / "damage_textures"

ARENA = venue.read_constants(venue.ARENA_GD, [
    "BARRICADE_HEIGHT", "BARRICADE_PANEL", "BARRICADE_JOIN",
    "DESK_LENGTH", "DESK_HEIGHT", "DESK_DEPTH", "DESK_TOP_THICKNESS", "DESK_TOP_OVERHANG",
    "DESK_LED_HEIGHT", "DESK_MONITOR_WIDTH", "DESK_MONITOR_HEIGHT", "DESK_MONITOR_DEPTH",
])
RING = venue.read_constants(venue.RING_GD, [
    "POST_RADIUS", "POST_BOTTOM", "POST_TOP", "TURNBUCKLE_PAD_WIDTH", "TURNBUCKLE_PAD_HEIGHT",
    "TURNBUCKLE_PAD_DEPTH", "APRON_TOP", "APRON_BOTTOM", "STEP_WIDTH", "STEP_RUN",
    "STEP_PLATFORM", "STEP_TOP_Y", "STEP_FLOOR_Y", "ROPE_HEIGHT_BOTTOM", "ROPE_HEIGHT_MIDDLE",
    "ROPE_HEIGHT_TOP",
])
STEP_TREADS = 4


# --- textures ----------------------------------------------------------------

def charred_textures(name: str, paint: tuple, burn: float) -> tuple:
    """Painted panel burnt by a blast: the paint `paint` blistered to black
    toward the middle (v = 0.5, u = 0.5 of the unwrap) and at the torn
    edges, soot streaks, bare metal where the paint flaked."""
    rng = np.random.RandomState(kit.seed_of(name + "_char"))
    n = 512
    big = kit.fbm(rng, n, 5, 4)
    fine = kit.fbm(rng, n, 48, 3)
    yy, xx = np.mgrid[0:n, 0:n] / float(n)
    centre = np.clip(1.0 - np.hypot(xx - 0.5, yy - 0.5) * 2.0, 0, 1)
    char = np.clip((centre * burn + big * 0.6 - 0.35) * 2.2, 0, 1)
    base = np.array(paint, np.float32)[None, None] * (0.85 + 0.25 * fine[..., None])
    soot = np.array([0.025, 0.022, 0.02], np.float32)
    ember = np.array([0.32, 0.12, 0.04], np.float32)
    rim = np.clip(1.0 - np.abs(char - 0.55) * 6.0, 0, 1) * 0.35
    out = base * (1 - char[..., None]) + soot * char[..., None] + ember * rim[..., None]
    flake = np.clip((kit.fbm(rng, n, 24, 3) - 0.72) * 6.0, 0, 1) * (1 - char)
    out = out * (1 - flake[..., None]) + np.array([0.35, 0.34, 0.33]) * flake[..., None]
    rough = 0.55 + 0.4 * char - 0.2 * flake
    orm = np.stack([1.0 - 0.4 * char, np.clip(rough, 0, 1), flake * 0.8], -1)
    nrm = kit.normal_from_height(big * 0.4 + fine * 0.3 - char * 0.2, 4.0)
    TEX.mkdir(parents=True, exist_ok=True)
    kit.save_rgb(np.clip(out, 0, 0.85), TEX / f"{name}_base.png")
    kit.save_rgb(orm, TEX / f"{name}_orm.png")
    kit.save_rgb(nrm, TEX / f"{name}_normal.png")
    return TEX / f"{name}_base.png", TEX / f"{name}_orm.png", TEX / f"{name}_normal.png"


def cracked_led_texture(name: str) -> tuple:
    """Dead LED tiles: a black face with the pixel grid faintly showing,
    spider cracks catching the light, and soot."""
    rng = np.random.RandomState(kit.seed_of(name + "_led"))
    n = 512
    yy, xx = np.mgrid[0:n, 0:n]
    grid = (((xx % 6) < 2) & ((yy % 6) < 2)).astype(np.float32) * 0.035
    base = np.stack([grid * 0.8, grid * 0.8, grid * 1.1], -1) + 0.012
    from PIL import Image, ImageDraw
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    for _ in range(9):
        cx, cy = rng.uniform(0, n), rng.uniform(0, n)
        for _k in range(rng.randint(5, 9)):
            ang = rng.uniform(0, 2 * math.pi)
            x, y = cx, cy
            for _s in range(rng.randint(4, 9)):
                ang += rng.uniform(-0.5, 0.5)
                nx, ny = x + math.cos(ang) * rng.uniform(10, 34), y + math.sin(ang) * rng.uniform(10, 34)
                d.line([x, y, nx, ny], fill=int(rng.uniform(120, 230)), width=2)
                x, y = nx, ny
    cracks = np.asarray(img, np.float32) / 255.0
    soot = np.clip(kit.fbm(rng, n, 6, 4) - 0.4, 0, 1)
    base = base * (1 - soot[..., None] * 0.8) + cracks[..., None] * 0.22
    rough = 0.25 + 0.5 * soot + 0.2 * cracks
    orm = np.stack([np.ones_like(rough), np.clip(rough, 0, 1), np.zeros_like(rough)], -1)
    nrm = kit.normal_from_height(cracks * 0.8 - soot * 0.2, 3.0)
    TEX.mkdir(parents=True, exist_ok=True)
    kit.save_rgb(np.clip(base, 0, 0.85), TEX / f"{name}_base.png")
    kit.save_rgb(orm, TEX / f"{name}_orm.png")
    kit.save_rgb(nrm, TEX / f"{name}_normal.png")
    return TEX / f"{name}_base.png", TEX / f"{name}_orm.png", TEX / f"{name}_normal.png"


# --- helpers -----------------------------------------------------------------

def rot_y(v: Vector, deg: float) -> Vector:
    a = math.radians(deg)
    return Vector((v.x * math.cos(a) + v.z * math.sin(a), v.y, -v.x * math.sin(a) + v.z * math.cos(a)))


def tilted_box(part, centre: Vector, size: Vector, yaw: float, pitch: float, roll: float,
               bevel: float = 0.0) -> None:
    """A box turned by yaw (about Y), then pitch (about its X), then roll (its Z)."""
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    cr, sr = math.cos(math.radians(roll)), math.sin(math.radians(roll))
    x = Vector((cy, 0.0, -sy))
    z = Vector((sy, 0.0, cy))
    y = Vector((0.0, 1.0, 0.0))
    y, z = y * cp + z * sp, z * cp - y * sp
    x, y = x * cr + y * sr, y * cr - x * sr
    venue_box(part, centre, (x, y, z), size, bevel)


def venue_box(part, centre: Vector, axes: tuple, size: Vector, bevel: float = 0.0) -> None:
    ex, ey, ez = axes[0] * (size.x * 0.5), axes[1] * (size.y * 0.5), axes[2] * (size.z * 0.5)
    corners = [centre + ex * sx + ey * sy + ez * sz for sx, sy, sz in
               ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1),
                (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1))]
    faces = ((0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7))
    if bevel > 0.0:
        part._beveled(corners, faces, bevel, 1)
        return
    v = [part.vert(c) for c in corners]
    for f in faces:
        part.quad(*[v[i] for i in f])


def ragged_sheet(part, w: float, h: float, thickness: float, nu: int, nv: int, hole,
                 shape) -> None:
    """A sheet w x h in the XY plane centred on x = 0, y from 0, with every
    cell whose centre `hole(s, t)` says is gone left out, and each vertex
    moved by `shape(p, s, t)` -- the tear, the bend. Closed round every cell
    so the torn edges have thickness."""
    half = thickness * 0.5
    for j in range(nv):
        for i in range(nu):
            s0, s1, t0, t1 = i / nu, (i + 1) / nu, j / nv, (j + 1) / nv
            if hole((s0 + s1) * 0.5, (t0 + t1) * 0.5):
                continue
            pts = []
            for s, t in ((s0, t0), (s1, t0), (s1, t1), (s0, t1)):
                pts.append(shape(Vector(((s - 0.5) * w, t * h, 0.0)), s, t))
            front = [part.vert(p + Vector((0, 0, half))) for p in pts]
            back = [part.vert(p - Vector((0, 0, half))) for p in pts]
            part.quad(*front, [(s0, t0), (s1, t0), (s1, t1), (s0, t1)])
            part.quad(back[3], back[2], back[1], back[0])
            for k in range(4):
                m = (k + 1) % 4
                part.quad(front[k], back[k], back[m], front[m])


def export(out: pathlib.Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out), export_format="GLB", export_apply=True, export_yup=True,
        use_selection=False, export_cameras=False, export_lights=False,
        export_materials="EXPORT", export_image_format="AUTO", export_extras=True)


# --- the pieces ---------------------------------------------------------------

def build_barricade(root, panel_mat, steel_mat) -> None:
    rng = np.random.RandomState(kit.seed_of("barricade_damaged"))
    w = ARENA["BARRICADE_PANEL"] - ARENA["BARRICADE_JOIN"]
    h = ARENA["BARRICADE_HEIGHT"]
    t = 0.14
    jag = rng.uniform(-0.08, 0.08, 64)

    def hole(s: float, tt: float) -> bool:
        # the blast hole: an ellipse round the middle, low, with a jagged rim
        k = int(tt * 63)
        dx = (s - 0.5 + jag[k] * 0.6) / 0.22
        dy = (tt - 0.42) / 0.55
        return dx * dx + dy * dy < 1.0

    def shape(p: Vector, s: float, tt: float) -> Vector:
        # torn edges peeled away from the blast (+Z), the top folded over,
        # the whole panel sagging toward the hole
        near = max(0.0, 1.0 - abs(s - 0.5) / 0.32)
        q = Vector(p)
        q.z += near * near * 0.42 * (0.6 + 0.4 * tt)
        q.y -= near * 0.10 * tt
        q.x += math.copysign(near * 0.07, s - 0.5)
        return q

    part = kit.WeaponPart(root.name + "_panel")
    ragged_sheet(part, w, h - 0.07, t, 24, 12, hole, shape)
    kit.add_mesh(root, part, panel_mat, uv_scale=1.0, auto_smooth_deg=35.0)
    frame = kit.WeaponPart(root.name + "_frame")
    # the cap rail, snapped at the hole, each half bent up and out
    for side in (-1.0, 1.0):
        pts = []
        for k in range(9):
            u = k / 8.0
            x = side * (w * 0.5 - u * (w * 0.5 - 0.18))
            near = max(0.0, 1.0 - abs(x) / (w * 0.32))
            pts.append(Vector((x, h - 0.035 + near * 0.12, near * near * 0.55)))
        frame.tube(pts, 0.048, sides=8)
    # the brace behind the middle, buckled
    frame.tube([Vector((0.25, h - 0.3, 0.05)), Vector((0.32, 0.55, 0.36)),
                Vector((0.18, 0.28, 0.30)), Vector((0.12, 0.02, 0.42))], 0.028, sides=6)
    kit.add_mesh(root, frame, steel_mat, uv_scale=4.0, auto_smooth_deg=50.0)
    shards = kit.WeaponPart(root.name + "_shards")
    for i in range(7):
        tilted_box(shards, Vector((rng.uniform(-0.6, 0.6), 0.012, rng.uniform(0.2, 1.1))),
                   Vector((rng.uniform(0.08, 0.24), 0.012, rng.uniform(0.06, 0.18))),
                   rng.uniform(0, 180), rng.uniform(-8, 8), rng.uniform(-8, 8))
    kit.add_mesh(root, shards, panel_mat, uv_scale=2.0, auto_smooth_deg=30.0)


def build_desk(root, body_mat, top_mat, led_mat, plastic_mat) -> None:
    rng = np.random.RandomState(kit.seed_of("desk_damaged"))
    length, depth = ARENA["DESK_LENGTH"], ARENA["DESK_DEPTH"]
    height, thick = ARENA["DESK_HEIGHT"], ARENA["DESK_TOP_THICKNESS"]
    over = ARENA["DESK_TOP_OVERHANG"]
    gap = 0.34                                    # the broken middle
    body = kit.WeaponPart(root.name + "_body")
    body_h = height - thick
    for side in (-1.0, 1.0):
        # each half's body, its inner end crushed down toward the break
        x0, x1 = side * gap, side * (length * 0.5 - 0.04)

        def crush(p: Vector, s0=x0, s1=x1) -> Vector:
            u = (p.x - s0) / (s1 - s0)                    # 0 at the break
            q = Vector(p)
            q.y *= 0.42 + 0.58 * min(1.0, u * 1.6)
            q.z += (1.0 - min(1.0, u * 2.0)) * 0.08 * (q.y / max(body_h, 0.01))
            return q
        half = kit.WeaponPart(root.name + "_b%d" % int(side), deform=crush)
        half.grid_panel(Vector((min(x0, x1), 0.0, -depth * 0.5)), Vector((abs(x1 - x0), 0, 0)),
                        Vector((0, body_h, 0)), 10, 4, 0.03)
        half.grid_panel(Vector((min(x0, x1), 0.0, depth * 0.5)), Vector((abs(x1 - x0), 0, 0)),
                        Vector((0, body_h, 0)), 10, 4, 0.03)
        half.box(Vector((side * (length * 0.5 - 0.03), body_h * 0.5, 0.0)),
                 Vector((0.06, body_h, depth + 0.04)), bevel=0.01)
        kit.add_mesh(root, half, body_mat, uv_scale=1.0, auto_smooth_deg=35.0)
        # the worktop slab, hinged at the outer end and dropped into the V
        slab_len = length * 0.5 + over - gap * 0.6
        drop = 13.0 + rng.uniform(-2, 2)
        cx = side * (gap * 0.6 + slab_len * 0.5)
        cy = height - thick * 0.5 - math.sin(math.radians(drop)) * slab_len * 0.5 - 0.03
        tilted_box(body if False else top_part(root, side), Vector((cx, cy, rng.uniform(-0.03, 0.03))),
                   Vector((slab_len, thick, depth + over * 2.0)), rng.uniform(-3, 3), 0.0,
                   side * -drop, bevel=0.015)
    # what fell through the middle: broken panels and the LED face's pieces
    for i in range(6):
        tilted_box(body, Vector((rng.uniform(-gap, gap), rng.uniform(0.05, 0.3), rng.uniform(-0.3, 0.3))),
                   Vector((rng.uniform(0.2, 0.45), 0.025, rng.uniform(0.15, 0.4))),
                   rng.uniform(0, 180), rng.uniform(-40, 40), rng.uniform(-40, 40))
    kit.add_mesh(root, body, body_mat, uv_scale=1.0, auto_smooth_deg=35.0)
    led = kit.WeaponPart(root.name + "_led")
    led_h = ARENA["DESK_LED_HEIGHT"]
    tiles = 14
    tile_w = (length - 0.14) / tiles
    for i in range(tiles):
        x = -length * 0.5 + 0.07 + (i + 0.5) * tile_w
        if abs(x) < gap * 0.8:
            continue                                   # blown out
        near = max(0.0, 1.0 - abs(x) / (length * 0.32))
        sag = near * 0.25
        tilted_box(led, Vector((x, 0.12 + led_h * 0.5 - sag * 0.6, -depth * 0.5 - 0.02 - near * 0.06)),
                   Vector((tile_w - 0.01, led_h * (1.0 - near * 0.3), 0.012)),
                   rng.uniform(-4, 4) * near, rng.uniform(-14, 6) * near, rng.uniform(-10, 10) * near)
    kit.add_mesh(root, led, led_mat, uv_scale=1.0, auto_smooth_deg=30.0)
    kit_part = kit.WeaponPart(root.name + "_kit")
    m_w, m_h, m_d = ARENA["DESK_MONITOR_WIDTH"], ARENA["DESK_MONITOR_HEIGHT"], ARENA["DESK_MONITOR_DEPTH"]
    # one monitor knocked flat on the left slab, one hanging off the front on
    # the right, the third in pieces on the floor in front
    tilted_box(kit_part, Vector((-1.25, height - 0.04, 0.05)), Vector((m_w, m_h, m_d)), 12, 82, 0)
    tilted_box(kit_part, Vector((1.15, height - 0.26, -depth * 0.5 - 0.08)), Vector((m_w, m_h, m_d)),
               -8, -35, 18)
    for i in range(5):
        tilted_box(kit_part, Vector((rng.uniform(-0.6, 0.6), 0.015, -depth * 0.5 - rng.uniform(0.2, 0.8))),
                   Vector((rng.uniform(0.06, 0.2), 0.02, rng.uniform(0.05, 0.14))),
                   rng.uniform(0, 180), rng.uniform(-10, 10), rng.uniform(-10, 10))
    kit.add_mesh(root, kit_part, plastic_mat, uv_scale=2.0, auto_smooth_deg=30.0)


_tops: dict = {}


def top_part(root, side: float):
    key = (root.name, side)
    if key not in _tops:
        _tops[key] = kit.WeaponPart(root.name + "_top%d" % int(side))
    return _tops[key]


def flush_tops(root, mat) -> None:
    for (name, _side), part in list(_tops.items()):
        if name == root.name:
            kit.add_mesh(root, part, mat, uv_scale=1.0, auto_smooth_deg=35.0)
            del _tops[(name, _side)]


def build_post(root, post_mat, pad_mat, steel_mat) -> None:
    rng = np.random.RandomState(kit.seed_of("post_damaged"))
    length = RING["POST_TOP"] - RING["POST_BOTTOM"]
    lean = math.radians(4.0)
    axis = Vector((0.0, math.cos(lean), math.sin(lean)))
    post = kit.WeaponPart(root.name + "_post")
    # a dent where the blast hit it, at the middle rope
    dent_y = RING["ROPE_HEIGHT_MIDDLE"] - RING["POST_BOTTOM"]
    kit.sweep(post, [axis * (length * k / 20.0) for k in range(21)],
              lambda t, th: RING["POST_RADIUS"] * (1.0 - 0.35 * math.exp(-((t * length - dent_y) / 0.12) ** 2)
                                                   * max(0.0, -math.cos(th))),
              sides=14, caps=True)
    kit.add_mesh(root, post, post_mat, project=False, auto_smooth_deg=60.0)
    rods = kit.WeaponPart(root.name + "_rods")
    for rope_y in (RING["ROPE_HEIGHT_BOTTOM"], RING["ROPE_HEIGHT_MIDDLE"], RING["ROPE_HEIGHT_TOP"]):
        at = axis * (rope_y - RING["POST_BOTTOM"])
        for side in (-1.0, 1.0):
            d = Vector((side * 0.7071, 0.0, -0.7071))
            rods.tube([at, at + d * 0.16 + Vector((0, -0.01, 0))], 0.009, sides=6)
    kit.add_mesh(root, rods, steel_mat, uv_scale=6.0, auto_smooth_deg=60.0)
    pads = kit.WeaponPart(root.name + "_pads")
    pw, ph, pd = RING["TURNBUCKLE_PAD_WIDTH"], RING["TURNBUCKLE_PAD_HEIGHT"], RING["TURNBUCKLE_PAD_DEPTH"]
    # the top pad hanging by its strap, face down
    top_at = axis * (RING["ROPE_HEIGHT_TOP"] - RING["POST_BOTTOM"])
    tilted_box(pads, top_at + Vector((0.0, -0.32, -0.16)), Vector((pw, ph, pd)), 45, 70, 8, bevel=0.02)
    pads.tube([top_at + Vector((0.0, 0.0, -0.08)), top_at + Vector((0.0, -0.22, -0.18))], 0.008, sides=5)
    # the other two blown down onto the floor in front of the corner
    floor = -1.0 - RING["POST_BOTTOM"] + 0.0
    floor_y = (RING["STEP_FLOOR_Y"] - RING["POST_BOTTOM"]) + ph * 0.5
    tilted_box(pads, Vector((0.35, floor_y, 0.9)), Vector((pw, ph, pd)), rng.uniform(0, 90), 0, 0, bevel=0.02)
    tilted_box(pads, Vector((-0.4, floor_y, 1.25)), Vector((pw, ph, pd)), rng.uniform(90, 180), 0, 90, bevel=0.02)
    del floor
    kit.add_mesh(root, pads, pad_mat, uv_scale=2.0, auto_smooth_deg=40.0)


def build_apron(root, cloth_mat, frame_mat) -> None:
    rng = np.random.RandomState(kit.seed_of("apron_damaged"))
    w = 2.2
    h = RING["APRON_TOP"] - RING["APRON_BOTTOM"]
    jag = rng.uniform(-0.1, 0.1, 64)

    def hole(s: float, t: float) -> bool:
        k = int(s * 63)
        dx = (s - 0.5) / 0.24
        dy = (t - 0.5 + jag[k]) / 0.36
        return dx * dx + dy * dy < 1.0

    def shape(p: Vector, s: float, t: float) -> Vector:
        # the edges round the hole blown inward (-Z, into the ring's
        # underside) and the flaps below it hanging
        dx, dy = (s - 0.5) / 0.4, (t - 0.5) / 0.6
        near = max(0.0, 1.0 - math.sqrt(dx * dx + dy * dy))
        q = Vector(p)
        q.z -= near * near * 0.22
        if t < 0.45:
            q.y -= near * 0.06
        return q

    cloth = kit.WeaponPart(root.name + "_skirt")
    ragged_sheet(cloth, w, h, 0.006, 30, 14, hole, shape)
    kit.add_mesh(root, cloth, cloth_mat, uv_scale=1.0, auto_smooth_deg=40.0)
    frame = kit.WeaponPart(root.name + "_frame")
    # the ring's steel behind: a cross-member and two uprights, in shadow
    frame.box(Vector((0.0, h * 0.55, -0.32)), Vector((w * 0.9, 0.08, 0.08)))
    for x in (-0.6, 0.6):
        frame.box(Vector((x, h * 0.5, -0.36)), Vector((0.07, h, 0.07)))
    frame.box(Vector((0.0, h * 0.5, -0.6)), Vector((w, h, 0.02)))          # the dark beyond
    kit.add_mesh(root, frame, frame_mat, uv_scale=2.0, auto_smooth_deg=30.0)


def build_steps(root, steel_mat, tread_mat) -> None:
    rng = np.random.RandomState(kit.seed_of("steps_damaged"))
    width = RING["STEP_WIDTH"]
    run, plat = RING["STEP_RUN"], RING["STEP_PLATFORM"]
    total = plat + run * STEP_TREADS
    top = RING["STEP_TOP_Y"] - RING["STEP_FLOOR_Y"]

    def crush(p: Vector) -> Vector:
        # twisted about the run and crushed down on the blast side (+X)
        q = Vector(p)
        u = (p.z + total * 0.5) / total
        q.y *= 1.0 - 0.32 * max(0.0, p.x / (width * 0.5)) * (0.4 + 0.6 * u)
        a = math.radians(9.0) * (u - 0.5)
        q.x, q.y = q.x * math.cos(a) - q.y * math.sin(a) * 0.3, q.y + q.x * math.sin(a) * 0.3
        return q
    steps = kit.WeaponPart(root.name + "_steel", deform=crush)
    # the platform against the ring, then the treads stepping down and out
    z = -total * 0.5
    steps.box(Vector((0.0, top * 0.5, z + plat * 0.5)), Vector((width, top, plat)), bevel=0.01)
    z += plat
    treads = kit.WeaponPart(root.name + "_treads", deform=crush)
    for k in range(STEP_TREADS):
        hk = top * (STEP_TREADS - k) / (STEP_TREADS + 1.0)
        steps.box(Vector((0.0, hk * 0.5, z + run * 0.5)), Vector((width, hk, run)), bevel=0.008)
        if k != 1:                                    # the second tread torn away
            treads.box(Vector((0.0, hk + 0.008, z + run * 0.5)), Vector((width - 0.04, 0.016, run - 0.03)))
        z += run
    kit.add_mesh(root, steps, steel_mat, uv_scale=1.5, auto_smooth_deg=35.0)
    # the torn tread, lying beside them
    tilted_box(treads, Vector((width * 0.5 + 0.35, 0.012, 0.2)), Vector((width - 0.04, 0.016, run - 0.03)),
               rng.uniform(20, 50), 0, 6)
    kit.add_mesh(root, treads, tread_mat, uv_scale=2.0, auto_smooth_deg=30.0)


def build_led_patch(root, dead_mat, cabinet_mat, cable_mat) -> None:
    rng = np.random.RandomState(kit.seed_of("led_smashed"))
    tile = 0.32
    n = 7                                              # 7 x 7 tiles, 2.24 m
    tiles = kit.WeaponPart(root.name + "_tiles")
    for j in range(n):
        for i in range(n):
            cx, cy = (i - (n - 1) * 0.5) * tile, (j - (n - 1) * 0.5) * tile
            r = math.hypot(cx, cy) + rng.uniform(-0.12, 0.12)
            if r < 0.55:
                continue                               # gone: the cabinet shows
            if r > 1.05 and rng.uniform() < 0.5:
                continue                               # whole: the live screen shows round it
            k = max(0.0, 1.0 - (r - 0.55) / 0.6)
            tilted_box(tiles, Vector((cx, cy, 0.012 + k * 0.03)), Vector((tile - 0.008, tile - 0.008, 0.015)),
                       rng.uniform(-8, 8) * k, rng.uniform(-18, 18) * k, rng.uniform(-10, 10) * k)
    kit.add_mesh(root, tiles, dead_mat, uv_scale=1.0, auto_smooth_deg=30.0)
    cab = kit.WeaponPart(root.name + "_cabinet")
    cab.box(Vector((0.0, 0.0, -0.28)), Vector((1.3, 1.3, 0.02)))           # the back of the cabinet
    for x in (-0.48, 0.0, 0.48):
        cab.box(Vector((x, 0.0, -0.14)), Vector((0.04, 1.2, 0.26)))
    for y in (-0.48, 0.48):
        cab.box(Vector((0.0, y, -0.14)), Vector((1.2, 0.04, 0.26)))
    # the walls of the hole, so it has depth from an angle
    for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        cab.box(Vector((sx * 0.62, sy * 0.62, -0.13)),
                Vector((0.02 if sx else 1.26, 0.02 if sy else 1.26, 0.28)))
    kit.add_mesh(root, cab, cabinet_mat, uv_scale=2.0, auto_smooth_deg=30.0)
    cables = kit.WeaponPart(root.name + "_cables")
    for i in range(6):
        x0, y0 = rng.uniform(-0.45, 0.45), rng.uniform(0.1, 0.5)
        pts = [Vector((x0, y0, -0.2))]
        for k in range(1, 6):
            pts.append(Vector((x0 + rng.uniform(-0.05, 0.05) * k, y0 - 0.12 * k, -0.2 + 0.05 * k)))
        cables.tube(pts, 0.008, sides=5)
    kit.add_mesh(root, cables, cable_mat, uv_scale=6.0, auto_smooth_deg=60.0)


def build_rubble(root, char_mat, steel_mat) -> None:
    rng = np.random.RandomState(kit.seed_of("rubble"))
    chunks = kit.WeaponPart(root.name + "_chunks")
    for i in range(14):
        ang = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.2, 1.4)
        s = rng.uniform(0.05, 0.22)
        tilted_box(chunks, Vector((math.cos(ang) * r, s * 0.25, math.sin(ang) * r)),
                   Vector((s, s * rng.uniform(0.2, 0.6), s * rng.uniform(0.5, 1.2))),
                   rng.uniform(0, 180), rng.uniform(-15, 15), rng.uniform(-15, 15))
    kit.add_mesh(root, chunks, char_mat, uv_scale=3.0, auto_smooth_deg=30.0)
    bits = kit.WeaponPart(root.name + "_bits")
    for i in range(5):
        ang = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.3, 1.2)
        a = Vector((math.cos(ang) * r, 0.03, math.sin(ang) * r))
        bits.tube([a, a + rot_y(Vector((0.3, 0.02, 0.0)), rng.uniform(0, 360)),
                   a + rot_y(Vector((0.45, 0.06, 0.1)), rng.uniform(0, 360))], 0.012, sides=6)
    kit.add_mesh(root, bits, steel_mat, uv_scale=4.0, auto_smooth_deg=60.0)


def main() -> None:
    kit.TEX_DIR = TEX                                  # the kit's metal and polymer go here too
    TEX.mkdir(parents=True, exist_ok=True)
    (TEX / ".gdignore").write_text("")
    kit.reset()
    panel = kit.pbr_material("dmg_barricade", *charred_textures("dmg_barricade", (0.10, 0.10, 0.11), 1.1), 0.8)
    steel = kit.pbr_material("dmg_steel", *kit.metal_textures("dmg_steel", (0.12, 0.12, 0.12), 0.3, 0.5,
                                                               rust=0.1, size=256), 0.6)
    desk_body = kit.pbr_material("dmg_desk", *charred_textures("dmg_desk", (0.09, 0.09, 0.10), 1.2), 0.8)
    desk_top = kit.pbr_material("dmg_desk_top", *charred_textures("dmg_desk_top", (0.16, 0.16, 0.17), 0.9), 0.8)
    led = kit.pbr_material("dmg_led", *cracked_led_texture("dmg_led"), 0.6)
    plastic = kit.pbr_material("dmg_plastic", *kit.polymer_textures("dmg_plastic", (0.03, 0.03, 0.03), size=256), 0.6)
    post = kit.pbr_material("dmg_post", *charred_textures("dmg_post", (0.07, 0.07, 0.08), 1.4), 0.7)
    pad = kit.pbr_material("dmg_pad", *charred_textures("dmg_pad", (0.055, 0.055, 0.06), 0.8), 0.6)
    cloth = kit.pbr_material("dmg_apron", *charred_textures("dmg_apron", (0.05, 0.05, 0.055), 1.3), 0.5)
    dark = kit.flat_material("dmg_dark", (0.02, 0.02, 0.022), 0.9)
    cable = kit.flat_material("dmg_cable", (0.04, 0.04, 0.04), 0.6)
    report = []
    for name, build in (
            ("BarricadePanel_Damaged", lambda r: build_barricade(r, panel, steel)),
            ("CommentaryDesk_Damaged", lambda r: (build_desk(r, desk_body, desk_top, led, plastic),
                                                  flush_tops(r, desk_top))),
            ("RingPost_Damaged", lambda r: build_post(r, post, pad, steel)),
            ("RingApron_Damaged", lambda r: build_apron(r, cloth, dark)),
            ("RingSteps_Damaged", lambda r: build_steps(r, post, steel)),
            ("LedWall_Smashed", lambda r: build_led_patch(r, led, dark, cable)),
            ("Rubble", lambda r: build_rubble(r, desk_body, steel))):
        root = kit.state_root(name)
        build(root)
        report.append("%s: %d triangles" % (name, kit.triangles_under(root)))
    export(OUT)
    report.append("wrote " + str(OUT.relative_to(venue.REPO)))
    print("\n".join(report))


if __name__ == "__main__":
    main()
    import bpy_exit  # noqa: E402 -- skip bpy's teardown segfault (see there)
    bpy_exit.finish(0)
