#!/usr/bin/env python3
"""Family 3, carried and slammed (gauntlet/refs/weapons_nhb.md): the trash
can and its lid, the steel steps, the ring bell, the cookie sheet, the
frying pan and the briefcase. (The championship belt is the one Roman
carries -- game/assets/props/aew_title.glb, its Held* nodes -- not a second
model.)

Run:  python3 tools/blender/weapons/carried.py

  game/assets/weapons/trash_can.glb
      TrashCan_Clean   the can, lid on; children ..._can and ..._lid so the
                       lid comes off as its own weapon
      TrashCan_Dented  after it has been used: caved-in sides, a crushed rim,
                       the lid buckled -- in the mesh

The galvanised steel can every hardcore match has: tapered, three swaged
ribs round it, two side handles, a domed lid with a strap handle. Hot-dip
spangle on the zinc, dull and scuffed, grime at the bottom.

Origin at the right-hand side handle (grip_r), as it is carried; grip_l at
the other handle; strike at the base, which is what lands; lid_grip at the
lid's handle.
"""

from __future__ import annotations

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import weapon_kit as kit  # noqa: E402
from weapon_kit import Vector  # noqa: E402

import numpy as np  # noqa: E402

H = 0.70
R_BOT, R_TOP = 0.215, 0.245
RIBS = (0.16, 0.36, 0.56)
WALL = 0.0015


def galv_textures(weapon_id: str) -> tuple:
    """Spangled zinc: cells of slightly different brightness and roughness
    (the crystals of a hot-dip coat), dulled, scuffed, grimy low down."""
    rng = np.random.RandomState(kit.seed_of(weapon_id + "_galv"))
    n = kit.TEX_SIZE
    # spangle: a coarse random grid, nearest-upsampled and warped
    from PIL import Image, ImageFilter
    cells = rng.rand(150, 150).astype(np.float32)
    img = Image.fromarray((cells * 255).astype(np.uint8)).resize((n, n), Image.NEAREST)
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    sp = np.asarray(img, np.float32) / 255.0
    fine = kit.fbm(rng, n, 64, 3)
    zinc = np.array([0.60, 0.61, 0.60])
    # the crystals are a sheen, not a pattern: a few percent of brightness
    base = zinc[None, None] * (0.90 + 0.07 * sp[..., None] + 0.08 * fine[..., None])
    scuff = kit.scratches(rng, n, 150, 0.15, 1, spread=1.2) * 0.6
    base = base + scuff[..., None] * 0.12
    # white rust and grime (v low = can bottom with world-metre UVs at scale 1)
    # v is height up the wall in metres (0 at the base): grime in the
    # bottom 15 cm, where it stood in whatever it stood in
    v = np.linspace(1, 0, n)[:, None].repeat(n, 1)
    grime = np.clip((kit.fbm(rng, n, 8, 4) - 0.40) * 2.5, 0, 1) * np.clip(1.0 - v / 0.15, 0, 1)
    base = base * (1 - grime[..., None] * 0.45)
    whiterust = np.clip((kit.fbm(rng, n, 20, 3) - 0.72) * 5, 0, 1) * 0.6
    base = base * (1 - whiterust[..., None] * 0.3) + np.array([0.70, 0.70, 0.66]) * whiterust[..., None] * 0.3
    rough = 0.46 + 0.10 * sp + 0.12 * fine + 0.3 * grime + 0.3 * whiterust - 0.1 * scuff
    # weathered zinc is a dull metal: an oxide skin over it
    metal = 0.75 - 0.5 * grime - 0.5 * whiterust
    orm = np.stack([np.ones_like(rough), np.clip(rough, 0, 1), np.clip(metal, 0, 1)], -1)
    nrm = kit.normal_from_height(sp * 0.05 + fine * 0.2 - scuff * 0.3, 3.0)
    d = kit.TEX_DIR
    kit.save_rgb(np.clip(base, 0, 0.85), d / f"{weapon_id}_galv_base.png")
    kit.save_rgb(orm, d / f"{weapon_id}_galv_orm.png")
    kit.save_rgb(nrm, d / f"{weapon_id}_galv_normal.png")
    return d / f"{weapon_id}_galv_base.png", d / f"{weapon_id}_galv_orm.png", d / f"{weapon_id}_galv_normal.png"


