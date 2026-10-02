#!/usr/bin/env python3
"""The referee, Aubrey Edwards, rebuilt to a AAA standard (character_aaa_plan.md
A1-A3) on a realistic human body, on her existing skeleton.

    python3 tools/blender/aubrey_aaa.py

Reads   game/assets/characters/aubrey_edwards.glb   (the kit build: skeleton,
                                                    uniform, hair)
Writes  game/assets/characters/aubrey_aaa.glb

Why: her kit body (Quaternius' Superhero_Female) is a cartoon -- 17 mm eyes,
painted lids, a toy's face -- and the owner's character sheet is a real woman.
The body is now MPFB's (MakeHuman for Blender, CC0 code and assets), shaped to
her, and everything the game relies on is kept:

* THE SKELETON is hers, untouched: the same 70 bones, names and rest pose, so
  every clip, paired move and the referee's own logic play on her as before
  (the plan's rule 1). MPFB's game-engine rig uses the same bone names (its
  "head" is her "Head"), so the body is FITTED to her skeleton rather than
  the other way round: each MPFB bone is pinned to her bone of the same name
  (Copy Location to its head, Damped Track to its tail) and that pose is
  baked into the mesh. Her joints then bend exactly where the clips bend
  them. Joints move and bones only aim -- no Stretch To, which would scale
  each bone's own region (her kit head bone is 20 cm to MPFB's 15) -- so the
  mesh between joints stretches through its blended weights while a head or
  a hand keeps its size.
* THE WEIGHTS are MPFB's own -- complete and smooth, fingers included --
  renamed onto her bones; her kit body cannot supply them (the skin under
  her uniform was deleted when the uniform was cut).
* HER UNIFORM is new (stage 4b): MakeHuman's own CC0 clothes, fitted to her
  by MPFB -- female_casualsuit01, a fitted short-sleeved tee and slim jeans
  split apart, and shoes06, trainers -- restyled to the owner's sheet: the
  tee striped (painted in its UV space from 3D position, piece by piece, a
  black cuff on each sleeve) and tucked under a belt with a square buckle
  and a radio pack; the jeans' waist raised to the belt, the legs let out
  straight and lengthened to break on the shoe, all near-black; the
  trainers black. Each garment then conforms to the body by a minimum
  standoff, takes its weights from it, and the skin under the cloth (and
  the feet inside the shoes) is deleted so nothing can poke through in a
  pose. The kit's patch is laid flat on the new shirt.
* HER PONYTAIL is new (stage 4b): long and falling close down her back from
  the tie, its spring bones re-laid along it; the kit's was short, curled
  and stood out behind her.
* HER COLLAR is new: the kit shirt's neckline zig-zagged from 1.39 to 1.53 m
  and stood up round her neck in shards. Now the shirt is trimmed below the
  collar line and a polo collar is built round her actual neck -- rays
  inward at COLLAR_STEPS angles find the surface -- as a stand and a
  fold-over flap (COLLAR_PROFILE), open at the front with the points angled
  down, and a zip placket down the front, in the shirt's own black trim.
* HER HAIR CAP is new: the kit's was cut for the cartoon skull and on a real
  head covered a strip over the crown with bare sides. It is grown from the
  new head's own scalp faces inside a hairline traced off the owner's sheet
  (HAIRLINE: high at the forehead, down past the temples, over and behind
  the ears to the nape), lifted CAP_OFF, feathered over its last
  centimetre by vertex alpha, and UV'd so the strands run from the hairline
  back to the ponytail tie -- slicked hair, combed back. Its strand texture
  (aubrey_hair_strands.png) is painted here.
* Helpers (MakeHuman's joint cubes, tights, skirt, eye and teeth proxies) are
  measured and then deleted; the eyes are rebuilt as eyeballs where MPFB's
  eye helpers sit, for the head kit's eye texture (build_eyes.py, EyeKit).

Requires MPFB installed as a Blender extension (bl_ext.user_default.mpfb) and
its MakeHuman system assets and skin packs under ~/.cache/aegis_assets/mpfb;
see gauntlet/refs/character_aaa_plan.md. Deterministic.
"""

from __future__ import annotations

import importlib
import math
import pathlib
import sys

import bpy  # noqa: E402  (first: it provides bmesh and mathutils)
import addon_utils
import bmesh
from mathutils import Vector

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import bpy_exit  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "game/assets/characters/aubrey_edwards.glb"
OUT = ROOT / "game/assets/characters/aubrey_aaa.glb"
MPFB = "bl_ext.user_default.mpfb"

## MPFB's macro sliders for her: a woman (MakeHuman's gender runs 0 female
## to 1 male -- the first build at 1.0 was a heavyset man) of about forty
## (age 0.5 is 25 and 1.0 is 90), lean and athletic -- she runs a ring for a
## living -- with idealised rather than average proportions.
MACROS = {
    "gender": 0.0, "age": 0.62, "muscle": 0.62, "weight": 0.42,
    "proportions": 0.75, "african": 0.0, "asian": 0.0, "caucasian": 1.0,
    "cupsize": 0.5, "firmness": 0.6,
}
## Her torso (stage 4b), measured off the owner's sheet (front and side
## views, scaled to her height): the shirt ~31 cm across the chest at the
## armpits and ~25 cm deep at the bust, ~30 cm across the belt, ~37 cm
## across the hips. The macros alone gave a narrow, shallow chest (24 x 19)
## over a wider waist (33). Applied like FACE.
BODY = {
    "measure-waist-circ-decr": 0.3,
    "torso-scale-depth-incr": 0.3,
    "torso-scale-horiz-incr": 1.0,
    "torso-vshape-incr": 0.2,
}
## (A first pass -- cup 0.75, bust +0.6, waist -1.0, V-shape 0.6 -- matched
## the chest and belt numbers but was chest-heavy with a pinched waist: the
## owner's sheet is straighter, and the shirt hangs from the bust; see
## SHIRT_DRAPE.)
## MPFB's waist acts above her belt line; at the belt (sheet: ~30 cm across)
## the body is narrowed directly, side to side, by up to WAIST_SLIM, in a
## smooth band WAIST_SIGMA either side of WAIST_Z.
WAIST_Z = 1.025
WAIST_SIGMA = 0.06
WAIST_SLIM = 0.06
## Her likeness (stage 3): MPFB face targets, set against the owner's
## character sheet (front, 3/4 and profile) on a clay render. An oval face,
## high cheekbones over lightly hollowed cheeks, a slim jaw into a short,
## rounded chin with a clean line into the neck; a long straight nose with a
## softly rounded tip; a mouth with a firm, full lower lip carried forward;
## open almond eyes under a raised brow; a slim neck. A name
## without a side (e.g. "cheek-bones-incr") is applied to both l- and r-.
## The jaw was tuned again after the colour pass (four variants against the
## sheet), then the whole face again (six variants, clay beside the sheet's
## front, 3/4 and profile): her chin is short and rounded, not long and
## pointed; her face is full at the cheekbones and the mouth, not tapered;
## the nose is long, with a fuller tip. Seen textured, that pass's mouth was
## too wide and puffy and the lower face too broad, so both came back in (a
## mouth about a third of the face's width, a firm lower lip, a slimmer jaw)
## and the red now stops at the lip line instead of bleeding past it.
FACE = {
    # head
    "forehead-temple-decr": 0.3,
    "forehead-trans-backward": 0.25,
    "head-fat-decr": 0.5,
    "head-oval": 0.3,
    # chin and jaw
    "chin-height-decr": 0.3,
    "chin-prominent-incr": 0.5,
    "chin-width-decr": 0.6,
    "neck-double-decr": 0.6,
    "neck-scale-horiz-decr": 0.4,
    # cheeks
    "cheek-bones-incr": 1.26,
    "cheek-inner-decr": 0.15,
    "cheek-volume-decr": 0.4,
    # nose
    "nose-point-down": 0.3,
    "nose-scale-depth-incr": 0.85,
    "nose-scale-horiz-incr": 0.2,
    "nose-scale-vert-incr": 0.65,
    "nose-volume-incr": 0.25,
    "nose-width1-decr": 0.1,
    "nose-width2-decr": 0.1,
    # mouth
    "mouth-cupidsbow-incr": 0.6,
    "mouth-lowerlip-height-incr": 0.1,
    "mouth-lowerlip-volume-incr": 0.3,
    "mouth-scale-horiz-incr": 0.25,
    "mouth-trans-forward": 0.49,
    "mouth-upperlip-volume-incr": 0.15,
    # eyes and brows
    "eye-corner2-up": 0.2,
    "eye-height2-incr": 0.2,
    "eye-scale-incr": 0.3,
    "eyebrows-trans-forward": 0.3,
    "eyebrows-trans-up": 0.1,
}
## MPFB bone -> her bone, where the names differ.
BONE_NAMES = {"head": "Head"}
## Bones that take her bone's direction but keep their own position. Her kit
## skeleton is a stylised one with a big head: its head joint sits 21.7 cm
## under the crown, where a real head's is ~15. Pinned there, a real head
## sank 8 cm onto a stub of a neck (eyes at 1.58 against 1.66). Left free, it
## rides MPFB's own neck; the head turns about her Head bone, ~3.5 cm lower
## in the neck, which no clip's head rotation shows.
FREE_JOINTS = {"head"}
## Her neck is slim (the sheet); fitted to her kit's neck bone, the body's
## came out ~2.5 cm thicker than MPFB's own. The skin on the neck bone is
## drawn toward the neck's axis by NECK_SLIM times its neck weight.
NECK_SLIM = 0.12
## Garment -> (minimum, maximum) standoff off the new body, metres. The
## minimums are the kit build's own offsets (referee_aubrey.py SHIRT_OFF,
## TROUSER_OFF, SHOE_OFF); the maximums let a shirt drape but not tent.
GARMENTS = {
    "Aubrey_Shirt": (0.005, 0.08),
    "Aubrey_Trousers": (0.004, 0.15),
    "Aubrey_Shoes": (0.003, 0.08),
}
## The kit's garments, replaced (stage 4b) by MakeHuman's own CC0 clothes
## fitted by MPFB: female_casualsuit01 (a fitted short-sleeved tee and slim
## jeans, one mesh, split here) restyled as her shirt and trousers, and
## shoes06 (trainers) in black.
KIT_GARMENTS = ("Aubrey_Shirt", "Aubrey_Trousers", "Aubrey_Shoes")
KIT_MATERIALS_REPLACED = ("M_AubreyHair", "M_Belt", "M_Shoes", "M_Trousers", "M_RefStripes")
SUIT = "female_casualsuit01"
SHOES = "shoes06"
## Her shirt's stripes (the sheet): black and white bands STRIPE_W wide,
## black down the centre front, vertical round the torso and running down
## each sleeve to a black cuff CUFF_W deep. Painted onto the tee's own UVs
## from 3D position, like her make-up. Torso and sleeve meet at SLEEVE_X.
STRIPE_W = 0.036
STRIPE_WHITE = (232, 232, 226)
STRIPE_BLACK = (20, 20, 22)
CUFF_W = 0.022
SLEEVE_X = 0.172
## The front's stripes are angles round an axis this far behind her spine
## (the back's, this far in front), times the distance to her surface.
TORSO_AXIS_BACK = 0.14
SHIRT_TEX = ROOT / "game/assets/characters/aubrey_aaa_shirt.png"
## The jeans' and trainers' own textures, taken to black: a twill keeps its
## seams and wear in a narrow band of near-black; the trainers keep their
## panels' shading. The suit's normal map (the jeans' wrinkles) comes along.
TROUSERS_TEX = ROOT / "game/assets/characters/aubrey_aaa_trousers.jpg"
TROUSERS_TONE = (11.0, 11.0, 12.0, 12.0)   # r, g, b at black, plus lift at white
SUIT_NORMAL = ROOT / "game/assets/characters/aubrey_aaa_suit_normal.png"
SUIT_NORMAL_SIZE = 2048
SHOES_TEX = ROOT / "game/assets/characters/aubrey_aaa_shoes.png"
SHOES_TONE = (12.0, 12.0, 13.0, 34.0)
## Tucked in: the shirt is cut under the belt; the belt (sheet: black
## leather, square silver buckle, a radio pack at the back right) is built
## round the trousers from rays, BELT_OFF proud of them.
BELT_TOP = 1.036
BELT_H = 0.036
BELT_OFF = 0.004
BELT_THICK = 0.004
BELT_STEPS = 64
TUCK_UNDER = 0.012
## The shirt hangs from her bust to the belt (the sheet: as wide just above
## the belt, ~31 cm, as across the chest), not clinging to her waist: below
## SHIRT_DRAPE_FROM, at each angle round her, the cloth is let out to at
## least SHIRT_DRAPE times its reach at the bust, easing back in over the
## last SHIRT_DRAPE_GATHER above the belt where it is tucked.
SHIRT_DRAPE_FROM = 1.30
SHIRT_DRAPE = 0.97
SHIRT_DRAPE_GATHER = 0.05
SHIRT_DRAPE_EASE = 0.10
BUCKLE_W, BUCKLE_H, BUCKLE_BAR = 0.046, 0.044, 0.0065
PACK_ANGLE = 145.0          # degrees round from the front, toward her right
PACK_SIZE = (0.058, 0.085, 0.028)
## Her trousers (the sheet): straight-legged work trousers, not slim jeans.
## The jeans' low waist is raised to the belt (each angle's top edge
## stretched up to TROUSER_WAIST over the span above TROUSER_WAIST_FROM); the
## legs below the knee are lengthened so the hem falls to TROUSER_HEM over
## the shoe; and each leg is let out to at least TROUSER_LEG_R round its
## axis (hip to ankle), blended in over the thigh.
TROUSER_WAIST = 1.026
TROUSER_WAIST_FROM = 0.84
TROUSER_HEM = 0.035
TROUSER_KNEE = 0.50
TROUSER_LEG_R = 0.064
TROUSER_LEG_FROM = (0.86, 0.70)   # z where the letting-out starts, and is full
## The patch sits on the new shirt, this far off it.
PATCH = "Aubrey_Patch"
PATCH_OFF = 0.0025
## The sheet's patch, placed by its landmarks rather than absolute height
## (her collar and shoulders do not sit where the photo's do): its centre a
## quarter of the way (0.23) from the collar points down to the belt, and
## out from the zip by 0.29 of the chest's width, but kept on the front of
## her chest (wider, its edge wrapped round her side in a smear); a tenth
## larger than the kit's. (x, z of its centre.)
PATCH_SCALE = 1.1
PATCH_CUTS = 3
PATCH_CENTRE = (-0.094, 1.332)
## Its wrapping axis: this far behind the body's centre line.
PATCH_AXIS_Y = 0.14
## Her chest pocket (the sheet), on her left -- a narrow pen pocket, placed
## like the patch by landmarks: from 0.21 to 0.53 of the way from the collar
## points down to the belt, its centre out from the zip by 0.26 of the
## chest's width, 0.14 of it wide. Cut from the shirt's own
## cloth -- its UVs taken from the shirt beside it (POCKET_STRIPE_SHIFT) --
## standing POCKET_OFF proud, with a flap POCKET_FLAP deep over its top.
## (x from, x to, z bottom, z top), metres.
POCKET = (0.058, 0.101, 1.216, 1.339)
POCKET_OFF = 0.005
POCKET_FLAP = 0.022
## A sewn-on pocket's stripes never quite meet the shirt's: its cloth is
## sampled to one side, by whichever of these shifts makes it whitest (on
## the sheet it is mostly white, over the black stripe it sits on).
POCKET_STRIPE_SHIFTS = [0.004 * k for k in range(-12, 5)]
POCKET_GRID = (4, 10)
GARMENT_SMOOTH = 6
## The hair cap's standoff: slicked tight to the skull.
CAP = "Aubrey_HairCap"
CAP_OFF = 0.004
## Her hairline: height above the eyes (m) by the angle round the head from
## straight ahead (degrees) -- a high forehead, the temples, over the ear,
## behind it, the nape.
## (On the new head her ear sits at ~95 degrees, nearly beside the head's
## centre: the hairline drops straight down behind it to the nape. At 100
## degrees and +1 cm the strip behind her ears was bare -- an undercut.)
HAIRLINE = [(0.0, 0.072), (35.0, 0.062), (60.0, 0.042), (82.0, 0.030),
            (95.0, 0.020), (104.0, -0.045), (125.0, -0.065), (180.0, -0.080)]
