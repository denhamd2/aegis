#!/usr/bin/env python3
"""Family 5, sprays and firearms (gauntlet/refs/weapons_nhb.md): the fire
extinguisher, the handgun and the rocket launcher.

Run:  python3 tools/blender/weapons/sprays.py

  game/assets/weapons/fire_extinguisher.glb
      FireExtinguisher_Clean  a 6 kg dry-powder extinguisher; origin at the
                              carry handle where the right hand closes
      FireExtinguisher_Cloud  the discharge: a powder plume shell, origin at
                              the nozzle, running out along +Z (the
                              muzzle's), for the game to scale and fade

Red enamel cylinder with domed ends and a black foot ring, a chrome valve
head with the squeeze lever over the carry handle, a pressure gauge, the
safety pin and its tamper tag, a rubber hose down the side to a horn
clipped to the body, and a printed instruction label -- original artwork.
Scuffed and chipped like one kept under a ring.

Markers: grip_r (carry handle), grip_l (the horn, for two-handed aim),
muzzle (horn mouth, +Z out), strike (the base, for when it is swung).

  game/assets/weapons/handgun.glb
      Handgun_Clean   an original polymer-frame semi-automatic: steel slide
                      with rear serrations and three-dot sights, ejection
                      port, accessory rail, stippled grip. Origin at the
                      grip; the barrel points -Z.
      Handgun_Flash   the muzzle flash: crossed star planes, origin at the
                      muzzle, along its +Z
  game/assets/weapons/rpg.glb
      Rpg_Clean       a shoulder-fired launcher, loaded: steel tube, flared
                      venturi, varnished wooden heat shield with bands,
                      pistol grip and trigger, optical sight, the warhead
                      standing out of the muzzle. Origin at the pistol grip;
                      the tube points -Z and sits on the right shoulder.
      Rpg_Rocket      the projectile alone, fins open, origin at its middle,
                      nose along -Z
      Rpg_Blast       the detonation: a fireball core inside a billow of
                      smoke, origin on the floor at its centre
No real maker's design or markings; the shapes are the generic type.
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
from PIL import Image, ImageDraw  # noqa: E402

R = 0.076
# (y, radius) up the body, from the floor
BODY = [(0.0, 0.0), (0.003, 0.060), (0.010, 0.071), (0.030, R), (0.430, R), (0.455, 0.073),
        (0.480, 0.062), (0.500, 0.044), (0.512, 0.026), (0.516, 0.0)]
FOOT = [(0.0, 0.0), (0.0, 0.074), (0.012, 0.079), (0.050, 0.079), (0.056, 0.077)]
GRIP = Vector((-0.045, 0.585, 0.0))      # carry handle, under the lever


def label_texture(weapon_id: str) -> pathlib.Path:
    w, h = 1024, 768
    img = Image.new("RGB", (w, h), (226, 220, 200))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w, 150], fill=(168, 18, 14))
    f_big, f_mid, f_small = kit.font(104), kit.font(44), kit.font(26)
    d.text((40, 20), "FIRE EXTINGUISHER", font=f_big, fill=(245, 240, 230))
    d.text((40, 175), "ABC DRY POWDER  6 kg", font=f_mid, fill=(25, 22, 20))
    steps = ["1  PULL THE PIN", "2  AIM AT THE BASE", "3  SQUEEZE THE LEVER", "4  SWEEP SIDE TO SIDE"]
    for i, t in enumerate(steps):
        d.text((40, 260 + i * 46), t, font=f_small, fill=(30, 26, 24))
    for i, (letter, col) in enumerate((("A", (40, 120, 50)), ("B", (190, 30, 30)), ("C", (30, 70, 170)))):
        x0 = 560 + i * 150
        d.rectangle([x0, 250, x0 + 130, 380], outline=col, width=8)
        box = d.textbbox((0, 0), letter, font=f_big)
        d.text((x0 + 65 - (box[2] - box[0]) // 2 - box[0], 262), letter, font=f_big, fill=col)
    d.text((40, 470), "OPERATING TEMP -20 C TO +60 C   TEST PRESSURE 25 BAR", font=f_small, fill=(60, 54, 50))
    d.text((40, 510), "SERVICE ANNUALLY.  KEEP AWAY FROM CHILDREN.", font=f_small, fill=(60, 54, 50))
    d.rectangle([0, h - 70, w, h], fill=(168, 18, 14))
    arr = np.asarray(img, np.float32) / 255.0
    rng = np.random.RandomState(kit.seed_of(weapon_id + "_label"))
    wear = kit.fbm(rng, 1024, 8, 4)[:h, :w]
    scuff = kit.scratches(rng, 1024, 60, 0.15, 1, spread=1.0)[:h, :w]
    arr = arr * (0.88 + 0.14 * wear[..., None]) * (1 - scuff[..., None] * 0.3)
    path = kit.TEX_DIR / f"{weapon_id}_label_base.png"
    kit.save_rgb(np.clip(arr, 0, 0.85), path)
    return path


def chrome_material(name: str):
    return kit.flat_material(name, (0.80, 0.80, 0.78), 0.18, 1.0)


def lathe(part, profile, sides=40, v_scale=1.0):
    ys = [p[0] for p in profile]
    rs = [p[1] for p in profile]
    path = [Vector((0, y, 0)) for y in ys]
    # the sweep's radius is by arc fraction; give it per-ring radii instead
    total = sum((path[i + 1] - path[i]).length for i in range(len(path) - 1)) or 1.0
    arcs = [0.0]
    for i in range(1, len(path)):
        arcs.append(arcs[-1] + (path[i] - path[i - 1]).length)
    fr = [a / total for a in arcs]
    kit.sweep(part, path, lambda t, th: float(np.interp(t, fr, rs)), sides=sides, caps=False, v_scale=v_scale)


def ring_lathe(part, profile, sides=40):
    """A revolved (y, r) polyline, radius allowed to change at constant y."""
    rings = []
    for y, r in profile:
        rings.append([part.vert(Vector((math.cos(a) * r, y, math.sin(a) * r)))
                      for a in np.linspace(0, 2 * math.pi, sides, endpoint=False)])
    for i in range(len(rings) - 1):
        for k in range(sides):
            j = (k + 1) % sides
            part.quad(rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k])


def build_clean(root, prefix, paint, label, chrome, black, gauge_mat, tag_mat) -> None:
    def shift(p: Vector) -> Vector:
        return p - GRIP

    body = kit.WeaponPart(prefix + "_body", shift)
    lathe(body, [(y, r) for y, r in BODY], sides=48, v_scale=1.0)
    kit.add_mesh(root, body, paint, project=False, auto_smooth_deg=180.0)

    foot = kit.WeaponPart(prefix + "_foot", shift)
    ring_lathe(foot, [(y, r) for y, r in FOOT], 48)
    kit.add_mesh(root, foot, black, uv_scale=4.0)

    # the label: a band round the front half, its own UVs 0..1
    lab = kit.WeaponPart(prefix + "_label", shift)
    y0, y1, a0, a1 = 0.17, 0.39, math.radians(-200), math.radians(20)
    cols, rows = 32, 4
    grid = [[lab.vert(Vector((math.cos(a0 + (a1 - a0) * i / cols) * (R + 0.0008),
                              y0 + (y1 - y0) * j / rows,
                              math.sin(a0 + (a1 - a0) * i / cols) * (R + 0.0008))))
             for i in range(cols + 1)] for j in range(rows + 1)]
    for j in range(rows):
        for i in range(cols):
            lab.quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i],
                     [(1 - i / cols, j / rows), (1 - (i + 1) / cols, j / rows),
                      (1 - (i + 1) / cols, (j + 1) / rows), (1 - i / cols, (j + 1) / rows)])
    kit.add_mesh(root, lab, label, project=False, auto_smooth_deg=180.0)

    # valve head: collar, body, outlet, lever over the carry handle
    valve = kit.WeaponPart(prefix + "_valve", shift)
    ring_lathe(valve, [(0.512, 0.0), (0.512, 0.027), (0.540, 0.027), (0.544, 0.022), (0.556, 0.022),
                       (0.556, 0.018), (0.600, 0.018), (0.606, 0.0)], 24)
    valve.tube([Vector((0, 0.574, 0)), Vector((0.045, 0.574, 0))], 0.008, 12)          # outlet to the hose
    valve.oriented_box(Vector((-0.050, 0.618, 0)), Vector((1, 0.18, 0)), Vector((0, 0, 1)),
                       Vector((0.14, 0.008, 0.026)), bevel=0.003)                       # squeeze lever
    valve.oriented_box(Vector((-0.050, 0.585, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)),
                       Vector((0.13, 0.008, 0.026)), bevel=0.003)                       # carry handle
    kit.add_mesh(root, valve, chrome, uv_scale=4.0)

    # pressure gauge on the valve's front
    gauge = kit.WeaponPart(prefix + "_gauge", shift)
    gauge.cylinder(Vector((0, 0.578, -0.018)), Vector((0, 0, -1)), 0.016, 0.010, 20)
    kit.add_mesh(root, gauge, gauge_mat, uv_scale=30.0)

    # safety pin through the handles and its tag
    pin = kit.WeaponPart(prefix + "_pin", shift)
    pin.tube([Vector((-0.02, 0.600, -0.03)), Vector((-0.02, 0.600, 0.03))], 0.0022, 8)
    ring = [Vector((-0.02 + math.cos(a) * 0.014, 0.600 + math.sin(a) * 0.014, -0.044))
            for a in np.linspace(0, 2 * math.pi, 17)]
    pin.tube(ring, 0.0018, 6, caps=False)
    kit.add_mesh(root, pin, chrome, uv_scale=4.0)
    tag = kit.WeaponPart(prefix + "_tag", shift)
    tag.oriented_box(Vector((-0.02, 0.570, -0.052)), Vector((1, 0, 0)), Vector((0, 0, 1)),
                     Vector((0.022, 0.03, 0.0015)))
    kit.add_mesh(root, tag, tag_mat, uv_scale=4.0)

    # hose: from the outlet, round and down the side to a horn in a clip
    hose = kit.WeaponPart(prefix + "_hose", shift)
    pts = [Vector((0.045, 0.574, 0)), Vector((0.085, 0.565, 0.0)), Vector((0.105, 0.52, 0.02)),
           Vector((0.098, 0.44, 0.04)), Vector((0.090, 0.34, 0.05)), Vector((0.087, 0.25, 0.052))]
    hose.tube(pts, 0.009, 12, caps=True)
    kit.add_mesh(root, hose, black, uv_scale=4.0)
    horn = kit.WeaponPart(prefix + "_horn", shift)
    hp = [Vector((0.087, 0.25, 0.052)), Vector((0.087, 0.20, 0.052)), Vector((0.087, 0.10, 0.052))]
    kit.sweep(horn, hp, lambda t, th: 0.011 + 0.017 * t ** 1.5, sides=20, caps=False)
    clip = [Vector((math.cos(a) * (R + 0.004), 0.16, math.sin(a) * (R + 0.004)))
            for a in np.linspace(0.2, 1.1, 8)]
    horn.tube(clip, 0.003, 6, caps=True)
    kit.add_mesh(root, horn, black, uv_scale=4.0, project=True)

    kit.marker(root, "grip_r", shift(GRIP), Vector((0, 0, 1)), Vector((0, 1, 0)))
    kit.marker(root, "grip_l", shift(Vector((0.087, 0.20, 0.052))), Vector((0, -1, 0)), Vector((1, 0, 0)))
    kit.marker(root, "muzzle", shift(Vector((0.087, 0.10, 0.052))), Vector((1, 0, 0)), Vector((0, -1, 0)))
    kit.marker(root, "strike", shift(Vector((0, 0.0, 0))), Vector((0, 0, 1)), Vector((0, -1, 0)))


def cloud_texture(weapon_id: str) -> pathlib.Path:
    rng = np.random.RandomState(kit.seed_of(weapon_id + "_cloud"))
    n = 512
    puff = kit.fbm(rng, n, 4, 5)
    a = np.clip((puff - 0.30) * 2.2, 0, 1) * 0.85
    rgb = np.ones((n, n, 3), np.float32) * 0.83 + (puff[..., None] - 0.5) * 0.08
    path = kit.TEX_DIR / f"{weapon_id}_cloud_base.png"
    kit.save_rgba(np.concatenate([rgb, a[..., None]], -1), path)
    return path


def build_cloud(root, prefix, mat) -> None:
    """Overlapping lumpy puffs growing out along +Z: a plume shell."""
    rng = np.random.RandomState(kit.seed_of("fire_extinguisher_plume"))
    part = kit.WeaponPart(prefix + "_plume")
    z = 0.05
    for k in range(9):
        r = 0.04 + 0.06 * k
        c = Vector((rng.uniform(-0.05, 0.05) * k, rng.uniform(-0.03, 0.06) * k, z))
        rings, segs = 8, 14
        verts = []
        for i in range(rings + 1):
            phi = math.pi * i / rings
            row = []
            for j in range(segs):
                th = 2 * math.pi * j / segs
                lump = 1.0 + 0.18 * math.sin(3 * th + k) * math.sin(2 * phi + k * 0.7)
                p = Vector((math.sin(phi) * math.cos(th), math.cos(phi), math.sin(phi) * math.sin(th) * 1.3))
                row.append(part.vert(c + p * r * lump))
            verts.append(row)
        for i in range(rings):
            for j in range(segs):
                jj = (j + 1) % segs
                part.quad(verts[i][j], verts[i][jj], verts[i + 1][jj], verts[i + 1][j])
        z += r * 0.95
    kit.add_mesh(root, part, mat, uv_scale=1.2, auto_smooth_deg=180.0)


# --- the handgun --------------------------------------------------------------

HG_GRIP = Vector((0.0, 0.040, 0.032))
HG_MUZZLE = Vector((0.0, 0.118, -0.152))


def _skew_block(part, top_y, top_z, bot_y, bot_z, half_x_top, half_x_bot, bevel=0.003):
    """A grip-shaped block: front/back faces raked, as a pistol grip is."""
    corners = []
    for sx, sy, sz in ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1),
                       (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)):
        if sy < 0:
            corners.append(Vector((sx * half_x_bot, bot_y, bot_z[0] if sz < 0 else bot_z[1])))
        else:
            corners.append(Vector((sx * half_x_top, top_y, top_z[0] if sz < 0 else top_z[1])))
    faces = ((0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7))
    part._beveled(corners, faces, bevel, 1)


def build_handgun(root, prefix, steel, poly, black) -> None:
    def shift(p: Vector) -> Vector:
        return p - HG_GRIP

    slide = kit.WeaponPart(prefix + "_slide", shift)
    slide.box(Vector((0, 0.118, -0.055)), Vector((0.026, 0.032, 0.19)), bevel=0.003)
    for k in range(8):                                   # rear serrations
        slide.box(Vector((0, 0.116, 0.004 + k * 0.0045)), Vector((0.0276, 0.024, 0.0022)))
    slide.box(Vector((0, 0.1365, -0.140)), Vector((0.0045, 0.006, 0.008)), bevel=0.0008)     # front sight
    for sx in (-1, 1):                                                                    # rear sight
        slide.box(Vector((sx * 0.0055, 0.137, 0.030)), Vector((0.006, 0.007, 0.009)), bevel=0.0008)
    slide.tube([Vector((0, 0.115, -0.149)), Vector((0, 0.115, -0.1525))], 0.0068, 16)          # barrel crown
    kit.add_mesh(root, slide, steel, uv_scale=8.0)

    frame = kit.WeaponPart(prefix + "_frame", shift)
    frame.box(Vector((0, 0.093, -0.045)), Vector((0.024, 0.020, 0.160)), bevel=0.0025)
    for k in range(3):                                   # accessory rail
        frame.box(Vector((0, 0.081, -0.105 + k * 0.012)), Vector((0.020, 0.004, 0.006)), bevel=0.0006)
    _skew_block(frame, 0.088, (0.000, 0.046), -0.012, (0.022, 0.070), 0.0150, 0.0160, bevel=0.0065)
    frame.box(Vector((0, -0.016, 0.046)), Vector((0.030, 0.008, 0.052)), bevel=0.002)          # mag plate
    guard = [Vector((0, 0.084, -0.058)), Vector((0, 0.066, -0.060)), Vector((0, 0.056, -0.048)),
             Vector((0, 0.054, -0.020)), Vector((0, 0.060, -0.004)), Vector((0, 0.070, 0.004))]
    frame.tube(guard, 0.0036, 10)
    kit.add_mesh(root, frame, poly, uv_scale=8.0)

    small = kit.WeaponPart(prefix + "_parts", shift)
    small.tube([Vector((0, 0.083, -0.024)), Vector((0, 0.072, -0.028)), Vector((0, 0.064, -0.024))], 0.0028, 8)
    small.box(Vector((0.0105, 0.126, -0.035)), Vector((0.0062, 0.010, 0.040)))                 # ejection port
    small.tube([Vector((0, 0.115, -0.1527)), Vector((0, 0.115, -0.1530))], 0.0046, 12)         # bore
    for z, x in ((-0.141, 0), (0.030, -0.0055), (0.030, 0.0055)):                              # sight dots
        small.tube([Vector((x, 0.1385, z - 0.0045)), Vector((x, 0.1385, z - 0.0047))], 0.0012, 8)
    kit.add_mesh(root, small, black, uv_scale=8.0)
    up = Vector((0, 0.1, -0.023)).normalized()
    kit.marker(root, "grip_r", shift(HG_GRIP), up, Vector((1, 0, 0)))
    kit.marker(root, "grip_l", shift(HG_GRIP + Vector((-0.015, 0, 0))), up, Vector((-1, 0, 0)))
    kit.marker(root, "muzzle", shift(Vector((0, 0.115, -0.153))), Vector((0, 1, 0)), Vector((0, 0, -1)))
    kit.marker(root, "strike", shift(Vector((0, -0.016, 0.046))), up, Vector((0, -1, 0)))


def build_flash(root, prefix, mat) -> None:
    """Three planes crossed along the bore and a face-on star: the flash
    reads from every side. Along -Z here; the marker's +Z is the bore."""
    part = kit.WeaponPart(prefix + "_flash")
    ln, w = 0.22, 0.09
    for k in range(3):
        a = math.pi * k / 3
        side = Vector((math.cos(a), math.sin(a), 0)) * w
        v = [part.vert(p) for p in (side, -side, -side + Vector((0, 0, -ln)), side + Vector((0, 0, -ln)))]
        part.quad(*v, [(0, 0.5), (1, 0.5), (1, 1), (0, 1)])
    s = 0.07
    v = [part.vert(Vector(p)) for p in ((-s, -s, -0.01), (s, -s, -0.01), (s, s, -0.01), (-s, s, -0.01))]
    part.quad(*v, [(0, 0), (1, 0), (1, 1), (0, 1)])
    kit.add_mesh(root, part, mat, project=False, smooth=False)


