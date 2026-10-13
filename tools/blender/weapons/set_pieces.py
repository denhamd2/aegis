#!/usr/bin/env python3
"""Family 4, set pieces (gauntlet/refs/weapons_nhb.md): the table, the
ladder, thumbtacks, the bed of nails, the light-tube bundle and the
barbed-wire board.

Run:  python3 tools/blender/weapons/set_pieces.py

  game/assets/weapons/table.glb
      Table_Up      set up, 1.83 x 0.76 m, top at 0.74 m; origin at floor
                    centre, the length along X
      Table_Folded  legs folded under, lying flat -- as it comes out from
                    under the ring
      Table_Broken  Table_Up snapped across the middle: each piece a child
                    piece_NN with its origin at its own centre, laid out
                    where it was in the whole table, so the game can throw
                    them apart from there

The table is the folding banquet kind every promotion uses: a particle-board
top with a wood-laminate face and a plain edge, two steel U-legs that fold
under on hinges, a brace from each leg to the underside. The break is the
one that happens to a real one: the board gives along a ragged line near the
middle, laminate peeling back, splinters standing out of both edges, the
legs buckling inward.
"""

from __future__ import annotations

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import weapon_kit as kit  # noqa: E402
from weapon_kit import Vector  # noqa: E402
from chairs import paint_textures  # noqa: E402

import numpy as np  # noqa: E402

LEN, WID, TOP_Y, THICK = 1.83, 0.76, 0.74, 0.022
LEG_X = 0.70            # leg hinge distance from centre along the length
LEG_HALF = 0.31         # half width of a U leg across the table
TUBE = 0.0115


def wood_textures(weapon_id: str) -> tuple:
    """Particle board with a light wood-laminate face: grain along the
    length (UV x, from the top's cube projection), board flecks on the edges
    and underside, scuffs and a dirty ring where the boots have been."""
    rng = np.random.RandomState(kit.seed_of(weapon_id + "_wood"))
    n = kit.TEX_SIZE
    warp = kit.fbm(rng, n, 3, 4)
    fine = kit.fbm(rng, n, 80, 2)
    yy = np.linspace(0, 1, n, endpoint=False)[:, None].repeat(n, 1)
    # fine, near-straight grain: ~3 mm lines over the 1.8 m the map covers
    grain = 0.5 + 0.5 * np.sin(2 * math.pi * (yy * 170.0 + warp * 1.6 + fine * 0.25))
    grain = grain ** 3.0 * (0.6 + 0.4 * kit.fbm(rng, n, 12, 2))
    light = np.array([0.66, 0.53, 0.38])
    dark = np.array([0.47, 0.34, 0.22])
    lam = light[None, None] * (1 - grain[..., None] * 0.45) + dark[None, None] * grain[..., None] * 0.45
    lam *= 0.93 + 0.12 * fine[..., None]
    flecks = kit.fbm(rng, n, 160, 2)
    board = np.array([0.55, 0.44, 0.30])[None, None] * (0.75 + 0.5 * flecks[..., None])
    # the top face and the rest share one map: the laminate covers most of it,
    # board shows through where it is worn (and is all there is on the edges,
    # which the projection lands on the same pixels -- so wear reads as edge)
    worn = np.clip((kit.fbm(rng, n, 5, 4) - 0.70) * 5.0, 0, 1) * 0.7
    scuff = kit.scratches(rng, n, 120, 0.12, 1, spread=0.8) * 0.6
    base = lam * (1 - worn[..., None]) + board * worn[..., None]
    base = base * (1 - scuff[..., None] * 0.25) + scuff[..., None] * 0.08
    dirt = np.clip((kit.fbm(rng, n, 7, 3) - 0.55) * 3.0, 0, 1)
    base *= 1 - dirt[..., None] * 0.25
    rough = 0.48 + 0.25 * worn + 0.15 * scuff + 0.1 * dirt
    orm = np.stack([np.ones_like(rough), np.clip(rough, 0, 1), np.zeros_like(rough)], -1)
    nrm = kit.normal_from_height(grain * 0.15 - worn * 0.4 + flecks * worn * 0.4 - scuff * 0.2, 3.0)
    d = kit.TEX_DIR
    kit.save_rgb(np.clip(base, 0, 0.85), d / f"{weapon_id}_wood_base.png")
    kit.save_rgb(orm, d / f"{weapon_id}_wood_orm.png")
    kit.save_rgb(nrm, d / f"{weapon_id}_wood_normal.png")
    return d / f"{weapon_id}_wood_base.png", d / f"{weapon_id}_wood_orm.png", d / f"{weapon_id}_wood_normal.png"