## The cap feathers out over this much of its edge.
HAIRLINE_FEATHER = 0.02
## Her ears: never under the cap. Out from the head's centre line beyond
## EAR_X, within EAR_Z of eye height, the cap's margin goes negative.
EAR_X = 0.064
EAR_Z = (-0.040, 0.022)
## ...and within EAR_Y of the ear's own depth (its lobe's y): before, the
## whole band of the head at ear height was bare, behind the ear too -- an
## undercut.
EAR_Y = (-0.026, 0.022)
## Strand repeats round the head.
CAP_U_TILES = 6
HAIR_STRANDS = ROOT / "game/assets/characters/aubrey_hair_strands.png"
HAIR_SIZE = 1024
HAIR_SEED = 47
## Her hair (the owner's sheet): mid brown, slicked wet, with lighter
## caramel strands through it. (At (74, 52, 36) it read light tan under the
## arena's key.)
HAIR_BASE = (60, 42, 29)
HAIR_LIGHT = (126, 90, 58)
PONYTAIL = ("Aubrey_Ponytail", "Aubrey_HairTie")
## Her ponytail (the sheet: high, long, falling to mid-back close along the
## back of her head and neck), rebuilt (stage 4b) -- the kit's was short,
## curled and stood out behind her. A tube of strands along a path from the
## tie, out over the crown and down the back, PONYTAIL_GAP off whatever is
## under it, ending at PONYTAIL_TIP_Z; its radius by fraction of the length
## (PONYTAIL_R); slightly flattened against her back; in the cap's own
## strand texture so the colour matches. Its five spring bones are re-laid
## along the path in equal lengths.
PONYTAIL_TIP_Z = 1.235
PONYTAIL_GAP = 0.002
## The side of the tail toward her lies on her: those ring vertices are
## pressed onto what is under them, this far off it.
PONYTAIL_HUG = 0.002
PONYTAIL_R = [(0.0, 0.017), (0.12, 0.031), (0.35, 0.034), (0.65, 0.026),
              (0.88, 0.013), (1.0, 0.004)]
PONYTAIL_FLAT = (1.15, 0.8)
PONYTAIL_RINGS = 56
PONYTAIL_SIDES = 16
PONYTAIL_U_TILES = 3.0
TIE = "Aubrey_HairTie"
PONYTAIL_BONES = ("ponytail_1", "ponytail_2", "ponytail_3", "ponytail_4", "ponytail_5")
## The collar: where it sits (its base, m), how many angles round the neck,
## the gap at the front (degrees either side of straight ahead), and its
## profile as (height above the base, standoff off the neck) from the stand's
## foot up and over the fold to the flap's edge.
## The base is tilted, as a collar sits: COLLAR_Z at the sides, COLLAR_TILT
## lower at the front (over the notch between the collarbones) and higher at
## the back. Flat at 1.47 the inward rays met the slope of her trapezius and
## the collar sat round her shoulders.
COLLAR_Z = 1.478
COLLAR_TILT = 0.024
## The neck is sampled this far up from the base, and no wider than this.
COLLAR_SAMPLE_UP = 0.022
COLLAR_MAX_R = 0.072
COLLAR_STEPS = 48
## On the owner's sheet the collar is open at the front in a V -- its ends
## ~35 degrees either side of straight ahead, the points dropping -- with the
## zip starting at the V's point (SHIRT_V). The collar hugs her neck -- a stand ~3.5 cm high all
## round, the flap folded down close over it and ending above her shoulder
## line -- rather than spreading over her shoulders (the first version, a
## cape on the tee's wide neckline).
COLLAR_GAP = 35.0
COLLAR_PROFILE = [(0.000, 0.004), (0.016, 0.004), (0.030, 0.004), (0.040, 0.007),
                  (0.038, 0.011), (0.028, 0.013), (0.016, 0.015), (0.006, 0.017)]
## The collar's points drop by this at the front edges.
COLLAR_POINT_DROP = 0.040
## Shirt faces above the collar's (tilted) base plus COLLAR_TRIM_UP, within
## COLLAR_TRIM_R of the neck's own surface at that angle, go: the flap
## (reaching up to COLLAR_FLAP_MAX off the neck) covers the cut. (A fixed
## 0.105 from the axis, for the kit shirt, left a saw-toothed edge out on
## her shoulders past the flap; no cut left the tee's striped neckband
## standing inside the collar.)
COLLAR_TRIM_UP = 0.0
COLLAR_TRIM_R = 0.016
## The flap rests this far off the shirt (at 0.005 the tee's stripes showed
## through it in specks), and reaches no further than COLLAR_FLAP_MAX off her
## neck: resting on the tee wherever that was, it spread like a bib.
COLLAR_FLAP_OFF = 0.005
COLLAR_FLAP_MAX = 0.024
## The open neck (the sheet's shirt front, measured off its patch's width):
## a V cut in the shirt from the collar's open ends down to its point
## SHIRT_V[1] below them; its edges bound in the
## trim, SHIRT_V_EDGE wide -- wide enough to cover the cut, which steps
## along the shirt's faces (at 5 mm the white steps showed).
SHIRT_V = (None, 0.045)
SHIRT_V_EDGE = 0.011
## The placket: a zip down the shirt's black centre stripe (the sheet), from
## under the collar's points to PLACKET_BOTTOM -- a narrow black tape with a
## metal track down it (ZIP_HALF_W) and a pull at its top. (A 3.2 cm strip
## started at the collar's top, where the shirt is cut away: its rays missed
## and its top hung in front of her throat as a dark block.)
PLACKET_BOTTOM = 1.355
PLACKET_HALF_W = 0.007
ZIP_HALF_W = 0.0012
ZIP_PULL = (0.004, 0.012)
TRIM_MATERIAL = "M_RefTrim"
## Skin is deleted where a ray out along its normal meets cloth within this.
COVER_REACH = 0.08
## ...or where it lies within COVER_NEAR of cloth, more than
## COVER_OPENING_CLEAR from any of the cloth's openings.
COVER_NEAR = 0.015
COVER_OPENING_CLEAR = 0.04
## The feet, inside the trainers, go whole below their collar: the shoe's
## heel cup sits only ~2 mm off her heel and the skin showed through it.
FOOT_HIDDEN_Z = 0.09
## Eyeball radius over MPFB's eye helper's: the helper is the eye's visible
## front; a real eyeball is ~12 mm.
EYE_RADIUS = 0.0118
EYE_SEGMENTS = (32, 16)
## The eyes' front projection (build_eyes.py AUBREY_AAA): mm per UV unit.
EYE_MM_PER_UV = 30.0
EYE_COLOR = ROOT / "game/assets/characters/aubrey_aaa_eye_color.png"

## Her skin (stage 4): a CC0 MakeHuman skin with no make-up painted on --
## toigo's young light-skinned female, bronze -- graded from its orange
## toward the sheet's rosier beige, and down: at (0.88, 0.90, 1.04) she read
## bleached under the arena's key, then her make-up painted over it in UV
## space from 3D positions (paint_skin): the head's triangles are
## rasterised into a map of where each texel sits on her, and each layer of
## make-up is a function of that position, so it lands on her actual lids
## and lips whatever the targets did to them.
MPFB_ASSETS = pathlib.Path.home() / ".cache/aegis_assets/mpfb"
SKIN_SOURCE = (MPFB_ASSETS / "unpacked_skins01/skins/toigo_light_skin_female_bronze"
               / "young_lightskinned_female_diffuse_Bronze.png")
SKIN_OUT = ROOT / "game/assets/characters/aubrey_aaa_skin.jpg"
SKIN_GRADE = (0.80, 0.74, 0.80)
SKIN_QUALITY = 92
## Smoky eyes (the sheet's make-up close-up): a soft dark plum-brown shadow
## in an ellipse round each eye (mm: wider to the outer corner, higher over
## the lid than under it), pulled 2 mm outward into a wing, lighter on the
## lower lid; and a liner along the lid margin -- where the lids meet the
## eyeball, the body's socket being closed behind it.
SMOKE = dict(shift=2.0, a_out=19.0, a_in=15.0, b_up=17.0, b_down=9.0,
             e0=0.45, e1=1.15, lower=0.7, color=(66, 42, 44), strength=0.85)
LINER = dict(near=0.8, far=3.0, color=(28, 20, 20), strength=0.85, lower=0.6,
             margin_slack=0.0012)
## The eye socket's skin within SOCKET mm of the eyeball's centre (its radius
## is 11.8) goes to SOCKET_COLOR, fading out by the far value.
SOCKET = (13.0, 14.4)
SOCKET_COLOR = (34, 22, 22)
SOCKET_OPEN = (17.0, 6.5)
SOCKET_DEPTH = 8.0
## Red lips, off MPFB's own "lips" vertex group, the texture's shading kept.
LIPS = dict(lo=0.25, hi=0.6, blur=1.5, color=(128, 14, 28), strength=0.9)
## Brow and lash cards: MakeHuman's own (CC0), fitted to her face by MPFB.
## The brow strands go her brown and denser than drawn (the sheet's brows
## are full and groomed); the lashes near-black with mascara.
BROWS = "eyebrow010"
LASHES = "eyelashes02"
CARD_TEXTURES = {
    BROWS: (ROOT / "game/assets/characters/aubrey_aaa_brows.png", (72, 48, 34), 1.8),
    LASHES: (ROOT / "game/assets/characters/aubrey_aaa_lashes.png", (22, 17, 16), 1.3),
}
## Stud earrings in each lobe (the sheet's ear close-up): a small brilliant,
## 2.2 mm across the girdle, set 1 mm proud of the lobe's outer face.
STUD_RADIUS = 0.0022
STUD_PROUD = 0.001


