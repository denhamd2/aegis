#!/usr/bin/env python3
"""Kenny Omega's skin and gear textures, on Cody's model.

Kenny is built on Cody's model (KennyModel extends CodyModel): the owner,
27 Oct, "use Cody's body for Kenny and adjust it to Kenny, e.g. skin shade,
no Cody tattoos". Same mesh, same UVs, so each of Cody's texture atlases is
rewritten here as Kenny's and KennyModel swaps them in at load time.

HEAD (kenny_head.png). Three sources:
* Cody's head texture: the skin's fine detail -- pores, creases, the lids --
  which the photo cannot give: its face is ~245 px across, Cody's ~1000.
* kenny_face_projected.png (tools/blender/kenny_face_projection.py): the
  owner's sheet's front head shot written into this texture space. Its LOW
  frequencies are the likeness -- the flush, the brows, the nose, the beard
  -- and replace Cody's under its weight (frequency separation: the photo
  below FACE_SIGMA texels, Cody above).
* Procedural beard: his short auburn beard, over the photo and Cody's skin
  alike, placed by where each texel sits on the head (beard_masks) so it runs
  along the jaw into the sideburns as the sheet's does.
Then: the lids stay Cody's (the photo's eyes, painted onto lids of another
shape, read as smudges); the skull-and-flag tattoo on the neck is replaced by
the same patch of the other side of his neck, mirrored; the painted hair on
the scalp, under his curls, is recoloured to Kenny's dirty-blond roots; and
all the skin is retinted to Kenny's tone (SKIN_GAIN).

BODY. Each skin atlas retinted the same way; "Dream" on the chest and the
mark on the right ring finger replaced by mirrored or neighbouring skin.

Run:  python3 tools/assets/build_kenny_textures.py
Deterministic: same inputs, byte-identical outputs.
"""
from __future__ import annotations

import importlib.util
import math
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPO = pathlib.Path(__file__).resolve().parents[2]
CHARACTERS = REPO / "game/assets/characters"
_spec = importlib.util.spec_from_file_location(
    "cody_tex", REPO / "tools/assets/build_cody_textures.py")
cody_tex = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cody_tex)

HEAD_SOURCE = CHARACTERS / "cody_rhodes_ximage_d17c32323759dea.png"
PROJECTED = CHARACTERS / "kenny_face_projected.png"
HEAD_OUT = CHARACTERS / "kenny_head.png"

## Kenny's skin against Cody's, as a gain on Cody's albedo. The sheet's
## medians -- chest (193,107,98), arm (182,104,85), cheek (199,106,92) -- are
## a photograph under arena light, not an albedo: the first pass matched them
## and rendered a brick-red face (forehead (170,65,52), red over green 2.6
## against the sheet's 1.9), since the game's warm keys and tonemap carry an
## albedo's red further. The second went too far the other way: a cool, lilac
## pink (156,101,97). So the albedo is the one that RENDERS near the sheet:
## brighter than Cody's tan and as warm, red over green ~1.5 with KennyModel's
## tint, the rest of the flush left to the lights.
SKIN_GAIN = np.array([1.20, 1.21, 1.18])
## His face a shade redder than the body's tone, over the photo's area: the
## sheet's face is flushed red all over under arena light (forehead G/R 0.65
## there). Green only -- adding blue went lilac (pass 2).
FACE_HUE = np.array([1.0, 0.96, 1.0])
## The photo's detail below this many texels replaces Cody's.
FACE_SIGMA = 3.0
## Its edge feathered over this many texels, inside its coverage.
FACE_FEATHER = 24
## The photo's colour level moved this far toward the retinted skin round it:
## all the way, so the projection carries its own variation -- the flush round
## the nose and cheeks, the beard, the brows -- on Kenny's skin tone and not
## the photograph's red, and fades into the cheeks without a seam.
FACE_LEVEL_MATCH = 1.0
## Highlights baked into the photo (the wet forehead, the nose under the
## lights) compressed above this luminance: the game lights them itself.
HIGHLIGHT_KNEE = 0.55

## Masks in texture fractions (x right, y down).
## Cody's lid openings: the lids stay his.
EYES = [(0.386, 0.342, 0.050, 0.022), (0.610, 0.342, 0.050, 0.022)]
## The beard, placed on the head itself and not on the atlas: each texel's
## bind-pose point (gear_points) against his face's landmarks. A polygon
## drawn on the atlas stopped in a straight edge mid-cheek, short of the ear,
## and the owner saw it ("the beard on the side of his face doesn't look
## right"): the sheet's beard runs along the whole jaw into the sideburns.
## Angles are round the head's vertical axis (at z HEAD_AXIS_Z) from the front,
## either side; heights in metres, bind pose.
HEAD_AXIS_Z = -0.09
## The cheek line: under the nose at the front, rising to the sideburns.
BEARD_TOP = [(0.0, 1.661), (20.0, 1.665), (35.0, 1.675), (55.0, 1.69), (70.0, 1.70),
             (82.0, 1.725), (95.0, 1.73)]