def slab(part: kit.WeaponPart, outline: list[tuple[float, float]], y0: float, y1: float) -> None:
    """A flat solid: `outline` (x, z, counter-clockwise from above) extruded
    from y0 to y1. Non-convex outlines are fine (n-gon caps)."""
    bot = [part.vert(Vector((x, y0, z))) for x, z in outline]
    top = [part.vert(Vector((x, y1, z))) for x, z in outline]
    part.bm.faces.new(top)
    part.bm.faces.new(list(reversed(bot)))
    m = len(outline)
    for i in range(m):
        j = (i + 1) % m
        part.quad(bot[i], bot[j], top[j], top[i])


def crack_line(rng: np.random.RandomState, steps: int = 14) -> list[tuple[float, float]]:
    """The ragged break across the board, from the front edge (-z) to the
    back (+z), wandering a few centimetres either side of x = 0.08."""
    pts = []
    x = 0.08
    for k in range(steps + 1):
        z = -WID / 2 + WID * k / steps
        x += rng.uniform(-0.028, 0.028)
        x = max(0.0, min(0.16, x))
        pts.append((x, z))
    return pts


def splinters(part: kit.WeaponPart, edge: list[tuple[float, float]], side: float,
              rng: np.random.RandomState, y: float) -> None:
    """Thin slivers standing out of a broken edge (side -1: the left half's
    edge, sticking out toward +x)."""
    for k in range(1, len(edge) - 1):
        if rng.rand() < 0.35:
            continue
        x, z = edge[k]
        ln = rng.uniform(0.02, 0.07)
        w = rng.uniform(0.004, 0.010)
        h = rng.uniform(0.003, THICK * 0.6)
        tilt = rng.uniform(-0.5, 0.5)
        yaw = rng.uniform(-0.5, 0.5)
        dirv = Vector((-side * math.cos(yaw), math.sin(tilt) * 0.6, math.sin(yaw))).normalized()
        base = Vector((x, y + rng.uniform(-THICK * 0.3, THICK * 0.3), z))
        tip = base + dirv * ln
        across = Vector((0, 0, 1)) if abs(dirv.z) < 0.7 else Vector((1, 0, 0))
        a = base - across * w
        b = base + across * w
        up = Vector((0, h, 0))
        v = [part.vert(p) for p in (a, b, b + up, a + up, tip, tip + up * 0.3)]
        for f in ((0, 1, 2, 3), (0, 3, 5, 4), (1, 4, 5, 2), (0, 4, 1), (3, 2, 5)):
            try:
                part.bm.faces.new([v[i] for i in f])
            except ValueError:
                pass


TRIM_R = 0.0125


def trim(part: kit.WeaponPart, path_xz: list[tuple[float, float]], y: float) -> None:
    """The vinyl T-moulding round a banquet table's edge."""
    part.tube([Vector((x, y, z)) for x, z in path_xz], TRIM_R, 10, caps=True)


def outline_trim(half_l: float, half_w: float) -> list[tuple[float, float]]:
    r = 0.03
    pts = []
    for cx, cz, a0 in ((half_l, half_w, 0.0), (-half_l, half_w, 0.5 * math.pi),
                       (-half_l, -half_w, math.pi), (half_l, -half_w, 1.5 * math.pi)):
        for k in range(5):
            a = a0 + 0.5 * math.pi * k / 4
            pts.append((cx - math.copysign(r, cx) + math.cos(a) * r, cz - math.copysign(r, cz) + math.sin(a) * r))
    pts.append(pts[0])
    return pts


def u_leg(part: kit.WeaponPart, hinge_x: float, foot_x: float, foot_y: float, top_y: float,
          brace_to: Vector | None) -> None:
    """A U leg: two tubes from the hinge under the top down to the feet,
    a foot rail across them, a cross bar, a brace back to the underside."""
    for s in (-1, 1):
        part.tube([Vector((hinge_x, top_y, s * LEG_HALF)), Vector((foot_x, foot_y, s * LEG_HALF))], TUBE, 10)
        part.tube([Vector((foot_x, foot_y, s * LEG_HALF)) + Vector((0, -0.002, 0)),
                   Vector((foot_x, foot_y, s * LEG_HALF)) + Vector((0, 0.03, 0))], TUBE + 0.003, 10)
    part.tube([Vector((foot_x, foot_y + 0.03, -LEG_HALF)), Vector((foot_x, foot_y + 0.03, LEG_HALF))], TUBE, 10)
    mid = Vector((hinge_x, top_y, 0)).lerp(Vector((foot_x, foot_y, 0)), 0.35)
    part.tube([mid + Vector((0, 0, -LEG_HALF)), mid + Vector((0, 0, LEG_HALF))], TUBE * 0.8, 10)
    part.tube([Vector((hinge_x, top_y, -LEG_HALF - 0.02)), Vector((hinge_x, top_y, LEG_HALF + 0.02))], TUBE * 0.9, 10)
    if brace_to is not None:
        part.tube([mid, brace_to], TUBE * 0.7, 8)