def mpfb(module: str, name: str):
    return getattr(importlib.import_module(f"{MPFB}.{module}"), name)


def make_body(old_arm):
    """MPFB's human, shaped to her and fitted to her skeleton, weights on her
    bone names; returns (body object, {"l"/"r": (eye centre, eye forward)})."""
    HumanService = mpfb("services.humanservice", "HumanService")
    TargetService = mpfb("services.targetservice", "TargetService")
    Props = mpfb("entities.objectproperties", "HumanObjectProperties")
    human = HumanService.create_human()
    human.name = "Aubrey_Body"
    for key, value in MACROS.items():
        Props.set_value(key, value, entity_reference=human)
    TargetService.reapply_macro_details(human)
    for name, weight in sorted({**FACE, **BODY}.items()):
        sided = TargetService.target_full_path(name) is None
        for full in ([f"l-{name}", f"r-{name}"] if sided else [name]):
            path = TargetService.target_full_path(full)
            if path is None or not pathlib.Path(path).name.startswith(full + "."):
                raise SystemExit(f"aubrey_aaa: no MPFB target {full}")
            TargetService.load_target(human, path, weight=weight, name=full)
    rig = HumanService.add_builtin_rig(human, "game_engine")
    # Pin every MPFB bone onto hers. Disconnected first: Blender ignores Copy
    # Location on a bone connected to its parent, and the first build kept
    # MPFB's own (shorter) spine -- her head 8 cm low.
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in rig.data.edit_bones:
        eb.use_connect = False
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        target = BONE_NAMES.get(pb.name, pb.name)
        if target not in old_arm.data.bones:
            continue
        if pb.name not in FREE_JOINTS:
            loc = pb.constraints.new("COPY_LOCATION")
            loc.target, loc.subtarget = old_arm, target
        aim = pb.constraints.new("DAMPED_TRACK")
        aim.target, aim.subtarget = old_arm, target
        aim.head_tail = 1.0
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    # Bake: shape keys (the macro targets), then the fitting pose.
    bpy.context.view_layer.objects.active = human
    for o in bpy.context.selected_objects:
        o.select_set(False)
    human.select_set(True)
    for mod in list(human.modifiers):
        if mod.type == "MASK":
            human.modifiers.remove(mod)
    if human.data.shape_keys:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    for mod in list(human.modifiers):
        if mod.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=mod.name)
    # The eyes, from MPFB's eye helpers, before the helpers go.
    eyes = {}
    for side in ("l", "r"):
        group = human.vertex_groups[f"helper-{side}-eye"].index
        pts = [human.matrix_world @ v.co for v in human.data.vertices
               if any(g.group == group and g.weight > 0.5 for g in v.groups)]
        centre = sum(pts, Vector()) / len(pts)
        front = min(pts, key=lambda p: p.y)          # she faces -Y
        eyes[side] = (centre, (front - centre).normalized())
    slim_neck(human, old_arm)
    taper_waist(human)
    cards = make_cards(human)
    make_garments(human, old_arm)
    lobes = ear_lobes(human)
    # Keep only the body.
    body_group = human.vertex_groups["body"].index
    bm = bmesh.new()
    bm.from_mesh(human.data)
    deform = bm.verts.layers.deform.active
    doomed = [v for v in bm.verts if body_group not in v[deform]]
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(human.data)
    bm.free()
    paint_skin(human, eyes)
    # Weights onto her bones: rename, and drop every group that is not one
    # of her bones (MPFB's own helper and joint groups).
    for vg in list(human.vertex_groups):
        name = BONE_NAMES.get(vg.name, vg.name)
        if name in old_arm.data.bones:
            vg.name = name
        else:
            human.vertex_groups.remove(vg)
    bpy.data.objects.remove(rig, do_unlink=True)
    human.parent = old_arm
    human.matrix_parent_inverse = old_arm.matrix_world.inverted()
    arm_mod = human.modifiers.new("Armature", "ARMATURE")
    arm_mod.object = old_arm
    for card in cards:
        rigid_on_head(card, old_arm)
    for name in GARMENTS:
        obj = bpy.data.objects[name]
        obj.parent = old_arm
        obj.matrix_parent_inverse = old_arm.matrix_world.inverted()
        obj.modifiers.new("Armature", "ARMATURE").object = old_arm
    return human, eyes, lobes


def world_bvh(objs):
    from mathutils.bvhtree import BVHTree
    verts, polys = [], []
    for o in objs:
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in o.data.vertices]
        polys += [[base + i for i in p.vertices] for p in o.data.polygons]
    return BVHTree.FromPolygons(verts, polys)


def conform(obj, bvh, t_min: float, t_max: float):
    """Pushes `obj` out to t_min off the surface in `bvh` and in to t_max,
    leaves what is between, smooths the corrections, enforces t_min again.
    Returns each vertex's world displacement."""
    mw = obj.matrix_world
    inv = mw.inverted()
    me = obj.data
    n = len(me.vertices)
    pos = [mw @ v.co for v in me.vertices]
    disp = [Vector() for _ in range(n)]
    for i, p in enumerate(pos):
        loc, nor, _, _ = bvh.find_nearest(p)
        if loc is None:
            continue
        d = (p - loc).dot(nor)
        if d < t_min:
            disp[i] = nor * (t_min - d)
        elif d > t_max:
            disp[i] = nor * (t_max - d)
    nbr = [[] for _ in range(n)]
    for e in me.edges:
        a, b = e.vertices
        nbr[a].append(b)
        nbr[b].append(a)
    for _ in range(GARMENT_SMOOTH):
        disp = [disp[i] * 0.5 + sum((disp[j] for j in nbr[i]), Vector()) * (0.5 / len(nbr[i]))
                if nbr[i] else disp[i] for i in range(n)]
    for i in range(n):
        p = pos[i] + disp[i]
        loc, nor, _, _ = bvh.find_nearest(p)
        if loc is not None:
            d = (p - loc).dot(nor)
            if d < t_min:
                disp[i] += nor * (t_min - d)
    for i, v in enumerate(me.vertices):
        v.co = inv @ (pos[i] + disp[i])
    me.update()
    return pos, disp


def follow(obj, anchor_pos, anchor_disp):
    """Moves `obj` with the displacement of the nearest anchor vertex."""
    from mathutils.kdtree import KDTree
    tree = KDTree(len(anchor_pos))
    for i, p in enumerate(anchor_pos):
        tree.insert(p, i)
    tree.balance()
    mw = obj.matrix_world
    inv = mw.inverted()
    for v in obj.data.vertices:
        p = mw @ v.co
        _, i, _ = tree.find(p)
        v.co = inv @ (p + anchor_disp[i])
    obj.data.update()


def take_weights(obj, body) -> None:
    """Replaces `obj`'s skin weights with the new body's, by nearest face."""
    for vg in list(obj.vertex_groups):
        obj.vertex_groups.remove(vg)
    mod = obj.modifiers.new("Weights", "DATA_TRANSFER")
    mod.object = body
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    mod.layers_vgroup_select_src = "ALL"
    mod.layers_vgroup_select_dst = "NAME"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.datalayout_transfer(modifier=mod.name)
    # Applied ahead of the armature, which must stay last.
    while obj.modifiers[0] != mod:
        bpy.ops.object.modifier_move_up(modifier=mod.name)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def refit(old_arm, body):
    objects = bpy.data.objects
    body_bvh = world_bvh([body])
    for name, (t_min, t_max) in GARMENTS.items():
        conform(objects[name], body_bvh, t_min, t_max)
    # The hair: the cap onto the new skull; the ponytail with the cap where
    # the tie sits.
    tie = objects[TIE]
    tie_centre = sum((tie.matrix_world @ v.co for v in tie.data.vertices), Vector()) / len(tie.data.vertices)
    cap_pos, cap_disp = conform(objects[CAP], body_bvh, CAP_OFF, CAP_OFF)
    near = [d for p, d in zip(cap_pos, cap_disp) if (p - tie_centre).length < 0.05]
    delta = sum(near, Vector()) / len(near) if near else Vector()
    for name in PONYTAIL:
        o = objects[name]
        for v in o.data.vertices:
            v.co = o.matrix_world.inverted() @ (o.matrix_world @ v.co + delta)
        o.data.update()
    bpy.context.view_layer.objects.active = old_arm
    bpy.ops.object.mode_set(mode="EDIT")
    local = old_arm.matrix_world.inverted().to_3x3() @ delta
    for name in PONYTAIL_BONES:
        eb = old_arm.data.edit_bones.get(name)
        if eb:
            eb.head += local
            eb.tail += local
    bpy.ops.object.mode_set(mode="OBJECT")
    for name in GARMENTS:
        take_weights(objects[name], body)
    print(f"refit: ponytail moved {delta.length * 1000:.0f} mm")
    return tie_centre + delta


def cover_skin(body, cloth) -> None:
    """Deletes the body's faces that are wholly under cloth."""
    from mathutils.kdtree import KDTree
    bvh = world_bvh(cloth)
    # The cloth's open edges (neck, cuffs, hems, the V): skin near them must
    # stay, or a gap opens at the opening.
    edges = []
    for o in cloth:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
        edges += [o.matrix_world @ v.co for v in bm.verts if v.is_boundary]
        bm.free()
    openings = KDTree(len(edges))
    for i, q in enumerate(edges):
        openings.insert(q, i)
    openings.balance()
    mw = body.matrix_world
    covered = []
    for v in body.data.vertices:
        p = mw @ v.co
        n = (mw.to_3x3() @ v.normal).normalized()
        hit = bvh.ray_cast(p + n * 0.001, n, COVER_REACH)[0]
        if hit is None:
            # Skin close under (or through) the cloth, away from any opening:
            # where the shirt creases at the shoulder seam a ray out along
            # the skin's normal slips past it, and the shoulder showed.
            loc = bvh.find_nearest(p)[0]
            far = openings.find(p)[2] > COVER_OPENING_CLEAR
            hit = loc if (loc is not None and (loc - p).length < COVER_NEAR and far) else None
        covered.append(hit is not None)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.faces.ensure_lookup_table()
    doomed = [f for f in bm.faces if all(covered[v.index] or (mw @ v.co).z < FOOT_HIDDEN_Z
                                         for v in f.verts)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(body.data)
    bm.free()
    print(f"cover_skin: {len(doomed)} faces under cloth removed")


def paint_strands() -> None:
    """Slick hair, strands along v: dense fine parallel strands in clumps,
    lighter caramel ones through them, a wispy fringe of loose ends at v 1
    (the hairline). RGB is the colour; alpha the coverage."""
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter
    rng = np.random.default_rng(HAIR_SEED)
    w = h = HAIR_SIZE
    base = np.zeros((h, w, 3), dtype=np.float32)
    base[:] = HAIR_BASE
    light = Image.new("L", (w, h), 0)
    dark = Image.new("L", (w, h), 0)
    alpha = Image.new("L", (w, h), 255)
    dl, dd = ImageDraw.Draw(light), ImageDraw.Draw(dark)
    for _ in range(900):
        x = rng.uniform(0, w)
        wobble = rng.uniform(0.5, 2.5)
        pts = [(x + wobble * math.sin(t * 6.0 + x), t * h) for t in np.linspace(0, 1, 40)]
        (dl if rng.random() < 0.35 else dd).line(pts, fill=int(rng.integers(60, 200)), width=1)
    light = np.asarray(light.filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float32)[..., None] / 255.0
    dark = np.asarray(dark.filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float32)[..., None] / 255.0
    rgb = base * (1.0 - 0.45 * dark) + (np.array(HAIR_LIGHT, dtype=np.float32) - base) * light * 0.8
    # The hairline fringe: the last 8% thins into separate tapering ends.
    da = ImageDraw.Draw(alpha)
    da.rectangle([0, int(h * 0.92), w, h], fill=0)
    for _ in range(1400):
        x = rng.uniform(0, w)
        end = h * rng.uniform(0.93, 1.0)
        da.line([(x, h * 0.90), (x + rng.normal(0, 1.5), end)], fill=int(rng.integers(140, 255)), width=1)
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.5))
    out = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")
    out.putalpha(alpha)
    out.save(HAIR_STRANDS, optimize=True)


