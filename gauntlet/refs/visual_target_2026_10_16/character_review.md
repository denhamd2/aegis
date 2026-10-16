# Hero character checkpoint — October 16

**QA verdict: NO-SHIP for the final reference target.** This is an incremental
character checkpoint for native review. The eight-view goal and 60 fps native
acceptance remain open. The preceding shared-look checkpoint is `fdf97e0`;
the published build remains `fb69eae`.

## Changes and evidence

| Area | Change | Result in the fixed portraits |
| --- | --- | --- |
| Cody hair | A scalp cap and 1,200 fine swept clump cards, volume-following shading normals, tapered atlas fibres and alpha-to-coverage. Four meshes, 16,844 source triangles versus 53,284 across eleven shells. | Finer outline and less broad plastic glare. Earlier broad-card prototypes looked like feathers/tabs and were rejected. The accepted checkpoint still has a conspicuous painted hairline and cap-like streaking. |
| Cody eyes | Reduced the blue-channel iris tint; geometry, sclera treatment and eye rig retained. | Slightly calmer blue; eyes and lids still require likeness work. |
| Roman beard | Restrained colour variation and coverage-derived normal relief, with the original opacity copied exactly. | More local fibre variation, but the silhouette/cheek transition still reads as a solid cutout. Texture changes alone have not solved this. |
| Facial finish | Faces retain a wet layer with lower coverage and greater roughness than chest/shoulder skin. | Broad oily highlights are reduced. A separate dry diagnostic identified clearcoat as their source; the dry diagnostic was not selected as the final look. |

The new groom has approximately 68% fewer source triangles. This does not
establish a GPU-time improvement: alpha coverage, overdraw and native shading
cost still need measurement. Source body meshes, skeletons, skin weights and
authored animation libraries are unchanged.

All twelve before/after portraits were inspected. They use the same cameras,
30-degree lens, key/back lights, 960×540 output and 12 settling frames. Godot
4.6.3 Forward+/Vulkan ran on llvmpipe software rasterisation. These are isolated
bind-pose studies, without the arena, follow spot, camera fill, animation or
gameplay camera. They cannot establish Metal equivalence or Mac frame rate.
The before images were captured before replacing the imported eye texture;
they were not recaptured through a shared cache after that replacement.

| Character | Before | After |
| --- | --- | --- |
| Cody | [Front](character_review/cody_before_front.png), [three-quarter](character_review/cody_before_threequarter.png), [profile](character_review/cody_before_profile.png) | [Front](character_review/cody_after_front.png), [three-quarter](character_review/cody_after_threequarter.png), [profile](character_review/cody_after_profile.png) |
| Roman | [Front](character_review/roman_before_front.png), [three-quarter](character_review/roman_before_threequarter.png), [profile](character_review/roman_before_profile.png) | [Front](character_review/roman_after_front.png), [three-quarter](character_review/roman_after_threequarter.png), [profile](character_review/roman_after_profile.png) |

[Portable manifests and hashes](character_review/manifest.json) identify the
images, runtime settings and generated assets. The supplied targets remain in
the [source manifest](source_manifest.json); the principal portrait targets
are “Roman entrance on Ramp - new.png” and “Cody mid body closup - entrance on
ramp - new.png”. These are target comparisons, not matched-pose pixel tests.

## Verification

- Final affected gdUnit run: **32/32 passed**, report `game/reports/report_410`.
  Covers Cody rig/attachment, orientation, Roman hair, skin and hair/shadow
  presentation. The new hair stays inside an 18,000-triangle guard.
- Final groom GLB, card atlas and both beard maps rebuilt byte for byte.
  The imported groom's source MD5 matches the final GLB. Beard opacity is
  byte-identical to its original mask.
- Python compilation, native-runner shell syntax and patch whitespace passed.
- The previous full suite's existing clip-authoring pin failure remains
  unresolved; see [validation](validation.md). This subpass has not completed
  another full round/evidence gate and is not accepted as a final art round.

## Remaining major gaps

Facial structure, eyelid seating and authored anatomical skin relief remain
well below the generated targets. Cody's hair needs better root blending,
regional flow and a less uniform cap; Roman needs a reconstructed beard edge
and clumps. The coat still has coarse ornament silhouettes and bright flat
panels. Necklace, belt deformation, raised-arm correction, Aubrey, ring and
audience surfaces require their planned passes. Hair stability during head
turns and native close-ups must be reviewed before final acceptance.

`tools/capture/native_reference.sh` now also captures all six hero portraits
through `--studio --portrait-view all`, alongside complete-arena appearance
views and the separate real-time match pacing sample. A fixed-fps still is
never performance evidence. Keep the experimental stage probe disabled.