def build(root, prefix: str, state: str, wood, steel, trim_mat) -> None:
    rng = np.random.RandomState(kit.seed_of("table_break"))
    half_l, half_w = LEN / 2, WID / 2
    if state == "Folded":
        y0 = 0.035                       # lying on its folded legs
        top = kit.WeaponPart(prefix + "_top")
        slab(top, [(-half_l, -half_w), (half_l, -half_w), (half_l, half_w), (-half_l, half_w)], y0, y0 + THICK)
        kit.add_mesh(root, top, wood, uv_scale=0.55)
        edge = kit.WeaponPart(prefix + "_trim")
        trim(edge, outline_trim(half_l, half_w), y0 + THICK / 2)
        kit.add_mesh(root, edge, trim_mat)
        legs = kit.WeaponPart(prefix + "_legs")
        for s in (-1, 1):
            u_leg(legs, s * LEG_X, s * (LEG_X - 0.62), 0.012, 0.024, None)
        kit.add_mesh(root, legs, steel)
        kit.marker(root, "top", Vector((0, y0 + THICK, 0)))
        kit.marker(root, "grip_r", Vector((0.35, y0 + THICK * 0.5, -half_w)), Vector((1, 0, 0)), Vector((0, 0, -1)))
        kit.marker(root, "grip_l", Vector((-0.35, y0 + THICK * 0.5, -half_w)), Vector((1, 0, 0)), Vector((0, 0, -1)))
        return
    y0, y1 = TOP_Y - THICK, TOP_Y
    if state == "Up":
        top = kit.WeaponPart(prefix + "_top")
        slab(top, [(-half_l, -half_w), (half_l, -half_w), (half_l, half_w), (-half_l, half_w)], y0, y1)
        kit.add_mesh(root, top, wood, uv_scale=0.55)
        edge = kit.WeaponPart(prefix + "_trim")
        trim(edge, outline_trim(half_l, half_w), y0 + THICK / 2)
        kit.add_mesh(root, edge, trim_mat)
        legs = kit.WeaponPart(prefix + "_legs")
        for s in (-1, 1):
            u_leg(legs, s * LEG_X, s * (LEG_X - 0.04), 0.0, y0 - TUBE, Vector((s * 0.15, y0 - TUBE, 0)))
        kit.add_mesh(root, legs, steel)
        kit.marker(root, "top", Vector((0, y1, 0)))
        kit.marker(root, "grip_r", Vector((0.35, y1, -half_w)), Vector((1, 0, 0)), Vector((0, 1, 0)))
        kit.marker(root, "grip_l", Vector((-0.35, y1, -half_w)), Vector((1, 0, 0)), Vector((0, 1, 0)))
        return
    # Broken: two halves along a ragged line, slivers, loose chunks, the legs
    crack = crack_line(rng)
    left = [(-half_l, half_w), (-half_l, -half_w)] + crack
    right = [(half_l, -half_w), (half_l, half_w)] + list(reversed(crack))
    pieces = []
    for idx, (outline, side) in enumerate(((left, -1), (right, 1))):
        # each piece's mesh around its own centre; the node carries the offset
        cx = sum(p[0] for p in outline) / len(outline)
        part = kit.WeaponPart("%s__piece_%02d" % (prefix, idx))
        local = [(x - cx, z) for x, z in outline]
        # counter-clockwise from above for the right winding
        area = sum(local[i][0] * local[(i + 1) % len(local)][1] - local[(i + 1) % len(local)][0] * local[i][1]
                   for i in range(len(local)))
        if area < 0:
            local = list(reversed(local))
        slab(part, local, -THICK / 2, THICK / 2)
        splinters(part, [(x - cx, z) for x, z in crack], side, rng, 0.0)
        pieces.append((part, Vector((cx, y0 + THICK / 2, 0)), wood))
        # its trim, round the three outer sides only -- torn at the crack
        band = kit.WeaponPart("%s__piece_%02d_trim" % (prefix, idx))
        end_x = -half_l if side < 0 else half_l
        path = [(crack[-1][0] - cx, half_w), (end_x - cx, half_w), (end_x - cx, -half_w), (crack[0][0] - cx, -half_w)]
        trim(band, path, 0.0)
        pieces.append((band, Vector((cx, y0 + THICK / 2, 0)), trim_mat))
    # loose chunks and slivers off the break
    for k in range(5):
        part = kit.WeaponPart("%s__piece_%02d" % (prefix, 2 + k))
        w, ln = rng.uniform(0.015, 0.05), rng.uniform(0.05, 0.16)
        slab(part, [(-ln / 2, -w / 2), (ln / 2, -w / 2), (ln / 2 + 0.01, w / 2), (-ln / 2, w / 2)],
             -THICK * 0.3, THICK * 0.3)
        x, z = crack[2 + k * 2]
        pieces.append((part, Vector((x, y0 + THICK / 2, z)), wood))
    for k, s in enumerate((-1, 1)):
        # buckled: the feet kicked out, the leg leaning in under the break --
        # each U its own piece, around its own hinge, so it can fall flat
        legs = kit.WeaponPart("%s__piece_%02d" % (prefix, 7 + k))
        u_leg(legs, 0.0, s * 0.10, 0.0, y0 - TUBE, Vector((s * 0.22 - s * LEG_X, y0 - TUBE - 0.04, 0)))
        pieces.append((legs, Vector((s * LEG_X, 0, 0)), steel))
    for part, at, mat in pieces:
        obj = kit.add_mesh(root, part, mat, uv_scale=0.55)
        obj.location = kit.to_blender(at)
        obj["piece"] = True
        # the two halves sag a few degrees into the break, still in place
        if part.name.endswith(("__piece_00", "__piece_01", "__piece_00_trim", "__piece_01_trim")):
            side = -1.0 if "_00" in part.name else 1.0
            obj.rotation_euler = (0.0, -side * math.radians(7.0), 0.0)
            obj.location.z -= 0.035
    kit.marker(root, "top", Vector((0, y1, 0)))


