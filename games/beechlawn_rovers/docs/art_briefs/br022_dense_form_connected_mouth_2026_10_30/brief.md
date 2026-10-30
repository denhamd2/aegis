# BR-022 dense form and connected mouth study, 30 October 2026

Status: **no candidate passed the art gate**. The six shipping heads, their
normal/near GLBs, and the Mac package remain at the last accepted checkpoint.
The owner asked to approximately double the strict likeness scores. This
study tested a stronger photo-landmark form fit for all six identities and a
connected mouth surface for Robbie Roden and David Murray. Neither produced
the requested improvement.

## Form fit

The original photos and current saved-head front renders were measured with
the offline MediaPipe Face Landmarker. The reproducible tool is
[`measure_player_portraits.py`](../../../../../tools/blender/beechlawn/measure_player_portraits.py);
the [bounded bilateral sculpt pilot](../../../../../tools/blender/beechlawn/pilot_br022_dense_form.py)
uses paired contour, brow, eye, nose and mouth landmarks. It excludes the
smiling-photo mouth positions from Robbie's and David's neutral heads, protects
the lower neck, and carries the same form delta through the head shape keys
and eyes. Both a subtle (0.85 strength) and stronger (1.0 strength, 2.0 gain)
preview were rendered from disposable source copies under ignored `build/`.

The stronger front comparisons are archived for [Shane](form/shane_denham_baseline.png)
([fit](form/shane_denham_strong_fit.png)),
[John](form/john_orourke_baseline.png) ([fit](form/john_orourke_strong_fit.png)),
[player Des](form/bordeaux_09_baseline.png) ([fit](form/bordeaux_09_strong_fit.png)),
[referee Des Sr.](form/des_feeney_sr_baseline.png) ([fit](form/des_feeney_sr_strong_fit.png)),
[Robbie](form/robbie_roden_baseline.png) ([fit](form/robbie_roden_strong_fit.png)), and
[David](form/david_murray_baseline.png) ([fit](form/david_murray_strong_fit.png)).
The mild fit was barely visible. The stronger fit distorted David's lower
jaw, exposed Shane's teeth in neutral, narrowed John's already generic eye
area, and did not resolve the other identities. No sculpt was promoted.
The portraits' differing yaw, pitch and expressions also limit direct
screen-space landmark transfer; the landmark numbers are guides, not a 3D
scan or a likeness score.

## Connected oral topology

The [source pilot](../../../../../tools/blender/beechlawn/pilot_br022_connected_mouth.py)
extends the earlier [cut experiment](../../../../../tools/blender/beechlawn/pilot_br022_topology_mouth.py).
It removes a single connected region of front-mouth faces, orders its
boundary, and bridges that boundary to four new lip rings in the same skinned
head mesh. It transfers vertex weights and UVs, creates matching positions
for the existing shape keys, and adds the existing test cavity and upper
crowns. The two disposable `.blend` sources and renders were made by Blender
4.3.2 under a 240-second deadline. The Robbie cut has 114 boundary vertices
and a 4,782-vertex final head; David has 68 boundary vertices and a
4,598-vertex final head. The mouth rim is a genuine boundary rather than a
separate overlay. A separate
[source audit](../../../../../tools/blender/beechlawn/audit_br022_connected_mouth.py)
confirmed all 4,326 original head vertices and weights stay in order,
all four source shape keys remain, the 65-bone armature remains, and the
new mouth rim has 114/68 boundary edges for Robbie/David. This is source
integrity evidence only; it does not establish acceptable appearance.

The [Robbie neutral](mouth/robbie_roden_neutral_front.png),
[Robbie smile](mouth/robbie_roden_smile_front.png),
[David neutral](mouth/david_murray_neutral_front.png) and
[David smile](mouth/david_murray_smile_front.png) are visibly unacceptable:
neutral has a cut-looking lip seam; Smile has pinched, discoloured corners,
exposed straight dental crowns and insufficient cheek/eye expression. The
[Robbie turned view](mouth/robbie_roden_smile_threequarter.png) and
[David turned view](mouth/david_murray_smile_threequarter.png) confirm the
same defects. The connected topology solves only the structural continuity
problem; the inherited facial surface, UV/pigment and expression sculpt still
fail. This candidate stopped at Blender review, so no native Godot or Mac
performance claim follows from it.

## Decision and next acceptance

The strict **shipping** scores remain Shane 6/20, John 7/20, player Des 6/20,
referee Des Sr. 4/20, Robbie 5/20 and David 6/20. A landmark-fit score or a
prototype smile must not be substituted for photographic likeness. To reach
roughly double these scores, BR-022 still needs an individually sculpted
mouth-capable head surface, lips and teeth with natural neutral/partial/full
smiles; identity-specific eyelids, cheeks, jaw, skin and groom; and photo plus
native Forward+ checks at front and turned angles. Independent neutral,
three-quarter and profile references for the six people would make those
forms judgeable. Preserve the shared 65-bone rig, neck join and body budget.

BR-022 remains **item 22 of 27, in progress**. BR-025 remains **item 25 of 27,
in progress** for target-Mac appearance and sustained 1080p60. The published
Mac build is still v0.5.10 / CFBundleVersion 21; this rejected study does not
trigger a new release.