# --- the rocket launcher ---------------------------------------------------------

RPG_GRIP = Vector((0.0, -0.10, -0.16))
TUBE_R = 0.034


def _along_z(z0, z1, n):
    return [Vector((0, 0, z0 + (z1 - z0) * k / n)) for k in range(n + 1)]


def warhead_profile(t: float) -> float:
    """PG-type round, t from the motor joint (0) to the nose (1)."""
    pts = [(0.0, 0.030), (0.12, 0.030), (0.16, 0.044), (0.24, 0.046), (0.50, 0.047), (0.62, 0.044),
           (0.86, 0.020), (0.92, 0.010), (0.97, 0.009), (1.0, 0.0)]
    return float(np.interp(t, [p[0] for p in pts], [p[1] for p in pts]))


def build_warhead(part, z_joint: float, length: float) -> None:
    kit.sweep(part, _along_z(z_joint, z_joint - length, 48), lambda t, th: warhead_profile(t),
              sides=28, caps=True)


def build_rpg(root, prefix, steel, wood, olive, black, glass) -> None:
    def shift(p: Vector) -> Vector:
        return p - RPG_GRIP

    tube = kit.WeaponPart(prefix + "_tube", shift)
    kit.sweep(tube, _along_z(0.44, -0.50, 30), lambda t, th: TUBE_R, sides=28, caps=False)
    kit.sweep(tube, _along_z(-0.50, 0.44, 4), lambda t, th: TUBE_R - 0.004, sides=28, caps=False)
    tube.tube([Vector((math.cos(a) * (TUBE_R + 0.002), math.sin(a) * (TUBE_R + 0.002), -0.50))
               for a in np.linspace(0, 2 * math.pi, 29)], 0.004, 8, caps=False)             # muzzle lip
    # the venturi: a flared bell, outside and in
    kit.sweep(tube, _along_z(0.44, 0.66, 16), lambda t, th: TUBE_R + 0.030 * t ** 1.6, sides=28, caps=False)
    kit.sweep(tube, _along_z(0.66, 0.44, 16), lambda t, th: TUBE_R - 0.003 + 0.030 * (1 - t) ** 1.6,
              sides=28, caps=False)
    tube.tube([Vector((math.cos(a) * (TUBE_R + 0.0315), math.sin(a) * (TUBE_R + 0.0315), 0.66))
               for a in np.linspace(0, 2 * math.pi, 29)], 0.003, 8, caps=False)
    # bands round the heat shield, sling swivels, iron sights
    for z in (-0.13, 0.19):
        kit.sweep(tube, _along_z(z, z + 0.018, 1), lambda t, th: 0.0505, sides=28, caps=True)
    tube.box(Vector((0, 0.046, -0.45)), Vector((0.004, 0.024, 0.006)), bevel=0.001)          # front post
    tube.box(Vector((0, 0.046, -0.215)), Vector((0.016, 0.022, 0.006)), bevel=0.001)         # rear leaf
    for z in (-0.30, 0.30):
        tube.tube([Vector((0.0, -0.036, z - 0.012)), Vector((0.0, -0.048, z)), Vector((0.0, -0.036, z + 0.012))],
                  0.0025, 6)
    kit.add_mesh(root, tube, steel, uv_scale=4.0)

    shield = kit.WeaponPart(prefix + "_shield", shift)
    kit.sweep(shield, _along_z(0.19, -0.13, 12), lambda t, th: 0.048 + 0.0015 * math.cos(th * 2),
              sides=28, caps=True, v_scale=1.6)
    kit.add_mesh(root, shield, wood, project=False, auto_smooth_deg=180.0)

    grip = kit.WeaponPart(prefix + "_grip", shift)
    _skew_block(grip, -0.034, (-0.185, -0.145), -0.150, (-0.160, -0.118), 0.014, 0.015)
    grip.tube([Vector((0, -0.035, -0.225)), Vector((0, -0.062, -0.228)), Vector((0, -0.070, -0.205)),
               Vector((0, -0.064, -0.180)), Vector((0, -0.040, -0.180))], 0.0035, 10)          # trigger guard
    grip.tube([Vector((0, -0.036, -0.200)), Vector((0, -0.052, -0.203)), Vector((0, -0.058, -0.196))], 0.003, 8)
    kit.add_mesh(root, grip, black, uv_scale=8.0)

    sight = kit.WeaponPart(prefix + "_sight", shift)
    sight.box(Vector((-0.058, 0.040, -0.07)), Vector((0.03, 0.05, 0.10)), bevel=0.004)
    sight.tube([Vector((-0.064, 0.058, -0.02)), Vector((-0.064, 0.058, 0.05))], 0.016, 20)
    sight.tube([Vector((-0.040, 0.010, -0.07)), Vector((-0.034, 0.010, -0.07))], 0.01, 12)    # mount
    kit.add_mesh(root, sight, black, uv_scale=8.0)
    lens = kit.WeaponPart(prefix + "_lens", shift)
    lens.tube([Vector((-0.064, 0.058, 0.0495)), Vector((-0.064, 0.058, 0.051))], 0.012, 20)
    kit.add_mesh(root, lens, glass, uv_scale=8.0)

    head = kit.WeaponPart(prefix + "_warhead", shift)
    build_warhead(head, -0.48, 0.44)
    kit.add_mesh(root, head, olive, uv_scale=6.0)

    kit.marker(root, "grip_r", shift(RPG_GRIP), Vector((0, 1, -0.3)), Vector((1, 0, 0)))
    kit.marker(root, "grip_l", shift(Vector((0, -0.05, 0.03))), Vector((0, 1, 0)), Vector((-1, 0, 0)))
    kit.marker(root, "shoulder", shift(Vector((0, 0.0, 0.10))), Vector((0, 1, 0)), Vector((0, 0, -1)))
    kit.marker(root, "muzzle", shift(Vector((0, 0, -0.93))), Vector((0, 1, 0)), Vector((0, 0, -1)))