# --- the ladder ------------------------------------------------------------------

LAD_LEN = 3.05           # rail length
LAD_HALF_W_BOT, LAD_HALF_W_TOP = 0.30, 0.22
LAD_RUNG = 0.30


def ladder_half(part, steps, rail_mat_part, foot_part, angle: float, back: bool, open_: bool) -> list:
    """One side of an A-frame: two rails tapering in toward the top, steps
    (front) or round braces (back). Returns the rung centres (front side)."""
    rungs = []
    # feet apart, tops together: the front half's feet forward (-Z)
    dirz = -1.0 if not back else 1.0
    rise = math.cos(angle)

    def at(s_, x):
        z = (LAD_LEN - s_) * math.sin(angle) * dirz
        return Vector((x, s_ * rise, z + (0.0 if open_ else (0.04 if back else 0.0))))
    for sx in (-1, 1):
        pts = []
        for k in range(11):
            s_ = LAD_LEN * k / 10
            hw = LAD_HALF_W_BOT + (LAD_HALF_W_TOP - LAD_HALF_W_BOT) * (s_ / LAD_LEN)
            pts.append(at(s_, sx * hw))
        # a C-channel rail: a rounded rectangle section, 76 x 25 mm
        from swung import section_sweep, rounded_rect_section
        section_sweep(rail_mat_part, pts, lambda t, tan: Vector((1, 0, 0)), rounded_rect_section(0.076, 0.026, 0.004),
                      sides=12, caps=True)
        kit.sweep(foot_part, [pts[0] - Vector((0, 0.01, 0)), pts[0] + Vector((0, 0.07, 0))],
                  lambda t, th: 0.034, sides=12, caps=True)
    n = int(LAD_LEN / LAD_RUNG)
    for k in range(1, n):
        s_ = k * LAD_RUNG
        hw = LAD_HALF_W_BOT + (LAD_HALF_W_TOP - LAD_HALF_W_BOT) * (s_ / LAD_LEN)
        c = at(s_, 0.0)
        if not back:
            # a flat step, level when the ladder stands open, with ridges
            steps.oriented_box(c, Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((hw * 2, 0.022, 0.085)), bevel=0.004)
            for r in (-0.025, 0.0, 0.025):
                steps.box(c + Vector((0, 0.012, r)), Vector((hw * 2 - 0.02, 0.004, 0.006)))
            rungs.append(c + Vector((0, 0.011, 0)))
        elif k % 3 == 0:
            rail_mat_part.tube([at(s_, -hw), at(s_, hw)], 0.012, 10)
    return rungs