def can_radius(y: float, theta: float) -> float:
    r = R_BOT + (R_TOP - R_BOT) * (y / H)
    for ry in RIBS:
        r += 0.008 * math.exp(-((y - ry) / 0.012) ** 2)
    # a slight corrugation round the body
    r += 0.0012 * math.cos(theta * 24)
    return r


DENTS = [  # (theta, y, depth, size)
    (0.6, 0.42, 0.075, 0.12), (2.4, 0.22, 0.05, 0.09), (4.1, 0.55, 0.06, 0.10), (5.4, 0.30, 0.035, 0.07)]


def dented(p: Vector) -> Vector:
    """Caved in where it was swung into skulls; the rim crushed oval."""
    r = math.hypot(p.x, p.z)
    if r < 1e-6:
        return p
    theta = math.atan2(p.z, p.x)
    push = 0.0
    for th, y, depth, size in DENTS:
        dth = math.atan2(math.sin(theta - th), math.cos(theta - th)) * r
        push += depth * math.exp(-((dth / size) ** 2 + ((p.y - y) / size) ** 2))
    k = max(r - push, 0.02) / r
    q = Vector((p.x * k, p.y, p.z * k))
    # the top squashed oval and dipped on one side
    f = max(p.y / H, 0.0) ** 2
    q.x *= 1.0 + 0.10 * f
    q.z *= 1.0 - 0.13 * f
    q.y -= 0.03 * f * (0.5 + 0.5 * math.cos(theta - 1.0))
    return q


