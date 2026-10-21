# BR-022 shared fabric response — 21 October 2026

BR-022, item 22 of 25, remains in progress. This pass follows the shared
collar/raglan fit; it changes material response, not anatomy or animation.

## Reference and gap brief

Authority: archived home kit boards
`file_000000000da0824386b7ef8edd3a9c79.png` and
`file_00000000fcac81f4b3870dc4ce96ac38.png`, with Bordeaux/keeper boards in
`references/README.md`. Their close-ups show fine polyester knit, subdued
fabric highlights, denser elastic socks and smoother printed marks. Owner
corrections remain Uhlsport, Thomas Loomes & Co and the tall oval EST 2004 crest.

Five gaps, in order:

1. Godot's shared role replacement ignores the existing roughness image.
2. That image is itself a constant 205/255, so merely wiring it is insufficient.
3. The tiny resampled knit normal is almost flat; fabric structure is absent.
4. The normal and role pigments lack mipmaps, risking distant aliasing.
5. Blender and live Godot do not use a common, inspectable surface recipe.

## Scope and checks before editing

Use create-player, blender-director/reference-image-match, blender-materials
and realistic-style guides. Generate original data maps for the existing atlas,
with no photographic lighting or changes to supplied pigment/graphics. Keep
the current rig, clips, heads, meshes, UVs and six shared role materials.
Retain source/export compatibility using the Godot export guide if re-exporting.

Record fixed idle-frame-2 before/after source close-ups and actual roster Web
views. Extend the isolated review with explicit sun and physically occluded
shade lighting, sharing the match's sky/sun settings. Keep sun shadows enabled
for these comparisons, even in software WebGL; a disabled sun is not shade.
Check long/short sleeves, keepers/referee, a moving-arm pose and broadcast
distance. A passing still is not all-animation approval or native M1 timing.

Save measured map ranges, resource sharing/import checks and remaining gaps.
Keep prior fit regressions; run relevant existing Godot integration checks and
Play/Watch startup. Build validation and native Mac hardware validation are
separate gates. Exact keeper graphics and individual likeness stay open.

## Result and evidence

The live role materials now use one shared 2K tangent-space knit normal and
six 1K atlas-aligned linear roughness masks. Nominal dry shirt roughness is
0.79, shorts 0.84, socks 0.89, printed front marks 0.60, badge 0.70 and boot
swatch 0.59, with restrained weave variation. These are editable look-development
values, not measured fabric specifications. Knit spacing on the front chart is
estimated at 1.7 mm; no raised stitches are added to the playable mesh.

Colour images are unchanged. Pigment, normal and roughness have mipmaps and the
runtime uses anisotropic mip filtering. This reduces jagged distant graphics in
the fixed views; it is not a measured temporal-aliasing or M1 performance result.
Blender's source uses the same data and portable metallic/roughness response.
The exported glTF packs roughness into green; it exactly matches the canonical
mask's red data. The exported normal matches its canonical PNG byte-for-byte.

`source_validation.json` records identical protected hashes before and after:
all meshes/UVs/weights/custom normals, transforms, bone rests and action curves.
The source remains at 68,244 all-variant triangles, 16 mesh parts, 65 bones and
19 clips. The general shared-character validator passes including arm/waist
coverage, head delta compatibility and locomotion pose checks.

`source_comparison.jpg` holds matched Blender close-ups. Its head is the older
diagnostic base; actual roster heads are in the Web captures. `before_after.jpg`
holds fixed sun/shade Web comparisons at idle frame 2. Shade comes from a real
shadow-only occluder along the unchanged sun direction, with sun shadows enabled
and sky/exposure unchanged. Seven current Web views cover both sleeve types,
John's save, referee, a pass and broadcast distance, without browser errors.
The single-actor scene isolates cloth response; it is not the whole venue.

Four existing headless integration checks pass: shared resources, shared-head
roster, pose safety and 11v11. The resource check samples the actual imported
mask (print 0.600, shirt 0.788, sock 0.894), verifies mips and one shared normal,
and checks team-local propagation with independent playback. Play/Watch,
keyboard/AI kickoff, options, return-to-title and minimum UI layout pass in
Chromium SwiftShader; `match/title_web_check.json` records that scope.

The uncompressed imported image payload is approximately 16 MiB for the shared
normal including mips and 1.33 MiB per role mask (24 MiB for these runtime data
maps). Pigment mips add memory too; the source import also retains its embedded
default material maps. This is not measured total VRAM or process memory. No
extra mesh parts, live cloth, shader layers or per-player kit copies are added.

The result is an incremental material pass. Bright direct light still washes
some pale areas; keeper graphic reconstruction, individual likeness, residual
garment folds and native M1 lighting/performance approval remain open. Fixed
stills do not establish all-animation acceptance. Next BR-022 (22/25) subtask:
match both goalkeeper kit graphics to their archived sheets, then check front,
back and keeper-save poses in the actual roster.
