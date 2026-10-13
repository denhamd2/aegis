#!/usr/bin/env python3
"""Family 6, whips and fists (gauntlet/refs/weapons_nhb.md): the chain,
the weight belt (Cody's) and the brass knuckles.

Run:  python3 tools/blender/weapons/whips.py

  game/assets/weapons/chain.glb
      Chain_Clean    1.2 m of welded steel chain hanging from the right hand
      Chain_Wrapped  the same chain wound round the fist, its end trailing
  game/assets/weapons/weight_belt.glb
      WeightBelt_Clean  a leather lifting belt hanging from its buckle end,
                        as he whips with it; stitched, holed, worn
  game/assets/weapons/brass_knuckles.glb
      BrassKnuckles_Clean  four rings and a palm bar, on the right hand

Origins at the right hand's grip. The chain and belt hang down -Y from it
(the striking end is the far end, so grip_r's +Y points down them).
"""

from __future__ import annotations

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import weapon_kit as kit  # noqa: E402
from weapon_kit import Vector  # noqa: E402

import numpy as np  # noqa: E402

LINK_L, LINK_W, WIRE = 0.034, 0.020, 0.0032   # outside length / width, wire radius
PITCH = LINK_L - 2 * WIRE * 2 + 0.002          # centre-to-centre along the chain


def link(part, centre: Vector, along: Vector, across: Vector) -> None:
    """One oval link: a stadium-shaped loop of round wire."""
    along = along.normalized()
    across = across.normalized()
    hl = LINK_L / 2 - WIRE
    hw = LINK_W / 2 - WIRE
    straight = hl - hw
    pts = []
    for k in range(14):
        a = 2 * math.pi * k / 14
        c, s_ = math.cos(a), math.sin(a)
        # a stadium: semicircles at the ends, straight sides
        x = c * hw + math.copysign(straight, c) if abs(c) > 1e-6 else 0.0
        pts.append(centre + along * x + across * (s_ * hw))
    pts.append(pts[0])
    part.tube(pts, WIRE, 5, caps=False)


def chain_along(part, path: list, rng) -> None:
    """Links laid along `path` (polyline), each turned 90 degrees to the
    last, with a little random twist so it does not read as a pattern."""
    lengths = [0.0]
    for i in range(1, len(path)):
        lengths.append(lengths[-1] + (path[i] - path[i - 1]).length)
    total = lengths[-1]
    n = int(total / PITCH)
    seg = 0
    for k in range(n):
        d = k * PITCH + PITCH / 2
        while seg < len(path) - 2 and lengths[seg + 1] < d:
            seg += 1
        f = (d - lengths[seg]) / max(lengths[seg + 1] - lengths[seg], 1e-9)
        p = path[seg].lerp(path[seg + 1], f)
        tan = (path[seg + 1] - path[seg]).normalized()
        ref = Vector((1, 0, 0)) if abs(tan.x) < 0.9 else Vector((0, 0, 1))
        a = (ref - tan * ref.dot(tan)).normalized()
        b = tan.cross(a)
        twist = (math.pi / 2) * (k % 2) + rng.uniform(-0.15, 0.15)
        across = a * math.cos(twist) + b * math.sin(twist)
        link(part, p, tan, across)


def build_chain(root, prefix, steel, wrapped: bool) -> None:
    rng = np.random.RandomState(kit.seed_of("chain_" + ("wrap" if wrapped else "hang")))
    part = kit.WeaponPart(prefix + "_links")
    if not wrapped:
        # hanging from the fist, swinging a little out of plumb
        path = [Vector((0.02 * math.sin(f * 3), -1.2 * f, 0.06 * f * f)) for f in np.linspace(0, 1, 30)]
    else:
        # four turns round the fist (round the hand's X axis), then the tail
        path = []
        for f in np.linspace(0, 1, 120):
            a = f * 4 * 2 * math.pi
            path.append(Vector((-0.04 + 0.09 * f, math.cos(a) * 0.055, math.sin(a) * 0.055)))
        end = path[-1]
        path += [end + Vector((0.01, -0.1 * f, 0.02 * f)) for f in np.linspace(0.1, 1, 10)] \
            + [end + Vector((0.02, -0.1 - 0.35 * f, 0.03)) for f in np.linspace(0.1, 1, 8)]
    chain_along(part, path, rng)
    kit.add_mesh(root, part, steel, uv_scale=10.0, auto_smooth_deg=180.0)
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", path[-1], Vector((0, -1, 0)), Vector((0, 0, -1)))