def build(root, prefix: str, galv, deform, origin: Vector) -> None:
    """The can in its own frame (base centre at the origin), then shifted so
    the right handle is at the root's origin."""
    def place(p: Vector) -> Vector:
        q = deform(p) if deform else p
        return q - origin

    can = kit.WeaponPart(prefix + "_can", place)
    # rings dense only where the swaged ribs turn
    ys = set(round(H * k / 24, 4) for k in range(25))
    for ry in RIBS:
        ys.update(round(ry + d, 4) for d in np.linspace(-0.03, 0.03, 11))
    ys = sorted(ys)
    path = [Vector((0, y, 0)) for y in ys]
    # outer wall (the sweep's t is arc fraction, which on this straight path is y / H)
    kit.sweep(can, path, lambda t, th: can_radius(t * H, th), sides=48, caps=False, v_scale=1.0)
    # inner wall, a skin thickness in, plain; the rolled rim joins them
    inner = [Vector((0, H * (1 - k / 10), 0)) for k in range(11)]
    kit.sweep(can, inner, lambda t, th: R_BOT + (R_TOP - R_BOT) * (1 - t) - WALL * 3,
              sides=48, caps=False, v_scale=1.0)
    rim = [Vector((math.cos(a) * (R_TOP + 0.002), H, math.sin(a) * (R_TOP + 0.002)))
           for a in np.linspace(0, 2 * math.pi, 49)]
    can.tube(rim, 0.006, 8, caps=False)
    # the base: a disc with a stiffening ring
    base_ring = [Vector((math.cos(a) * (R_BOT - 0.01), 0.004, math.sin(a) * (R_BOT - 0.01)))
                 for a in np.linspace(0, 2 * math.pi, 49)]
    can.tube(base_ring, 0.006, 8, caps=False)
    disc = [can.vert(Vector((math.cos(a) * R_BOT, 0.001, math.sin(a) * R_BOT))) for a in
            np.linspace(0, 2 * math.pi, 48, endpoint=False)]
    can.bm.faces.new(list(reversed(disc)))
    # side handles: a strap bent out from two rivets
    for s in (-1, 1):
        hy = 0.58
        x = s * (can_radius(hy, 0) + 0.004)
        pts = [Vector((x, hy - 0.03, -0.06)), Vector((x + s * 0.035, hy - 0.035, -0.045)),
               Vector((x + s * 0.045, hy - 0.04, 0.0)), Vector((x + s * 0.035, hy - 0.035, 0.045)),
               Vector((x, hy - 0.03, 0.06))]
        can.tube(pts, 0.0055, 8, caps=True)
        for z in (-0.06, 0.06):
            can.tube([Vector((x - s * 0.002, hy - 0.03, z)), Vector((x + s * 0.008, hy - 0.03, z))], 0.011, 10)
    kit.add_mesh(root, can, galv, project=False, auto_smooth_deg=180.0)

    lid = kit.WeaponPart(prefix + "_lid", place)
    lid_y = H + 0.004
    # domed lid as a lathe: (radius, height) profile
    prof = [(0.0, 0.062), (0.05, 0.059), (0.10, 0.051), (0.15, 0.038), (0.20, 0.021),
            (0.235, 0.010), (0.252, 0.004), (0.256, -0.012), (0.250, -0.016)]
    rings = []
    for rr, hh in prof:
        rings.append([lid.vert(Vector((math.cos(a) * rr, lid_y + hh, math.sin(a) * rr)))
                      for a in np.linspace(0, 2 * math.pi, 48, endpoint=False)])
    for i in range(len(rings) - 1):
        for k in range(48):
            j = (k + 1) % 48
            lid.quad(rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k])
    # lid handle: a strap over the top
    hp = [Vector((-0.07, lid_y + 0.058, 0)), Vector((-0.06, lid_y + 0.10, 0)), Vector((0, lid_y + 0.115, 0)),
          Vector((0.06, lid_y + 0.10, 0)), Vector((0.07, lid_y + 0.058, 0))]
    lid.tube(hp, 0.007, 10, caps=True)
    kit.add_mesh(root, lid, galv, uv_scale=1.0, auto_smooth_deg=180.0)

    hx = can_radius(0.58, 0) + 0.05
    kit.marker(root, "grip_r", place(Vector((hx, 0.545, 0))), Vector((0, 0, 1)), Vector((1, 0, 0)))
    kit.marker(root, "grip_l", place(Vector((-hx, 0.545, 0))), Vector((0, 0, 1)), Vector((-1, 0, 0)))
    kit.marker(root, "strike", place(Vector((0, 0.0, 0))), Vector((0, 0, 1)), Vector((0, -1, 0)))
    kit.marker(root, "lid_grip", place(Vector((0, lid_y + 0.115, 0))), Vector((1, 0, 0)), Vector((0, 1, 0)))


# --- shared ------------------------------------------------------------------

def diamond_plate_textures(name: str, color: tuple) -> tuple:
    """Steel tread plate: raised lozenges in a herringbone, worn bright on
    their tops, grime in the valleys."""
    rng = np.random.RandomState(kit.seed_of(name + "_plate"))
    n = kit.TEX_SIZE
    yy, xx = np.mgrid[0:n, 0:n] / n
    cells = 28
    u, v = xx * cells, yy * cells
    iu, iv = np.floor(u), np.floor(v)
    fu, fv = u - iu, v - iv
    alt = ((iu + iv) % 2).astype(bool)
    # a lozenge per cell, at +-45 degrees alternately
    a = np.where(alt, (fu - fv), (fu + fv - 1.0))
    b = np.where(alt, (fu + fv - 1.0), (fu - fv))
    loz = np.clip(1.0 - (np.abs(a) / 0.16) ** 2 - (np.abs(b) / 0.55) ** 2, 0, 1) ** 0.5
    fine = kit.fbm(rng, n, 64, 3)
    grime = np.clip((kit.fbm(rng, n, 6, 4) - 0.45) * 2.5, 0, 1)
    base = np.array(color)[None, None] * (0.9 + 0.15 * fine[..., None])
    base = base * (1 + loz[..., None] * 0.25) * (1 - grime[..., None] * (1 - loz[..., None]) * 0.5)
    r = 0.55 - 0.25 * loz + 0.2 * grime
    orm = np.stack([np.ones_like(r), np.clip(r, 0, 1), np.full_like(r, 0.85)], -1)
    nrm = kit.normal_from_height(loz * 1.0 + fine * 0.1, 5.0)
    d = kit.TEX_DIR
    kit.save_rgb(np.clip(base, 0, 0.85), d / f"{name}_plate_base.png")
    kit.save_rgb(orm, d / f"{name}_plate_orm.png")
    kit.save_rgb(nrm, d / f"{name}_plate_normal.png")
    return d / f"{name}_plate_base.png", d / f"{name}_plate_orm.png", d / f"{name}_plate_normal.png"


