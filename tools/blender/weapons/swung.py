#!/usr/bin/env python3
"""Family 2, swung weapons (gauntlet/refs/weapons_nhb.md) -- this pass: the
baseball bat, the barbed-wire bat and the inflatable banana.

Run:  python3 tools/blender/weapons/swung.py

  game/assets/weapons/baseball_bat.glb       BaseballBat_Clean
  game/assets/weapons/barbed_wire_bat.glb    BarbedWireBat_Clean
  game/assets/weapons/inflatable_banana.glb  InflatableBanana_Clean,
                                             InflatableBanana_Broken (deflated)

Every one is held like a bat: origin at the right hand's grip, the weapon
running up +Y from it, grip_l below it toward the knob, strike at the
sweet spot.

The bat is a turned ash 34-inch (0.84 m), lacquered, with cloth grip tape on
the handle, ball marks and scuffs on the barrel and an original burnt-in
stamp. The barbed-wire bat is that bat with two-strand wire wound round the
barrel. The banana is a 1.15 m vinyl inflatable: five welded panels (the
ridges a banana has), glossy, brown at the ends, ripe spots printed on.
"""

from __future__ import annotations

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import weapon_kit as kit  # noqa: E402
from weapon_kit import Vector  # noqa: E402

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

BAT_LEN = 0.84
GRIP_S = 0.12          # right hand, from the knob end
GRIP_L_S = 0.05        # left hand, below it
# (distance from the knob end, radius): a 34" wood bat, 2.6" barrel
BAT_PROFILE = [(0.0, 0.010), (0.003, 0.021), (0.008, 0.0275), (0.014, 0.0285), (0.020, 0.025),
               (0.028, 0.0160), (0.036, 0.0136), (0.26, 0.0140), (0.36, 0.0165), (0.44, 0.0215),
               (0.52, 0.0270), (0.60, 0.0315), (0.70, 0.0332), (0.80, 0.0330), (0.825, 0.0315),
               (0.836, 0.0270), (0.840, 0.0150), (0.8405, 0.0)]
TAPE_FROM, TAPE_TO = 0.030, 0.30


def bat_radius(s: float) -> float:
    xs = [p[0] for p in BAT_PROFILE]
    ys = [p[1] for p in BAT_PROFILE]
    return float(np.interp(s, xs, ys))


def bat_path(steps: int = 90) -> list[Vector]:
    # denser at the knob and the end, where the profile turns
    ss = sorted(set([p[0] for p in BAT_PROFILE] + [BAT_LEN * k / steps for k in range(steps + 1)]))
    return [Vector((0.0, s - GRIP_S, 0.0)) for s in ss]


# --- textures ----------------------------------------------------------------