def leather_textures(name: str, color: tuple) -> tuple:
    """Oiled lifting-belt leather: pebbled grain, darker worn edges, a
    stitch line inset from each edge (the map's v runs along the belt and u
    across it), and an original maker's stamp."""
    from PIL import Image, ImageDraw
    rng = np.random.RandomState(kit.seed_of(name + "_leather"))
    n = kit.TEX_SIZE
    grain = kit.fbm(rng, n, 120, 2)
    mottle = kit.fbm(rng, n, 6, 4)
    base = np.array(color)[None, None] * (0.85 + 0.15 * grain[..., None] + 0.2 * (mottle[..., None] - 0.5))
    u = np.linspace(0, 1, n, endpoint=False)[None, :].repeat(n, 0)
    edge = np.clip(1 - np.minimum(u, 1 - u) / 0.06, 0, 1) ** 2
    base = base * (1 - edge[..., None] * 0.35)
    stitch = np.zeros((n, n), np.float32)
    v = np.arange(n)[:, None].repeat(n, 1)
    for uu in (0.085, 0.915):
        on = (np.abs(u - uu) < 0.006) & ((v // 10) % 2 == 0)
        stitch = np.maximum(stitch, on.astype(np.float32))
    thread = np.array([0.80, 0.72, 0.55])
    base = base * (1 - stitch[..., None]) + thread * stitch[..., None]
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    f = kit.font(64)
    txt = Image.new("L", (420, 90), 0)
    ImageDraw.Draw(txt).text((10, 6), "AEGIS  LIFT", font=f, fill=255)
    txt = txt.rotate(90, expand=True)
    img.paste(txt, (n // 2 - txt.width // 2, int(n * 0.35)))
    del d
    stamp = np.asarray(img, np.float32) / 255.0
    base = base * (1 - stamp[..., None] * 0.45)
    r = 0.55 + 0.15 * grain - 0.15 * edge + 0.1 * stamp
    orm = np.stack([np.ones_like(r), np.clip(r, 0, 1), np.zeros_like(r)], -1)
    nrm = kit.normal_from_height(grain * 0.5 - stitch * 0.6 - stamp * 0.5, 3.0)
    dd = kit.TEX_DIR
    kit.save_rgb(np.clip(base, 0, 0.85), dd / f"{name}_leather_base.png")
    kit.save_rgb(orm, dd / f"{name}_leather_orm.png")
    kit.save_rgb(nrm, dd / f"{name}_leather_normal.png")
    return dd / f"{name}_leather_base.png", dd / f"{name}_leather_orm.png", dd / f"{name}_leather_normal.png"


def build_belt(root, prefix, leather, steel) -> None:
    """Hanging from the buckle end: the strap a flat band, 10 cm wide at the
    back tapering to 6 cm at the tongue, 1.1 m, curling a little as it
    hangs. Its own UVs: u across, v along."""
    strap = kit.WeaponPart(prefix + "_strap")
    L, T = 1.10, 0.009
    rows = 40
    grid_f, grid_b = [], []
    for j in range(rows + 1):
        f = j / rows
        y = -0.03 - L * f
        z = 0.05 * f * f + 0.012 * math.sin(f * 9)
        w = 0.06 + 0.04 * math.sin(math.pi * min(f / 0.7, 1.0)) if f < 0.92 else 0.06 * (1 - (f - 0.92) / 0.08 * 0.4)
        rf, rb = [], []
        for i in range(5):
            x = (i / 4 - 0.5) * w
            rf.append((strap.vert(Vector((x, y, z - T / 2))), (i / 4, f * L)))
            rb.append((strap.vert(Vector((x, y, z + T / 2))), (i / 4, f * L)))
        grid_f.append(rf)
        grid_b.append(rb)
    for j in range(rows):
        for i in range(4):
            a, b, c, d = grid_f[j][i], grid_f[j][i + 1], grid_f[j + 1][i + 1], grid_f[j + 1][i]
            strap.quad(a[0], b[0], c[0], d[0], [a[1], b[1], c[1], d[1]])
            a, b, c, d = grid_b[j][i], grid_b[j + 1][i], grid_b[j + 1][i + 1], grid_b[j][i + 1]
            strap.quad(a[0], b[0], c[0], d[0], [a[1], b[1], c[1], d[1]])
    for j in range(rows):
        for i in (0, 4):
            strap.quad(grid_f[j][i][0], grid_f[j + 1][i][0], grid_b[j + 1][i][0], grid_b[j][i][0])
    for j in (0, rows):
        for i in range(4):
            strap.quad(grid_f[j][i][0], grid_b[j][i][0], grid_b[j][i + 1][0], grid_f[j][i + 1][0])
    kit.add_mesh(root, strap, leather, project=False, auto_smooth_deg=40.0)
    metal = kit.WeaponPart(prefix + "_buckle")
    # a double-prong roller buckle, its frame round the strap's end
    frame = kit.rounded_rect(Vector((0, -0.01, 0)), Vector((1, 0, 0)), Vector((0, 1, 0)), 0.045, 0.03, 0.008, 3)
    metal.tube(frame, 0.004, 8, caps=False)
    metal.tube([Vector((-0.042, -0.035, 0)), Vector((0.042, -0.035, 0))], 0.006, 12)      # the roller
    for x in (-0.012, 0.012):
        metal.tube([Vector((x, 0.0, 0)), Vector((x, -0.03, -0.004))], 0.0028, 6)          # prongs
    # holes down the tongue end: grommets
    for k in range(7):
        f = 0.80 + k * 0.022
        y = -0.03 - L * f
        z = 0.05 * f * f + 0.012 * math.sin(f * 9)
        ring = [Vector((math.cos(a) * 0.006, y + math.sin(a) * 0.006, z - T / 2 - 0.0005))
                for a in np.linspace(0, 2 * math.pi, 13)]
        metal.tube(ring, 0.0012, 4, caps=False)
    kit.add_mesh(root, metal, steel, uv_scale=8.0)
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, -1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0, -0.03 - L * 0.95, 0.05)), Vector((0, -1, 0)), Vector((0, 0, -1)))


def build_knuckles(root, prefix, brass) -> None:
    """Four finger rings across X, a grip bar under them for the palm,
    joined by a web. Origin at the middle of the grip bar (the palm)."""
    part = kit.WeaponPart(prefix + "_brass")
    ring_r, wall = 0.0115, 0.0042
    for k in range(4):
        cx = -0.036 + k * 0.024
        ring = [Vector((cx, 0.032 + math.sin(a) * ring_r, math.cos(a) * ring_r)) for a in np.linspace(0, 2 * math.pi, 25)]
        part.tube(ring, wall, 10, caps=False)
    # the striking ridge over the knuckles, and the palm bar
    part.box(Vector((0, 0.032, -0.016)), Vector((0.104, 0.012, 0.008)), bevel=0.003)
    part.tube([Vector((-0.050, 0.004, 0.0)), Vector((-0.030, -0.006, 0.0)), Vector((0.030, -0.006, 0.0)),
               Vector((0.050, 0.004, 0.0))], 0.0075, 12)
    for x in (-0.05, 0.05):
        part.tube([Vector((x, 0.004, 0.0)), Vector((x * 0.95, 0.024, 0.0))], 0.006, 10)
    kit.add_mesh(root, part, brass, uv_scale=10.0, auto_smooth_deg=60.0)
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0, 0.032, -0.02)), Vector((1, 0, 0)), Vector((0, 0, -1)))