## The neckline: low under the chin, up to the jaw's underside at the sides.
BEARD_FLOOR = [(0.0, 1.565), (40.0, 1.575), (70.0, 1.59), (95.0, 1.60)]
## How far round it reaches, by height: in front of the ear above the jaw's
## corner, round under the ear below it.
BEARD_REACH = [(1.64, 102.0), (1.665, 96.0), (1.68, 90.0), (1.75, 90.0)]
BEARD_FEATHER = 0.008
## Down the neck it thins out over this far, as a neckline grows.
BEARD_NECK_FADE = 0.016
## His colour: the sheet's face is flushed, his cheeks and nose redder than
## his forehead (cheek over forehead 0.85, 0.69, 0.65 in its arena photo). A
## flush on the cheeks and the nose, placed on the head like the beard:
## [centre (x from the midline, m), radii, mirrored]. Under the beard.
FLUSH = [((0.045, 1.680, -0.010), (0.028, 0.026, 0.040), True),
         ((0.0, 1.680, 0.015), (0.014, 0.020, 0.030), False)]
FLUSH_SHADE = np.array([1.0, 0.85, 0.83])
## Cody's nostrils are painted near black (luminance 16): on him they read as
## two holes under a short tip. The sheet's are in shadow, not black. Texels
## darker than NOSTRIL_BELOW round the nose base are lifted toward a dark
## warm brown. [centre (x from the midline), radii], m.
NOSTRILS = ((0.0, 1.663, 0.010), (0.022, 0.009, 0.016))
NOSTRIL_BELOW = 70.0
NOSTRIL_FLOOR = np.array([78.0, 42.0, 34.0])
HEAD_MIDLINE_X = 0.004
## The mouth's own islands sit at the atlas's top corners: nothing above this.
BEARD_ATLAS_TOP = 0.15
LIPS = (0.500, 0.581, 0.090, 0.031)
## His brows: the atlas's are Cody's, dark brown strokes at about half the
## skin's level. The sheet's are sandy ginger, at about 0.7 of the skin round
## them and redder (brow over brow-skin, measured: 0.74, 0.69, 0.62). Each brow
## hair is taken to that colour by how dark it is against the skin beside it.
BROWS = [(0.398, 0.305, 0.074, 0.028), (0.594, 0.305, 0.074, 0.028)]
BROW_SHADE = np.array([0.80, 0.66, 0.54])
## Colour, measured on the sheet's neutral head: his chin sits at 0.72 of his
## cheek's level and redder, the jaw darker still. Short auburn hairs, about a
## fifth of them ginger-blond, over skin they shade.
BEARD_DARK = np.array([118.0, 64.0, 44.0])
BEARD_LIGHT = np.array([184.0, 128.0, 82.0])
BEARD_BLOND = 0.22
## Hair cover: densest on the chin, jaw and under it, thinner up the cheeks.
BEARD_DENSITY = 0.62
BEARD_CHEEK = 0.42
## The skin the beard grows from, shaded by it: the sheet's chin over its
## cheek, channel by channel.
BEARD_SHADE = np.array([0.74, 0.65, 0.66])
BEARD_WASH = 0.38
BEARD_STRAND = 0.7
## Cody's neck tattoo (head atlas): replaced by the mirror image of the same
## patch on the other side of the neck.
NECK_TATTOO = [(0.130, 0.625), (0.240, 0.615), (0.420, 0.790), (0.420, 0.835),
               (0.330, 0.990), (0.200, 0.990), (0.130, 0.860)]
## Kenny's hair over the scalp's painted crop: his dark roots, all of it. Where
## the crop shows below the curls' cap, at the forehead, a blond crop read as
## a pale band across the hairline (Cody's does the same under his groom).
SCALP_BLOND = np.array([112.0, 90.0, 62.0])
SCALP_ROOT = np.array([84.0, 66.0, 44.0])
## The fringe of Cody's crop below that region: this many texels of it, filled
## from the forehead this many texels further down (the face island is upright).
FRINGE_GROW = 88
FRINGE_FROM = 120
## His hairline: (degrees round the head from the front, height in m, bind
## pose). Cody's scalp runs flat across the forehead at 1.787 m out to 50
## degrees and drops square at the temples -- a helmet. The sheet's is a soft
## M: a little higher at the centre, receded at the temple corners, curving
## down to the sideburns. Read off the sheet by the distance between the
## pupils it came out at +1 cm centre, +2.5 cm temples, and on the head that
## bared him to the crown (kenny_face_judge.md, run 3): this near the top of
## the skull a centimetre of height is a lot of scalp, and the photo's head
## tilt cannot be told from its hairline. Hence half that, the corners rounded.
## The curls (tools/blender/kenny_curls.py) read this table too, so scalp and
## hair agree.
HAIRLINE = [(0.0, 1.792), (15.0, 1.794), (28.0, 1.799), (40.0, 1.801), (50.0, 1.790),
            (58.0, 1.765), (66.0, 1.745), (75.0, 1.731), (85.0, 1.725), (100.0, 1.70)]
