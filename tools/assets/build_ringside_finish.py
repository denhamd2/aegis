#!/usr/bin/env python3
"""A deterministic linear roughness map for the existing 2x2 crash-mat tile.

The colour and normal maps remain independent: illumination/reflections are
never painted into this map. Darker satin faces carry broad LED reflections;
the recessed seams and occasional scuffs have a rougher return.
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/environment/materials/ringside_pads_roughness.png"


def main() -> None:
    size = 1024
    y, x = np.mgrid[:size, :size].astype(float) / size
    d = np.minimum(np.mod(x * 2.0, 1.0), 1.0 - np.mod(x * 2.0, 1.0))
    d = np.minimum(d, np.minimum(np.mod(y * 2.0, 1.0), 1.0 - np.mod(y * 2.0, 1.0)))
    seam = 1.0 - np.clip((d - 0.006) / 0.035, 0.0, 1.0)
    grain = np.random.default_rng(20261015).normal(0.0, 0.012, (size, size))
    broad = 0.018 * np.sin(x * np.pi * 18.0 + np.sin(y * np.pi * 4.0))
    roughness = np.clip(0.44 + seam * 0.19 + broad + grain, 0.36, 0.68)
    data = np.uint8(np.round(roughness * 255.0))
    Image.fromarray(data).save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
