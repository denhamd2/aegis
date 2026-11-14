# Kenny: three likeness revisions and independent identity assets

Owner request after verified ambulance publication `fa5c06d`: review repository
head/face/hair/body references, complete three independent judge/revision loops
aiming toward 10/10, and remove continuing Cody identity dependencies.

## References and fixed capture

Primary: [head three-view](../characters/kenny_3view.jpg),
[character sheet](../characters/kenny_omega_sheet.png),
[crown](../characters/kenny_hair_top.png),
[back groom](../characters/kenny_hair_back.png). Earlier generated review images
are historical evidence, not targets. Dry/wet curl, stubble, redness and lighting
vary across references; judge stable identity features. The owner's existing
dark-brown eye preference remains applicable.

Nine isolated runtime views per state at 768×768, Forward+ Vulkan llvmpipe:
four head/body yaws plus crown. Idle at 30%, fixed lighting, cameras and AA.
The actual runtime meshes, shape/material adapters and groom are captured.
These are not full-arena, native-performance or reconstructed reference cameras.

Rubric: head/face 40%, hair 25%, body 20%, skin/materials 15%. The read-only
visual judge is independent of the source specialist and runtime integrator.

| State | Head/face | Hair | Body | Materials | Weighted /10 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline | 4.0 | 2.5 | 6.5 | 4.0 | **4.1** |
| Revision 1 | 3.5 | 3.0 | 6.5 | 3.5 | **4.0** |
| Revision 2 | 4.0 | 3.5 | 6.5 | 4.5 | **4.5** |
| Revision 3 | 4.0 | 4.0 | 6.5 | 4.5 | **4.6** |

[Final independent verdict](round3_review.md): **ship with notes for owner review;
likeness acceptance remains open**. Raw weighted score 4.575 rounds to 4.6. Exactly
three cosmetic revisions were exported; diagnosis and invalid captures are not
extra scored iterations.

## Revision history and limits

Baseline feedback: generic scowled face, prominent eyes, faceted zigzag ribbons,
helmet crown and black gaps; coarse pores, heavy beard and shoulder stretching.
The athletic body taper was retained rather than indiscriminately enlarged.

Revision 1 established owned source/maps and finer hair cards but regressed to
4.0: angular shading and sparse straight curtains. Its normal bake omitted old
fit offsets, TABLE normal Jacobian, 14-pass RELAX and SOFTEN; custom cross-UV
normal continuity was lost (baseline minimum dot .99996; R1 chest .484).
Normal/detail-off kept the patches; unlit removed them. See archived diagnostics.
R1 remains in the ledger rather than being relabelled as an improvement.

Revision 2 restored the complete owned bake, transported seam normals, dense
alpha cores and loose curved clump volume. Correct shader mip-edge AA uses
`ALPHA_TEXTURE_COORDINATE`. An intermediate typo produced shader errors/white
hair: those captures were rejected and never scored. The valid nine-view R2
set scored 4.5. Face specificity and regular sideways hair strips remained weak.

Revision 3 removes horizontal flyaway guides, reworks S/curl centreline paths
and wisps, softens brow/lid/cheek/jaw fields and reduces coarse stubble treatment.
The final judge found a tidier silhouette and more continuous clumps, while
facial identity remains generic/over-scowled. Stiff crown loops, pale broad ribbons
and straight back curtains still miss irregular rounded curls and dark roots with
blonde ends. Coarse brow/beard and residual chest/shoulder texture stretching
remain. All nine final views and four primary references were reviewed. There
is no new obvious static missing-geometry or opaque-sheet blocker. Automated
success does not establish visual likeness or AAA quality.

## Independence: before and after

Before: KennyModel extended CodyModel; its separate `kenny_body.glb` was
byte-identical to `cody_rhodes.glb` (71,421,480 bytes; SHA256
`13763adae79df4cff2113633dc4a532322aa88d60a05ea181682f55fb16ce9c3`).
Inherited setup applied CodyBodyShape and Cody head roughness/wet maps. Pain
expressions depended on Kenny passing a Cody type check. Active face, hair,
texture, eye and review builders read Cody inputs; no Kenny native source existed.

Now: [Kenny.blend](../../../tools/blender/characters/Kenny.blend) owns editable
body/groom, 67-bone binds/weights, packed seed maps and frozen guide/sculpt data.
[The builder and rebuild instructions](../../../tools/blender/characters/README.md)
are the normal authority; old entry points delegate to it. One-time historical
migration commands refuse to overwrite the source and are not rebuild inputs.
Donor lineage remains documented: this is donor-derived, not an original scan.

Kenny and Cody extend neutral RiggedWrestlerModel independently. CodyBodyShape
stays Cody-only; Kenny owns head finish maps, skin/gear/eye/hair profiles and
expression settings. Shared neutral rig, animations and rendering algorithms
remain shared. The exported face is baked once; BodyBulk.KENNY, tint and eye
tone remain live. Pain expressions consume explicit profiles for all characters.

## Validation

- **78/78 focused cases across 11 suites pass**, zero failures/errors/orphans:
  Kenny, Cody, Roman, FaceExpression, BodyBulk, HipHelpers, ShoulderHelpers,
  SkinLook, KennyHairSway, ModelOrientation and Blood. See
  [JUnit report](final-focused-tests.xml) and [log](final-focused-tests.log).
- Both load orders and two Kenny instances checked: changing Kenny head colour,
  sweat or pain cannot alter Cody or the other Kenny. Runtime face equals the
  owned export plus the intended live bulk; eyes use their owned rest geometry.
- All **74 Cody asset fingerprints unchanged**. Cody's fixed control portrait is
  pixel-identical before/after the neutral adapter extraction (RGB mean 0).
- Final body 74,213 + groom 38,186 = **112,399 triangles**, versus original
  112,714. Native source 80,207,159 bytes; body GLB 38,380,596; hair 2,595,392.
  Ear-height P02–P98 hair width .2174 m (<.27), lowest hair 1.4572 m (>1.40).
- Source audit: 67 bones/binds/parents and weights preserved; protected eye
  geometry unchanged, protected neck maximum delta 1.34e-7 m. No tested seam
  normal divergence above 20°. See source identity/normal audit JSON files.
- Final cold rebuild started with only Kenny.blend and its builder, no Cody
  files or generated game inputs. Positions, normals, indices, UVs, weights,
  binds, material/node definitions and embedded images match; hair BIN exact.
  One body tangent component differs by .00010002. All 17 generated PNG maps
  are byte-identical. GLB container byte identity is not claimed. See
  [semantic comparison](isolated_regeneration_final_detail.json),
  [map comparison](isolated_maps_final.json) and container fingerprints.
- Removed 11 obsolete donor-named extracted maps/imports only after reference
  checks (65,049,397 bytes). Retained the still-live mouth map; current embedded
  Kenny maps and matching imports are included. See obsolete_texture_cleanup.json.
- Python sources parse and `git diff --check` passes. Final nine-view renderer
  completed without shader/runtime ERROR lines.

This focused result does not label full gameplay CI green. Before this batch,
ambulance and cell CI shared four failures/two errors/five orphans in 1,316 cases,
including the now-replaced stale test requiring Kenny to inherit Cody. Other
baseline categories: prop overlap, paired Cross Rhodes clearance, realism cue
and fire material lookup. Exact new CI results must be recorded separately.

## Delivery

Commit/push and exact Mac publication verification are pending. Native M1/16 GB
60 fps, full-arena appearance and final owner acceptance remain unverified.