def wood_textures(weapon_id: str) -> tuple:
    """Lacquered ash: straight grain along the length (v), ball marks and
    scuffs on the barrel, the stamp. u is round the bat, v its length."""
    rng = np.random.RandomState(kit.seed_of(weapon_id + "_wood"))
    n = kit.TEX_SIZE
    warp = kit.fbm(rng, n, 4, 4)
    fine = kit.fbm(rng, n, 64, 3)
    u = np.linspace(0, 1, n, endpoint=False)[None, :].repeat(n, 0)
    grain = 0.5 + 0.5 * np.sin(2 * math.pi * (u * 38.0 + warp * 2.2))
    grain = grain ** 3
    ash = np.array([0.66, 0.50, 0.32])
    late = np.array([0.46, 0.31, 0.17])
    base = ash[None, None] * (1 - grain[..., None] * 0.55) + late[None, None] * grain[..., None] * 0.55
    base *= (0.92 + 0.16 * fine[..., None])
    # rows: v = arc / V_SCALE... image row 0 is v = 1 (top)
    v = 1.0 - (np.arange(n) + 0.5) / n
    s_of_row = v * BAT_SCALE_INV
    barrel = np.clip((s_of_row - 0.45) / 0.1, 0, 1)[:, None]
    marks = np.zeros((n, n), np.float32)
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    for _ in range(26):
        cx, cy = rng.uniform(0, n), rng.uniform(0.04, 0.35) * n
        rx, ry = rng.uniform(10, 28), rng.uniform(6, 16)
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=int(rng.uniform(40, 110)))
    marks = np.asarray(img.resize((n, n)), np.float32) / 255.0
    marks = np.asarray(Image.fromarray((marks * 255).astype(np.uint8)).resize((n // 8, n // 8), Image.BILINEAR)
                       .resize((n, n), Image.BICUBIC), np.float32) / 255.0
    scuff = kit.scratches(rng, n, 70, 0.08, 1, spread=0.5) * 0.5 * barrel
    base = base * (1 - marks[..., None] * 0.5) + np.array([0.80, 0.74, 0.62]) * scuff[..., None] * 0.6
    stamp = _stamp(n, "AEGIS", "PRO 34")
    base = base * (1 - stamp[..., None] * 0.72)
    rough = 0.32 + 0.10 * fine + 0.25 * scuff + 0.15 * marks
    orm = np.stack([np.ones_like(rough), np.clip(rough, 0, 1), np.zeros_like(rough)], -1)
    height = grain * 0.2 - marks * 0.6 - scuff * 0.3
    nrm = kit.normal_from_height(height, 3.0)
    d_ = kit.TEX_DIR
    kit.save_rgb(np.clip(base, 0, 0.85), d_ / f"{weapon_id}_wood_base.png")
    kit.save_rgb(orm, d_ / f"{weapon_id}_wood_orm.png")
    kit.save_rgb(nrm, d_ / f"{weapon_id}_wood_normal.png")
    return (d_ / f"{weapon_id}_wood_base.png", d_ / f"{weapon_id}_wood_orm.png",
            d_ / f"{weapon_id}_wood_normal.png")


# the bat's UV v is arc length * V_SCALE; this is its inverse, to place marks
V_SCALE = 1.0 / 0.9
BAT_SCALE_INV = 0.9


def _stamp(n: int, line1: str, line2: str) -> np.ndarray:
    """An oval burn-stamp on the barrel, text running along the bat."""
    w, h = 300, 120
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    d.ellipse([4, 4, w - 4, h - 4], outline=255, width=5)
    f1, f2 = kit.font(52), kit.font(24)
    for text, f, y in ((line1, f1, 14), (line2, f2, 74)):
        box = d.textbbox((0, 0), text, font=f)
        d.text(((w - (box[2] - box[0])) // 2 - box[0], y), text, font=f, fill=255)
    img = img.rotate(90, expand=True)          # along the length
    out = Image.new("L", (n, n), 0)
    s = 0.58                                   # centre of the stamp, from the knob
    row = int((1.0 - s * V_SCALE) * n) - img.height // 2
    out.paste(img, (int(0.22 * n) - img.width // 2, row))
    return np.asarray(out, np.float32) / 255.0 * 0.9


def tape_textures(weapon_id: str) -> tuple:
    rng = np.random.RandomState(kit.seed_of(weapon_id + "_tape"))
    n = 512
    yy, xx = np.mgrid[0:n, 0:n] / n
    # spiral wraps: one turn per 30 mm, so along v (metres*V_SCALE) ...
    wraps = (xx + yy / (0.03 * V_SCALE)) % 1.0
    edge = np.clip(1.0 - np.abs(wraps - 0.5) * 2.0, 0, 1) ** 8
    weave = kit.fbm(rng, n, 96, 2)
    dirt = kit.fbm(rng, n, 6, 3)
    base = np.full((n, n, 3), 0.035) + weave[..., None] * 0.025 + (dirt[..., None] - 0.5) * 0.02
    base = base + edge[..., None] * 0.05
    rough = 0.82 + 0.1 * weave
    orm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], -1)
    nrm = kit.normal_from_height(-edge * 0.8 + weave * 0.3, 4.0)
    d = kit.TEX_DIR
    kit.save_rgb(base, d / f"{weapon_id}_tape_base.png")
    kit.save_rgb(orm, d / f"{weapon_id}_tape_orm.png")
    kit.save_rgb(nrm, d / f"{weapon_id}_tape_normal.png")
    return d / f"{weapon_id}_tape_base.png", d / f"{weapon_id}_tape_orm.png", d / f"{weapon_id}_tape_normal.png"


def vinyl_textures(weapon_id: str) -> tuple:
    rng = np.random.RandomState(kit.seed_of(weapon_id + "_vinyl"))
    n = kit.TEX_SIZE
    v = 1.0 - (np.arange(n) + 0.5) / n
    t = (v / BANANA_V)[:, None].repeat(n, 1)     # 0..1 along the banana
    u = np.linspace(0, 1, n, endpoint=False)[None, :].repeat(n, 0)
    yellow = np.array([0.84, 0.68, 0.06])
    green = np.array([0.45, 0.55, 0.10])
    brown = np.array([0.22, 0.13, 0.04])
    tip = np.clip(1.0 - np.minimum(t, 1 - t) / 0.07, 0, 1)
    greenish = np.clip(1.0 - t / 0.2, 0, 1) * 0.35
    base = yellow[None, None] * (1 - greenish[..., None]) + green[None, None] * greenish[..., None]
    base = base * (1 - tip[..., None]) + brown[None, None] * tip[..., None]
    # printed ripe spots
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    for _ in range(45):
        cx, cy = rng.uniform(0, n), rng.uniform(0.12, 0.88) * BANANA_V * n
        r = rng.uniform(5, 15)
        d.ellipse([cx - r * 0.6, n - cy - r, cx + r * 0.6, n - cy + r], fill=int(rng.uniform(120, 255)))
    from PIL import ImageFilter
    img = img.filter(ImageFilter.GaussianBlur(4))
    # soft, blotchy, printed a shade of brown -- not holes
    spots = np.asarray(img, np.float32) / 255.0 * 0.55 * (0.6 + 0.4 * kit.fbm(rng, n, 32, 2))
    base = base * (1 - spots[..., None]) + brown[None, None] * spots[..., None]
    # welded seams down the five ridges
    seam = np.zeros((n, n), np.float32)
    for k in range(5):
        seam = np.maximum(seam, np.clip(1 - np.abs(((u - k / 5 + 0.5) % 1.0) - 0.5) * n / 3.0, 0, 1))
    base = base * (1 - seam[..., None] * 0.18)
    crease = kit.fbm(rng, n, 24, 3)
    rough = 0.22 + 0.10 * crease + seam * 0.2
    orm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough)], -1)
    nrm = kit.normal_from_height(seam * 1.0 + crease * 0.15, 4.0)
    dd = kit.TEX_DIR
    kit.save_rgb(np.clip(base, 0, 0.85), dd / f"{weapon_id}_vinyl_base.png")
    kit.save_rgb(orm, dd / f"{weapon_id}_vinyl_orm.png")
    kit.save_rgb(nrm, dd / f"{weapon_id}_vinyl_normal.png")
    return (dd / f"{weapon_id}_vinyl_base.png", dd / f"{weapon_id}_vinyl_orm.png",
            dd / f"{weapon_id}_vinyl_normal.png")


# --- the bat -----------------------------------------------------------------

def build_bat(root, prefix: str, wood, tape) -> None:
    body = kit.WeaponPart(prefix + "_wood")
    kit.sweep(body, bat_path(), lambda t, th: bat_radius(t * BAT_PROFILE[-1][0]), sides=28,
              caps=True, v_scale=V_SCALE)
    kit.add_mesh(root, body, wood, project=False, auto_smooth_deg=180.0)
    grip = kit.WeaponPart(prefix + "_tape")
    tape_path = [Vector((0, s - GRIP_S, 0)) for s in np.linspace(TAPE_FROM, TAPE_TO, 30)]
    kit.sweep(grip, tape_path,
              lambda t, th: bat_radius(TAPE_FROM + t * (TAPE_TO - TAPE_FROM)) + 0.0011
              + 0.0003 * math.sin(th * 3 + t * 60), sides=24, caps=False, v_scale=V_SCALE)
    kit.add_mesh(root, grip, tape, project=False, auto_smooth_deg=180.0)
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((0, GRIP_L_S - GRIP_S, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0, 0.70 - GRIP_S, 0)), Vector((0, 1, 0)), Vector((0, 0, -1)))


def bat_wire(root, prefix: str, wire, rng) -> None:
    part = kit.WeaponPart(prefix + "_wire")
    pts = []
    s0, s1, turns = 0.40, 0.81, 6.5
    for k in range(int(turns * 32) + 1):
        f = k / (turns * 32)
        s = s0 + (s1 - s0) * f
        ang = 2 * math.pi * turns * f
        r = bat_radius(s) + 0.0032
        pts.append(Vector((math.cos(ang) * r, s - GRIP_S, math.sin(ang) * r)))
    # loose ends: one sprung off the top, one trailing down the handle side
    top = pts[-1]
    pts += [top + Vector((0.01, 0.015, 0.008)), top + Vector((0.03, 0.03, 0.02)), top + Vector((0.045, 0.05, 0.02))]
    start = pts[0]
    lead = [start + Vector((0.035, -0.06, 0.01)), start + Vector((0.02, -0.03, 0.006))]
    kit.barbed_wire(part, lead + pts, rng, barb_every=0.085)
    kit.add_mesh(root, part, wire, smooth=True, uv_scale=4.0, auto_smooth_deg=180.0)


# --- the banana --------------------------------------------------------------

BANANA_LEN = 1.15
BANANA_GRIP_T = 0.09
BANANA_V = 1.0 / 1.25          # the vinyl texture's v per metre of banana


def banana_path(droop: float = 0.0, steps: int = 64) -> list[Vector]:
    """An arc in the YZ plane, curving toward -Z (the front); the grip at the
    origin, BANANA_GRIP_T of the way up."""
    radius = 1.35 * (1.0 + droop * 2.0)
    span = BANANA_LEN / radius
    pts = []
    for k in range(steps + 1):
        a = span * (k / steps - BANANA_GRIP_T)
        pts.append(Vector((0.0, math.sin(a) * radius, -(1 - math.cos(a)) * radius)))
    return pts


