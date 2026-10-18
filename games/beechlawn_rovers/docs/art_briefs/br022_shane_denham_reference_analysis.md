# BR-022 — Shane Denham #8 reference analysis

**Scope:** First human player and Beechlawn home-kit prototype, using the existing Y-Bot skeleton only as a retarget baseline. This is a likeness and construction pass, not roster completion.

## Subject and source map

- Identity: Shane Denham, Beechlawn Rovers #8, outfield player.
- Character sheet: `references/source_uploads/chat_attachments/character_roster_sheets/1-69014.jpg` (front/profile/back body views and face/expression views).
- Home kit construction: `references/source_uploads/drive_folder/file_000000000da0824386b7ef8edd3a9c79.png` and `file_00000000fcac81f4b3870dc4ce96ac38.png`.
- Existing rig baseline: `assets/characters/mixamo/y_bot_animation_library.glb`, editable source `tools/blender/beechlawn/y_bot_source.blend` and animation source `games/beechlawn_rovers/tools/blender/y_bot_animation_library.blend`.
- Target: reusable gameplay character, about 1.80 m per the sheet; intended 4v4 broadcast view at 1080p. Face and kit must also pass fixed studio close/turnaround views.

## Reference-to-feature map

| Feature | Evidence | Modeling decision |
|---|---|---|
| Overall silhouette | Character sheet front/profile/back | Adult male, medium/compact build; natural shoulder, torso and thigh mass; no exaggerated athlete proportions. Use 1.80 m as the sheet's approximate scale, not a biometric claim. |
| Face | Front, profile and expressions | Short brown hair, clean-shaven, broad/rounded lower face, moderate brow and nose, fair skin. Match the main planes and hairline before adding skin detail. |
| Hair | Portrait and head turnaround | Short brown cut, compact scalp silhouette with restrained directional clumps; no long groom/cards that create broadcast-distance alpha cost. |
| Jersey | Character sheet plus kit object boards | Long sleeves; black body with bright royal-blue vertical panels/stripes, blue sleeves and collar trim. Build separate fitted garment surfaces over the shared human base. |
| Graphics | Kit boards | White `THOMAS LOOMES & CO` front sponsor, supplied Beechlawn crest, white #8 front/back/shorts numbers where the board shows them. Preserve source art and do not invent a crest founding date; source sheets conflict on date. |
| Shorts/socks/boots | Character sheet and kit boards | Black shorts with blue/white side detail; black socks with blue and white bands; dark boots with restrained studs. |
| Materials | Kit closeups and supplied skin-map examples | Matte woven fabric with subtle weave/roughness variation; natural fair skin and restrained roughness/SSS. Do not bake lighting into textures or use example skin map as direct projection. |
| Rig | Current Mixamo Y-Bot import | Keep its skeleton/bone names and metre-scale convention if compatible; replace robot shell with human mesh and fitted clothing. Verify sprint, kick, crouch, turn and fall deformations. |

## Camera and look development

- Fixed studio views: neutral front, profile, three-quarter, back, portrait closeup; orthographic turnaround cameras for body and 70–85 mm portrait lens for face.
- Neutral overcast key/fill, grey card, fixed AgX view transform and exposure. Keep same camera, light and pose for future comparisons.
- Game acceptance view: existing elevated broadcast camera, both teams and ball visible; check legibility of blue/black striping and number at actual player pixel size.

## Current gap and priority

The current Y-Bot shell is segmented and robotic and cannot be accepted as the human identity. Current kit palettes and floating labels do not provide garments, UV graphics, facial identity, or suitable deformation. Highest priority is a coherent human silhouette/body and fitted kit on the known skeleton; second is head/hair likeness; third is texture/graphic refinement and gameplay deformations.

## Active skills and execution gates

Use project-local `create-player`, plus `blender-director`, `character-artist`, `blender-materials`, `realistic-style`, and `rigging` for skeleton fit/export. Read the relevant source images and audit the actual imported mesh/skeleton. Build reproducibly with `bpy`; inspect front/profile/three-quarter/back/portrait renders before Godot import. Keep player geometry/material work inside this Beechlawn project; do not reuse wrestling assets.

