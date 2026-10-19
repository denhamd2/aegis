# BR-022 — Shane photo-led head refinement (22/25, in progress)

Identity source: `references/source_uploads/chat_attachments/shane_face_photo/69012.jpg`, owner-uploaded original photo on 2026-10-19. Preserve the original unchanged. Character sheet `character_roster_sheets/1-69014.jpg` remains secondary profile/hair evidence; current kit and labels remain authoritative. The photo is a smiling, slightly turned portrait under indoor light, not a neutral scan. Hidden profile depth and exact dimensions remain estimates.

## Feature map and gaps before editing

- Current lower face is too short and rectangular. Photo has broad cheek mass, a rounded, tapering jaw and a longer cheek-to-chin interval. Preserve neck seam and head-bone fit; narrow rear jaw corners, extend chin gently, retain cheek fullness.
- Current eye apertures are narrow horizontal slits. Photo has readable upper lids, deeper orbital brow and fuller lower lids. Open upper lid without enlarging eyeballs; keep eyeball/lid fit.
- Photo nose has a broad rounded tip, visible alar wings and a less flat bridge-to-tip transition. Refine actual bridge/tip/alar geometry rather than paint shadows.
- Current mouth is too wide, flat and featureless. Narrow resting lip span, define upper lip/philtrum and mouth-corner planes. Photo smile lifts cheeks and corners; provide a separate editable smile shape rather than bake a teeth photograph into skin.
- Hair is cropped brown with a slight side sweep, softened irregular hairline and rounded crown. Correct cap silhouette/edge and card flow within existing budget.
- Preserve anatomical UVs, iris alignment and non-photographic skin pigment. Never project phone UI, suit, or a rectangular face photograph onto the head.

## Delivery and review

Use `/create-player`, Blender Director/reference-match, character artist, modeler, hair groom, UV/texturing, materials and Godot export guides via headless Blender. Update the current model in place through a separate Shane head variant on the unchanged shared skeleton; other players keep the reusable base. Keep fixed front, three-quarter, profile, clay and textured comparisons, then validate actual Godot asset and roster integration. Archive baseline renders. Inspect neutral and smile states separately. No exact/AAA likeness or M1 frame-rate claim from these captures.

## Owner feedback follow-up

The owner rejected the cap-dominated hair as painted. Replace sparse strips and scalp-normal overrides with a dimensional directional groom, inspect cap intersections and highlights, then validate the real exported head again. Further face fitting restores fuller buccal tissue, broadens nasal wings, rounds the chin and strengthens the inner brow. Neutral and restrained closed-smile states remain separate; an exact open-teeth expression is not claimed.
