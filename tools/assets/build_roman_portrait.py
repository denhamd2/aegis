#!/usr/bin/env python3
"""October 16 Roman portrait albedo/roughness from the supplied head sources.

Keeps the measured UVs, beard underpaint and scalp coverage. Finer brows,
less baked facial shading and nonmetallic roots complement the mesh refit.
Reuses the canonical head reconstruction rather than filtering a painted
output repeatedly. The supplied wrinkle normal stays the primary relief.

Run: python3 tools/assets/build_roman_portrait.py [--out-dir PATH]
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

import build_roman_hair_alpha as source


def build_scatter_mask(out: Path):
    # The supplied mask is white on hair and black on skin. SkinLook's
    # unmasked diffusion otherwise bleeds forehead light through dark roots.
    hair = Image.open(source.CHARACTERS / "roman_reigns_headhair_mask.png").convert("L")
    skin = hair.point(lambda value: 255 - value)
    skin.resize((1024, 1024), Image.Resampling.LANCZOS).save(
        out / "roman_reigns_portrait_sss.png", optimize=True)


def build_roots(out: Path):
    # Existing authored scalp coverage already excludes ears/face. A separate
    # nonmetallic material can shade these short dark roots independently
    # from skin, with the same UVs and the same skinned head mesh.
    coverage = Image.open(source.CHARACTERS / "roman_reigns_head_rm.png").getchannel("G")
    roots = Image.new("RGBA", (1024, 1024), (255, 255, 255, 0))
    roots.putalpha(coverage.resize(roots.size, Image.Resampling.LANCZOS))
    roots.save(out / "roman_reigns_portrait_roots.png", optimize=True)


def build(out: Path):
    out.mkdir(parents=True, exist_ok=True)
    colour = out / "roman_reigns_portrait_color.png"
    surface = out / "roman_reigns_portrait_rm.png"
    source.CONTRAST = .25
    source.LIFT = .35
    source.WRINKLE_KEEP = .35
    source.BROW_STRANDS = 1100
    source.BROW_WIDTH_PX = .6
    source.BROW_LENGTH = (.0025, .0045)
    source.BROW_FILL = 130
    source.BROW_PROFILE = [
        (.011, 1.7350, .0032), (.020, 1.7360, .0038),
        (.032, 1.7366, .0035), (.044, 1.7360, .0029),
        (.054, 1.7345, .0019), (.060, 1.7330, .0008),
    ]
    # Short, denser stubble makes the painted cheek transition less like
    # long marker strokes. Geometry/opacity of the existing beard is kept.
    source.BEARD_STRAND_LENGTH = (.0025, .0045)
    source.BEARD_STRAND_DENSITY = 1.4e6
    source.BEARD_LINE_FEATHER = .0045
    source.SCALP_CAP_FEATHER = (.0045, .009)
    source.SCALP_CAP_COLOR = (7, 6, 5)
    source.SCALP_CAP_ROUGHNESS = .70
    source.SKIN_ZONES = [
        ((.050, 1.688, .120), (.030, .022, .040), (1.035, .97, .965)),
        ((.000, 1.680, .150), (.020, .028, .030), (1.04, .965, .955)),
        ((.034, 1.718, .120), (.022, .010, .030), (.98, .96, .96)),
    ]
    source.LIP_TONE = (.65, .55, .56)
    model = source.CHARACTERS / "roman_reigns.glb"
    source.build_head(source.CHARACTERS / "roman_reigns_body_color.png",
                      source.CHARACTERS / "roman_reigns_Image.png", colour)
    source.paint_skin(model, colour)
    brows = source.paint_brows(model, colour)
    source.paint_beard_shadow(model, colour)
    source.paint_beard_strands(model, colour)
    source.paint_scalp_cap(model, colour, surface)
    # Scalp coverage is not metal. Keep the existing roughness separation
    # and the same underpaint; remove the old metallic root mask only.
    rm = np.array(Image.open(surface).convert("RGB"))
    rm[..., 1:] = 0
    # Dark brow hairs must not share the forehead's broad skin highlight.
    # Use the actual authored fibre mask, preserving fine strand edges.
    brow_weight = np.asarray(brows, dtype=np.float32) / 255
    rm[..., 0] = np.uint8(np.maximum(rm[..., 0],
                                    (source.HEAD_SKIN_ROUGHNESS +
                                     (.88 - source.HEAD_SKIN_ROUGHNESS) * brow_weight) * 255) + .5)
    Image.fromarray(rm).save(surface, optimize=True)
    build_scatter_mask(out)
    build_roots(out)
    print("Roman portrait maps written; original head sources unchanged.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, default=source.CHARACTERS)
    build(parser.parse_args().out_dir)
