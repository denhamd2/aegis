#!/usr/bin/env python3
"""Roman Reigns's eyes and lashes, as textures (character_aaa_plan.md S1).

Measured off the supplied roman_reigns.glb:

* M_EYE is two eyeballs, each a front cap and an outer band on one sphere of
  radius 13.2 mm, skinned to J_Eye_L / J_Eye_R, with UVs laid as a FLAT
  FRONT PROJECTION: 1 UV unit = 31 mm (du/dx +-32.3, dv/dy -31.8; the right
  eye mirrored in u), the line of sight at UV (0.501, 0.455). It shipped
  untextured -- flat glossy white, with an iris faked by spheres stuck on
  the front -- and the outer band, seen nearly edge-on in the lid opening,
  mirrored the arena's cool light as two chrome strips above and below the
  eye ("the blue-grey smear").
* M_transB_eyelash is 156 lash cards, also untextured, so it drew as a solid
  black bar on the upper lid. Upper lashes use the top half of their UV
  square, roots at v 0.04 and tips toward v 0.48; lower lashes the bottom
  half, roots at v 0.96 and tips toward 0.48.

So this paints, at real sizes off that projection:

  roman_reigns_eye_color.png   sclera, iris, pupil -- dark brown, as his are
                               in the owner's photos
  roman_reigns_eye_orm.png     R occlusion, G roughness: the band where the
                               lids meet the eye shaded and rough, the cornea
                               glass-smooth
  roman_reigns_eye_height.png  the iris sitting BEHIND the cornea (parallax)
  roman_reigns_lash_alpha.png  lash strands for the cards' layout

RomanModel._fix_eyes puts them on.

Usage:  python3 tools/assets/build_roman_eyes.py     (deterministic)
"""

from __future__ import annotations

import math
import pathlib
import sys

import numpy as np

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    sys.exit("Pillow is required: pip install Pillow")

CHARACTERS = pathlib.Path(__file__).resolve().parents[2] / "game/assets/characters"

SIZE = 1024
## The line of sight on the eye's UVs, and millimetres per UV unit.
CENTRE = (0.501, 0.455)
MM_PER_UV = 31.0
## Real anatomy, in mm: an adult iris is ~11.8 mm across; the pupil under arena
## light is small, ~3.8 mm. The collarette -- the ring where the iris's inner
## and outer zones meet -- sits about 40% of the way out.
IRIS_R = 5.9
PUPIL_R = 1.9
COLLARETTE_R = 3.0
LIMBUS_W = 0.7
## Colours (sRGB). His eyes are a deep dark brown; the inner zone is a
## warmer brown than the outer, and the limbal ring nearly black. First
## rendered at (118, 72, 36) inner with a bright collarette, the eye read
## amber and doll-like -- a stare his photos do not have.
IRIS_INNER = np.array([78, 46, 24], dtype=np.float32)
IRIS_OUTER = np.array([42, 25, 15], dtype=np.float32)
COLLARETTE_LIFT = 10.0
LIMBUS = np.array([22, 14, 10], dtype=np.float32)
PUPIL = np.array([6, 5, 5], dtype=np.float32)
## Not paper-white: a living sclera is a warm off-white, a shade below what
## a white material renders as under a key.
SCLERA = np.array([204, 193, 180], dtype=np.float32)
VEIN = np.array([185, 92, 82], dtype=np.float32)
## Where the eye meets the lids: past OCCLUDE_FROM mm the sclera is in the
## lids' shadow, fully by OCCLUDE_TO -- the outer band (from ~9.3 mm) lives
## here. Occlusion also darkens the albedo a little, as a real eye's corners
## are darker than its front.
## From 6.5 mm: at 7.5 the corners of the opening (~10-12 mm out to the
## sides) still read bright paper-white.
OCCLUDE_FROM = 6.5
OCCLUDE_TO = 11.5
OCCLUDED_AO = 0.22
OCCLUDED_ALBEDO = 0.62
## Roughness: the cornea is a wet lens, the sclera wet but less smooth, the
## shadowed band rough enough not to mirror the rig.
CORNEA_ROUGHNESS = 0.04
SCLERA_ROUGHNESS = 0.16
BAND_ROUGHNESS = 0.55
## The iris plane sits ~2.5 mm behind the cornea's apex. As a height map:
## white is the cornea surface, the iris darker.
IRIS_DEPTH = 0.55
SEED = 31


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def polar():
    u = (np.arange(SIZE) + 0.5) / SIZE
    uu, vv = np.meshgrid(u, u)
    dx = (uu - CENTRE[0]) * MM_PER_UV
    dy = (vv - CENTRE[1]) * MM_PER_UV
    return np.hypot(dx, dy), np.arctan2(dy, dx)