def build_rocket(root, prefix, olive, steel) -> None:
    head = kit.WeaponPart(prefix + "_warhead")
    build_warhead(head, -0.10, 0.44)
    kit.add_mesh(root, head, olive, uv_scale=6.0)
    motor = kit.WeaponPart(prefix + "_motor")
    kit.sweep(motor, _along_z(0.30, -0.10, 12), lambda t, th: 0.021, sides=20, caps=True)
    for k in range(4):
        a = math.pi / 2 * k + math.pi / 4
        d = Vector((math.cos(a), math.sin(a), 0))
        motor.oriented_box(Vector((0, 0, 0.27)) + d * 0.048, d.cross(Vector((0, 0, 1))), d,
                           Vector((0.0016, 0.05, 0.055)))
    kit.add_mesh(root, motor, steel, uv_scale=6.0)
    kit.marker(root, "tail", Vector((0, 0, 0.30)), Vector((0, 1, 0)), Vector((0, 0, 1)))


def build_blast(root, prefix, fire, smoke) -> None:
    rng = np.random.RandomState(kit.seed_of("rpg_blast"))
    core = kit.WeaponPart(prefix + "_fire")
    for k in range(7):
        c = Vector((rng.uniform(-0.6, 0.6), 0.5 + rng.uniform(0, 0.9), rng.uniform(-0.6, 0.6)))
        kit.lumpy_ball(core, c, rng.uniform(0.45, 0.85), k, lump=0.22)
    kit.add_mesh(root, core, fire, uv_scale=0.8, auto_smooth_deg=180.0)
    cloud = kit.WeaponPart(prefix + "_smoke")
    for k in range(9):
        a = 2 * math.pi * k / 9
        c = Vector((math.cos(a) * 1.0, 1.1 + rng.uniform(0, 1.2), math.sin(a) * 1.0))
        kit.lumpy_ball(cloud, c, rng.uniform(0.7, 1.1), 20 + k, lump=0.25)
    kit.add_mesh(root, cloud, smoke, uv_scale=0.6, auto_smooth_deg=180.0)