def build_ladder(root, prefix, alu, steps_mat, cap_mat, open_: bool) -> None:
    rails = kit.WeaponPart(prefix + "_rails")
    steps = kit.WeaponPart(prefix + "_steps")
    feet = kit.WeaponPart(prefix + "_feet")
    cap = kit.WeaponPart(prefix + "_cap")
    angle = math.radians(13) if open_ else 0.0
    if open_:
        height = LAD_LEN * math.cos(angle)
        spread = LAD_LEN * math.sin(angle)
        rungs = ladder_half(steps, steps, rails, feet, angle, False, True)
        ladder_half(steps, steps, rails, feet, angle, True, True)
        # move both halves so the feet straddle the origin and the top meets
        cap.box(Vector((0, height + 0.03, 0)), Vector((LAD_HALF_W_TOP * 2 + 0.10, 0.07, 0.20)), bevel=0.02,
                bevel_segments=2)
        # spreader bars, one each side, halfway down
        for sx in (-1, 1):
            y = height * 0.42
            rails.tube([Vector((sx * 0.27, y, -spread * 0.58)), Vector((sx * 0.27, y - 0.04, 0)),
                        Vector((sx * 0.27, y, spread * 0.58))], 0.008, 8)
    else:
        rungs = ladder_half(steps, steps, rails, feet, 0.0, False, False)
        ladder_half(steps, steps, rails, feet, 0.0, True, False)
        cap.box(Vector((0, LAD_LEN + 0.03, 0.02)), Vector((LAD_HALF_W_TOP * 2 + 0.10, 0.07, 0.11)), bevel=0.02,
                bevel_segments=2)
    kit.add_mesh(root, rails, alu, uv_scale=1.5)
    kit.add_mesh(root, steps, steps_mat, uv_scale=2.0)
    kit.add_mesh(root, feet, cap_mat, uv_scale=4.0)
    kit.add_mesh(root, cap, cap_mat, uv_scale=2.0)
    for k, c in enumerate(rungs):
        kit.marker(root, "rung_%d" % (k + 1), c)
    top_y = LAD_LEN * math.cos(angle) + 0.065
    kit.marker(root, "top", Vector((0, top_y, 0)))
    kit.marker(root, "grip_r", rungs[3] + Vector((0.18, 0, 0)), Vector((0, 1, 0)), Vector((1, 0, 0)))
    kit.marker(root, "grip_l", rungs[1] + Vector((-0.18, 0, 0)), Vector((0, 1, 0)), Vector((-1, 0, 0)))


# --- thumbtacks, bed of nails ---------------------------------------------------------

def tack(part, at: Vector, up: Vector, spin: float) -> None:
    """A brass drawing pin: a domed 10 mm head and an 11 mm point."""
    up = up.normalized()
    kit.sweep(part, [at, at + up * 0.0025], lambda t, th: 0.0052 * math.sqrt(max(1 - t * t, 0.05)), sides=8, caps=True)
    kit.sweep(part, [at, at - up * 0.011], lambda t, th: 0.0007 * (1 - t) + 0.0001, sides=4, caps=False)


def build_tacks(root, prefix, brass, bag_mat, scattered: bool) -> None:
    rng = np.random.RandomState(kit.seed_of("thumbtacks"))
    tacks = kit.WeaponPart(prefix + "_tacks")
    if scattered:
        # poured out: a heap thinning to strays over a metre; about half land
        # point-up, which is the point
        for k in range(260):
            r = abs(rng.normal(0, 0.28)) + rng.uniform(0, 0.05)
            a = rng.uniform(0, 2 * math.pi)
            at = Vector((math.cos(a) * r, 0.0, math.sin(a) * r))
            if rng.rand() < 0.5:
                tack(tacks, at + Vector((0, 0.012, 0)), Vector((0, 1, 0)), a)          # point up
            else:
                tilt = Vector((math.cos(a + 1.3), 0.25, math.sin(a + 1.3)))
                tack(tacks, at + Vector((0, 0.004, 0)), tilt, a)                      # on its side
        kit.add_mesh(root, tacks, brass, uv_scale=40.0, auto_smooth_deg=180.0)
        kit.marker(root, "top", Vector((0, 0.01, 0)))
        return
    # the bag: a clear zip bag, sagging round its load, held at the zip
    for k in range(70):
        at = Vector((rng.uniform(-0.07, 0.07), rng.uniform(-0.17, -0.06), rng.uniform(-0.02, 0.02)))
        tack(tacks, at, Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))), 0.0)
    kit.add_mesh(root, tacks, brass, uv_scale=40.0, auto_smooth_deg=180.0)
    bag = kit.WeaponPart(prefix + "_bag")
    bag.grid_panel(Vector((-0.09, -0.20, 0.0)), Vector((0.18, 0, 0)), Vector((0, 0.20, 0)), 10, 12, 0.0004,
                   lambda s_, t: 0.035 * math.sin(math.pi * s_) * (1 - t) ** 0.6 + 0.004)
    bag.grid_panel(Vector((-0.09, -0.20, 0.0)), Vector((0.18, 0, 0)), Vector((0, 0.20, 0)), 10, 12, 0.0004,
                   lambda s_, t: -0.035 * math.sin(math.pi * s_) * (1 - t) ** 0.6 - 0.004)
    bag.box(Vector((0, -0.006, 0)), Vector((0.182, 0.008, 0.006)))                 # the zip
    kit.add_mesh(root, bag, bag_mat, uv_scale=8.0, auto_smooth_deg=180.0)
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "pour", Vector((0, -0.18, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)))


