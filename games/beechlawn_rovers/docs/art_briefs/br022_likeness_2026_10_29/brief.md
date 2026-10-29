# BR-022 six-head likeness refinement, 29 October 2026

Status: **technical pass, visual finish open**. Baseline is published Mac
v0.5.10 at `a08bd13923edaafc1ec77880384863b01e9acc3f`. This is an
in-progress BR-022 source and export revision, not a 20/20 likeness sign-off.
BR-025 (25/27) still owns packaged target-Mac appearance and sustained
1080p60 measurement.

## Reference and identity contract

The archived [Shane portrait](../../../references/source_uploads/chat_attachments/shane_face_photo/69012.jpg),
original John and Des reference sheets, and owner-supplied
[Robbie](../../../references/source_uploads/chat_attachments/br022_realism_followup/70467.jpg)
and [David](../../../references/source_uploads/chat_attachments/br022_realism_followup/70466.jpg)
photographs are the face authorities. The owner confirmed that 70467 shows
Robbie Roden. Robbie and David have chiefly near-frontal smiling photographs;
their hidden side anatomy is estimated. Generated roster sheets guide kit and
back views but cannot override the photographs.

The six separate saved identities are Shane Denham, John O’Rourke, player Des
Feeney (`bordeaux_09`), referee Des Feeney Sr. (`des_feeney_sr`), Robbie Roden
and David Murray. The player Des export is used by all eleven Boardeaux
players; the referee uses its own head. All keep the common 65-bone body bind,
protected neck seam and UVs. The shared body and animation files did not
change in this pass.

## Four passes and outcome

1. **Face shape:** `refine_six_identity.py` changes individual cheek, jaw,
   nasolabial and lower-face forms, plus restrained asymmetry. The lower third
   received the largest adjustment for Robbie and David. Each saved source
   delta was regenerated against the unchanged shared head master.
2. **Eyes and expressions:** visible eyelid apertures were adjusted and the
   six Blink shapes refitted. Player Des now closes both eyelids in the source
   visibility audit. The existing Shane dental fit remains. A more open smile
   with new teeth for Robbie and David was built and captured in
   [the rejected trial](native_smile_rejected/); it read as clenched and boxy in native
   motion. Those mouth meshes and runtime changes were removed. The final
   exports keep the previous restrained smile shapes.
3. **Hair and skin:** Robbie has a shorter, finer crop with a less uniform
   hairline; David's fair receding temples are more explicit. Referee Des has
   a slightly fuller side groom and moustache. Player Des has a fuller goatee.
   Skin albedo, normal and roughness maps were rebaked after sculpt changes.
4. **Native review and correction:** the six final head details, including the
   corrected referee, are in [native_final](native_final/). All six also have
   [three-quarter and profile captures](native_angles/). These are actual
   1280×720 Godot Forward+ imports on Linux llvmpipe. Front and angle
   comparisons exposed continuing generic anatomy and plastic skin response.
   The rejected oral experiment was removed rather than entering a playable
   export.

## Art director likeness review

Scores below judge **recognisable likeness to the supplied person**, not just
technical mesh quality. They use the stricter likeness-only scale from the
previous owner review; the earlier combined face/skin scores used a different
rubric. The current neutral renders merit only small changes. No score is
20/20.

| Person | Earlier → current /20 | Main remaining visual gap |
| --- | ---: | --- |
| Shane Denham | 6 → 6 | Rigid crop, generic eye and mouth planes |
| John O’Rourke | 7 → 7 | Hair and beard clumping, eye anatomy |
| Player Des Feeney | 5 → 6 | Goatee, eye/cheek structure and expression |
| Referee Des Feeney Sr. | 4 → 4 | Older facial planes and moustache still look synthetic |
| Robbie Roden | 5 → 5 | Photograph’s warm smile, cheek fold and real hair flow |
| David Murray | 5 → 6 | Receding hairline improved; eyes, teeth and smile still wrong |

The [previous native head set](../br022_realism_followup_2026_10_28/native_final_heads/)
uses the same camera and lighting for a direct side-by-side. The head geometry
is sound, but likeness is not yet convincing in close-up. A dedicated mouth
opening/cavity and fitted dental arches, portrait-landmark sculpting of each
face, directional hair volumes and higher-quality skin projection are still
needed. Single-angle references cannot certify exact profiles.

## Technical and performance scope

[Six-head source/export audit](export_audit.json) checks the actual GLBs against
saved Blender geometry, protected neck UVs, frontal lip winding and materials.
[Expression fit](expression_fit.json) checks all twelve eyelids plus Shane's
neutral/smile dental visibility. The serial Godot roster, face replay and
resource smoke checks passed. Their previously known cached-resource exit
diagnostic is not a script or shader failure.

[Geometry budget](geometry_budget.json) compares all 18 changed normal/near
head and groom GLBs with v0.5.10: 49 meshes and 67 surfaces in both versions;
601,561 → 606,246 exported vertices and 481,945 → 484,144 triangles. Combined
compressed GLB bytes are 93,315,920 → 93,662,968. The triangle increase is
primarily the denser referee side groom/moustache. The same stationary Rovers
Arena [match capture](native_match/) reports 1,209 draw calls in both versions,
with 1,158,202 → 1,156,614 primitives and 4,379,964 → 4,370,860 KiB peak
process RSS. These are single Linux software-renderer readings; package bytes,
draw calls and RSS do not establish GPU residency or M1 Pro frame time.

Delivery remains **in progress** until the six likenesses pass a new visual
review and BR-025 completes target-Mac verification. The current captures
support a source checkpoint; they do not justify claiming a finished 20/20
release.