def hairline(angle: float) -> float:
    a, z = zip(*HAIRLINE)
    for i in range(len(a) - 1):
        if a[i] <= angle <= a[i + 1]:
            t = (angle - a[i]) / (a[i + 1] - a[i])
            return z[i] + (z[i + 1] - z[i]) * t
    return z[-1]


def make_cap(old_arm, body, eyes, tie_centre, lobes):
    """The slicked cap, grown from the new head's scalp (see HAIRLINE)."""
    eye_z = (eyes["l"][0].z + eyes["r"][0].z) / 2.0
    centre = (eyes["l"][0] + eyes["r"][0]) / 2.0 + Vector((0.0, 0.075, 0.01))
    mw = body.matrix_world
    head = old_arm.data.bones["Head"]
    # The scalp is the skin that follows the head -- with the nape, which
    # follows the neck: on the Head bone alone the cap stopped above the
    # ears at the back, an undercut.
    head_groups = {body.vertex_groups[n].index for n in ("Head", "neck_01")}
    margin = {}
    for v in body.data.vertices:
        if sum(g.weight for g in v.groups if g.group in head_groups) <= 0.5:
            continue
        p = mw @ v.co
        r = p - centre
        angle = math.degrees(math.atan2(abs(r.x), -r.y))
        m = (p.z - eye_z) - hairline(angle)
        # The ear: a negative margin, so the cap feathers round it rather
        # than stopping on whole faces.
        ear_y = lobes["l" if p.x > 0 else "r"][0].y
        if EAR_Z[0] < p.z - eye_z < EAR_Z[1] and EAR_Y[0] < p.y - ear_y < EAR_Y[1]:
            m = min(m, EAR_X - abs(r.x))
        margin[v.index] = m
    faces = [f for f in body.data.polygons
             if all(i in margin for i in f.vertices) and max(margin[i] for i in f.vertices) > 0.0]
    used = sorted({i for f in faces for i in f.vertices})
    remap = {old: new for new, old in enumerate(used)}
    axis = (tie_centre - centre).normalized()
    e1 = (Vector((0.0, 0.0, 1.0)) - axis * axis.z).normalized()
    e2 = axis.cross(e1)
    verts, uvs, alpha = [], [], []
    for i in used:
        v = body.data.vertices[i]
        p = mw @ v.co
        n = (mw.to_3x3() @ v.normal).normalized()
        verts.append(p + n * CAP_OFF)
        r = (p - centre).normalized()
        phi = math.acos(max(-1.0, min(1.0, r.dot(axis))))
        az = math.atan2(r.dot(e2), r.dot(e1))
        uvs.append(((az / (2.0 * math.pi) + 0.5) * CAP_U_TILES, phi / 2.4))
        t = max(0.0, min(1.0, margin[i] / HAIRLINE_FEATHER))
        alpha.append(t * t * (3.0 - 2.0 * t))
    mesh = bpy.data.meshes.new(CAP)
    mesh.from_pydata(verts, [], [[remap[i] for i in f.vertices] for f in faces])
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        us = [uvs[mesh.loops[li].vertex_index] for li in poly.loop_indices]
        # Faces straddling the wrap of the azimuth: lift the low side.
        lift = CAP_U_TILES if max(u for u, _ in us) - min(u for u, _ in us) > CAP_U_TILES / 2 else 0.0
        for li, (u, vv) in zip(poly.loop_indices, us):
            uv.data[li].uv = (u + lift if u < CAP_U_TILES / 2 and lift else u, 1.0 - vv)
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, a in enumerate(alpha):
        col.data[i].color = (1.0, 1.0, 1.0, a)
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mat = bpy.data.materials.new("M_AubreyHair")
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(HAIR_STRANDS))
    bsdf = nt.nodes["Principled BSDF"]
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    mat.blend_method = "CLIP"
    mesh.materials.append(mat)
    cap = bpy.data.objects.new(CAP, mesh)
    bpy.context.scene.collection.objects.link(cap)
    group = cap.vertex_groups.new(name="Head")
    group.add(list(range(len(verts))), 1.0, "REPLACE")
    cap.parent = old_arm
    cap.matrix_parent_inverse = old_arm.matrix_world.inverted()
    mod = cap.modifiers.new("Armature", "ARMATURE")
    mod.object = old_arm
    print(f"make_cap: {len(faces)} faces")
    return cap


def make_collar(old_arm, body, shirt):
    """Trims the shirt's ragged neckline and builds a polo collar and a zip
    placket round her neck (see COLLAR_PROFILE)."""
    from mathutils.bvhtree import BVHTree
    trim = next(m for m in shirt.data.materials if m and m.name.startswith(TRIM_MATERIAL))
    body_bvh = world_bvh([body])
    # The neck's axis at the collar's base: rays inward, averaged.
    def neck_radius(theta, z, centre):
        d = Vector((math.sin(theta), -math.cos(theta), 0.0))
        hit = body_bvh.ray_cast(Vector((centre.x, centre.y, z)) + d * 0.3, -d, 0.3)[0]
        return (hit - Vector((centre.x, centre.y, z))).length if hit else None
    def base_z(theta):
        return COLLAR_Z - COLLAR_TILT * math.cos(theta)

    def radius(theta, centre):
        r = neck_radius(theta, base_z(theta) + COLLAR_SAMPLE_UP, centre)
        return min(r, COLLAR_MAX_R) if r else COLLAR_MAX_R

    centre = Vector((0.0, 0.0, COLLAR_Z))
    for _ in range(3):
        pts = []
        for k in range(COLLAR_STEPS):
            th = 2.0 * math.pi * k / COLLAR_STEPS
            r = radius(th, centre)
            pts.append(Vector((centre.x + math.sin(th) * r, centre.y - math.cos(th) * r, COLLAR_Z)))
        centre = sum(pts, Vector()) / len(pts)
    # Trim the shirt.
    bm = bmesh.new()
    bm.from_mesh(shirt.data)
    mw = shirt.matrix_world
    def above(p):
        rel = p.xy - centre.xy
        th = math.atan2(rel.x, -rel.y)
        return p.z > base_z(th) + COLLAR_TRIM_UP and rel.length < radius(th, centre) + COLLAR_TRIM_R
    # The V starts at the collar's open ends -- their inner corners, at the
    # neck's surface COLLAR_GAP either side -- and runs down to its point.
    # (From the front's base instead, a flat strip of shirt stood between the
    # collar's ends and the V.)
    gap_r = math.radians(COLLAR_GAP)
    v_half = radius(gap_r, centre) * math.sin(gap_r) + 0.003
    v_top = base_z(gap_r) + 0.008
    v_apex = v_top - SHIRT_V[1]

    def in_v(p):
        if p.y > centre.y or p.z < v_apex:
            return False
        return abs(p.x - centre.x) < v_half * (p.z - v_apex) / SHIRT_V[1]
    doomed = [f for f in bm.faces if any(above(mw @ v.co) for v in f.verts)
              or any(in_v(mw @ v.co) for v in f.verts)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(shirt.data)
    bm.free()
    # The collar. Its flap rests ON the shirt: at the back the shirt sits
    # further out over her trapezius than a neck-hugging flap, which ended
    # up inside it.
    shirt_bvh = world_bvh([shirt])

    def shirt_r(theta, z):
        d = Vector((math.sin(theta), -math.cos(theta), 0.0))
        o = Vector((centre.x, centre.y, z))
        hit = shirt_bvh.ray_cast(o + d * 0.3, -d, 0.3)[0]
        return (hit - o).length if hit else 0.0
    gap = math.radians(COLLAR_GAP)
    thetas = [gap + (2.0 * math.pi - 2.0 * gap) * k / (COLLAR_STEPS - 1) for k in range(COLLAR_STEPS)]
    verts, faces = [], []
    for k, th in enumerate(thetas):
        r = radius(th, centre)
        d = Vector((math.sin(th), -math.cos(th), 0.0))
        z0 = base_z(th)
        # The points: the flap's front ends drop.
        edge = 1.0 - min(1.0, min(th - gap, 2.0 * math.pi - gap - th) / math.radians(30.0))
        for j, (h, off) in enumerate(COLLAR_PROFILE):
            drop = COLLAR_POINT_DROP * edge * (j / (len(COLLAR_PROFILE) - 1)) if j >= 4 else 0.0
            z = z0 + h - drop
            if j < 4:
                # The stand hugs the neck at its own height: one radius for
                # the whole band put it inside the skin where the neck
                # flares into the trapezius at the back.
                reach = (neck_radius(th, z, centre) or r) + off
            else:
                # 5 mm proud: at 3 the shirt's stripes flickered through.
                reach = min(max(r + off, shirt_r(th, z) + COLLAR_FLAP_OFF), r + COLLAR_FLAP_MAX)
            verts.append(Vector((centre.x, centre.y, z0 + h - drop)) + d * reach)
    rows = len(COLLAR_PROFILE)
    # The flap lies ON the shirt: each of its points pushed out to at least
    # COLLAR_FLAP_OFF off the shirt's surface, the corrections smoothed
    # round the ring, then the minimum enforced again. (Placed by radius
    # alone, the tee's shoulders came through it in shards.)
    flap = [k * rows + j for k in range(COLLAR_STEPS) for j in range(4, rows)]
    for rnd in range(3):
        push = {}
        for i in flap:
            loc, nor, _, _ = shirt_bvh.find_nearest(verts[i])
            if loc is None:
                continue
            d = (verts[i] - loc).dot(nor)
            if d < COLLAR_FLAP_OFF:
                push[i] = nor * (COLLAR_FLAP_OFF - d)
        if rnd < 2:
            smooth_push = {}
            for i in flap:
                k, j = divmod(i, rows)
                nb = [push.get(kk * rows + j, Vector()) for kk in (k - 1, k + 1) if 0 <= kk < COLLAR_STEPS]
                smooth_push[i] = push.get(i, Vector()) * 0.5 + sum(nb, Vector()) * (0.5 / max(len(nb), 1))
            push = smooth_push
        for i, d in push.items():
            verts[i] = verts[i] + d
    for k in range(COLLAR_STEPS - 1):
        for j in range(rows - 1):
            a = k * rows + j
            faces.append((a, a + rows, a + rows + 1, a + 1))
    # The placket: the zip tape and its metal track, laid on the shirt (and
    # her skin where the shirt is cut away under the collar), from just
    # under the collar's points down.
    front_bvh = world_bvh([shirt, body])
    top = v_apex
    mats = [0] * len(faces)
    # The V's edges, bound in the trim: a narrow band down each from the
    # collar's base to the point, laid on shirt and skin.
    for sign in (-1.0, 1.0):
        rows = []
        for k in range(9):
            t = k / 8.0
            z = v_top + (v_apex - v_top) * t
            x_edge = sign * v_half * (1.0 - t)
            row = []
            for dx in (-sign * 0.002, sign * SHIRT_V_EDGE):
                hit, nor, _, _ = front_bvh.ray_cast(Vector((centre.x + x_edge + dx, -0.5, z)),
                                                    Vector((0.0, 1.0, 0.0)), 1.0)
                row.append(hit + nor * 0.0025)
            rows.append(row)
        base = len(verts)
        for row in rows:
            verts.extend(row)
        for i in range(len(rows) - 1):
            a = base + 2 * i
            faces.append((a, a + 1, a + 3, a + 2) if sign > 0 else (a, a + 2, a + 3, a + 1))
            mats.append(0)

    def strip_down(half_w, off, mat):
        z = top
        rows = []
        while z >= PLACKET_BOTTOM:
            row = []
            for x in (-half_w, half_w):
                hit, nor, _, _ = front_bvh.ray_cast(Vector((centre.x + x, -0.5, z)), Vector((0.0, 1.0, 0.0)), 1.0)
                row.append(hit + nor * off)
            rows.append(row)
            z -= 0.01
        base = len(verts)
        for row in rows:
            verts.extend(row)
        for i in range(len(rows) - 1):
            a = base + 2 * i
            faces.append((a, a + 1, a + 3, a + 2))
            mats.append(mat)

    strip_down(PLACKET_HALF_W, 0.002, 0)
    strip_down(ZIP_HALF_W, 0.0028, 1)
    # The pull: a small tab hanging from the top of the track.
    hit, nor, _, _ = front_bvh.ray_cast(Vector((centre.x, -0.5, top - 0.004)), Vector((0.0, 1.0, 0.0)), 1.0)
    p0 = hit + nor * 0.0034
    base = len(verts)
    w, h = ZIP_PULL[0] / 2.0, ZIP_PULL[1]
    verts.extend([p0 + Vector((-w, 0.0, 0.0)), p0 + Vector((w, 0.0, 0.0)),
                  p0 + Vector((w, -0.001, -h)), p0 + Vector((-w, -0.001, -h))])
    faces.append((base, base + 1, base + 2, base + 3))
    mats.append(1)
    mesh = bpy.data.meshes.new("Aubrey_Collar")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.uv_layers.new(name="UVMap")
    mesh.materials.append(trim)
    zip_mat = bpy.data.materials.new("M_Zip")
    zip_mat.use_nodes = True
    bsdf = zip_mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.62, 0.63, 0.66, 1.0)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.3
    mesh.materials.append(zip_mat)
    for poly, m in zip(mesh.polygons, mats):
        poly.material_index = m
    collar = bpy.data.objects.new("Aubrey_Collar", mesh)
    bpy.context.scene.collection.objects.link(collar)
    collar.parent = old_arm
    collar.matrix_parent_inverse = old_arm.matrix_world.inverted()
    mod = collar.modifiers.new("Armature", "ARMATURE")
    mod.object = old_arm
    take_weights(collar, body)
    print(f"make_collar: neck at {tuple(round(c, 3) for c in centre)}, {len(faces)} faces")
    return collar