def profile_prism(part, profile_zy: list, half_w: float, bevel_in: float = 0.0) -> None:
    """A side profile (z, y) extruded across x from -half_w to half_w; the
    profile counter-clockwise seen from +x."""
    left = [part.vert(Vector((-half_w, y, z))) for z, y in profile_zy]
    right = [part.vert(Vector((half_w, y, z))) for z, y in profile_zy]
    part.bm.faces.new(list(reversed(left)))
    part.bm.faces.new(right)
    n = len(profile_zy)
    for i in range(n):
        j = (i + 1) % n
        part.quad(left[i], left[j], right[j], right[i])


# --- steel steps -----------------------------------------------------------------

STEP_W, STEP_RISE, STEP_RUN = 1.0, 0.32, 0.30
STEP_SPLIT = 0.48


def build_steps(root, prefix, shell, treads, top_only: bool) -> None:
    """Three steps, a shell of sheet steel with tread plates, in two units:
    the base and the top unit that lifts off it (what gets carried). Origin
    at floor centre; the steps climb toward +Z (the back is at +Z)."""
    d = STEP_RUN * 3
    z0 = -d / 2
    prof = [(z0, 0.0), (z0 + d, 0.0), (z0 + d, STEP_RISE * 3), (z0 + STEP_RUN * 2, STEP_RISE * 3),
            (z0 + STEP_RUN * 2, STEP_RISE * 2), (z0 + STEP_RUN, STEP_RISE * 2), (z0 + STEP_RUN, STEP_RISE),
            (z0, STEP_RISE)]

    def clip(prof, lo, hi):
        out = []
        for z, y in prof:
            out.append((z, min(max(y, lo), hi)))
        cleaned = []
        for p in out:
            if not cleaned or (abs(p[0] - cleaned[-1][0]) > 1e-6 or abs(p[1] - cleaned[-1][1]) > 1e-6):
                cleaned.append(p)
        if len(cleaned) > 1 and abs(cleaned[0][0] - cleaned[-1][0]) < 1e-6 and abs(cleaned[0][1] - cleaned[-1][1]) < 1e-6:
            cleaned.pop()
        return cleaned

    units = [("_top", STEP_SPLIT, STEP_RISE * 3)] if top_only else [("_base", 0.0, STEP_SPLIT),
                                                                     ("_top", STEP_SPLIT, STEP_RISE * 3)]
    for suffix, lo, hi in units:
        body = kit.WeaponPart(prefix + suffix)
        pr = [(z, y) for z, y in clip(prof, lo, hi)]
        # only the part of the profile in this unit's height band: drop the
        # degenerate zero-area runs that clipping leaves
        pr2 = []
        for z, y in pr:
            if lo <= y <= hi:
                pr2.append((z, y))
        profile_prism(body, pr2, STEP_W / 2 - 0.01)
        # side panel lips and the turned-down edges
        for sx in (-1, 1):
            body.box(Vector((sx * (STEP_W / 2 - 0.005), (lo + hi) / 2, z0 + d - 0.02)), Vector((0.012, hi - lo, 0.04)),
                     bevel=0.004)
        kit.add_mesh(root, body, shell, uv_scale=1.2)
        tr = kit.WeaponPart(prefix + suffix + "_treads")
        for k in range(3):
            y = STEP_RISE * (k + 1)
            if lo < y <= hi + 1e-6:
                zc = z0 + STEP_RUN * k + STEP_RUN / 2 if k < 2 else z0 + STEP_RUN * 2 + STEP_RUN / 2
                depth = STEP_RUN if k < 2 else STEP_RUN
                tr.box(Vector((0, y + 0.004, zc)), Vector((STEP_W - 0.06, 0.008, depth - 0.03)), bevel=0.003)
                tr.box(Vector((0, y - 0.006, zc - depth / 2 + 0.006)), Vector((STEP_W - 0.02, 0.024, 0.016)), bevel=0.004)
        if tr.bm.verts:
            kit.add_mesh(root, tr, treads, uv_scale=1.0)
        else:
            tr.bm.free()
    if top_only:
        kit.marker(root, "grip_r", Vector((0.42, STEP_SPLIT + 0.05, z0 + d)), Vector((-1, 0, 0)), Vector((0, 0, 1)))
        kit.marker(root, "grip_l", Vector((-0.42, STEP_SPLIT + 0.05, z0 + d)), Vector((1, 0, 0)), Vector((0, 0, 1)))
        kit.marker(root, "strike", Vector((0, STEP_SPLIT, 0)), Vector((0, 0, 1)), Vector((0, -1, 0)))
    kit.marker(root, "top", Vector((0, STEP_RISE * 3, z0 + STEP_RUN * 2.5)))


