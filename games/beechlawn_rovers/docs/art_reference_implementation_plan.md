# Beechlawn Rovers — Reference Art Implementation Plan

Current shared receiving follow-up: [contextual control](art_briefs/contextual_control_2026_10_25/brief.md), BR-002 (2/27) and BR-021 (21/27), in progress. Four original standing/moving left/right clips use the existing shared rig and archived player/kit/broadcast references. Movement/Ctrl/Shift choose contextual outlets; the supporting gait continues during moving contacts. Preserve current heads, bodies, kits, base gaits and keeper/skill content. Use create-player’s receiving-order, pose-clock and layer-cost checks. Native before/after footage is motion evidence; M1 feel/performance remains BR-025 (25/27).

Current sports-prop follow-up: [UCL 26/27 League ball](art_briefs/ucl_ball_2026_10_25/brief.md), BR-023 (23/27, in progress). The owner approved the latest **League size-5** photographs (70119/70118/70117/70116), with black branding, as the new default. Earlier mini photos are supplementary only; do not substitute their pink logos/MINI label or the Pro variant. Retrieve `references/source_uploads/chat_attachments/ucl_26_27_ball/`; use Blender director → prop artist → UV/texturing → PBR → optimization/export, then matched studio and native Forward+ ball rotations. The original worn ball remains a saved option; gameplay physics are shared. Delivery/target-Mac acceptance stays BR-025 (25/27).

Current gameplay motion follow-up: [stride/foot plants](art_briefs/br021_stride_2026_10_24/brief.md),
BR-021 (21/27, in progress), adds five original shared gaits with measured
stance travel, natural arm/wrist motion and stepping through deceleration.
All body/head/kit sources remain intact. Native pitch-side motion and live-ball
checks pass; broader motion and M1 acceptance remain open. Next delivery action
is BR-025 (25/27), a fresh Mac package for combined playtesting.

Current keeper motion follow-up: [high-shot saves](art_briefs/br009_high_shots_2026_10_24/brief.md),
BR-009 (9/27, in progress), adds three original shared-rig overhead/high-dive
clips with measured glove contact, physical take-off and arrival timing.
Both keeper appearance references and the existing body/head/kit assets are
preserved. Distribution motion and native Mac match acceptance remain open.
The [full-stretch follow-up](art_briefs/br009_dives_2026_10_24/brief.md) adds
bilateral low/mid/high dives, physical lateral flight and staged landing/get-up.
Native footage and travelling-ball checks cover both existing keeper visuals.

Current Shane/John follow-up: [portrait refinement](art_briefs/shane_john_refinement/brief.md),
BR-022 (22/27), using the original photos, corrected roll measurements and
matched native portraits. Preserve the separate Des sources and John’s warm
beard. John's reattached portrait also guides continuous cheek/jaw/sideburn
coverage, checked from both native profiles with unchanged beard colours.
This does not close the AAA likeness or target-Mac acceptance gates.

Current finishing work: [23 October realism pass](art_briefs/realism_finish/brief.md),
BR-022 (22/27), with shared-body fullness, individual heads and cinematic/turf
presentation. Player Des now has additional original side/back photographs
69911/69910/69909 in the [reference archive](../references/README.md).
Use their temporal wedge, sideburns and rear horseshoe ahead of the generated
sheet's groom; retain the bare crown. Referee Des remains a separate identity.
Technical export checks do not close the AAA likeness or M1 hardware gates.

