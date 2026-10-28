# BR-022: player body and face realism, 28 October 2026

Status: **in progress**. This is a four-pass production review of the six most
visible identities, not an exact-likeness or AAA sign-off. The earlier 70149
football screenshot supplies a smoother silhouette target, not a player
identity. Shane, John, player Des and referee Des have archived original
photos; Robbie and David have generated roster sheets only, so their unseen
profiles are estimates. The four original source-to-export identity audits
remain the likeness anchor. The 65-bone rig, motion clips, UVs, skin weights,
kit palette and 22-player/one-referee roster are retained.

## Four review passes

| Pass | Art direction and correction | Evidence |
| --- | --- | --- |
| 1 | Review skull, cheek and jaw volumes from front/profile; soften the repeated long, angular face. Add one skin-and-kit `AthleticForm` morph, shared by all players and the referee, to taper the boxy torso, thigh, arm, hand and toe silhouettes. | [Clay fronts and profiles](pass_1/), [body morph audit](../realism_finish/body_shapes.json) |
| 2 | Fit the eyelid aperture and eye globes together; adjust the lower orbital plane and referee brow. | [Clay fronts and profiles](pass_2/) |
| 3 | Refine nose projection, alar wing and lip volume; keep the mouth and neck vertex order intact. | [Clay fronts and profiles](pass_3/) |
| 4 | Re-bake anatomical skin/normal/roughness and individual grooms; add distinct Robbie/David heads and crops, review their native cheek and mouth silhouettes, then correct the over-broad Robbie profile. Soften the player Des side-hair band and the John/Des facial-hair density. | [Native four original faces](native_after/), [Robbie final review](native_final_robbie_profile/), [David final review](native_final_new_faces/) |

The head recipe is [refine_br022_faces.py](../../../../../tools/blender/beechlawn/refine_br022_faces.py).
Passes 1–3 have clay fronts/profiles for all six identities. Pass 4 was judged
in the actual Godot review scene, then revised where the first in-game render
exposed a broad Robbie mouth and rectangular player Des hair. The source
`.blend` and [head deltas](../../../../../tools/blender/beechlawn/head_pipeline/deltas/)
remain editable. The shared body recipe retains its neutral source and applies
the corrective at weight 1 while preserving the separate per-player Fullness.

## Art director scores

Subjective scores out of 20, at the same 960×540 native review camera. Body
scores assess the common athletic silhouette, hand scale, kit continuity and
moving deformation; face scores assess distinct form, features, groom and skin.
They are production triage scores, not a mathematical likeness metric.

| Identity | Body before → after | Face before → after | Main remaining gap |
| --- | --- | --- | --- |
| Shane Denham | 6 → 7 | 7 → 8 | Narrow shape changes; stiff hands and short crop. |
| John O’Rourke | 6 → 7 | 7 → 8 | Beard fibres, skin depth and eyelid finish. |
| Player Des Feeney | 6 → 7 | 5 → 6 | Sparse side hair and stubbly, uneven facial hair. |
| Referee Des Feeney Sr. | 6 → 7 | 6 → 6 | Moustache stippling and older skin anatomy. |
| Robbie Roden | 6 → 7 | 4 → 5 | Inherited wide oral form still reads stylized. No original photo. |
| David Murray | 6 → 7 | 4 → 6 | Receding crop and facial planes need an original photo. |

The common body is still visibly simple beside the supplied smooth football
example. These passes improve scale and continuity, but a substantial further
gain needs a new high-density anatomical body/kit source, better skinning at
shoulders and hips, and higher-quality groom cards. Face scores stay low because
the source face topology and short-hair rendering still read synthetic at
portrait distance. BR-022 stays open for those changes and original-photo
comparison; BR-025 remains the target-Mac visual/performance gate.

## Runtime and budget evidence

- [Before faces and full bodies](native_before/), [after bodies](native_body_final/),
  [sprint deformation](native_body_sprint/), [after match](native_match_final/).
  These are native Forward+ captures on Linux llvmpipe, not M1 rendering.
- The head and body exports keep one shared rig and mesh instances, 22 players
  and one official. Robbie and David each have their own head and crop; no new
  independent skeleton is created for every actor. [GLB geometry audit](geometry_budget.json)
  records 82,418,576 → 106,374,332 bytes across the 19 changed/new packages.
  The shared body package changes from 25,184 to 33,454 mesh vertices and
  40,688 to 54,564 triangles because hands and boots now carry the corrective.
- At sunny Rovers Arena, 640×360 stationary kickoff, same llvmpipe adapter,
  the earlier [baseline](../p2_2026_10_28/budget/match_broadcast.json) was
  1,208 draw calls, 1,157,084 primitives and 4,311,156 KiB peak process RSS.
  The [new match report](native_match_final/match_broadcast.json) is 1,209 draw
  calls, 1,156,322 primitives and 4,389,656 KiB RSS. The +77 MiB process
  difference is a single-capture observation, not measured GPU residency or
  target-Mac frame rate. Turf triangles remain 32,768.
- The [four original head export audit](export_audit.json) checks source/GLB
  agreement, protected neck and lip triangles. BR-019's eight original clips
  still pass their 65-bone/60 Hz export audit. Serial `run_smoke_tests.py`
  checks cover the six resource identities,
  neutral morph/bind integrity, one shared body, sprint/pose safety, recorded
  facial replay restoration and roster isolation. Godot's known cached-resource
  exit diagnostic remains; there are no new script/shader failures in those
  tests. The Mac export and package verification are recorded by the release
  workflow after the validated commit.

## Transfer from the wrestling body review

The useful techniques are skin-weight-aware editing, checking normals and
silhouette at pose boundaries, and testing the actual imported rig under
motion. Wrestling-scale muscle bulk, costume texture maps and its hair budget
do not describe footballers in kits. No wrestling source or build was changed.

## Next acceptance

Review the packaged v0.5.9 universal Mac build on the M1 Pro/16 GB target:
portrait and broadcast appearance, body deformation during sprint/contact,
and sustained combined-match 1080p60 frame timing. Linux software-renderer
captures do not establish these results.
