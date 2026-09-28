#!/usr/bin/env python3
"""The tiling skin micro-detail normal map: pores and fine creases.

gauntlet/refs/aaa_gap.md, item 6. Every skin in the slice was a smooth
surface under its base normal map, so a key light made one unbroken highlight
across a forehead or a shoulder -- the "CG" sheen. Real skin breaks that
highlight into thousands of points: pores, each a tiny dimple, and a fine
cross-hatch of creases between them. A scanned 4K texture carries that; ours
do not, and there is no scan to take. So it is generated, the way a
texture artist's "skin detail" tile is: height from pores and creases, then
a normal map from the height.

Run:  python3 tools/assets/build_skin_detail.py
Writes game/assets/characters/skin_detail_normal.png (512 x 512, tiling).
Deterministic: a fixed seed, so the same run writes the same bytes.

Scale: a pore is ~0.1-0.25 mm across and they sit 0.5-1 mm apart on a
cheek, further on the body. The tile holds ~48 pores across; SkinLook tiles
it so one tile covers a few centimetres of skin.
"""

from __future__ import annotations

import pathlib

import numpy as np
from PIL import Image

REPO = pathlib.Path(__file__).resolve().parents[2]
OUT = REPO / "game/assets/characters/skin_detail_normal.png"
SIZE = 512
SEED = 7
PORES_ACROSS = 48
PORE_RADIUS = 2.2      # px, gaussian sigma
PORE_DEPTH = 1.0
CREASE_DEPTH = 0.35
## How steep the resulting normals are. Kept low: this is micro-detail under
## a base normal map, not relief.
STRENGTH = 2.2


def wrapped_gaussian_blur(a: np.ndarray, sigma: float) -> np.ndarray:
    """Blur that wraps at the edges (via FFT), so the tile stays seamless."""
    f = np.fft.fftfreq(a.shape[0])
    kx, ky = np.meshgrid(f, f)
    g = np.exp(-2.0 * (np.pi ** 2) * (sigma ** 2) * (kx ** 2 + ky ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def main() -> int:
    rng = np.random.default_rng(SEED)
    height = np.zeros((SIZE, SIZE))
    # Pores: a jittered grid (even spacing, no clumps), each a dimple of
    # varied depth and size.
    cell = SIZE / PORES_ACROSS
    impulses = np.zeros((SIZE, SIZE))
    for gy in range(PORES_ACROSS):
        for gx in range(PORES_ACROSS):
            x = int((gx + rng.uniform(0.15, 0.85)) * cell) % SIZE
            y = int((gy + rng.uniform(0.15, 0.85)) * cell) % SIZE
            impulses[y, x] -= PORE_DEPTH * rng.uniform(0.5, 1.2)
    height += wrapped_gaussian_blur(impulses, PORE_RADIUS) * (2 * np.pi * PORE_RADIUS ** 2)
    # Creases: noise stretched along two diagonals -- the fine diamond
    # cross-hatch of skin between the pores.
    for angle in (np.pi / 4, -np.pi / 4):
        noise = rng.normal(size=(SIZE, SIZE))
        f = np.fft.fftfreq(SIZE)
        kx, ky = np.meshgrid(f, f)
        along = kx * np.cos(angle) + ky * np.sin(angle)
        across = -kx * np.sin(angle) + ky * np.cos(angle)
        # Long along the crease, narrow across it.
        g = np.exp(-(along / 0.012) ** 2 - (across / 0.09) ** 2)
        crease = np.real(np.fft.ifft2(np.fft.fft2(noise) * g))
        crease = -np.abs(crease)          # creases are grooves, never ridges
        crease /= np.abs(crease).max()
        height += CREASE_DEPTH * crease
    height -= height.mean()
    height /= np.abs(height).max()
    # Normal from the wrapped gradient.
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    n = np.dstack([-dx * STRENGTH, -dy * STRENGTH, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    # OpenGL convention (Godot's): +Y up in the image means +V.
    rgb = np.clip((n * 0.5 + 0.5) * 255.0 + 0.5, 0, 255).astype(np.uint8)
    rgb[..., 1] = 255 - rgb[..., 1]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgb, "RGB").save(OUT, optimize=False)
    print(f"wrote {OUT} ({SIZE}x{SIZE}), z range {n[..., 2].min():.3f}..1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