def periodic_noise(rng, theta, count, scale):
    """Smooth noise round the circle: a sum of random-phase harmonics."""
    out = np.zeros_like(theta)
    for k in range(1, count + 1):
        out += rng.normal(0.0, 1.0) / k ** 0.6 * np.cos(k * scale * theta + rng.uniform(0, 2 * np.pi))
    return out / np.abs(out).max()


def build_eye(color_path, orm_path, height_path) -> None:
    rng = np.random.default_rng(SEED)
    r, th = polar()
    # Iris fibres: radial striations (many harmonics round the circle) that
    # wander a little with radius, and crypts -- darker pits -- in the
    # outer zone.
    fibres = np.zeros_like(r)
    for k in (37, 53, 71, 97, 131):
        fibres += np.cos(k * th + 1.7 * np.sin(r * 1.3 + k) + rng.uniform(0, 2 * np.pi)) / len((37, 53, 71, 97, 131))
    crypts = periodic_noise(rng, th, 24, 1.0) * np.sin(r * 2.1 + periodic_noise(rng, th, 8, 1.0) * 2.0)
    zone = smooth(COLLARETTE_R - 0.4, COLLARETTE_R + 0.6, r)
    iris = IRIS_INNER[None, None, :] * (1.0 - zone[..., None]) + IRIS_OUTER[None, None, :] * zone[..., None]
    iris *= (1.0 + 0.22 * fibres - 0.12 * np.clip(crypts, 0.0, 1.0) * zone)[..., None]
    # A bright, uneven collarette ring.
    collar = np.exp(-((r - COLLARETTE_R) / 0.35) ** 2) * (0.6 + 0.4 * periodic_noise(rng, th, 12, 1.0))
    iris += (collar * COLLARETTE_LIFT)[..., None]
    # The limbal ring: the iris darkens into its rim, softly.
    limb = smooth(IRIS_R - LIMBUS_W, IRIS_R - 0.05, r)
    iris = iris * (1.0 - limb[..., None]) + LIMBUS[None, None, :] * limb[..., None]
    # Sclera, with faint veins reaching in from the edge.
    sclera = np.broadcast_to(SCLERA, r.shape + (3,)).astype(np.float32).copy()
    veins = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(veins)
    for _ in range(26):
        a = rng.uniform(0, 2 * np.pi)
        rad = rng.uniform(11.5, 13.0)
        pts = []
        for _ in range(22):
            pts.append((CENTRE[0] * SIZE + math.cos(a) * rad / MM_PER_UV * SIZE,
                        CENTRE[1] * SIZE + math.sin(a) * rad / MM_PER_UV * SIZE))
            rad -= rng.uniform(0.12, 0.28)
            a += rng.normal(0.0, 0.035)
            if rad < 7.0:
                break
        draw.line(pts, fill=int(rng.integers(60, 120)), width=1)
    veins = np.asarray(veins.filter(ImageFilter.GaussianBlur(0.8)), dtype=np.float32) / 255.0
    sclera = sclera * (1.0 - veins[..., None]) + VEIN[None, None, :] * veins[..., None]
    # Iris into sclera over a fraction of a millimetre.
    edge = smooth(IRIS_R - 0.05, IRIS_R + 0.35, r)
    rgb = iris * (1.0 - edge[..., None]) + sclera * edge[..., None]
    pupil = 1.0 - smooth(PUPIL_R - 0.15, PUPIL_R + 0.2, r)
    rgb = rgb * (1.0 - pupil[..., None]) + PUPIL[None, None, :] * pupil[..., None]
    occluded = smooth(OCCLUDE_FROM, OCCLUDE_TO, r)
    rgb *= (1.0 - (1.0 - OCCLUDED_ALBEDO) * occluded)[..., None]
    Image.fromarray(np.clip(np.round(rgb), 0, 255).astype(np.uint8), "RGB").save(color_path, optimize=True)
    ao = 1.0 - (1.0 - OCCLUDED_AO) * occluded
    rough = np.where(r < IRIS_R + 0.6, CORNEA_ROUGHNESS, SCLERA_ROUGHNESS)
    rough = rough + (BAND_ROUGHNESS - SCLERA_ROUGHNESS) * occluded
    orm = np.stack([ao, rough, np.zeros_like(r)], axis=-1)
    Image.fromarray(np.round(orm * 255).astype(np.uint8), "RGB").save(orm_path, optimize=True)
    # Height: the cornea surface at 1, the iris IRIS_DEPTH down, easing in at
    # the limbus; the pupil a little deeper still.
    # (The pupil is not set deeper than the iris: in parallax it dragged a
    # dark keyhole down the iris.)
    height = 1.0 - IRIS_DEPTH * (1.0 - smooth(IRIS_R - 0.3, IRIS_R + 0.4, r))
    Image.fromarray(np.round(height * 255).astype(np.uint8), "L").save(height_path, optimize=True)
    print(f"eye -> {color_path.name}, {orm_path.name}, {height_path.name}")


