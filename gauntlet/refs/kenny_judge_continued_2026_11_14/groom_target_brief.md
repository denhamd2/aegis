# Kenny groom target: authored masses and silhouette gate

Read-only visual brief, separate from the round 7 head-surface judgement.
No implementation, generated image or new likeness score is included.

## Target and scale convention

Use the confirmed `kenny_3view.jpg`, `kenny_hair_top.png` and
`kenny_hair_back.png` in `gauntlet/refs/characters/`. The top/back references
show the fuller dry-curl structure; wetter photos in `kenny_omega_sheet.png`
compress those clumps and darken them, but do not change the fundamental flow.
The legacy round 6 ribbons are a comparison state, not the target.

Below, **W** means the head's temple-to-temple skull width, excluding hair and
ears, matched at the same projected scale. Proportion ranges are blockout
guides inferred from the images, not measured physical dimensions or a scan.
Keep existing safe gameplay/rig bounds; do not enlarge a bound merely to fit
one approximate photo projection.

## Five authored flow regions

| Region | Root and direction | Required mass/read | Common failure to avoid |
| --- | --- | --- | --- |
| **1. Front crest** | Begin along the irregular front hairline and sweep backward across a slightly off-centre break. Individual bundles turn through broad shallow S bends as they join the crown. | A low, connected rolling crest above the scalp, with an asymmetric outline and dark roots visible between highlighted bundles. Most added volume above the inferred scalp is roughly 0.1–0.2W; this is not the distance from the forehead hairline to the top of the skull. | Parallel upright hoops, equal-height spikes, a straight zipper part, or a vertical wall of strips at the hairline. |
| **2. Loose forelock** | On the wearer's **right**, the viewer's **left** in the frontal reference, a dominant highlighted group turns out of the crest and falls close to the outer forehead/temple. | A few nested curls frame the outer brow/temple and merge into the side fall. The lock should have a thicker root/core and finer ends, with a small gap from the face rather than a large projecting loop. | A freestanding handle/antenna, a single flat blonde blade, or a lock crossing a pupil. |
| **3. Swept temple and ear** | The opposite side, viewer's right/wearer's left, is tighter at the temple. Roots flow diagonally backward over and behind the ear before dropping. | Preserve the exposed temple recession and a readable ear. The main volume sits behind the ear; a few smaller return curls soften the edge. The two sides should not be mirrored duplicates. | A straight vertical curtain glued over both ears, a shaved-looking uniform panel, or equal side volumes copied by symmetry. |
| **4. Crown over the occiput** | Carry the front/side bundles over the rounded crown, turning diagonally and then downward over the back of the skull. Overlapping S/C turns stagger their bend locations. | A continuous nested mass of rounded waves covers the crown/back foundation. Darker inner channels separate highlighted groups, but large flat scalp-cap patches must not remain visible. At the macro level, several large directional groups subdivide into finer curls; no mandatory count is inferred from the photo. | Decorative curls only around the rim of an exposed cap, uniformly parallel wood-grain strokes, or broad solid ribbon faces standing in for volume. |
| **5. Nape and shoulder fall** | Below the occiput, groups continue downward with alternating inward/outward curl turns. Side groups join the back fall behind the jaw/ear. | Staggered tips: shorter inner curls stop near the neck base, while a few longer highlighted curls brush the upper trapezius/upper back. The lower outline is broken and softly rounded, not a level haircut or a rectangular flap. | A flat opaque nape collar, a straight continuous sheet, long lateral whiskers, or every tip ending at the same height. |

## Curl hierarchy and volume

- Establish the five masses before fibre detail. A useful starting range for
  a visible curl's outer turn is about **0.1–0.2W** across; bundles within that
  turn are smaller, approximately **0.04–0.10W**, and should split into much
  finer fibres. These ranges deliberately overlap: the reference contains
  several curl scales, not one repeated coil size.
- Give a curl an inner and outer side, soft depth and a changing tangent.
  Long S bends dominate much of the back, with some tighter C/loop returns.
  A succession of identical sawtooth kinks is not the same structure.
- The dry-reference envelope is moderately wider than the skull at the
  jaw/nape, with more volume behind the ears than across the exposed temples.
  Judge the actual outline against the photos instead of expanding every
  strand equally. Round 6's broad pale blades and compressed straight curtain
  should not be carried into the new mass blockout.
- Fine flyaways are an edge treatment after the mass passes. They remain
  irregular, curled and mostly near the main silhouette; they must not form
  evenly spaced sideways comb teeth or dominate the width of the groom.

## Root-to-tip and material transition

The roots, temples and inner layers are dark brown, with warm blonde highlights
already appearing through the crown and becoming more frequent toward the
mid-lengths and ends. This is a continuous, bundle-specific transition, not a
uniform dark top followed by a hard blonde band. Some dark strands continue to
the ends; some highlighted strands begin nearer the roots. Avoid alternating
solid brown/platinum ribbons or using black gaps to substitute for inner mass.

The highlight should break into fibres and change with the curl's curvature.
A large flat pale face that stays bright along its whole length will continue
to read as a strip, regardless of its polygon count. Do not copy lit reference
pixels directly into PBR base colour as if they were a measured material.

## Silhouette/coverage gate before strand polish

Use the existing front, quarter, side, back and top views at matched head scale.
Assess a simple neutral/solid groom first, then the textured version:

1. **Front/quarter:** the asymmetrical crest and close forelock frame the face;
   they are not a row of hooks or a forward-projecting handle. Side masses are
   connected to the crown and their ends descend naturally.
2. **Side:** temple roots travel backward; the ear remains readable, with the
   bulk behind it. There is no nape plate or large sideways whisker.
3. **Back/top:** overlapping curled masses cover the foundation. Narrow root
   channels/part breaks are legitimate; a broad continuous cap-shaped region
   is not. The back outline must show rounded bulges and staggered ends rather
   than a rectangle or zigzag-cut sheet.
4. **Across all views:** the mass must remain convincing without pale texture
   stripes. Fibre/alpha detail can refine a passed mass, but cannot repair an
   uncovered cap or missing curl silhouette.

Passing this structural gate would justify detailed groom look development;
it would not certify animated contacts, temporal alpha stability, full-arena
appearance, native M1 frame pacing or 10/10 overall likeness. The head-surface
gate remains separate and must not be hidden under the new hair.