# --- ring bell ------------------------------------------------------------------

def build_bell(root, prefix, brass, wood, felt) -> None:
    """The timekeeper's bell: a brass gong-bell on a turned post on a board,
    and its hammer. Carried by the board, swung bell-first. Origin at the
    board's centre underneath (where the hand takes it)."""
    base = kit.WeaponPart(prefix + "_base")
    base.box(Vector((0, 0.015, 0)), Vector((0.30, 0.03, 0.20)), bevel=0.006, bevel_segments=2)
    kit.sweep(base, [Vector((0, 0.03, 0)), Vector((0, 0.13, 0))],
              lambda t, th: 0.02 + 0.012 * math.cos(t * math.pi * 2) ** 2, sides=16, caps=True)
    kit.add_mesh(root, base, wood, uv_scale=4.0)
    bell = kit.WeaponPart(prefix + "_bell")
    # a shallow dome, open underneath, with a rolled lip and a boss on top
    # ~15 cm across, standing clear of the board's edges
    prof = [(r * 0.62, 0.128 + (y - 0.135) * 0.95) for r, y in
            ((0.0, 0.215), (0.02, 0.214), (0.05, 0.208), (0.08, 0.195), (0.10, 0.180), (0.112, 0.160),
             (0.116, 0.140), (0.118, 0.135))]
    rings = [[bell.vert(Vector((math.cos(a) * r, y, math.sin(a) * r)))
              for a in np.linspace(0, 2 * math.pi, 40, endpoint=False)] for r, y in prof]
    inner = [[bell.vert(Vector((math.cos(a) * r * 0.96, y - 0.004, math.sin(a) * r * 0.96)))
              for a in np.linspace(0, 2 * math.pi, 40, endpoint=False)] for r, y in prof]
    for i in range(len(rings) - 1):
        for k in range(40):
            j = (k + 1) % 40
            bell.quad(rings[i][k], rings[i + 1][k], rings[i + 1][j], rings[i][j])
            bell.quad(inner[i][k], inner[i][j], inner[i + 1][j], inner[i + 1][k])
    for k in range(40):
        j = (k + 1) % 40
        bell.quad(rings[-1][k], inner[-1][k], inner[-1][j], rings[-1][j])
    bell.cylinder(Vector((0, 0.203, 0)), Vector((0, 1, 0)), 0.010, 0.010, 16)
    kit.add_mesh(root, bell, brass, uv_scale=6.0, auto_smooth_deg=180.0)
    hammer = kit.WeaponPart(prefix + "_hammer")
    hammer.tube([Vector((0.10, 0.04, 0.07)), Vector((0.10, 0.04, -0.12))], 0.006, 10)
    kit.add_mesh(root, hammer, wood, uv_scale=6.0)
    head = kit.WeaponPart(prefix + "_hammer_head")
    head.cylinder(Vector((0.085, 0.04, 0.07)), Vector((1, 0, 0)), 0.016, 0.03, 16)
    kit.add_mesh(root, head, felt, uv_scale=6.0)
    kit.marker(root, "grip_r", Vector((0.0, 0.0, 0.06)), Vector((0, 0, -1)), Vector((0, -1, 0)))
    kit.marker(root, "grip_l", Vector((0.0, 0.0, -0.06)), Vector((0, 0, -1)), Vector((0, -1, 0)))
    kit.marker(root, "strike", Vector((0, 0.205, 0)), Vector((0, 1, 0)), Vector((0, 1, 0)))


