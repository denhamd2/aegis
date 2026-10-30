# BR-022 original-photo landmark fit, 29 October 2026

Status: **in progress; likeness and release gates remain open**. This is a
source/export checkpoint for the six saved hero heads. The currently published
Mac build is v0.5.10 / CFBundleVersion 21.

## Reference and implementation

The six archived original portraits remain the identity authority: Shane
Denham, John O'Rourke, Boardeaux player Des Feeney, referee Des Feeney Sr.,
Robbie Roden and David Murray. The owner confirmed that `70467.jpg` depicts
Robbie. `measure_player_portraits.py` now measures all six with the MediaPipe
Face Landmarker and records photo/model hashes and crops in
[`photo_landmark_fit.json`](../../../../../tools/blender/beechlawn/head_pipeline/photo_landmark_fit.json).
The official local task model is an offline authoring dependency, not a game
dependency. Its SHA256 is recorded with the measurements.

[`fit_six_portraits.py`](../../../../../tools/blender/beechlawn/fit_six_portraits.py)
fits symmetric face/jaw/nose widths and feature heights with bounded fields.
It edits each saved neutral and expression cage, then records sculpt deltas
against the unchanged shared master. The 65-bone rig, skin weights, UVs and
protected neck vertices remain unchanged. Smiling photo mouth dimensions are
applied only to the Smile shape for Robbie and David; the first neutral-mouth
attempt looked strained in native renders and was corrected before this
checkpoint. The previous separate mouth-opening prototype also looked worse
and is absent from these sources and exports.

Normal and close-up GLBs plus six fitted grooms were rebuilt. The Boardeaux
player head still serves its existing fixture aliases; the referee remains a
separate identity. No shared body, wrestling asset or Web build changed.

## Measured and visual result

The [before/after Blender fronts](blender/) use the same camera and light.
[`fit_metrics.json`](fit_metrics.json) records each photo, original render and
fitted render hash and the seven normalized metrics. Across 36 selected
face/jaw/nose/feature-height checks, 23 move closer to the portrait. Mean
absolute error falls from 0.0766 to 0.0583 eye-distance units. The largest
remaining gaps are Robbie's jaw and David's chin. Single-angle photos cannot
prove the side profile, and a smiling mouth should not be treated as a neutral
target.

The [six imported native portraits](native/) are 1280×720 Godot Forward+
captures on Linux llvmpipe after an explicit GLB reimport. Source/export
[audit](export_audit.json) passes for all six heads, including lip winding,
saved geometry, materials, protected neck vertices and UVs. The imported
portraits show a modest structural gain, especially in Robbie's face width
and the referee's lower third. They still have generic eyes and mouth planes,
coarse groom flow and synthetic skin response. Numerical landmark improvement
does not establish recognisable 20/20 likeness.

The [geometry budget](geometry_budget.json) compares the same 18 GLBs with
the preceding checkpoint: 49 meshes and 67 surfaces in both; 484,144 to
484,160 triangles and 93,662,968 to 93,698,388 encoded bytes. These package
counts do not measure target GPU memory or frame time.

| Person | Current strict likeness /20 | Remaining gap |
| --- | ---: | --- |
| Shane Denham | 6 | Eye and smile planes; rigid crop |
| John O'Rourke | 7 | Beard and swept hair flow; eye anatomy |
| Player Des Feeney | 6 | Goatee, cheeks and expression |
| Referee Des Feeney Sr. | 4 | Age structure, moustache and skin |
| Robbie Roden | 5 | Warm open smile, real hair flow and jaw |
| David Murray | 6 | Eye anatomy, smile/teeth and lower-face length |

This is an art review score, separate from the numerical fit. A realistic
mouth cavity and fitted teeth, individual eyelid and cheek sculpt, stronger
photo-registered skin detail and groom direction still need a successful
visual pass. The failed oral trial was rejected instead of being released.
A separate [photo-detail pilot](rejected_photo_detail.png) projected high-pass
detail from Robbie's supplied portrait onto his facial UVs. The eye/nose
regions looked mottled and misregistered in Blender, so that pilot was also
excluded from the production source and GLBs.

## Validation and next acceptance

The source/export audit, [expression visibility audit](expression_fit.json),
and native neutral portraits passed. Robbie's newly fitted Blink initially
left 5.1% of his right eye exposed, just over the 5% source limit. A local
closed-lid correction brought it below that limit; its final native
[blink capture](native_blink/) and Robbie/David [smile captures](native_smile/)
are archived. The smiles are still visually inadequate as likeness work.

The serial `shared_head_roster_smoke.gd`, `recorded_face_replay_smoke.gd` and
`shared_roster_resources_smoke.gd` passed with their known cached-resource
exit diagnostic. The project
`build/` folder is excluded from Godot import with `.gdignore` because offline
Blender previews there caused an invalid Blender importer error and stale GLB
cache during the first capture. The first byte-identical captures were
discarded; the evidence above comes from reimported GLBs.

BR-022 (item 22 of 27) remains in progress until the six identities pass the
owner's likeness review. BR-025 (item 25 of 27) remains the next target-Mac
appearance and sustained 1080p60 check. Linux software Vulkan stills do not
establish M1 Pro appearance or frame time. No v0.5.11 Mac release is claimed.
