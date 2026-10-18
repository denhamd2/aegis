# BR-022 / BR-023 first-pass art brief

**Scope:** One gameplay-scale Beechlawn outfielder/keeper kit prototype and the first reusable Kilmore Drive park-dressing blockout. This is an integration pass, not approval of final player likenesses or a finished environment.

## Source references and feature map

### Beechlawn player and goalkeeper

- Shane Denham #8 character sheet: `references/source_uploads/chat_attachments/character_roster_sheets/1-69014.jpg`.
- John O’Rourke #1 character sheet: `references/source_uploads/chat_attachments/character_roster_sheets/2-69011.jpg`.
- Beechlawn home kit object board: `references/source_uploads/drive_folder/file_000000000da0824386b7ef8edd3a9c79.png` and complementary `file_00000000fcac81f4b3870dc4ce96ac38.png`.
- Beechlawn goalkeeper kit object board: `references/source_uploads/drive_folder/file_00000000fcc481f4a367f1c29ae78bff.png`.
- Identity sheets govern face, hair and body silhouette. Kit boards govern jersey construction, black/blue home stripes, crest/sponsor placement, black shorts, blue outfield socks, goalkeeper light-grey/blue graphic jersey, white socks and pale gloves.
- The kit board says crest `EST. 2004`, while some character sheets show different years. The prototype uses a neutral `BR` crest marker and does not guess a year or fabricate the exact crest graphic.

### Park and match presentation

- Local park environment board: `references/source_uploads/chat_attachments/football_reference_upload_round_1/2-69021.jpg`.
- Kilmore Drive satellite and map context: `references/google_captures/satellite/` and `references/source_uploads/chat_attachments/openstreetmap/69078.jpg`.
- Street context: `references/google_captures/street_view/`.
- Broadcast target: `references/source_uploads/chat_attachments/football_reference_upload_round_1/1-69022.jpg`.
- Environment cues used: worn green public-park grass; a long weathered boundary wall; hedges and mature trees; Dublin residential facades behind the pitch; roadside footpath, road, lamps and a few parked cars; soft overcast daylight. The playable pitch remains 105 m × 68 m and the map is used for layout/context, never as a game texture.

## Current-to-reference gap

The starting scene used a uniform flat pitch shader, identical box-roof houses on both sides, sphere-canopy trees, no road/path/car cues, warm direct light and capsule-body players with flat team-color shirts. It had no readable sponsor, crest placement, keeper gloves or sock distinction. The authored environment and kit sheets provide stronger silhouette, value and layout cues; their small texture details cannot be judged from the current camera distance yet.

## Implemented prototype direction

- The park dressing is now a reusable Godot builder separated from the gameplay pitch/goals. It keeps gameplay collisions and field markings authoritative in `training_ground.gd`, while the backdrop supplies Blender-authored low-cost house, tree and parked-car modules plus wall/hedge, footpath, road and lamp dressing. `tools/blender/beechlawn/build_kilmore_park_modules.py` rebuilds the original GLBs and a Blender preview; `kilmore_park_modules.blend` preserves the editable source.
- The current 4v4 actors instantiate `FootballerVisual`, with the verified 65-bone Y-Bot rig, active idle/jog/sprint blend, and team/keeper palette colors. The kit object sheets continue to guide team colors and the planned garments/graphics. An earlier primitive-body pass tested sponsor/crest/number labels, socks and keeper gloves, but those details are not present on the segmented Y-Bot shell and must be rebuilt on a proper human mesh.
- The Y-Bot's segmented robot geometry remains a rig/import proxy and is not accepted as the final BR-022 character mesh. The rig is now integrated into the gameplay scene and the pass/receive clips are synchronized with the live ball. The first mesh production gate remains a Blender human base fitted to the same skeleton, followed by face/kit front, profile, three-quarter, back and broadcast reviews.
- The scene lighting is shifted toward neutral, softer daylight so the park palette and blue/black/light goalkeeper kits remain readable.

## Next visual review gaps

1. Compare the game camera against the broadcast composite and environment sheet; refine facade/tree proportions, wall/goal weathering, and irregular markings beyond the current blockout.
2. Replace the rejected capsule-based Shane prototype with a continuous, properly weighted human base on the Y-Bot skeleton, then transfer the kit boards' fabric/graphics into fitted garments and UVs. Do not treat the Y-Bot palette colors as kit implementation.
3. Compare accepted player front/profile/three-quarter/back and keeper glove/silhouette to their sheets. No likeness pass is complete yet.

## Performance and validation target

Use shared materials and repeated low-cost meshes; no runtime cloth/foliage simulation. Smoke checks confirm GLB loading, the 65-bone rig on all eight actors, palette assignment, and pass/receive contacts. The [Web Compatibility gameplay capture](rigged_4v4_web_compat_capture.png) confirms the proxy is visible during play, but the broadcast view is too distant for detailed gait judging and does not match Mac Forward+/Metal lighting. Target 1080p/60 fps must be measured on the Apple M1 Pro separately. Cloud validation is not evidence of target-Mac frame rate.

## Current BR-022/023 review artifacts

- [Latest Kilmore Drive Web Compatibility frame](kilmore_drive_web_first_pass.png): facade orientation is corrected, grass and road use credited CC0 surface maps, and overcast/turf readability is improved. This remains a stylized blockout, not a like-for-like environment render.
- Shane #8 fixed views: [front](shane_denham_08_front.png), [profile](shane_denham_08_profile.png), [three-quarter](shane_denham_08_threequarter.png), [back](shane_denham_08_back.png), and [portrait](shane_denham_08_portrait.png). These expose the rejected first draft's face, body continuity, and deformation gaps; it is deliberately kept under `assets/characters/_prototypes/` and is not in the roster.
- Focused records: [`br022_shane_denham_reference_analysis.md`](br022_shane_denham_reference_analysis.md) and [`br023_kilmore_reference_analysis.md`](br023_kilmore_reference_analysis.md).