## Behind this the hairline is Cody's.
HAIRLINE_REACH = 100.0
## The skin for the bared temples: its pores from this many texels further
## down the forehead (the face island is upright), its tone from round about
## -- cloned whole, the forehead's creases showed twice.
RECEDE_FROM = 150
RECEDE_TONE = 20.0
RECEDE_PORES = 3.0

## Body atlases (Cody's) -> Kenny's. Tattoos: [(atlas, polygon)].
BODY = {
    "cody_rhodes_ximage_f862503283dc0b8.png": "kenny_body_abdomen.png",
    "cody_rhodes_ximage_d527779c45f15f2.png": "kenny_body_arm_r.png",
    "cody_rhodes_ximage_359c096926a07e8.png": "kenny_body_arm_l.png",
    "cody_rhodes_ximage_e0ec4a43013e474.png": "kenny_body_chest.png",
}
## "Dream", over his left pec (chest atlas): mirrored from the right.
DREAM = [(0.525, 0.270), (0.640, 0.250), (0.655, 0.480), (0.540, 0.500)]
## The mark on the right ring finger (right arm atlas): skin from beside it.
RING = [(0.455, 0.120), (0.555, 0.120), (0.555, 0.155), (0.455, 0.155)]
RING_SHIFT = (-0.115, 0.0)

## GEAR. Cody's gear is navy and red-white-blue; Kenny's (the sheet's PANTS,
## BOOT and WRIST TAPE panels) is white tights with gold-and-black panels down
## the outer thighs, black-and-gold kneepads, tall black boots with gold
## panels, a black-and-gold belt and white tape. The meshes match: Cody's
## tights run from the waist to 0.29 m, his boots below. So each gear atlas
## is painted afresh from where its texels sit on the body (gear_points: the
## bind-pose point each texel lands on), and Kenny's tall boot tops, which
## reach to 0.44 m, are painted onto the tights' shins.
GLB = CHARACTERS / "cody_rhodes.glb"
## material: (output, size).
GEAR = {
    "xmaterial_e531cd813705b95": ("kenny_gear_tights.png", (2048, 2048)),
    "xmaterial_c7ae1bc9f4b14": ("kenny_gear_belt.png", (2048, 512)),
    "xmaterial_6d1e7e57b971093": ("kenny_gear_boot_r.png", (1024, 1024)),
    "xmaterial_6d205e57b97438d": ("kenny_gear_boot_l.png", (1024, 1024)),
}
WRIST_SOURCE = "cody_rhodes_ximage_af3f303435d7457.png"
WRIST_OUT = "kenny_gear_wrist.png"
TIGHTS_WHITE = np.array([236.0, 233.0, 224.0])
## The marbled grey in the sheet's white tights.
TIGHTS_MARBLE = np.array([196.0, 192.0, 184.0])
GOLD = np.array([206.0, 168.0, 84.0])
GOLD_DARK = np.array([150.0, 112.0, 46.0])
BLACK = np.array([26.0, 24.0, 24.0])
TAPE = np.array([240.0, 238.0, 232.0])
## Heights (m, bind pose): the kneepad band and the boot tops on the shin.
KNEEPAD = (0.44, 0.61)
BOOT_TOP = 0.44
## The outer-thigh panel: from the hip to the kneepad, round the outside of
## the thigh (degrees from the front, + outward), its edges scalloped.
THIGH_PANEL = (0.61, 1.03, 38.0, 128.0)
## A gold stripe down the outer back of each thigh.
BACK_STRIPE = (0.61, 1.0, 150.0)
## On the boots: a gold panel down the front of the shaft and one down the
## outside.
BOOT_PANELS = ((0.0, 22.0), (90.0, 16.0))
BOOT_FOOT = 0.13
GEAR_SEED = 2710


def load(path, mode="RGB"):
    return np.asarray(Image.open(path).convert(mode)).astype(np.float32)


def save(rgb, path, alpha=None):
    out = np.clip(np.round(rgb), 0, 255).astype(np.uint8)
    if alpha is not None:
        out = np.dstack([out, alpha])
        Image.fromarray(out, "RGBA").save(path, optimize=True)
    else:
        Image.fromarray(out, "RGB").save(path, optimize=True)
    print("wrote", path.name)


def blur(a, sigma):
    """Gaussian blur of a float image: separable, edges clamped."""
    if a.ndim == 2:
        return blur(a[..., None], sigma)[..., 0]
    r = max(1, int(3 * sigma + 0.5))
    x = np.arange(-r, r + 1, dtype=np.float32)
    k = np.exp(-0.5 * (x / sigma) ** 2)
    k /= k.sum()
    out = a.astype(np.float32)
    for axis in (0, 1):
        pad = [(0, 0)] * out.ndim
        pad[axis] = (r, r)
        padded = np.pad(out, pad, mode="edge")
        acc = np.zeros_like(out)
        n = out.shape[axis]
        for i, wgt in enumerate(k):
            acc += wgt * np.take(padded, np.arange(i, i + n), axis=axis)
        out = acc
    return out


def polygon_mask(w, h, poly, feather):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).polygon([(x * w, y * h) for x, y in poly], fill=255)
    if feather > 0:
        m = m.filter(ImageFilter.GaussianBlur(feather))
    return np.asarray(m, np.float32) / 255.0