def build_bed_of_nails(root, prefix, wood, nails_mat) -> None:
    """A 1.2 x 0.6 m plywood board, nails on a 5 cm grid poking 5 cm up
    through it. Origin at floor centre; lie a man on it."""
    board = kit.WeaponPart(prefix + "_board")
    board.box(Vector((0, 0.009, 0)), Vector((1.2, 0.018, 0.6)), bevel=0.003)
    kit.add_mesh(root, board, wood, uv_scale=0.8)
    nails = kit.WeaponPart(prefix + "_nails")
    rng = np.random.RandomState(kit.seed_of("bed_of_nails"))
    for i in range(23):
        for j in range(11):
            x = -0.55 + i * 0.05 + rng.uniform(-0.004, 0.004)
            z = -0.25 + j * 0.05 + rng.uniform(-0.004, 0.004)
            lean = Vector((rng.uniform(-0.08, 0.08), 1.0, rng.uniform(-0.08, 0.08))).normalized()
            base = Vector((x, 0.018, z))
            tip = base + lean * rng.uniform(0.045, 0.055)
            nails.tube([base, tip - lean * 0.005], 0.0016, 4, caps=False)
            kit.sweep(nails, [tip - lean * 0.005, tip], lambda t, th: 0.0016 * (1 - t), sides=4, caps=False)
    kit.add_mesh(root, nails, nails_mat, uv_scale=20.0, auto_smooth_deg=180.0)
    kit.marker(root, "top", Vector((0, 0.07, 0)))
    kit.marker(root, "grip_r", Vector((0.6, 0.009, 0)), Vector((0, 0, 1)), Vector((1, 0, 0)))
    kit.marker(root, "grip_l", Vector((-0.6, 0.009, 0)), Vector((0, 0, 1)), Vector((-1, 0, 0)))


# --- light tubes ---------------------------------------------------------------------

TUBE_LEN, TUBE_R = 1.20, 0.0128


def build_tubes(root, prefix, glass, caps_mat, tape_mat, broken: bool) -> None:
    """Six 4-foot fluorescent tubes taped into a bundle with gaffer tape at
    three bands. Held at one end band like a bat. Broken: each tube snapped
    in two or three, the halves still in the tape, glass shards loose."""
    rng = np.random.RandomState(kit.seed_of("light_tubes"))
    centres = [Vector((math.cos(a) * 0.0145, 0, math.sin(a) * 0.0145)) for a in np.linspace(0, 2 * math.pi, 6, endpoint=False)]
    centres = [Vector((0, 0, 0))] + [Vector((math.cos(a) * 0.026, 0, math.sin(a) * 0.026))
                                    for a in np.linspace(0, 2 * math.pi, 6, endpoint=False)]
    centres = centres[:6]
    y0, y1 = -0.10, TUBE_LEN - 0.10
    glass_p = kit.WeaponPart(prefix + "_glass")
    caps_p = kit.WeaponPart(prefix + "_caps")
    pieces = []
    for k, c in enumerate(centres):
        if not broken:
            kit.sweep(glass_p, [c + Vector((0, y0 + 0.02, 0)), c + Vector((0, y1 - 0.02, 0))],
                      lambda t, th: TUBE_R, sides=12, caps=False)
        else:
            cut = y0 + rng.uniform(0.45, 0.75) * TUBE_LEN
            kit.sweep(glass_p, [c + Vector((0, y0 + 0.02, 0)), c + Vector((0, cut, 0))],
                      lambda t, th: TUBE_R * (1 if t < 0.97 else 0.85 + 0.3 * abs(math.sin(th * 3 + k))),
                      sides=12, caps=False)
            # the far end, a separate piece, knocked off line
            far = kit.WeaponPart("%s__piece_%02d" % (prefix, k))
            kit.sweep(far, [Vector((0, cut + 0.03, 0)), Vector((0, y1 - 0.02, 0))],
                      lambda t, th: TUBE_R * (1 if t > 0.03 else 0.8 + 0.3 * abs(math.sin(th * 3 - k))),
                      sides=12, caps=False)
            far.tube([Vector((0, y1 - 0.02, 0)), Vector((0, y1, 0))], TUBE_R + 0.0005, 12)
            pieces.append((far, c + Vector((rng.uniform(-0.03, 0.03), 0, rng.uniform(-0.03, 0.03))),
                           (rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08))))
        for yy in ((y0, y0 + 0.02),) + (((y1 - 0.02, y1),) if not broken else ()):
            caps_p.tube([c + Vector((0, yy[0], 0)), c + Vector((0, yy[1], 0))], TUBE_R + 0.0005, 12)
            for px in (-0.006, 0.006):
                end = yy[0] if yy[0] == y0 else yy[1]
                d = -1 if yy[0] == y0 else 1
                caps_p.tube([c + Vector((px, end, 0)), c + Vector((px, end + d * 0.007, 0))], 0.0011, 4)
    kit.add_mesh(root, glass_p, glass, uv_scale=2.0, auto_smooth_deg=180.0)
    kit.add_mesh(root, caps_p, caps_mat, uv_scale=8.0)
    tape = kit.WeaponPart(prefix + "_tape")
    for yy in (0.0, 0.50, 0.95):
        if broken and yy > 0.4:
            continue
        kit.sweep(tape, [Vector((0, yy - 0.025, 0)), Vector((0, yy + 0.025, 0))],
                  lambda t, th: 0.0405 + 0.002 * abs(math.cos(th * 3)), sides=24, caps=False)
    kit.add_mesh(root, tape, tape_mat, uv_scale=8.0, auto_smooth_deg=180.0)
    for part, at, tilt in pieces:
        o = kit.add_mesh(root, part, glass, uv_scale=2.0, auto_smooth_deg=180.0)
        o.location = kit.to_blender(at)
        o.rotation_euler = (tilt[0], 0.0, tilt[1])
        o["piece"] = True
    if broken:
        shards = kit.WeaponPart(prefix + "__piece_06")
        for k in range(40):
            p = Vector((rng.uniform(-0.05, 0.05), rng.uniform(0.3, 0.9), rng.uniform(-0.05, 0.05)))
            a = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized() * rng.uniform(0.008, 0.02)
            b = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized() * rng.uniform(0.008, 0.02)
            v = [shards.vert(p), shards.vert(p + a), shards.vert(p + b)]
            try:
                shards.bm.faces.new(v)
            except ValueError:
                pass
        o = kit.add_mesh(root, shards, glass, uv_scale=2.0, smooth=False)
        o["piece"] = True
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((0, -0.06, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0, 0.70, 0)), Vector((0, 1, 0)), Vector((0, 0, -1)))


