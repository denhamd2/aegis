#!/usr/bin/env python3
"""Family 4, set pieces (gauntlet/refs/weapons_nhb.md) -- this pass: the
table.

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
    legs = kit.WeaponPart("%s__piece_%02d" % (prefix, 7))
    for s in (-1, 1):
        # buckled: the feet kicked out, the leg leaning in under the break
        u_leg(legs, s * LEG_X, s * (LEG_X + 0.10), 0.0, y0 - TUBE, Vector((s * 0.22, y0 - TUBE - 0.04, 0)))
    pieces.append((legs, Vector((0, 0, 0)), steel))
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


def main() -> None:
    report = []
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
