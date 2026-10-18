# Shane Denham: face, body and Beechlawn kit matching plan

Reviewed 2026-10-18. **BR-022, item 22 of 25: in progress, prototype not approved.**

This is the next execution plan for Shane. It supersedes the proposed next steps in earlier prototype logs where they disagree. The goal is a faithful visual match under controlled Blender and Godot views, with the same quality retained during football animation. An exact reconstruction of unseen anatomy is not determined by these 2D sheets; conflicting depictions must use the explicit reference hierarchy below.

## Sources and reference decisions

All paths below are relative to `games/beechlawn_rovers/`.

| Purpose | Archived source |
| --- | --- |
| Primary face, build, fit, expressions, long sleeves and identity #8 | `references/source_uploads/drive_folder/file_00000000d76881f48f576ff4249aa3b2.png` |
| Additional Shane front/profile/turnaround evidence | `references/source_uploads/chat_attachments/character_roster_sheets/1-69014.jpg` |
| Shared home-kit construction, palette, crest, sponsor, manufacturer and fabric | `references/source_uploads/drive_folder/file_000000000da0824386b7ef8edd3a9c79.png` |
| Complementary shared kit views and alternate back treatment | `references/source_uploads/drive_folder/file_00000000fcac81f4b3870dc4ce96ac38.png` |
| Current editable mesh | Repository-root `tools/blender/beechlawn/shane_denham_08.blend` |
| Current generator | Repository-root `tools/blender/beechlawn/build_shane_denham_player.py` |
| Current texture generator | Repository-root `tools/blender/beechlawn/build_shane_tailored_textures.py` (2K panel atlas; uses archived artwork extraction) |

Working interpretation, consistent with using the kit object boards as the shared uniform master:

- Shane's face, body, long sleeves and personal number come from his character sheet. The master kit's example wearer, MURRAY and number 5 are not Shane's identity.
- Use the kit-board blue/black panel construction, centered Uhlsport mark, left-chest crest, Thomas Loomes & Co sponsor, black shorts and royal-blue socks. Its palette is blue `#1E5CC6`, black `#0B0B0B`, white `#FFFFFF`, interpreted as sRGB source colors.
- The character sheet instead shows Umbro marks, blue sleeves, black socks with blue/white tops, a white shorts side stripe, and a different crest/date. These cannot all match the kit master simultaneously. The proposed production version uses the kit master for those shared details; do not keep mixing the two uniforms accidentally.
- Keep the existing provisional kit-board crest, EST. 2004, intact. Owner correction on 2026-10-17: Shane's back must read **S. DENHAM** above **8**. Use the kit board's condensed uppercase name treatment and Shane's character-sheet chamfered block eight, rather than copying MURRAY/5. This explicitly supersedes the earlier number-only assumption. For the proposed shared-master shorts, use its crest/manufacturer treatment rather than adding the character sheet's conflicting white stripe/number layout.

These choices are stated assumptions, open to an explicit owner correction. They do not block the body, face or garment-topology work.

## What was actually reviewed

Opened the current `.blend` directly with Blender 4.3.2, regenerated front/profile/three-quarter/back/portrait views, inspected mesh/material/UV/bone/weight data, and inspected the actual GLB material JSON. Refreshed Godot's import before repeating the asset smoke check. The earlier full-body images and Godot cache were stale; their old face and triangle count were not reliable evidence of the latest export.

Pre-fix audit: [`br022_shane_current_asset_audit.json`](br022_shane_current_asset_audit.json), capturing the 41,204-triangle, 15-surface starting version. The subsequent [foundation pass](br022_shane_foundation_pass.md) recorded a 37,716-triangle, 10-surface intermediate export. The [body, face and tailored-kit pass](br022_shane_body_face_tailored_pass.md) supersedes that asset and records the current visual work; the [validation report](br022_shane_foundation_validation.json) always identifies the current GLB by checksum. All 65 bones and 15 actions remain unchanged. The gap table below is the initial diagnosis, not a description of every current defect. Structural validation is not likeness approval.

## Reference-to-model gaps

