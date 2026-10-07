#!/usr/bin/env python3
"""Builds alpha-masked hair/beard textures for the Roman Reigns model.

The supplied model's hair and beard meshes are alpha cards, and the export
wired their *packed data* maps in as base colour. Those maps -- hair_rai,
hair_rai_4 and combinations_rai -- are not albedo at all: R and B carry
identical data (mean 122.4 each in hair_rai) and the **green channel is the
strand opacity mask**. Fed to a renderer as albedo with no alpha, R=B high
against low G is literally the definition of magenta, which is why every hair
card on the model renders as a solid magenta blob.

There is no hair colour texture anywhere in the asset -- not embedded in the
.glb (14 images, all accounted for) and not among the loose PNGs. So the
colour has to come from a tint, and what these files supply is the mask.

This writes, for each source atlas, an RGBA PNG with white RGB and the source's
green channel as alpha. White RGB means the material's albedo_color does the
tinting, so hair colour stays a one-line change in roman_model.gd rather than
something baked into a 2048x2048 texture.

Usage:  python3 tools/assets/build_roman_hair_alpha.py
Outputs are written next to their sources in game/assets/characters/.
"""

import pathlib
import sys

import json
import math
import struct

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter
except ImportError:
    sys.exit("Pillow is required: pip install Pillow")

CHARACTERS = pathlib.Path(__file__).resolve().parents[2] / "game/assets/characters"

## How much of the source's tonal range to keep when rebuilding the head
## albedo. 1.0 is the raw ratio, which reads as bruising; see build_head().
CONTRAST = 0.42
## Floor under the darkest texels, so baked occlusion shades rather than
## punches holes.
LIFT = 0.30

# source atlas -> generated alpha-masked texture
## Alpha gamma per generated mask. 1.0 leaves the source untouched.
##
## The beard needs it and the scalp does not, and the masks say why. Fraction
## of texels at or above a given alpha:
##
##                  >=0.50   >0      opaque share of what exists
##   hair_alpha      0.320   0.409   78%
##   beard_alpha     0.096   0.158   61%
##
## Only 9.6% of the beard mask is half-opaque or better against 15.8% that is
## non-zero: nearly 40% of its strands are ghosts. That is why the beard reads
## as scattered bristle high on the cheek rather than as the jawline the source
## model has -- the faint strands ARE in the right places, they are just too
## transparent to see, so the eye joins up only the strongest clumps.
##
## Gamma 0.55 lifts a 0.25 texel to 0.46 and a 0.5 to 0.68 while pinning 0 to 0
## and 255 to 255. No strand is invented and none is discarded; the ones the
## artist drew simply render at a weight you can see. The eyebrows live in this
## same mask and are sparser than the jaw, which is why they were missing
## altogether.
BEARD_GAMMA = 0.45

## Strand dilation for the beard mask, in texels (odd, 0 = off).
##
## Superseded by BEARD_INTERLEAVE below and left at 0. Kept because the
## measurement it produced is the reason interleaving exists: dilation makes
## each strand FATTER, and past a very small radius that is how you get a
## moustache rendered as a solid slab (7 was tried, and looked exactly like
## that). It cannot add strands, only weight.
BEARD_DILATE = 0

## Horizontal offsets, in texels, at which to composite extra copies of the
## beard mask over itself.
##
## This is the repaint, done arithmetically rather than by hand. The problem
## was never that the beard's strands were in the wrong place -- measured
## against the mouth and eye lines, the mesh spans exactly where a beard,
## moustache and brow mesh should. The problem is that there are not enough of
## them: 15.8% of the mask is non-zero against the scalp mask's 40.9%, drawn
## by the same artist for the same head, so the jaw reads as scattered bristle
## next to a full head of hair.
##
## The atlas is a grid of strand cards whose hairs run vertically. Compositing
## the mask over horizontally-shifted copies of itself therefore lays a new
## hair into the gap beside each existing one, at the same length, curvature
## and taper, because it IS the same hair moved sideways. Every strand stays
## exactly as thin as it was drawn -- which is the difference between this and
## dilation, and the difference between a beard and a smear.
##
## Measured, at or above 0.5 alpha, against the scalp mask as the target:
##
##   hair_alpha (target)          0.3204
##   beard, untouched             0.0963
##   [-3, 3]                      0.2237
##   [-5, -2, 2, 5]  (chosen)     0.2917
##   [-7, -4, -2, 2, 4, 7]        0.3454   <- overshoots the scalp
##   [-9, -6, -3, 3, 6, 9]        0.3746
##
## Chosen to land just UNDER the scalp rather than over it: a beard denser
## than the head of hair above it reads as painted-on, and the offsets are
## small enough (max 5 texels of 2048) that bleed across card boundaries stays
## below one strand width.
BEARD_INTERLEAVE = (-5, -2, 2, 5)

SOURCES = {
    "roman_reigns_hair_rai.png": ("roman_reigns_hair_alpha.png", 1.0, 0, ()),
    "roman_reigns_hair_rai_4.png": (
        "roman_reigns_hair_4_alpha.png", 1.0, 0, ()),
    "roman_reigns_combinations_rai.png": (
        "roman_reigns_beard_alpha.png", BEARD_GAMMA, BEARD_DILATE,
        BEARD_INTERLEAVE),
}


def build(source: pathlib.Path, target: pathlib.Path, gamma: float = 1.0,
          dilate: int = 0, interleave: tuple = ()) -> None:
    image = Image.open(source).convert("RGBA")
    # Green is the strand mask; red and blue are the packed data we discard.
    mask = image.split()[1]
    if interleave:
        # Add strands BETWEEN the strands, rather than making each one fatter.
        # The atlas is a grid of strand cards whose hairs run vertically, so
        # compositing horizontally-shifted copies of the mask (lighter = per
        # texel max) drops a new hair into each gap while every hair stays as
        # thin as it was drawn. Shape and direction are the artist's; only the
        # count changes. See BEARD_INTERLEAVE.
        combined = mask
        for dx in interleave:
            combined = ImageChops.lighter(
                combined, ImageChops.offset(mask, dx, 0))
        mask = combined
    if dilate:
        # Grow each strand into its neighbours. A max filter takes the
        # brightest texel in the window, so a strand widens and the gaps
        # between strands close, while a region with no strand in reach stays
        # empty -- the beard's SHAPE is still the artist's, only its weight
        # changes. This is the one operation here that adds coverage rather
        # than redistributing it; see BEARD_DILATE.
        mask = mask.filter(ImageFilter.MaxFilter(dilate))
    if gamma != 1.0:
        # Thicken what is already there. alpha -> alpha**gamma with gamma < 1
        # lifts partial texels toward opaque and leaves 0 and 255 untouched,
        # so no strand is invented and none is lost -- the existing ones just
        # stop being ghosts. See BEARD_GAMMA for why the beard needs it.
        lut = [min(255, round(255.0 * ((i / 255.0) ** gamma))) for i in range(256)]
        mask = mask.point(lut)
    white = Image.new("L", image.size, 255)
    Image.merge("RGBA", (white, white, white, mask)).save(target, optimize=True)
    histogram = mask.histogram()
    total = sum(histogram)
    opaque = sum(histogram[128:]) / total
    print(f"{source.name:38} -> {target.name:34} {opaque:5.1%} of texels opaque")


