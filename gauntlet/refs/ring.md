# ring.md — the ring and ringside reference

The ring the build's *look* is matched to, alongside `VISUAL_BAR.md` (which
keeps governing the measured *relationships*). Where the two touch, the call
sites in `core/ring/ring_builder.gd` and `core/materials/material_library.gd`
say which won and why.

## Source

**"Wrestling Ring"** by Ryan Kiesselbach (`@ryankiesselbach`) on Sketchfab —
<https://sketchfab.com/3d-models/wrestling-ring-76f8cc19b9ad458685313bad672ea49c>

Sketchfab's API reports `isDownloadable: false` and no licence grant, i.e. all
rights reserved. **Reference only.** No geometry, textures, materials or UVs
from it are in this repository. It is handled the same way as the WWE 2K
footage: measurement and observation are committable, the asset is not.

Following the convention in `raw/README.md`, the preview image itself is not
committed. Pull it from the model page when you need to look at it.

## What was observed

Observations, not measurements — this is a single rendered preview, not a
frame-stepped clip, so nothing here carries a number the way `timings.md` does.
Every one of these is a COVERAGE DECISION in the sense `ARCHITECTURE.md` uses
the term.

| element | reference | what the build did before |
| --- | --- | --- |
| canvas | plain off-white, wear and panel seams only — **no logo, no painted border** | blue field, chevron centre mark, two secondary marks, painted border |
| ropes | three per side, thin, **black cable**, near-taut | cream, taped, 3–4.8cm midspan sag |
| posts | **square black slabs**, flat-faced, axis-aligned, standing well clear of the top rope | 8.5cm cylinders with steel caps and lace collars |
| turnbuckles | a short dark sleeve and a clevis per rope. **No pad.** | 0.37 × 1.13m branded vinyl pads, straps, buckles |
| skirt | flat dark grey, drum-tight, unbranded | blue, chevron print band, nine folds per side |
| steps | **bare bright metal**, three treads, second-brightest surface in frame | dark painted steel, shared with the apron rail |
| ringside floor | dark concrete slab scored into large panels | untextured dark floor, no seams |
| barricades | discrete rectangular panels with visible joins, a cap rail, and a leg raking outward behind each | one continuous box per side |
| seating | rows of **empty black folding chairs** on the flat floor | raked bowl only, straight off the barricade |
| overall | near-monochrome, desaturated, neutral | pushed cool throughout |

## What it does not govern

The reference is a training-hall ring photographed in flat neutral studio
light. It says nothing about, and was not allowed to change:

- **Lighting.** `match.tscn`'s Environment, tonemap and glow, and
  `core/lighting/arena_lighting.gd`, are untouched. `VISUAL_BAR.md`'s exposure
  anchor still governs.
- **The frozen dimensions.** 6m mat, mat surface at y = 0, ropes at ±3.1 and
  heights 0.5/0.85/1.2. The reference's proportions sit close enough that
  nothing had to move.
- **The hall beyond ringside.** The entrance stage, ramp, truss, video wall and
  the raked upper bowl have no counterpart in the reference and keep the
  presentation the camera slice was built around.