def make_eyes(old_arm, eyes):
    """Both eyeballs in one mesh (Aubrey_Eyes), front-projected UVs centred on
    each line of sight, rigid on her Head bone. The spheres are written out
    vertex by vertex: as two objects the glTF exporter shared (or not) one
    index buffer between them run to run, joined they came out in selection
    order, and bmesh's create_uvsphere orders its faces differently each run
    -- any of which kept the file from being byte-identical."""
    import math
    seg_u, seg_v = EYE_SEGMENTS
    verts, faces, uvs = [], [], []
    for side in ("l", "r"):
        centre, forward = eyes[side]
        rot = Vector((0.0, 0.0, 1.0)).rotation_difference(forward).to_matrix()
        right = Vector((1.0, 0.0, 0.0))
        up = forward.cross(right).normalized()
        right = up.cross(forward).normalized()
        base = len(verts)
        # Poles at the local z ends, seg_v - 1 rings between them.
        local = [Vector((0.0, 0.0, EYE_RADIUS))]
        for ring in range(1, seg_v):
            th = math.pi * ring / seg_v
            for k in range(seg_u):
                ph = 2.0 * math.pi * k / seg_u
                local.append(Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph),
                                     math.cos(th))) * EYE_RADIUS)
        local.append(Vector((0.0, 0.0, -EYE_RADIUS)))
        verts += [centre + rot @ v for v in local]
        ring_at = lambda ring, k: base + 1 + (ring - 1) * seg_u + k % seg_u
        bottom = base + len(local) - 1
        for k in range(seg_u):
            faces.append((base, ring_at(1, k), ring_at(1, k + 1)))
            for ring in range(1, seg_v - 1):
                faces.append((ring_at(ring, k), ring_at(ring + 1, k),
                              ring_at(ring + 1, k + 1), ring_at(ring, k + 1)))
            faces.append((ring_at(seg_v - 1, k), bottom, ring_at(seg_v - 1, k + 1)))
        for i in range(base, len(verts)):
            p = verts[i] - centre
            uvs.append((0.5 + p.dot(right) * 1000.0 / EYE_MM_PER_UV,
                        0.5 - p.dot(up) * 1000.0 / EYE_MM_PER_UV))
    mesh = bpy.data.meshes.new("Aubrey_Eyes")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        layer.data[loop.index].uv = uvs[loop.vertex_index]
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.materials.append(image_material("MI_AubreyEyes", EYE_COLOR, roughness=0.05))
    mesh.update()
    eye = bpy.data.objects.new("Aubrey_Eyes", mesh)
    bpy.context.scene.collection.objects.link(eye)
    group = eye.vertex_groups.new(name="Head")
    group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
    eye.parent = old_arm
    eye.matrix_parent_inverse = old_arm.matrix_world.inverted()
    mod = eye.modifiers.new("Armature", "ARMATURE")
    mod.object = old_arm
    return [eye]


def image_material(name: str, path: pathlib.Path, roughness: float, alpha: bool = False):
    """A Principled material on one image (its alpha too, if asked)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(path))
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if alpha:
        mat.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        mat.blend_method = "BLEND"
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def rigid_on_head(obj, old_arm) -> None:
    """Parent obj to her skeleton, every vertex on the Head bone."""
    from mathutils import Matrix
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.data.transform(world)
    obj.matrix_world = Matrix.Identity(4)
    obj.vertex_groups.clear()
    group = obj.vertex_groups.new(name="Head")
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    obj.parent = old_arm
    obj.matrix_parent_inverse = old_arm.matrix_world.inverted()
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = old_arm


def bake_world(obj) -> None:
    """Unparents obj with its world transform applied to its mesh."""
    from mathutils import Matrix
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.data.transform(world)
    obj.matrix_world = Matrix.Identity(4)


def split_by_height(obj, z: float):
    """Splits obj's connected pieces: those centred above z stay, the rest
    become a new object; returns (upper, lower)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    seen, upper = set(), set()
    for start in bm.verts:
        if start.index in seen:
            continue
        piece, stack = [], [start]
        seen.add(start.index)
        while stack:
            v = stack.pop()
            piece.append(v.index)
            for e in v.link_edges:
                o = e.other_vert(v)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        if sum(bm.verts[i].co.z for i in piece) / len(piece) > z:
            upper.update(piece)
    bm.free()
    lower = obj.copy()
    lower.data = obj.data.copy()
    bpy.context.scene.collection.objects.link(lower)
    for target, keep in ((obj, True), (lower, False)):
        bm = bmesh.new()
        bm.from_mesh(target.data)
        doomed = [v for v in bm.verts if (v.index in upper) != keep]
        bmesh.ops.delete(bm, geom=doomed, context="VERTS")
        bm.to_mesh(target.data)
        bm.free()
    return obj, lower


def apply_subdivision(obj, levels: int = 1) -> None:
    mod = obj.modifiers.new("Subdivision", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def shape_trousers(trousers, old_arm) -> None:
    """Raises the jeans' waist to the belt, lengthens and straightens the
    legs (TROUSER_*)."""
    import math
    mw = trousers.matrix_world
    inv = mw.inverted()
    pts = [mw @ v.co for v in trousers.data.vertices]
    # The top edge's height by angle round the waist.
    bins = 24
    top = [TROUSER_WAIST_FROM] * bins
    angle_bin = lambda p: int((math.atan2(p.x, -(p.y - 0.02)) + math.pi) / (2 * math.pi) * bins) % bins
    for p in pts:
        b = angle_bin(p)
        top[b] = max(top[b], p.z)
    legs = {}
    for side in ("l", "r"):
        hip = old_arm.matrix_world @ old_arm.data.bones[f"thigh_{side}"].head_local
        ankle = old_arm.matrix_world @ old_arm.data.bones[f"calf_{side}"].tail_local
        legs[side] = (hip, ankle)
    bottom = min(p.z for p in pts)
    stretch = (TROUSER_KNEE - TROUSER_HEM) / (TROUSER_KNEE - bottom)
    for v, p in zip(trousers.data.vertices, pts):
        q = p.copy()
        t = top[angle_bin(p)]
        if p.z > TROUSER_WAIST_FROM and t > TROUSER_WAIST_FROM + 0.01:
            q.z = TROUSER_WAIST_FROM + (p.z - TROUSER_WAIST_FROM) * (
                (TROUSER_WAIST - TROUSER_WAIST_FROM) / (t - TROUSER_WAIST_FROM))
        if p.z < TROUSER_KNEE:
            q.z = TROUSER_KNEE - (TROUSER_KNEE - p.z) * stretch
        if q.z < TROUSER_LEG_FROM[0]:
            hip, ankle = legs["l" if p.x > 0 else "r"]
            f = (hip.z - q.z) / (hip.z - ankle.z)
            axis = hip.lerp(ankle, f)
            radial = (q - axis).to_2d()
            r = radial.length
            w = float(_smooth(TROUSER_LEG_FROM[0], TROUSER_LEG_FROM[1], q.z))
            target = TROUSER_LEG_R * w
            soft = (r + target + math.sqrt((r - target) ** 2 + 0.01 ** 2)) / 2.0
            if r > 1e-6:
                q.x, q.y = (axis.to_2d() + radial * (soft / r))
        v.co = inv @ q
    trousers.data.update()


def make_garments(human, old_arm) -> None:
    """Her shirt, trousers and shoes from MakeHuman's CC0 clothes, fitted to
    her by MPFB (after the targets and the fitting pose), split, subdivided
    once and named as the kit's were."""
    HumanService = mpfb("services.humanservice", "HumanService")
    clothes = MPFB_ASSETS / "unpacked_makehuman_system_assets/clothes"
    made = {}
    for name in (SUIT, SHOES):
        obj = HumanService.add_mhclo_asset(str(clothes / name / f"{name}.mhclo"), human,
                                           asset_type="Clothes", subdiv_levels=0,
                                           set_up_rigging=False)
        for mod in list(obj.modifiers):
            obj.modifiers.remove(mod)
        if obj.data.shape_keys:
            obj.shape_key_clear()
        bake_world(obj)
        obj.vertex_groups.clear()
        made[name] = obj
    hips = old_arm.matrix_world @ old_arm.data.bones["pelvis"].head_local
    shirt, trousers = split_by_height(made[SUIT], hips.z + 0.12)
    shape_trousers(trousers, old_arm)
    for obj, name in ((shirt, "Aubrey_Shirt"), (trousers, "Aubrey_Trousers"),
                      (made[SHOES], "Aubrey_Shoes")):
        obj.name = obj.data.name = name
        apply_subdivision(obj)
        for poly in obj.data.polygons:
            poly.use_smooth = True
        zs = [v.co.z for v in obj.data.vertices]
        print(f"garment {name}: z {min(zs):.3f}..{max(zs):.3f}, {len(zs)} verts")
    for vg in list(human.vertex_groups):
        if vg.name.startswith("Delete."):
            human.vertex_groups.remove(vg)


def garment_textures() -> None:
    """The trousers' and trainers' textures and the suit's normal map, from
    MakeHuman's own, written next to the model."""
    import numpy as np
    from PIL import Image
    clothes = MPFB_ASSETS / "unpacked_makehuman_system_assets/clothes"
    for src, out, tone in ((clothes / SUIT / f"{SUIT}_diffuse.png", TROUSERS_TEX, TROUSERS_TONE),
                           (clothes / SHOES / f"{SHOES}_diffuse.png", SHOES_TEX, SHOES_TONE)):
        rgb = np.asarray(Image.open(src).convert("RGB"), np.float32)
        lum = rgb.mean(-1, keepdims=True) / 255.0
        img = np.array(tone[:3], np.float32) + lum * tone[3]
        im = Image.fromarray(np.clip(np.round(img), 0, 255).astype(np.uint8), "RGB")
        if out.suffix == ".jpg":
            im.save(out, quality=90, optimize=True)
        else:
            im.save(out, optimize=True)
    normal = Image.open(clothes / SUIT / f"{SUIT}_normal.png").convert("RGB")
    normal.resize((SUIT_NORMAL_SIZE, SUIT_NORMAL_SIZE), Image.LANCZOS).save(SUIT_NORMAL, optimize=True)


def paint_stripes(shirt, old_arm) -> None:
    """The shirt's stripes, in its UV space from 3D position (STRIPE_W)."""
    import numpy as np
    from PIL import Image
    size = 2048
    pos, _, hit = position_map(shirt, size, -10.0, group=None)
    x, y, z = pos[..., 0], pos[..., 1], pos[..., 2]
    spine = old_arm.matrix_world @ old_arm.data.bones["spine_02"].head_local
    arm = old_arm.matrix_world @ old_arm.data.bones["upperarm_l"].head_local
    # Torso: the tee's front and back are separate pieces (UV islands, the
    # left and right halves of its upper atlas), meeting at its side seams.
    # Each is striped by angle round an axis well behind it (the front) or
    # in front of it (the back), times that distance: straight down the
    # middle, wrapping round the sides, every band its true width at the
    # centre line. (By x alone the sides were one solid band; panels by y
    # made blotches over the chest.)
    px = (np.arange(size) + 0.5) / size
    uu, vv = np.meshgrid(px, 1.0 - px)
    left = uu < 0.5
    left_y = y[hit & left & (vv > 0.5)].mean()
    right_y = y[hit & ~left & (vv > 0.5)].mean()
    front = left if left_y < right_y else ~left
    reach = TORSO_AXIS_BACK
    s_front = np.arctan2(x, -(y - (spine.y + reach))) * (reach + 0.10)
    s_back = np.arctan2(x, y - (spine.y - reach)) * (reach + 0.10)
    s_torso = np.where(front, s_front, s_back)
    # Sleeves: arc length round the arm's axis -- down the sleeve.
    s_sleeve = np.arctan2(z - arm.z, -(y - arm.y)) * 0.05
    # The sleeves are the tee's own sleeve pieces: their UV island, found as
    # the box round the faces well out along the arm. (By |x| alone, the top
    # of the shoulder took the sleeves' pattern in blotches.)
    uvs = shirt.data.uv_layers["UVMap"].data
    island = [uvs[li].uv for poly in shirt.data.polygons
              if abs((shirt.matrix_world @ poly.center).x) > SLEEVE_X + 0.06
              for li in poly.loop_indices]
    u0 = min(u.x for u in island) - 0.01
    u1 = max(u.x for u in island) + 0.01
    v0 = min(u.y for u in island) - 0.01
    v1 = max(u.y for u in island) + 0.01
    sleeve = (uu > u0) & (uu < u1) & (vv > v0) & (vv < v1)
    s = np.where(sleeve, s_sleeve, s_torso)
    wave = np.cos(np.pi * s / STRIPE_W)
    black = _smooth(-0.12, 0.12, wave)
    end = max(abs((shirt.matrix_world @ v.co).x) for v in shirt.data.vertices)
    black = np.where(sleeve & (np.abs(x) > end - CUFF_W), 1.0, black)
    img = (np.array(STRIPE_WHITE, np.float32) * (1.0 - black[..., None])
           + np.array(STRIPE_BLACK, np.float32) * black[..., None])
    img[~hit] = STRIPE_WHITE
    Image.fromarray(np.round(img).astype(np.uint8), "RGB").save(SHIRT_TEX, optimize=True)


def garment_material(name: str, color: pathlib.Path, roughness: float, normal=None):
    mat = image_material(name, color, roughness)
    if normal is not None:
        nodes = mat.node_tree.nodes
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(normal))
        tex.image.colorspace_settings.name = "Non-Color"
        nmap = nodes.new("ShaderNodeNormalMap")
        mat.node_tree.links.new(tex.outputs["Color"], nmap.inputs["Color"])
        mat.node_tree.links.new(nmap.outputs["Normal"], nodes["Principled BSDF"].inputs["Normal"])
    return mat