def main() -> None:
    report = []
    kit.reset()
    wid = "chain"
    steel = kit.pbr_material(wid + "_steel", *kit.metal_textures(wid, (0.55, 0.55, 0.53), 0.2, 0.35, rust=0.15,
                                                                   size=256), 0.5)
    for state, wrapped in (("Clean", False), ("Wrapped", True)):
        root = kit.state_root("Chain_" + state)
        build_chain(root, root.name, steel, wrapped)
        report.append("chain %s: %d triangles" % (state, kit.triangles_under(root)))
    kit.export(wid)

    kit.reset()
    wid = "weight_belt"
    leather = kit.pbr_material(wid + "_leather", *leather_textures(wid, (0.30, 0.16, 0.07)), 0.8)
    steel = kit.pbr_material(wid + "_buckle", *kit.metal_textures(wid, (0.70, 0.70, 0.68), 0.05, 0.25, size=256), 0.5)
    root = kit.state_root("WeightBelt_Clean")
    build_belt(root, root.name, leather, steel)
    report.append("weight_belt: %d triangles" % kit.triangles_under(root))
    kit.export(wid)

    kit.reset()
    wid = "brass_knuckles"
    brass = kit.pbr_material(wid + "_brass", *kit.metal_textures(wid, (0.80, 0.62, 0.30), 0.06, 0.25, size=256), 0.5)
    root = kit.state_root("BrassKnuckles_Clean")
    build_knuckles(root, root.name, brass)
    report.append("brass_knuckles: %d triangles" % kit.triangles_under(root))
    kit.export(wid)
    print("\n".join(report))


if __name__ == "__main__":
    main()
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
    import bpy_exit  # noqa: E402 -- skip bpy's teardown segfault (see there)
    bpy_exit.finish(0)
