#!/usr/bin/env python3
"""The wrestlers' and the referee's eyes, as textures (character_aaa_plan.md S1).

One procedural eye -- sclera, iris, pupil, lid occlusion, roughness, iris
depth -- painted per character off that character's own eye UVs (EYE_SPECS),
plus what each model needs on top: Roman's lash strands; Cody's photographic
eye texture kept and corrected; Aubrey's painted eye-and-lid texture
repainted to her; Kenny's new eye caps (tools/blender/kenny_eyes.py).

ROMAN. Measured off the supplied roman_reigns.glb:

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

CODY (cody_rhodes.glb): each eyeball is a 13.1 mm sphere on his Eye_L/Eye_R
bones with a flat front projection (~30.5 mm per UV unit, line of sight at
(0.5, 0.5)) carrying a photographic eye texture -- a good one, but with a
grey iris where his are blue, and bloodshot. So it is kept: the iris tinted
blue by luminance, the veins calmed, and the same occlusion/roughness/height
maps as Roman's laid over it (cody_eye_*.png).

AUBREY (aubrey_edwards.glb): a 17 mm cartoon eye whose texture (T_Eye_Brown,
256 px) paints the eye AND the skin of the lids round it -- the four corner
cards of her Eyes mesh are lids, and its darker band drew as thick brown
rims. In the owner's photos her eyes are blue-green under dark, smoky
make-up. So the iris is repainted blue-green, the baked highlight square
goes (the clearcoat makes a real one), the lid skin takes her face's tone,
and a smoky liner band runs round the eye (aubrey_eye_*.png, 512 px).

AUBREY, AAA rebuild (aubrey_aaa.glb, tools/blender/aubrey_aaa.py): real
eyeballs, 11.8 mm, front-projected at 30 mm per UV unit round the line of
sight at (0.5, 0.5) -- so the whole procedural eye at real sizes, in the
sheet's colour: a grey-green iris with a warm hazel ring round the pupil
(aubrey_aaa_eye_*.png). Her lids and make-up are in her skin texture now.

KENNY: his scan has no eyes, only paint. tools/blender/kenny_eyes.py builds
eye caps over the openings, front-projected at KENNY's spec, and this paints
them blue-grey (kenny_eye_*.png).

Usage:  python3 tools/assets/build_eyes.py     (deterministic)
"""

import dataclasses
import io
import json
import math
import pathlib
import struct
import sys

import numpy as np

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    sys.exit("Pillow is required: pip install Pillow")

CHARACTERS = pathlib.Path(__file__).resolve().parents[2] / "game/assets/characters"


@dataclasses.dataclass
class EyeSpec:
    """One character's eye on its own UVs: where the line of sight lands and
    how many millimetres a UV unit spans, then the anatomy and colours
    (sRGB). The defaults are Roman's."""
    centre: tuple = (0.501, 0.455)
    mm_per_uv: float = 31.0
    size: int = 1024
    ## Real anatomy, in mm: an adult iris is ~11.8 mm across; the pupil under
    ## arena light is small, ~3.8 mm. The collarette -- the ring where the
    ## iris's inner and outer zones meet -- sits about 40% of the way out.
    iris_r: float = 5.9
    pupil_r: float = 1.9
    collarette_r: float = 3.0
    limbus_w: float = 0.7
    ## Roman's eyes are a deep dark brown; the inner zone warmer than the
    ## outer, the limbal ring nearly black. First rendered at (118, 72, 36)
    ## inner with a bright collarette, his eye read amber and doll-like.
    iris_inner: tuple = (78, 46, 24)
    iris_outer: tuple = (42, 25, 15)
    collarette_lift: float = 10.0
    limbus: tuple = (22, 14, 10)
    pupil: tuple = (6, 5, 5)
    ## Not paper-white: a living sclera is a warm off-white, a shade below
    ## what a white material renders as under a key.
    sclera: tuple = (204, 193, 180)
    vein: tuple = (185, 92, 82)
    veins: int = 26
    ## Where the eye meets the lids: past occlude_from mm the sclera is in
    ## the lids' shadow, fully by occlude_to. On Roman the eyeball's outer
    ## band (from ~9.3 mm) lives there; at 7.5 the corners of his opening
    ## still read paper-white.
    occlude_from: float = 6.5
    occlude_to: float = 11.5
    occluded_ao: float = 0.22
    occluded_albedo: float = 0.62
    ## The cornea is a wet lens, the sclera wet but less smooth, the shadowed
    ## band rough enough not to mirror the rig.
    cornea_roughness: float = 0.04
    sclera_roughness: float = 0.16
    band_roughness: float = 0.55
    ## The iris plane sits ~2.5 mm behind the cornea's apex. As a height map:
    ## white is the cornea surface, the iris darker.
    iris_depth: float = 0.55
    seed: int = 31