def drape_shirt(shirt, old_arm) -> None:
    """Lets the shirt hang straight from the bust to the belt (SHIRT_DRAPE)."""
    spine = old_arm.matrix_world @ old_arm.data.bones["spine_02"].head_local
    mw = shirt.matrix_world
    inv = mw.inverted()
    bins = 48
    pts = [mw @ v.co for v in shirt.data.vertices]

    def polar(p):
        dx, dy = p.x, p.y - spine.y
        a = math.atan2(dx, -dy)
        return int((a + math.pi) / (2.0 * math.pi) * bins) % bins, math.hypot(dx, dy)

    reach = [0.0] * bins
    for p in pts:
        if abs(p.z - SHIRT_DRAPE_FROM) < 0.03 and abs(p.x) < SLEEVE_X:
            b, r = polar(p)
            reach[b] = max(reach[b], r)
    reach = [max(reach[b - 1], reach[b], reach[(b + 1) % bins]) for b in range(bins)]
    for v, p in zip(shirt.data.vertices, pts):
        if not (BELT_TOP - TUCK_UNDER < p.z < SHIRT_DRAPE_FROM) or abs(p.x) >= SLEEVE_X:
            continue
        b, r = polar(p)
        if reach[b] <= 0.0:
            continue
        t = float(_smooth(BELT_TOP, BELT_TOP + SHIRT_DRAPE_GATHER, p.z))
        # ...and in from nothing over the SHIRT_DRAPE_EASE below where the
        # reach is taken: let out at full strength right up to it, the cloth
        # stepped out at the shoulder blades in a crease, the stripes jogging.
        t *= float(_smooth(SHIRT_DRAPE_FROM, SHIRT_DRAPE_FROM - SHIRT_DRAPE_EASE, p.z))
        target = r + (reach[b] * SHIRT_DRAPE - r) * t
        if target > r:
            k = target / r
            v.co = inv @ Vector((p.x * k, spine.y + (p.y - spine.y) * k, p.z))
    shirt.data.update()


def tuck_shirt(shirt) -> None:
    """Cuts the shirt away under the belt: tucked in."""
    cut = BELT_TOP - TUCK_UNDER
    bm = bmesh.new()
    bm.from_mesh(shirt.data)
    doomed = [f for f in bm.faces if all((shirt.matrix_world @ v.co).z < cut for v in f.verts)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(shirt.data)
    bm.free()


def dress_garments(old_arm) -> None:
    objects = bpy.data.objects
    shirt, trousers, shoes = (objects[n] for n in ("Aubrey_Shirt", "Aubrey_Trousers", "Aubrey_Shoes"))
    tuck_shirt(shirt)
    drape_shirt(shirt, old_arm)
    garment_textures()
    paint_stripes(shirt, old_arm)
    trim = bpy.data.materials[TRIM_MATERIAL]
    shirt.data.materials.clear()
    shirt.data.materials.append(garment_material("M_RefStripes", SHIRT_TEX, 0.8))
    shirt.data.materials.append(trim)
    trousers.data.materials.clear()
    trousers.data.materials.append(garment_material("M_Trousers", TROUSERS_TEX, 0.85, SUIT_NORMAL))
    shoes.data.materials.clear()
    shoes.data.materials.append(garment_material("M_Shoes", SHOES_TEX, 0.6))


def make_belt(old_arm, body):
    """The belt round the trousers (rays in from outside at BELT_STEPS
    angles, BELT_OFF proud), its square buckle at the front and the radio
    pack at the back right; one mesh, weighted from the body."""
    import math
    objects = bpy.data.objects
    bvh = world_bvh([objects["Aubrey_Trousers"], objects["Aubrey_Shirt"]])
    rows = (BELT_TOP - BELT_H, BELT_TOP - BELT_H / 2.0, BELT_TOP)
    ring = []
    for z in rows:
        pts = [Vector((0.0, 0.0, z))]
        hits = []
        for k in range(BELT_STEPS):
            a = 2.0 * math.pi * k / BELT_STEPS
            d = Vector((math.sin(a), -math.cos(a), 0.0))
            loc = bvh.ray_cast(Vector((0.0, 0.02, z)) + d * 0.5, -d, 0.5)[0]
            hits.append(loc)
        ring.append(hits)
    # One radius per angle (the widest row), so the band stands straight.
    centre = Vector((0.0, 0.02, 0.0))
    radius = []
    for k in range(BELT_STEPS):
        r = max(((h - centre).to_2d().length for h in (row[k] for row in ring) if h is not None),
                default=0.15)
        radius.append(r + BELT_OFF)
    radius = [(radius[k - 1] + 2.0 * radius[k] + radius[(k + 1) % BELT_STEPS]) / 4.0
              for k in range(BELT_STEPS)]
    verts, faces, mats = [], [], []

    def band_point(k, z, out):
        a = 2.0 * math.pi * k / BELT_STEPS
        r = radius[k % BELT_STEPS] + out
        return Vector((math.sin(a) * r, centre.y - math.cos(a) * r, z))

    z0, z1 = BELT_TOP - BELT_H, BELT_TOP
    # Cross-section loop: inner bottom, outer bottom, outer top, inner top.
    section = [(z0, 0.0), (z0, BELT_THICK), (z1, BELT_THICK), (z1, 0.0)]
    for k in range(BELT_STEPS):
        for z, out in section:
            verts.append(band_point(k, z, out))
    for k in range(BELT_STEPS):
        a, b = k * 4, ((k + 1) % BELT_STEPS) * 4
        for j in range(4):
            jn = (j + 1) % 4
            faces.append((a + j, b + j, b + jn, a + jn))
            mats.append(0)

    def box(c, half, axes, mat):
        """A box centred at c, half-extents along three axes."""
        base = len(verts)
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    verts.append(c + axes[0] * half[0] * sx + axes[1] * half[1] * sy
                                 + axes[2] * half[2] * sz)
        for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            faces.append(tuple(base + i for i in f))
            mats.append(mat)

    front = band_point(0, (z0 + z1) / 2.0, BELT_THICK + 0.003)
    right, up, out = Vector((1.0, 0.0, 0.0)), Vector((0.0, 0.0, 1.0)), Vector((0.0, -1.0, 0.0))
    hw, hh, bar = BUCKLE_W / 2.0, BUCKLE_H / 2.0, BUCKLE_BAR / 2.0
    depth = 0.002
    for c, half in ((front + up * (hh - bar), (hw, depth, bar)),
                    (front - up * (hh - bar), (hw, depth, bar)),
                    (front + right * (hw - bar), (bar, depth, hh - 2 * bar)),
                    (front - right * (hw - bar), (bar, depth, hh - 2 * bar))):
        box(c, half, (right, out, up), 1)
    a = math.radians(-PACK_ANGLE)
    k = PACK_ANGLE / 360.0 * BELT_STEPS
    r = radius[int(round(-k)) % BELT_STEPS] + BELT_THICK + PACK_SIZE[2] / 2.0
    d = Vector((math.sin(a), -math.cos(a), 0.0))
    side = Vector((-d.y, d.x, 0.0))
    c = Vector((0.0, centre.y, BELT_TOP + 0.008 - PACK_SIZE[1] / 2.0)) + d * r
    box(c, (PACK_SIZE[0] / 2.0, PACK_SIZE[2] / 2.0, PACK_SIZE[1] / 2.0), (side, d, up), 2)
    mesh = bpy.data.meshes.new("Aubrey_Belt")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    for poly, m in zip(mesh.polygons, mats):
        poly.material_index = m
    for name, color, metal, rough in (("M_Belt", (0.018, 0.018, 0.018, 1.0), 0.0, 0.42),
                                      ("M_Buckle", (0.86, 0.87, 0.89, 1.0), 1.0, 0.18),
                                      ("M_RadioPack", (0.025, 0.025, 0.027, 1.0), 0.0, 0.6)):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
        mesh.materials.append(mat)
    mesh.update()
    belt = bpy.data.objects.new("Aubrey_Belt", mesh)
    bpy.context.scene.collection.objects.link(belt)
    belt.parent = old_arm
    belt.matrix_parent_inverse = old_arm.matrix_world.inverted()
    take_weights(belt, body)
    belt.modifiers.new("Armature", "ARMATURE").object = old_arm
    return belt


def ponytail_radius(t: float) -> float:
    for (t0, r0), (t1, r1) in zip(PONYTAIL_R, PONYTAIL_R[1:]):
        if t0 <= t <= t1:
            return r0 + (r1 - r0) * (t - t0) / (t1 - t0)
    return PONYTAIL_R[-1][1]


def make_ponytail(old_arm, tie_centre):
    """The ponytail (PONYTAIL_*), weighted along its re-laid spring bones."""
    objects = bpy.data.objects
    under = world_bvh([o for o in objects if o.type == "MESH" and o.name in
                       ("Aubrey_Body", "Aubrey_Shirt", "Aubrey_Collar", CAP)])
    # The path: from the tie, each step down the surface behind her.
    path = [tie_centre.copy()]
    z = tie_centre.z - 0.01
    while z > PONYTAIL_TIP_Z:
        hit = under.ray_cast(Vector((0.0, 0.6, z)), Vector((0.0, -1.0, 0.0)), 1.0)[0]
        y = hit.y if hit is not None else path[-1].y
        path.append(Vector((0.0, y, z)))
        z -= 0.01
    # Off the surface by the hair's own radius, smoothed, and never in front
    # of the tie's line at the top.
    length = [0.0]
    for a, b in zip(path, path[1:]):
        length.append(length[-1] + (b - a).length)
    for i in range(1, len(path)):
        t = length[i] / length[-1]
        path[i].y += ponytail_radius(t) * PONYTAIL_FLAT[1] + PONYTAIL_GAP
        path[i].y = max(path[i].y, tie_centre.y + 0.02 * min(1.0, i / 4.0))
    for _ in range(6):
        path = [path[0]] + [(path[i - 1] + path[i] * 2.0 + path[i + 1]) / 4.0
                            for i in range(1, len(path) - 1)] + [path[-1]]
    length = [0.0]
    for a, b in zip(path, path[1:]):
        length.append(length[-1] + (b - a).length)
    total = length[-1]

    def at(s):
        for i in range(len(path) - 1):
            if length[i] <= s <= length[i + 1]:
                f = (s - length[i]) / max(length[i + 1] - length[i], 1e-9)
                return path[i].lerp(path[i + 1], f), (path[i + 1] - path[i]).normalized()
        return path[-1], (path[-1] - path[-2]).normalized()

    # The spring bones, equal lengths along the path.
    n_bones = len(PONYTAIL_BONES)
    bpy.context.view_layer.objects.active = old_arm
    bpy.ops.object.mode_set(mode="EDIT")
    inv = old_arm.matrix_world.inverted()
    for k, name in enumerate(PONYTAIL_BONES):
        eb = old_arm.data.edit_bones[name]
        eb.head = inv @ at(total * k / n_bones)[0]
        eb.tail = inv @ at(total * (k + 1) / n_bones)[0]
    bpy.ops.object.mode_set(mode="OBJECT")
    # The tube.
    verts, uvs, faces, weights = [], [], [], []
    side = Vector((1.0, 0.0, 0.0))
    for j in range(PONYTAIL_RINGS + 1):
        t = j / PONYTAIL_RINGS
        c, tangent = at(total * t)
        n = (side - tangent * side.dot(tangent)).normalized()
        b = tangent.cross(n)
        r = ponytail_radius(t)
        twist = 0.6 * t
        for k in range(PONYTAIL_SIDES + 1):
            a = 2.0 * math.pi * k / PONYTAIL_SIDES + twist
            wave = 1.0 + 0.06 * math.sin(3.0 * a + 9.0 * t)
            p = c + (n * math.cos(a) * PONYTAIL_FLAT[0]
                     + b * math.sin(a) * PONYTAIL_FLAT[1]) * r * wave
            # Toward her (-y): pressed onto her, in or out, so the tail lies
            # on her head and back -- seen from the side, no daylight.
            toward = max(0.0, (c - p).y / max(r * PONYTAIL_FLAT[1], 1e-6))
            if toward > 0.0:
                hit = under.ray_cast(Vector((p.x, c.y + 0.05, p.z)), Vector((0.0, -1.0, 0.0)), 0.3)[0]
                if hit is not None:
                    p.y += (hit.y + PONYTAIL_HUG - p.y) * toward
            verts.append(p)
            uvs.append((k / PONYTAIL_SIDES * PONYTAIL_U_TILES, 1.0 - t))
        # Weights: linear between the two nearest bones' midpoints.
        x = t * n_bones - 0.5
        lo = max(0, min(n_bones - 1, math.floor(x)))
        hi = min(n_bones - 1, lo + 1)
        f = max(0.0, min(1.0, x - lo))
        weights.append(((PONYTAIL_BONES[lo], 1.0 - f), (PONYTAIL_BONES[hi], f)))
    ring = PONYTAIL_SIDES + 1
    for j in range(PONYTAIL_RINGS):
        for k in range(PONYTAIL_SIDES):
            a = j * ring + k
            faces.append((a, a + 1, a + ring + 1, a + ring))
    mesh = bpy.data.meshes.new("Aubrey_Ponytail")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        layer.data[loop.index].uv = uvs[loop.vertex_index]
    col = mesh.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i in range(len(verts)):
        col.data[i].color = (1.0, 1.0, 1.0, 1.0)
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.materials.append(bpy.data.materials["M_AubreyHair"])
    mesh.update()
    tail = bpy.data.objects.new("Aubrey_Ponytail", mesh)
    bpy.context.scene.collection.objects.link(tail)
    groups = {name: tail.vertex_groups.new(name=name) for name in PONYTAIL_BONES}
    for j, pair in enumerate(weights):
        idx = list(range(j * ring, (j + 1) * ring))
        for name, w in pair:
            if w > 0.0:
                groups[name].add(idx, w, "ADD")
    tail.parent = old_arm
    tail.matrix_parent_inverse = old_arm.matrix_world.inverted()
    tail.modifiers.new("Armature", "ARMATURE").object = old_arm
    print(f"make_ponytail: {total:.3f} m, tip at z {path[-1].z:.3f}")
    return tail


def taper_waist(human) -> None:
    """Narrows the body side to side round WAIST_Z (see WAIST_SLIM)."""
    mw = human.matrix_world
    inv = mw.inverted()
    for v in human.data.vertices:
        p = mw @ v.co
        k = WAIST_SLIM * math.exp(-0.5 * ((p.z - WAIST_Z) / WAIST_SIGMA) ** 2)
        v.co = inv @ Vector((p.x * (1.0 - k), p.y, p.z))
    human.data.update()


def slim_neck(human, old_arm) -> None:
    """Draws the neck's skin toward its axis (NECK_SLIM by neck weight)."""
    group = human.vertex_groups["neck_01"].index
    head = old_arm.matrix_world @ old_arm.data.bones["neck_01"].head_local
    tail = old_arm.matrix_world @ old_arm.data.bones["neck_01"].tail_local
    mw = human.matrix_world
    inv = mw.inverted()
    for v in human.data.vertices:
        w = next((g.weight for g in v.groups if g.group == group), 0.0)
        if w <= 0.0:
            continue
        p = mw @ v.co
        f = max(0.0, min(1.0, (p.z - head.z) / (tail.z - head.z))) if tail.z != head.z else 0.0
        axis = head.lerp(tail, f)
        radial = Vector((p.x - axis.x, p.y - axis.y, 0.0))
        v.co = inv @ (p - radial * (NECK_SLIM * w))
    human.data.update()


def place_patch(body) -> None:
    """The patch onto the shirt -- once the shirt has its final shape (after
    the drape: placed before it, the shirt came out through it)."""
    # The patch onto the new shirt: each vertex straight back along the
    # line she faces until it is PATCH_OFF in front of the shirt -- one
    # direction for all, so it lies on her like a sewn patch. (To the
    # nearest point, its corner folded over the curve of her chest.)
    objects = bpy.data.objects
    shirt_bvh = world_bvh([objects["Aubrey_Shirt"]])
    patch = objects[PATCH]
    inv = patch.matrix_world.inverted()
    # On her right chest, as the sheet's pictures show it (its caption says
    # left; the owner went by the pictures): the kit's patch, on her left,
    # is mirrored across her -- positions only, so the UVs and the logo
    # still read the right way round -- and its faces turned back out.
    # Then the sheet's size and place: PATCH_SCALE about its centre, the
    # centre moved to PATCH_CENTRE.
    pts = [patch.matrix_world @ v.co for v in patch.data.vertices]
    lo = Vector((min(p.x for p in pts), 0.0, min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), 0.0, max(p.z for p in pts)))
    mid = (lo + hi) / 2.0
    for v, p in zip(patch.data.vertices, pts):
        q = Vector((PATCH_CENTRE[0], p.y, PATCH_CENTRE[1])) + Vector(
            (-(p.x - mid.x), 0.0, p.z - mid.z)) * PATCH_SCALE
        v.co = inv @ q
    # Mirroring the positions mirrored the artwork too: mirror its u back.
    uv = patch.data.uv_layers[0].data
    us = [d.uv.x for d in uv]
    u_mid = (min(us) + max(us)) / 2.0
    for d in uv:
        d.uv.x = 2.0 * u_mid - d.uv.x
    bm = bmesh.new()
    bm.from_mesh(patch.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    # Fine enough to follow the curve of her chest: at the kit's 35
    # vertices its flat faces cut into the shirt between them.
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=PATCH_CUTS, use_grid_fill=True)
    bm.to_mesh(patch.data)
    bm.free()
    # Wrapped round her rather than pressed straight back: each vertex in
    # along the line from an axis behind her chest (as the stripes are
    # laid), so its outer edge follows the curve of her chest instead of
    # being dragged round the side in a smear.
    axis_y = PATCH_AXIS_Y
    for v in patch.data.vertices:
        p = patch.matrix_world @ v.co
        d = Vector((p.x, p.y - axis_y, 0.0)).normalized()
        o = Vector((0.0, axis_y, p.z)) + d * 0.6
        hit, nor, _, _ = shirt_bvh.ray_cast(o, -d, 0.6)
        if hit is not None:
            v.co = inv @ (hit + d * PATCH_OFF)
    patch.data.update()
    # Its weights from where it now is (taken before the move, they were
    # the left side's).
    take_weights(patch, body)