1. Capture/audit current rig and establish scale/bone map.
2. Build human proportions and silhouette; render fixed turnaround.
3. Build face/hair and fitted jersey/shorts/socks/boots; fit supplied marks.
4. Validate deformation on existing football clips and export GLB.
5. Inspect exported player in Godot at close and broadcast views; record remaining likeness/rig gaps.

## Performance assumptions

Share the skeleton and common materials across players. Avoid runtime cloth/hair physics and heavy transparent strands. Measure triangles, textures, draw calls and alpha coverage after the first mesh exists. M1 Pro / 16 GB / 1080p / 60 fps remains unverified until measured on the target Mac.

## First modelling pass — review outcome (2026-10-17)

- Created a repeatable Blender source/build at `tools/blender/beechlawn/build_shane_denham_player.py` and `tools/blender/beechlawn/shane_denham_08.blend`; exported `assets/characters/_prototypes/shane_denham_08_prototype.glb` with the shared 65-bone rig and 58,564 triangles. Fixed review renders are saved beside this brief (`shane_denham_08_front.png`, `..._profile.png`, `..._threequarter.png`, `..._back.png`, `..._portrait.png`).
- The prototype checks material placement and export plumbing, but it **fails the likeness and animation gates**: face is toy-like and missing the sheet's broad facial planes, body and clothing read as separated capsules rather than a continuous human, and the existing idle clip visibly deforms the hip/leg region. The shirt graphics are placeholders, not the supplied crest or a UV-matched garment texture.
- It is intentionally **not integrated into the roster**. The match continues to use the existing proxy. The Godot import smoke test confirms only that this draft retains its skeleton, selected clips, material surfaces and a modest triangle count; it does not validate quality.
- Next player pass: replace the primitive-built surface with a continuous human base suitable for skinning (prefer a freely licensed, editable human base over adding more primitive detail), transfer weights against the actual Y-Bot bind pose, then solve face silhouette and kit UV/crest before another review. Keep this prototype as a rejected iteration/reference for what to avoid; do not label BR-022 complete.

## UV face follow-up (2026-10-17)

- Replaced the floating front-face photo patch with a separate 64×32 lat-long head mesh, skinned to the existing `mixamorig:Head` bone and carrying a dedicated `JerseyUV` map. The supplied Shane front portrait is registered into a 1K head albedo atlas; the head is deliberately kept separate through GLB export so its UV layer is not lost when kit meshes are joined.
- Updated the review cameras to use the character's actual front/back directions and reset the rig to rest pose for likeness comparisons. Front, profile, three-quarter, back, and portrait review renders were regenerated.
- Blender GLB export and Godot headless import smoke test pass. The smoke test reports 65 bones, face/kit textures, core clips, and 54,580 triangles.
- This is a UV pipeline/projection pass, not a finished likeness. The photo still reads as a frontal projection on a simple ellipsoid; profile texture coverage, facial planes/topology, hairline and short-hair shape, head/neck integration, and full-body anatomy remain below the `create-player` acceptance gate. Keep the player out of the match roster until those gaps are corrected and the final mesh is checked in Godot.

## Likeness refinement pass (2026-10-17)

- Compared the existing fixed Blender review render against the archived sheet and the pitch-render target. The key gap is structural: the current draft still uses a projected face on a simplified skull and tube/capsule-based body parts. Lighting and extra texture detail alone cannot make it match the natural game-render anatomy.
- Updated the repeatable build to give the head a tighter jaw and fuller cheek contour, shallow nose/cheek/brow relief aligned to the registered portrait, and a neck that overlaps into the shirt collar. Rounded the jersey shoulder/collar profile and replaced the two visible sleeve capsules per arm with one continuous tapered blue sleeve and a narrow black inner panel, matching the long-sleeve reference better.
- Rebuilt the Blender source and GLB. `shane_denham_import_smoke.gd` passes in Godot 4.6.3: 65-bone rig, 15 core actions, kit/face textures present, 54,580 triangles. The GLB remains a prototype and is still not assigned to the active roster.
- Review remains **not approved**: current front/T-pose render still shows simplified body anatomy, limited hand/boot forms, rigid arm presentation in the bind pose, and the face remains a photo projection rather than finished facial topology with full side-view match. The next high-impact step is to replace the primitive body/head foundation with a deformable, licensed human base mesh, then transfer/clean weights on the Mixamo skeleton and re-register Shane's face/kit UVs before in-game review. Avoid polishing small skin detail until that base is solved.

