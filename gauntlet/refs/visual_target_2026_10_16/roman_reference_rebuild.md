# Roman — reference-directed face rebuild

The owner rejected the incremental `140d930` result and reaffirmed the supplied
ramp portrait as the target. This pass changes the underlying colour source,
facial proportions and beard construction; it does not treat the previous
checkpoint as accepted likeness.

[Compare engine frames with the target](roman_reference_rebuild/index.html).
The images are actual Godot frames, copied unchanged. The generated UV atlas
is source artwork for the model, never a replacement gameplay screenshot.

## What changed

- A retained, image-generated diffuse colour source directed by the supplied
  target replaces the damaged-channel face reconstruction. It carries skin
  pigment, fine facial detail, dense brows and a finer beard transition.
  Its native size is **1254×1254**; registration/resampling produces the 2K
  game atlas. It is synthetic artwork, not a scan or native 2K capture.
- Nose/lip rows are registered to the original UV anatomy. Neck/tattoo islands
  blend back to the existing source. Anatomical normals, skin weights and
  topology remain the supplied assets; no screen-space face overlay is used.
- Diagnostic landmark ratios identified a long midface and broad mouth.
  Nose/mouth move together upward; the mouth/alar/canthus widths are refined,
  with a broader jaw. The eye meshes, centres, neck seam and rig remain fixed.
  Rendered views determine likeness; the optional MediaPipe measurements are
  estimates affected by lighting, expression and camera, not a quality score.
- The visible beard shell is replaced by **1,800 curved fibre clumps** sampled
  on its already fitted source surface. They share its actual skin, skeleton
  and transform. Fibre ends curl into the volume. A long straight fringe was
  reviewed and rejected. The old mesh remains the fitting authority, hidden
  after successful groom construction.
- Scalp, brows **and beard** underpaint now use independent nonmetallic hair shading.
  The old scalp-only mask let beard pigment receive flesh scattering and
  sweat, creating a pale waxy chin patch. The expanded mask excludes all painted hair
  from flesh diffusion while preserving the exposed forehead and lips.
- The reference's tighter wet highlights use a Roman-specific, bounded flesh
  film (.45 share / 1.1 roughness gain); other characters retain their existing
  settings. Hair is excluded from that response.
- Brown eyes retain a wet catchlight with less broad reflection. Resting upper
  lids sit at -25 degrees; blink timing and the corrected cap geometry remain.

## Review scope

Neutral front/three-quarter/profile studies use the same camera/key/back
setup as `140d930`: Forward+/Vulkan on llvmpipe, 960×540, fixed clock,
12 settling frames. They omit the arena and use the bind pose.

Additional front/three-quarter/side samples use the **complete RomanModel**
and adapted `Roman_Stand` at 35%, its production head modifier and hair
attachments, and the normal entrance wetness. Their environment uses the game's AgX/exposure settings and the production
walk key/back/camera-fill parameters, with a longer portrait distance and a
22-degree lens. The arena, follow spot and stage lighting remain omitted. The separate forced-closed
blink checks the changed eye surroundings. None of these stills establish
motion quality or native Metal performance.

The comparison figure uses unretouched diagnostic crops scaled by pupil
distance. Unchanged full frames, camera metadata, the original target and
hashes remain available beside it. It does not normalize lighting or conceal
render defects. `measure_face.py --model PATH` reproduces the optional
landmark diagnostics in a separate Python environment; no ML model or package
is added to the game.

## Budget and acceptance

The new beard has 10,800 triangles and replaces 4,574 visible source triangles:
**+6,226 drawn triangles** per close-up Roman, with one fibre material. It casts
no additional shadow. The existing shared head underpaint instance is reused;
there is no second new head/skeleton. Maps remain mipmapped/compressed:
2K colour/RM and 1K roots/SSS/fibre atlas. Native M1 Pro GPU cost must still be
measured against the owner's steady 60 fps requirement.

See [validation](validation.md) for automated/package results. The original
GLB, skeletons, skin weights, animation clips, fixed-tick gameplay and paired
move control remain unchanged. The published Mac release is separate from
the local review preview; native appearance/performance acceptance remains open.

## Visual verdict and publication request

The new pigment, brows and curved beard remove the previous flat skin and
waxy chin. The reference still has more accurate orbital/nose/lip forms,
finer wet hair clumps and more natural skin shading. Visible long-hair
card ends remain in the posed side views. A denser monocular face fit was
rendered and rejected because the visible benefit was too small; it is not
part of the game. This checkpoint does not claim an exact reference match.

The owner accepted this version for now and explicitly requested committing
all changes and publishing the Mac build. That publication request does not
establish native performance or final eight-reference visual acceptance.

The figure uses the adapted pose for the rebuilt crop and a neutral frame
for the old crop; the main three-view slider retains identical cameras and
poses. Reproduce the optional figure with `measure_face.py --model PATH
--after pose_Roman_Stand_ffront.png` from the review directory.