def make_pocket(old_arm, body):
    """Her chest pocket (POCKET): a panel and a flap laid on the shirt by rays
    from the front, closed down to the shirt round their edges, in the
    shirt's material with the shirt's UVs at each point."""
    shirt = bpy.data.objects["Aubrey_Shirt"]
    bvh = world_bvh([shirt])
    mesh_s = shirt.data
    uvs = mesh_s.uv_layers["UVMap"].data
    mw = shirt.matrix_world

    def on_shirt(x, z, off):
        loc, nor, idx, _ = bvh.ray_cast(Vector((x, -0.5, z)), Vector((0.0, 1.0, 0.0)), 1.0)
        if idx is None:
            raise SystemExit(f"make_pocket: no shirt at x {x:.3f}, z {z:.3f}")
        poly = mesh_s.polygons[idx]
        # The UV there: barycentric weights in whichever of the polygon's fan
        # triangles holds the point (the point projected into its plane).
        # (mathutils' point-in-triangle test wants exact coplanarity; on a
        # bent quad it failed, and the fallback scrambled the stripes.)
        corners = [(mw @ mesh_s.vertices[mesh_s.loops[li].vertex_index].co, uvs[li].uv.copy())
                   for li in poly.loop_indices]
        best, best_err = None, None
        for k in range(1, len(corners) - 1):
            (a, ta), (b, tb), (c, tc) = corners[0], corners[k], corners[k + 1]
            v0, v1, v2 = b - a, c - a, loc - a
            d00, d01, d11 = v0.dot(v0), v0.dot(v1), v1.dot(v1)
            d20, d21 = v2.dot(v0), v2.dot(v1)
            den = d00 * d11 - d01 * d01
            if abs(den) < 1e-18:
                continue
            wb = (d11 * d20 - d01 * d21) / den
            wc = (d00 * d21 - d01 * d20) / den
            wa = 1.0 - wb - wc
            err = -min(wa, wb, wc, 0.0)
            if best_err is None or err < best_err:
                best_err = err
                best = ta * wa + tb * wb + tc * wc
        return loc + nor * off, (best.x, best.y)

    x0, x1, z0, z1 = POCKET
    nx, nz = POCKET_GRID
    verts, uv, faces = [], [], []
    from PIL import Image
    tex = Image.open(SHIRT_TEX).convert("L")
    tw, th = tex.size

    def whiteness(shift):
        total = 0.0
        for j in range(nz + 1):
            for i in range(nx + 1):
                x = x0 + (x1 - x0) * i / nx + shift
                if bvh.ray_cast(Vector((x, -0.5, z0 + (z1 - z0) * j / nz)), Vector((0.0, 1.0, 0.0)), 1.0)[2] is None:
                    return -1.0
                _, (u, v) = on_shirt(x0 + (x1 - x0) * i / nx + shift, z0 + (z1 - z0) * j / nz, 0.0)
                total += tex.getpixel((min(tw - 1, int(u * tw)), min(th - 1, int((1.0 - v) * th))))
        return total
    shift = max(POCKET_STRIPE_SHIFTS, key=whiteness)

    def panel(zb, zt, off, lip):
        """A grid from zb to zt, off proud, its rim stepping down to lip."""
        base = len(verts)
        for j in range(nz + 1):
            z = zb + (zt - zb) * j / nz
            for i in range(nx + 1):
                x = x0 + (x1 - x0) * i / nx
                edge = i in (0, nx) or j in (0, nz)
                p, _ = on_shirt(x, z, lip if edge else off)
                _, t = on_shirt(x + shift, z, 0.0)
                verts.append(p)
                uv.append(t)
        for j in range(nz):
            for i in range(nx):
                a = base + j * (nx + 1) + i
                faces.append((a, a + 1, a + nx + 2, a + nx + 1))

    panel(z0, z1 - POCKET_FLAP * 0.5, POCKET_OFF, 0.0008)
    panel(z1 - POCKET_FLAP, z1, POCKET_OFF * 1.8, POCKET_OFF * 0.9)
    mesh = bpy.data.meshes.new("Aubrey_Pocket")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        layer.data[loop.index].uv = uv[loop.vertex_index]
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.materials.append(shirt.data.materials[0])
    mesh.update()
    pocket = bpy.data.objects.new("Aubrey_Pocket", mesh)
    bpy.context.scene.collection.objects.link(pocket)
    pocket.parent = old_arm
    pocket.matrix_parent_inverse = old_arm.matrix_world.inverted()
    print(f"make_pocket: cloth from {shift * 1000:.0f} mm to the side")
    take_weights(pocket, body)
    pocket.modifiers.new("Armature", "ARMATURE").object = old_arm
    return pocket