ROMAN = EyeSpec()
## Cody: his eyeball is 13.1 mm and his UVs ~30.5 mm per unit, centred. The
## iris and veins come from his own texture (build_cody); these set the
## occlusion, roughness and depth maps, and the blue the iris is tinted to.
CODY = EyeSpec(centre=(0.5, 0.5), mm_per_uv=30.5, size=512, iris_r=6.25,
               occlude_from=7.5, occlude_to=12.5)
## His eyes are blue (the owner's references): the tint the iris's own
## luminance is carried in, and how far the veins are calmed toward a clean
## sclera (his texture is badly bloodshot).
CODY_IRIS_TINT = (0.66, 0.86, 1.18)
CODY_VEIN_CALM = 0.7
CODY_TEXTURE = "ximage_bbfc59e63cc5933"
## Aubrey: a cartoon eye, 17 mm, its UVs ~82 mm per unit (1 / 12.2 per mm)
## round the iris at (0.497, 0.502), which is 0.097 UV in radius -- 8 mm, the
## eye's own proportion. Blue-green, as in the owner's photos.
AUBREY = EyeSpec(centre=(0.497, 0.502), mm_per_uv=82.0, size=512, iris_r=7.95,
                 pupil_r=2.4, collarette_r=3.9, limbus_w=0.9,
                 iris_inner=(118, 122, 84), iris_outer=(66, 98, 104),
                 collarette_lift=14.0, limbus=(26, 34, 36), veins=0,
                 occlude_from=9.5, occlude_to=16.0, seed=41)
AUBREY_TEXTURE = "T_Eye_Brown"
## Her lids: the texture's skin, recoloured to her face, with smoky make-up
## (dark liner and shadow) in a band round the eye opening.
AUBREY_SKIN = (232, 196, 178)
AUBREY_SMOKE = (58, 44, 46)
AUBREY_SMOKE_PX = 14
AUBREY_SMOKE_STRENGTH = 0.85
## Aubrey's rebuild: true eyeballs (11.8 mm) projected at 30 mm per unit,
## centred. Grey-green, hazel-gold at the pupil (the sheet's eye close-up).
## A clear white with no veins and a darker shadowed band: in the game the
## veined, lit edge of the eye read as pink corners.
AUBREY_AAA = EyeSpec(centre=(0.5, 0.5), mm_per_uv=30.0, size=512,
                     iris_inner=(132, 116, 64), iris_outer=(92, 112, 98),
                     collarette_lift=12.0, limbus=(34, 42, 38), veins=0,
                     sclera=(214, 206, 196), occluded_albedo=0.5,
                     occlude_from=6.5, occlude_to=10.5, seed=53)
## Kenny: new caps (kenny_eyes.py) front-projected at 30 mm per unit,
## centred. Blue-grey, a touch of hazel at the pupil.
KENNY = EyeSpec(centre=(0.5, 0.5), mm_per_uv=30.0, size=512,
                iris_inner=(122, 120, 96), iris_outer=(84, 104, 122),
                collarette_lift=12.0, limbus=(30, 36, 44), veins=18, seed=43)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def polar(spec: EyeSpec):
    u = (np.arange(spec.size) + 0.5) / spec.size
    uu, vv = np.meshgrid(u, u)
    dx = (uu - spec.centre[0]) * spec.mm_per_uv
    dy = (vv - spec.centre[1]) * spec.mm_per_uv
    return np.hypot(dx, dy), np.arctan2(dy, dx)


