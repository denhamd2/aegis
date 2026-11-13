# Blender prop and cage authoring — 13 November 2026

The owner requires the steel cage, Hell in a Cell, ambulance and casket to be
modeled in Blender. All four shipping visuals now have editable `.blend` files,
reproducible builders and GLB exports in the project. **This establishes the
Blender pipeline, not completed AAA visual quality.**

## Sources and behaviour

Open `tools/blender/props/{steel_cage,hell_in_a_cell,ambulance,casket}.blend`.
`cage_hardware.blend` supplies the padlock/chain and unit hoist cable. All texture
paths are relative, all referenced textures exist, and every native file opens
in Blender 4.3.2: [source validation](blend_validation.json).

Rebuild with Blender in background mode and either `caged_structures.py` or
`match_containers.py`. Both save native source files and export game assets.
Geometry, UVs and materials are original procedural Blender work; no downloaded
models, manufacturer branding or generated images were used.

- Cage/cell: chamfered steel, box-truss cell uprights, chain-link cards, separate
  door and roof panels, cage top lip and authored hardware. Godot retains the
  same Spec queries, collision and moving-part control. Shipping specs load the
  Blender assets; custom experimental Specs retain the legacy builder for
  compatibility. Fence cutout rendering avoids alpha-sort sheets and hash noise.
- Casket: rounded profiled shell/lid, padded lining, draped bier and brass swing
  bars. Ambulance: raked cab/hood, wheel-arch openings, shaped tyres/hubs, mirrors,
  door seams/seals/handles and sidewall storage/seating. Existing mouth, bed,
  lip, placement and collision snapshots match their originals exactly.
- Small material tiles retain the original 512×512 total texel budget per
  base/ORM/normal set. Splitting atlas cells prevents mip bleed; continuous UVs
  prevent visible tiling across subdivided cloth. Normal/roughness detail is
  reused rather than adding geometry for texture grain.

## Checks and renders

**89 distinct focused cases pass**, zero failures/errors: all-weapon grip (1),
weapon pickup/AI/set-piece/ladder/fire-crew regression (47), container rules and
finishes (6), and steel cage/cell/roof gameplay (35). The final hardware change
also passes the affected roof/lowering/padlock suite again (10 of those cases,
not another 10 distinct cases). XML reports are stored alongside this file.
Import, Python compilation and source portability checks pass.

The grip correction seats settled two-handed carries and excludes a still
travelling left hand from whole-prop seating corrections. The unchanged contact
gate now passes all weapons: table carry/swing 1.2/2.0 cm, ladder swing right/left
1.9/1.8 cm. Earlier eight-weapon failures were reproduced with original assets;
no tolerance or assertion was weakened.

[Asset audit](asset_audit.json): casket 5,512 triangles / 4 materials;
ambulance 12,558 / 8; steel cage 12,126 / 2; cell 20,550 / 2. Hardware is separate.

`before/` and `after/` contain matching container studies (open, half and closed;
ambulance front included). `after/cage.png` and `after/cell.png` show the final
cutout fence material. Earlier door-motion studies and gameplay checks establish
moving-part behaviour; those preliminary material variants are not final art.

Captured in Godot 4.6.3 Forward+, 640×480 on software Vulkan llvmpipe, using the
isolated `container_art_study` and `cage_art_study` probes. These are studio
geometry/material checks, not full-arena or native performance measurements.

## Reference direction and remaining acceptance

Construction/proportion references: [Braun Chief XL brochure](https://www.braunambulances.com/wp-content/uploads/2025/05/Braun-Chief-XL-Ambulance-Brochure-v051525.pdf)
and [Batesville metal caskets](https://www.batesville.com/caskets/metal-caskets/).
Existing cage/cell panel counts, steel colour and dimensions retain the owner's
approved direction. WWE 2K visual parity has **not** been accepted as complete.

Remaining: reference-matched close-up detail and materials, full-arena appearance,
fence aliasing in motion, owner Mac visual review and native M1/16 GB frame-time
measurements. Hoist visuals remain simple cables. Do not label the assets AAA
or claim 60 fps from these checks. Original unfinished priorities 3–9 and the
remaining weapon families stay on the backlog.
