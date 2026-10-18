# Shane Denham: likeness and deformation cleanup

2026-10-18. **BR-022, item 22 of 25 — corrective pass implemented; overall character production remains in progress.** This supersedes the current-asset description in the [earlier body/face/kit pass](br022_shane_body_face_tailored_pass.md). The source and GLB remain prototypes pending final likeness, gameplay and target-hardware acceptance.

## What changed

Used the project `create-player` workflow and the repository character, rigging, retopology, hair, UV, material, realism and Godot export guides through headless Blender 4.3.2. Inspected real mesh normals, deform weights, source bone poses, curves and imported Godot materials. Original player/kit sheets, the production rig and the shared animation-library file were preserved.

### Face, skin and hair

- Adjusted the actual nose tip/bridge/alar volume, mouth width, brow ridge, eye spacing, lower jaw and neck taper using smooth local geometry fields. Reduced the overly square jaw and thinned the lower lip with the archived anatomical target. These are artist fitting controls inferred from the front/profile sheets, not factual measurements of the player.
- Changed the green iris cast to brown/hazel on the curved eyeballs.
- Added a clean **CC0 MargaretToigo skin base**, resampled through the original MakeHuman anatomical UV islands into the 2K head and 512 body maps. Bounded pigment tuning, registered lips/brows and a separate 1K pore/crease normal map supplement it. This is skin source art; facial identity still comes from geometry/reference matching. No flat portrait, pasted eye/teeth image or face card is attached to the model.
- The source/CRC/SHA256/license evidence is archived in `references/third_party/makehuman/skin_toigo/`. The earlier Aksel comparison contained painted injuries and is explicitly marked rejected; it is not connected to the final material.
- Replaced the large opaque clumps with **168 strand-textured cards and an opaque root layer**, using one alpha-tested `MASK` material. Buried roots, consistent winding, matching pigment and scalp-derived custom normals reduce the appearance of separate flat plates. No runtime hair simulation or blended transparency sorting was added.

### Neck shading: a measured normal fault

The duplicated head/body boundary already matched in position, but its normals differed by a mean of **171.55°**, with a maximum near **177°**. Recalculating the open skin pieces independently had reversed body islands. The builder now orients each island against the closed anatomical surface and reconciles shared shading normals after covered skin is removed. The current source check measures under **0.005°** of boundary normal mismatch.

This is distinct from texture overlap: inspection confirmed the head/body pigment bakes were already separate. Texture samples did not support the initial overlap hypothesis.

### Shorts, hem and the underlying retarget problem

The old shorts inherited body creases and crossed their inner-leg surfaces during inflation. Shin influence was negligible; it was not the main cause of the bulge. The final shorts use a clean **1,015-vertex / 944-quad** pattern with a shared waist, saddle crotch, two leg loops and folded open hems. Cross-sections follow the fitted body with cloth ease. Waist weights follow the anatomical surface; lower loops follow the appropriate thigh. The UV front width now matches the garment so the manufacturer mark is not clipped at the side.

More importantly, inspecting the source idle revealed about **125.13° of axial thigh rotation** despite a plausible knee path. This retarget/bind mismatch twisted the human mesh and trousers; changing frame rate or adding cloth vertices could not repair it.

`shane_leg_retarget.py` now bakes corrected rotations for **Left/Right UpLeg, Leg and Foot** into the prototype's copies of the 15 existing actions. It preserves the hip/knee/ankle paths and foot orientations at the authored 60-fps samples. It adds no IK, bones, runtime solver, gameplay change or new move. Other animation curves and the source library remain unchanged. Pose state is reset between clips so unkeyed properties cannot leak from the previous action; the routine also preserves genuinely unkeyed lower-body layers.

The jersey hem now follows the pelvis, fading back into the original torso weights above it. This removes the leg influence there; the final captures still show an uneven lower edge and collar/sleeve defects, so the garment is not visually accepted.

## Evidence and validation

- **65 production bones:** rest matrices, endpoints and parents unchanged.
- **15 action names/durations:** retained at 60 authoring fps. All curves outside the six documented leg-rotation tracks remain identical to the source.
- **741 authored samples:** the retarget report verifies contact paths and foot orientations. Largest measured joint-path error is below **0.00004 cm**; measured foot-orientation discrepancy stays below **0.056°**. These are sample comparisons, not a claim of continuous subframe identity.
- Independent validation compares the exported-source poses against a separate source armature at 45 probes, checks finite evaluated meshes, shared neck positions and source action timing.
- Normalized skin weights, at most four positive influences per vertex; no collapsed kit UV triangles, no printed chest faces sampling the plain trim region, and no lower shorts vertices crossing their anatomical side in rest pose.
- Completed actual Blender neutral front/profile/back/three-quarter, clay head and existing idle/sprint/shot frame captures. The Godot 4.6.3 import smoke passed, including the alpha-scissor hair material. Fresh Web idle/portrait captures reached the first-draw marker with no browser page errors. Passing these structural checks is not likeness approval.

