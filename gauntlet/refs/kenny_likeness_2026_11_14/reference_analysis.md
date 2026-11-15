# Kenny: reference analysis and production brief

14 November 2026. Owner requests an independent Kenny character and three judged likeness revisions, aiming for 10/10 without promising that score. Ambulance batch fa5c06d is verified deployed. Independent Kenny baseline: 4.1/10; rubric head/face 40%, hair 25%, body 20%, materials 15%.

## Reference index and visual target

- `gauntlet/refs/characters/kenny_3view.jpg`: primary neutral front, three-quarter and profile head proportions. Broad lower face and chin, long defined nose, hooded/deep-set pale eyes, low continuous brow; uneven brown roots and pale highlights in loose shoulder-length waves.
- `kenny_hair_top.png`, `kenny_hair_back.png` in that folder: crown parting, irregular swept-back clumps, darker temples/roots, fine flyaways and nape length. These are owner references, without a claim about their original photographic provenance.
- `kenny_omega_sheet.png`: body and gear turnaround, wet arena hair, facial details and expression support. Its red/warm arena lighting must not be baked into albedo. The neutral portrait and wet arena hair represent different grooming/lighting states; match primary masses and identifying forms consistently.
- `tools/assets/sources/kenny_face_owner.png`, `kenny_body_{chest,abdomen,arm}_owner.jpg`: owner-supplied texture inputs already used by this project. They do not replace geometric likeness review.

Palette direction: warm light skin `#B9856D`, restrained flush `#A86659`, brown roots `#49372A`, mid hair `#8B6C4B`, selected ash/gold highlights `#C3AD80`, beard `#70503C`, iris `#4E3C2E`, warm dark mouth `#57342E`. The owner's explicit 8 November dark-brown-eye choice takes precedence over apparent pale eyes in a reference. These are approximate visual intent, not calibrated albedo samples. Preserve varied pores and roughness without a uniform orange-peel or wax coating. Hair needs overlapping fine strands and irregular clumps rather than opaque faceted zigzag ribbons.

## Baseline gaps and first revision

| Area | Independent finding | First correction |
| --- | --- | --- |
| Head/face | Bulging eyes, overscowled brow, generic face | Own the existing fitted shape, then correct the brow/eye transition, nose profile and cheek–jaw–chin planes with smooth bounded fields; keep eye centres and mouth/neck contacts stable |
| Hair | Largest technical defect: broad faceted ribbons, helmet crown, flat clumps and dark gaps | Finer irregular loose curl ribbons with controlled scalp overlap; asymmetric swept crown, darker roots and selected highlights; shoulder/nape length retained |
| Materials | Heavy painted beard, exaggerated pores/orange peel | Soften high-frequency albedo/beard detail and own the head roughness/wet maps; coordinate any runtime-only pore strength with the main owner |
| Body | Athletic and usable; stretched shoulder/armpit patches | Preserve the existing mass and rig; reduce local map stretch/harsh detail rather than arbitrary muscle inflation |

## Independent source authority

Canonical editable source: `tools/blender/characters/Kenny.blend`. A one-time, explicitly recorded bootstrap imports the existing Kenny-owned body/groom exports and captures current Kenny maps and bind data into that file. Historical donor: `kenny_body.glb` was a copy of the supplied Cody rig/mesh. This remains donor-derived topology; it is not an independently created sculpt or scan. Record hashes and provenance in packed native text data.

After bootstrap, `tools/blender/characters/kenny_character.py` reads only this native authority and neutral code. It must not read Cody models, maps, scripts or generated game outputs as rebuild inputs. All canonical maps are packed; all 67 bones, bind transforms, weights, material keys and authored groom data are owned by Kenny. Existing Kenny generation entry points become compatibility routes to the same authority, with no second active pipeline. Shared eye generation must not recreate Kenny from Cody inputs.

The existing Kenny fitted face is baked once into native geometry before the first sculpt. The old yoke correction may be captured once as historical donor-derived seed geometry, without retaining a runtime/source dependency on its character-specific script. No exported morph targets: the existing expression installer expects a mesh without them. Do not bake `BodyBulk.KENNY`; the main owner keeps that explicit Kenny profile at runtime and disables the old `KennyFaceShape.apply` after the first baked export to prevent double application. Runtime/scenes/tests remain the main owner's scope.

## Budgets and validation

- Baseline body: 74,213 triangles, one 67-joint skin, 12 source materials. Groom: 38,501 triangles/four meshes on the same rig. Approximately 112,714 combined before runtime eyes/helpers. Preserve body topology/weights and target equal or lower groom cost; any increase needs a concrete visible gain.
- Retain current texture dimensions, packed editable maps and portable game outputs. Add owned `kenny_skin_head_roughness.png` and `kenny_skin_head_wet.png`; initial patterns are explicitly snapshotted donor-derived work, then independently authored.
- Each of exactly three revisions ends with locked neutral front/three-quarter/profile/eyes and body views plus animated poses under the main owner's Godot probe, followed by independent scoring. No fourth visual loop to chase a number.
- Cheap authoring gates: rig/bind/weight and material-key preservation, triangle/material/map counts, no exported morphs, packed-source completeness, no Cody identity input in active rebuild paths, and identical Cody asset fingerprints. Main owner verifies animation paths, expression/eye/hair behaviour, contacts, deterministic matches and release.
- Native M1/16 GB performance is unverified until measured on the target Mac; isolated cloud renders cannot establish 60 fps.