def skin_tone(atlas: Image.Image) -> tuple[int, int, int]:
    """Median skin colour of the body atlas.

    Filtered to texels that actually look like skin (R > G > B, mid
    brightness) so the tattoo sleeve, the black trunks and the pink mouth
    interior don't drag the estimate. Downsampled first -- this only needs a
    representative colour, not every texel.
    """
    small = atlas.convert("RGB").resize((512, 256))
    skin = [
        (r, g, b)
        for r, g, b in small.getdata()
        if r > g > b and 60 < r < 240 and (r - b) > 20
    ]
    if not skin:
        raise SystemExit("no skin-like texels found in the body atlas")
    skin.sort(key=lambda c: c[0] * 0.299 + c[1] * 0.587 + c[2] * 0.114)
    return skin[len(skin) // 2]


def build_head(atlas: pathlib.Path, source: pathlib.Path, target: pathlib.Path) -> None:
    """Reconstructs a usable head albedo from a partly destroyed source.

    roman_reigns_Image.png is the head map -- its UVs line up exactly with the
    head mesh (forehead wrinkles, eye sockets, nostrils, lips and ears all land
    where they should, which body_color does not manage). But two of its three
    channels are gone: blue is pinned to 255 across 100% of the image, and red
    is clipped at both ends across ~40% of it. Only green survived intact (0%
    clipped low, 3% high).

    So the detail is recoverable and the colour is not. This takes green as
    luminance and tints it with the skin tone measured off body_color -- the
    same character's skin, undamaged -- normalising so mid-grey maps to that
    tone. The result keeps every wrinkle, pore and lip edge the source had.

    This is a RECONSTRUCTION, not the original texture. If the original head
    albedo can be re-exported from the source model with its channels intact,
    it should replace this outright.
    """
    tone = skin_tone(Image.open(atlas))
    green = Image.open(source).convert("RGB").split()[1]
    histogram = green.histogram()
    total = sum(histogram)
    mean = sum(i * c for i, c in enumerate(histogram)) / total

    lut = [[0] * 256 for _ in range(3)]
    for value in range(256):
        # Contrast is compressed toward the mean rather than applied at full
        # range. The green channel is a bake, not a photograph: it carries
        # baked occlusion in the eye sockets, under the brow and along the
        # nasolabial folds. Multiplying skin tone by the raw ratio drove
        # those regions to a dark red-brown and the face came out looking
        # beaten up rather than shaded. CONTRAST keeps the same detail and
        # the same relative ordering, at a fraction of the amplitude, and
        # LIFT stops the darkest texels bottoming out into near-black.
        ratio = LIFT + (1.0 - LIFT) * (value / mean)
        scale = 1.0 + CONTRAST * (ratio - 1.0)
        for channel in range(3):
            lut[channel][value] = max(0, min(255, round(tone[channel] * scale)))
    channels = [green.point(lut[c]) for c in range(3)]
    Image.merge("RGB", channels).save(target, optimize=True)
    print(f"{source.name:38} -> {target.name:34} skin tone {tone}, green mean {mean:.1f}")


## Skin, worked over the reconstructed albedo (build_head).
##
## Against 2K26 the face read as a wax mask: one flat orange tint, every baked
## crease at the same depth (forehead, crow's feet, nasolabial folds -- he
## looked twenty years older and carved), and a pale peach mouth that drew
## the eye before anything else did (gauntlet/refs/characters/review/
## faces_2k26_vs_ours.jpg). A real face is zoned: warmer and redder across
## the cheeks, nose and ears, where blood sits near the surface; darker and a
## little cooler in the eye sockets; and lips several shades deeper than the
## skin round them. So:
##
## 1. The bake is split into bands. The broad shading stays; the wrinkle band
##    (WRINKLE_RADII) comes down to WRINKLE_KEEP; the pore band stays almost
##    whole, so the skin keeps its grain.
## 2. Each zone is an ellipsoid-ish falloff in the head's own 3D space,
##    carried into texture space through the UVs (_uv_field) like the brows
##    and the beard, and applied as a multiply so the texture's detail rides
##    through.
WRINKLE_RADII = (3, 18)
WRINKLE_KEEP = 0.45
PORE_KEEP = 0.9
## (centre x, y, z, radius x, y, z, multiply RGB). x is mirrored.
SKIN_ZONES = [
    # cheeks: warm flush over the cheekbone
    ((0.050, 1.688, 0.120), (0.030, 0.022, 0.040), (1.03, 0.95, 0.94)),
    # nose: the same warmth, a touch stronger at the tip and wings
    ((0.000, 1.680, 0.150), (0.020, 0.028, 0.030), (1.03, 0.95, 0.94)),
    # eye sockets: deeper and cooler, the way his read under arena light
    ((0.034, 1.718, 0.120), (0.022, 0.010, 0.030), (0.88, 0.86, 0.90)),
]
## The lips: deeper, browner and a little mauve, against skin that is warm.
## (0.64, 0.54, 0.56) first: right in the texture, but the lower lip faces
## up into the arena's overhead key and still rendered pale peach
## (face_shot), so it goes deeper than it would under flat light.
LIP_TONE = (0.50, 0.40, 0.43)
LIP_Y = 1.647
LIP_HALF_W = 0.026
LIP_HALF_H = 0.0095
LIP_FEATHER = 0.45
## And matte, in the roughness map (written with the scalp cap's): at the
## skin's 0.58 the lower lip, facing up into the overhead key, caught a
## broad pale sheen that read as a peach band even once the colour was right.
LIP_ROUGHNESS = 0.80
_lip_field = None


def paint_skin(model: pathlib.Path, target: pathlib.Path) -> None:
    import numpy as np
    head = _glb_attributes(model, "M_Head")
    pos = np.array(head["POSITION"])
    uv = np.array(head["TEXCOORD_0"])
    tris = np.array(head["INDICES"]).reshape(-1, 3)
    albedo = Image.open(target).convert("RGB")
    size = albedo.size[0]
    img = np.asarray(albedo, dtype=np.float32)

    # 1. Soften the creases, keep the pores.
    def blur(r):
        return np.asarray(albedo.filter(ImageFilter.GaussianBlur(r)), dtype=np.float32)
    fine, broad = blur(WRINKLE_RADII[0]), blur(WRINKLE_RADII[1])
    img = broad + WRINKLE_KEEP * (fine - broad) + PORE_KEEP * (img - fine)

    # 2. Colour zones.
    tint = np.ones((size, size, 3), dtype=np.float32)
    front = pos[:, 2] > 0.0
    for centre, radius, mul in SKIN_ZONES:
        for side in ((1.0, -1.0) if centre[0] else (1.0,)):
            c = np.array([centre[0] * side, centre[1], centre[2]])
            d = np.sqrt((((pos - c) / np.array(radius)) ** 2).sum(axis=1))
            w = np.clip(1.0 - d, 0.0, 1.0) * front
            w = w * w * (3.0 - 2.0 * w)
            field = _uv_field(size, uv, tris, w)[..., None]
            tint *= 1.0 + field * (np.array(mul, dtype=np.float32) - 1.0)
    lip = np.sqrt((pos[:, 0] / LIP_HALF_W) ** 2 + ((pos[:, 1] - LIP_Y) / LIP_HALF_H) ** 2)
    w = np.clip((1.0 + LIP_FEATHER - lip) / LIP_FEATHER, 0.0, 1.0) * (pos[:, 2] > 0.04)
    global _lip_field
    _lip_field = _uv_field(size, uv, tris, w * w * (3.0 - 2.0 * w))
    field = _lip_field[..., None]
    tint *= 1.0 + field * (np.array(LIP_TONE, dtype=np.float32) - 1.0)
    # The zones are rasterised per triangle: blur off the facets.
    tint_img = Image.fromarray(np.clip(tint * 127.5, 0, 255).astype(np.uint8), "RGB") \
        .filter(ImageFilter.GaussianBlur(4))
    tint = np.asarray(tint_img, dtype=np.float32) / 127.5
    out = np.clip(img * tint, 0, 255).astype(np.uint8)
    Image.fromarray(out, "RGB").save(target, optimize=True)
    print(f"{'skin zones, lips':38} -> {target.name:34} wrinkles x{WRINKLE_KEEP}")


## Eyebrows, painted into the head albedo.
##
## The model has none that render. The beard/brow card mesh (M_Combinations)
## stops at y 1.708 -- the bottom of the eyes, 2 cm under where a brow sits --
## so there are no brow cards at all, whatever the alpha threshold; and the
## head map's surviving green channel is a shading bake with no brow in it.
## Rendered, he had a bare ridge over each eye (tools/probe/clip_shot.tscn
## --face).
##
## So brows are grown here as hair strokes: laid out in the HEAD'S OWN 3D
## SPACE over the measured eyes (M_EYE: centres x +-0.033, tops y 1.730), then
## carried into texture space through the head mesh's UVs, so they land on
## the brow ridge rather than wherever a guess in UV space would put them.
## Heavy, straight and low at the inner end, the way his are; thinning to a
## tail past the outer corner of the eye. Seeded, so the file is the same
## every build.
BROW_COLOR = (16, 12, 10)
BROW_SEED = 7
## (x from the midline, centre y, half-thickness) in metres along the brow.
##
## Flattened and lowered against the owner's side-by-side: the first profile
## rose 6.5 mm from the inner end to an arch over the outer eye and dropped
## again, and on the model that arch read as a worried, raised brow -- where
## his sit low and nearly straight over the eyes, the inner ends pulled down,
## which is most of his stare. Now it rises only 3 mm, peaks flat, and the
## tail barely drops; a touch thinner so it reads as hair, not marker.
##
## Then a fifth heavier, against 2K26's (faces_2k26_vs_ours.jpg): his are
## thick dark bars at broadcast distance and ours read grey and thin.
BROW_PROFILE = [(0.011, 1.7332, 0.0060), (0.020, 1.7348, 0.0064),
                (0.032, 1.7360, 0.0056), (0.044, 1.7363, 0.0045),
                (0.054, 1.7352, 0.0030), (0.060, 1.7336, 0.0015)]
BROW_STRANDS = 900
## Opacity of the soft fill under the strands: skin never shows through a
## brow this dense at broadcast distance, where single strands filter away.
BROW_FILL = 165
BROW_SUPERSAMPLE = 4


def _glb_attributes(path: pathlib.Path, mesh_name: str) -> dict:
    """POSITION / NORMAL / TEXCOORD_0 of one mesh's first primitive, read
    straight from the .glb -- no Blender, no numpy."""
    data = path.read_bytes()
    json_len = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + json_len])
    binary = 20 + json_len + 8
    mesh = next(m for m in gltf["meshes"] if m["name"] == mesh_name)
    out = {}
    prim = mesh["primitives"][0]
    if "indices" in prim:
        acc = gltf["accessors"][prim["indices"]]
        view = gltf["bufferViews"][acc["bufferView"]]
        fmt = {5121: "B", 5123: "H", 5125: "I"}[acc["componentType"]]
        start = binary + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        out["INDICES"] = list(struct.unpack_from("<%d%s" % (acc["count"], fmt), data, start))
    for key in ("POSITION", "NORMAL", "TEXCOORD_0"):
        accessor = gltf["accessors"][mesh["primitives"][0]["attributes"][key]]
        view = gltf["bufferViews"][accessor["bufferView"]]
        width = {"VEC2": 2, "VEC3": 3}[accessor["type"]]
        start = binary + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        flat = struct.unpack_from("<%df" % (accessor["count"] * width), data, start)
        out[key] = [flat[i:i + width] for i in range(0, len(flat), width)]
    return out


