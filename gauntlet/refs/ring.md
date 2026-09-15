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
| turnbuckles | a short dark sleeve and a clevis per rope. **No pad.** | 0.37 × 1.13m branded vinyl pads, straps, buckles | *(superseded — see 'The corners are padded again' below)* |
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

## Ringside layout — where the steps and the barrier go

Added when the steps were moved off the sides and the barrier was brought in.
Two of these are **regulation**, which is firmer footing than a photograph:
they are what a sanctioning body requires, not what one promotion happened to
build on one night.

| property | source | value | build |
| --- | --- | --- | --- |
| steel steps position | Virginia 18VAC120-40-415.1 — the ring "shall have suitable steps for use of the contestants **in their corners**" | at the corners, not mid-side | two sets, each butted against a post, `STEP_POST_GAP` = 0.10 between |
| steps arrangement | broadcast convention: two sets, opposite | diagonal | `+X` beside the post at (+3, +3); `-X` beside the post at (-3, -3) |
| barrier distance | Virginia 18VAC120-40-415.1 — "the ringside barrier must be a **minimum of six feet** from the outside edge of the ring" | ≥ 6 ft (1.83 m) from the ring's outside edge | `BARRICADE_RADIUS` 6.0 from ring centre — **2.80 m (9 ft 2 in)** clear of the apron at 3.20 |
| ringside floor | every televised ringside | black interlocking matting, barrier in to the ring | `RingsideMat`, a slab out to the barrier line |

**What this replaced, and why it was wrong.** The steps stood halfway down
each ±X side, offset 0.35 m along Z for no reason the file recorded — a
wrestler climbing them steps over the middle of the top rope rather than
beside a turnbuckle. The barrier stood at 9.0 from ring centre, 5.80 m clear
of the apron: *nineteen feet* of empty floor, over three times the regulation
minimum, which is not a ringside.

Bringing the barrier to 6.0 does the seating on its own, because the floor
rows are offsets of that line (`ArenaBuilder._build_floor_seats`): three
metres of dead floor becomes four more rows of the best seats in the building,
and the front row now sits where a front row sits.

Asserted in `game/tests/test_ring_model.gd` and `test_stage_set.gd`, so a
later edit that drifts any of it fails loudly.

Source: [Virginia Administrative Code 18VAC120-40-415.1](https://law.lis.virginia.gov/admincode/title18/agency120/chapter40/section415.1/)


## The corners are padded again

Added when the ring was matched to the AEW *Dynamite* references supplied by
the project owner — three photographs of a televised ring, which is a
different thing from the training-hall ring the table above was taken off.

**This reverses the `turnbuckles` row, and only that row.** The Sketchfab
reference is a bare ring in flat studio light and its corners genuinely carry
no pad; a televised corner carries three. Where the two disagree about
something the cameras are pointed at, the one that looks like the show wins.
The rest of the table is untouched — the canvas, the ropes, the skirt, the
steps and the barricades all still read off the original reference.

| element | reference | build |
| --- | --- | --- |
| pads | three cushions per corner, one per rope, black, turned to face the mat | `TurnbucklePads`, 0.52 × 0.24 × 0.30, at `TURNBUCKLE_PAD_XZ` 3.013 |
| post | still square, still axis-aligned, standing clear above the top pad | unchanged |
| ropes | running INTO the pads, not past the post | unchanged geometry; the pad is deep enough to swallow the terminations |

**What the number 3.013 is doing.** The post is axis-aligned and the pad is
diagonal, so the post's nearest point to the mat is a *vertex*, at u = 4.133
along the corner diagonal. The rope terminations sit at u = 4.329. A pad has
to clear the first and cover the second, and at 0.30 deep centred on u = 4.261
it does both. Centred on the ropes instead — the obvious choice, and the one
tried first — the post stands through the middle of the cushion and each pad
renders as two lobes with a pole between them.

Both conditions are asserted in `game/tests/test_ring_model.gd` as arithmetic
over the constants, so a later edit to the post section or the rope span that
breaks either one fails rather than quietly splitting the pads again.

**What did not change.** The frozen dimensions above still hold: the ropes are
still at ±3.1 and the collision bodies are untouched, so nothing here reaches
the simulation. The pad material is `ring_turnbuckle_pad`, a key that already
existed — retired, unused, and still carrying the saturated blue tint of the
branded corner it last dressed, which is what the restored pads rendered as
until it was retinted.
