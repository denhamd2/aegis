# Characters and crowd to a AAA standard — research and recommendations

David asked for:
- Roman and Cody as close as possible to their **WWE 2K26** models;
- Aubrey Edwards and Kenny Omega as realistic as possible, using 2K's
  practices;
- a much more realistic crowd;
- and **no breakage of the character animation we have already built**.

This file is the research, an audit of what we have, the rules that protect
the animation, and a phased plan. Nothing here is implemented yet.

---

## 1. What WWE 2K26 does

### Public sources

- **Head and body scans.** Top stars get "entirely brand new models with new,
  highly detailed scans that take advantage of the boost in hardware
  minimums". Others reuse years-old models, and the mix is visible ("like
  playing two separate games").
  ([GamingTrend](https://gamingtrend.com/reviews/wwe-2k26-review/),
  [Wikipedia](https://en.wikipedia.org/wiki/WWE_2K26))
- **Weak scans are what reviewers punish.** Faces that "look to have low
  resolution" or "made out of Play-Doh"; awkward jaw and speaking animation.
  ([GamingTrend](https://gamingtrend.com/reviews/wwe-2k26-review/))
- **Hair.** "Improved hair physics" from dropping last-gen; two-tone hair
  blending, with a blend point and sharpness.
  ([Operation Sports](https://www.operationsports.com/wwe-2k26-creation-suite-upgrades-add-body-morphing-and-60-layer-attires/))
- **Body.** Region morphing (chest, upper and lower arms, stomach). The
  attire is layered: 40 layers for body and head, 60 per attire set.
  ([Operation Sports](https://www.operationsports.com/wwe-2k26-creation-suite-upgrades-add-body-morphing-and-60-layer-attires/))
- **Skin and sweat.** "Sweat glistens under arena lights"; sweat builds,
  bruises deepen, blood builds over a match.
  ([Vital Clash](https://www.thevitalclash.com/2026/02/wwe-2k26-graphics-look-unreal-and.html),
  [Outer Haven](https://www.theouterhaven.net/wwe-2k26-review/))
- **Crowd.** Denser and more reactive, but reviewers still call the crowd
  models dated and largely lifeless. It is 2K's weakest area, so a realistic
  crowd is a place we can match or beat them.
  ([Gaming Respawn](https://gamingrespawn.com/featured/64532/wwe-2k26-review/),
  [Outer Haven](https://www.theouterhaven.net/wwe-2k26-review/))

### Read off 2K26 footage we hold

Sources: the entrance storyboards in the scratchpad (`ref2k/roman.png`,
`ref2k/cody.png`) and the match storyboard.

- **Separate parts.** A 2K star is several parts, not one shell: a
  photo-scanned head and body; **separate eyes** (wet cornea, iris depth,
  caruncle); teeth and tongue; eyelash and brow cards; **layered hair cards**
  with physics; and attire as separate cloth meshes.
- **Skin.** Subsurface scattering, a tiled micro-normal (pores), and
  sweat/wet masks that ramp up during a match.
- **Hair.** Roman's 2K26 hair is long, wet, wavy cards falling past the
  shoulders. Cody's is short, platinum and swept back, with darker roots
  (their two-tone blend).
- **Likeness lives in the head.** Bodies are generic-but-correct anatomy;
  identity is the face scan, the hair and the tattoos.

### Industry practice (not 2K-specific; stated as such)

- **Characters.**
  - Hero characters: 60–150k triangles across head, body, hair and attire.
  - Faces: 4K albedo, normal and roughness maps.
  - A facial blendshape set (blinks, brows, jaw, pain) driven from the body
    rig.
  - 2–3 LODs, with hair and eyes held at full detail longest.
- **Crowds.**
  - **Instanced low-poly humans** (300–2,000 triangles) near the ring, from
    a dozen varied bodies and clothing textures.
  - Animated with **vertex-animation textures** (VAT: no skeleton per
    person).
  - **Impostors** (camera-facing cards rendered from those same people) in
    the far bowl.
  - Per-instance colour and animation offsets, so no two neighbours match.
  - ([NVIDIA GPU Gems 3, ch.2](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-2-animated-crowd-rendering),
    [Kavan, Polypostors](https://users.cs.utah.edu/~ladislav/kavan08polypostor/kavan08polypostor.pdf))

---

## 2. What we have (audited)

| Model | Source | Triangles | Rig | What holds it back |
| --- | --- | --- | --- | --- |
| **Roman** | Supplied game-style model | 79k, 19 meshes | Own 471-bone rig + 114, retargeted (`BONE_MAP`) | Closest to 2K already (separate hair, beard and eye cards). The head's shape and texture resolution limit likeness; the hair needs length and wet waves |
| **Cody** | **Photogrammetry scan of an action figure** | 74k, one mesh | Base rig (rigged by us) | Plastic: painted eyes, sculpted hair, baked lighting, figure proportions. Hair replaced by our cards; coat built on his body |
| **Kenny** | **Photogrammetry scan of an action figure** | 150k, one mesh, 1 material | Base rig | Same as Cody. Hair and face are part of the sculpt; one 4K texture for everything |
| **Aubrey** | Quaternius CC0 **stylised** base, our kit | 17k | Base rig | Cartoon proportions (big eyes, small jaw); low detail |
| **Crowd** | `tools/blender/crowd.py` | 132 per person (9 boxes) | None; shader bob | Box people; no faces or clothing detail; one pose family |

**The gap in one line.** 2K starts from scans of the real people. Two of ours
are scans of toys, and one is a cartoon base. Shaders and lighting are now
close (the AAA rounds 1–12 and the lighting round), so **geometry and
texture source are now the bottleneck**.

---

## 3. Rules that keep the animation working

Everything we built rides on the **skeleton**, not the mesh. The match
simulation, the paired moves, the grips and the collision tests all read
bones:
- `PairClearance.SEGMENTS`;
- `PairedContacts` targets;
- `PairedFit`;
- foot IK;
- pose lint.

So a model can change completely without touching the animation, if and only
if these hold:

1. **Same skeleton, same rest pose, same bone lengths.**
   - Cody, Kenny and Aubrey are on the base rig, so its 65 bone names,
     hierarchy and rest transforms stay byte-identical.
   - Roman keeps his rig and `BONE_MAP`.
   - New geometry is **re-skinned onto the existing skeleton**; the skeleton
     never adapts to the mesh. (`import-wrestler` skill, Phase 4: "same rig ⇒
     never retarget".)
2. **Body volume stays inside the collision capsules' assumptions.**
   - `pair_clearance.gd` assumes a torso radius of 0.13 m, a neck/head of
     0.085, thighs 0.065, arms 0.045.
   - A new body may be more detailed, but not bulkier than those plus about
     1 cm, or paired moves will visibly interpenetrate even though the tests
     pass.
   - Measure it with `compare_proportions.py` (the import skill) against
     today's mesh: width and depth at ten heights.
3. **Everything fitted to a body is refitted after it changes.**
   - Cody's coat (`cody_coat.py` copies his body surface);
   - Roman's title and ula fala fits;
   - Roman's hair spring colliders;
   - the eye bones (`EyeAim`, Cody's eye split) and Roman's blink lids.
4. **Heights stay** (`apply_physique_height`, the real heights from round 30).
5. **Gates on every change**, all already in the repo:
   - `test_*_model`, `test_roman_hair`, `test_pose_lint`, `test_pair_clearance`;
   - the `limb_clearance`, `wear_clearance`, `floating_probe` and
     `extreme_poses` probes, rendered;
   - the determinism seeds 1, 2, 3, 5, 7 and 11 (identical winners and
     ticks);
   - Vulkan renders, side by side with the reference.

   A change ships only if all of them pass. Each model change lands behind
   its own commit so it can be reverted alone.

---

## 4. Recommendations per character

### Shared technique (do once, all four benefit)

- **S1. A "head kit" standard.** (Roman's eyes and lashes done -- README
  "Roman's eyes"; Cody, Kenny and Aubrey still to do.) Every wrestler gets:
  - separate **eyes** (cornea + iris depth + wet layer, driven by the existing
    eye bones);
  - **teeth and tongue**;
  - **lash and brow cards**;
  - a 4K face albedo, normal and roughness set;
  - a **tiled pore micro-normal** (`SkinLook.add_pores` exists).
- **S2. Facial blendshapes.** Blink, brow raise and furrow, jaw open, sneer,
  pain wince, driven by match events.
  - Shape keys ride on the mesh, not the skeleton, so they are
    animation-safe.
  - Roman's blink today is lids only.
- **S3. Hair cards to 2K standard.**
  - 3 layers (scalp cap, mid volume, flyaway strands) with alpha-to-coverage
    and a blended hairline (Roman's `SCALP_BLEND` pattern);
  - two-tone root-to-tip (we already do this);
  - spring chains on the long cards (Roman's `HairSprings` pattern).
- **S4. Sweat, bruise and blood masks.** Extend `Sweat` with a wet mask
  (chest, forehead, back) instead of a uniform clearcoat. Add a redness and
  bruise mask driven by limb damage.
- **S5. LODs.**
  - Two LODs per hero; hair and eyes held at LOD0 to 15 m.
  - This is our first LOD work (`lod-pipeline`); it pays for S1–S3.

### Roman — towards his 2K26 model

Roman is the closest to 2K already. Improve in place; no rebuild.

- **R1. Hair** (done to the limit of the supplied cards; README "Roman's
  hair and beard, R1 complete"):
  - hanging lengths past the shoulders; wet, narrow highlights; a matte
    scalp cap; the beard's own warm brown-black -- done;
  - a wave: a detail normal on a position UV2 plus the same wave bent into
    the hanging geometry; strand ridges in the base normal -- done;
  - flyaways at the nape; staggered, frayed ends -- done;
  - crown slicked flat and the hang slimmed, to the owner's photos -- done;
  - the beard: groomed cheek line, sideburns into the hair, painted as
    strands under the cards, full moustache -- done.
- **R1b. Ringlets** -- done (README "Roman's ringlets, R1b"): 30 wet
  ringlets built in Blender (tools/blender/roman_ringlets.py), laid down his
  neck and back and skinned to his hair chains; the supplied sheet cut below
  the nape for them; the crown pulled in tighter than supplied.
- **R2. Face texture to 4K.** Re-project from his best reference photos onto
  the existing UVs (`build_roman_hair_alpha.py` already rebuilds his head
  albedo): pores, beard-line shadow, the sheen on cheekbones and nose.
- **R3. Shape tweaks by shape key**, not by editing bones. Measured against
  2K26's Roman: jaw width, brow ridge, nose bridge. Keys are mesh-only, so
  animation-safe.
- **R4. Tattoo.** Raise the tribal sleeve and chest texture to 4K, with a
  slight ink sheen. It is his most recognisable marking after the hair.

### Cody — towards his 2K26 model

The action-figure scan cannot reach 2K. Its face is sculpted plastic.

- **C1 (recommended). A new realistic head on the existing body.**
  - Generate a male head with **MPFB (MakeHuman for Blender)**. Its output
    is **CC0**, so it is safe to ship.
    ([MPFB](https://extensions.blender.org/add-ons/mpfb/),
    [licence](https://static.makehumancommunity.org/about/license.html))
  - **Likeness-sculpt it** headless from front and profile reference photos:
    landmark-driven shape keys (brow, nose, jaw, cheekbones) fitted to
    measured ratios.
  - Bake a photo-projected 4K skin texture.
  - Join it at the neck seam to his body, skinned to the same `Head`,
    `neck_01` and eye bones.
  - Then: separate eyes and teeth (S1), and new hair cards (S3: platinum,
    darker roots, short tapered sides, swept-back top).
  - The skeleton is untouched; the coat is rebuilt after (rule 3).
- **C2. Body texture pass.** Remove the scan's baked shadows (delight the
  albedo), add pores and SSS; the tattoo-free torso gets real muscle normals.
- **C3. Robe.**
  - The collar is done (WIP).
  - Next: gold frogging across the chest, epaulettes, and panel widths to
    the owner's photo; cloth folds baked as normal detail.
  - Optionally a jiggle bone or two on the coat tails (presentation-only, like
    the hair springs).

### Kenny — realistic

Kenny is an action-figure scan, with one material.

- **K1. The same head path as C1**:
  - MPFB head, likeness-sculpted to Kenny;
  - **real hair cards**: his long dark hair with bleached lengths, worn loose
    to the shoulders, with springs;
  - separate eyes, teeth, lashes.
- **K2. Split his single material into skin, attire and boots.** Then each
  gets its own shading: SSS on skin, sheen on cloth, gloss on boots. This
  needs mask textures painted in UV space; the mesh and skin weights are
  untouched.
- **K3. Delight the 4K albedo** (it carries the figure's baked studio light),
  plus pores and SSS.

### Aubrey — realistic

Aubrey's base is stylised.

- **A1 (recommended). Rebuild her on an MPFB female body** at her measured
  height, re-skinned onto the base rig, with her kit rebuilt by
  `referee_aubrey.py` (it already builds the shirt, trousers and hair
  procedurally on whatever body it is given).
  - This is the one character where a **body** swap is worth it: the
    stylised proportions are visible in every wide shot.
  - The rules in section 3 apply: same skeleton; refit the ponytail springs.
- **A2. Hair.** A long, wavy, mid-back ponytail with a curled end; a
  feathered hairline; no part-line seam.
- **A3. Head kit** (S1), a natural brow, and a paler skin with SSS (her
  `_paler` grade carries over).
- **Fallback if A1 is not wanted.** A shape-key pass on the current head
  (smaller eyes, longer mid-face, narrower jaw). Cheaper, but it stays
  stylised.

---

## 5. The crowd — beyond 2K26

Today the crowd is box people (132 triangles each, 9 boxes) with shirt
colours and a vertex-shader bob. Recommended:

- **CR1. 12–16 CC0 crowd people from MPFB**: varied build, sex, age, skin
  tone, hair and clothing (tees, hoodies, jerseys, caps).
  - Decimated to about 1,500 triangles near the ring and about 400 in the
    lower bowl.
  - One shared 2K texture atlas.
- **CR2. Animation without skeletons:** vertex-animation textures baked in
  Blender.
  - Clips: sit idle, clap, cheer (arms up), stand and cheer, boo
    (thumbs-down), phone up, point, a sign-hold for the sign fans.
  - The shader picks the clip and offsets per instance. It is driven by the
    `crowd_excitement` global we already have, so a near-fall puts them on
    their feet.
  - Cosmetic only: ARCHITECTURE.md's rule holds; no gameplay or replay state
    is touched.
- **CR3. Instancing.**
  - Near rows and floor seats: `MultiMeshInstance3D`, with per-instance
    colour (shirt, skin, hair) and clip offset from a seeded RNG, so it is
    deterministic.
  - Upper bowl: **impostor cards** rendered from the same people in 8
    directions × 3 poses, so far rows still read as people at the
    broadcast-wide distance.
- **CR4. Signs, merch and lights.**
  - Scattered AEW signs and championship replicas;
  - wrestler shirts weighted to whoever is in the match (Roman shirts and
    Cody shirts);
  - the existing phone flashes kept.
- **CR5. Front row.** Ringside rows get the highest LOD, with face textures:
  2K's ringside fans are in shot on every low camera.
- **Performance.** About 3,500 people. About 20k instanced near-row
  triangles plus impostors is far cheaper than today's 460k-triangle baked
  bowl budget (see `crowd.py`'s note).

---

## 6. Plan, in order

Each step is gated by section 3, committed alone, and shown to David as a
before/after contact sheet.

| Phase | What | Effort | Risk to animation |
| --- | --- | --- | --- |
| **0** | Finish the WIP: collar render check; Roman hair R1 | 0.5 day | None (attire/hair geometry only) |
| **1** | Shared tech S1 eyes/teeth/lashes kit, S4 sweat masks, S5 LODs | 2–3 days | Low (separate meshes on existing eye/head bones) |
| **2** | Roman R2–R4 (4K face, shape keys, tattoo) | 1–2 days | Very low (texture and shape keys) |
| **3** | MPFB pipeline proven on **Aubrey** (A1–A3): body build, re-skin, kit rebuild | 3–4 days | Medium, contained: base rig unchanged; `pose_lint`, springs and clearances re-run |
| **4** | Cody C1–C3 (new head, delight, robe) using the proven pipeline | 3–4 days | Low–medium (head only; coat rebuilt) |
| **5** | Kenny K1–K3 | 2–3 days | Low–medium |
| **6** | Crowd CR1–CR5 | 4–5 days | None (cosmetic layer, no gameplay contact) |
| **7** | S2 facial blendshapes across all four, event-driven | 2 days | None (shape keys) |

**Aubrey rebuild -- progress.** `tools/blender/aubrey_aaa.py` (WIP, not yet
wired into the game) builds `aubrey_aaa.glb`: stage 1 done -- an MPFB body
(CC0), female, ~40, lean, fitted to her existing 70-bone skeleton (joints
pinned, bones aimed; the head left on MPFB's own neck because her kit
skeleton's head joint is stylised-low) with MPFB's weights on her bone names,
and eyeballs at MPFB's eye helpers. MPFB is installed as a Blender extension
and its CC0 asset packs (system assets, skins01/02) live in
~/.cache/aegis_assets/mpfb. Stage 2 done -- the shirt, trousers and shoes
conformed to the new body (standoff limits, smoothed, re-weighted from it,
covered skin removed), a fitted polo collar and placket, the ponytail moved
with its bones, and a new hair cap with a feathered, measured hairline.
Known: white specks on the collar flap, a sliver of neck in the back fold.
Stage 3 done -- her likeness as MPFB face targets (FACE), set against the
sheet's front, 3/4 and profile on clay renders. Stage 4 done -- colour: a
CC0 skin regraded, smoky eyes, liner and red lips painted in UV space from 3D
position, MakeHuman brow and lash cards, grey-green eyes (build_eyes.py
AUBREY_AAA), stud earrings; the mouth narrowed and the eyes opened less once
seen in colour. Stage 4b done -- body and uniform reviewed against the
sheet and rebuilt: MakeHuman CC0 tee/jeans/trainers as her uniform (stripes,
tucked, belt, buckle, radio pack, straight black trousers, black trainers),
a polo collar laid on the shirt, a long ponytail, the hairline to the nape,
a slimmer neck. Next: wire it in and gate it.

**Why Aubrey goes first in the head/body work.** She has no likeness
expectations from a 2K model and the simplest kit. If the MPFB → re-skin →
gates pipeline is going to fail, it fails on her, before it touches Cody or
Kenny.

## 7. Decisions for David

1. **MPFB as the base** for Cody's and Kenny's new heads and Aubrey's body.
   It is CC0, so it is safe to ship. A likeness built from photos is
   "close", not a 2K-grade scan: 2K scans the real person in a capture
   rig, which we cannot do.
2. **Crowd scope.** The full CR1–CR5, or a first pass of CR1–CR3 (real
   people, animated, instanced) without signs and merch.
3. **Likeness rights.** Real names, faces and marks are already in the build
   (`lighting.md` notes the open policy question). This plan deepens that.
   It is worth a conscious yes before shipping anything outside the team.