## Lashes: tapered, curving hairs from the root line. His upper lashes are
## dark, dense and of moderate length; the lower ones short and sparse.
LASH_UPPER = dict(root=0.045, tip=(0.28, 0.45), count=260, curl=0.05)
LASH_LOWER = dict(root=0.955, tip=(0.80, 0.70), count=110, curl=-0.03)
LASH_SEED = 37


def build_lashes(path) -> None:
    rng = np.random.default_rng(LASH_SEED)
    ss = 2
    size = SIZE * ss
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    for spec, down in ((LASH_UPPER, 1.0), (LASH_LOWER, -1.0)):
        for _ in range(spec["count"]):
            u0 = rng.uniform(0.02, 0.98)
            tip_v = rng.uniform(min(spec["tip"]), max(spec["tip"]))
            length = abs(tip_v - spec["root"])
            lean = rng.normal(0.0, 0.02) + spec["curl"]
            width = rng.uniform(1.2, 2.2) * ss
            steps = 14
            prev = None
            for k in range(steps + 1):
                t = k / steps
                u = u0 + lean * t * t
                v = spec["root"] + down * length * t
                p = (u * size, v * size)
                if prev is not None:
                    w = max(1, round(width * (1.0 - 0.85 * t)))
                    draw.line([prev, p], fill=int(255 * (1.0 - 0.5 * t)), width=w)
                prev = p
    mask = mask.filter(ImageFilter.GaussianBlur(0.5 * ss)).resize((SIZE, SIZE), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    out.putalpha(mask)
    out.save(path, optimize=True)
    print(f"lashes -> {path.name}")


def main() -> int:
    build_eye(CHARACTERS / "roman_reigns_eye_color.png", CHARACTERS / "roman_reigns_eye_orm.png",
              CHARACTERS / "roman_reigns_eye_height.png")
    build_lashes(CHARACTERS / "roman_reigns_lash_alpha.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