def tube_glass_texture(name: str) -> pathlib.Path:
    """The phosphor coat: milky white, faintly banded, a little dirty."""
    rng = np.random.RandomState(kit.seed_of(name + "_glass"))
    n = 256
    band = kit.fbm(rng, n, 8, 3)
    rgb = np.ones((n, n, 3)) * (0.78 + 0.06 * band[..., None])
    a = np.full((n, n), 0.88) - 0.08 * band
    path = kit.TEX_DIR / f"{name}_glass_base.png"
    kit.save_rgba(np.concatenate([np.clip(rgb, 0, 0.85), np.clip(a, 0, 1)[..., None]], -1), path)
    return path


# --- barbed-wire board ------------------------------------------------------------------

def build_wire_board(root, prefix, wood, wire) -> None:
    """A 1.2 x 0.8 m sheet of plywood with barbed wire wrapped round it,
    five strands front to back and two across. Origin at its foot's centre,
    stood on its long edge, the wired face toward -Z."""
    board = kit.WeaponPart(prefix + "_board")
    board.box(Vector((0, 0.40, 0)), Vector((1.2, 0.80, 0.018)), bevel=0.003)
    kit.add_mesh(root, board, wood, uv_scale=0.8)
    w = kit.WeaponPart(prefix + "_wire")
    rng = np.random.RandomState(kit.seed_of("wire_board"))
    for k in range(5):
        x = -0.48 + k * 0.24 + rng.uniform(-0.02, 0.02)
        loop = [Vector((x + 0.02 * math.sin(f * 7 + k), 0.40 + 0.4 * math.cos(a) * 1.02, 0.012 * math.sin(a) * 1.4))
                for f, a in zip(np.linspace(0, 1, 40), np.linspace(-math.pi * 0.98, math.pi * 0.98, 40))]
        loop = [Vector((p.x, max(min(p.y, 0.805), -0.005), p.z if abs(p.y - 0.40) < 0.39 else p.z * 0.5)) for p in loop]
        # a front run (z < 0) down the face and the back run up
        front = [Vector((x + 0.015 * math.sin(f * 9 + k), 0.80 - 0.80 * f, -0.012)) for f in np.linspace(0, 1, 24)]
        kit.barbed_wire(w, front, rng)
    for k, y in enumerate((0.22, 0.58)):
        across = [Vector((-0.6 + 1.2 * f, y + 0.02 * math.sin(f * 11 + k), -0.0135)) for f in np.linspace(0, 1, 30)]
        kit.barbed_wire(w, across, rng)
    kit.add_mesh(root, w, wire, uv_scale=4.0, auto_smooth_deg=180.0)
    kit.marker(root, "top", Vector((0, 0.40, -0.02)), Vector((0, 1, 0)), Vector((0, 0, -1)))
    kit.marker(root, "grip_r", Vector((0.45, 0.80, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((-0.45, 0.80, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))


def plywood_textures(name: str) -> tuple:
    return kit.wood_textures(name, (0.74, 0.60, 0.42), (0.60, 0.45, 0.28), 30, 0.0, along_rows=False)


def build_more(report: list) -> None:
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    from chairs import wire_textures
    kit.reset()
    wid = "ladder"
    alu = kit.pbr_material(wid + "_alu", *kit.metal_textures(wid, (0.70, 0.70, 0.68), 0.08, 0.35), 0.5)
    steps = kit.pbr_material(wid + "_steps", *kit.metal_textures(wid + "_steps", (0.60, 0.60, 0.58), 0.15, 0.45), 0.6)
    cap = kit.pbr_material(wid + "_cap", *kit.polymer_textures(wid + "_cap", (0.65, 0.50, 0.04)), 0.5)
    for state, open_ in (("Open", True), ("Closed", False)):
        root = kit.state_root("Ladder_" + state)
        build_ladder(root, root.name, alu, steps, cap, open_)
        report.append("ladder %s: %d triangles" % (state, kit.triangles_under(root)))
    kit.export(wid)

    kit.reset()
    wid = "thumbtacks"
    brass = kit.pbr_material(wid + "_brass", *kit.metal_textures(wid, (0.80, 0.64, 0.32), 0.05, 0.30, size=256), 0.5)
    bag = kit.flat_material(wid + "_bag", (0.85, 0.85, 0.85), 0.15, 0.0)
    bag.blend_method = "BLEND"
    bag.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = 0.25
    for state, sc in (("Bag", False), ("Scattered", True)):
        root = kit.state_root("Thumbtacks_" + state)
        build_tacks(root, root.name, brass, bag, sc)
        report.append("thumbtacks %s: %d triangles" % (state, kit.triangles_under(root)))
    kit.export(wid)

    kit.reset()
    wid = "bed_of_nails"
    wood = kit.pbr_material(wid + "_wood", *plywood_textures(wid), 0.7)
    nails = kit.pbr_material(wid + "_nails", *kit.metal_textures(wid, (0.45, 0.45, 0.43), 0.1, 0.4, rust=0.3,
                                                                  size=256), 0.5)
    root = kit.state_root("BedOfNails_Clean")
    build_bed_of_nails(root, root.name, wood, nails)
    report.append("bed_of_nails: %d triangles" % kit.triangles_under(root))
    kit.export(wid)

    kit.reset()
    wid = "light_tubes"
    glass = kit.pbr_material(wid + "_glass", tube_glass_texture(wid), None, None, roughness=0.15, alpha=True,
                             emission=0.15)
    glass.blend_method = "BLEND"
    caps_m = kit.flat_material(wid + "_caps", (0.70, 0.70, 0.68), 0.35, 1.0)
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    from swung import tape_textures
    tape = kit.pbr_material(wid + "_tape", *tape_textures(wid), 0.8)
    for state, broken in (("Clean", False), ("Broken", True)):
        root = kit.state_root("LightTubes_" + state)
        build_tubes(root, root.name, glass, caps_m, tape, broken)
        report.append("light_tubes %s: %d triangles" % (state, kit.triangles_under(root)))
    kit.export(wid)

    kit.reset()
    wid = "barbed_wire_board"
    wood = kit.pbr_material(wid + "_wood", *plywood_textures(wid), 0.7)
    wb, wo = wire_textures(wid)
    wire = kit.pbr_material(wid + "_wire", wb, wo, None)
    root = kit.state_root("BarbedWireBoard_Clean")
    build_wire_board(root, root.name, wood, wire)
    report.append("barbed_wire_board: %d triangles" % kit.triangles_under(root))
    kit.export(wid)


def main() -> None:
    report = []
    build_more(report)
    kit.reset()
    weapon_id = "table"
    wood = kit.pbr_material(weapon_id + "_wood", *wood_textures(weapon_id), 0.7)
    sb, so, sn = paint_textures(weapon_id + "_legs", (0.05, 0.05, 0.055), 0.18)
    steel = kit.pbr_material(weapon_id + "_legs", sb, so, sn, 0.7)
    trim_mat = kit.flat_material(weapon_id + "_trim", (0.035, 0.03, 0.028), 0.55)
    for state in ("Up", "Folded", "Broken"):
        root = kit.state_root("Table_" + state)
        build(root, root.name, state, wood, steel, trim_mat)
        report.append("table %s: %d triangles" % (root.name, kit.triangles_under(root)))
    report.append("wrote " + str(kit.export(weapon_id).relative_to(kit.ROOT)))
    print("\n".join(report))


if __name__ == "__main__":
    main()
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
    import bpy_exit  # noqa: E402 -- skip bpy's teardown segfault (see there)
    bpy_exit.finish(0)
