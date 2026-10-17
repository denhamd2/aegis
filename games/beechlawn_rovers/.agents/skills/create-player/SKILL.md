---
name: create-player
description: Create or substantially refine a Beechlawn Rovers footballer in Blender from the project's archived character sheet and kit references. Use for identity, body proportions, face, hair, kit, materials, rig fit, and Godot-ready validation. This skill is specific to Beechlawn Rovers.
---

# Create a Beechlawn football player

Deliver a recognizable, reference-faithful, game-ready footballer on the first serious pass by resolving reference conflicts and likeness at blockout, then validating geometry, materials, and kit in consistent views before adding small detail. “First pass” means a disciplined, evidence-led build that avoids preventable rework; it does not mean skipping review or promising a one-shot AAA result.

## Scope and routing

This skill applies only inside `games/beechlawn_rovers/`. Do not apply its roster, kit, proportions, or output rules to Aegis wrestling characters. Use the project reference archive as the source of truth. Before modeling, also read the relevant repo guides:

- `../../../../../.claude/skills/blender-director/SKILL.md`
- `../../../../../.claude/skills/character-artist/SKILL.md`
- `../../../../../.claude/skills/blender-materials/SKILL.md`
- `../../../../../.claude/skills/realistic-style/SKILL.md`
- Add `rigging`, `hair-groom`, `uv-workflow`, `blender-uv-texturing`, or `retopology` only for work actually in scope.

Follow `../../../docs/art_reference_implementation_plan.md` and `../../../references/README.md`. Retrieve untouched source files from `../../../references/source_uploads/`; do not rely on chat history, preview thumbnails, or generated reconstructions as the only source. Keep Blender sources and repeatable build scripts in `../../../tools/blender/beechlawn/`, and export game assets only into this Godot project.

## Reference analysis before modeling

1. Identify the exact player, squad number, role, character-sheet source, and matching kit board. Record source filenames in a short asset brief.
2. Separate evidence by purpose: full-body front/side/back views establish silhouette and garment fit; portrait and expression views establish face, hair, and skin; kit close-ups establish crest, number, trim, fabric, collar, and sleeve construction. Use the individual character sheet for that player's fit and appearance, and the shared kit sheet for garment/graphic construction.
3. Make a feature map before editing: height/build and proportions; head shape and facial landmarks; hairline, hairstyle, facial hair; shirt silhouette and sleeve length; crest, number, sponsors/marks if shown; shorts, socks, boots, and goalkeeper-specific equipment. Link each decision to its source image or label it as an assumption.
4. Resolve disagreements explicitly in the brief. Follow the project's decisions in `art_reference_implementation_plan.md` (including the current sleeve and crest-date notes); do not silently invent a crest date, number, identity, body feature, or kit mark. Measurements read from generated sheets are visual estimates, not authoritative biometric data.
5. Define review views and target scale before adding detail: neutral front, side/profile, three-quarter, and back; portrait close-up; and the expected Godot broadcast view. Keep camera, focal length, lighting, exposure, pose, and color management fixed for before/after comparisons.

## Build order