def periodic_noise(rng, theta, count, scale):
    """Smooth noise round the circle: a sum of random-phase harmonics."""
    out = np.zeros_like(theta)
    for k in range(1, count + 1):
        out += rng.normal(0.0, 1.0) / k ** 0.6 * np.cos(k * scale * theta + rng.uniform(0, 2 * np.pi))
    return out / np.abs(out).max()


def col(c):
    return np.array(c, dtype=np.float32)


def paint_eye(spec: EyeSpec):
    """The procedural eye, before occlusion: (rgb float array, r, theta)."""
    rng = np.random.default_rng(spec.seed)
    r, th = polar(spec)
    # Iris fibres: radial striations (many harmonics round the circle) that
    # wander a little with radius, and crypts -- darker pits -- in the
    # outer zone.
    fibres = np.zeros_like(r)
    for k in (37, 53, 71, 97, 131):
        fibres += np.cos(k * th + 1.7 * np.sin(r * 1.3 + k) + rng.uniform(0, 2 * np.pi)) / len((37, 53, 71, 97, 131))
    crypts = periodic_noise(rng, th, 24, 1.0) * np.sin(r * 2.1 + periodic_noise(rng, th, 8, 1.0) * 2.0)
    zone = smooth(spec.collarette_r - 0.4, spec.collarette_r + 0.6, r)
    iris = col(spec.iris_inner)[None, None, :] * (1.0 - zone[..., None]) \
        + col(spec.iris_outer)[None, None, :] * zone[..., None]
    iris *= (1.0 + 0.22 * fibres - 0.12 * np.clip(crypts, 0.0, 1.0) * zone)[..., None]
    # A bright, uneven collarette ring.
    collar = np.exp(-((r - spec.collarette_r) / 0.35) ** 2) * (0.6 + 0.4 * periodic_noise(rng, th, 12, 1.0))
    iris += (collar * spec.collarette_lift)[..., None]
    # The limbal ring: the iris darkens into its rim, softly.
    limb = smooth(spec.iris_r - spec.limbus_w, spec.iris_r - 0.05, r)
    iris = iris * (1.0 - limb[..., None]) + col(spec.limbus)[None, None, :] * limb[..., None]
    # Sclera, with faint veins reaching in from the edge.
    sclera = np.broadcast_to(col(spec.sclera), r.shape + (3,)).astype(np.float32).copy()
    veins = Image.new("L", (spec.size, spec.size), 0)
    draw = ImageDraw.Draw(veins)
    for _ in range(spec.veins):
        a = rng.uniform(0, 2 * np.pi)
        rad = rng.uniform(11.5, 13.0)
        pts = []
        for _ in range(22):
            pts.append((spec.centre[0] * spec.size + math.cos(a) * rad / spec.mm_per_uv * spec.size,
                        spec.centre[1] * spec.size + math.sin(a) * rad / spec.mm_per_uv * spec.size))
            rad -= rng.uniform(0.12, 0.28)
            a += rng.normal(0.0, 0.035)
            if rad < 7.0:
                break
        draw.line(pts, fill=int(rng.integers(60, 120)), width=1)
    veins = np.asarray(veins.filter(ImageFilter.GaussianBlur(0.8)), dtype=np.float32) / 255.0
    sclera = sclera * (1.0 - veins[..., None]) + col(spec.vein)[None, None, :] * veins[..., None]
    # Iris into sclera over a fraction of a millimetre.
    edge = smooth(spec.iris_r - 0.05, spec.iris_r + 0.35, r)
    rgb = iris * (1.0 - edge[..., None]) + sclera * edge[..., None]
    pupil = 1.0 - smooth(spec.pupil_r - 0.15, spec.pupil_r + 0.2, r)
    rgb = rgb * (1.0 - pupil[..., None]) + col(spec.pupil)[None, None, :] * pupil[..., None]
    return rgb, r, th


def occlusion(spec: EyeSpec, r):
    return smooth(spec.occlude_from, spec.occlude_to, r)


def save_rgb(rgb, path):
    Image.fromarray(np.clip(np.round(rgb), 0, 255).astype(np.uint8), "RGB").save(path, optimize=True)