Active guides: Blender Director, Import Wrestler, Character Artist, Hair Groom, Realistic Style, Asset Optimization and Godot Export. Headless Blender is the available authoring path under project guidance. Source bootstrap and the first art revision are now authorised by the completed baseline; do not begin the second revision before its judgement.

## Revision 1 handover

Exported body 74,213 triangles/12 stable material keys; groom 27,769 triangles in four meshes (10,732 fewer than baseline), combined 101,982. One 67-bone skin per export, no morphs. Native source is 74,983,596 bytes with packed seed/working maps and bind/guide data. Game material colour factors remain white; skin tint, brown-eye tone and `BodyBulk.KENNY` remain runtime. Face geometry is baked, so the main owner disables the old runtime face sculpt. Head pore mix is separately reduced through the owned runtime profile by the main owner.

`source_identity_audit.json` in the sibling judge folder compares the current native body against its frozen owned seed, using native vertex identity rather than donor-index assumptions: 4,339 head vertices change, maximum 4.206 mm and RMS 0.485 mm; protected head/neck below y1.575 and all eye-material vertices remain exact. All 67 bind matrices/parents and all body weights are identical. All 74 captured Cody asset fingerprints remain unchanged. The native first captures the prior fit/shape fields and historical yoke geometry; subsequent shading uses rebuilt native normals rather than the former runtime normal-bending overlay.

The compatibility builders now route to the native authority. The shared eye builder no longer regenerates Kenny. Await the first independent judgement before any second art revision.

## Revision 1 judgement and diagnosed regression

Independent result: **4.0/10**, below the 4.1 baseline. Scores: head/face 3.5, hair 3.0, body 6.5, materials 3.5. Revision 1 is not a supported visual improvement. Fine strands improved but lost curled mass; angular cheek and body patches worsened continuity.

Root's fixed-camera normal/detail-off diagnostic retained the angular patches; unlit removed them. Source audit found that globally clearing authored split normals broke cross-UV smoothing: 17/17 chest duplicate groups diverged over 20°, four over 45°, versus near-identical baseline normals. The initial face capture also omitted the original fitted normal offsets, weighted RELAX passes and SOFTEN normal stage. This was a capture defect, not a reason for more speculative facial carving.

## Revision 2 handover

The original Kenny-owned baseline GLB was retrieved once from project history, verified against the original bootstrap fingerprint, and its local positions/per-loop normals packed into `KennyRawSeed` in the native file. Kenny's fit offsets/normal offsets and full RELAX/SOFTEN parameters are also packed. Future builds read that block only. The corrected pipeline applies fit normal offsets, inverse-transpose field normal transport, 14 synchronised welded-neighbour RELAX passes and SOFTEN, followed by the captured historical yoke field and the existing first-revision sculpt. No additional facial carving was added.

Normal continuity gate passed before the export: zero tested head/chest/arm groups diverge over 20°; chest minimum dot 0.999955, arms 0.999970/0.999924. Eye geometry, binds and weights remain unchanged; protected neck maximum numerical difference is 0.134 micrometres. Exported tangents are explicit. The changed live bulk/face order is not claimed pixel-identical to the old pipeline; the main owner retains animation/contact checks.

Hair gains crossed rounded loose clumps, a lifted asymmetric crown, dark roots/selected blond tips, denser minification-safe clump cores and fine transparent edges. The opaque cap ends at the skull/nape rather than forming a long curtain. The main owner corrects the Kenny hair shader's alpha-to-coverage texture coordinate. Atlas mean alpha is 0.506; >0.5 coverage stays approximately 0.60 at native through 8× minification, versus revision 1 falling to 0.077.

Export: body 74,213 triangles; groom 38,170, below the original 38,501; combined 112,383. Twelve body material keys, 67 bones, no morphs, white material factors. Native file 78,133,788 bytes. All 74 Cody asset fingerprints still match. Await the second independent judgement; no third art pass until its findings.

## Revision 2 judgement and final revision 3 handover

Valid second judgement: **4.5/10** (face 4.0, hair 3.5, body 6.5, materials 4.5). The major first-revision shading regression is substantially repaired. Likeness remains well short of the requested target: the hair still forms lateral whiskers and crimped strips, with an overscowled face and heavy coarse stubble. These are supported remaining gaps, not a reason to inflate the score.

The final third pass removes the old flyaway guides identified by nonzero root sway alpha. Main clumps now use root-anchored smooth cubic paths with irregular three-dimensional elliptical S/curl motion and rounded profiles; a few short downward wisps replace long regular lateral rays. The source retains dark roots, selected ash/blond tips and the minification-safe strand atlas. Ear-level geometry is explicitly bounded under the owner's unchanged size limit.

The final face pass lowers/softens the overhanging brow and upper lid, with small forward cheek/chin contour corrections; eye geometry remains anchored. Beard/brow high frequencies and dense dark pigment are reduced. Body detail is softened modestly, and skin maps rebalance red/green/blue while holding pixel luminance; runtime tint, eye tone and bulk remain live. Donor UV layout, underlying topology and the available source textures remain limitations; this is not a scan-quality anatomical rebuild or a claim of AAA completion.

Final export: body 74,213 triangles + groom 38,186 = **112,399**, below the original combined 112,714. Ear P02–P98 width **0.217399716 m**, lowest hair **1.457218289 m**, both passing the pre-export owner bounds. Native source **80,207,159 bytes**, 67 bones, 12 body material keys, no morphs, explicit tangents. Source identity/normal audits are updated; `source_rebuild_fingerprints.json` records the 19 expected game-output hashes for cold regeneration. The main owner performs the third independent judgement, game checks, cold regeneration and publication. No fourth cosmetic pass is planned.