def banana_radius(t: float, theta: float) -> float:
    body = 0.085 * min(1.0, math.sin(math.pi * min(t / 0.30, 1.0) * 0.5) ** 0.6) \
        * min(1.0, math.sin(math.pi * min((1 - t) / 0.22, 1.0) * 0.5) ** 0.7)
    stem = 0.016 if t < 0.06 else 0.0
    r = max(body, stem, 0.008)
    return r * (1.0 + 0.055 * math.cos(5 * theta))


def deflated_radius(t: float, theta: float) -> float:
    r = banana_radius(t, theta)
    a, b = 1.45, 0.20                    # flattened to a sheet, wider than it was round
    flat = r / math.sqrt((math.cos(theta) / a) ** 2 + (math.sin(theta) / b) ** 2)
    wrinkle = 1.0 + 0.10 * math.sin(t * 41.0 + theta * 3.0) * math.sin(t * 17.0 - theta)
    return flat * wrinkle


def build_banana(root, prefix: str, vinyl, deflated: bool) -> None:
    part = kit.WeaponPart(prefix + "_vinyl")
    path = banana_path(0.6 if deflated else 0.0)
    if deflated:
        # lying slack: the whole thing sags flat on the floor side
        path = [Vector((p.x, p.y * 0.98, p.z * 0.4 - 0.02 * math.sin(i * 0.3))) for i, p in enumerate(path)]
    kit.sweep(part, path, deflated_radius if deflated else banana_radius, sides=40, caps=True,
              v_scale=BANANA_V)
    kit.add_mesh(root, part, vinyl, project=False, auto_smooth_deg=180.0)
    a = path[int(len(path) * 0.7)]
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", path[1], Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", a, Vector((0, 1, 0)), Vector((0, 0, -1)))


# --- batch A: sledgehammer, lead pipe, 2x4 with nails, shovel -------------------

def _y(y0, y1, n):
    return [Vector((0, y0 + (y1 - y0) * k / n, 0)) for k in range(n + 1)]


def oval(rx, rz):
    """A handle's oval section: radius at theta for an rx-by-rz ellipse."""
    return lambda t, th: 1.0 / math.sqrt((math.cos(th) / rx) ** 2 + (math.sin(th) / rz) ** 2)


def build_sledgehammer(root, prefix, wood, steel) -> None:
    # hickory handle, 0.90 m, oval, swelling to the knob; head at the top
    h = kit.WeaponPart(prefix + "_handle")
    prof = lambda t: 1.0 + 0.25 * max(0.0, 1 - t / 0.06) + 0.12 * max(0.0, (t - 0.85) / 0.15)
    kit.sweep(h, _y(-0.10, 0.80, 40), lambda t, th: oval(0.0165, 0.012)(t, th) * prof(t),
              sides=20, caps=True, v_scale=1.1)
    kit.add_mesh(root, h, wood, project=False, auto_smooth_deg=180.0)
    head = kit.WeaponPart(prefix + "_head")
    head.box(Vector((0, 0.80, 0)), Vector((0.21, 0.065, 0.065)), bevel=0.008, bevel_segments=2)
    for sx in (-1, 1):                                    # striking faces, a touch proud and domed
        head.cylinder(Vector((sx * 0.105, 0.80, 0)), Vector((sx, 0, 0)), 0.030, 0.008, 24)
    head.box(Vector((0, 0.833, 0)), Vector((0.03, 0.004, 0.028)))           # wedge in the eye
    kit.add_mesh(root, head, steel, uv_scale=6.0)
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((0, -0.07, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0.113, 0.80, 0)), Vector((0, 1, 0)), Vector((1, 0, 0)))


def build_lead_pipe(root, prefix, steel, tape) -> None:
    pipe = kit.WeaponPart(prefix + "_pipe")
    r = 0.0168                                            # 1-inch schedule-40 steel pipe
    kit.sweep(pipe, _y(-0.08, 0.52, 30), lambda t, th: r, sides=24, caps=False, v_scale=1.0)
    kit.sweep(pipe, _y(0.52, -0.08, 4), lambda t, th: r - 0.0034, sides=24, caps=False)
    for y in (-0.08, 0.52):                               # the cut ends, a wall thick
        ring = [pipe.vert(Vector((math.cos(a) * rr, y, math.sin(a) * rr)))
                for rr in (r, r - 0.0034) for a in np.linspace(0, 2 * math.pi, 24, endpoint=False)]
        for k in range(24):
            j = (k + 1) % 24
            pipe.quad(ring[k], ring[j], ring[24 + j], ring[24 + k])
    # a threaded coupling screwed on the far end, threads showing below it
    kit.sweep(pipe, _y(0.47, 0.53, 6), lambda t, th: 0.0215 + 0.0006 * math.cos(th * 6), sides=24, caps=True)
    kit.sweep(pipe, _y(0.44, 0.47, 12), lambda t, th: r + 0.0007 * math.sin(t * 2 * math.pi * 8), sides=24,
              caps=False)
    kit.add_mesh(root, pipe, steel, project=False, auto_smooth_deg=60.0)
    grip = kit.WeaponPart(prefix + "_tape")
    kit.sweep(grip, _y(-0.075, 0.13, 20), lambda t, th: r + 0.0012 + 0.0003 * math.sin(th * 3 + t * 40),
              sides=24, caps=False, v_scale=V_SCALE)
    kit.add_mesh(root, grip, tape, project=False, auto_smooth_deg=180.0)
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((0, -0.06, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0, 0.42, 0)), Vector((0, 1, 0)), Vector((0, 0, -1)))


def _nail(part, base: Vector, d: Vector, length: float) -> None:
    tip = base + d * length
    part.tube([base - d * 0.002, tip - d * 0.008], 0.0021, 6, caps=True)
    kit.sweep(part, [tip - d * 0.008, tip], lambda t, th: 0.0021 * (1 - t), sides=6, caps=False)
    part.tube([base - d * 0.0035, base - d * 0.002], 0.0052, 10, caps=True)  # the head