# --- cookie sheet, frying pan, briefcase ---------------------------------------------

def build_cookie_sheet(root, prefix, alu, dented: bool) -> None:
    """A rimmed aluminium half-sheet, 0.46 x 0.33. Dented: folded over a
    head, the middle caved. Origin at the grip on the short edge."""
    W, L = 0.33, 0.46

    def dent(p: Vector) -> Vector:
        if not dented:
            return p
        q = Vector(p)
        q.z += 0.045 * math.exp(-((p.x / 0.12) ** 2 + ((p.y - 0.25) / 0.12) ** 2))
        q.z += 0.06 * max(0.0, p.y - 0.30) ** 1.2 * 3
        return q

    sheet = kit.WeaponPart(prefix + "_sheet", dent)
    sheet.grid_panel(Vector((-W / 2, 0.0, 0)), Vector((W, 0, 0)), Vector((0, L, 0)), 16, 22, 0.0012)
    rim = kit.rounded_rect(Vector((0, L / 2, -0.012)), Vector((1, 0, 0)), Vector((0, 1, 0)), W / 2, L / 2, 0.02, 4)
    sheet.tube(rim, 0.0032, 8, caps=False)
    for k in range(len(rim) - 1):
        a, b = rim[k], rim[k + 1]
        a0 = Vector((a.x * 0.985, (a.y - L / 2) * 0.985 + L / 2, 0.0))
        b0 = Vector((b.x * 0.985, (b.y - L / 2) * 0.985 + L / 2, 0.0))
        sheet.quad(sheet.vert(a0), sheet.vert(b0), sheet.vert(b), sheet.vert(a))
    kit.add_mesh(root, sheet, alu, uv_scale=2.5, auto_smooth_deg=50.0)
    kit.marker(root, "grip_r", Vector((0.06, 0.0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((-0.06, 0.0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0, 0.26, 0)), Vector((0, 1, 0)), Vector((0, 0, -1)))


def build_pan(root, prefix, iron) -> None:
    """A 12-inch cast-iron skillet: thick walls, pour spouts, a long handle
    with a hanging hole, a helper lug. Held by the handle; origin there."""
    pan = kit.WeaponPart(prefix + "_iron")
    cy = 0.27                                    # pan centre along the handle (+Y)
    R, H, T = 0.152, 0.048, 0.006
    prof_out = [(0.0, 0.0), (R - 0.03, 0.0), (R - 0.01, 0.004), (R, 0.02), (R + 0.004, H)]
    prof_in = [(R + 0.004 - T, H), (R - T, 0.022), (R - 0.012, T + 0.003), (R - 0.03, T), (0.0, T)]

    def ring_at(r, y, k):
        a = 2 * math.pi * k / 48
        spout = 1.0 + 0.04 * max(0.0, math.cos(a - math.pi / 2)) ** 30 + 0.04 * max(0.0, math.cos(a + math.pi / 2)) ** 30
        return Vector((math.cos(a) * r * spout, cy + math.sin(a) * r * spout, -y))

    rings = []
    for r, y in prof_out + prof_in:
        rings.append([pan.vert(ring_at(r, y, k)) for k in range(48)])
    for i in range(len(rings) - 1):
        for k in range(48):
            j = (k + 1) % 48
            pan.quad(rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k])
    # the handle: a tapered bar, out along -Y from the rim, a hole near the end
    section_h = lambda t, th: (math.cos(th) * (0.016 - 0.004 * t), math.sin(th) * (0.009 - 0.002 * t))
    path = [Vector((0, cy - R + 0.004 - 0.18 * f, -(H - 0.01) - 0.012 * f)) for f in np.linspace(0, 1, 12)]
    from swung import section_sweep
    section_sweep(pan, path, lambda t, tan: Vector((0, 0, 1)), section_h, sides=16, caps=True)
    pan.tube([Vector((0, cy + R + 0.004, -(H - 0.008))), Vector((0, cy + R + 0.034, -(H - 0.008)))], 0.009, 12)
    kit.add_mesh(root, pan, iron, uv_scale=3.0, auto_smooth_deg=60.0)
    for child in root.children:
        child.location = child.location - kit.to_blender(Vector((0, cy - R - 0.12, -(H - 0.01))))
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((0, -0.05, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0, R + 0.12, 0.03)), Vector((0, 1, 0)), Vector((0, 0, 1)))