def ellipse_mask(w, h, e, feather):
    cx, cy, rx, ry = e
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).ellipse(((cx - rx) * w, (cy - ry) * h, (cx + rx) * w, (cy + ry) * h), fill=255)
    if feather > 0:
        m = m.filter(ImageFilter.GaussianBlur(feather))
    return np.asarray(m, np.float32) / 255.0


def mirrored_fill(rgb, mask):
    """`rgb` with the masked texels replaced by the texture's mirror image
    across its vertical centre line (the other side of a symmetric island)."""
    mirror = rgb[:, ::-1]
    return rgb * (1 - mask[..., None]) + mirror * mask[..., None]


def hair_masks(w, h):
    """Cody's painted-hair region (build_cody_textures' outline)."""
    def hair_mask(skin):
        mask = Image.new("L", (w, h), 0)
        draw = ImageDraw.Draw(mask)
        draw.rectangle((0, 0, w, int(cody_tex.HAIR_BOTTOM * h)), fill=255)
        draw.polygon([(x * w, y * h) for x, y in skin], fill=0)
        for x0, y0, x1, y1 in cody_tex.CORNERS:
            draw.rectangle((x0 * w, y0 * h, x1 * w, y1 * h), fill=0)
        return np.asarray(mask).astype(np.float32) / 255.0
    sure = hair_mask(cody_tex.SKIN)
    m = np.asarray(Image.fromarray(np.round(sure * 255).astype(np.uint8))
                   .filter(ImageFilter.GaussianBlur(w / 512.0)), np.float32) / 255.0
    return m


HEAD_MATERIAL = "xmaterial_c3d4d9e78b44a79"


def hairline_at(theta):
    """His hairline's height (m) at `theta` degrees round from the front."""
    return np.interp(theta, [r[0] for r in HAIRLINE], [r[1] for r in HAIRLINE])


def head_points(w, h):
    """Each head-atlas texel's bind-pose point and the angle (degrees, either
    side) round the head's vertical axis from the front."""
    pts, uvs, tris = glb_mesh()[HEAD_MATERIAL]
    point, cover = gear_points(pts, uvs, tris, (w, h))
    theta = np.degrees(np.abs(np.arctan2(point[..., 0], point[..., 2] - HEAD_AXIS_Z)))
    return point, cover, theta


def beard_masks(point, cover, theta):
    """(beard, cheek): where his beard grows on the head atlas, from each
    texel's point on the head, and how near it is to the cheek line (1 at the
    line, where it thins, 0 in the beard's body)."""
    h, w = cover.shape
    y = point[..., 1]

    def table(at, rows):
        return np.interp(at, [r[0] for r in rows], [r[1] for r in rows])

    top = table(theta, BEARD_TOP)
    floor = table(theta, BEARD_FLOOR)
    reach = table(y, BEARD_REACH)
    # A tighter edge under the nose: the moustache is only two centimetres
    # deep and a full feather left it half bare.
    f = BEARD_FEATHER * table(theta, [(0.0, 0.5), (30.0, 1.0)])
    beard = (smoothstep(floor - BEARD_NECK_FADE, floor + f, y) * (1 - smoothstep(top - f, top + f, y))
             * (1 - smoothstep(reach - 4.0, reach + 4.0, theta)) * cover)
    beard[: int(BEARD_ATLAS_TOP * h)] = 0.0
    # Thinning toward the cheek line, but not on the moustache: it is only
    # two centimetres deep, and the sheet's is as dense as his chin.
    cheek = smoothstep(top - 0.03, top, y) * smoothstep(15.0, 30.0, theta)
    return beard.astype(np.float32), cheek.astype(np.float32)