def build_board(root, prefix, wood, nail_steel, rng, broken: bool) -> None:
    """A 2x4 (38 x 89 mm) 0.95 m long, nails driven through the far end and
    out the other side at angles. Broken: snapped across, a long splinter."""
    W, D, L0, L1 = 0.089, 0.038, -0.12, 0.83

    def board(name, y0, y1, ragged_top=None, ragged_bottom=None):
        part = kit.WeaponPart(name)
        if ragged_top is None and ragged_bottom is None:
            part.box(Vector((0, (y0 + y1) / 2, 0)), Vector((D, y1 - y0, W)), bevel=0.003)
        else:
            # a box whose one end is a jagged break
            nx, nz = 4, 7
            def end_y(i, j, ragged, base):
                return base + (ragged[i][j] if ragged is not None else 0.0)
            for ry, yb, sign in ((ragged_top, y1, 1), (ragged_bottom, y0, -1)):
                pass
            from mathutils import Vector as V
            xs = np.linspace(-D / 2, D / 2, nx + 1)
            zs = np.linspace(-W / 2, W / 2, nz + 1)
            top = [[part.vert(V((x, end_y(i, j, ragged_top, y1), z))) for j, z in enumerate(zs)]
                   for i, x in enumerate(xs)]
            bot = [[part.vert(V((x, end_y(i, j, ragged_bottom, y0), z))) for j, z in enumerate(zs)]
                   for i, x in enumerate(xs)]
            for i in range(nx):
                for j in range(nz):
                    part.quad(top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1])
                    part.quad(bot[i][j], bot[i][j + 1], bot[i + 1][j + 1], bot[i + 1][j])
            ring_t = [top[i][0] for i in range(nx + 1)] + [top[nx][j] for j in range(1, nz + 1)] + \
                [top[i][nz] for i in range(nx - 1, -1, -1)] + [top[0][j] for j in range(nz - 1, 0, -1)]
            ring_b = [bot[i][0] for i in range(nx + 1)] + [bot[nx][j] for j in range(1, nz + 1)] + \
                [bot[i][nz] for i in range(nx - 1, -1, -1)] + [bot[0][j] for j in range(nz - 1, 0, -1)]
            for k in range(len(ring_t)):
                m = (k + 1) % len(ring_t)
                part.quad(ring_b[k], ring_b[m], ring_t[m], ring_t[k])
        return part

    nails = kit.WeaponPart(prefix + "_nails")
    nail_rng = np.random.RandomState(kit.seed_of("board_nails"))
    for k in range(9):
        y = 0.55 + 0.03 * k + nail_rng.uniform(-0.01, 0.01)
        z = nail_rng.uniform(-0.03, 0.03)
        d = Vector((1.0, nail_rng.uniform(-0.25, 0.25), nail_rng.uniform(-0.3, 0.3))).normalized()
        if k % 3 == 2:
            d = Vector((d.x, d.y, -d.z * 2)).normalized()
        _nail(nails, Vector((D / 2, y, z)), -d, 0.11 + nail_rng.uniform(0, 0.03))
    if not broken:
        part = board(prefix + "_board", L0, L1)
        kit.add_mesh(root, part, wood, uv_scale=1.6)
        kit.add_mesh(root, nails, nail_steel, uv_scale=8.0)
    else:
        rag_rng = np.random.RandomState(kit.seed_of("board_break"))
        brk = 0.36
        rag = [[rag_rng.uniform(-0.035, 0.035) + (0.05 if (i + j) % 5 == 0 else 0.0) for j in range(8)]
               for i in range(5)]
        low = board(prefix + "__piece_00", L0, brk, ragged_top=rag)
        high = board(prefix + "__piece_01", brk, L1, ragged_bottom=[[v - 0.004 for v in row] for row in rag])
        o = kit.add_mesh(root, low, wood, uv_scale=1.6)
        o["piece"] = True
        o = kit.add_mesh(root, high, wood, uv_scale=1.6)
        o["piece"] = True
        o.rotation_euler = (0.0, 0.0, math.radians(4))
        o = kit.add_mesh(root, nails, nail_steel, uv_scale=8.0)
        o.rotation_euler = (0.0, 0.0, math.radians(4))
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((0, -0.08, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((-D / 2 - 0.05, 0.65, 0)), Vector((0, 1, 0)), Vector((-1, 0, 0)))


def build_shovel(root, prefix, wood, steel, black) -> None:
    """A round-point digging shovel: ash handle with a D-grip, a pressed
    steel blade with a rolled step and socket. Handle along +Y, blade at the
    top, its face toward -Z."""
    h = kit.WeaponPart(prefix + "_handle")
    kit.sweep(h, _y(-0.10, 0.80, 30), lambda t, th: 0.0175, sides=20, caps=True, v_scale=1.1)
    kit.add_mesh(root, h, wood, project=False, auto_smooth_deg=180.0)
    m = kit.WeaponPart(prefix + "_metal")
    # D-grip: a steel yoke and a wooden cross bar at the bottom
    for s in (-1, 1):
        m.tube([Vector((0, -0.08, 0)), Vector((s * 0.03, -0.15, 0)), Vector((s * 0.055, -0.22, 0))], 0.0065, 10)
    # socket up to the blade
    kit.sweep(m, _y(0.70, 0.86, 10), lambda t, th: 0.0185 + 0.006 * t, sides=20, caps=False)
    # blade: a dished sheet, round point, with rolled top edges (the step)
    bw, bl = 0.24, 0.30

    def blade_point(s, t):
        half = bw / 2 * (1 - max(0.0, (t - 0.55) / 0.45) ** 1.8)
        x = (s - 0.5) * 2 * half
        y = 0.86 + t * bl
        z = -0.02 * (1 - ((s - 0.5) * 2) ** 2) + 0.03 * t
        return Vector((x, y, z))
    nu, nv = 14, 16
    rows_f, rows_b = [], []
    for j in range(nv + 1):
        rf, rb = [], []
        for i in range(nu + 1):
            p = blade_point(i / nu, j / nv)
            rf.append(m.vert(p + Vector((0, 0, -0.001))))
            rb.append(m.vert(p + Vector((0, 0, 0.001))))
        rows_f.append(rf)
        rows_b.append(rb)
    for j in range(nv):
        for i in range(nu):
            m.quad(rows_f[j][i], rows_f[j][i + 1], rows_f[j + 1][i + 1], rows_f[j + 1][i])
            m.quad(rows_b[j][i], rows_b[j + 1][i], rows_b[j + 1][i + 1], rows_b[j][i + 1])
    m.tube([blade_point(0, 0), blade_point(0.5, 0) + Vector((0, 0, 0.004)), blade_point(1, 0)], 0.006, 8)
    kit.add_mesh(root, m, steel, uv_scale=4.0)
    bar = kit.WeaponPart(prefix + "_dgrip")
    bar.tube([Vector((-0.06, -0.22, 0)), Vector((0.06, -0.22, 0))], 0.014, 16)
    kit.add_mesh(root, bar, black, uv_scale=8.0)
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((0, -0.22, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", blade_point(0.5, 0.6), Vector((0, 1, 0)), Vector((0, 0, -1)))


def build_batch_a(report: list) -> None:
    kit.reset()
    wid = "sledgehammer"
    wood = kit.pbr_material(wid + "_wood", *kit.wood_textures(wid, (0.66, 0.50, 0.32), (0.44, 0.28, 0.14), 40, 0.5,
                                                               along_rows=False), 0.6)
    steel = kit.pbr_material(wid + "_head", *kit.metal_textures(wid, (0.05, 0.05, 0.05), 0.35, 0.42, rust=0.3), 0.8)
    root = kit.state_root("Sledgehammer_Clean")
    build_sledgehammer(root, root.name, wood, steel)
    report.append("sledgehammer: %d triangles" % kit.triangles_under(root))
    kit.export(wid)

    kit.reset()
    wid = "lead_pipe"
    steel = kit.pbr_material(wid + "_steel", *kit.metal_textures(wid, (0.40, 0.40, 0.38), 0.3, 0.58, rust=0.30), 0.8)
    tape = kit.pbr_material(wid + "_tape", *tape_textures(wid), 0.8)
    root = kit.state_root("LeadPipe_Clean")
    build_lead_pipe(root, root.name, steel, tape)
    report.append("lead_pipe: %d triangles" % kit.triangles_under(root))
    kit.export(wid)

    kit.reset()
    wid = "board_with_nails"
    wood = kit.pbr_material(wid + "_wood", *kit.wood_textures(wid, (0.72, 0.60, 0.42), (0.55, 0.42, 0.26), 50, 0.0,
                                                               along_rows=False), 0.8)
    nails = kit.pbr_material(wid + "_nails", *kit.metal_textures(wid + "_nails", (0.40, 0.40, 0.38), 0.2, 0.4,
                                                                  rust=0.45, size=256), 0.6)
    rng = np.random.RandomState(kit.seed_of(wid))
    for state, broken in (("Clean", False), ("Broken", True)):
        root = kit.state_root("BoardWithNails_" + state)
        build_board(root, root.name, wood, nails, rng, broken)
        report.append("board_with_nails %s: %d triangles" % (state, kit.triangles_under(root)))
    kit.export(wid)

    kit.reset()
    wid = "shovel"
    wood = kit.pbr_material(wid + "_wood", *kit.wood_textures(wid, (0.70, 0.55, 0.36), (0.50, 0.34, 0.18), 40, 0.4,
                                                               along_rows=False), 0.6)
    steel = kit.pbr_material(wid + "_steel", *kit.metal_textures(wid, (0.30, 0.31, 0.30), 0.45, 0.55, rust=0.3), 0.8)
    black = kit.pbr_material(wid + "_grip", *kit.polymer_textures(wid, (0.03, 0.03, 0.03)), 0.6)
    root = kit.state_root("Shovel_Clean")
    build_shovel(root, root.name, wood, steel, black)
    report.append("shovel: %d triangles" % kit.triangles_under(root))
    kit.export(wid)


# --- batch B: kendo stick, hockey stick, crutch, stop sign ------------------------

def section_sweep(part, path: list, up_of, section, sides: int = 20, caps: bool = True,
                  v_scale: float = 1.0) -> None:
    """Like kit.sweep but with an explicit frame: up_of(t, tangent) gives the
    section's 'up' (its second axis), section(t, theta) -> (a, b) the point
    in (side, up) at that angle. For flat things -- a blade, a slat -- whose
    section must not spin."""
    n = len(path)
    lengths = [0.0]
    for i in range(1, n):
        lengths.append(lengths[-1] + (path[i] - path[i - 1]).length)
    total = lengths[-1] or 1.0
    rings = []
    for i, p in enumerate(path):
        tan = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        t = lengths[i] / total
        up = up_of(t, tan)
        up = (up - tan * up.dot(tan)).normalized()
        side = tan.cross(up).normalized()
        ring = []
        for k in range(sides + 1):
            th = 2 * math.pi * k / sides
            a, b = section(t, th)
            ring.append(part.vert(p + side * a + up * b))
        rings.append(ring)
    for i in range(n - 1):
        v0, v1 = lengths[i] * v_scale, lengths[i + 1] * v_scale
        for k in range(sides):
            part.quad(rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k],
                      [(k / sides, v0), ((k + 1) / sides, v0), ((k + 1) / sides, v1), (k / sides, v1)])
    if caps:
        for ring, rev in ((rings[0], True), (rings[-1], False)):
            c = part.bm.verts.new(sum((v.co for v in ring[:-1]), Vector()) / sides)
            for k in range(sides):
                try:
                    part.bm.faces.new((c, ring[k + 1], ring[k]) if rev else (c, ring[k], ring[k + 1]))
                except ValueError:
                    pass


def rounded_rect_section(w, h, r):
    """(a, b) round a w x h rectangle with corner radius r, by angle."""
    def f(t, th):
        c, s_ = math.cos(th), math.sin(th)
        # superellipse with exponent from the corner rounding
        e = 2.0 + 8.0 * (1 - min(r / min(w, h) * 2, 1.0))
        a = math.copysign(abs(c) ** (2 / e), c) * w / 2
        b = math.copysign(abs(s_) ** (2 / e), s_) * h / 2
        return a, b
    return f


def bamboo_textures(wid: str) -> tuple:
    rng = np.random.RandomState(kit.seed_of(wid + "_bamboo"))
    n = kit.TEX_SIZE
    u = np.linspace(0, 1, n, endpoint=False)[None, :].repeat(n, 0)
    v = 1.0 - (np.arange(n) + 0.5)[:, None].repeat(n, 1) / n
    fibre = 0.5 + 0.5 * np.sin(2 * math.pi * (u * 90 + kit.fbm(rng, n, 6, 3) * 0.8))
    base = np.array([0.80, 0.66, 0.38])[None, None] * (0.9 + 0.12 * fibre[..., None])
    # nodes: a darker raised ring every ~0.26 m (v is metres * 0.9)
    node = np.zeros((n, n), np.float32)
    for vn in (0.12, 0.36, 0.60, 0.84):
        node = np.maximum(node, np.exp(-((v - vn) / 0.006) ** 2))
    base = base * (1 - node[..., None] * 0.45)
    scorch = np.clip((kit.fbm(rng, n, 5, 4) - 0.55) * 3.0, 0, 1)
    base = base * (1 - scorch[..., None] * 0.25)
    scuff = kit.scratches(rng, n, 80, 0.06, 1, spread=0.4) * 0.4
    base = base * (1 - scuff[..., None] * 0.3)
    r = 0.42 + 0.1 * fibre + 0.2 * scuff
    orm = np.stack([np.ones_like(r), r, np.zeros_like(r)], -1)
    nrm = kit.normal_from_height(fibre * 0.15 + node * 0.8 - scuff * 0.3, 3.0)
    d = kit.TEX_DIR
    kit.save_rgb(np.clip(base, 0, 0.85), d / f"{wid}_bamboo_base.png")
    kit.save_rgb(orm, d / f"{wid}_bamboo_orm.png")
    kit.save_rgb(nrm, d / f"{wid}_bamboo_normal.png")
    return d / f"{wid}_bamboo_base.png", d / f"{wid}_bamboo_orm.png", d / f"{wid}_bamboo_normal.png"


KS_BUTT = -0.22          # the butt, below the right hand
KS_TSUKA = 0.28          # the leather handle's length
KS_LEN = 1.10


def ks_radius(s: float, th: float) -> float:
    r = 0.0150 - 0.0030 * max(0.0, (s - KS_TSUKA) / (KS_LEN - KS_TSUKA))
    groove = 0.10 * math.exp(-(math.sin(2 * th) / 0.14) ** 2)
    return r * (1 - groove)


def build_kendo(root, prefix, bamboo, leather, string, broken: bool) -> None:
    y = lambda s_: KS_BUTT + s_
    split = 0.62
    body = kit.WeaponPart(prefix + "_bamboo")
    top = KS_LEN - 0.06 if not broken else split
    path = _y(y(KS_TSUKA - 0.01), y(top), 36)
    kit.sweep(body, path, lambda t, th: ks_radius(KS_TSUKA + t * (top - KS_TSUKA), th),
              sides=24, caps=True, v_scale=0.9)
    kit.add_mesh(root, body, bamboo, project=False, auto_smooth_deg=180.0)
    hand = kit.WeaponPart(prefix + "_leather")
    kit.sweep(hand, _y(y(0.0), y(KS_TSUKA), 10), lambda t, th: 0.0165 + 0.0006 * math.cos(th * 2),
              sides=24, caps=True)
    if not broken:
        kit.sweep(hand, _y(y(KS_LEN - 0.065), y(KS_LEN), 8),
                  lambda t, th: 0.0138 * math.sqrt(max(1 - max(0.0, (t - 0.6) / 0.4) ** 2, 0.02)), sides=24,
                  caps=True)                                                   # sakigawa, the tip cap
        kit.sweep(hand, _y(y(0.80), y(0.825), 2), lambda t, th: 0.0143, sides=24, caps=True)   # nakayui
    kit.add_mesh(root, hand, leather, uv_scale=8.0)
    cord = kit.WeaponPart(prefix + "_string")
    cord_top = KS_LEN - 0.06 if not broken else split - 0.02
    cord.tube([Vector((0, y(KS_TSUKA), -0.0168)), Vector((0, y(cord_top), -0.0145))], 0.0012, 6)
    kit.add_mesh(root, cord, string, uv_scale=8.0)
    if broken:
        # the four slats, split apart above the break and splayed
        for k in range(4):
            slat = kit.WeaponPart("%s__piece_%02d" % (prefix, k))
            a0 = math.pi / 2 * k + 0.08
            a1 = a0 + math.pi / 2 - 0.16

            def sect(t, th, a0=a0, a1=a1):
                # a quarter-round: the arc, then back along two flat faces
                ang = a0 + (a1 - a0) * (0.5 + 0.5 * math.cos(th))
                rr = 0.0135 if math.sin(th) >= 0 else 0.004
                return math.cos(ang) * rr, math.sin(ang) * rr
            pts = _y(y(split), y(KS_LEN - 0.04), 12)
            spread = Vector((math.cos(a0 + 0.7), 0, math.sin(a0 + 0.7)))
            pts = [p + spread * (0.08 * ((p.y - y(split)) / (KS_LEN - split)) ** 1.6) for p in pts]
            section_sweep(slat, pts, lambda t, tan: Vector((0, 0, 1)), sect, sides=10, caps=True, v_scale=0.9)
            o = kit.add_mesh(root, slat, bamboo, project=False, auto_smooth_deg=180.0)
            o["piece"] = True
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((0, y(0.03), 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0, y(0.85), 0)), Vector((0, 1, 0)), Vector((0, 0, -1)))


def build_hockey(root, prefix, shaft_mat, blade_mat, knob_mat) -> None:
    """Shaft up +Y from the butt; at the heel the blade turns forward and
    down at the lie angle (135 degrees to the shaft), curving left."""
    butt, heel = -0.18, 1.30
    shaft = kit.WeaponPart(prefix + "_shaft")
    section_sweep(shaft, _y(butt, heel, 24), lambda t, tan: Vector((0, 0, -1)),
                  rounded_rect_section(0.0215, 0.032, 0.006), sides=24, caps=True, v_scale=1.0)
    kit.add_mesh(root, shaft, shaft_mat, project=False, auto_smooth_deg=50.0)
    knob = kit.WeaponPart(prefix + "_knob")
    section_sweep(knob, _y(butt - 0.004, butt + 0.12, 8), lambda t, tan: Vector((0, 0, -1)),
                  lambda t, th: rounded_rect_section(0.0245 + 0.004 * max(0.0, 1 - t * 6),
                                                     0.0355 + 0.004 * max(0.0, 1 - t * 6), 0.007)(t, th),
                  sides=24, caps=True)
    kit.add_mesh(root, knob, knob_mat, uv_scale=10.0)
    blade = kit.WeaponPart(prefix + "_blade")
    d = Vector((0, -0.707, -0.707))
    pts = []
    for k in range(17):
        f = k / 16
        pts.append(Vector((0.03 * f ** 2, heel, 0)) + d * (0.31 * f) + Vector((0, 0.04 * f * (1 - f) * 0, 0)))
    def blade_sect(t, th):
        hgt = 0.075 * (1 - 0.15 * t) * (1.0 if t < 0.85 else math.sqrt(max(1 - ((t - 0.85) / 0.15) ** 2, 0.15)))
        thick = 0.011 - 0.004 * t
        return rounded_rect_section(thick, hgt, 0.003)(t, th)
    # the heel joins the shaft: start a little up inside it
    pts = [Vector((0, heel - 0.04, 0.0))] + pts
    section_sweep(blade, pts, lambda t, tan: Vector((0, 1, 0)).cross(Vector((1, 0, 0))).cross(tan) * -1
                  if False else Vector((0, 0.707, -0.707)), blade_sect, sides=24, caps=True)
    kit.add_mesh(root, blade, blade_mat, uv_scale=6.0)
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((0, butt + 0.04, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0, heel - 0.05, 0)) + d * 0.12, Vector((0, 1, 0)), Vector((1, 0, 0)))