def build_briefcase(root, prefix, leather, brass, black) -> None:
    """A hard-sided leather attache case, 0.45 x 0.33 x 0.10, stitched
    seam round the middle, brass combination latches, the handle on top.
    Origin at the handle."""
    case = kit.WeaponPart(prefix + "_case")
    case.box(Vector((0, -0.18, 0)), Vector((0.45, 0.33, 0.10)), bevel=0.012, bevel_segments=3)
    kit.add_mesh(root, case, leather, uv_scale=2.5)
    trim = kit.WeaponPart(prefix + "_trim")
    seam = kit.rounded_rect(Vector((0, -0.18, 0)), Vector((1, 0, 0)), Vector((0, 1, 0)), 0.2265, 0.1665, 0.012, 3)
    seam = [Vector((p.x, p.y, 0)) for p in seam]
    # seam lies in the case's middle plane, round the edge: an x-y loop at z=0
    edge = []
    for p in kit.rounded_rect(Vector((0, -0.18, 0)), Vector((1, 0, 0)), Vector((0, 1, 0)), 0.2268, 0.1668, 0.014, 3):
        edge.append(Vector((p.x, p.y, 0.0)))
    trim.tube(edge, 0.0035, 6, caps=False)
    for sx in (-1, 1):                                     # handle mounts
        trim.box(Vector((sx * 0.055, -0.012, 0)), Vector((0.022, 0.012, 0.03)), bevel=0.003)
    kit.add_mesh(root, trim, black, uv_scale=6.0)
    handle = kit.WeaponPart(prefix + "_handle")
    handle.tube([Vector((-0.055, -0.008, 0)), Vector((-0.045, 0.022, 0)), Vector((0.0, 0.03, 0)),
                 Vector((0.045, 0.022, 0)), Vector((0.055, -0.008, 0))], 0.009, 12)
    kit.add_mesh(root, handle, leather, uv_scale=6.0)
    latches = kit.WeaponPart(prefix + "_latches")
    for sx in (-1, 1):
        latches.box(Vector((sx * 0.14, -0.035, -0.051)), Vector((0.05, 0.03, 0.006)), bevel=0.002)
        for k in range(3):                                 # combination wheels
            latches.cylinder(Vector((sx * 0.14 - 0.012 + k * 0.012, -0.045, -0.054)), Vector((1, 0, 0)), 0.004,
                             0.006, 10)
    kit.add_mesh(root, latches, brass, uv_scale=8.0)
    kit.marker(root, "grip_r", Vector((0, 0.025, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((-0.2, -0.33, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0, -0.18, -0.05)), Vector((0, 1, 0)), Vector((0, 0, -1)))


def build_more(report: list) -> None:
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    from chairs import paint_textures
    kit.reset()
    wid = "steel_steps"
    sb, so, sn = paint_textures(wid, (0.50, 0.50, 0.51), 0.12)
    shell = kit.pbr_material(wid + "_shell", sb, so, sn, 0.6)
    treads = kit.pbr_material(wid + "_treads", *diamond_plate_textures(wid, (0.30, 0.30, 0.31)), 1.0)
    for state, top in (("Clean", False), ("Top", True)):
        root = kit.state_root("SteelSteps_" + state)
        build_steps(root, root.name, shell, treads, top)
        report.append("steel_steps %s: %d triangles" % (state, kit.triangles_under(root)))
    kit.export(wid)

    kit.reset()
    wid = "ring_bell"
    brass = kit.pbr_material(wid + "_brass", *kit.metal_textures(wid, (0.78, 0.60, 0.30), 0.05, 0.28), 0.5)
    wood = kit.pbr_material(wid + "_wood", *kit.wood_textures(wid, (0.40, 0.22, 0.10), (0.25, 0.12, 0.05), 50, 0.8,
                                                               size=512), 0.5)
    felt = kit.flat_material(wid + "_felt", (0.35, 0.05, 0.05), 0.95)
    root = kit.state_root("RingBell_Clean")
    build_bell(root, root.name, brass, wood, felt)
    report.append("ring_bell: %d triangles" % kit.triangles_under(root))
    kit.export(wid)

    kit.reset()
    wid = "cookie_sheet"
    alu = kit.pbr_material(wid + "_alu", *kit.metal_textures(wid, (0.66, 0.66, 0.64), 0.1, 0.40), 0.5)
    for state, dented in (("Clean", False), ("Dented", True)):
        root = kit.state_root("CookieSheet_" + state)
        build_cookie_sheet(root, root.name, alu, dented)
        report.append("cookie_sheet %s: %d triangles" % (state, kit.triangles_under(root)))
    kit.export(wid)

    kit.reset()
    wid = "frying_pan"
    iron = kit.pbr_material(wid + "_iron", *kit.metal_textures(wid, (0.05, 0.05, 0.05), 0.08, 0.55, rust=0.08), 0.8)
    root = kit.state_root("FryingPan_Clean")
    build_pan(root, root.name, iron)
    report.append("frying_pan: %d triangles" % kit.triangles_under(root))
    kit.export(wid)

    kit.reset()
    wid = "briefcase"
    leather = kit.pbr_material(wid + "_leather", *kit.polymer_textures(wid + "_leather", (0.22, 0.10, 0.05)), 0.8)
    brass = kit.pbr_material(wid + "_brass", *kit.metal_textures(wid, (0.78, 0.60, 0.30), 0.05, 0.30, size=256), 0.5)
    black = kit.flat_material(wid + "_trim", (0.04, 0.03, 0.025), 0.5)
    root = kit.state_root("Briefcase_Clean")
    build_briefcase(root, root.name, leather, brass, black)
    report.append("briefcase: %d triangles" % kit.triangles_under(root))
    kit.export(wid)


def main() -> None:
    more: list = []
    build_more(more)
    print("\n".join(more))
    kit.reset()
    weapon_id = "trash_can"
    galv = kit.pbr_material(weapon_id + "_galv", *galv_textures(weapon_id), 0.6)
    origin = Vector((can_radius(0.58, 0) + 0.05, 0.545, 0.0))
    report = []
    for state, deform in (("Clean", None), ("Dented", dented)):
        root = kit.state_root("TrashCan_" + state)
        build(root, root.name, galv, deform, origin)
        report.append("trash_can %s: %d triangles" % (root.name, kit.triangles_under(root)))
    report.append("wrote " + str(kit.export(weapon_id).relative_to(kit.ROOT)))
    print("\n".join(report))


if __name__ == "__main__":
    main()
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
    import bpy_exit  # noqa: E402 -- skip bpy's teardown segfault (see there)
    bpy_exit.finish(0)