1. **Proportions and silhouette.** Start at the project's metre scale and use the supplied Y-Bot as a rig/import baseline only, not as the final human likeness. Match total height, head-to-body ratio, shoulder/torso/hip mass, limb lengths, and stance to the character sheet. Confirm the silhouette in front, profile, and back before facial or cloth detail.
2. **Body and face.** Fit the human body to the shared skeleton and preserve its usable bone names/rest pose unless a measured rig problem requires a change. Establish skull, jaw, cheek, brow/orbit, nose, lips, ears, neck, and facial hair as distinct readable forms. Correct broad shape before painting detail. Compare face landmarks in front, profile, and three-quarter views; use image measurements as diagnostics only, with the rendered likeness and source sheet deciding the result. Keep eyelids, mouth, jaw, and shoulder/hip deformation topology suitable for animation.
3. **Hair and facial hair.** Match silhouette, hairline, direction, and clump scale from the sheet. Build clean root coverage and tapered flow; avoid broad flat card ends, hard scalp seams, uniform plastic shine, and beard edges that read as a cutout. Use a scalp/base layer plus restrained cards or clumps appropriate to camera distance. Keep hair and beard shading out of skin-only subsurface, sweat, and wetness masks. Do not copy a hero-character strand count or triangle increase without measuring the football camera, overdraw, and 4v4/22-player cost.
4. **Kit construction.** Model jersey, shorts, socks, boots, and keeper gloves as clean, appropriately layered clothing pieces. Match garment fit, sleeve length, collar, stripe/block layout, cuff and sock bands, boot silhouette, crest placement, and front/back/shorts numbers to the references. Keep logos and typography crisp and correctly oriented; use exact supplied designs, not guessed text. Use separate material regions or atlases so roster variants share materials where practical. Do not let the cloth hide or distort the player's body silhouette.
5. **UVs and materials.** Keep UV islands aligned to anatomy and garment panels; inspect seams and mirrored areas. Use base-color/albedo for pigment and graphics, normal maps for restrained pores/weave/stitch relief, and roughness variation for skin, hair, and cloth. Treat color textures as sRGB and data maps (normal/roughness/masks) as linear. If image-generation or projection is used to create pigment/detail, register it to the model's actual UV anatomy, preserve source detail on untouched islands, and inspect seams; the generated atlas is texture source art, never a substitute for the actual model in-engine. Keep skin response subtle and controllable: pores and micro-normal should not become noise at gameplay distance; subsurface scattering should be modest and restricted to exposed skin; wetness should be bounded and optional, never a global glossy layer. Prevent hair pigment from receiving flesh scattering. Avoid baking scene lighting or shadows into base color.
6. **Rig and export.** Keep the gameplay skeleton reusable across the roster where proportions allow; use per-player mesh/material data rather than duplicating a full rig or unique shader for every player. Check applied transforms, metre scale, Y-up orientation, clean hierarchy, weights, seams, and extreme shoulder raise, sprint, kick, crouch, and fall poses. Export GLB with packed/relative textures and stable material/action names. Retain the editable `.blend`, source textures, and deterministic build script.

## Reference-led quality loop

- Create a simple material/lighting lookdev scene and produce neutral front, side, three-quarter, and back renders plus a face close-up. Match the source views as closely as possible in camera and pose before judging likeness; do not use post-processing to hide a geometry or texture mismatch.
- Compare the same fixed views side by side and record the largest remaining gaps by category: silhouette, face, hair, kit construction/graphics, material response, or rig fit. Fix the largest structural mismatch first. A texture cannot repair wrong facial planes; extra polygons cannot fix a wrong silhouette; more hair cards cannot fix a bad hairline.
- Use Aegis's recent Roman/Cody work only as transferable method: separate geometry corrections from UV pigment, preserve a known-good rig when possible, mask hair independently from flesh shading, use bounded character-specific material tuning, compare identical multi-view captures, and report measured costs. Those reviews still identified face-plane, pore, hairline, and clump-end gaps after the passes; a better texture or lower triangle count is not proof of a finished likeness. Do not copy its wrestlers, art, exact material values, groom density, or hero close-up budget into football.
- Inspect the actual exported asset in Godot after Blender approval. Verify face and kit in the broadcast camera, texture import/color-space, material slots, bone/rest pose, scale/orientation, and deformations with the production rig. A Blender mannequin or studio render is an iteration gate, not final validation.

## Performance and quality gates

Prioritize likeness and construction at the intended camera distance, then optimize without losing the reference match. Share materials and rig data; limit unique transparent hair layers and shadow casters; use mipmapped, compressed textures and suitable LODs. Measure triangle count, texture memory, alpha overdraw, and shadow cost rather than assuming fewer polygons alone means faster rendering. Review one representative player in the 4v4 scene, then test the assembled roster. The M1 Pro/16 GB 1080p/60 fps target is unverified until measured on the target Mac; cloud renders do not establish it.

Do not call a player reference-matched until the front/profile/three-quarter/back and portrait comparisons show no major identity or kit mismatch, and the exported Godot character remains readable in the broadcast view and expected poses. Record unresolved source conflicts and the exact remaining visual gaps instead of presenting assumptions as completed facts.