| Area | Current visible gap | Required result |
| --- | --- | --- |
| Face | Generic oval/pointed lower face; weak brow, cheek and mouth planes; no convincing eyebrows or lip color; eye/eyelid integration is basic. | Shane's compact, broader face, soft squared jaw/chin, fuller cheeks, distinct brow/orbits, bridge/tip/nostril shape and mouth proportions in both front and profile. |
| Skin | Pale and flat; head/body response differs. The procedural head shader has neither a base-color texture nor base-color factor in the GLB, so its exported base defaults to white. | Matched complexion with anatomically placed pigment and restrained pores/roughness, represented by portable baked maps and an explicit fallback color. |
| Hair | Smooth brown cap with a jagged polygon hairline and no cropped-hair flow. | Shane's short brown crop, temple taper, irregular natural hairline, crown direction and breakup at the silhouette. |
| Body | Torso/waist silhouette is too pinched and elongated relative to the sheet; neck transition, hands and lower limbs remain crude. Local heuristic transforms distort the anatomy. | A solid adult Sunday-league build matching the source front/profile/back proportions, with natural torso, pelvis, thighs, knees, calves, hands and feet. |
| Jersey geometry | Hem extends too far down, with open/jagged collar and shoulder boundaries; sleeves and armholes are poorly constructed. | Correct hip-level hem, restrained loose sports fit, continuous raglan/shoulder construction, deliberate collar and cuffs, and believable fabric volume. |
| Jersey design | Pale-looking blue, overly simple wrap stripes and uniformly blue sleeves; sponsor is small/high; crest and back #8 are not reliably visible on the mesh. | Master-board royal blue/black stripe widths, black raglan sleeve areas with blue shoulder/outer-arm detail, real collar trim, crisp chest marks and correctly located #8. |
| Shorts | A dark material region on the body with tight fit and jagged boundaries. | Independent black shorts with waistband, crotch/inseam, two open mid-thigh legs, hems, cloth volume and the selected master-board marks. |
| Socks/boots | Capsule socks and ring bands are detached from the anatomical shins; boots sit forward of bare feet. These are modeled placement errors visible in profile/back. | Socks follow calves/ankles into the boots; plain royal-blue ribbing/folded tops for the master uniform. Correct boot size, toe/heel placement and ground contact. |
| Motion | Rest-pose appearance conceals deformation problems. | Stable shoulder, elbow, hip, knee, ankle and neckline behavior in actual existing football clips. |

The weight audit found **1,160 body vertices and 432 kit vertices with positive deformation weights whose sums differ from one by more than 0.001**. None of the used vertices is completely unweighted; no vertex has more than four positive deforming influences. Normalization must be repaired and pose-tested. This audit alone does not prove it causes every visible deformation artifact.

## Ordered execution plan

1. **Establish a trustworthy comparison scene and anatomy/rig fit.** Preserve the current rejected iteration; work on a versioned next source. Match the reference cameras and an arms-down neutral review pose, alongside construction rest pose. Use the sheet's approximate 1.80 m as an editable scale assumption. Record shoulder/chest/waist/hip widths, crown/chin/neck landmarks, crotch/knee/ankle positions, elbow/wrist positions and foot size. Set one consistent mesh/armature coordinate convention; align source joint centers to the existing 65-bone rig before transferring weights. Replace the piecewise arm/leg coordinate guesses in `make_makehuman_body()` with continuous, joint-aware fitting. Fix `prune_vertex_weights()` using copied `(group, weight)` values before removing assignments, then normalize from that stable snapshot. **Gate:** correct body/skeleton/foot alignment in front/profile/back, verified weight sums, and a simple bent-knee/arm test without collapse.

2. **Resolve Shane's body silhouette in clay.** Shape the existing licensed anatomical base with continuous sculpt/cage edits. Match the sturdy torso, less pinched waist, pelvis, limb lengths/mass, neck and hands to the personal sheet. Use separate neck/head regions only with a deliberate seam and shared position at the join. Fit socks and boots against these actual legs/feet, not independent hard-coded centers. Preserve the existing gameplay rig/clip interface; report any unavoidable rest-pose change before applying it. **Gate:** matching neutral front/profile/back silhouettes, believable joint locations and no separate bare feet showing behind shoes.

3. **Sculpt the facial likeness, then hair.** Measure paired front/profile landmarks: eye line and spacing, brow/orbit, cheek width, nose bridge/alar width/tip projection, mouth width and placement, chin depth/width, jaw angle, ears and cranial silhouette. Make localized anatomical edits with a higher-resolution sculpt source where necessary; retain or rebuild clean eyelid/lip/nose loops on the game mesh. Fit eyes beneath eyelids rather than leaving exposed overlay-like spheres. Match neutral likeness first, then add a restrained smile and blink shape using the expression references. Shape the short crop to the actual skull; use a scalp layer plus limited clumps/cards or baked detail. **Gate:** recognizable front, profile and three-quarter clay face before skin texture; no portrait image used to supply the facial features.

4. **Construct the actual garments.** Build manageable front/back/side and long-sleeve pieces around the fitted body, with deliberate raglan joins, shoulder/underarm loops, V/crossover collar, ribbed cuffs and hem. Use body extraction as a starting surface only; replace threshold-cut edges in `make_fitted_jersey_from_body()` with proper boundaries. Add modest cloth ease and sculpted folds at armpits, elbows, waist and hem. Build separate shorts with an elastic waistband, inseam, leg openings and appropriate loose volume. Build calf-shaped socks with the selected folded cuff and boot overlap. Remove or hide covered body faces only after deformation coverage is verified. **Gate:** complete geometry in front/side/back, clean boundaries, no intersections or gaps at normal poses.