Machine-readable reports: [source/GLB validation](br022_shane_foundation_validation.json), [leg retarget](br022_shane_leg_retarget.json), [texture budget](br022_shane_texture_budget.json).

Review images:

- [Front](shane_denham_08_neutral_front.png), [back](shane_denham_08_neutral_back.png), [profile](shane_denham_08_neutral_profile.png).
- [Face](shane_denham_08_neutral_portrait.png), [face profile](shane_denham_08_neutral_profile_portrait.png).
- [Untextured head](shane_denham_08_clay_nohair_neutral_portrait.png), [untextured profile](shane_denham_08_clay_nohair_neutral_profile_portrait.png).
- [Idle frame 44](shane_denham_08_idle_f44_front.png), [sprint](shane_denham_08_sprint_f10_front.png), [shot](shane_denham_08_shotright_f18_profile.png).
- [Godot posed asset](shane_godot_web_idle.png), [Godot face](shane_godot_web_portrait.png). These are isolated asset views using the match light/environment, with park dressing omitted for software WebGL. They are not Mac or full-match captures.

## Performance

The current export contains **51,022 triangles and six material surfaces**, down about **20%** from 63,726 triangles in the preceding pass. The GLB is approximately **11 MB**. The conservative uncompressed RGBA8 texture estimate, including mip chains, is **57.33 MiB**; it is not measured GPU residency. The original CC0 skin image is outside the runtime asset tree and only the baked maps are exported.

All fitting, normal repair, hair construction, texture transfer and rotation correction happen offline. Runtime still uses the existing skeleton and ordinary baked animation. Alpha-tested hair trades some pixel/shadow cost for fewer triangles; a cap-only distant LOD and smaller distant skin maps are lighter alternatives. Confirm LOD transitions and measured frame times on M1 Pro/16 GB at 1080p before claiming steady 60 fps.

## Remaining acceptance

The face/hair remain a reconstruction requiring closer artistic comparison with the sheets, especially the eye/brow contours, cheek-to-mouth planes, hairline and fine strand flow. Do not label the asset an exact or approved AAA likeness. The captures also expose jagged collar/shoulder edges, an abrupt sleeve join and an uneven jersey hem; a clean garment silhouette is a remaining blocking art check. The existing upper-body motion also has awkward silhouettes; this retarget pass preserves those paths and does not claim to reanimate them.

Before roster integration:

1. Check complete clips, including turns, slide/get-up and action blends, for cloth/body intersections and visible flips. Still probes do not establish every frame's appearance.
2. Verify the final mesh in the gameplay AnimationTree: blend transitions, root-motion policy, boot/ball contacts, keeper/opponent interaction, culling and broadcast mip/LOD behavior.
3. Replace blanket team-tint overrides with kit-specific material handling before introducing the merged character; eyes, hair and skin must retain their own materials.
4. Profile the actual 4v4 scene and a 22-character load on the target Mac. Hardware acceptance remains pending.

**Next:** BR-022 (22/25) stays in progress. Use the fixed reference/asset views for the remaining likeness decision, then validate full gameplay blends/contact before expanding the roster. Carry the tested leg calibration into the shared roster pipeline only after that integration check.

## Reproduce

From repository root:

```sh
python3 tools/blender/beechlawn/build_shane_tailored_textures.py
timeout 180s blender -b --python-exit-code 1 --python tools/blender/beechlawn/build_shane_denham_player.py
timeout 60s blender -b --python-exit-code 1 --python tools/blender/beechlawn/validate_shane_foundation.py
timeout 130s blender -b --python-exit-code 1 --python tools/blender/beechlawn/render_shane_denham_review.py -- --neutral
timeout 100s blender -b --python-exit-code 1 --python tools/blender/beechlawn/render_shane_denham_review.py -- --motion-check
timeout 90s blender -b --python-exit-code 1 --python tools/blender/beechlawn/render_shane_denham_review.py -- --neutral --face-views --clay --no-hair
timeout 60s godot --headless --editor --path games/beechlawn_rovers --import
python3 games/beechlawn_rovers/tools/run_smoke_tests.py shane_denham_import_smoke.gd
timeout 180s python3 games/beechlawn_rovers/tools/build_shane_review_web.py /tmp/beechlawn-shane-review
timeout 110s python3 tools/capture/capture_beechlawn_web.py games/beechlawn_rovers/docs/art_briefs/shane_godot_web_idle.png --web-root /tmp/beechlawn-shane-review --query 'pose=idle&frame=44' --ready-expression 'window.BEECHLAWN_REVIEW_READY === true' --wait 1
```

The editable source is repository-root `tools/blender/beechlawn/shane_denham_08.blend`; the runtime export is `assets/characters/_prototypes/shane_denham_08_prototype.glb`. Pre-pass source and matched images are preserved under `tools/blender/beechlawn/archive/shane_before_likeness_cleanup_20261018.blend` and `docs/art_briefs/shane_before_likeness_cleanup_20261018/`.