**Reviewed:** 2026-10-18
**Source folder:** [Beechlawn Game reference folder](https://drive.google.com/drive/folders/1GUh4bQDTKJY7-44wLtbsKZAWq6SyIotm); [Kilmore Drive Street View](https://maps.app.goo.gl/p7TfFiB6Qmqviwsh6); [Kilmore Drive satellite view](https://maps.app.goo.gl/SPqee19XAk4EQ6qs7)  
**Archived copies:** [`references/README.md`](../references/README.md)  
**Scope:** Reference map and production direction. The first scoped kit/backdrop prototype is tracked separately in [`art_briefs/br022_br023_first_pass.md`](art_briefs/br022_br023_first_pass.md); it does not approve final character or environment art.

## Backlog placement

The work belongs primarily to **BR-022 — Character and kit production (item 22 of 25)** and **BR-023 — Kilmore Drive park environment (item 23 of 25)**. It depends on the current playable systems and should be brought forward only as a small, representative visual slice is needed to validate the game.

Related work is staged across the existing backlog:

| Backlog item | Relationship to these references | Current state in `docs/backlog.md` |
|---|---|---|
| **BR-003 — Reusable footballer rig and first animation set (3/25)** | Replace the Y-Bot shell after the shared rig, import convention, and proxy locomotion are sound. The final mesh is the target for the first authored football clips. | Y-Bot rig and locomotion/pass/receive clips now run on all eight 4v4 actors; final human mesh and authored action polish remain. |
| **BR-005 — Player/team data and tuning (5/25)** | The currently populated four-player rosters cover the short match. The new sheets provide a full Beechlawn identity set for a later roster expansion. | Marked complete for the current four-slot data; do not treat that as full-roster art. |
| **BR-009 — First goalkeeper (9/25)** | John O’Rourke’s #1 keeper identity, gloves, kit, and keeper-specific animation references. | In progress; movement/save logic smoke checked, authored keeper motion and match tuning remain. |
| **BR-013 — Efficient 22-player simulation (13/25)** | Later visual scale-up. Only one Boardeaux face/identity is supplied, so this folder cannot provide a distinct 11-player Boardeaux team. | Not started. |
| **BR-016 — Fouls, offside and referee (16/25)** | Des Feeney Sr. character/kit and referee actions. | Not started. |
| **BR-019 — Shooting and aerial actions (19/25)** | Later headers, volleys, jumps, crosses, and keeper aerial interactions. | Not started. |
| **BR-021 — Animation contact and blending pass (21/25)** | Final foot planting, transitions, contact markers, and camera-distance review against the finished players. | Not started. |
| **BR-022 — Character and kit production (22/25)** | Main destination for all player/referee likeness and kit work. | Shane #8's [body/face/kit pass](art_briefs/br022_shane_body_face_tailored_pass.md) builds on the rig/weight/timing foundation with anatomical facial targets, UV skin, opaque short hair, fitted garments and a complete 2K panel atlas. Facial likeness/hair, complete animation coverage and gameplay/Mac acceptance remain open under the [Shane plan](art_briefs/br022_shane_likeness_and_kit_plan.md). The [cleanup pass](art_briefs/br022_shane_likeness_cleanup.md) adds the measured normal/retarget corrections, clean skin bake, short hair cards and fitted shorts. The prototype remains out of the roster. |
| **BR-023 — Kilmore Drive park environment (23/25)** | Main destination for pitch, goal/net, local boundary, vegetation, houses, and lighting. | Reusable backdrop now includes inward-facing house facades, variant trees/cars, roadway and a more varied grass shader; Web Compatibility review still reads as a stylized blockout. |
| **BR-025 — M1 performance and Mac delivery (25/25)** | Final target-device 1080p/60 fps validation after the authored assets enter the 4v4 and 11v11 scenes. | Not started; M1 Pro/16 GB hardware profiling is still required. |

The practical order is: **continue the BR-001/002 playable checks and BR-003 animation work; advance only the reference-backed venue blockout under BR-023 and one roster/keeper kit prototype under BR-022 in parallel; establish the shared human mesh/rig convention before producing final identities; integrate and tune those assets with BR-009/016/021; then expand the art load for BR-013 and profile under BR-025.** The small early passes provide visual test context without treating the full park or roster as approved before camera, contact, and performance constraints are known.

## Reference-to-backlog map and required source-of-truth workflow

The durable source of truth is the [reference archive index](../references/README.md), with source files in `../references/source_uploads/` and saved map captures in `../references/google_captures/`. The index resolves every Drive filename and every direct-upload occurrence to its subject; use it to retrieve originals instead of relying on the chat transcript or memory. Keep originals unedited. Create derived crops, paintovers, UVs, or texture experiments in the relevant asset working folder and label them as derivatives.

| Backlog item | References to retrieve before work | Use of the references / acceptance focus |
|---|---|---|
| **BR-003 / BR-021 — rig and animation** | Y-Bot source ZIP; character full-body turnarounds and build guides; `69022` gameplay image; ball sheet; keeper/referee sheets when their actions are addressed. See archive index for full paths. | Keep the Y-Bot proxy for motion tests, then verify proportions and deformation against the chosen final character sheets. Static sheets guide silhouette and pose, not animation timing. Check contacts and transitions in Godot with the live ball and final meshes. |
| **BR-005 / BR-022 — identity, roster, kit** | All twelve Beechlawn player sheets, John O’Rourke #1, Des Feeney #9, both Beechlawn kit views, Beechlawn goalkeeper kit, Boardeaux home/keeper kit, and owner-uploaded direct roster batch (`69014`, `69011`, `69006`, `69004`, `69017`). | Match named identity, facial proportions, hair, build, number and garment silhouette per individual sheet. Use kit-object boards as shared garment/graphic construction references. The direct upload batch helps identify the first 4v4 sample; the Drive folder remains the complete character source. Preserve the limitation that Boardeaux has one supplied identity. |
| **BR-009 — goalkeeper** | John O’Rourke #1 character sheet and Beechlawn keeper kit; Boardeaux “Feeney 1” kit and Des Feeney face if validating the opposing keeper visual. | Validate keeper-specific gloves, shirt, silhouette, stance, reach and authored save poses; keep animation and ball physics independent. |
| **BR-014 — broadcast camera/HUD** | `69022` direct-upload broadcast gameplay image and the Drive broadcast gameplay/presentation composites, identified in the archive index. | Match elevated sideline framing, scale, player visibility, scoreboard/radar hierarchy, and readability; do not copy third-party marks/logos from concept composites. |
| **BR-016 — referee** | Des Feeney Sr. referee character sheet and separate referee-kit board. | Preserve his distinct identity from Boardeaux’s Des Feeney #9; validate whistle/cards and restart/goal/card signals in the actual broadcast shot. |
| **BR-019 — aerial actions and ball** | Worn-ball object sheet; goal/net sheet; gameplay composite; relevant player and keeper turnarounds. | Match the ball’s worn graphics, scale, seams, and visible spin; review header/volley contact against the moving ball and goal. |
| **BR-023 — local park environment** | Both pitch/location boards; `69021` direct environment board; `69020` goal/net sheet; Drive ball/goal sheets; uploaded estate screenshot; all Street View headings/contact sheet; Google satellite overview/zoom captures; OpenStreetMap `69078.jpg`; Google Earth `69084.jpg`. | Place the target pitch in the western field southwest of the Kilmore Drive / Beechlawn Close bend, with the more formal club grounds to its east. Use 105 m × 68 m from the gameplay specification as the playable field dimensions; use the map sources for placement, orientation, boundaries, and surroundings. Google Earth adds a visible 100 m scale bar and satellite context, but appears to show the neighboring St. John Vianney grounds, not the target western pitch. The OSM screenshot has no scale; neither screenshot alone establishes a surveyed target-pitch size. These are layout references, not in-game textures. |
| **BR-025 — performance** | Final approved character/kit/goal/environment assets plus broadcast image for intended viewing distance. | Profile representative and full match scenes after fidelity is established. Simplify using measured screen size, shared materials, LODs and instancing while protecting reference-critical silhouettes and colors. |

Before each reference-driven art backlog item, write a short asset-specific reference analysis: source paths, visual features that must match, current-vs-reference gaps, target camera distance, and the validation shot/test. For character likeness, compare the face/profile views; for environment and match framing, match the camera and large-scale composition before adding surface detail. Use the two uploaded gameplay/marketing composites for visual hierarchy only; never reproduce their game branding or copy proprietary assets. Keep this analysis beside the related asset or update this plan when it establishes a reusable decision.

## Reference audit

The folder contains 27 files: 26 PNG reference sheets and one Google Maps satellite screenshot.

File-level audit: 12 Beechlawn player sheets; two overlapping Beechlawn home-kit sheets and one Beechlawn goalkeeper-kit sheet; one Boardeaux player sheet, one Boardeaux home-kit sheet, and one Boardeaux goalkeeper-kit sheet; one referee character sheet and one referee-kit sheet; one ball sheet and one goal/net sheet; two pitch/location boards; two gameplay/presentation composites; and the satellite screenshot. The two Beechlawn home-kit boards agree on the main kit design but provide different coverage, so treat them as complementary views rather than separate uniforms.

### Characters and kits

**Owner complexion direction (2026-10-22):** the football roster should have
fair, untanned skin. Preserve reference-specific redness, freckles and age;
match faces, necks, exposed arms, hands and legs together under fixed daylight.
Use the editable [skin palette and review](art_briefs/fair_skin_review/brief.md)
when regenerating assets. Nationality is not a pigment measurement.

The Beechlawn player sheets identify **11 outfield players** and **one goalkeeper**. All show front/profile/back views and face expressions; most include a height guide and example skin, normal, roughness, and hair maps. Those map panels communicate the intended surface treatment, but they are examples, not UV-ready texture maps for a game mesh.

Only John O’Rourke is explicitly marked as a goalkeeper; the sheets do not establish the other players’ positions or gameplay ratings. Keep those values editable/defaulted instead of inferring them from numbers or appearance.

| Character | Number / role | Distinguishing cues to preserve |
|---|---:|---|
| Colly Roden | #2, outfield | Short spiked brown hair; broader, compact build. |
| Derek Mitchell | #3, outfield | Close/receding hair, fair skin, mature face. |
| Kev Mullen | #4, outfield | Very short light-brown hair; leaner face/build. |
| David Murray | #5, outfield | Short light/reddish-brown hair; broad, friendly face. |
| Deco McCabe | #6, outfield | Short light-brown hair; rounder face/build. |
| David Denham | #7, outfield | Dark curly hair; fuller face. |
| Shane Denham | #8, outfield | Short brown hair; clean-shaven; distinct smile and face shape. |
| Damo Murphy | #9, outfield | Dark hair and full beard. |
| Robbie Roden | #10, outfield | Short dark-brown hair; younger-looking, clean-shaven face. |
| Michael McCabe | #11, outfield | Short light-brown hair with beard/stubble; broader face. |
| Paddy Mason | #69, outfield | Bald head; older face and smile. |
| John O’Rourke | #1, goalkeeper | Auburn/light-brown hair, full reddish-brown beard; gloves and dedicated keeper shirt. |

The **Beechlawn home kit** is black with royal/bright-blue vertical panels and blue sleeves/trim, black shorts, blue socks, white player name/number, chest sponsor “THOMAS LOOMES & CO,” and club crest. Per-player turnarounds generally depict long sleeves; the kit object sheets also show short-sleeve garment variants. The keeper sheet specifies a light-grey/white and blue geometric long-sleeve shirt, black shorts, white socks, yellow-accented gloves, and O’Rourke name/number details.

The Boardeaux folder contains **one outfield identity: Des Feeney #9**, with a balding/receding head, short sides, and goatee/beard. His home kit is sky blue with dark trim, black shorts with white side panels, white/blue socks, and “Boards.ie” sponsor. A separate Boardeaux goalkeeper kit sheet shows the same Feeney face, a charcoal patterned shirt, black shorts/socks, gloves, and “FEENEY 1” on the back. That supports the requested 4v4 visual base (three outfield slots plus keeper), but not a distinct 11-player Boardeaux roster. Keep the other Boardeaux slot IDs/names/ratings generic as current data policy requires; do not fabricate player identities.

The **referee is Des Feeney Sr.**, a separate older character with a bald/receding head, grey moustache, all-black referee kit, whistle, watch, and red/yellow cards. The supplied referee sheet gives no squad number. Keep him distinct from Boardeaux player Des Feeney #9 in names, mesh, materials, and roster data.

### Objects, field, and match look

- **Ball:** worn off-white panelled size-5 match ball, approximately 21–22 cm diameter, with red/black graphics, seam/stitch detail, dirt, abrasion, and surface maps. The project already uses an owner-supplied worn model around 4.4k triangles; retain it and first compare its UVs/graphics/material to the sheet rather than rebuilding a duplicate.
- **Goal:** weathered white/cream tubular frame and sagging net, approximately 7.32 m wide by 2.44 m high. The sheet calls for a no-stanchion/local-park style, chipped paint/rust/mud, knotted net, and a low-cost playable collision setup separate from render geometry.
- **Pitch sheets:** a Boardeaux/local-park environment board and a Beechlawn location board show a residential Dublin park setting: worn natural grass, patchy high-use areas, faded/irregular painted markings, houses and parked cars along one side, a boundary wall/hedge, footpaths/street edge, mature trees, and distant floodlights. The actual satellite screenshot gives field orientation and surrounding footprint only; it should not be used as an in-game photo texture.
- **Street View supplement:** I resolved and viewed the shared panorama from eight headings around the same roadside location. Looking across the field, the road-side foreground has asphalt, a curb, a narrow paved footpath, and grass; the playing field is broad and open, with goal frames, a far boundary of low wall/hedge and trees, and low residential roofs beyond. Rotating toward the street shows semi-detached houses, front gardens, hedge-topped walls, parked cars, utility poles, and several overhead wires. A leafless roadside tree and small planted/shrub areas break up the near edge. The panorama is an overcast, soft-light reference. These observations add the missing road-facing boundary and overhead-wire silhouettes to BR-023; use the panorama for layout and visual study only, never as an in-game texture.
- **OpenStreetMap placement supplement:** the owner-uploaded `69078.jpg` adds a clear street-map view centered on the Kilmore Drive / Beechlawn Close bend. It places the target western green field just southwest of that bend, with a neighboring green field immediately east; Hazelwood Park is to the west/southwest and Charnel Road lies farther south. Use this as the top-down neighborhood/field-placement anchor when laying out the environment blockout. The visible map is cropped and has no scale bar or pitch dimension labels, so it does not provide an independently measurable pitch length or width. Keep the gameplay spec's 105 m × 68 m playable dimensions for now; use OSM feature geometry or a measured/surveyed source later if the authored field footprint needs an exact geospatial match. Keep the original screenshot as a reference image, not a ground texture.
- **Google Earth scale/context supplement:** the owner-uploaded `69084.jpg` is archived alongside the OSM view. Its coordinate grid and 100 m scale bar make it a stronger source for approximate real-world spacing than the cropped street map; the satellite imagery also reveals the layout and surrounding tree/boundary bands around the named St. John Vianney Football Club. The screenshot appears to cover the formal neighboring grounds east of the target western park field, so use it as adjacent-site context and a scale cross-check, while the OSM screenshot anchors the target field within Kilmore Drive Park. A tilted/rotated phone capture with labels obscuring markings is still not a survey: retain 105 m × 68 m from the gameplay specification until exact target-field geometry is measured from source map data or a survey. Do not use either map screenshot as an in-game texture.
- **Satellite supplement:** the shared link opens the aerial layer over Kilmore Drive and can be zoomed onto the western park field. The wide view confirms the park’s irregular outline and orientation against Kilmore Drive/Beechlawn streets, housing/back gardens, and the separate, more formal playing ground to the east. At closer zoom, the target field shows faint/overlapping line layouts, broad worn/muddy traffic strips, a few bare patches, two small goal frames, trees along parts of the residential edge, and a long straight hard boundary beside the neighboring ground. Together with the OSM screenshot, this is strong evidence for the rough field footprint, axis, neighboring context, and grass variation. The imagery is not a survey: linework is faint, some markings overlap, and the closest tiles soften, so do not claim precise full-pitch dimensions from aerial pixels. Set playable dimensions from the football specification and verify placement against the goal (7.32 m) and field markings. Treat the satellite photo as a layout/reference source, not a game texture.
- **Gameplay/presentation boards:** two composite images show an elevated sideline broadcast view, score/time HUD, radar, players in midfield, close duel/face shots, a celebration, and a goalkeeper save. Use these to prioritize composition and readability. Do not reproduce third-party game marks/logos visible in a concept image.

## Production approach

### 1. Lock a reference bible and screen-distance targets

Create a compact reference board per asset family: (a) player head/face/profile and full-body silhouette, (b) kit graphics, (c) keeper, (d) referee, (e) ball/goal, (f) pitch layout and boundary, and (g) broadcast framing. Establish a 1 Blender unit = 1 metre scene with a 1.8 m mannequin and the stated real-world ball/goal dimensions. Compare silhouettes from the intended broadcast camera before small detail; use the head/profile views for face likeness and the turnaround for clothing/number placement.

Use a consistent reference hierarchy: individual character sheets control face, hair, build, and sleeve silhouette; kit object sheets control reusable colors/logos/material construction; the environment sheet and location board control setting/layout; the gameplay composites control camera framing and scene readability. Do not turn the example skin-map panels into direct texture projections.

### 2. Build one reusable human body/rig and establish a representative slice

Keep the verified Mixamo Y-Bot 65-bone skeleton/import convention as the initial retarget target, but replace its robot shell with one game-ready, human-proportioned, deformable base mesh. In Blender, block proportions first, then build clean deformation topology, individual head shapes, and hairstyle silhouettes. Use one shared body/rig and shared body/kit materials where possible; use distinct heads and hair to preserve each supplied identity. Fit the goalkeeper and referee through kit/accessory variants rather than creating unrelated skeletons.

The first art review set should cover the currently playable Beechlawn trio (Shane #8, Robbie #10, David Murray #5), John O’Rourke #1 in goal, Boardeaux Des Feeney #9 as the shared outfield visual base plus his “Feeney 1” keeper kit, and Des Feeney Sr. as referee. Use neutral A/T-pose and one running/turning pose for deformation review. Once the pipeline is approved, author the remaining Beechlawn identities against the same base for the later roster. Avoid trying to model all twelve Beechlawn players before the first representative mesh, rig, kit, and Godot import pass is accepted.

Face work should prioritize recognisable silhouette and proportions: head shape, brow/eye spacing, nose, jaw, hairline, hairstyle, and facial hair. Use the multiple expression panels as reference for simple facial pose targets (neutral, focused, talking, smile), not as a promise of full cinematic facial capture. For game playback, a small set of efficient facial controls/shape keys is enough initially. Hair should use restrained game-ready cards or shaped clumps, not a heavy real-time strand groom.

### 3. Make kit graphics and skin/fabric materials consistently

Create fitted, separately manageable jersey/short/sock/glove pieces over the shared body, with weights transferred then manually cleaned at shoulders, hips, elbows, knees, and cuffs. Preserve the selected sleeve variant per player sheet. Put team stripes, sponsor, crest, names, and numbers in clean UV/decal assets rather than floating geometry; use the same UV layout and material for all Beechlawn outfielders, swapping player name/number data. Keep Boardeaux outfield and keeper uniform masters separate. Match the reference’s skin tone and facial texture with calibrated base-color/roughness/normal maps; use subdued rough skin, natural facial variation, and realistic eye response. Use woven fabric micro-normal/roughness and modest cloth sheen; boots, sock elastic, glove latex, and printed marks need distinct but restrained material response. Use Principled BSDF/glTF-compatible materials only.

Texture size and detail should follow the final camera test: start with a 2K head/face set for the near players and shared 1K–2K team kit textures, then validate memory/draw calls in Godot before duplicating for 22 characters. Shane's rejected portrait projection has been removed. The current head uses a 2K anatomical pigment map, the body a 512 map and restrained baked micro-normals. The tailored 2K kit atlas includes the supplied marks, S. DENHAM / 8, sleeve, shorts and sock charts. Reference-level skin/hair detail and cloth deformation still require visual acceptance under the [current Shane plan](art_briefs/br022_shane_likeness_and_kit_plan.md). Use mipmaps, shared materials, atlas repeated details, and LODs; no runtime cloth simulation for the first release.

### 4. Author motion against a lightweight mannequin before final-mesh validation

The supplied sheets are static; they do not contain animation clips. Use the shared rig to author/review movement in a blank Blender scene before transferring it to the final character:

1. **BR-003 first set:** ready/idle, acceleration and jog/run, deceleration/stop, 45°/90°/180° turns, close-control dribble, receive/first touch, ground pass, shot, standing tackle, slide/impact response, and recovery/get-up. Favor in-place clips, clean arcs, planted support foot, controlled torso counter-rotation, and readable follow-through. Keep the ball impulse driven by Godot and a named animation contact marker.
2. **BR-009 keeper set:** ready set, short lateral shuffle, drop/catch, low/high dive, parry, secure hold, get-up, and distribution; keep authored root motion/collision independent from the authoritative Godot ball.
3. **BR-016 referee set:** walk/jog, whistle, point direction/restart, signal goal, and card presentation. Keep the whistle/cards as simple accessories and ensure pose reads from broadcast distance.
4. **BR-019/021 later polish:** headers, volleys, aerial landings, crosses, and more contextual action interruption after the first 4v4 pass/contact loop is stable.

Use Blender curves, timing, contact, weight, anticipation, and follow-through for authored clips. Use no per-frame physics or expensive IK chain at runtime. Keep locomotion in-place so Godot controls player movement and avoids root-motion/physics conflicts.

### 5. Create the local-park environment and goal as reusable, light assets

Build the field as a controllable playable surface with a layered material: broad grass-color/roughness variation, subtle grass direction, worn patches in traffic areas, and imperfect/faded field paint. Keep field lines gameplay-accurate even if their texture edge is irregular. Construct a modest reusable residential backdrop: a few modular house facade/roof kits, parked-car silhouettes, wall/hedge segments, footpath/curb, utility poles/wires as camera-facing silhouettes, and a small set of instanced trees. Preserve the map’s long boundary wall and relationship to the neighboring ground. Put detail where the camera sees it; use simple distant facades/instances rather than unique high-poly houses or dense moving crowds. Use the map and Street View for boundary placement and axis only.

Model the goal at the stated dimensions with render tubes/net separated from simple post/crossbar collision proxies. Create net sag in its base mesh, with only a small event-driven deformation for a scored shot if the current net implementation needs it. Preserve line-of-sight through the mesh. Reuse the existing worn ball and build its material to match the off-white/red/black wear reference; verify rotation, collision size, and shot visibility in the match camera.

For lighting, build a neutral soft daylight setup first (sky/world plus a single broad sun direction) so faces, blue/black kits, grass, and white markings stay readable. The references show both overcast conditions and warmer sun; use the pitch sheets as the baseline environment mood and the composite’s warmer image as a secondary lookdev comparison, not as a second environment that must be built now. Keep a separate evening/floodlight variant out of the initial 4v4 scope.

### 6. Export, integration, and acceptance

Keep editable `.blend` sources and repeatable scripts under `tools/blender/beechlawn/` at the repository root; export game assets to the football project’s `assets/` tree as GLB. Preserve the existing shared rig’s rest matrices and object transforms, including its local-centimetre coordinate convention; apply transform cleanup only where compatible with the established bind/export contract. Use compatible Principled materials, a shared skeleton, named animation clips, packed/relative textures and separate collision geometry. Import each representative character alone first; verify skeleton/rest pose, correct height, material slots, skinning at extreme arms-up/crouch/turn poses, clip names, event-marker timing, and no unexpected root translation. Then check a Godot match scene with the final meshes, ball contacts, camera and lighting.

The mannequin pass is not the final gate. Review at two scales: face/kit close shot for likeness and logo/number placement; normal broadcast view for team distinction, legibility, pitch/goal framing, and animation contact. Run repeatable 4v4 and then 22-character render/profile probes. The M1 Pro 16 GB goal remains an unmeasured target: keep 60 fps provisional until a target-device 1080p playtest records frame-time, memory, shader stutter, draw calls, and input response. In cloud, check Godot import/startup, deterministic simulation smoke tests, asset counts/material sharing, and a representative capture; do not call these M1 validation.

## Reference decisions and confirmed owner corrections

1. **Crest:** the later original upload `references/source_uploads/chat_attachments/club_crest/69032.jpg` is authoritative: tall navy/white oval, EST 2004, green tree and green/white lower stripes. Retain its proportions; differing years or round badges in generated sheets are superseded. No further year confirmation is needed.
2. **Manufacturer and sponsor:** use **Uhlsport** and **Thomas Loomes & Co**. These owner corrections supersede Umbro/“Loones” renderings in earlier/generated references. Apply the complete panel layout, with player-specific name and number sourced from the roster and character sheet.
3. **Sleeves:** follow each player/role reference and live appearance resource. The shared source now supports long and short variants; validate skin coverage, fit and animation in both. Earlier prototype-only short-sleeve restrictions are superseded.
4. **Boardeaux identities:** Des Feeney is the supplied outfield likeness, with a keeper reference as recorded in the archive. The approved shared roster permits a common starting head and independent per-player edit slots. Preserve current roster IDs/names, distinguish placeholder likenesses from individually authored heads, and avoid inventing factual player details.

## Blender skills and tools to apply

These skills are repository-local production guides in `.claude/skills/`, rather than callable Codex MCP tools. For every relevant Blender task, read the guides actually needed from the routing table in root `AGENTS.md`; do not load all 38 guides by default. The reference-led workflow starts with `blender-director` and `references/reference-image-match.md`, writes the analysis using `references/reference-analysis-template.md`, then applies the specialist and validation guides below:

| Backlog work | Read/apply these guides before editing |
|---|---|
| Every reference-driven asset or look match | `blender-director`; `references/reference-image-match.md`; `references/reference-analysis-template.md`; `references/visual-match-checklist.md`; `references/validation-checklist.md`. Adapt their MCP/UI steps to available headless tools. |
| Footballer face/body/kit/hair | Start with the project-local `.agents/skills/create-player/SKILL.md`; then use `character-artist`, `rigging`, and `blender-materials`; add `retopology`, `hair-groom`, `uv-workflow`, or `blender-uv-texturing` only when that operation is in scope; use `realistic-style` for realistic human/PBR guidance. |
| Locomotion, football actions, keeper or referee animation | `blender-animation`; `rigging`; use the shorter `animation` guide as a checklist; validate event timing/root motion through the project’s Godot animation workflow. |
| Park, houses, vegetation and spatial layout | `environment-artist`; add `scene-assembly`, `procedural-modeling`, `geometry-nodes`, or `lod-pipeline` when needed; use `blender-lighting`, `blender-cameras`, and `blender-rendering` for a reference-matched lookdev capture. |
| Ball, goal, kit hardware and other props | `prop-artist`; add `hard-surface`, `blender-materials`, and `collision-proxy` only as appropriate. |
| Godot-ready asset handoff and QA | `asset-optimization`; `godot-export`; `blender-export`; `qa-review`; the project-scoped `.agents/skills/gda/SKILL.md` before using `gda`. |

The project guide says Blender 4.3.2 and `bpy` are available headlessly, with no Blender MCP connected. Therefore inspect/edit `.blend` files through small repeatable scripts, save editable sources under `tools/blender/beechlawn/`, export only into this Godot project, and test imports/visual results in Godot. Never claim MCP/UI access that is not available. Preserve the intended reference even when optimizing for the M1 Pro; if a detail is too costly at broadcast distance, record the tradeoff and use a cheaper screen-space equivalent rather than silently changing identity or setting.

## Approved 11v11 integration update

The owner approved the shared-body/full-team/environment pass on 2026-10-18.
`11v11_implementation.md` records the revised order: BR-022 common asset/role
kits, BR-011/013 complete lineups, BR-014 camera/radar, BR-023 terrain/park,
then BR-021/025 engine and performance acceptance. This supersedes earlier
prototype-only/4v4-only ordering. Assets are now integrated drafts; reference
likeness, precise site reconstruction and native performance are still open.
See `art_briefs/11v11_release_evidence.md` for actual screenshots and checks.

## Broadcast integration validation — 19 October 2026

BR-014/021/024 now use the existing archived player/kit, pitch, goal/net, ball
and Kilmore Drive references in an original pre-match sequence. See the
[broadcast production brief and actual render gallery](art_briefs/broadcast_presentation_plan.md).
The shared player-spawning defect is corrected (one rig per actor), and the
Blender source includes original walk-on/warm-up loops and relaxed braking arms.
Both tree modules now export their leaf coordinates in material UV0; the
source builder preserves this when joining bark and leaf meshes. Goal-net mip
coverage and distant chalk filtering are corrected. These are integration
and rendering fixes, not acceptance of likeness, clothing seams, terrain
accuracy or final venue fidelity. Those reference-to-asset gates remain open.

## Roadside grass setback — 19 October 2026

The target western field sits inside the park: do not place the road or path
beside its touchline. The original Drive satellite upload and the three Google
Maps zoom captures show a broad open grassy band on the road-facing side.
BR-023 now authors 35 m of grass before the footpath and 37.75 m to the nearest
asphalt edge, with the housing/street props set back together. Those are
approximate layout choices, not surveyed dimensions. Keep spectators beside
the playing area and the central apron open. Trees sit at the distant park
edge or in sparse western clusters. See the [comparison, Blender layout study
and actual engine captures](art_briefs/kilmore_road_setback.md). The park's
irregular outline, westward extent, street bends and final asset fidelity
remain open; do not describe this spacing correction as an exact site rebuild.

The subsequent [site-footprint pass](art_briefs/kilmore_site_footprint.md)
traces the western taper/inset and continues the road through reusable Blender
GLBs plus a Godot layout resource. Source pixels and calibration are archived
in `references/research/kilmore_site/site_trace.json`. This advances the outline
and western extent, not surveyed accuracy or individual property matching.

## Original-photo identity update — 19 October 2026

BR-022 (22/25) now uses the owner-uploaded Shane photo `shane_face_photo/69012.jpg` for facial identity, with sheet profiles treated as secondary estimates. See `art_briefs/shane_photo_likeness/brief.md` for the neutral sculpt/expression distinction, independent head integration and review evidence. Future player work starts with the revised `/create-player` workflow and its task-specific production checks. The landing art uses photorealistic David/owner portraits; it does not demonstrate gameplay mesh fidelity.

The approved shared-head follow-up promotes that neutral into the common
`footballer_head_master.blend`, with independent roster sculpt offsets and
separate hair selections. Follow [shared head production](art_briefs/shared_head_pipeline.md)
for edits and regeneration. Other player identities remain starting heads;
this does not establish their facial likeness or unseen profiles.

## Sky and direct daylight — 19 October 2026

The owner requested a sunnier partly-cloudy match after the initial overcast
direction. BR-023 (23/25) now uses the broadcast reference's brighter mood while
retaining natural cloud/horizon cues from the local park references. A CC0 pure
sky photograph provides the background and ambient radiance; a matching real
directional light casts shadows. See [sky/light review](art_briefs/kilmore_sky.md)
for provenance, shared editable settings and renderer evidence. Volumetric fog
is disabled; exact venue geometry and native M1 timing remain open.


### 20 October 2026 — shared neckline and wet weather follow-up

BR-022 (22/25) repairs the live shared collar/neck junction using the archived
home kit sheets, preserving identity and animation resources. See
[shared kit repair](art_briefs/shared_kit_repair/brief.md). Further shoulder,
underarm and per-player likeness review remains open.

BR-023 (23/25) adds owner-requested mud/puddles at both goals and match-weather
presets. The same mask drives visible water and BR-004 ball resistance.
[Wet weather and atmosphere research](art_briefs/kilmore_wet_weather.md) records
why light depth haze is appropriate for the clear broadcast, while geometry,
vegetation, PBR materials and cast shadows remain the main realism work.


### BR-022 shared shoulder/underarm fit follow-up

The current 23-actor roster uses the shared production body; old prototype-only
notes above are historical. The [shoulder/underarm fit](art_briefs/shared_shoulder_fit/brief.md)
reduces the inflated yoke, repairs the chest tear and improves nine sampled
poses while preserving heads, the neck interface, rig, clips and kit artwork.
Rear armhole deformation, final tailoring and individual likeness remain open.


### 21 October 2026 — exposed skin and garment construction

BR-022 (22/25) now repairs missing forearm skin inherited from the long-sleeve
body mask, a folded/torn-looking lower shirt strip and rear-underarm collapse.
The [construction brief](art_briefs/shared_cloth_finish/brief.md) maps the home
and Boardeaux kit references to local geometry repairs and fixed-pose evidence.
The archived CC0 anatomical source supplies only missing skin, preserving the
current neck, heads, shared rig, 19 actions and kit images. Further garment
fidelity and individual likeness remain open; this does not accept the art as
an exact reference match or establish native M1 performance.

### BR-022 upper-back cloth envelope and long-sleeve taper — 21 October

The [shared sleeve-fit pass](art_briefs/shared_sleeve_fit/brief.md) continues the
current production source, using the home/Shane/Boardeaux sheets. It fills the
central anatomical upper-back hollow on both shirts and reduces excess long
forearm volume without changing skin, neck normals, cuff join, rig, clips, UVs
or supplied graphics. Matched clay before/after views, both nine-pose sheets
and actual Godot roster captures are the acceptance evidence for this local
change. The current fixed 11,878-triangle upper-shirt cohort improves from
994 to 975 inverted samples across nine poses; this cohort is not identical
to pre-hem-topology reports and is not an all-pose cloth approval. Further
raglan/collar finish, fabric material and individual identity work remain
under BR-022 (22/25). Native M1 timing remains pending.

### BR-022 collar and raglan construction — 21 October

The [collar/raglan pass](art_briefs/shared_collar_raglan/brief.md) fits a regular
V binding and smooth supporting cloth rows on both shirt variants. The default
Blender pigment now uses the existing runtime home atlas; older source renders
had shown piping that was absent after Godot's role-material replacement.
Surface-skinned trim geometry resolves that mismatch with the existing colour
swatches and one retained mesh/material slot. No supplied image is repainted.
A source validator reproduces collar skin penetration in the old mesh, then
passes all nine fixed poses on the new one. See the brief for the rejected
projection trial, final source/Web evidence and remaining limitations. BR-022
(22/25) stays open; next check fabric normal/roughness response under match
sunlight before expanding individual identities and exact keeper patterns.

### BR-022 shared fabric response — 21 October

The [fabric pass](art_briefs/shared_fabric_response/brief.md) makes the shared
Godot role materials use atlas-aligned linear roughness, restrained original
knit normals and mip-filtered pigment/data textures. The Blender source uses
the same recipe. Supplied graphics, all geometry, weights, custom normals,
bone rests and 19 clips are retained. Fixed sun/shade Web comparisons use real
shadowing with unchanged sky/exposure; source and actual roster evidence cover
both sleeves, keeper, referee, pass and broadcast views. Existing 11v11,
resource-sharing and Play/Watch checks pass. Texture memory rises; native M1
timing/lighting and bright pale-area response remain open. BR-022 (22/25)
stays in progress; next reconstruct both keeper kit graphics from their
archived object sheets and check front/back/save poses before expanding
individual identities.

### BR-022 keeper kit graphics — 21 October

The [pitch-side review correction](art_briefs/pitch_review_stage/brief.md)
places the Web and desktop roster preview on the Kilmore Drive pitch and
shows the static park beyond it. The current gallery no longer uses sky-only
character captures. This is a camera/scene staging correction; the archived
environment sheets remain the visual reference and individual likeness work
is still open.

The [keeper kit pass](art_briefs/keeper_kit_graphics/brief.md) adds original
reference-led shirt patterns for John O'Rourke and the Boardeaux keeper while
applying the archived crest and lettering separately. Role-specific sock
binding UVs let John's cuffs stay white and Boardeaux's stay dark. Actual
11v11 profiles render both kits with editable back prints; the common 65-bone
rig and 19 clips remain. Flat motif art is an approximation of the supplied
boards. Glove construction, individual likeness, a convincing save motion,
and native M1 approval remain open. BR-022 remains item 22/25.

### BR-024 supplied wordmark and menu palette — 21 October

The owner-supplied `69668.jpg` supersedes the native Anton/lime title treatment.
Use its original white/red title ink and a red/black/white landing/Options
palette, keeping the existing photorealistic players and their blue/black kits.
The [menu revision brief](art_briefs/title_red_black_evidence/brief.md) records
the direct-source treatment and Web comparison. This belongs to BR-024 (24/25);
it does not change character/kit production or match broadcast graphics.

## Turf, directed broadcasts and four-head finish — 23 October 2026

The current [follow-up brief](art_briefs/broadcast_turf_refresh_2026_10_23/brief.md)
tracks BR-023 (23/27), BR-026/027 (26/27, 27/27) and BR-022 (22/27).
The owner chose dense short turf near cameras and the existing textured surface
at broadcast distance. Wider blue lower thirds are centered and responsive;
goal, replay and full-time coverage uses deliberate camera stations and cuts.
Shane/John/player Des/referee Des retain separate portraits, sculpts and grooms.
New form/roughness/expression work is an improvement pass, not owner approval
of AAA likeness. Native M1 graphics and performance remain unmeasured.

## Match HUD and second venue — 24 October 2026

BR-006 (6/27) closes the previously missing automatic-cursor acceptance with
real-release receiver handover and stable defensive interception selection.
BR-014 (14/27) uses archived `70060.jpg` for the compact monochrome gameplay
HUD; blue intro graphics are deliberately independent. BR-023 (23/27) now
includes the owner-approved large Rovers Arena beside Kilmore Drive. The
Blender director/environment/LOD/Godot-export workflow produced an original
modular source after the free BlendSwap download was account-gated.

Use the shared functional field/goals/net impacts in either venue. A match-owned
venue profile carries terrain, wear, display identity and camera anchors; never
apply arena stripes/flat ground to Kilmore or copy Kilmore puddles into the arena.
Retain source `.blend`, generator, GLB audit, reference, licences and native
comparison evidence in the owning football project. M1 performance remains
BR-025 acceptance. See `art_briefs/match_presentation_2026_10_24/brief.md`.

## Approved Hill Dickinson remodel — 25 October 2026

BR-023 (23/27, in progress) now replaces the whole Rovers building rather than polishing the earlier octagonal arena. Reference archive: `references/hill_dickinson_2026_10_25/`; production brief and staged native evidence: `docs/art_briefs/hill_dickinson_remodel_2026_10_25/`. Preserve Rovers branding and crowd occupancy. Match the continuous South stand, tiered sides/North, fanned/tapered corners, barrel roof, trusses, masonry/glass/metal shell and maintained pitch. Exterior building included; dockside landscape excluded. Shared grass improvements preserve Kilmore's paint, bumps, wear, mud and puddle physics. Use Blender director/environment/procedural/material/texture/LOD/Godot-export routing. Mac appearance and 1080p60 remain BR-025 (25/27).
