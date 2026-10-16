#!/usr/bin/env python3
"""Author fibre relief and restrained colour variation from the beard mask.

Opacity is copied unchanged. This adds material data; it does not repaint
the face, enlarge the beard or alter its imported cards/skin weights.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

OUT = Path(__file__).resolve().parents[2] / "game/assets/characters"


def main():
    source = Image.open(OUT / "roman_reigns_beard_alpha.png").convert("RGBA")
    w, h = source.size
    rng = np.random.default_rng(161027)
    grain = Image.fromarray(rng.integers(0, 256, (128, 128), dtype=np.uint8))
    grain = np.asarray(grain.resize((w, h), Image.Resampling.BICUBIC), dtype=np.float32) / 255
    tone = np.uint8(np.clip(.72 + .28 * grain, 0, 1) * 255 + .5)
    colour = Image.merge("RGB", tuple(Image.fromarray(tone) for _ in range(3)))
    colour.putalpha(source.getchannel("A"))
    colour.save(OUT / "roman_reigns_beard_detail.png")
    # Normal relief follows the existing fibre coverage, never its lighting.
    height = np.asarray(source.getchannel("A").filter(ImageFilter.GaussianBlur(.65)), dtype=np.float32) / 255
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * .9
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * .9
    normal = np.dstack((-dx, dy, np.ones_like(height)))
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    Image.fromarray(np.uint8((normal * .5 + .5) * 255 + .5)).save(OUT / "roman_reigns_beard_detail_normal.png")
    for name in ["roman_reigns_beard_detail.png", "roman_reigns_beard_detail_normal.png"]:
        config = (OUT / name).with_suffix(".png.import")
        if config.exists():
            text = config.read_text().replace("compress/mode=0", "compress/mode=2")
            text = text.replace("compress/high_quality=false", "compress/high_quality=true")
            text = text.replace("mipmaps/generate=false", "mipmaps/generate=true")
            if "_normal" in name:
                text = text.replace("compress/normal_map=0", "compress/normal_map=1")
            config.write_text(text)
    print("Beard detail maps written; source opacity preserved.")


if __name__ == "__main__":
    main()
