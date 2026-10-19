---
name: create-player
description: Create or refine a Beechlawn footballer's likeness, body, hair, kit, UV textures, or shared-rig integration from archived references; validate the exported player in Godot.
---

# Create a Beechlawn player

Scope: Beechlawn Rovers only. Keep wrestling assets and rules separate. Aim for recognisable, reference-faithful players through measured iteration; a first pass is a review gate, not a promise of an exact or AAA likeness.

Paths below are relative to the **repository root**. Preserve the current production asset and improve it in place. Inspect the current source and runtime wiring before choosing a generator: rebuilding an older source can discard later animation, tailoring and material fixes.

## 1. Establish the reference and baseline

Read `games/beechlawn_rovers/docs/art_reference_implementation_plan.md` and `references/README.md` within that project. Retrieve archived originals; copy new uploads unchanged into its reference archive with provenance and SHA256. For face identity, use the owner's latest original portrait ahead of generated character-sheet faces; retain sheet profiles as secondary evidence and label unseen anatomy as an estimate. Resolve conflicting kit marks through recorded owner corrections.

Write a short feature/gap brief: player and number, evidence filenames, head/body silhouette, facial landmarks, hairline, garment construction, graphics and five largest current mismatches. Separate expression, perspective and indoor lighting from identity. Decide fixed front/profile/three-quarter/back, portrait and gameplay review views before editing. Preserve before captures with the same camera, pose, light, exposure and render settings used after.

Read these specialists when their branch applies:

| Work | Repository guide |
| --- | --- |
| Reference-led production | `.claude/skills/blender-director/SKILL.md` and its reference-image-match workflow |
| Anatomy, face or clothing | `.claude/skills/character-artist/SKILL.md` |
| Mesh edits and source organisation | `.claude/skills/blender-modeler/SKILL.md`; add `.claude/skills/blender-modeling/SKILL.md` for mesh-operation detail |
| Skin/cloth response | `.claude/skills/blender-materials/SKILL.md`, `.claude/skills/realistic-style/SKILL.md` |
| Hair silhouette/cards | `.claude/skills/hair-groom/SKILL.md` |
| UV layout or image registration | `.claude/skills/uv-workflow/SKILL.md`, `.claude/skills/blender-uv-texturing/SKILL.md` |
| Changed weights, rest pose or rig | `.claude/skills/rigging/SKILL.md` |
| Godot delivery | `.claude/skills/godot-export/SKILL.md` |

Use available headless Blender/bpy directly when MCP is absent. Store editable sources and repeatable scripts in `tools/blender/beechlawn/`; exported assets belong to the football project. No Blender dependency at game startup.

**Gate:** original evidence, current production source, baseline views and prioritised gap list are recorded.

## 2. Fix form, then surfaces

Work from silhouette to facial planes to detail. Check neutral clay front/profile/three-quarter before tuning skin. Fit skull, jaw, cheek, brow/orbit, nose, lips, ears and neck as geometry. Keep lids fitted to curved eyeballs; iris placement cannot repair a wrong aperture. Treat a smile as a separate editable expression from neutral identity. Use proper oral geometry for an open smile; skin pigment cannot stand in for teeth or mouth depth. A single portrait cannot establish an exact hidden profile.

Preserve the common skeleton, rest transforms, bone names, animation timing and body/kit interfaces. Use an independent head variant for individual likeness so one player's edits do not change the squad. Keep topology-compatible sculpt deltas fingerprinted; preserve the neck's positions, weights **and normals**. See [production checks](production-checks.md) for seams, skin binding and safe exports.

Hair needs scalp coverage, a reference-shaped hairline/crown and directional clumps before flyaways. Inspect root edges and card ends from several angles. Bound transparency, shadow cost and strand count to the football camera.

Match garment silhouette before texture polish: torso and shoulder mass, collar, sleeve joins, cuffs, shorts leg openings, sock bands and boots. Map supplied complete panel graphics onto the constructed garment, including crest, sponsor, manufacturer and trim. Keep text size and placement reference-led. Check front and back with folded limbs, not only a bind pose.

Preserve anatomical UV islands and register pigment to them. Base colour carries pigment; geometry and restrained normal/roughness maps carry form and relief. Keep photographic illumination out of albedo. A rectangular portrait overlay is not a facial texture solution. Colour maps are sRGB; normal/roughness/masks are linear. Mask hair separately from skin scattering/wetness. Use exporter-supported PBR nodes and inspect the saved image after reload to catch colour-space changes.

**Gate:** matched clay and textured views show the structural changes; record remaining likeness, garment and texture gaps before export.

## 3. Integrate and prove

Export compatible GLB with stable part/material/action names and editable source. For a head package, reuse the live body skeleton and animation player; validate joint-index/bind compatibility and swap the matching eyes/hair when needed. Hook the variant into the actual player resources, including retained small-sided fixtures. An isolated prototype render alone does not update the match.

Inspect the actual Godot import in portrait and broadcast views, then representative idle, sprint, kick and turn poses. If shoulders, legs or clothing changed, extend checks to crouch, slide/get-up and keeper poses. Test transitions and contact timing where affected. Use bounded, serial Godot checks through the project runner; diagnose a timeout before starting another copy.

Count active rigs, mesh surfaces, triangles, texture dimensions/mips and transparent layers. Shared resources should propagate body/kit/animation updates while per-player sculpt and playback stay independent. Validate the assembled 22 players plus referee, not just the isolated asset. Cloud/Web captures establish integration and layout; native M1 Pro 1080p/60 fps remains a target until measured there.

Save before/after evidence, export/import results and unresolved gaps beside the asset brief. Generated promotional artwork is source art, not evidence of the playable mesh. Report the exact asset and backlog ID/ordinal changed; keep likeness approval separate from technical validation.

**Gate:** the intended roster player uses the reviewed export, common assets remain intact, relevant runtime checks pass and evidence/limitations are recorded.