def build_crutch(root, prefix, alu, pad, foam, tip) -> None:
    """Aluminium underarm crutch, swung by the leg: the origin is low on the
    leg where the right hand grabs it, the armpit pad is what lands."""
    alu_p = kit.WeaponPart(prefix + "_frame")
    leg_bot, fork, top = -0.14, 0.32, 1.10
    alu_p.tube([Vector((0, leg_bot, 0)), Vector((0, fork + 0.02, 0))], 0.0125, 16)
    for s in (-1, 1):
        rail = [Vector((0, fork, 0)), Vector((s * 0.03, fork + 0.08, 0)), Vector((s * 0.052, fork + 0.22, 0)),
                Vector((s * 0.058, 0.70, 0)), Vector((s * 0.062, top - 0.03, 0))]
        alu_p.tube(rail, 0.0105, 14)
        for yy in (0.47, 0.52, 0.57, 0.62):                         # adjustment holes
            alu_p.tube([Vector((s * 0.0545, yy, -0.011)), Vector((s * 0.0545, yy, -0.0095))], 0.0032, 8)
    for yy in (0.0, 0.05, 0.10, 0.15, 0.20):
        alu_p.tube([Vector((0, yy, -0.0128)), Vector((0, yy, -0.0115))], 0.0032, 8)
    alu_p.tube([Vector((-0.058, 0.70, 0)), Vector((0.058, 0.70, 0))], 0.0055, 10)   # wing nut bolt
    kit.add_mesh(root, alu_p, alu, uv_scale=6.0)
    pd = kit.WeaponPart(prefix + "_pad")
    pd.box(Vector((0, top + 0.008, 0)), Vector((0.165, 0.045, 0.06)), bevel=0.018, bevel_segments=3)
    kit.add_mesh(root, pd, pad, uv_scale=6.0)
    fm = kit.WeaponPart(prefix + "_grip")
    kit.sweep(fm, [Vector((-0.052, 0.66, 0)), Vector((0.052, 0.66, 0))], lambda t, th: 0.016, sides=18, caps=True)
    kit.add_mesh(root, fm, foam, uv_scale=6.0)
    tp = kit.WeaponPart(prefix + "_tip")
    kit.sweep(tp, _y(leg_bot - 0.045, leg_bot + 0.035, 6),
              lambda t, th: 0.020 - 0.004 * t + 0.0008 * math.cos(th * 12) * (1 if t < 0.15 else 0), sides=24,
              caps=True)
    kit.add_mesh(root, tp, tip, uv_scale=6.0)
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((0, -0.08, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0, top + 0.03, 0)), Vector((0, 1, 0)), Vector((0, 1, 0)))


