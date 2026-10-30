# BR-022 five further likeness studies, 30 October 2026

Status: **five preview rounds completed; 20/20 likeness not achieved**. These
are isolated Blender studies of the six saved hero heads. None passed the
reference-led visual gate for promotion into the game. The game sources,
sculpt deltas, GLBs, materials and Mac release remain at the 29 October
checkpoint. The owner-provided photographs are the identity authority; see
the [six-person photo and native baseline review](../br022_landmark_fit_2026_10_29/brief.md).

## What was tried

All comparisons use the same 640 × 640 Eevee camera, lighting and neutral
face unless explicitly marked Smile. The linked PNGs are review evidence,
not native Godot captures. Each pilot ran under Blender 4.3.2 with a 180 s
process deadline and exited successfully. The absolute RGB pixel difference
below measures whether the image changed; it is **not** a likeness score.

| Round | People / edit | Result against the supplied photo | Mean RGB change /255 | Decision |
| --- | --- | --- | ---: | --- |
| 1 | Robbie, David and referee Des Sr.; lower chin and narrower jaw | David acquired a visibly stretched, angular chin; Robbie's lower face remained generic. The protected neck vertices, shape keys and weights survived, but form worsened. [Robbie before](comparisons/robbie_baseline_front.png) / [after](comparisons/round1_robbie_front.png), [David before](comparisons/david_baseline_front.png) / [after](comparisons/round1_david_front.png). | 0.72 Robbie; 0.80 David | Reject |
| 2 | Robbie; wider raised mouth corners and cheeks in Smile | The [baseline Smile](comparisons/round2_robbie_baseline_smile.png) and [edited Smile](comparisons/round2_robbie_smile.png) both read as closed-mouth frowns. The photo shows a broad open smile with visible teeth. | 0.21 | Reject |
| 3 | Robbie; thin-plate-spline registered cheek and forehead photo detail | The [detail preview](comparisons/round3_robbie_skin.png) differs barely from the [baseline](comparisons/robbie_baseline_front.png) and cannot correct eye, mouth or nose structure. The earlier broader photo projection mottled and misregistered those features; this bounded version avoided that artifact but added no meaningful likeness. | 0.07 | Reject |
| 4 | Robbie; raised frontal hairline and flattened, swept fibres | [Front](comparisons/round4_robbie_groom_front.png) and [three-quarter](comparisons/round4_robbie_groom_threequarter.png) previews reduce the helmet height. The transition remains too straight, and the unaltered scalp pigment ends at the old hairline. It needs a matching skin-map rebake and native review before use. | 2.15 | Hold as a groom study |
| 5 | Robbie and David; 28% neutral Blink to narrow the eyelid opening | [Robbie](comparisons/round5_robbie_lids.png) and [David](comparisons/round5_david_lids.png) look sleepy, with the same generic eye structure. Their photographs show distinct upper lid folds and smiling cheeks, not a partial blink. | 0.17 Robbie; 0.12 David | Reject |

The original references for the new identities are [Robbie Roden](../../../references/source_uploads/chat_attachments/br022_realism_followup/70467.jpg)
(identity confirmed by the owner) and [David Murray](../../../references/source_uploads/chat_attachments/br022_realism_followup/70466.jpg).
The two are smiling in the photos. A neutral-mouth measurement cannot replace
a real expression sculpt or establish a matching smile.

The pilots are preserved as
[`pilot_round1_lower_face.py`](../../../../../tools/blender/beechlawn/pilot_round1_lower_face.py),
[`pilot_round2_smile.py`](../../../../../tools/blender/beechlawn/pilot_round2_smile.py),
[`pilot_round3_skin.py`](../../../../../tools/blender/beechlawn/pilot_round3_skin.py),
[`pilot_round4_groom.py`](../../../../../tools/blender/beechlawn/pilot_round4_groom.py)
and [`pilot_round5_lids.py`](../../../../../tools/blender/beechlawn/pilot_round5_lids.py).
Round 3's archived [crop](inputs/robbie_reference_crop.png) and
[landmark coordinates](inputs/robbie_landmarks.json) make that rejected
registration study reproducible without the ignored build directory. The
pilots write editable sources and/or renders into `build/`, never to the
shipping asset directories. Re-running round 3 from those archived inputs
produced pixel-identical RGB output to the saved comparison PNG (the PNG file
hash differs because of encoding metadata).

## Art-director scores after the five rounds

| Person | Likeness /20 | Blocking visual differences |
| --- | ---: | --- |
| Shane Denham | 6 | Generic eyes and smile; rigid crop |
| John O'Rourke | 7 | Beard and swept hair flow; eye anatomy |
| Boardeaux player Des Feeney | 6 | Goatee, cheeks and expression |
| Referee Des Feeney Sr. | 4 | Older facial structure, moustache and skin |
| Robbie Roden | 5 | Closed frown versus photographed open smile; hairline and jaw |
| David Murray | 6 | Eye folds, open smile and lower-face structure |

The scores remain the strict 29 October scores because no candidate passed.
Calling any of these heads 20/20 would misrepresent the visible comparison.
The main blocker is the inherited mouth and eye topology: parameter nudges on
the current closed-mouth head cannot reproduce the photographed oral opening,
upper teeth, cheek compression and individual eyelids. One near-frontal photo
per person also leaves unobserved profile depth and expressions.

## Acceptance path

BR-022 is item **22 of 27, in progress**. A credible next production pass is a
mouth-capable head source with an actual cavity, upper dental arcade and
well-ordered lip loops; then individual eyelid/cheek sculpt, matching skin and
hair maps, expression checks, source/export audits, and imported native
Forward+ portraits for all six. Independent side and three-quarter reference
photos would be needed to judge a strict 20/20 all-angle match. The source
must keep the existing 65-bone rig, UVs/weights and neck seam or transfer them
explicitly; the whole match must still meet its asset budget.

No candidate reached the native promotion gate, so no new Godot smoke run or
native capture is represented as validation of these pilots. The published
Mac build remains v0.5.10 / CFBundleVersion 21. BR-025, item **25 of 27, in
progress**, is the subsequent packaged target-Mac appearance and sustained
1080p60 acceptance; cloud software rendering cannot establish it.
