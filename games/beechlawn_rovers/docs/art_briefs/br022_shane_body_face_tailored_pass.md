# Shane Denham: body, face and tailored-kit pass

2026-10-18. **BR-022, item 22 of 25: in progress.** The editable Blender source and exported prototype have changed. This is a documented implementation pass, not approval of reference likeness, finished AAA art, animation quality or target-Mac performance. The gameplay roster still uses its existing proxy.

The [subsequent likeness/deformation cleanup](br022_shane_likeness_cleanup.md) supersedes the current-asset counts and unchanged-animation claim below. This report records the preceding 63,726-triangle iteration; the linked validation JSON and root review images now track the latest export.

## References and tools

Applied the project `create-player` workflow and the repository Blender director, character, realism, rigging, hair, UV, materials and Godot export guides through actual headless Blender 4.3.2/bpy work. Godot 4.6.3 imports and a Chromium WebGL capture inspect the exported asset; there is no Blender MCP connection or generated-image substitute for these renders.

The [Shane plan](br022_shane_likeness_and_kit_plan.md) records the archived source paths and conflicts. Shane's personal sheet supplies identity, face/build and long sleeves. The shared kit board supplies the selected crest, Uhlsport, Thomas Loomes & Co, blue/black garment construction, black shorts and blue socks. The owner's **S. DENHAM / 8** instruction supersedes the kit board's example MURRAY / 5. Original references and licensed source anatomy remain untouched.

## Changes made directly in Blender

| Area | Before | Current change |
| --- | --- | --- |
| Body/head | Long lower face/neck relationship, narrow torso, large fingertips. | Continuous compact-head shaping, slightly broader head/cheeks, fuller torso/waist and restrained fingertip shortening. The rig's rest matrices and source action keys are preserved. These are visual fitting controls, not inferred biometric facts. |
| Face | Generic macro anatomy with little individual fitting. | Seventeen archived CC0 anatomical targets adjust head shape/age, chin, nose, mouth width/corners, lids and under-eye form. Local cheek/jaw fields supplement the source targets. Individual facial likeness still falls short of the sheet. |
| Eyes | Separate frontal iris/pupil discs protruded in front of the lids. | Remove those discs; paint iris/pupil detail on the actual curved eyeballs. Preserve source eyelid topology and head binding. Eye color, lid detail and expression still need reference refinement. |
| Skin | Plain/fallback material; historical portrait atlas produced the rejected pasted-face effect. | Separate 2K anatomical head UV allocation, 512 body pigment map, restrained baked micro-normals and portable PBR materials. No portrait image is connected to the active head. Pigment is authored in anatomical regions, without baked scene lighting. This is not a completed photographic skin treatment. |
| Hair | Smooth scalp shell. | Scalp fitted to the head plus 1,000 opaque tapered short clumps and baked strand detail. No runtime groom or transparency sorting. The silhouette and flow remain too uniform for final approval. |
| Jersey | Helper fit test, jagged cut boundaries and inadequate panel registration. | Continuous body-derived shoulder/sleeve surface, cut boundaries, cuffs/hem, subtle offline drape and a binding following the actual neckline loop. Front chest gets a loose envelope instead of copying tight pectoral cavities. The resulting surface still needs more deliberate cloth topology and folds. |
| Shorts/socks | Helper placement and skin/clothing intersections. | Longer loose shorts with open legs, waistband/hem treatment; calf-shaped blue socks with cuffs and boot overlap. Covered skin is culled in final fitted coordinates. Sparse pose checks do not establish complete deformation coverage. |
| Kit artwork | Earlier 1K wrap layout and small sponsor. | Dedicated 2K front/back/sleeve/short/sock/trim charts, original supplied crest/manufacturer/sponsor, larger sponsor, S. DENHAM and chamfered eight. Baked knit normals/roughness replace Blender-only fabric nodes. |

Root causes corrected during this pass:

- Open clothing inherited inward normals, putting the apparent loose shorts inside the thighs. Clearance now uses the closed anatomical body's outward surface; connected garment components are oriented consistently.
- Nearest-surface rebinding could cross the inner-thigh gap. The garments now retain the original anatomically corresponding weights interpolated during cutting/subdivision, then normalize/prune to four influences.
- Generic heat weights also reached too far down the chest: some sponsor-region vertices carried roughly 15% upper-arm influence. The shirt now fades out upper-arm influence below the axilla, preserving the ribcage/shoulder blend and normalizing the result.
- Edge-on atlas projections produced zero-area UV triangles and undefined normal-map tangents. Plain cut-edge faces receive valid fabric UVs. Sixteen edge-on chest faces had incorrectly been sent to plain black, cutting into the sponsor: printed-panel repairs now preserve the original local artwork sample instead.
- Moving only the collar boundary into a V inverted its neighbouring rows. The V influence now falls off through the adjacent rows. The binding follows the real cut loop; its shared winding is reconciled before smooth shading.
- The disposable Godot review pose initially used Blender bone names and axes. Godot imports the colon as an underscore and converts the armature coordinates. The review uses imported names/axes; it does not edit any animation.

## Validation and actual evidence

- Compared all **65 bones** and **15 existing actions** against the original library: rest matrices, parents, endpoints, keys, handles and interpolation unchanged.
- Preserved **60 fps authoring** and checked exported action durations against their source ranges. Authoring FPS does not establish rendered frame rate.
- All used source vertices retain normalized weights and at most four positive deform influences.
- **45 structural pose probes** cover beginning/middle/end samples across the existing actions: finite geometry and coincident duplicated head/body seam (30 shared vertices).
- No zero-area cloth UV triangles; the head's actual 2K pigment map is attached and no historical portrait overlay is attached.
- Current export: **63,726 triangles, six material surfaces**, approximately **9.24 MB** GLB. See the [checksum-bearing validation](br022_shane_foundation_validation.json).
- Fixed Blender neutral front/profile/back/three-quarter/face views and three existing-clip poses are rendered. These are appearance checks beyond the structural tests.
- Godot import smoke checks inspect the actual skeleton, meshes, materials, clips and shot duration. The disposable Web asset-review scene provides close visual inspection without changing the production main scene or roster.