def _uv_mapper(head: dict):
    """Maps a point on the front of the face (x, y) to head UVs, by inverse-
    distance weighting of the four nearest front-facing head vertices."""
    front = [(p, uv) for p, n, uv in zip(head["POSITION"], head["NORMAL"],
                                         head["TEXCOORD_0"])
             if n[2] > 0.3 and abs(p[0]) < 0.09 and 1.69 < p[1] < 1.79]

    def to_uv(x: float, y: float) -> tuple[float, float]:
        near = sorted(front, key=lambda e: (e[0][0] - x) ** 2 + (e[0][1] - y) ** 2)[:4]
        total = u = v = 0.0
        for p, uv in near:
            w = 1.0 / max((p[0] - x) ** 2 + (p[1] - y) ** 2, 1e-10)
            total += w
            u += uv[0] * w
            v += uv[1] * w
        return u / total, v / total
    return to_uv


def _brow_at(t: float) -> tuple[float, float, float]:
    """(x, y, half-thickness) at t in [0, 1] along BROW_PROFILE."""
    f = t * (len(BROW_PROFILE) - 1)
    i = min(int(f), len(BROW_PROFILE) - 2)
    k = f - i
    a, b = BROW_PROFILE[i], BROW_PROFILE[i + 1]
    return tuple(a[j] + (b[j] - a[j]) * k for j in range(3))


