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


def main() -> None:
    report = []
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
