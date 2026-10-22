# Boardeaux Des Feeney #9 — face and head refinement

Latest source, groom, four-image PBR package and runtime evidence supersede
this historical pass: see [the four-head finish](../four_head_finish/brief.md).
The current authoring entry points delegate to `author_four_head_finish.py`;
materials/grooms use `player_head_finish.py` and `player_head_groom.py`.

BR-022, item 22 of 25, remains in progress. This pass refines the Boardeaux player identity used by all eleven away players and the retained small-sided fixtures. Des Feeney Sr., the referee, uses a separate head recipe. The common body, skeleton, kit and animation library remain shared.

## Reference and baseline

Primary identity evidence is the owner's unchanged portrait, `references/source_uploads/chat_attachments/boardeaux_des_photo/69016.jpg`. Secondary evidence is `references/source_uploads/drive_folder/file_0000000030a88243862e7c5dc9dbd7db.png`, Des #9's character sheet. The portrait takes precedence for face identity; the generated sheet supplies secondary side/rear and costume guidance. The low-resolution portrait has soft indoor illumination, so its colour cast and apparent shadow depth are not baked into the skin.

The reference shows an exposed round forehead, receded short side/back hair, full cheeks and jowls, modest dark eyes, a rounded nose, a narrow closed mouth and dark moustache/goatee. The earlier model's five main gaps were generic proportions, a wide straight mouth, overly exposed eyes, sparse facial hair and inconsistent skin/hair appearance between Blender and Godot. Baselines are `before/blender/des_player_front.png` and `before/web/des_portrait.png`.

## Changes

- Refined the player-only sculpt delta: rounder cheeks/lower face, narrower closed mouth, reduced nose projection and alar span, smaller ear projection, fitted eyelid/eyeball dimensions and a rounder exposed crown. Mouth deformation fades into the anterior muzzle rather than sharply pulling the surrounding cheeks inward. Neck seam positions and normals remain protected.
- Replaced the legacy vertex-colour mixing material with a directly exported 2K anatomical skin atlas, restrained 1K normal map and 512px dark-brown eye atlas. The licensed CC0 skin contributes bounded small-scale detail; broad colour, lip/brow placement and hair-root pigment are authored for Des. No portrait photo is projected or placed over the head.
- Added denser, shorter tapered fibres and softened root pigment for the receded sides/back, moustache, chin goatee and brows. The goatee uses a rounded, feathered boundary rather than a rectangular patch. Hair remains a separately reusable skinned package; it adds 28,961 triangles, with no alpha layers.
- Captured the current editable source back into its revisioned delta and rebuilt the actual roster package. Previously, the source sculpt had newer raised facial features while the runtime delta still retained older eye positions; the exported fibres and face could therefore disagree.
- Added `audit_des_player_export.py`, which compares every exported neutral head/eye vertex with the editable source in both directions. It also checks that all three embedded images belong to Des and that the old vertex-colour streams are absent. This catches a stale sculpt export even when a roster resource loads successfully.

## Sources and runtime assets

- Editable source: `tools/blender/beechlawn/des_feeney_head.blend`.
- Repeatable sculpt: `tools/blender/beechlawn/author_des_feeney_likeness.py`.
- Materials and groom: `des_player_finish.py` and `des_player_groom.py` in that directory.
- Recorded delta: `tools/blender/beechlawn/head_pipeline/deltas/bordeaux_09.json`.
- Runtime head: `assets/characters/shared/heads/players/bordeaux_09.glb`.
- Runtime hair: `assets/characters/shared/heads/des_side_hair.glb`.

Capture source changes using the common `build_roster_heads.py -- --capture-player bordeaux_09 --sculpt tools/blender/beechlawn/des_feeney_head.blend` workflow. Then run `audit_des_player_export.py`; do not assume saving the Blender file updated the roster GLB.

## Validation and evidence

`export_audit.json` records the source/export comparison and exact runtime GLB hash. `runtime_checks.log` records the bounded Godot suite: 22 players plus one referee, shared roster resources, independent playback, head/eye/hair overrides, pose safety and inverse-bind checks.

`after/des_player_front.png`, `des_player_threequarter.png` and `des_player_profile.png` are Blender renders of the editable source. `web/des_portrait.png`, `des_threequarter_portrait.png`, `des_profile_portrait.png` and `des_broadcast.png` are actual Godot Compatibility/Chromium captures on the Kilmore Drive review pitch. `web/review.json` records browser errors and lighting. These are playable-asset reviews, not generated promotional artwork. The review export is isolated and does not replace the main game scene.

## Godot shading and neck follow-up, 22 October 2026

The first actual Godot review exposed diagonal self-shadow bands which were absent in Blender. Fixed-camera ablations rule out the normal map and exported vertex normals: disabling only the normal map leaves the forehead band RMS at 1.82, while disabling shadows reduces it to 0.49. The maximum exported/source normal difference is 0.035 degrees. Increasing the shared match sun's normal bias from 0.8 to 1.8 keeps shadows enabled and reduces band RMS to 0.80, below the scoped 1.30 review threshold. A depth-bias-only change and a shorter shadow distance did not meet that gate. `check_head_banding.py` reproduces the failing old capture and passes the refreshed default portrait; it is a fixed Des/camera QA check, not a universal skin-quality score.

The new individual skin also initially introduced a visible collar colour seam. The bake now retains the common anatomical albedo below the protected neck and blends into Des's skin over 3 cm. The GLB audit samples 158 protected front-neck UV corners: the previous atlas had a median linear colour difference of 0.082 and a 99th percentile of 0.200; the corrected atlas has a median of 0 and a 99th percentile of 0.0039 against the shared source. UVs and geometry remain unchanged.

`diagnostics/summary.json` records the isolations, before/after measurements and contact-shadow comparison. The refreshed standard portraits use the actual default sun configuration with normal maps and shadows enabled. `web/des_front.png` adds a whole-body view. The full 11v11 match export supplies `diagnostics/contact_shadows/ball_shadow_on.png`, `ball_shadow_off.png` and `sunny_goalmouth.png`; the ball/goal-frame shadows remain visible, with no noticeable new ball-shadow detachment against the archived same-view baseline. The wet/weather smoke check also passes. These observations do not establish native Metal rendering parity.

## Acceptance boundary

The implementation and integration checks are separate from likeness approval. The head is still an interpretation of a blurred near-frontal portrait, with a fairly symmetric base, simplified eye/lip/ear anatomy and limited skin detail. The side profile is estimated using secondary sheet evidence. Exact or AAA-quality likeness is not certified by technical checks or these captures. Owner visual acceptance remains open under BR-022. Native M1 Pro appearance and 1080p/60 fps performance require separate hardware validation.