## Body and jersey correction pass (2026-10-17)

- Rebuilt the Beechlawn jersey atlas to use the supplied #1E5CC6 blue, twelve alternating wrap panels, source crest, manufacturer mark, and source sponsor artwork. Reduced and recentered the sponsor inside the front-facing UV area to prevent it wrapping beneath the sleeves. Widened the waist/chest profile so the jersey no longer tapers like a narrow mannequin torso.
- Replaced the brief-like shorts volume and independently deforming leg islands with a longer mid-thigh short silhouette; reduced the overlarge knee/calf forms. Updated the review script to show the action's planted first frame rather than the later weight-shift frame.
- Rebuilt Blender source and exported the updated prototype GLB. The `shane_denham_import_smoke.gd` test passes (65 bones, face/kit textures, clips, 54,580 triangles).
- **Still not approved for roster use.** The idle-pose render continues to expose gaps and poor lower-body deformation, and the proxy-based anatomy remains unlike the natural human proportions in the sheet/render. The source Mixamo mannequin / generated primitive replacement is now the clear blocker; this pass improves jersey layout and bind-pose proportions but does not meet the requested final visual match. Next work should use a continuous, properly licensed humanoid base mesh, then re-skin the clothing with joint-aware weights and validate all four views plus gameplay idle/walk.

## Clothing construction research and kit recommendations (2026-10-17)

### What the latest render shows

- The blue/black atlas and front graphics are present, but the shirt is still a procedural ring shell. Its profile reads as a stiff tube, the torso-to-sleeve transition is not tailored, and skin shows around the shoulder/side in the neutral rig pose. The front UV projection also compresses parts of the sponsor/crest at the chest curve.
- The shorts are currently represented mainly as a material region on the body, so they lack a real waistband, hem thickness, fabric break and convincing leg openings. Sock bands and boots are separate simple forms and need to be integrated with the kit silhouette.
- A measured torso-profile experiment was tried against the MakeHuman body, but the garment and body deformed differently in the review pose and the result was worse; that experimental edit was reverted. Do not treat the current shell as an approved clothing solution.

### Recommended garment workflow