def sign_face_texture(wid: str) -> pathlib.Path:
    from PIL import Image, ImageDraw
    n = 1024
    img = Image.new("RGB", (n, n), (150, 14, 18))
    d = ImageDraw.Draw(img)
    c = n / 2
    def octagon(r):
        return [(c + r * math.cos(math.radians(22.5 + 45 * k)), c + r * math.sin(math.radians(22.5 + 45 * k)))
                for k in range(8)]
    d.polygon(octagon(n * 0.5), fill=(232, 228, 220))
    d.polygon(octagon(n * 0.465), fill=(150, 14, 18))
    f = kit.font(300)
    box = d.textbbox((0, 0), "STOP", font=f)
    d.text((c - (box[2] - box[0]) / 2 - box[0], c - (box[3] - box[1]) / 2 - box[1]), "STOP", font=f,
           fill=(232, 228, 220))
    arr = np.asarray(img, np.float32) / 255.0
    rng = np.random.RandomState(kit.seed_of(wid + "_face"))
    fade = kit.fbm(rng, n, 6, 4)
    grime = np.clip((kit.fbm(rng, n, 9, 4) - 0.5) * 2, 0, 1)
    scr = kit.scratches(rng, n, 140, 0.15, 1)
    arr = arr * (0.85 + 0.2 * fade[..., None]) * (1 - grime[..., None] * 0.25)
    arr = arr * (1 - scr[..., None] * 0.35) + np.array([0.75, 0.75, 0.74]) * scr[..., None] * 0.35
    path = kit.TEX_DIR / f"{wid}_face_base.png"
    kit.save_rgb(np.clip(arr, 0, 0.85), path)
    return path