def head() -> None:
    src = Image.open(HEAD_SOURCE).convert("RGBA")
    w, h = src.size
    alpha = np.asarray(src)[..., 3]
    cody = load(HEAD_SOURCE)
    hair = hair_masks(w, h)
    skin = cody * SKIN_GAIN
    point, cover, theta = head_points(w, h)

    # The tattoo first, so nothing below inherits it.
    tattoo = polygon_mask(w, h, NECK_TATTOO, 6)
    skin = mirrored_fill(skin, tattoo)
    # Cody's painted crop runs a short, spiky fringe down onto the forehead,
    # below the hair region the cap covers: on Kenny it read as a pale band
    # across his hairline. It becomes the forehead skin from just below it.
    grown = Image.fromarray((hair > 0.5).astype(np.uint8) * 255)
    for _ in range(FRINGE_GROW // 4):
        grown = grown.filter(ImageFilter.MaxFilter(9))  # 4 texels a pass
    fringe = np.clip(np.asarray(grown.filter(ImageFilter.GaussianBlur(6)), np.float32) / 255.0
                     - hair, 0.0, 1.0)
    skin = skin * (1 - fringe[..., None]) + np.roll(skin, -FRINGE_FROM, 0) * fringe[..., None]
    # His receding temples: Cody's painted scalp below Kenny's hairline becomes
    # forehead, cloned from further down it, and is no longer hair.
    line = hairline_at(theta)
    bared = (hair * (1 - smoothstep(line - 0.004, line + 0.002, point[..., 1]))
             * (1 - smoothstep(HAIRLINE_REACH - 5.0, HAIRLINE_REACH, theta)) * cover)
    below = np.roll(skin, -RECEDE_FROM, 0)
    bare = blur(below, RECEDE_TONE) + (below - blur(below, RECEDE_PORES))
    skin = skin * (1 - bared[..., None]) + bare * bared[..., None]
    hair = hair * (1 - bared)

    proj = load(PROJECTED, "RGBA")
    k = proj[..., :3]
    a = proj[..., 3] / 255.0
    eyes = np.zeros((h, w), np.float32)
    for e in EYES:
        eyes = np.maximum(eyes, ellipse_mask(w, h, e, 10))
    a = a * (1 - eyes) * (1 - hair)
    # A wide feather, inside the photo's own edge: at a few texels its
    # boundary drew a flat-toned rectangle on his forehead.
    inner = Image.fromarray(np.round(a * 255).astype(np.uint8))
    for _ in range(FACE_FEATHER // 4):
        inner = inner.filter(ImageFilter.MinFilter(9))
    a = np.minimum(a, blur(np.asarray(inner, np.float32) / 255.0, FACE_FEATHER * 0.6))
    # The photo's level toward the skin it lands on.
    sel = a > 0.6
    lvl_k = np.median(k[sel], 0)
    lvl_c = np.median(blur(skin, FACE_SIGMA)[sel], 0)
    k = k * (lvl_c / lvl_k) ** FACE_LEVEL_MATCH
    # Highlights become his skin at the knee's brightness, hue and all:
    # scaled down instead, the near-white shine went grey-blue.
    lum = k.mean(2, keepdims=True) / 255.0
    med = np.median(k[sel], 0)
    flat = med * (HIGHLIGHT_KNEE / max(float(med.mean()) / 255.0, 1e-3))
    t = np.clip((lum - HIGHLIGHT_KNEE) / 0.12, 0, 1)
    k = k * (1 - t) + flat * t
    face = blur(k, FACE_SIGMA) + (skin - blur(skin, FACE_SIGMA)) * 0.9
    out = skin * (1 - a[..., None]) + face * a[..., None]
    out = out * (1 - a[..., None]) + out * FACE_HUE * a[..., None]

    # His flush, cheeks and nose.
    flush = np.zeros((h, w), np.float32)
    for centre, radii, mirrored in FLUSH:
        for side in ((1.0, -1.0) if mirrored else (1.0,)):
            c = np.array([HEAD_MIDLINE_X + centre[0] * side, centre[1], centre[2]])
            q = np.linalg.norm((point - c) / np.array(radii), axis=-1)
            flush = np.maximum(flush, smoothstep(0.0, 1.0, 1.0 - q))
    flush *= cover
    out = out * (1 - flush[..., None]) + out * FLUSH_SHADE * flush[..., None]
    # His nostrils in shadow, not black.
    c = np.array([HEAD_MIDLINE_X + NOSTRILS[0][0], NOSTRILS[0][1], NOSTRILS[0][2]])
    near = smoothstep(0.0, 0.3, 1.0 - np.linalg.norm((point - c) / np.array(NOSTRILS[1]), axis=-1))
    lift = near * np.clip((NOSTRIL_BELOW - out.mean(-1)) / 50.0, 0.0, 1.0) * 0.7 * cover
    out = out * (1 - lift[..., None]) + NOSTRIL_FLOOR * lift[..., None]

    # The beard, over the photo and Cody's skin alike: drawn only where the
    # photo reached, it ended in a seam where the projection faded out.
    beard, cheek = beard_masks(point, cover, theta)
    beard *= 1 - ellipse_mask(w, h, LIPS, 6)
    rng = np.random.default_rng(271026)
    # Short strokes growing downward: noise stretched along the texture's
    # vertical, which on the face island is down the face.
    noise = rng.random((h, w)).astype(np.float32)
    noise = blur(noise, 0.7)
    noise = np.mean([np.roll(noise, d, 0) for d in range(-6, 7)], 0)
    noise = (noise - noise.mean()) / noise.std()
    # Patchy, as a real beard is: cover drifts over a couple of centimetres.
    patch = blur(rng.random((h, w)).astype(np.float32), 24)
    patch = (patch - patch.mean()) / patch.std()
    cover = beard * np.clip(BEARD_DENSITY * (1 - cheek) + BEARD_CHEEK * cheek + 0.08 * patch, 0, 1)
    # A strand where the noise clears the quantile the local cover asks for.
    order = np.clip((noise * 0.5 + 0.5), 0, 1)
    strand = np.clip((order - (1 - cover)) * 6, 0, 1)
    tone = blur(rng.random((h, w)).astype(np.float32), 1.2)
    blond = (tone > np.quantile(tone, 1 - BEARD_BLOND)).astype(np.float32)
    hair_colour = BEARD_DARK * (1 - blond[..., None]) + BEARD_LIGHT * blond[..., None]
    wash = beard * BEARD_WASH
    out = out * (1 - wash[..., None]) + out * BEARD_SHADE * wash[..., None]
    out = out * (1 - (strand * BEARD_STRAND)[..., None]) + hair_colour * (strand * BEARD_STRAND)[..., None]

    # His brows, sandy ginger: a brow hair is as dark as it is against the
    # skin a few millimetres round it; that darkness becomes his colour.
    brows = np.zeros((h, w), np.float32)
    for e in BROWS:
        brows = np.maximum(brows, ellipse_mask(w, h, e, 12))
    # Wide enough that the brow itself barely darkens it.
    near = blur(out, 40)
    lum, near_lum = out.mean(2), near.mean(2)
    hairness = np.clip((near_lum - lum) / (0.3 * np.maximum(near_lum, 1.0)), 0, 1) * brows
    brow_colour = near * BROW_SHADE * (1 - 0.1 * hairness[..., None])
    out = out * (1 - hairness[..., None]) + brow_colour * hairness[..., None]

    # The scalp under his curls.
    lumc = cody.mean(2)
    ratio = np.clip(lumc / max(float(np.median(lumc[hair > 0.9])), 1.0), 0, 1.6)[..., None]
    root = np.clip(1.1 - ratio, 0, 1)
    colour = (SCALP_BLOND * (1 - root) + SCALP_ROOT * root) * np.clip(ratio, 0.8, 1.1)
    out = out * (1 - hair[..., None]) + colour * hair[..., None]
    save(out, HEAD_OUT, alpha)


def body() -> None:
    for src_name, out_name in BODY.items():
        src = Image.open(CHARACTERS / src_name).convert("RGBA")
        w, h = src.size
        rgb = load(CHARACTERS / src_name) * SKIN_GAIN
        if src_name.endswith("e0ec4a43013e474.png"):
            rgb = mirrored_fill(rgb, polygon_mask(w, h, DREAM, 4))
        if src_name.endswith("d527779c45f15f2.png"):
            m = polygon_mask(w, h, RING, 3)
            dx, dy = int(RING_SHIFT[0] * w), int(RING_SHIFT[1] * h)
            beside = np.roll(rgb, (-dy, -dx), (0, 1))
            rgb = rgb * (1 - m[..., None]) + beside * m[..., None]
        save(rgb, CHARACTERS / out_name, np.asarray(src)[..., 3])


def glb_mesh() -> dict:
    """Cody's Body mesh in bind pose, by material: (points, uvs, triangles)."""
    import json
    import struct
    data = GLB.read_bytes()
    n = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + n])
    binary = 20 + n + 8

    def accessor(i):
        a = gltf["accessors"][i]
        view = gltf["bufferViews"][a["bufferView"]]
        dtype = {5126: "<f4", 5123: "<u2", 5125: "<u4", 5121: "u1"}[a["componentType"]]
        width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
        start = binary + view.get("byteOffset", 0) + a.get("byteOffset", 0)
        return np.frombuffer(data, dtype, a["count"] * width, start).reshape(a["count"], width)

    def local(node):
        if "matrix" in node:
            return np.array(node["matrix"], np.float64).reshape(4, 4).T
        x, y, z, w = node.get("rotation", [0, 0, 0, 1])
        r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                      [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                      [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
        m = np.eye(4)
        m[:3, :3] = r * np.array(node.get("scale", [1, 1, 1]))
        m[:3, 3] = node.get("translation", [0, 0, 0])
        return m

    parent = {c: i for i, node in enumerate(gltf["nodes"]) for c in node.get("children", [])}
    index = next(i for i, node in enumerate(gltf["nodes"]) if node.get("name") == "Body")
    world, i = local(gltf["nodes"][index]), index
    while i in parent:
        i = parent[i]
        world = local(gltf["nodes"][i]) @ world
    out = {}
    for prim in gltf["meshes"][gltf["nodes"][index]["mesh"]]["primitives"]:
        name = gltf["materials"][prim["material"]]["name"]
        pts = accessor(prim["attributes"]["POSITION"]).astype(np.float64)
        pts = (np.c_[pts, np.ones(len(pts))] @ world.T)[:, :3]
        out[name] = (pts, accessor(prim["attributes"]["TEXCOORD_0"]).astype(np.float64),
                     accessor(prim["indices"]).astype(np.int64).reshape(-1, 3))
    return out


def gear_points(pts, uvs, tris, size):
    """(h, w, 3) bind-pose point painted by each texel, and its coverage. The
    UV triangles rasterised with barycentric interpolation; a triangle whose
    UVs wrap (a boot's run past v 0) is drawn at each whole-tile offset that
    brings part of it into the texture. Texels no triangle covers take the
    average of the covered ones near them, so filtering at the seams does not
    pull in a stray colour."""
    w, h = size
    point = np.zeros((h, w, 3), np.float64)
    cover = np.zeros((h, w), bool)
    for tri in tris:
        uv = uvs[tri]
        p = pts[tri]
        for dv in range(-int(math.floor(uv[:, 1].max())), -int(math.floor(uv[:, 1].min())) + 1):
            xy = np.c_[uv[:, 0] * w, (uv[:, 1] + dv) * h]
            x0, y0 = np.floor(xy.min(0)).astype(int)
            x1, y1 = np.ceil(xy.max(0)).astype(int)
            x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, w - 1), min(y1, h - 1)
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            (ax, ay), (bx, by), (cx, cy) = xy
            det = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(det) < 1e-12:
                continue
            l0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / det
            l1 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / det
            l2 = 1.0 - l0 - l1
            inside = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
            if not inside.any():
                continue
            lam = np.stack([l0, l1, l2], -1)[inside]
            ys, xs = np.nonzero(inside)
            point[ys + y0, xs + x0] = lam @ p
            cover[ys + y0, xs + x0] = True
    filled = point.copy()
    for sigma in (2.0, 8.0, 32.0):
        weight = blur(cover.astype(np.float32), sigma)
        spread = blur((point * cover[..., None]).astype(np.float32), sigma) / np.maximum(weight, 1e-6)[..., None]
        filled = np.where(cover[..., None] | (weight[..., None] < 1e-4), filled, spread)
        point = np.where(cover[..., None], point, filled)
        cover = cover | (weight > 1e-4)
    return point.astype(np.float32), cover


def leg_frame(pts, point):
    """Height, side (+1 his left, -1 his right) and the angle round the leg
    (degrees: 0 the front, + outward, 180 the back) of each texel's point,
    about each leg's own axis -- the centroid of the mesh's points of that
    leg at that height."""
    hs = np.arange(0.0, 1.25, 0.04)
    axes = {}
    for side in (-1.0, 1.0):
        leg = pts[pts[:, 0] * side > 0.01]
        xs, zs = [], []
        for y in hs:
            band = leg[np.abs(leg[:, 1] - y) < 0.03]
            if len(band) < 8:
                xs.append(np.nan)
                zs.append(np.nan)
                continue
            xs.append(band[:, 0].mean())
            zs.append(band[:, 2].mean())
        xs, zs = np.array(xs), np.array(zs)
        ok = ~np.isnan(xs)
        if ok.any():
            axes[side] = (np.interp(hs, hs[ok], xs[ok]), np.interp(hs, hs[ok], zs[ok]))
    # A boot's mesh is one leg: the other side's axis is its mirror image.
    for side in (-1.0, 1.0):
        if side not in axes:
            xs, zs = axes[-side]
            axes[side] = (-xs, zs)
    hgt = point[..., 1]
    side = np.where(point[..., 0] >= 0.0, 1.0, -1.0)
    xc = np.where(side > 0, np.interp(hgt, hs, axes[1.0][0]), np.interp(hgt, hs, axes[-1.0][0]))
    zc = np.where(side > 0, np.interp(hgt, hs, axes[1.0][1]), np.interp(hgt, hs, axes[-1.0][1]))
    ang = np.degrees(np.arctan2((point[..., 0] - xc) * side, point[..., 2] - zc))
    return hgt, side, ang


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def filigree(a, b, scale, seed, width=0.09):
    """Thin swirling lines (0-1) over surface coordinates a, b (metres): the
    contours of a smooth, folded random field -- scrollwork at game range."""
    rng = np.random.default_rng(seed)
    f = np.zeros_like(a)
    for _ in range(5):
        k1, k2 = rng.uniform(0.6, 1.5, 2) * 2.0 * math.pi / scale
        p1, p2 = rng.uniform(0.0, 2.0 * math.pi, 2)
        f += np.sin(a * k1 + p1 + 1.4 * np.sin(b * k2 * 0.7 + p2)) \
            * np.cos(b * k2 + p2 + 1.4 * np.sin(a * k1 * 0.7 + p1))
    g = f * 1.1
    d = np.abs(g - np.round(g))
    return smoothstep(width, width * 0.35, d)


def marble(point, seed):
    """Soft grey clouding (0-1) on the tights, from the 3D point."""
    rng = np.random.default_rng(seed)
    f = np.zeros(point.shape[:2], np.float32)
    for octave in range(4):
        k = (2.0 ** octave) * 9.0
        d = rng.normal(0.0, 1.0, 3)
        d /= np.linalg.norm(d)
        e = rng.normal(0.0, 1.0, 3)
        e /= np.linalg.norm(e)
        f += np.sin(point @ d * k + rng.uniform(0, 6.28) + 1.5 * np.sin(point @ e * k * 0.8)) / (1.6 ** octave)
    return smoothstep(0.6, 1.6, f)


def paint(base, mask, colour):
    return base * (1.0 - mask[..., None]) + colour * mask[..., None]


def tights(point, pts):
    hgt, side, ang = leg_frame(pts, point)
    out = paint(np.broadcast_to(TIGHTS_WHITE, point.shape).astype(np.float32),
                marble(point, GEAR_SEED) * 0.35, TIGHTS_MARBLE)
    radius = 0.075
    a = np.radians(ang) * radius
    # The outer-thigh panel, scalloped edges, black outline, black scrollwork.
    h0, h1, t0, t1 = THIGH_PANEL
    wave = 7.0 * np.sin(hgt * 60.0 + side * 1.3)
    inside = smoothstep(t0 - 2, t0 + 2, ang + wave) * smoothstep(t1 + 2, t1 - 2, ang - wave) \
        * smoothstep(h0, h0 + 0.02, hgt) * smoothstep(h1, h1 - 0.03, hgt)
    rim = smoothstep(t0 - 9, t0 - 3, ang + wave) * smoothstep(t1 + 9, t1 + 3, ang - wave) \
        * smoothstep(h0 - 0.015, h0, hgt) * smoothstep(h1 + 0.02, h1, hgt)
    out = paint(out, rim, BLACK)
    gold = paint(np.broadcast_to(GOLD, point.shape).astype(np.float32),
                 marble(point * 3.0, GEAR_SEED + 1) * 0.5, GOLD_DARK)
    gold = paint(gold, filigree(a, hgt, 0.14, GEAR_SEED + 2, 0.07), BLACK)
    out = paint(out, inside, gold)
    # The stripe down the back of the thigh.
    b0, b1, bc = BACK_STRIPE
    stripe = smoothstep(9, 6, np.abs(ang - bc)) * smoothstep(b0, b0 + 0.02, hgt) \
        * smoothstep(b1, b1 - 0.02, hgt)
    out = paint(out, stripe, GOLD)
    # Kneepads: black, gold scrollwork, gold rims top and bottom.
    k0, k1 = KNEEPAD
    front = smoothstep(130, 115, np.abs(ang))
    pad = smoothstep(k0 - 0.005, k0 + 0.005, hgt) * smoothstep(k1 + 0.005, k1 - 0.005, hgt) * front
    pad_rim = (smoothstep(0.012, 0.006, np.abs(hgt - k0 - 0.012))
               + smoothstep(0.012, 0.006, np.abs(hgt - k1 + 0.012))) * front
    out = paint(out, pad, BLACK)
    out = paint(out, pad * filigree(a, hgt, 0.07, GEAR_SEED + 3, 0.07), GOLD)
    out = paint(out, np.clip(pad_rim, 0, 1) * pad, GOLD)
    # The boot tops on the shin: black, with the boots' gold panels.
    shin = smoothstep(BOOT_TOP + 0.004, BOOT_TOP - 0.004, hgt)
    out = paint(out, shin, BLACK)
    out = paint(out, shin * boot_panels(ang, a, hgt), GOLD)
    return out


def boot_panels(ang, a, hgt):
    m = np.zeros_like(ang)
    for centre, half in BOOT_PANELS:
        m = np.maximum(m, smoothstep(half + 2, half - 2, np.abs(ang - centre)))
    return m * (1.0 - filigree(a, hgt, 0.06, GEAR_SEED + 4, 0.08))


def boot(point, pts):
    hgt, side, ang = leg_frame(pts, point)
    out = paint(np.broadcast_to(BLACK, point.shape).astype(np.float32),
                marble(point * 2.0, GEAR_SEED + 5) * 0.4, BLACK * 1.8)
    shaft = smoothstep(BOOT_FOOT, BOOT_FOOT + 0.02, hgt)
    out = paint(out, shaft * boot_panels(ang, np.radians(ang) * 0.06, hgt), GOLD)
    return out


def belt(point, pts):
    centre = np.median(pts[:, 1])
    ang = np.degrees(np.arctan2(point[..., 0], point[..., 2] + 0.09))
    a = np.radians(ang) * 0.16
    hgt = point[..., 1]
    out = paint(np.broadcast_to(BLACK, point.shape).astype(np.float32),
                marble(point * 2.0, GEAR_SEED + 6) * 0.3, BLACK * 1.6)
    band = smoothstep(0.024, 0.018, np.abs(hgt - centre))
    out = paint(out, band * filigree(a, hgt, 0.05, GEAR_SEED + 7, 0.1), GOLD)
    rims = smoothstep(0.004, 0.002, np.abs(np.abs(hgt - centre) - 0.028))
    return paint(out, rims, GOLD)


def gear() -> None:
    mesh = glb_mesh()
    painters = {"xmaterial_e531cd813705b95": tights, "xmaterial_c7ae1bc9f4b14": belt,
                "xmaterial_6d1e7e57b971093": boot, "xmaterial_6d205e57b97438d": boot}
    for material, (out_name, size) in GEAR.items():
        pts, uvs, tris = mesh[material]
        point, _ = gear_points(pts, uvs, tris, size)
        save(painters[material](point, pts), CHARACTERS / out_name)
    # The tape: Cody's own wrist tape, its weave kept, cleaned to white.
    src = Image.open(CHARACTERS / WRIST_SOURCE).convert("RGBA")
    rgb = load(CHARACTERS / WRIST_SOURCE)
    lum = rgb.mean(2, keepdims=True)
    save(np.clip(lum / max(float(np.median(lum)), 1.0), 0.6, 1.08) * TAPE,
         CHARACTERS / WRIST_OUT, np.asarray(src)[..., 3])


def main() -> int:
    head()
    body()
    gear()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
