#!/usr/bin/env python3
"""Reference-directed Roman portrait colour/roughness on the supplied UVs.

Keeps the measured UVs, beard underpaint and scalp coverage. Finer brows,
less baked facial shading and nonmetallic roots complement the mesh refit.
Registers a retained image-generated albedo source, preserves the neck seam
and retains the supplied anatomical wrinkle normal as relief. --legacy
rebuilds the earlier damaged-channel reconstruction for historical comparison.

Run: python3 tools/assets/build_roman_portrait.py [--out-dir PATH]
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates, gaussian_filter

import build_roman_hair_alpha as source


def build_scatter_mask(out: Path):
    # The independent scalp/beard underpaint mask is white on hair.
    # Exclude it from flesh diffusion, including the formerly waxy chin.
    hair = Image.open(out / 'roman_reigns_portrait_roots.png').getchannel('A')
    skin = hair.point(lambda value: 255 - value)
    skin.resize((1024, 1024), Image.Resampling.LANCZOS).save(
        out / "roman_reigns_portrait_sss.png", optimize=True)


def build_roots(out: Path):
    # Existing scalp coverage plus the registered beard pigment separate
    # hair response from flesh, on the same UVs and skinned head mesh.
    roots = Image.open(out / 'roman_reigns_portrait_color.png').convert('RGBA').resize((1024,1024), Image.Resampling.LANCZOS)
    coverage = np.asarray(Image.open(source.CHARACTERS / "roman_reigns_head_rm.png").getchannel("G").resize(roots.size, Image.Resampling.LANCZOS), dtype=np.float32) / 255
    # The old head mask covered scalp only. Painted beard pigment otherwise
    # received skin scattering/clearcoat and made a pale waxy chin patch.
    # Extend the SAME independent hair layer, keeping lips/nostrils flesh.
    rgb = np.asarray(roots.convert('RGB'), dtype=np.float32)
    v,u = np.mgrid[0:1024,0:1024].astype(np.float32)/1023
    luminance = rgb[...,0]*.2126+rgb[...,1]*.7152+rgb[...,2]*.0722
    beard = np.clip((105-luminance)/45,0,1)*np.clip((v-.48)/.025,0,1)
    beard *= np.clip((.80-v)/.035,0,1)
    lip = np.sqrt(((u-.5)/.087)**2+((v-.576)/.028)**2)
    beard *= np.clip((lip-.85)/.25,0,1)
    # Dense brows are hair too: the flesh diffusion/wet layer otherwise
    # turns the black eyebrow pigment grey under the close entrance key.
    brow_region = np.clip((v-.245)/.012,0,1)*np.clip((.31-v)/.012,0,1)
    brow_region *= np.clip((u-.26)/.025,0,1)*np.clip((.74-u)/.025,0,1)
    brows = np.clip((105-luminance)/45,0,1)*brow_region
    coverage = np.maximum.reduce([coverage,beard,brows])
    roots.putalpha(Image.fromarray(np.uint8(coverage*255+.5)))
    roots.save(out / "roman_reigns_portrait_roots.png", optimize=True)


def build_legacy(out: Path):
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
    build_roots(out)
    build_scatter_mask(out)
    print("Roman portrait maps written; original head sources unchanged.")


def build(out: Path):
    """Register the generated, reference-directed colour source to measured UVs.

    Nose/lips are aligned to the supplied anatomical normal, rather than
    accepting the image model's feature drift. Neck islands retain the prior
    source colour so the body seam and tattoo remain unchanged. No highlights
    or shadows are added. Relief/roughness remain separate material inputs.
    """
    out.mkdir(parents=True, exist_ok=True)
    raw = Path(__file__).with_name('sources') / 'roman_portrait_albedo_generated.png'
    image = np.asarray(Image.open(raw).convert('RGB'), dtype=np.float32)
    size = 2048
    v, u = np.mgrid[0:size, 0:size].astype(np.float32) / (size-1)
    # Destination -> source vertical registration, normalized image UVs.
    source_v = np.interp(v[:, 0], [0, .28, .35, .47, .57, .60, .72, 1],
                        [0, .28, .35, .46, .55, .58, .72, 1])[:, None]
    source_v = np.broadcast_to(source_v, (size,size))
    colour = np.stack([map_coordinates(image[..., c],
                         [source_v*(image.shape[0]-1), u*(image.shape[1]-1)],
                         order=1, mode='nearest') for c in range(3)], axis=2)
    legacy = np.asarray(Image.open(source.CHARACTERS/'roman_reigns_head_color.png').convert('RGB').resize((size,size)), dtype=np.float32)
    neck = np.clip((v-.75)/.15, 0, 1)
    neck = neck*neck*(3-2*neck)
    colour = colour*(1-neck[..., None]) + legacy*neck[..., None]
    Image.fromarray(np.uint8(np.clip(colour,0,255)+.5)).save(out/'roman_reigns_portrait_color.png', optimize=True)
    original = np.asarray(Image.open(source.CHARACTERS/'roman_reigns_head_rm.png').convert('RGB').resize((size,size)), dtype=np.float32)/255
    roughness = original[...,0]
    # Fine spatial variation changes the highlight without making the head
    # metallic or painting specular reflections into colour.
    rng = np.random.default_rng(161037)
    grain = gaussian_filter(rng.random((size,size), dtype=np.float32), 1.2)-.5
    roughness = np.clip(roughness + grain*.05, source.HEAD_SKIN_ROUGHNESS, .95)
    brow = np.exp(-.5*((v-.278)/.014)**2)*np.maximum(
        np.exp(-.5*((u-.37)/.07)**2), np.exp(-.5*((u-.63)/.07)**2))
    roughness = np.maximum(roughness, .58+.30*brow)
    rm = np.zeros((size,size,3), dtype=np.uint8)
    rm[...,0] = np.uint8(roughness*255+.5)
    Image.fromarray(rm).save(out/'roman_reigns_portrait_rm.png', optimize=True)
    build_roots(out)
    build_scatter_mask(out)
    print('Reference-directed portrait maps registered; source GLB/rig unchanged.')


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, default=source.CHARACTERS)
    parser.add_argument('--legacy', action='store_true', help='rebuild the prior damaged-channel reconstruction')
    args = parser.parse_args()
    (build_legacy if args.legacy else build)(args.out_dir)
