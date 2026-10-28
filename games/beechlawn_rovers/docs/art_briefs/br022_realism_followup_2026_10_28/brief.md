# BR-022 character realism follow-up, 28 October 2026

Status: production review in progress, starting from the published v0.5.9
source commit `e95590314348349e04d9bc4c0ac4916aec99c65a`. This brief uses
the [v0.5.9 six-character review](../br022_realism_2026_10_28/brief.md) as
its baseline. The fixed native [Shane front, kit and profile](native_before/)
views use 1280×720 Forward+ on Linux llvmpipe with the real roster asset.

## Reference and identity contract

The owner-supplied 70149 football screenshot sets a smoother playable body
target. The archived [Shane sheet](../../../references/source_uploads/chat_attachments/character_roster_sheets/1-69014.jpg)
shows front, side and back kit/body proportion; the original
[Shane portrait](../../../references/source_uploads/chat_attachments/shane_face_photo/69012.jpg)
is the face authority. The archived John, player Des and referee Des portraits
remain the other original face authorities. The newly supplied
[Robbie](../../../references/source_uploads/chat_attachments/br022_realism_followup/70467.jpg)
and [David](../../../references/source_uploads/chat_attachments/br022_realism_followup/70466.jpg)
photos are their primary face evidence. Both are smiling near-frontal social
screenshots; hidden side anatomy remains an estimate. Generated roster sheets
guide side/back shape and garments, not photographic texture projection.

All 22 players and the referee use one 65-bone body/kit rig and independent
playback. The shared source is `tools/blender/beechlawn/footballer_shared.blend`;
`build_body_fullness.py` exports body/kit morphs without rewriting that source.
The six selected individual heads remain saved sculpt deltas against master
revision `7a688a2e4bb86c1798369fb1d4d5ae7ce3a1a33585affc467604d1c68b2628c6`.
Player Des is `bordeaux_09`; referee Des is `des_feeney_sr`. Keep head/neck
interfaces, atlas UVs, per-player Fullness, body skinning, football action
clips and kit role graphics independent of any corrective sculpt.

## Priority gaps found in the native baseline

1. The shirt front extends to about 17.6 cm at y=110 cm while the upper chest
   reaches about 15.8 cm at y=130 cm in the source cage; the profile looks
   barrel-shaped beside the reference athlete.
2. Hands remain long and splayed in idle. The source wrist is near x=74 cm,
   while outer fingers extend toward x=95 cm. Sleeves read as straight tubes.
3. The shoulder/collar profile has a hard, dark interruption; shirt front and
   back still lack believable subtle cloth drape.
4. Facial forms still read generic in close native portraits; Robbie's mouth
   and cheek are especially broad. The original-face assets lack some portrait
   feature planes and high-quality skin variation.
5. Short hair, John's beard, player Des's goatee and the referee moustache
   contain fine isolated fibres that turn into visible dots at native portrait
   size. The source sheets show coherent masses and soft transitions.

Reviews will hold the same player/view/light/exposure between before and after
and inspect front, profile, kit, three-quarter portrait, sprint, turn,
slide/get-up and keeper poses before final export. Native target-Mac appearance
and 1080p60 performance remain BR-025 (item 25 of 27) acceptance work.

## Implemented source and in-game changes

- The shared `AthleticForm` morph tapers the abdominal shirt, sleeves,
  forearms, hands, thighs and boot toes continuously across kit and skin. The
  neutral body, 65-bone bind, UVs, action clips and independent `Fullness` stay
  intact. [Fixed-camera before](native_before/) and [body review](native_body_v2/)
  show a smaller waist and hands; the source remains visibly simple.
- `finish_br022_realism.py` refreshes six saved individual heads with bounded
  lids, mouth and cheek changes, then updates each source delta against the
  unchanged shared master. Robbie and David were adjusted against the original
  near-frontal photos. Robbie now has a short beard-shadow pigment; David's
  generated-sheet narrow lower face was widened to fit the original portrait.
  Hidden profile depth is estimated. Hairlines and hair/facial-hair strands
  were rebaked at sizes that survive the native portrait camera.
