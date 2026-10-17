# Beechlawn Rovers — Reference Art Implementation Plan

**Reviewed:** 2026-10-17  
**Source folder:** [Beechlawn Game reference folder](https://drive.google.com/drive/folders/1GUh4bQDTKJY7-44wLtbsKZAWq6SyIotm); [Kilmore Drive Street View](https://maps.app.goo.gl/p7TfFiB6Qmqviwsh6); [Kilmore Drive satellite view](https://maps.app.goo.gl/SPqee19XAk4EQ6qs7)  
**Archived copies:** [`references/README.md`](../references/README.md)  
**Scope:** Plan only. No Blender source, Godot scene, roster resource, or shipped asset was changed during this review.

## Backlog placement

The work belongs primarily to **BR-022 — Character and kit production (item 22 of 25)** and **BR-023 — Bordeaux park environment (item 23 of 25)**. It depends on the current playable systems and should be brought forward only as a small, representative visual slice is needed to validate the game.

Related work is staged across the existing backlog:

| Backlog item | Relationship to these references | Current state in `docs/backlog.md` |
|---|---|---|
| **BR-003 — Reusable footballer rig and first animation set (3/25)** | Replace the Y-Bot shell after the shared rig, import convention, and proxy locomotion are sound. The final mesh is the target for the first authored football clips. | In progress; proxy rig and idle/jog/sprint blend pass, final human mesh and football actions remain. |
| **BR-005 — Player/team data and tuning (5/25)** | The currently populated four-player rosters cover the short match. The new sheets provide a full Beechlawn identity set for a later roster expansion. | Marked complete for the current four-slot data; do not treat that as full-roster art. |
| **BR-009 — First goalkeeper (9/25)** | John O’Rourke’s #1 keeper identity, gloves, kit, and keeper-specific animation references. | In progress; movement/save logic smoke checked, authored keeper motion and match tuning remain. |
| **BR-013 — Efficient 22-player simulation (13/25)** | Later visual scale-up. Only one Bordeaux face/identity is supplied, so this folder cannot provide a distinct 11-player Bordeaux team. | Not started. |
| **BR-016 — Fouls, offside and referee (16/25)** | Des Feeney Sr. character/kit and referee actions. | Not started. |
| **BR-019 — Shooting and aerial actions (19/25)** | Later headers, volleys, jumps, crosses, and keeper aerial interactions. | Not started. |
| **BR-021 — Animation contact and blending pass (21/25)** | Final foot planting, transitions, contact markers, and camera-distance review against the finished players. | Not started. |
| **BR-022 — Character and kit production (22/25)** | Main destination for all player/referee likeness and kit work. | Not started. |
| **BR-023 — Bordeaux park environment (23/25)** | Main destination for pitch, goal/net, local boundary, vegetation, houses, and lighting. | Not started. |
| **BR-025 — M1 performance and Mac delivery (25/25)** | Final target-device 1080p/60 fps validation after the authored assets enter the 4v4 and 11v11 scenes. | Not started; M1 Pro/16 GB hardware profiling is still required. |

The practical order is: **finish the BR-001/002 playable checks; keep BR-003 animation authoring on the verified Y-Bot proxy; create the first final-human/kit/keeper/referee visual sample under BR-022; integrate and tune those assets with BR-009/016/021; finish the park under BR-023; only then expand the art load for BR-013 and profile under BR-025.** This keeps the first 4v4 match useful and avoids making a full roster before contact, camera, and performance constraints are known.

## Reference audit

The folder contains 27 files: 26 PNG reference sheets and one Google Maps satellite screenshot.

File-level audit: 12 Beechlawn player sheets; two overlapping Beechlawn home-kit sheets and one Beechlawn goalkeeper-kit sheet; one Bordeaux player sheet, one Bordeaux home-kit sheet, and one Bordeaux goalkeeper-kit sheet; one referee character sheet and one referee-kit sheet; one ball sheet and one goal/net sheet; two pitch/location boards; two gameplay/presentation composites; and the satellite screenshot. The two Beechlawn home-kit boards agree on the main kit design but provide different coverage, so treat them as complementary views rather than separate uniforms.

### Characters and kits

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

The Bordeaux folder contains **one outfield identity: Des Feeney #9**, with a balding/receding head, short sides, and goatee/beard. His home kit is sky blue with dark trim, black shorts with white side panels, white/blue socks, and “Boards.ie” sponsor. A separate Bordeaux goalkeeper kit sheet shows the same Feeney face, a charcoal patterned shirt, black shorts/socks, gloves, and “FEENEY 1” on the back. That supports the requested 4v4 visual base (three outfield slots plus keeper), but not a distinct 11-player Bordeaux roster. Keep the other Bordeaux slot IDs/names/ratings generic as current data policy requires; do not fabricate player identities.

The **referee is Des Feeney Sr.**, a separate older character with a bald/receding head, grey moustache, all-black referee kit, whistle, watch, and red/yellow cards. The supplied referee sheet gives no squad number. Keep him distinct from Bordeaux player Des Feeney #9 in names, mesh, materials, and roster data.

### Objects, field, and match look

- **Ball:** worn off-white panelled size-5 match ball, approximately 21–22 cm diameter, with red/black graphics, seam/stitch detail, dirt, abrasion, and surface maps. The project already uses an owner-supplied worn model around 4.4k triangles; retain it and first compare its UVs/graphics/material to the sheet rather than rebuilding a duplicate.
- **Goal:** weathered white/cream tubular frame and sagging net, approximately 7.32 m wide by 2.44 m high. The sheet calls for a no-stanchion/local-park style, chipped paint/rust/mud, knotted net, and a low-cost playable collision setup separate from render geometry.
- **Pitch sheets:** a Bordeaux/local-park environment board and a Beechlawn location board show a residential Dublin park setting: worn natural grass, patchy high-use areas, faded/irregular painted markings, houses and parked cars along one side, a boundary wall/hedge, footpaths/street edge, mature trees, and distant floodlights. The actual satellite screenshot gives field orientation and surrounding footprint only; it should not be used as an in-game photo texture.
- **Street View supplement:** I resolved and viewed the shared panorama from eight headings around the same roadside location. Looking across the field, the road-side foreground has asphalt, a curb, a narrow paved footpath, and grass; the playing field is broad and open, with goal frames, a far boundary of low wall/hedge and trees, and low residential roofs beyond. Rotating toward the street shows semi-detached houses, front gardens, hedge-topped walls, parked cars, utility poles, and several overhead wires. A leafless roadside tree and small planted/shrub areas break up the near edge. The panorama is an overcast, soft-light reference. These observations add the missing road-facing boundary and overhead-wire silhouettes to BR-023; use the panorama for layout and visual study only, never as an in-game texture.
- **Satellite supplement:** the shared link opens the aerial layer over Kilmore Drive and can be zoomed onto the western park field. The wide view confirms the park’s irregular outline and orientation against Kilmore Drive/Beechlawn streets, housing/back gardens, and the separate, more formal playing ground to the east. At closer zoom, the target field shows faint/overlapping line layouts, broad worn/muddy traffic strips, a few bare patches, two small goal frames, trees along parts of the residential edge, and a long straight hard boundary beside the neighboring ground. This is strong evidence for the rough field footprint, axis, neighboring context, and grass variation. The imagery is not a survey: linework is faint, some markings overlap, and the closest tiles soften, so do not claim precise full-pitch dimensions from it. Set playable dimensions from the football specification and verify placement against the goal (7.32 m) and field markings. Treat the satellite photo as a layout/reference source, not a game texture.
- **Gameplay/presentation boards:** two composite images show an elevated sideline broadcast view, score/time HUD, radar, players in midfield, close duel/face shots, a celebration, and a goalkeeper save. Use these to prioritize composition and readability. Do not reproduce third-party game marks/logos visible in a concept image.

## Production approach

### 1. Lock a reference bible and screen-distance targets

Create a compact reference board per asset family: (a) player head/face/profile and full-body silhouette, (b) kit graphics, (c) keeper, (d) referee, (e) ball/goal, (f) pitch layout and boundary, and (g) broadcast framing. Establish a 1 Blender unit = 1 metre scene with a 1.8 m mannequin and the stated real-world ball/goal dimensions. Compare silhouettes from the intended broadcast camera before small detail; use the head/profile views for face likeness and the turnaround for clothing/number placement.

Use a consistent reference hierarchy: individual character sheets control face, hair, build, and sleeve silhouette; kit object sheets control reusable colors/logos/material construction; the environment sheet and location board control setting/layout; the gameplay composites control camera framing and scene readability. Do not turn the example skin-map panels into direct texture projections.

### 2. Build one reusable human body/rig and establish a representative slice

Keep the verified Mixamo Y-Bot 65-bone skeleton/import convention as the initial retarget target, but replace its robot shell with one game-ready, human-proportioned, deformable base mesh. In Blender, block proportions first, then build clean deformation topology, individual head shapes, and hairstyle silhouettes. Use one shared body/rig and shared body/kit materials where possible; use distinct heads and hair to preserve each supplied identity. Fit the goalkeeper and referee through kit/accessory variants rather than creating unrelated skeletons.

The first art review set should cover the currently playable Beechlawn trio (Shane #8, Robbie #10, David Murray #5), John O’Rourke #1 in goal, Bordeaux Des Feeney #9 as the shared outfield visual base plus his “Feeney 1” keeper kit, and Des Feeney Sr. as referee. Use neutral A/T-pose and one running/turning pose for deformation review. Once the pipeline is approved, author the remaining Beechlawn identities against the same base for the later roster. Avoid trying to model all twelve Beechlawn players before the first representative mesh, rig, kit, and Godot import pass is accepted.

Face work should prioritize recognisable silhouette and proportions: head shape, brow/eye spacing, nose, jaw, hairline, hairstyle, and facial hair. Use the multiple expression panels as reference for simple facial pose targets (neutral, focused, talking, smile), not as a promise of full cinematic facial capture. For game playback, a small set of efficient facial controls/shape keys is enough initially. Hair should use restrained game-ready cards or shaped clumps, not a heavy real-time strand groom.

### 3. Make kit graphics and skin/fabric materials consistently

Create fitted, separately manageable jersey/short/sock/glove pieces over the shared body, with weights transferred then manually cleaned at shoulders, hips, elbows, knees, and cuffs. Preserve the selected sleeve variant per player sheet. Put team stripes, sponsor, crest, names, and numbers in clean UV/decal assets rather than floating geometry; use the same UV layout and material for all Beechlawn outfielders, swapping player name/number data. Keep Bordeaux outfield and keeper uniform masters separate. Match the reference’s skin tone and facial texture with calibrated base-color/roughness/normal maps; use subdued rough skin, natural facial variation, and realistic eye response. Use woven fabric micro-normal/roughness and modest cloth sheen; boots, sock elastic, glove latex, and printed marks need distinct but restrained material response. Use Principled BSDF/glTF-compatible materials only.

Texture size and detail should follow the final camera test: start with a 2K head/face set for the near players and shared 1K–2K team kit textures, then validate memory/draw calls in Godot before duplicating for 22 characters. Use mipmaps, shared materials, atlas repeated details, and LODs; no runtime cloth simulation for the first release.

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

Keep editable `.blend` sources and repeatable scripts under `games/beechlawn_rovers/tools/blender/`; export game assets to the project’s own `assets/` tree as GLB. Use the Godot export checklist: applied scale/rotation, clean Y-up hierarchy, compatible Principled materials, shared skeleton, named animation clips, relative/packed textures, and separate collision geometry. Import each representative character alone first; verify skeleton/rest pose, correct height, material slots, skinning at extreme arms-up/crouch/turn poses, clip names, event-marker timing, and no unexpected root translation. Then check a Godot match scene with the final meshes, ball contacts, camera and lighting.

The mannequin pass is not the final gate. Review at two scales: face/kit close shot for likeness and logo/number placement; normal broadcast view for team distinction, legibility, pitch/goal framing, and animation contact. Run repeatable 4v4 and then 22-character render/profile probes. The M1 Pro 16 GB goal remains an unmeasured target: keep 60 fps provisional until a target-device 1080p playtest records frame-time, memory, shader stutter, draw calls, and input response. In cloud, check Godot import/startup, deterministic simulation smoke tests, asset counts/material sharing, and a representative capture; do not call these M1 validation.

## Decisions to resolve before texture lock

1. **Beechlawn crest date:** the kit object sheets show “EST. 2004,” while several player character sheets display “EST. 2006” or “EST. 2008.” Treat the kit object sheet as the shared kit master for now, but confirm the canonical year before producing final crest decals.
2. **Sleeve variant:** individual player turnarounds generally show long sleeves; some kit-only garment panels show short sleeves. Use each player turnaround as the authority for the first pass and make the short-sleeve shirt a separate optional variant only if requested.
3. **Bordeaux roster depth:** this folder supplies Des Feeney #9 and “Feeney 1” keeper uniform/face references, not distinct identities for an 11-player squad. The requested 4v4 lineup can use the same source visual base for its three outfield slots and keeper. BR-013 will need more references or an explicit choice to use non-identifying generated variation for the other Bordeaux positions; do not silently invent names or likenesses.

## Blender skills and tools to apply

The relevant installed repo guides are `blender-director` (reference analysis and staged production brief), `character-artist` (likeness, topology, hair, garments), `rigging` (shared skeleton, weights, deformation tests), `blender-materials` (PBR skin/fabric/grass and glTF compatibility), `blender-animation` (timing, curves, contact, reusable clips), `environment-artist` (park layout, modular buildings, instancing), `prop-artist` (ball/goal construction and pivots), `asset-optimization` (LOD/material budget), `collision-proxy` (goal/gameplay colliders), and `godot-export` (GLB handoff/import checks). Per root `AGENTS.md`, Blender 4.3.2 is available headlessly through `bpy`; no Blender MCP is connected. Use repeatable headless Blender scripts, inspect source `.blend` files directly, and report that workflow accurately.
