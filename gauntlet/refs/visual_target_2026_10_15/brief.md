# Match visual target: 15 October 2026

The owner's `New.png` is the art direction for this pass. `Current.png` is
their native Mac gameplay baseline. Older WWE/AEW measurements remain useful
history; contradictory requirements (no match beams, concrete-coloured steel
steps, vertex-colour-only front rows) do not override this newer reference.

## Reference analysis

- Realistic AEW broadcast match, regulation ring dimensions retained.
- Current 2048x1132 and target 1688x932 have effectively the same framing.
  Keep the master camera; measure materials and lighting in matching crops.
- Ring is the brightest large surface; warm skin is distinct from the neutral
  canvas. Nearby spectators have faces and textured clothes; rear tiers remain
  dark, with blue aisle fixtures, sparse shafts and visible stair separation.
- Ringside has broad, broken reflections, not a mirror finish. The apron has
  cloth folds; the canvas has restrained wrinkles. Bare-metal steps have fine
  diamond plate and recesses. Concrete remains under the pads and seats.

Screen-space palette samples (tone-mapped pixels, **not material albedos**):

| Region | Current | Target |
| --- | --- | --- |
| Clear canvas patch | #D1D3D6 | #D4D1D6 |
| Near spectator bank | #413836 | #372729 |
| Rear spectator bank | #201E1D | #241A25 |
| Left ringside patch | #282829 | #584853 |
| Blue fixture | — | #3B73DB |
| Lit skin sample | — | #FAC097 |
| Black post sample | — | #080607 |

The canvas samples are already very close. Increase depth and surface response
locally rather than raising global exposure. The brighter ringside sample is
largely reflected light; do not paint its illumination into the base texture.

## Representative production slice

1. Reproducible Forward+ master, corner, crowd and body captures with actual
   driver/adapter metadata. Software captures never support performance claims.
2. Recover photographic UV textures for near crowd; retain cheaper existing
   figures at distance. Shared 2K atlases, up to 6K triangles per near variant,
   existing seeded placement, and section-level culling. Preserve original
   models and the sign-fan cutaway.
3. Correct ringside pad roughness and indirect/specular lighting, step metal,
   cloth response and stationary blue aisle accents. Keep entrance sweep
   behavior separate from match ambience.
4. Review both wrestlers under the same light. Keep restrained sweat and blood,
   and preserve the existing rigs and gameplay-driven animation.

Skills: blender-director/reference-image-match, realistic-style,
blender-materials, texture-workflow, blender-lighting, environment-artist,
camera-cinematography, asset-optimization, lod-pipeline, godot-export and
qa-review. Blender generates reproducible game assets; Godot renders the look.

## Acceptance

Compare full frames and 100% crops, then inspect motion for shimmer, material
swimming, ghosting, LOD popping and clipping. Target Apple Silicon with 16 GB
shared memory, 1080p/60 fps (16.7 ms budget); record the exact chip before
claiming that performance. Native Mac review remains necessary. Preserve all
existing uncommitted work and track the unrelated ladder-clearance failure.
