# Reference-led player, motion and turf finish

Authorized 23 October 2026. BR-022 (22/27), BR-021 (21/27), BR-023
(23/27), BR-026/027 and BR-025 retain their existing IDs and open hardware gates.

Baseline: the native front/three-quarter/profile captures in
`../broadcast_turf_refresh_2026_10_23/native_heads/` match the four current GLB
hashes. Compared against original portraits 69012, 69010, 69016 and 69015,
these remain approximately 2–3/10 for realism, with generic angular anatomy,
waxy skin, poorly fitted eyes, cap-like scalp hair and weak facial hair.
Import/geometry tests are not visual approval.

Production order: player Des in clay first; independently finish John, Shane
and referee Des; add shared body/garment fullness; smooth presentation without
changing authoritative contacts; introduce cinematic-only optical effects;
make turf detail available across the field with bounded visible geometry.

Identity priorities: Des needs round cheeks, lower-face/neck fullness, receded
scalp and a proper dark goatee; John needs softer cheeks/jaw, fitted lids,
swept dark-blonde/wheat hair with his warm beard retained; Shane needs his
rounded cheek/brow/nose/mouth forms and short crop; the referee needs older
soft tissue, hooded eyes, jowls and a broad grey moustache. Preserve fair skin,
the shared neck interface, rig, gait keys and player-specific expression data.

Defaults: subtle body fullness (Des greater than John); sharp live gameplay;
moderate background depth of field and restrained motion blur on cinematic
shots only; existing MSAA default with optional TAA. Free/original assets only.
No football Web export or wrestling-project edits.

Turf: short curved leaves and intermediate clusters use field coordinates,
projected size, frustum priorities and spatial MultiMesh chunks. Begin with a
240k drawn-triangle budget, retain mud/water/paint masks, and prewarm cuts.
At the old near density, a literal full-field copy would draw 190.4m triangles.

Validation: matched clay and textured views, actual native Forward+ portraits
and moving captures, shared morph independence and deformation poses,
physics/replay invariance, camera skip/cut restoration, turf limits and a full
22-player/referee match. Cloud Vulkan software rendering is appearance evidence;
M1 Pro 16 GB 1080p60 remains unmeasured until target-device profiling.

## Player Des: original side views, 23 October

Archived unchanged 69911/69910/69909 in
`references/source_uploads/chat_attachments/boardeaux_des_side_back/`.
These supersede the generated sheet for his scalp coverage: a high temporal
wedge joins a short, dark-brown horseshoe around the sides/back, with visible
sideburns and an exposed frontal scalp/crown. Upper-lip hair is much lighter
than the chin goatee. Five gaps for this scoped correction: missing temporal
mass, near-invisible rear hair, too-short strands, undifferentiated black
scalp/beard tone, and overly strong moustache. The existing face remains a
separate unfinished likeness gate; this groom change does not certify AAA.

Identity contract: `bordeaux_09`, Boardeaux player (all eleven away aliases),
`des_feeney_head.blend`, `players/bordeaux_09.glb`, `des_side_hair.glb`.
Preserve referee `des_feeney_sr`, protected head/neck coordinates and rig,
fullness/expression shapes, kits and animation library. Validate native
front/profile/rear portraits, geometry export audit and runtime aliases.

## Rounded Feeney eyes

The owner's additional direction applies to both identities. Current saved
sculpts have rounder visible lid apertures; globe centres, gaze/iris UVs,
per-identity brow/age shapes and the shared neck remain fixed. Front surface
visibility samples change player Des's height/width from 0.313 to 0.413 and
the referee's from 0.247 to 0.329. These are geometry checks, not likeness
ratings. See `round_eyes/apertures.json` and the native portraits.

The enlarged aperture exposed an inherited blink defect. The inset orbital
surface was excluded from the old lid modifier, leaving the central globe
visible. The new closure fits that surface over the curved globe; sampled
residual exposure is below 5% on both heads. Native closed-lid appearance is
checked separately. The correction propagates to all eleven Boardeaux slots;
Shane/John's individual shapes and all 65-bone body/action assets are retained.

Current finishing gaps: individual face anatomy/likeness still falls short of
AAA, and the collar/shoulder openings visible in both historical and current
portraits remain a kit-interface task. Disabling the new near LOD leaves those
openings, so this is not evidence of a new subdivision regression. The current
pass does not close those visual gates.

## Validation and next acceptance gates

`validation.json` records 21 unique smoke checks, the four-head source/export
audit, runtime asset hashes and original-photo verification. Final Feeney
portraits and closed-lid evidence are in `feeney_native/` and
`feeney_blink_native/`. `des_groom/` records the earlier scalp-only review;
the subsequent eye edit does not change its side/back coverage.
`presentation_native/` contains the actual menu, intro, turf and gameplay
views. Its default turf draw is 205,568 triangles across 12 near/16 intermediate
chunks; shaders and cinematic effects rendered without engine errors.

Pose/contact/replay isolation, body sharing and tint preservation across LODs
pass. The complete unskipped 180-second match reaches results. This one seed
has 6/5 goals, 6/4 contested shots and no keeper saves, so it does not certify
balanced goalkeeper or wing-play outcomes. Short headless runs sometimes print
shutdown ObjectDB/resource warnings; verbose isolation exits cleanly, leaving
cleanup observation open rather than claiming a leak-free runtime.

The optional TAA setting is persisted; native evidence uses baseline MSAA.
Camera focus/blur restore on wide shots, skips and exits; live gameplay stays
sharp. Still captures do not prove moving visual polish or M1 performance.
Next under BR-022 (22/27, in progress): repair the common collar/shoulder skin
interface, then refine individual facial anatomy against matched references.
Keep BR-025 target-Mac profiling open.
