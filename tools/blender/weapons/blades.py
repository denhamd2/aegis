#!/usr/bin/env python3
"""Blades for the No Holds Barred stage (the owner, 19 Oct: "the most
dangerous weapons laid out on the stage ... sharp knives and swords").

Run:  python3 tools/blender/weapons/blades.py

  game/assets/weapons/knife.glb   Knife_Clean   a 20 cm drop-point fighting
                                                knife: satin steel blade with
                                                a ground edge, brass guard,
                                                black polymer handle
  game/assets/weapons/sword.glb   Sword_Clean   a 72 cm single-edged sword
                                                with a gentle curve: polished
                                                blade, round steel guard, a
                                                wrapped two-hand handle

Both are held like a bat (swung.py): origin at the right hand's grip, the
blade running up +Y from it, grip_l below it for the sword's second hand,
strike at the blade's cutting point. The edge faces +X; an `edge` marker
points along it so a swing leads with the edge, not the flat.

No real maker's design or markings; the shapes are the generic type.
"""

from __future__ import annotations

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import weapon_kit as kit  # noqa: E402
from weapon_kit import Vector  # noqa: E402

import numpy as np  # noqa: E402


def blade(part, base_y: float, length: float, spine, edge, thick, curve, stations: int = 28) -> None:
    """A single-edged blade lofted up +Y from `base_y`. At t (0 at the guard,
    1 at the tip): `spine(t)` and `edge(t)` are the back and the cutting
    edge's x, `thick(t)` the spine's thickness, `curve(t)` an x offset that
    bends the whole section (a sabre's sweep). The section is a flat-ground
    pentagon: full thickness over the back 45%, then the grind to the edge."""
    rows = []
    for i in range(stations + 1):
        t = i / stations
        y = base_y + length * t
        sx, ex = spine(t) + curve(t), edge(t) + curve(t)
        if ex - sx < 0.0008:
            mid = 0.5 * (sx + ex)
            sx, ex = mid - 0.0004, mid + 0.0004
        th = max(thick(t), 0.0004) * 0.5
        gx = sx + 0.45 * (ex - sx)
        section = [Vector((sx, y, th)), Vector((gx, y, th)), Vector((ex, y, 0.0)),
                   Vector((gx, y, -th)), Vector((sx, y, -th))]
        rows.append([part.vert(p) for p in section])
    n = 5
    for i in range(stations):
        v0, v1 = i / stations, (i + 1) / stations
        for k in range(n):
            j = (k + 1) % n
            u0, u1 = k / n, (k + 1) / n
            part.quad(rows[i][k], rows[i][j], rows[i + 1][j], rows[i + 1][k],
                      [(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
    part.bm.faces.new(list(reversed(rows[0])))
    part.bm.faces.new(rows[-1])


def _y(y0: float, y1: float, n: int) -> list:
    return [Vector((0.0, y0 + (y1 - y0) * i / n, 0.0)) for i in range(n + 1)]


def _ease(t: float, start: float) -> float:
    """0 before `start`, rising to 1 at t = 1 along a quarter circle."""
    if t <= start:
        return 0.0
    u = (t - start) / (1.0 - start)
    return 1.0 - math.sqrt(max(0.0, 1.0 - u * u))


def build_knife(root, prefix, steel, brass, handle) -> None:
    b = kit.WeaponPart(prefix + "_blade")
    blade(b, 0.062, 0.20,
          spine=lambda t: -0.011 + 0.014 * _ease(t, 0.70),
          edge=lambda t: 0.015 - 0.012 * _ease(t, 0.45),
          thick=lambda t: 0.0048 * (1.0 - 0.8 * t ** 2),
          curve=lambda t: 0.0)
    kit.add_mesh(root, b, steel, uv_scale=8.0, auto_smooth_deg=30.0)
    g = kit.WeaponPart(prefix + "_guard")
    g.box(Vector((0.002, 0.057, 0.0)), Vector((0.062, 0.010, 0.016)), bevel=0.003)
    g.box(Vector((0.002, -0.068, 0.0)), Vector((0.030, 0.008, 0.022)), bevel=0.003)       # pommel
    kit.add_mesh(root, g, brass, uv_scale=10.0, auto_smooth_deg=60.0)
    h = kit.WeaponPart(prefix + "_handle")
    # an oval handle, swelling at the palm, finger grooves on the edge side
    kit.sweep(h, _y(-0.064, 0.052, 24),
              lambda t, th: (0.0125 + 0.002 * math.sin(math.pi * t) - 0.0012 * max(0.0, math.cos(th))
                             * (0.5 + 0.5 * math.cos(t * 2 * math.pi * 4))) * (1.0 - 0.28 * abs(math.sin(th))),
              sides=20, caps=True, v_scale=4.0)
    kit.add_mesh(root, h, handle, project=False, auto_smooth_deg=180.0)
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0.006, 0.21, 0)), Vector((0, 1, 0)), Vector((1, 0, 0)))
    kit.marker(root, "edge", Vector((0.015, 0.16, 0)), Vector((0, 1, 0)), Vector((1, 0, 0)))


