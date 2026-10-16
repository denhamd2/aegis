#!/usr/bin/env python3
"""Author repeatable skin roughness and a broken sweat film for the October refs.

These are material data, not painted lighting. Red/green in *_wet.png control
clearcoat amount/roughness; skin roughness is separate. The fixed seed and
shared 1K masks keep residency bounded. No source colour image is modified.
"""
from pathlib import Path
import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "game/assets/characters"
SIZE = 1024


def noise(rng, size, strength=1.0):
    a = rng.integers(0, 256, (size, size), dtype=np.uint8)
    image = Image.fromarray(a).resize((SIZE, SIZE), Image.Resampling.BICUBIC)
    return np.asarray(image, dtype=np.float32) / 255.0 * strength


def save(name, array):
    image = Image.fromarray(np.uint8(np.clip(array, 0, 1) * 255 + .5))
    image.save(OUT / name, optimize=False)
    config = (OUT / name).with_suffix(".png.import")
    if config.exists():
        source = config.read_text()
        source = source.replace("compress/mode=0", "compress/mode=2")
        source = source.replace("compress/high_quality=false", "compress/high_quality=true")
        source = source.replace("mipmaps/generate=false", "mipmaps/generate=true")
        config.write_text(source)
    print(name)


def main():
    rng = np.random.default_rng(16102026)
    broad = noise(rng, 18)
    mid = noise(rng, 170)
    # A 1K body atlas spans roughly a metre: beads need pixel-scale breakup,
    # while the slower roughness variation stays broad enough to mip cleanly.
    fine = noise(rng, 512)
    # A continuous thin film with small beads and dry interruptions. Avoid a
    # binary/noisy mask that sparkles as it crosses a pixel during movement.
    bead = np.clip((fine - .57) * 3.5, 0, 1)
    coverage = np.clip(.23 + .42 * broad + .32 * bead, .18, .91)
    film_rough = np.clip(.9 - .32 * bead + .06 * broad, .58, .96)
    wet = np.dstack((coverage, film_rough, np.zeros_like(coverage)))
    save("skin_wet_film.png", wet)
    body_rough = np.clip(.64 + .09 * (broad - .5) + .08 * (mid - .5), .52, .75)
    save("skin_body_roughness.png", body_rough)

    v, u = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32) / (SIZE - 1)
    def spot(x, y, sx, sy):
        return np.exp(-.5 * (((u - x) / sx) ** 2 + ((v - y) / sy) ** 2))
    # Cody's existing head UVs: brow ~.30, nose ~.48, mouth ~.59.
    t_zone = np.maximum(spot(.5, .28, .12, .045), spot(.5, .46, .037, .10))
    lip = spot(.5, .59, .075, .018)
    rough = np.clip(body_rough - .13 * t_zone - .12 * lip, .39, .76)
    # Keep the painted scalp below the groom matte and out of the sweat film.
    scalp = np.clip((.22 - v) / .035, 0, 1)
    scalp = np.maximum(scalp, np.clip((np.abs(u - .5) - .34) / .06, 0, 1) * (v < .65))
    save("cody_skin_head_roughness.png", rough * (1 - scalp) + .94 * scalp)
    cody_wet = wet.copy()
    cody_wet[..., 0] *= 1 - scalp
    save("cody_skin_head_wet.png", cody_wet)
    # Roman's existing head surface map explicitly identifies the scalp in G.
    source = Image.open(OUT / "roman_reigns_head_rm.png").convert("RGB")
    source = np.asarray(source.resize((SIZE, SIZE), Image.Resampling.BILINEAR), dtype=np.float32) / 255
    roman_wet = wet.copy()
    roman_wet[..., 0] *= np.clip(1 - source[..., 1] * 1.5, 0, 1)
    save("roman_reigns_skin_head_wet.png", roman_wet)


if __name__ == "__main__":
    main()
