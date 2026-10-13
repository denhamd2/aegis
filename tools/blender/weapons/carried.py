#!/usr/bin/env python3
"""Family 3, carried and slammed (gauntlet/refs/weapons_nhb.md) -- this
pass: the trash can and its lid.

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


def main() -> None:
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