def make_cards(human):
    """MakeHuman's brow and lash cards fitted to her face (MPFB fits them to
    the basemesh as it stands, so after the targets and the fitting pose),
    their strand textures recoloured; returns the two objects."""
    import numpy as np
    from PIL import Image
    HumanService = mpfb("services.humanservice", "HumanService")
    cards = []
    for kind, name, obj_name in (("eyebrows", BROWS, "Aubrey_Brows"),
                                 ("eyelashes", LASHES, "Aubrey_Lashes")):
        source = MPFB_ASSETS / "unpacked_makehuman_system_assets" / kind / name
        obj = HumanService.add_mhclo_asset(str(source / f"{name}.mhclo"), human,
                                           asset_type=kind.capitalize(), subdiv_levels=0,
                                           set_up_rigging=False)
        for mod in list(obj.modifiers):
            obj.modifiers.remove(mod)
        if obj.data.shape_keys:
            obj.shape_key_clear()
        obj.name = obj.data.name = obj_name
        out, rgb, gain = CARD_TEXTURES[name]
        strands = np.asarray(Image.open(source / f"{name}.png").convert("RGBA"), np.float32)
        card = np.zeros_like(strands)
        card[..., :3] = rgb
        card[..., 3] = np.clip(strands[..., 3] * gain, 0.0, 255.0)
        Image.fromarray(np.round(card).astype(np.uint8), "RGBA").save(out, optimize=True)
        obj.data.materials.clear()
        mat_name = "M_AubreyBrows" if kind == "eyebrows" else "M_AubreyLashes"
        obj.data.materials.append(image_material(mat_name, out, roughness=0.6, alpha=True))
        for poly in obj.data.polygons:
            poly.use_smooth = True
        cards.append(obj)
    # MPFB adds a delete group per card to the basemesh; it masks nothing here.
    for vg in list(human.vertex_groups):
        if vg.name.startswith("Delete."):
            human.vertex_groups.remove(vg)
    return cards


def ear_lobes(human):
    """Each earlobe's outer face, from MPFB's "ears" group: the lowest
    centimetre of each ear, its outermost point there; ({"l"/"r": point},
    outward normal)."""
    group = human.vertex_groups["ears"].index
    lobes = {}
    for side, sign in (("l", 1.0), ("r", -1.0)):
        pts = [human.matrix_world @ v.co for v in human.data.vertices
               if v.co.x * sign > 0 and any(g.group == group and g.weight > 0.5 for g in v.groups)]
        bottom = min(p.z for p in pts)
        low = [p for p in pts if p.z < bottom + 0.006]
        outer = max(low, key=lambda p: p.x * sign)
        centre = sum(low, Vector()) / len(low)
        lobes[side] = (Vector((outer.x, centre.y, bottom + 0.004)), Vector((sign, 0.0, 0.0)))
    return lobes


def make_studs(old_arm, lobes):
    """A small brilliant in each lobe: an eight-sided crown and pavilion,
    written out vertex by vertex (deterministic), facing outward."""
    import math
    verts, faces = [], []
    n = 8
    for side in ("l", "r"):
        point, normal = lobes[side]
        centre = point + normal * STUD_PROUD
        base = len(verts)
        up = Vector((0.0, 0.0, 1.0))
        side_axis = normal.cross(up).normalized()
        r = STUD_RADIUS
        verts.append(centre + normal * r * 0.55)                 # table centre
        for k in range(n):                                         # table ring
            a = 2.0 * math.pi * k / n
            verts.append(centre + normal * r * 0.55
                         + (up * math.cos(a) + side_axis * math.sin(a)) * r * 0.55)
        for k in range(n):                                         # girdle
            a = 2.0 * math.pi * (k + 0.5) / n
            verts.append(centre + (up * math.cos(a) + side_axis * math.sin(a)) * r)
        verts.append(centre - normal * r * 0.7)                   # culet
        table = lambda k: base + 1 + k % n
        girdle = lambda k: base + 1 + n + k % n
        for k in range(n):
            faces.append((base, table(k), table(k + 1)))
            faces.append((table(k), girdle(k), table(k + 1)))
            faces.append((table(k + 1), girdle(k), girdle(k + 1)))
            faces.append((girdle(k), base + 1 + 2 * n, girdle(k + 1)))
    mesh = bpy.data.meshes.new("Aubrey_Studs")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mat = bpy.data.materials.new("M_Stud")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.92, 0.93, 0.96, 1.0)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.08
    mesh.materials.append(mat)
    mesh.update()
    stud = bpy.data.objects.new("Aubrey_Studs", mesh)
    bpy.context.scene.collection.objects.link(stud)
    rigid_on_head(stud, old_arm)
    return stud


def _smooth(a, b, x):
    import numpy as np
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def position_map(body, size: int, z_min: float, group: str | None = "lips"):
    """A mesh rasterised into UV space (faces wholly above z_min): for every
    texel, the point on it that texel covers (world, metres), its weight in
    `group`, and whether it is covered."""
    import numpy as np
    mesh = body.data
    pos = np.zeros((size, size, 3), np.float32)
    lips = np.zeros((size, size), np.float32)
    hit = np.zeros((size, size), bool)
    uvs = mesh.uv_layers["UVMap"].data
    co = np.array([body.matrix_world @ v.co for v in mesh.vertices], np.float32)
    lip_w = np.zeros(len(co), np.float32)
    if group is not None:
        lip_group = body.vertex_groups[group].index
        for v in mesh.vertices:
            for g in v.groups:
                if g.group == lip_group:
                    lip_w[v.index] = g.weight
    mesh.calc_loop_triangles()
    for tri in mesh.loop_triangles:
        vi = list(tri.vertices)
        if co[vi, 2].min() < z_min:
            continue
        uv = np.array([uvs[i].uv for i in tri.loops], np.float32)
        px = np.stack([uv[:, 0] * size - 0.5, (1.0 - uv[:, 1]) * size - 0.5], 1)
        x0, y0 = np.maximum(np.floor(px.min(0)).astype(int), 0)
        x1, y1 = np.minimum(np.ceil(px.max(0)).astype(int), size - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = px
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        w0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
        w1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not inside.any():
            continue
        weights = np.stack([w0, w1, w2], -1)[inside]
        yy, xx = ys[inside], xs[inside]
        pos[yy, xx] = weights @ co[vi]
        lips[yy, xx] = weights @ lip_w[vi]
        hit[yy, xx] = True
    return pos, lips, hit


def paint_skin(body, eyes) -> None:
    """Her skin texture: the graded CC0 skin with her make-up painted on
    (SMOKE, LINER, LIPS), written to SKIN_OUT and put on the body."""
    import numpy as np
    from PIL import Image, ImageFilter
    base = np.asarray(Image.open(SKIN_SOURCE).convert("RGB"), np.float32) * np.array(SKIN_GRADE, np.float32)
    size = base.shape[0]
    z_min = min(c.z for c, _ in eyes.values()) - 0.20
    pos, lips, hit = position_map(body, size, z_min)
    lum = base.mean(-1)
    smoke = np.zeros(lum.shape, np.float32)
    liner = np.zeros(lum.shape, np.float32)
    socket = np.zeros(lum.shape, np.float32)
    verts = [body.matrix_world @ v.co for v in body.data.vertices]
    for side in ("l", "r"):
        centre, forward = eyes[side]
        up = Vector((0.0, 0.0, 1.0))
        up = (up - forward * up.dot(forward)).normalized()
        out = up.cross(forward)
        if out.x * centre.x < 0:
            out = -out
        c, f, u_ax, o_ax = (np.array(tuple(x), np.float32) for x in (centre, forward, up, out))
        d = pos - c
        u = d @ o_ax * 1000.0 - SMOKE["shift"]
        v = d @ u_ax * 1000.0
        w = d @ f * 1000.0
        a = np.where(u > 0, SMOKE["a_out"], SMOKE["a_in"])
        b = np.where(v > 0, SMOKE["b_up"], SMOKE["b_down"])
        shade = (1.0 - _smooth(SMOKE["e0"], SMOKE["e1"], np.sqrt((u / a) ** 2 + (v / b) ** 2)))
        shade *= (w > -2.0) * hit * np.where(v < 0, SMOKE["lower"], 1.0)
        smoke = np.maximum(smoke, shade)
        margin = np.array([tuple(p) for p in verts
                           if (p - centre).length < EYE_RADIUS + LINER["margin_slack"]
                           and (p - centre).dot(forward) > 0.3 * EYE_RADIUS], np.float32)
        flat = pos.reshape(-1, 3)
        dist = np.full(len(flat), 1e9, np.float32)
        for p in margin:
            dist = np.minimum(dist, np.linalg.norm(flat - p, axis=1))
        dist = dist.reshape(lum.shape) * 1000.0
        line = (1.0 - _smooth(LINER["near"], LINER["far"], dist)) * hit * (np.abs(u) < 20.0)
        liner = np.maximum(liner, line * np.where(v < 0, LINER["lower"], 1.0))
        # The socket: skin at or inside the eyeball's surface, seen only in
        # the sliver between eye and lid -- in shadow, not skin-pink (in the
        # game it read as a pink rim round each eye).
        dist_c = np.linalg.norm(pos - c, axis=-1) * 1000.0
        socket = np.maximum(socket, (1.0 - _smooth(SOCKET[0], SOCKET[1], dist_c)) * hit)
        # ...and the corners, which lie past the eyeball's sphere: skin within
        # the opening (an ellipse SOCKET_OPEN mm about the eye) and set back
        # behind SOCKET_DEPTH mm in front of its centre. (The base texture's
        # own painted eye-corner pink showed there.)
        uo = d @ o_ax * 1000.0
        opening = np.sqrt((uo / SOCKET_OPEN[0]) ** 2 + (v / SOCKET_OPEN[1]) ** 2)
        recessed = 1.0 - _smooth(SOCKET_DEPTH - 1.5, SOCKET_DEPTH + 1.5, w)
        socket = np.maximum(socket, (1.0 - _smooth(0.85, 1.05, opening)) * recessed * hit)
    img = base.copy()
    k = (smoke * SMOKE["strength"])[..., None]
    tone = (lum / lum[hit].mean())[..., None] ** 0.5
    img = img * (1.0 - k) + np.array(SMOKE["color"], np.float32) * tone * k
    k = (liner * LINER["strength"])[..., None]
    img = img * (1.0 - k) + np.array(LINER["color"], np.float32) * k
    k = socket[..., None]
    img = img * (1.0 - k) + np.array(SOCKET_COLOR, np.float32) * k
    mask = Image.fromarray(np.round(_smooth(LIPS["lo"], LIPS["hi"], lips) * 255).astype(np.uint8))
    lip = np.asarray(mask.filter(ImageFilter.GaussianBlur(LIPS["blur"])), np.float32) / 255.0
    lip_tone = (lum / np.median(lum[lip > 0.9]))[..., None] ** 0.7
    k = (lip * LIPS["strength"])[..., None]
    img = img * (1.0 - k) + np.array(LIPS["color"], np.float32) * lip_tone * k
    Image.fromarray(np.clip(np.round(img), 0, 255).astype(np.uint8), "RGB").save(
        SKIN_OUT, quality=SKIN_QUALITY, optimize=True)
    body.data.materials.clear()
    body.data.materials.append(image_material("M_AubreySkin", SKIN_OUT, roughness=0.5))


def main() -> int:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    addon_utils.enable(MPFB, default_set=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    old_arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    # The kit's materials that this build replaces step aside, so the new
    # ones keep their names (the game dresses surfaces by material name):
    # left in place, the new belt went out as "M_Belt.001", and the ponytail
    # took the kit's hair material rather than the cap's.
    for mat in list(bpy.data.materials):
        if mat.name in KIT_MATERIALS_REPLACED:
            mat.name = mat.name + "_Kit"
    trim = next(m for m in bpy.data.objects["Aubrey_Shirt"].data.materials
                if m and m.name.startswith(TRIM_MATERIAL))
    trim.use_fake_user = True
    for name in ("Aubrey_Body", "Eyes", "Eyebrows") + KIT_GARMENTS:
        if name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    body, eyes, lobes = make_body(old_arm)
    make_eyes(old_arm, eyes)
    make_studs(old_arm, lobes)
    tie_centre = refit(old_arm, body)
    dress_garments(old_arm)
    place_patch(body)
    collar = make_collar(old_arm, body, bpy.data.objects["Aubrey_Shirt"])
    make_belt(old_arm, body)
    make_pocket(old_arm, body)
    # The skin under the cloth goes last, once the collar has trimmed the
    # shirt: deleted first, the trim opened holes onto nothing.
    # Not the collar: rays up from under her jaw met it, and the skin there
    # was deleted -- black slivers under the chin.
    cover_skin(body, [bpy.data.objects[n] for n in GARMENTS])
    bpy.data.objects.remove(bpy.data.objects[CAP], do_unlink=True)
    paint_strands()
    make_cap(old_arm, body, eyes, tie_centre, lobes)
    bpy.data.objects.remove(bpy.data.objects["Aubrey_Ponytail"], do_unlink=True)
    make_ponytail(old_arm, tie_centre)
    for o in bpy.context.scene.objects:
        o.select_set(o == old_arm or o.parent == old_arm)
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                              export_yup=True, export_animations=False, export_skins=True,
                              export_apply=False, export_image_format="AUTO",
                              # The hair cap's feather is in its vertex alpha;
                              # by default only colours a material uses go out.
                              export_vertex_color="ACTIVE")
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print(f"aubrey_aaa: body {tris} triangles -> {OUT}")
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main())
