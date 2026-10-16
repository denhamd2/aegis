#!/usr/bin/env python3
"""Deterministic fibre atlas for Roman's curved, skinned beard clumps.

The runtime groom samples the existing trimmed/rigged beard, retaining its
volume and skin. This atlas carries coverage and fibre pigment, not lighting.
"""
from pathlib import Path
import argparse
import numpy as np
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[2] / 'game/assets/characters'


def build(out: Path):
    out.mkdir(parents=True, exist_ok=True)
    size, scale, cells = 1024, 3, 8
    image = Image.new('RGBA', (size*scale, size*scale), (32, 26, 23, 0))
    draw = ImageDraw.Draw(image)
    rng = np.random.default_rng(161036)
    for cell in range(cells):
        for fibre in range(24):
            x = rng.uniform(.08, .92)
            lean, wave, phase = rng.uniform(-.08,.08), rng.uniform(.005,.03), rng.uniform(0,6.283)
            length, start = rng.uniform(.70,.99), rng.uniform(.0,.035)
            shade = int(rng.uniform(13,28))
            points = []
            for t in np.linspace(start, length, 32):
                u = cell + .5 + (x-.5)*(1-.28*t) + lean*t + wave*np.sin(t*9+phase)
                points.append((u/cells*size*scale, (.015+t*.97)*size*scale))
            draw.line(points, fill=(shade,round(shade*.85),round(shade*.75),255), width=int(rng.integers(2,4)))
    image.resize((size,size), Image.Resampling.LANCZOS).save(out/'roman_reigns_beard_groom.png', optimize=True)
    print('Roman beard fibre atlas written.')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out-dir',type=Path,default=OUT)
    build(p.parse_args().out_dir)