def write_maps(spec: EyeSpec, r, prefix: str, skin=None, skin_roughness=0.6) -> None:
    """The occlusion/roughness map (R, G) and the iris height map. `skin`, a
    0-1 mask of texels that are lid skin rather than eye, takes the skin's
    roughness and no occlusion (Aubrey's texture paints her lids)."""
    occluded = occlusion(spec, r)
    ao = 1.0 - (1.0 - spec.occluded_ao) * occluded
    rough = np.where(r < spec.iris_r + 0.6, spec.cornea_roughness, spec.sclera_roughness)
    rough = rough + (spec.band_roughness - spec.sclera_roughness) * occluded
    if skin is not None:
        ao = ao * (1.0 - skin) + skin
        rough = rough * (1.0 - skin) + skin_roughness * skin
    orm = np.stack([ao, rough, np.zeros_like(r)], axis=-1)
    Image.fromarray(np.round(orm * 255).astype(np.uint8), "RGB").save(
        CHARACTERS / f"{prefix}_eye_orm.png", optimize=True)
    # Height: the cornea surface at 1, the iris iris_depth down, easing in at
    # the limbus. (The pupil is not set deeper than the iris: in parallax it
    # dragged a dark keyhole down Roman's iris.)
    height = 1.0 - spec.iris_depth * (1.0 - smooth(spec.iris_r - 0.3, spec.iris_r + 0.4, r))
    Image.fromarray(np.round(height * 255).astype(np.uint8), "L").save(
        CHARACTERS / f"{prefix}_eye_height.png", optimize=True)


def build_procedural(spec: EyeSpec, prefix: str) -> None:
    """Roman's and Kenny's: the whole eye painted."""
    rgb, r, _ = paint_eye(spec)
    rgb *= (1.0 - (1.0 - spec.occluded_albedo) * occlusion(spec, r))[..., None]
    save_rgb(rgb, CHARACTERS / f"{prefix}_eye_color.png")
    write_maps(spec, r, prefix)
    print(f"eye -> {prefix}_eye_color / _orm / _height")


def glb_image(path: pathlib.Path, name: str) -> Image.Image:
    """An image embedded in a .glb, by name."""
    data = path.read_bytes()
    n = struct.unpack("<I", data[12:16])[0]
    gltf = json.loads(data[20:20 + n])
    binary = 20 + n + 8
    image = next(i for i in gltf["images"] if i.get("name") == name)
    view = gltf["bufferViews"][image["bufferView"]]
    start = binary + view.get("byteOffset", 0)
    return Image.open(io.BytesIO(data[start:start + view["byteLength"]])).convert("RGB")


def build_cody() -> None:
    spec = CODY
    base = np.asarray(glb_image(CHARACTERS / "cody_rhodes.glb", CODY_TEXTURE)
                      .resize((spec.size, spec.size), Image.LANCZOS), dtype=np.float32)
    r, _ = polar(spec)
    out = base.copy()
    # The iris: its own luminance, carried in blue.
    iris = 1.0 - smooth(spec.iris_r - 0.25, spec.iris_r + 0.35, r)
    lum = base.mean(axis=-1, keepdims=True)
    out = out * (1.0 - iris[..., None]) + np.clip(lum * col(CODY_IRIS_TINT), 0, 255) * iris[..., None]
    # The sclera: the veins calmed toward a smooth, desaturated off-white.
    calm = np.asarray(Image.fromarray(base.astype(np.uint8)).filter(ImageFilter.GaussianBlur(9)), dtype=np.float32)
    calm = calm.mean(axis=-1, keepdims=True) * 0.25 + calm * 0.75
    # and lifted toward a clean off-white: his texture's sclera is grey-pink.
    calm = calm * 0.5 + col(spec.sclera)[None, None, :] * 0.5
    sclera = smooth(spec.iris_r + 0.3, spec.iris_r + 1.2, r)[..., None] * CODY_VEIN_CALM
    out = out * (1.0 - sclera) + calm * sclera
    out *= (1.0 - (1.0 - spec.occluded_albedo) * occlusion(spec, r))[..., None]
    save_rgb(out, CHARACTERS / "cody_eye_color.png")
    write_maps(spec, r, "cody")
    print("eye -> cody_eye_color / _orm / _height")