5. **Unwrap the complete uniform and match every mark.** Replace the wrap projection with explicit front, back, sleeve, collar, short-leg and sock UV islands. Keep unique artwork unmirrored. Register the stripe count/width/phase and shoulder detail to the master, using normalized garment landmarks for badge, manufacturer, sponsor and #8 placement. Use the supplied art; trace it cleanly if extraction resolution is inadequate. Preserve readable lettering and the exact selected crest. The whole visible uniform design belongs in its authored texture layout, not only a generic fabric swatch. **Gate:** checker texture has no obvious stretch, seam alignment is intentional, all front/back/shorts marks are visible at the correct sizes and positions.

6. **Bake and calibrate portable materials.** Author skin, lips, eyebrows and subtle facial variation on the actual head UVs; retain the portrait solely for comparison. Bake skin, cloth weave, small seams and hair detail to image maps. Use albedo without baked scene light, tangent-space normals and roughness/packed data maps. Match knit scale and restrained polyester sheen; prints and crest need their own masked response. Calibrate source sRGB palette under neutral light before adjusting exposure or saturation. Verify the face exports either its baked base-color map or an explicit pigment factor; a default factor of one is valid when multiplied by its baked texture. Inspect material JSON and the imported Godot materials; procedural Blender noise is not automatically reproduced by GLB. **Gate:** no white/default face, consistent head/body skin and garment colors, clean skin/hair boundaries, no detail present only in the Blender render.

7. **Validate deformation and texture stability.** Transfer weights after shape/topology changes, then clean them locally at shoulders, elbows, pelvis and knees. Check neutral, idle, walk/jog, sprint, pass, shot, turn, crouch, slide and get-up using the existing clips. Review both animation and stills at the extreme frames. Ensure stripes, lettering and cuffs stay attached; avoid hard seams, body exposure, pinching and stretched shorts. Bake authored cloth folds into mesh/normal maps; runtime cloth is not required. **Gate:** every named test pose/clip passes the visual checklist with at most four normalized deform weights per vertex.

8. **Verify the exported character in Godot and measure cost.** Force the changed GLB to reimport before smoke/visual checks. Compare exported triangle/material/image counts with the loaded Godot asset to catch stale imports. Capture head/kit close-ups, normal broadcast gameplay and motion in both the Web Compatibility test build and the Mac rendering configuration. Then test the 4v4 scene and a 22-character stress scene. Only replace the active proxy after likeness, garment and motion evidence pass. **Gate:** exported appearance agrees with approved Blender views, kit reads correctly in the match, and M1 Pro/16 GB/1080p frame-time/memory validation is recorded when hardware is available.

## Performance direction

- Keep the current roughly 41k-triangle export as a baseline. Spend additional geometry only on face silhouette, hands and garment deformation where visible; reduce it elsewhere using measured screen size.
- Initial candidate budgets: approximately 40–60k triangles for the nearest player, 20–30k intermediate LOD, 8–15k distant LOD. These are tuning starting points, not proof of 60 fps.
- Aim for roughly 5–6 effective material surfaces rather than the current 15, combining eyes/iris/pupils and compatible opaque kit parts after correct UVs are established. Verify the actual surface/draw-call count in Godot.
- Start with a 2K head set and shared 2K team-kit set, mipmaps and appropriate compression. Record total texture memory across the team. Avoid copying unique full kit maps to every player solely for name/number changes.
- Bake sculpt detail and cloth folds offline. Use the current skeleton and simple gameplay collision. No additional per-frame cloth/hair physics or long IK chains are needed for this work.
- Correct normals and use backface culling where the garment construction permits; the current GLB marks all materials double-sided. Avoid unnecessary transparent layers and alpha overdraw.

## Skills and evidence

Start with project `create-player` and shared `blender-director`/`character-artist`. Use `retopology` for face/joint/garment topology, `rigging` for fit/weights/pose checks, `hair-groom` for the short crop, `uv-workflow` and `blender-uv-texturing` for anatomical/panel maps, `blender-materials`/`realistic-style` for look development, and `godot-export` for the actual engine delivery. Run them through headless Blender/bpy available in this environment.

For each stage, save the editable source and the matching fixed review views, record the specific remaining mismatches, and make small reversible edits. Maintain both clay and textured comparison views. A passing load test, extra polygons, a generated beauty image, or a flattering camera alone cannot satisfy the visual acceptance gate.

**Execution update, 2026-10-18:** The [body, face and tailored-kit pass](br022_shane_body_face_tailored_pass.md) applies compact head/full torso shaping, reference-directed anatomical facial targets, curved textured eyes, an opaque short-hair build, anatomical skin UVs, continuous fitted garments and a complete 2K panel atlas. It retains S. DENHAM / 8 and the enlarged Thomas Loomes sponsor. See that report for actual Blender/Godot evidence, technical corrections and remaining visual gaps. The [likeness/deformation cleanup](br022_shane_likeness_cleanup.md) adds clean licensed skin detail, strand-textured hair, corrected neck normals, patterned shorts and a six-bone leg-roll retarget that preserves sampled contact paths. **Immediate next acceptance check:** close likeness against the sheets, then full-clip garment/AnimationTree review and final-mesh gameplay contact. BR-022 remains in progress; structural checks and a browser asset review do not approve likeness or M1 performance. Keep the prototype out of the roster until those gates pass.