def main() -> None:
    build_firearms()
    kit.reset()
    weapon_id = "fire_extinguisher"
    pb, po, pn = paint_textures(weapon_id, (0.55, 0.045, 0.035), 0.10)
    paint = kit.pbr_material(weapon_id + "_paint", pb, po, pn, 0.5)
    label = kit.pbr_material(weapon_id + "_label", label_texture(weapon_id), None, None, roughness=0.45)
    chrome = chrome_material(weapon_id + "_chrome")
    black = kit.flat_material(weapon_id + "_rubber", (0.03, 0.03, 0.03), 0.7)
    gauge = kit.flat_material(weapon_id + "_gauge", (0.80, 0.80, 0.76), 0.2)
    tag = kit.flat_material(weapon_id + "_tag", (0.75, 0.62, 0.05), 0.5)
    cloud = kit.pbr_material(weapon_id + "_cloud", cloud_texture(weapon_id), None, None, roughness=0.95, alpha=True)
    cloud.blend_method = "BLEND"
    report = []
    root = kit.state_root("FireExtinguisher_Clean")
    build_clean(root, root.name, paint, label, chrome, black, gauge, tag)
    report.append("fire_extinguisher %s: %d triangles" % (root.name, kit.triangles_under(root)))
    root = kit.state_root("FireExtinguisher_Cloud")
    build_cloud(root, root.name, cloud)
    report.append("fire_extinguisher %s: %d triangles" % (root.name, kit.triangles_under(root)))
    report.append("wrote " + str(kit.export(weapon_id).relative_to(kit.ROOT)))
    print("\n".join(report))