- A tooth-showing smile was tested for Robbie and David in
  [the rejected smile capture](native_photo_smiles/). The inherited oral mesh
  has no convincing cavity, so the teeth appeared clenched and the test was
  removed from the shipped GLBs. The saved `Smile` morph remains closed-mouth.
  The earlier Shane tooth geometry is unchanged.
- [Six-head source/export audit](export_audit.json) checks neutral geometry,
  protected neck and UVs, lip winding and fitted materials. It also rejects
  accidental Robbie/David tooth meshes. [Changed GLB budget](geometry_budget.json)
  includes source and exported geometry counts. The groom rebake reduced the
  aggregate changed-package size despite the body correction.

## Art director review

These are subjective production scores out of 20 at the same native Forward+
review distance. Body is the shared athletic silhouette; face scores include
likeness, expression, skin and groom. The previous review scores are retained
as the baseline. The originals for Robbie and David add stronger evidence and
expose mismatches that their generated sheets could not show.

| Identity | Body v0.5.9 → now | Face v0.5.9 → now | Unresolved visual gap |
| --- | ---: | ---: | --- |
| Shane Denham | 7 → 8 | 8 → 8 | Short rigid crop, mouth and collar silhouette |
| John O’Rourke | 7 → 8 | 8 → 8 | Hair/beard clumping and eye anatomy |
| Player Des Feeney | 7 → 8 | 6 → 6 | Sparse side groom and isolated goatee fibres |
| Referee Des Feeney Sr. | 7 → 8 | 6 → 6 | Moustache fibres and older facial planes |
| Robbie Roden | 7 → 8 | 5 → 6 | Original-photo eye, smile and beard realism |
| David Murray | 7 → 8 | 6 → 7 | Original-photo eye, smile and receding hair realism |

The [six native head review](native_final_heads/) uses 1280×720 Forward+ on
Linux llvmpipe. Its Robbie frame includes a rejected fine-fibre stubble trial;
the final pigment-only Robbie frame is in `native_final_robbie/`. The 20/20
target remains open. A new anatomical body/garment source with better shoulder
and hand deformation, expressive oral topology, portrait-specific sculpt and
higher-quality directional hair/skin work are necessary before a credible
close-up sign-off. Front-only Robbie/David photographs cannot establish exact
profiles. BR-025 (25/27, in progress) still owns packaged target-Mac appearance
and sustained 1080p60 measurement.

The [sprint frame 15 front/profile](native_motion_sprint/) checks the revised
shirt, forearm, hand, thigh and boot morph under a non-neutral 65-bone pose;
the collar and hand pose still need source-level work. A [sliding frame](native_motion_slide/)
checks the same shared mesh during ground contact.
The [validation manifest](validation.json) records seven serial Godot smoke
passes for roster isolation, source imports, bind/pose safety and recorded face
replay. The known cached-resource exit message appeared in three checks; no
new script or shader error occurred. The eight BR-019 animation exports retain
their 65-bone rest and 60 Hz contact audit.

## Rendering and budget check

The 19 changed GLBs total 106,374,332 bytes at v0.5.9 and 96,926,120 bytes
here, an 8.9% decrease, mostly from reduced groom fibres. The shared body
package is 33,807 vertices and 54,740 triangles after its revised morph.
At the same sunny Rovers Arena stationary kickoff, 640×360 Forward+ llvmpipe
[v0.5.9 match capture](../br022_realism_2026_10_28/native_match_final/)
recorded 1,209 draw calls, 1,156,322 primitives and 4,389,656 KiB peak
process RSS. The [current match capture](native_match/) records 1,209 draw
calls, 1,158,202 primitives and 4,379,964 KiB peak RSS. This is a single
software-renderer comparison; RSS is process memory, not GPU residency or an
M1 Pro frame-rate measurement.