def paint_brows(model: pathlib.Path, target: pathlib.Path) -> None:
    import random
    rng = random.Random(BROW_SEED)
    to_uv = _uv_mapper(_glb_attributes(model, "M_Head"))
    albedo = Image.open(target).convert("RGB")
    size = albedo.size[0]
    ss = BROW_SUPERSAMPLE
    mask = Image.new("L", (size * ss, size * ss), 0)
    draw = ImageDraw.Draw(mask)
    for side in (1.0, -1.0):
        for _ in range(BROW_STRANDS):
            # Denser toward the inner end, where his brows are heaviest.
            t = rng.random() ** 1.3
            x, y, half = _brow_at(t)
            y += rng.uniform(-half, half) * 0.95
            # Hairs lean up and out at the head of the brow, flatten along
            # the body, and droop slightly into the tail.
            angle = math.radians(62 - 70 * t + rng.uniform(-9, 9))
            length = rng.uniform(0.0045, 0.0075) * (1.0 - 0.35 * t)
            x2 = x + math.cos(angle) * length
            y2 = y + math.sin(angle) * length
            u0, v0 = to_uv(side * x, y)
            u1, v1 = to_uv(side * x2, y2)
            shade = rng.randint(190, 255)
            draw.line([(u0 * size * ss, v0 * size * ss), (u1 * size * ss, v1 * size * ss)],
                      fill=shade, width=max(1, round(1.6 * ss)))
    # The fill: the same brow shape as a solid band, softened, laid under the
    # strands so the brow reads as a brow and not as scratches once the
    # texture is mip-filtered at camera distance.
    for side in (1.0, -1.0):
        top, bottom = [], []
        for k in range(41):
            x, y, half = _brow_at(k / 40.0)
            top.append(to_uv(side * x, y + half * 0.8))
            bottom.append(to_uv(side * x, y - half * 0.8))
        outline = [(u * size * ss, v * size * ss) for u, v in top + bottom[::-1]]
        fill = Image.new("L", mask.size, 0)
        ImageDraw.Draw(fill).polygon(outline, fill=BROW_FILL)
        fill = fill.filter(ImageFilter.GaussianBlur(3 * ss))
        mask = ImageChops.lighter(mask, fill)
    mask = mask.resize(albedo.size, Image.LANCZOS)
    hair = Image.new("RGB", albedo.size, BROW_COLOR)
    Image.composite(hair, albedo, mask).save(target, optimize=True)
    print(f"{'brows':38} -> {target.name:34} {2 * BROW_STRANDS} strands")


## The beard's shadow, painted into the head albedo under the beard cards.
##
## Against the owner's side-by-side the beard read as a flat black cut-out
## with stepped edges, a disconnected moustache and a pale gap under the lower
## lip -- where he has one continuous, dense beard. The cards are fine; what
## showed was SKIN between and around them. A game beard is always two
## layers: cards for the silhouette, and a painted shadow on the skin beneath
## so the gaps read as more beard. Where to paint it is taken from the cards
## themselves (M_Combinations, which is all beard: it stops at the bottom of
## the eyes), not guessed: each head vertex is darkened by its distance to the
## nearest card vertex, full inside BEARD_SHADOW_NEAR, feathering out to
## nothing at BEARD_SHADOW_FAR -- reach enough to close the lip gap and join
## the moustache, soft enough that the edge feathers instead of stepping.
BEARD_SHADOW_COLOR = (30, 24, 21)
BEARD_SHADOW_NEAR = 0.004
BEARD_SHADOW_FAR = 0.014
BEARD_SHADOW_OPACITY = 0.72
## What is left of the shadow where the beard fades, up the sideburns.
BEARD_SHADOW_SIDES = 0.30
BEARD_SHADOW_SEED = 11
BEARD_LIP_Y = 1.646
BEARD_LIP_HALF_W = 0.028
BEARD_LIP_HALF_H = 0.0105


def _nearest_distance(points, cloud):
    """Distance from each of `points` to the nearest point of `cloud`."""
    import numpy as np
    near = np.empty(len(points))
    for i in range(0, len(points), 256):
        d = np.linalg.norm(points[i:i + 256, None, :] - cloud[None, :, :], axis=2)
        near[i:i + 256] = d.min(axis=1)
    return near