def build_firearms() -> None:
    report = []
    kit.reset()
    wid = "handgun"
    steel = kit.pbr_material(wid + "_slide", *kit.metal_textures(wid + "_slide", (0.07, 0.07, 0.075), 0.22, 0.32), 0.8)
    poly = kit.pbr_material(wid + "_frame", *kit.polymer_textures(wid + "_frame", (0.035, 0.035, 0.035)), 0.7)
    black = kit.flat_material(wid + "_black", (0.012, 0.012, 0.012), 0.5, 0.6)
    flash = kit.pbr_material(wid + "_flash", kit.glow_texture(wid, "flash"), None, None, roughness=1.0,
                             alpha=True, emission=6.0)
    flash.blend_method = "BLEND"
    root = kit.state_root("Handgun_Clean")
    build_handgun(root, root.name, steel, poly, black)
    report.append("handgun %s: %d triangles" % (root.name, kit.triangles_under(root)))
    root = kit.state_root("Handgun_Flash")
    build_flash(root, root.name, flash)
    report.append("wrote " + str(kit.export(wid).relative_to(kit.ROOT)))

    kit.reset()
    wid = "rpg"
    steel = kit.pbr_material(wid + "_steel", *kit.metal_textures(wid + "_steel", (0.10, 0.105, 0.09), 0.25, 0.45,
                                                                   rust=0.25), 0.8)
    wood = kit.pbr_material(wid + "_wood", *kit.wood_textures(wid, (0.50, 0.30, 0.15), (0.30, 0.15, 0.06), 60, 0.7,
                                                                along_rows=False), 0.6)
    ob, oo, on = paint_textures(wid + "_warhead", (0.22, 0.25, 0.12), 0.12)
    olive = kit.pbr_material(wid + "_warhead", ob, oo, on, 0.6)
    black = kit.pbr_material(wid + "_black", *kit.polymer_textures(wid + "_black", (0.03, 0.03, 0.028)), 0.6)
    glass = kit.flat_material(wid + "_lens", (0.05, 0.08, 0.10), 0.05, 0.0)
    fire = kit.pbr_material(wid + "_fire", kit.glow_texture(wid, "fire"), None, None, roughness=1.0,
                            alpha=True, emission=8.0)
    fire.blend_method = "BLEND"
    smoke = kit.pbr_material(wid + "_smoke", kit.glow_texture(wid, "smoke"), None, None, roughness=1.0, alpha=True)
    smoke.blend_method = "BLEND"
    for name, fn in (("Rpg_Clean", lambda r: build_rpg(r, r.name, steel, wood, olive, black, glass)),
                     ("Rpg_Rocket", lambda r: build_rocket(r, r.name, olive, steel)),
                     ("Rpg_Blast", lambda r: build_blast(r, r.name, fire, smoke))):
        root = kit.state_root(name)
        fn(root)
        report.append("rpg %s: %d triangles" % (name, kit.triangles_under(root)))
    report.append("wrote " + str(kit.export(wid).relative_to(kit.ROOT)))
    print("\n".join(report))


if __name__ == "__main__":
    main()
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
    import bpy_exit  # noqa: E402 -- skip bpy's teardown segfault (see there)
    bpy_exit.finish(0)