Render links:

- [Blender front](shane_denham_08_neutral_front.png), [profile](shane_denham_08_neutral_profile.png), [back](shane_denham_08_neutral_back.png).
- [Blender face](shane_denham_08_neutral_portrait.png), [face profile](shane_denham_08_neutral_profile_portrait.png).
- [Idle frame 44](shane_denham_08_idle_f44_front.png), [sprint frame 10](shane_denham_08_sprint_f10_front.png), [shot frame 18](shane_denham_08_shotright_f18_profile.png).
- [Godot Web front](shane_godot_web_front.png) and [face](shane_godot_web_portrait.png). Web review shares the match light/environment and grass shader; software rendering omits the expensive surrounding park dressing. This is an isolated asset capture, not normal gameplay or Mac-renderer parity.

## Remaining visual gaps and acceptance

The face is still too generalized: brow/orbit, nasal tip/alar shape, mouth/chin transitions, eye treatment and skin detail need further paired front/profile fitting. Hair needs a more natural taper, hairline and directional breakup. The uniform remains too smooth and body-derived; front artwork is still visibly disturbed in parts, and sleeve/shorts deformation and neckline/neck shading finish need focused cleanup. Boots remain a simple foundation. Do not label this a perfect or AAA match.

The existing idle/sprint/shot pose renders also expose awkward inherited arm silhouettes, floating/angled feet and cloth distortion. Structural pose probes can pass while these appearance defects remain. Animation polishing belongs under BR-003/BR-021; no football simulation or recovery logic was changed here.

### Lightweight asset/mannequin checks

- [x] Bone/action preservation, export duration and normalized four-weight checks.
- [x] Shared neck continuity and finite geometry at the 45 recorded probes.
- [x] Actual front/profile/back/portrait and selected idle/sprint/shot renders.
- [ ] Face/hair visually match the personal sheet in clay and textured views.
- [ ] Garment contours, front artwork, collar and hems remain clean in every frame of idle, jog, sprint, pass, shot, turn, crouch, slide and get-up.
- [ ] Feet remain planted where intended; no sleeves/shorts intersect skin or invert. Sparse stills do not check this fully.

### Final Godot gameplay checks

- [ ] Integrate only after visual/motion approval; replace blanket team-tint overrides with material-specific kit handling so eyes, hair and skin retain their appearance.
- [ ] Verify AnimationTree blend spaces, action transitions, scale/rotation and root-motion policy with the final mesh.
- [ ] Check boot-to-ball contact heights, pass/shot markers, receiving, goalkeeper interaction and opponent collisions in the actual pitch scene.
- [ ] Compare close/broadcast camera appearance and mipmaps; ensure back name/eight and front marks remain legible.
- [ ] Profile real 4v4 and 22-character loads on M1 Pro/16 GB at 1080p: frame-time distribution, CPU animation/skinning cost, GPU shadows and texture residency. Mac acceptance remains open.

## Runtime cost and lighter options

Fitting, cloth smoothing, morph fitting, UV repair, hair construction and baking run offline. Runtime adds no cloth solver, extra IK, high-poly gameplay collider or new bones. The source uses 63.7k triangles and six surfaces; those still cost skinning/draw work. The [texture budget](br022_shane_texture_budget.json) estimates **52.33 MiB** with full mip chains if every image were uncompressed RGBA8, not measured GPU residency. Imports/compression and shared kit resources affect actual usage.

For broadcast distance use imported mesh LODs and reduced distant hair geometry; share the team atlas, reduce body/eye/normal sizes where no visible difference is measured, and avoid unique complete kit copies per player. Profile before selecting final LOD distances or claiming a steady 60 fps.

## Reproduce

From repository root, with failure exit codes and deadlines:

```sh
python3 tools/blender/beechlawn/build_shane_tailored_textures.py
timeout 120s blender -b --python-exit-code 1 --python tools/blender/beechlawn/build_shane_denham_player.py
timeout 60s blender -b --python-exit-code 1 --python tools/blender/beechlawn/validate_shane_foundation.py
timeout 120s blender -b --python-exit-code 1 --python tools/blender/beechlawn/render_shane_denham_review.py -- --neutral
timeout 100s blender -b --python-exit-code 1 --python tools/blender/beechlawn/render_shane_denham_review.py -- --motion-check
timeout 60s godot --headless --editor --path games/beechlawn_rovers --import
python3 games/beechlawn_rovers/tools/run_smoke_tests.py shane_denham_import_smoke.gd
timeout 180s python3 games/beechlawn_rovers/tools/build_shane_review_web.py /tmp/beechlawn-shane-review
timeout 110s python3 tools/capture/capture_beechlawn_web.py games/beechlawn_rovers/docs/art_briefs/shane_godot_web_front.png --web-root /tmp/beechlawn-shane-review --ready-expression 'window.BEECHLAWN_REVIEW_READY === true' --wait 1
```

Editable source: repository-root `tools/blender/beechlawn/shane_denham_08.blend`. Runtime export: `assets/characters/_prototypes/shane_denham_08_prototype.glb`. The pre-tailoring source is retained in `tools/blender/beechlawn/archive/`.

**Next:** continue BR-022 (22/25) with the face/hair likeness and garment appearance gate, using these fixed comparison views, before any active-roster replacement. BR-025 target-Mac performance acceptance remains pending separately.