def build_aubrey() -> None:
    spec = AUBREY
    base = np.asarray(glb_image(CHARACTERS / "aubrey_edwards.glb", AUBREY_TEXTURE)
                      .resize((spec.size, spec.size), Image.LANCZOS), dtype=np.float32)
    rgb, r, _ = paint_eye(spec)
    lum = base.mean(axis=-1)
    # The eye opening is the texture's pale sclera and its iris; everything
    # else is lid skin.
    opening = ((lum > 165) | (r < spec.iris_r + 0.3)).astype(np.uint8) * 255
    opening = np.asarray(Image.fromarray(opening).filter(ImageFilter.MaxFilter(3))
                         .filter(ImageFilter.GaussianBlur(1.5)), dtype=np.float32) / 255.0
    skin = 1.0 - opening
    # Lid skin in her face's tone, keeping the texture's own shading.
    skin_lum = lum[skin > 0.9].mean()
    lids = (lum / skin_lum)[..., None] * col(AUBREY_SKIN)[None, None, :]
    # Smoky make-up: a dark band hugging the opening, fading out over the lid.
    grown = Image.fromarray((opening * 255).astype(np.uint8)).filter(
        ImageFilter.MaxFilter(2 * (AUBREY_SMOKE_PX // 2) + 1))
    for _ in range(2):
        grown = grown.filter(ImageFilter.MaxFilter(2 * (AUBREY_SMOKE_PX // 2) + 1))
    smoke = np.asarray(grown.filter(ImageFilter.GaussianBlur(AUBREY_SMOKE_PX / 2)), dtype=np.float32) / 255.0
    smoke = np.clip(smoke - opening, 0.0, 1.0) * AUBREY_SMOKE_STRENGTH
    lids = lids * (1.0 - smoke[..., None]) + col(AUBREY_SMOKE)[None, None, :] * smoke[..., None]
    # The eye itself: painted sclera and iris, shaded toward the opening's
    # edge -- the occlusion follows the opening's own shape here, not a
    # circle, since her lids are painted round it.
    edge_shade = np.asarray(Image.fromarray((opening * 255).astype(np.uint8)).filter(
        ImageFilter.MinFilter(9)).filter(ImageFilter.GaussianBlur(4)), dtype=np.float32) / 255.0
    eye = rgb * (spec.occluded_albedo + (1.0 - spec.occluded_albedo) * edge_shade)[..., None]
    out = lids * skin[..., None] + eye * opening[..., None]
    save_rgb(out, CHARACTERS / "aubrey_eye_color.png")
    write_maps(spec, r, "aubrey", skin=skin)
    # The wet film on the eye only (EyeKit reads R as clearcoat, G as its
    # gloss): her lids are skin.
    coat = np.stack([opening, np.ones_like(opening), np.zeros_like(opening)], axis=-1)
    Image.fromarray(np.round(coat * 255).astype(np.uint8), "RGB").save(
        CHARACTERS / "aubrey_eye_coat.png", optimize=True)
    print("eye -> aubrey_eye_color / _orm / _height")


## Lashes: tapered, curving hairs from the root line. His upper lashes are
## dark, dense and of moderate length; the lower ones short and sparse.
LASH_UPPER = dict(root=0.045, tip=(0.28, 0.45), count=260, curl=0.05)
LASH_LOWER = dict(root=0.955, tip=(0.80, 0.70), count=110, curl=-0.03)
LASH_SEED = 37


def build_lashes(path) -> None:
    rng = np.random.default_rng(LASH_SEED)
    ss = 2
    size = ROMAN.size * ss
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
    mask = mask.filter(ImageFilter.GaussianBlur(0.5 * ss)).resize((ROMAN.size, ROMAN.size), Image.LANCZOS)
    out = Image.new("RGBA", (ROMAN.size, ROMAN.size), (255, 255, 255, 0))
    out.putalpha(mask)
    out.save(path, optimize=True)
    print(f"lashes -> {path.name}")


def main() -> int:
    build_procedural(ROMAN, "roman_reigns")
    build_lashes(CHARACTERS / "roman_reigns_lash_alpha.png")
    build_cody()
    build_aubrey()
    build_procedural(AUBREY_AAA, "aubrey_aaa")
    build_procedural(KENNY, "kenny")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