def build_sword(root, prefix, steel, guard_steel, wrap) -> None:
    sweep_x = 0.035                                     # how far the tip stands off the line of the handle
    b = kit.WeaponPart(prefix + "_blade")
    blade(b, 0.075, 0.72,
          spine=lambda t: -0.015 + 0.018 * _ease(t, 0.93),
          edge=lambda t: 0.016 - 0.013 * _ease(t, 0.90),
          thick=lambda t: 0.0068 * (1.0 - 0.45 * t) * (1.0 - 0.7 * _ease(t, 0.9)),
          curve=lambda t: -sweep_x * t * t, stations=48)
    kit.add_mesh(root, b, steel, uv_scale=3.0, auto_smooth_deg=30.0)
    g = kit.WeaponPart(prefix + "_guard")
    kit.sweep(g, [Vector((0, 0.058, 0)), Vector((0, 0.066, 0))],
              lambda t, th: 0.036 + 0.004 * math.cos(th * 4), sides=32, caps=True)
    g.box(Vector((0, 0.071, 0)), Vector((0.036, 0.010, 0.013)), bevel=0.002)             # the collar
    kit.sweep(g, [Vector((0, -0.205, 0)), Vector((0, -0.192, 0))], lambda t, th: 0.0155, sides=20, caps=True)
    kit.add_mesh(root, g, guard_steel, project=False, auto_smooth_deg=50.0)
    h = kit.WeaponPart(prefix + "_wrap")
    # the wrap's diamond pattern, cross-laced up the handle
    kit.sweep(h, _y(-0.192, 0.058, 40),
              lambda t, th: (0.0145 + 0.0009 * abs(math.sin(th * 2 + t * 2 * math.pi * 9)))
              * (1.0 - 0.2 * abs(math.sin(th))),
              sides=24, caps=False, v_scale=6.0)
    kit.add_mesh(root, h, wrap, project=False, auto_smooth_deg=180.0)
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((0, -0.13, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0.012 - sweep_x * 0.56, 0.55, 0)), Vector((0, 1, 0)), Vector((1, 0, 0)))
    kit.marker(root, "edge", Vector((0.016 - sweep_x * 0.36, 0.50, 0)), Vector((0, 1, 0)), Vector((1, 0, 0)))


def main() -> None:
    report = []
    kit.reset()
    wid = "knife"
    # a blade is polished, not worked: smooth steel, no grain to read as stone
    steel = kit.flat_material(wid + "_steel", (0.86, 0.86, 0.85), 0.2, 1.0)
    brass = kit.pbr_material(wid + "_brass", *kit.metal_textures(wid + "_guard", (0.78, 0.60, 0.30), 0.08, 0.30,
                                                                  size=256), 0.5)
    handle = kit.pbr_material(wid + "_handle", *kit.polymer_textures(wid, (0.05, 0.05, 0.05), size=256), 0.6)
    root = kit.state_root("Knife_Clean")
    build_knife(root, root.name, steel, brass, handle)
    report.append("knife: %d triangles" % kit.triangles_under(root))
    report.append("wrote " + str(kit.export(wid).relative_to(kit.ROOT)))

    kit.reset()
    wid = "sword"
    steel = kit.flat_material(wid + "_steel", (0.90, 0.90, 0.89), 0.14, 1.0)
    guard = kit.pbr_material(wid + "_guard", *kit.metal_textures(wid + "_guard", (0.12, 0.11, 0.10), 0.25, 0.40,
                                                                  size=256), 0.6)
    wrap = kit.pbr_material(wid + "_wrap", *kit.polymer_textures(wid, (0.08, 0.05, 0.10), size=256), 0.6)
    root = kit.state_root("Sword_Clean")
    build_sword(root, root.name, steel, guard, wrap)
    report.append("sword: %d triangles" % kit.triangles_under(root))
    report.append("wrote " + str(kit.export(wid).relative_to(kit.ROOT)))
    print("\n".join(report))


if __name__ == "__main__":
    main()
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
    import bpy_exit  # noqa: E402 -- skip bpy's teardown segfault (see there)
    bpy_exit.finish(0)