1. **Fit from the final body in its bind pose.** Use the licensed human body as the fit source. Extract/duplicate only the torso surface needed for the shirt, then build the garment as a clean outer surface with deliberate clearance and separate front, back, side, shoulder and sleeve regions. Use shrinkwrap locally as a fit aid with an explicit target, mode and offset; do not shrinkwrap a whole loose shell across both sides of the body, since nearest-surface projection can pull faces through the torso or onto the wrong side. Blender documents shrinkwrap as projection onto a target surface and notes its different projection modes [in the modifier manual](https://docs.blender.org/manual/en/latest/modeling/modifiers/deform/shrinkwrap.html).
2. **Give the shirt garment topology, not a cylinder silhouette.** Use mostly even quads, with flow from chest and back into the shoulder, armpit and sleeve. Add support loops at the collar, shoulder seam, elbow, cuff and hem; keep the underarm opening clean and add a small gusset only if the pose tests show pinching. A light Solidify modifier can add a small hem/cuff edge for renders, but the final real-time mesh can bake/apply that detail; Solidify is thickness along surface normals and has limits around tight corners, so inspect hems and intersections [in Blender’s Solidify documentation](https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/solidify.html).
3. **Separate garment panels in UV space.** Place front and back as broad, low-distortion islands; unwrap sleeves independently so the stripes run consistently down each arm; reserve small islands for collar/cuffs. Put seams under the arms and along the side panels where they are least visible. This gives the sponsor and crest a stable, readable front-chest area rather than stretching them around a cylindrical UV. Blender’s UV guidance describes seams as cuts that guide how a mesh is unfolded [in the UV manual](https://docs.blender.org/manual/en/5.0/modeling/meshes/uv/unwrapping/seams.html).
4. **Preserve the actual supplied kit art.** Keep the supplied Beechlawn atlas for the blue/black striping, Uhlsport mark, crest, sponsor and #8. Remap those marks to the panel UVs instead of repainting or inventing substitutes. Keep the atlas in sRGB; any added normal/roughness maps should be interpreted as data maps, not color textures. Add only subtle, scale-correct knit texture and roughness breakup so the fabric reads as sports polyester at close range without making the print noisy at broadcast distance.
5. **Make shorts a separate fitted garment.** Build a waist band and two shaped leg panels with clear inseams, side stripes, hems and the reference number placement. Keep a small gap above the legs to avoid z-fighting, but let the shorts follow the pelvis and upper-thigh deformation. Do not use a painted material boundary on the skin as the final shorts.
6. **Weight garments deliberately and test poses.** Start with body-surface weights sampled to garment vertices, then manually clean the shoulder, armpit, elbow and pelvis transitions. Normalize and limit the exported influences to four per vertex. Blender’s weight-paint tools include smoothing/normalizing operations intended to refine deformation [in the weight-paint manual](https://docs.blender.org/manual/en/latest/sculpt_paint/weight_paint/editing.html). Inspect shirt and shorts together in neutral, jog, sprint arm swing, kick, turn, crouch and fall poses; do not accept a garment from a bind-pose render alone.
7. **Keep it game-ready for M1/16 GB.** Use skinned meshes rather than runtime cloth simulation for the match kit; share one material and atlas across the roster, avoid unnecessary transparent fabric, and combine compatible garment panels into a small number of surfaces after UV and weight validation. Measure full-match cost with the intended number of players and LODs before locking texture and triangle budgets.

### Priority for Shane’s next kit pass

1. Replace the ring-shell jersey with fitted, panel-based torso and sleeve geometry while retaining the supplied atlas artwork.
2. Resolve the shoulder/underarm seam and eliminate visible skin gaps in both neutral and moving poses.
3. Remap the sponsor, crest and stripes onto clean front/back/sleeve UV islands; compare against the source board at front, three-quarter and broadcast scale.
4. Build separate tailored shorts and refine socks/boots to match the kit sheet.
5. Re-render front, profile, back and posed deformation sheets, then rerun the Godot import test. Keep Shane out of the roster until the garment and animation checks pass.

### Fitted jersey improvement run (2026-10-17)

- Replaced the cylindrical jersey body and separate sleeve tubes with an offset outer shell extracted from the same MakeHuman body surface and using its existing skinning weights. This makes the torso profile follow the body more closely and removes the large tube-like silhouette.
- Fixed a parent-inverse scale error that had reduced the extracted shirt to 1/100 scale. Expanded face coverage at the collar/shoulder/armhole after the first render showed exposed wedges. The current shell contains 4,126 source faces and 4,228 vertices; export still reports 54,580 triangles, 65 bones and 15 actions.
- Updated fixed front and profile renders: `shane_denham_08_front.png`, `shane_denham_08_profile.png`; these views show better body fit and improved chest-panel layout than the previous ring shell. The UV shoulder blend experiment caused visible striping and was reverted to the uniform blue sleeve region.
- **Not approved.** The armhole/shoulder transition still has visible dark/skin gaps, the idle action deforms the body badly, shorts remain a body material region, and the character base/face still do not meet the reference. This is a measured garment prototype, not final clothing or animation validation. Keep it out of the roster; next fix should use a continuous licensed human base and purpose-built garment topology with explicit armhole seams, then retest in neutral, walking, sprint and kick poses.
- Validation: Blender 4.3.2 build/export succeeded; `python3 tools/run_smoke_tests.py shane_denham_import_smoke.gd` passes for GLB structure, textures and animation clips. This smoke test does not judge visual quality or runtime animation deformation.
- Follow-up diagnosis counted the jersey mesh boundary edges and tested alternate sleeve coverage/shoulder UV widths. Narrowing the sleeve selection made the exposed shoulder wedges larger; increasing the atlas width stretched the chest sponsor. Both experiments were discarded, and the broader sleeve region plus original chest UV widths were retained. The remaining artifacts need explicit fitted garment topology and panel UVs rather than more threshold tuning.

### Head sculpt and face UV pass (2026-10-17)

- Reworked `add_uv_head()` against the archived front and side portraits. The lower skull is broader through the jaw, the cheek plane is fuller, and the bridge/tip, brow, lip and chin have low-amplitude relief for a more readable profile. Removed the separate round ear spheres and formed subtle ear rims/conchae directly in the head surface. Reduced the hair cap height and raised/broke up its front hairline to follow the short crop in the sheet.
- Replaced the all-around lat-long portrait wrap with a front-projected face UV region registered from the chin to the front hairline. The temple, side and rear UVs sample the neutral skin field in the existing 1K atlas; the seam is at the back of the skull. The GLB keeps the same 65-bone rig and 54,580-triangle budget.
- Added a close profile portrait view to the Blender review script. Current evidence is `shane_denham_08_portrait.png` and `shane_denham_08_profile_portrait.png`; the source front/profile crop remains `references/source_uploads/chat_attachments/character_roster_sheets/1-69014.jpg`.
- **Still a likeness prototype, not approved.** The front likeness is recognizable but remains a photo registered to simple head topology rather than a fully sculpted face. The source has no clean side texture atlas, so the profile uses neutral skin and depends on the sculpt; the current profile is still too smooth and the head/neck intersection needs cleanup. No expression shapes or in-game close-up validation were added. Keep the asset out of the roster.
- Validation: Blender 4.3.2 build and GLB export succeeded; `python3 tools/run_smoke_tests.py shane_denham_import_smoke.gd` passes in Godot 4.6.3 for bones, textures and animation clips. This validates import structure only, not likeness or animation performance.

### Correction: remove portrait projection from the face (2026-10-17)

- The previous head pass still connected Shane's portrait albedo to the head material. That is the cause of the pasted-photo appearance, and it did not meet the requested geometry-led face work. Treat the portrait-projection notes above as a rejected historical iteration.
- Removed the portrait image from the head shader. The head now uses the licensed MakeHuman facial surface, localized reference-led shape edits, source eye forms, and integrated iris/pupil/catchlight geometry. Skin color and fine surface breakup are procedural; the portrait remains a modeling reference only. The head UV layer is retained for future hand-authored detail, with no face-photo pixels mapped onto it.
- Regenerated front and profile portrait renders. They confirm there is no pasted face image. The result is still a generic likeness prototype: jaw and lower-face proportions have been adjusted toward the sheet, but the hairstyle edge, mouth expression, face planes, head/neck transition, and overall likeness need further sculpting and review. **Not approved and not in the roster.**
- Validation correction from the subsequent full-character audit: the original smoke run used a stale Godot import. After editor reimport, the dedicated Godot 4.6.3 smoke test passes with **65 bones, kit atlas, core clips and 41,204 triangles**, agreeing with the actual GLB. The procedural skin does not export a base color, so baked portable maps remain required. Structural import success is not a likeness or gameplay-quality approval. Follow the current [face/body/kit plan](br022_shane_likeness_and_kit_plan.md) for the next work.

### Joint-fit foundation follow-up (2026-10-17)

- The subsequent [foundation pass](br022_shane_foundation_pass.md) replaces the heuristic body fit with native joint-landmark fitting, fixes the body/rig facing mismatch and weight normalization, aligns the footwear, and preserves the source library's 60-fps export timing. The head and body now share an explicit exportable skin base color, resolving the default-white issue described above.
- Current export: 37,716 triangles, 10 material surfaces, unchanged 65-bone rig and 15 existing action curves. Blender structural/pose/timing validation and the refreshed Godot asset smoke test pass. Detailed likeness, garments, animation content and in-game quality remain unapproved; consult the new report for current gaps rather than treating these historical prototype logs as the latest state.