def _uv_field(size, uv, tris, weight):
    """Rasterises a per-vertex weight into a size x size texture-space field
    through the mesh's UVs, keeping the max where islands overlap."""
    import numpy as np
    field = np.zeros((size, size), dtype=np.float32)
    for tri in tris:
        w = weight[tri]
        if w.max() <= 0.0:
            continue
        p = uv[tri] * size
        x0, y0 = np.floor(p.min(axis=0)).astype(int)
        x1, y1 = np.ceil(p.max(axis=0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, size - 1), min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = p
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9:
            continue
        l0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
        l1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        l2 = 1.0 - l0 - l1
        inside = (l0 >= -0.01) & (l1 >= -0.01) & (l2 >= -0.01)
        val = l0 * w[0] + l1 * w[1] + l2 * w[2]
        region = field[y0:y1 + 1, x0:x1 + 1]
        region[inside] = np.maximum(region[inside], val[inside])
    return field


def paint_beard_shadow(model: pathlib.Path, target: pathlib.Path) -> None:
    import numpy as np
    head = _glb_attributes(model, "M_Head")
    cards = np.array(_glb_attributes(model, "M_Combinations")["POSITION"])
    pos = np.array(head["POSITION"])
    uv = np.array(head["TEXCOORD_0"])
    tris = np.array(head["INDICES"]).reshape(-1, 3)
    near = _nearest_distance(pos, cards)
    weight = np.clip(1.0 - (near - BEARD_SHADOW_NEAR)
                     / (BEARD_SHADOW_FAR - BEARD_SHADOW_NEAR), 0.0, 1.0)
    # Never above the cheekbone line or behind the ear.
    weight[pos[:, 1] > 1.700] = 0.0
    weight[pos[:, 2] < 0.0] = 0.0
    # And never on the lips: the moustache and chin cards sit right against
    # them, and a first render painted the mouth grey. An ellipse over the
    # mouth (teeth, tongue and mouth bag span y 1.61-1.67 and x +-0.035;
    # the lips are the middle of that), feathered at its edge.
    lip = np.sqrt((pos[:, 0] / BEARD_LIP_HALF_W) ** 2
                  + ((pos[:, 1] - BEARD_LIP_Y) / BEARD_LIP_HALF_H) ** 2)
    weight *= np.clip((lip - 1.0) / 0.35, 0.0, 1.0)
    # And thinned toward the ear, as the cards are (RomanModel.beard_fade --
    # same band, same numbers): full on the jaw and chin, lighter on the
    # sideburn, where the painted strands (paint_beard_strands) carry it.
    def smooth(a, b, x):
        t = np.clip((x - a) / (b - a), 0.0, 1.0)
        return t * t * (3.0 - 2.0 * t)
    fade = beard_side(pos)
    weight *= 1.0 - (1.0 - BEARD_SHADOW_SIDES) * fade
    albedo = Image.open(target).convert("RGB")
    size = albedo.size[0]
    field = _uv_field(size, uv, tris, weight)
    # Stubble grain, seeded: a beard shadow is not a flat fill.
    rng = np.random.default_rng(BEARD_SHADOW_SEED)
    grain = 0.78 + 0.22 * rng.random((size, size), dtype=np.float32)
    mask = Image.fromarray(np.clip(field * grain * BEARD_SHADOW_OPACITY * 255, 0, 255)
                           .astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(3))
    shadow = Image.new("RGB", albedo.size, BEARD_SHADOW_COLOR)
    Image.composite(shadow, albedo, mask).save(target, optimize=True)
    print(f"{'beard shadow':38} -> {target.name:34} {int((field > 0.05).sum())} texels")


## How far up the side of the face a point is, as the beard thins: 0 on
## the front of the face and along the jaw, 1 up the sideburn. By the angle
## round the vertical axis from straight ahead (0) to the ear (90 degrees), so
## the moustache and chin are never in it -- the first fade ran on HEIGHT as
## well, and took the moustache to half opacity because it sits high.
## RomanModel.beard_fade is the same function; keep the numbers together.
BEARD_SIDE_DEG = (35.0, 62.0)
## Only above the jaw line: the jaw's corners carry the full beard.
BEARD_SIDE_Y = (1.615, 1.655)


def beard_angle(pos):
    import numpy as np
    pos = np.asarray(pos)
    return np.degrees(np.arctan2(np.abs(pos[..., 0]), pos[..., 2]))


def beard_side(pos):
    import numpy as np
    pos = np.asarray(pos)

    def smooth(a, b, x):
        t = np.clip((x - a) / (b - a), 0.0, 1.0)
        return t * t * (3.0 - 2.0 * t)
    return smooth(*BEARD_SIDE_DEG, beard_angle(pos)) * smooth(*BEARD_SIDE_Y, pos[..., 1])


## The beard's coverage on the cheeks and sideburns, painted as hairs.
##
## Against the reference (gauntlet/refs/frames/roman_head_reference.jpg) his
## beard runs up the sides of his face as sideburns into his hair, under a
## clean, groomed cheek line that climbs from the corner of the moustache to
## the ear. Rendered head-on (hair_shot.tscn roman_face) ours stopped at the
## mouth: bare skin from the jaw to the hair in front of each ear, and a
## ragged top edge of card tips. The cards there are few and short -- they
## reach y 1.654 at the cheek -- so the coverage has to be painted, the way a
## game beard is a painted base with cards over it.
##
## Painted as hairs, not a fill: points are sampled on the head mesh's own
## triangles inside the beard (so their UVs are exact, wherever the islands
## lie), and each grows a short stroke down the face and a little forward --
## the way a beard grows -- carried into the texture by its triangle's own
## UV mapping. Under them, a soft base fill so it reads as beard and not as
## scratches once mip-filtered. The cheek line is BEARD_LINE, height as a
## function of the angle round the face (beard_angle); strokes thin out over
## BEARD_LINE_FEATHER above it, so the line is crisp but not cut. Behind
## BEARD_LINE's last angle, and in the ear itself, nothing.
## His beard is groomed and boxed (the owner's photos, Oct 2026): the mass is
## on the chin and along the jaw, the cheek line drops from the corner of the
## moustache back along the jaw, the cheeks above it are clear, and the
## sideburn is a narrow strip down the front of the ear into the hair. The
## first pass painted the whole cheek up to the cheekbone ("way too much").
## So the line falls from the moustache (11 deg) to the jaw (45 deg), and only
## the last few degrees before the ear climb to the scalp cap at 1.775.
BEARD_LINE = [(0.0, 1.664), (11.0, 1.664), (25.0, 1.648), (45.0, 1.635),
              (58.0, 1.640), (64.0, 1.765), (72.0, 1.775)]
BEARD_LINE_FEATHER = 0.003
## Bottom of the painted area: under the jaw the cards carry it.
BEARD_PAINT_FLOOR = 1.600
BEARD_STRAND_DENSITY = 1.1e6    # strands per square metre (110 per cm2)
BEARD_STRAND_LENGTH = (0.0035, 0.0060)
BEARD_STRAND_GROW = (0.0, -1.0, 0.3)
BEARD_STRAND_JITTER_DEG = 16.0
BEARD_STRAND_SEED = 19
## Low: the cards carry the mass; at 0.5 the painted cheeks read as a dark mask.
BEARD_FILL = 0.30
BEARD_STRAND_COLOR = (26, 20, 17)
BEARD_SUPERSAMPLE = 4


def beard_line(angle):
    import numpy as np
    a, y = zip(*BEARD_LINE)
    return np.interp(angle, a, y)


def beard_paint_weight(pos):
    """1 inside the beard below the cheek line, feathering to 0 over
    BEARD_LINE_FEATHER above it; 0 past the ear, below the floor, on the lips."""
    import numpy as np
    pos = np.asarray(pos)
    ang = beard_angle(pos)
    above = pos[..., 1] - beard_line(ang)
    w = np.clip(1.0 - above / BEARD_LINE_FEATHER, 0.0, 1.0)
    w = np.where(ang > BEARD_LINE[-1][0], 0.0, w)
    w = np.where(pos[..., 1] < BEARD_PAINT_FLOOR, 0.0, w)
    # Never in the ear (the scalp cap's ear box): its bowl faces forward,
    # inside the sideburn's angle, and the first render painted it.
    ear = ((np.abs(pos[..., 0]) > SCALP_CAP_EAR[0])
           & (pos[..., 1] > SCALP_CAP_EAR[1]) & (pos[..., 1] < SCALP_CAP_EAR[2])
           & (pos[..., 2] > SCALP_CAP_EAR[3]) & (pos[..., 2] < SCALP_CAP_EAR[4]))
    w = np.where(ear, 0.0, w)
    lip = np.sqrt((pos[..., 0] / BEARD_LIP_HALF_W) ** 2
                  + ((pos[..., 1] - BEARD_LIP_Y) / BEARD_LIP_HALF_H) ** 2)
    return w * np.clip((lip - 1.0) / 0.35, 0.0, 1.0)


def paint_beard_strands(model: pathlib.Path, target: pathlib.Path) -> None:
    import numpy as np
    head = _glb_attributes(model, "M_Head")
    pos = np.array(head["POSITION"])
    uv = np.array(head["TEXCOORD_0"])
    tris = np.array(head["INDICES"]).reshape(-1, 3)
    albedo = Image.open(target).convert("RGB")
    size = albedo.size[0]
    # The base fill, through the same rasteriser as the shadow and the cap.
    weight = beard_paint_weight(pos)
    fill = _uv_field(size, uv, tris, weight * BEARD_FILL)
    fill = Image.fromarray((fill * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(2))
    # The strands.
    ss = BEARD_SUPERSAMPLE
    strokes = Image.new("L", (size * ss, size * ss), 0)
    draw = ImageDraw.Draw(strokes)
    rng = np.random.default_rng(BEARD_STRAND_SEED)
    grow = np.array(BEARD_STRAND_GROW, dtype=float)
    grow /= np.linalg.norm(grow)
    count = 0
    for tri in tris:
        a, b, c = pos[tri]
        if weight[tri].max() <= 0.0:
            continue
        n = np.cross(b - a, c - a)
        area = 0.5 * np.linalg.norm(n)
        if area <= 0.0:
            continue
        n /= 2.0 * area
        expected = area * BEARD_STRAND_DENSITY
        k = int(expected) + (1 if rng.random() < expected - int(expected) else 0)
        if k == 0:
            continue
        # Solving for barycentrics in this triangle's plane.
        e1, e2 = b - a, c - a
        gram = np.array([[e1 @ e1, e1 @ e2], [e1 @ e2, e2 @ e2]])
        inv = np.linalg.inv(gram)
        ua, ub, uc = uv[tri]
        # Growth direction in the plane, then jittered about the normal.
        d = grow - (grow @ n) * n
        if np.linalg.norm(d) < 1e-6:
            continue
        d /= np.linalg.norm(d)
        side = np.cross(n, d)
        for _ in range(k):
            r1, r2 = rng.random(), rng.random()
            if r1 + r2 > 1.0:
                r1, r2 = 1.0 - r1, 1.0 - r2
            p = a + r1 * e1 + r2 * e2
            if rng.random() > float(beard_paint_weight(p)):
                continue
            ang = np.radians(rng.uniform(-BEARD_STRAND_JITTER_DEG, BEARD_STRAND_JITTER_DEG))
            q = p + (np.cos(ang) * d + np.sin(ang) * side) * rng.uniform(*BEARD_STRAND_LENGTH)
            s_, t_ = inv @ np.array([(q - a) @ e1, (q - a) @ e2])
            uq = ua + s_ * (ub - ua) + t_ * (uc - ua)
            up = ua + r1 * (ub - ua) + r2 * (uc - ua)
            draw.line([(up[0] * size * ss, up[1] * size * ss), (uq[0] * size * ss, uq[1] * size * ss)],
                      fill=int(rng.integers(170, 256)), width=max(1, round(1.5 * ss)))
            count += 1
    strokes = strokes.resize(albedo.size, Image.LANCZOS)
    mask = ImageChops.lighter(fill, strokes)
    beard = Image.new("RGB", albedo.size, BEARD_STRAND_COLOR)
    Image.composite(beard, albedo, mask).save(target, optimize=True)
    print(f"{'beard strands':38} -> {target.name:34} {count} strands")

## The scalp under the hair, painted into the head albedo.
##
## The same two-layer rule as the beard, applied to the head: a game head of
## hair is cards for the silhouette over a painted scalp cap, so wherever the
## cards part, the eye finds more hair and not skin. Roman had no cap. With
## his hair lifted off the scalp for volume (RomanModel.hair_lift) and the
## hanging lengths drawn out past the shoulders (hair_stretch), the gaps
## between cards widened, and on hair_shot.tscn tan skin showed through at
## the temples, over the ear and in a dotted patch behind it.
##
## Where to paint comes from the cards, as with the beard: each head vertex
## is darkened by its distance to the nearest card of the two visible hair
## meshes, measured in BIND space (before the runtime lift): full inside a
## reach, feathering to nothing SCALP_CAP_FEATHER further out. The reach is
## not one number because the cards are not one distance off the skin --
## measured, the median gap is 3 mm at the front hairline and 12 mm over the
## back of the head (90th percentile 7.5 mm and 16 mm). One reach either
## missed the back (the first render: tan blotches through a grey wash) or
## crept down the forehead. So the tight SCALP_CAP_REACH[0] holds only on
## the hairline itself -- the front of the head (SCALP_CAP_FRONT_Z) below
## the top of the forehead (SCALP_CAP_FRONT_Y) -- and [1] everywhere else,
## the crown included: a front-to-back blend left the top of the crown, whose
## cards also sit ~10 mm off, half-painted. The feather is the hairline: hair
## thins into the forehead, it does not stop on a line -- but over a few
## millimetres: in game, at 9 mm the dark paint thinned over skin read as a
## grey-blue band across the top of the forehead under the cool key. So the
## feather narrows to SCALP_CAP_FEATHER[0] on the hairline and stays
## [1] elsewhere, where it only blends cap into nape and sideburn.
##
## Never on the face: SCALP_CAP_FACE keeps it off everything in front of the
## ears below the hairline, where the beard shadow takes over. Never on the
## ears: the hanging cards pass within 2 cm of their backs, and the first
## render painted them dark. SCALP_CAP_EAR is the box they stick out of the
## skull in (|x| beyond the skull's 0.076 half-width above them), bounded in
## depth by the ear itself (measured z -0.005..0.026): without that bound the
## box took the skin BEHIND the ear too, left it tan, and the side strands
## that hang over it drew as a stipple of dark dots on skin.
SCALP_CAP_MESHES = ("M_Hair", "S_Hair")
SCALP_CAP_COLOR = (20, 16, 14)
SCALP_CAP_REACH = (0.006, 0.017)
SCALP_CAP_FRONT_Z = (0.03, 0.08)
SCALP_CAP_FRONT_Y = (1.79, 1.82)
SCALP_CAP_FEATHER = (0.003, 0.009)
SCALP_CAP_OPACITY = 0.97
SCALP_CAP_SEED = 13
## (z in front of, y below) which the cap is never painted.
SCALP_CAP_FACE = (0.065, 1.765)
## (|x| beyond, y from, y to, z from, z to)
SCALP_CAP_EAR = (0.077, 1.63, 1.77, -0.015, 0.034)
## The cap's surface, written as roman_reigns_head_rm.png: roughness in R
## (roughness_texture, multiplying a material roughness of 1.0 -- so
## HEAD_SKIN_ROUGHNESS must equal RomanModel.SKIN_ROUGHNESS["Material.001"],
## and a test holds them together) and the cap's coverage in G
## (metallic_texture, at a material metallic of 1.0).
##
## Painting the cap dark was half the fix. Where the hairline cards thin, the
## cap shows through them, and the head's skin material threw the cool key
## back off it as a grey-blue band across the top of the forehead: on tan
## skin that sheen is lost in the colour, on near-black it IS the colour.
## Rendered with the head's reflectance at zero the band went dark, as a mat
## of roots does. Roughness alone did not do it (rendered at 1.0, the band
## stayed): what lit it is the 4% reflectance every dielectric has, and
## BaseMaterial3D cannot map that. Metallic can -- a metal reflects its own
## albedo, and this albedo is near-black -- so under the cap the head is
## "metallic", rough, and reflects almost nothing. Only under the cap, so
## the face keeps its sheen.
HEAD_SKIN_ROUGHNESS = 0.58
SCALP_CAP_ROUGHNESS = 1.0
## Texels the painted field is grown past each UV island's edge before the
## blur, as a bake pads its islands. Without it the blur averages the island
## with the empty texels outside it, and every UV seam draws as a pale line --
## one ran down the middle of the crown in the first render.
SCALP_CAP_PAD = 4


def paint_scalp_cap(model: pathlib.Path, target: pathlib.Path,
                    surface: pathlib.Path) -> None:
    import numpy as np
    head = _glb_attributes(model, "M_Head")
    cards = np.vstack([np.array(_glb_attributes(model, m)["POSITION"])
                       for m in SCALP_CAP_MESHES])
    pos = np.array(head["POSITION"])
    uv = np.array(head["TEXCOORD_0"])
    tris = np.array(head["INDICES"]).reshape(-1, 3)
    near = _nearest_distance(pos, cards)
    def smooth(a, b, x):
        u = np.clip((x - a) / (b - a), 0.0, 1.0)
        return u * u * (3.0 - 2.0 * u)
    hairline = smooth(*SCALP_CAP_FRONT_Z, pos[:, 2]) * (1.0 - smooth(*SCALP_CAP_FRONT_Y, pos[:, 1]))
    reach = SCALP_CAP_REACH[1] + (SCALP_CAP_REACH[0] - SCALP_CAP_REACH[1]) * hairline
    feather = SCALP_CAP_FEATHER[1] + (SCALP_CAP_FEATHER[0] - SCALP_CAP_FEATHER[1]) * hairline
    t = np.clip(1.0 - (near - reach) / feather, 0.0, 1.0)
    weight = t * t * (3.0 - 2.0 * t)
    weight[(pos[:, 2] > SCALP_CAP_FACE[0]) & (pos[:, 1] < SCALP_CAP_FACE[1])] = 0.0
    ear = ((np.abs(pos[:, 0]) > SCALP_CAP_EAR[0])
           & (pos[:, 1] > SCALP_CAP_EAR[1]) & (pos[:, 1] < SCALP_CAP_EAR[2])
           & (pos[:, 2] > SCALP_CAP_EAR[3]) & (pos[:, 2] < SCALP_CAP_EAR[4]))
    weight[ear] = 0.0
    albedo = Image.open(target).convert("RGB")
    size = albedo.size[0]
    field = _uv_field(size, uv, tris, weight)
    covered = field > 0.0
    padded = np.array(Image.fromarray((field * 255).astype(np.uint8), "L")
                      .filter(ImageFilter.MaxFilter(2 * SCALP_CAP_PAD + 1)),
                      dtype=np.float32) / 255.0
    field = np.where(covered, field, padded)
    # Grain, seeded, so the cap reads as dense short roots rather than paint.
    rng = np.random.default_rng(SCALP_CAP_SEED)
    grain = 0.80 + 0.20 * rng.random((size, size), dtype=np.float32)
    mask = Image.fromarray(np.clip(field * grain * SCALP_CAP_OPACITY * 255, 0, 255)
                           .astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(2))
    cap = Image.new("RGB", albedo.size, SCALP_CAP_COLOR)
    Image.composite(cap, albedo, mask).save(target, optimize=True)
    print(f"{'scalp cap':38} -> {target.name:34} {int((field > 0.05).sum())} texels")
    cover = np.asarray(mask, dtype=np.float32) / 255.0
    rough = HEAD_SKIN_ROUGHNESS + (SCALP_CAP_ROUGHNESS - HEAD_SKIN_ROUGHNESS) * cover
    if _lip_field is not None:
        lip = np.asarray(Image.fromarray((_lip_field * 255).astype(np.uint8), "L")
                         .filter(ImageFilter.GaussianBlur(4)), dtype=np.float32) / 255.0
        rough = np.maximum(rough, HEAD_SKIN_ROUGHNESS + (LIP_ROUGHNESS - HEAD_SKIN_ROUGHNESS) * lip)
    channels = [np.round(rough * 255), np.round(cover * 255), np.zeros_like(cover)]
    Image.merge("RGB", [Image.fromarray(c.astype(np.uint8), "L") for c in channels]) \
        .save(surface, optimize=True)
    print(f"{'scalp cap roughness/metallic':38} -> {surface.name:34}")


## A wave in the hair (character_aaa_plan.md R1), as two normal maps.
##
## The hanging lengths fell as flat, straight sheets: on hair_shot.tscn's back
## shot one smooth highlight ran down the whole length. His hair in 2K26 hangs
## in loose waves, and what makes a wave read under a key light is the
## highlight breaking into bands down the length -- the surface normal tilting
## back and forth along the strand.
##
## The wave cannot live in the hair atlases. Only the hanging lengths wave --
## a slicked crown does not -- and measured, 30% of M_Hair's atlas is shared
## by crown cards and hanging cards (the same strand strips reused), so any
## wave painted there ripples the crown too. So it is a DETAIL normal on UV2,
## and RomanModel._volumize_hair writes UV2 from where each hair vertex sits
## in bind space: u2 the angle round the head (0.5 at the back, so the seam
## is at the face, where nothing hangs), v2 the height down from
## HAIR_WAVE_Y[1]. The map below is a function of that height and angle,
## exactly: full wave below HAIR_WAVE_HANG_Y[0], none above [1], whatever
## atlas texel the card samples.
##
## Its phase drifts round the head (hair_wave_phase), so neighbouring clumps
## wave out of step -- one phase everywhere lays every card's bands level, a
## corrugated sheet. The same formula is in RomanModel.hair_wave_phase, which
## bends the hanging cards' geometry on the same wave, so the bands of light
## sit on the bends of the silhouette.
##
## Godot mixes the detail normal into the base normal by the detail albedo's
## alpha (RomanModel.HAIR_WAVE_MIX, 0.5), so both maps are written at
## 1 / mix of their slope.
HAIR_WAVE_MAP = "roman_reigns_hair_wave_nrm.png"
HAIR_WAVE_SIZE = (512, 1024)
## v2 spans this bind-space height, top to bottom: the hair's whole height
## after RomanModel.hair_stretch (cards end ~1.17).
HAIR_WAVE_Y = (1.08, 1.86)
## 0.78 m / 0.052 m = 15 whole waves, so the map tiles if it ever repeats.
## 5 cm: his hair hangs in wet ringlets, tighter than a loose wave (the
## owner's photos, Oct 2026); 6.5 cm read as a gentle swell.
HAIR_WAVE_LENGTH = 0.052
HAIR_WAVE_AMP = 0.0075
HAIR_WAVE_HANG_Y = (1.60, 1.68)
HAIR_WAVE_MIX = 0.5


def hair_wave_phase(u2):
    """Phase (in waves) of the hair wave at u2 round the head. A fixed sum of
    sines rather than seeded noise, so RomanModel can compute the same value
    for the geometry: smooth, and out of step every few centimetres."""
    import numpy as np
    t = 2.0 * np.pi * np.asarray(u2)
    return (0.50 * np.sin(7.0 * t) + 0.30 * np.sin(13.0 * t + 1.3)
            + 0.20 * np.sin(23.0 * t + 2.1))


def build_wave_normal(target: pathlib.Path) -> None:
    import numpy as np
    w, h = HAIR_WAVE_SIZE
    u2 = (np.arange(w) + 0.5) / w
    v2 = (np.arange(h) + 0.5) / h
    uu, vv = np.meshgrid(u2, v2)
    y = HAIR_WAVE_Y[1] - vv * (HAIR_WAVE_Y[1] - HAIR_WAVE_Y[0])
    t = np.clip((HAIR_WAVE_HANG_Y[1] - y) / (HAIR_WAVE_HANG_Y[1] - HAIR_WAVE_HANG_Y[0]), 0.0, 1.0)
    weight = t * t * (3.0 - 2.0 * t)
    angle = 2.0 * np.pi * ((HAIR_WAVE_Y[1] - y) / HAIR_WAVE_LENGTH + hair_wave_phase(uu))
    # Slope of the height along the strand, metres per metre.
    slope = weight * HAIR_WAVE_AMP * 2.0 * np.pi / HAIR_WAVE_LENGTH * np.cos(angle) / HAIR_WAVE_MIX
    n = np.stack([np.zeros_like(slope), -slope, np.ones_like(slope)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    Image.fromarray(np.round((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB") \
        .save(target, optimize=True)
    print(f"{'hair wave':38} -> {target.name:34}")


## The strands, as the base normal map of each hair atlas: a tilt across the
## strands that changes strand to strand, so the highlight breaks into
## strands instead of lying on a card as one sheen. Constant along the strand
## (v), so the map is a strip HAIR_STRAND_ROWS tall that repeats down the
## atlas. Strand width is set in metres and converted per atlas, whose u
## spans different widths of hair (measured off the card edges: M_Hair
## 0.313 m per unit, S_Hair 0.064).
HAIR_STRAND_MAPS = {
    "roman_reigns_hair_strands_nrm.png": 0.313,
    "roman_reigns_hair_4_strands_nrm.png": 0.064,
}
HAIR_STRAND_WIDTH = 0.0012
HAIR_STRAND_SLOPE = 0.14
HAIR_STRAND_SIZE = (1024, 8)
HAIR_STRAND_SEED = 17


def build_strand_normal(target: pathlib.Path, metres_per_u: float) -> None:
    import numpy as np
    w, h = HAIR_STRAND_SIZE
    rng = np.random.default_rng(HAIR_STRAND_SEED)
    u = (np.arange(w) + 0.5) / w
    step = HAIR_STRAND_WIDTH / metres_per_u
    knots = np.arange(0.0, 1.0 + step, step)
    values = rng.uniform(-1.0, 1.0, len(knots))
    values[-1] = values[0]   # wraps across u = 1
    slope = np.interp(u, knots, values) * HAIR_STRAND_SLOPE / HAIR_WAVE_MIX
    n = np.stack([-slope, np.zeros_like(slope), np.ones_like(slope)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    row = np.round((n * 0.5 + 0.5) * 255).astype(np.uint8)
    Image.fromarray(np.repeat(row[None, :, :], h, axis=0), "RGB").save(target, optimize=True)
    print(f"{'hair strands':38} -> {target.name:34} {len(knots) - 1} strands across")

def main() -> int:
    if not CHARACTERS.is_dir():
        sys.exit(f"not found: {CHARACTERS}")
    for source_name, (target_name, gamma, dilate, weave) in SOURCES.items():
        source = CHARACTERS / source_name
        if not source.exists():
            sys.exit(f"missing source texture: {source}")
        build(source, CHARACTERS / target_name, gamma, dilate, weave)
    build_head(
        CHARACTERS / "roman_reigns_body_color.png",
        CHARACTERS / "roman_reigns_Image.png",
        CHARACTERS / "roman_reigns_head_color.png",
    )
    paint_skin(CHARACTERS / "roman_reigns.glb", CHARACTERS / "roman_reigns_head_color.png")
    paint_brows(CHARACTERS / "roman_reigns.glb", CHARACTERS / "roman_reigns_head_color.png")
    paint_beard_shadow(CHARACTERS / "roman_reigns.glb", CHARACTERS / "roman_reigns_head_color.png")
    paint_beard_strands(CHARACTERS / "roman_reigns.glb", CHARACTERS / "roman_reigns_head_color.png")
    paint_scalp_cap(CHARACTERS / "roman_reigns.glb", CHARACTERS / "roman_reigns_head_color.png",
                    CHARACTERS / "roman_reigns_head_rm.png")
    build_wave_normal(CHARACTERS / HAIR_WAVE_MAP)
    for target_name, metres_per_u in HAIR_STRAND_MAPS.items():
        build_strand_normal(CHARACTERS / target_name, metres_per_u)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