def build_stop_sign(root, prefix, face, alu, post_mat, bolt, dented: bool) -> None:
    """A stop sign on a sheared-off U-channel post, held by the post like a
    bat; the sign is what lands. The face toward -Z."""
    R_SIGN = 0.405                            # circumradius: 0.75 m across the flats
    centre = Vector((0, 0.95, -0.012))

    def dent(p: Vector) -> Vector:
        if not dented:
            return p
        q = Vector(p)
        rel = p - centre
        # folded back over a head along a line across it, and caved in
        # (both clear of the post, which runs up the middle behind it)
        q.z += 0.10 * max(0.0, rel.x - 0.06) ** 1.3 * 2.4
        q.z += 0.05 * math.exp(-((rel.x + 0.20) ** 2 + (rel.y + 0.08) ** 2) / 0.012)
        return q

    sheet = kit.WeaponPart(prefix + "_face", dent)
    rings = 10
    verts = [[sheet.vert(centre + Vector((0, 0, -0.001)))]]
    uvs = []
    for i in range(1, rings + 1):
        rr = R_SIGN * i / rings
        row = []
        for k in range(32):
            a = math.radians(22.5) + 2 * math.pi * k / 32
            # an octagon: radius pulled in between the corners
            seg = (a - math.radians(22.5)) % (math.pi / 4) - math.pi / 8
            r_oct = rr * math.cos(math.pi / 8) / math.cos(seg)
            row.append(sheet.vert(centre + Vector((math.cos(a) * r_oct, math.sin(a) * r_oct, -0.001))))
        verts.append(row)
    def uv_of(v):
        co = v.co
        return (0.5 + co.x / (2 * R_SIGN), 0.5 + co.z / (2 * R_SIGN) - (centre.y) / (2 * R_SIGN))
    for k in range(32):
        j = (k + 1) % 32
        f = sheet.bm.faces.new((verts[0][0], verts[1][k], verts[1][j]))
    for i in range(1, rings):
        for k in range(32):
            j = (k + 1) % 32
            sheet.quad(verts[i][k], verts[i + 1][k], verts[i + 1][j], verts[i][j])
    # planar UVs from the undented positions (the face art is fixed to it)
    mesh_face = kit.add_mesh(root, sheet, face, project=False, smooth=True, auto_smooth_deg=180.0)
    uvl = mesh_face.data.uv_layers.active or mesh_face.data.uv_layers.new(name="UVMap")
    for loop in mesh_face.data.loops:
        co = mesh_face.data.vertices[loop.vertex_index].co   # blender frame: (x, -z, y)
        # seen from the face side (-Z) +X is on the viewer's left: mirror u
        uvl.data[loop.index].uv = (0.5 - co.x / (2 * R_SIGN), 0.5 + (co.z - centre.y) / (2 * R_SIGN))
    back = kit.WeaponPart(prefix + "_back", dent)
    # the aluminium blank behind the face, on the same grid so a bend moves
    # both alike, its rim showing round the edge
    pts = []
    for k in range(9):
        a = math.radians(22.5) + math.pi / 4 * k
        pts.append(centre + Vector((math.cos(a) * R_SIGN, math.sin(a) * R_SIGN, 0.0)))
    back.tube(pts, 0.0018, 6, caps=False)
    bverts = [[back.vert(centre + Vector((0, 0, 0.001)))]]
    for i in range(1, rings + 1):
        rr = R_SIGN * i / rings
        row = []
        for k in range(32):
            a = math.radians(22.5) + 2 * math.pi * k / 32
            seg = (a - math.radians(22.5)) % (math.pi / 4) - math.pi / 8
            r_oct = rr * math.cos(math.pi / 8) / math.cos(seg)
            row.append(back.vert(centre + Vector((math.cos(a) * r_oct, math.sin(a) * r_oct, 0.001))))
        bverts.append(row)
    for k in range(32):
        j = (k + 1) % 32
        back.bm.faces.new((bverts[0][0], bverts[1][j], bverts[1][k]))
    for i in range(1, rings):
        for k in range(32):
            j = (k + 1) % 32
            back.quad(bverts[i][k], bverts[i][j], bverts[i + 1][j], bverts[i + 1][k])
    kit.add_mesh(root, back, alu, uv_scale=2.0, auto_smooth_deg=180.0)
    # the U-channel post: a flat-bottomed U section, holed, sheared at the foot
    post = kit.WeaponPart(prefix + "_post")
    def u_sect(t, th):
        c, s_ = math.cos(th), math.sin(th)
        return math.copysign(abs(c) ** 0.25, c) * 0.032, math.copysign(abs(s_) ** 0.25, s_) * 0.012
    # behind the sign, bolted through it
    section_sweep(post, [p + Vector((0, 0, 0.015)) for p in _y(-0.15, 1.20, 20)], lambda t, tan: Vector((0, 0, 1)),
                  u_sect, sides=16, caps=True)
    kit.add_mesh(root, post, post_mat, uv_scale=4.0)
    b = kit.WeaponPart(prefix + "_bolts")
    for yy in (0.75, 1.15):
        b.tube([Vector((0, yy, -0.015)), Vector((0, yy, 0.03))], 0.006, 10)
        b.tube([Vector((0, yy, -0.0155)), Vector((0, yy, -0.0128))], 0.011, 12)
    kit.add_mesh(root, b, bolt, uv_scale=8.0)
    kit.marker(root, "grip_r", Vector((0, 0, 0.0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((0, -0.10, 0.0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", centre, Vector((0, 1, 0)), Vector((0, 0, -1)))


def build_batch_b(report: list) -> None:
    kit.reset()
    wid = "kendo_stick"
    bamboo = kit.pbr_material(wid + "_bamboo", *bamboo_textures(wid), 0.6)
    leather = kit.pbr_material(wid + "_leather", *kit.polymer_textures(wid + "_leather", (0.70, 0.62, 0.48)), 0.5)
    string = kit.flat_material(wid + "_string", (0.08, 0.06, 0.05), 0.8)
    for state, broken in (("Clean", False), ("Broken", True)):
        root = kit.state_root("KendoStick_" + state)
        build_kendo(root, root.name, bamboo, leather, string, broken)
        report.append("kendo_stick %s: %d triangles" % (state, kit.triangles_under(root)))
    kit.export(wid)

    kit.reset()
    wid = "hockey_stick"
    sb, so, sn = paint_texture_shaft(wid)
    shaft = kit.pbr_material(wid + "_shaft", sb, so, sn, 0.5)
    blade = kit.pbr_material(wid + "_blade", *tape_textures(wid + "_blade"), 0.8)
    knob = kit.pbr_material(wid + "_knob", *tape_textures_white(wid + "_knob"), 0.8)
    root = kit.state_root("HockeyStick_Clean")
    build_hockey(root, root.name, shaft, blade, knob)
    report.append("hockey_stick: %d triangles" % kit.triangles_under(root))
    kit.export(wid)

    kit.reset()
    wid = "crutch"
    alu = kit.pbr_material(wid + "_alu", *kit.metal_textures(wid, (0.66, 0.66, 0.64), 0.1, 0.30), 0.6)
    pad = kit.pbr_material(wid + "_pad", *kit.polymer_textures(wid + "_pad", (0.16, 0.16, 0.17)), 0.6)
    foam = kit.pbr_material(wid + "_foam", *kit.polymer_textures(wid + "_foam", (0.05, 0.05, 0.05)), 0.8)
    tip = kit.pbr_material(wid + "_tip", *kit.polymer_textures(wid + "_tip", (0.08, 0.08, 0.08)), 0.6)
    root = kit.state_root("Crutch_Clean")
    build_crutch(root, root.name, alu, pad, foam, tip)
    report.append("crutch: %d triangles" % kit.triangles_under(root))
    kit.export(wid)

    kit.reset()
    wid = "stop_sign"
    face = kit.pbr_material(wid + "_face", sign_face_texture(wid), None, None, roughness=0.35)
    alu = kit.pbr_material(wid + "_back", *kit.metal_textures(wid, (0.62, 0.63, 0.62), 0.05, 0.42), 0.6)
    post = kit.pbr_material(wid + "_post", *kit.metal_textures(wid + "_post", (0.50, 0.51, 0.49), 0.1, 0.5,
                                                                rust=0.2), 0.6)
    bolt = kit.flat_material(wid + "_bolt", (0.55, 0.55, 0.53), 0.4, 1.0)
    for state, dented in (("Clean", False), ("Dented", True)):
        root = kit.state_root("StopSign_" + state)
        build_stop_sign(root, root.name, face, alu, post, bolt, dented)
        report.append("stop_sign %s: %d triangles" % (state, kit.triangles_under(root)))
    kit.export(wid)


def paint_texture_shaft(wid: str) -> tuple:
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
    from chairs import paint_textures
    return paint_textures(wid + "_shaft", (0.04, 0.045, 0.05), 0.06)


def tape_textures_white(wid: str) -> tuple:
    b, o, n_ = tape_textures(wid)
    from PIL import Image
    arr = np.asarray(Image.open(b), np.float32) / 255.0
    arr = 0.80 - (0.06 - arr) * 4.0       # the black cloth tape's weave, in white
    kit.save_rgb(np.clip(arr, 0, 0.85), b)
    return b, o, n_


def main() -> None:
    report = []
    build_batch_a(report)
    build_batch_b(report)
    # the bat and the barbed bat
    for weapon_id, root_name, barbed in (("baseball_bat", "BaseballBat_Clean", False),
                                         ("barbed_wire_bat", "BarbedWireBat_Clean", True)):
        kit.reset()
        wood = kit.pbr_material(weapon_id + "_wood", *wood_textures(weapon_id), 0.6)
        tape = kit.pbr_material(weapon_id + "_tape", *tape_textures(weapon_id), 0.8)
        root = kit.state_root(root_name)
        build_bat(root, root_name, wood, tape)
        if barbed:
            sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
            from chairs import wire_textures
            wb, wo = wire_textures(weapon_id)
            wire = kit.pbr_material(weapon_id + "_wire", wb, wo, None)
            bat_wire(root, root_name, wire, np.random.RandomState(kit.seed_of(weapon_id + "_barbs")))
        report.append("%s %s: %d triangles" % (weapon_id, root_name, kit.triangles_under(root)))
        report.append("wrote " + str(kit.export(weapon_id).relative_to(kit.ROOT)))
    # the banana
    kit.reset()
    weapon_id = "inflatable_banana"
    vinyl = kit.pbr_material(weapon_id + "_vinyl", *vinyl_textures(weapon_id), 0.5)
    for root_name, deflated in (("InflatableBanana_Clean", False), ("InflatableBanana_Broken", True)):
        root = kit.state_root(root_name)
        build_banana(root, root_name, vinyl, deflated)
        report.append("%s %s: %d triangles" % (weapon_id, root_name, kit.triangles_under(root)))
    report.append("wrote " + str(kit.export(weapon_id).relative_to(kit.ROOT)))
    print("\n".join(report))


if __name__ == "__main__":
    main()
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
    import bpy_exit  # noqa: E402 -- skip bpy's teardown segfault (see there)
    bpy_exit.finish(0)
