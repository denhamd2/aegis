# BR-022 mouth topology and native integration study, 30 October 2026

Status: **rejected as a production asset**. The owner's request to continue
toward 20/20 likeness prompted a source-level mouth study on the current
Robbie Roden and David Murray heads. The existing saved neutral heads,
individual sculpt deltas, normal/near GLBs and Mac build are unchanged.

## Reference gap and mesh finding

The [original Robbie portrait](../../../references/source_uploads/chat_attachments/br022_realism_followup/70467.jpg)
and [David portrait](../../../references/source_uploads/chat_attachments/br022_realism_followup/70466.jpg)
show open, tooth-bearing smiles. Their current playable Smile only raises a
closed lip line. Robbie's saved `Skin_Head` has 4,326 vertices and 4,298
polygons. Its 54 boundary edges are elsewhere: **there is no mouth boundary
edge**. The lips and front oral bridge are one continuous surface. A dental
surface placed behind it cannot be exposed by simply lifting the corners.

## Tested approaches

1. [`pilot_br022_oral_v2.py`](../../../../../tools/blender/beechlawn/pilot_br022_oral_v2.py)
   kept the topology and recessed the Smile surface over a fitted mucosal
   patch and smaller, rounded upper crowns. A [geometry sweep](../../../../../tools/blender/beechlawn/sweep_br022_oral_recess.py)
   eliminated the first trial's 90 inverted lip triangles. The final
   [source audit](../../../../../tools/blender/beechlawn/audit_br022_oral_v2.py)
   found zero inverted lip triangles for both people. In a 161 × 61 front ray
   grid, neutral exposed zero teeth for each person and the Smile exposed
   1,481 Robbie / 1,678 David dental samples. David had one neutral cavity
   sample, below a visible pixel in the fixed render. The quarter/half/
   three-quarter Smile samples reveal teeth progressively for Robbie
   (28/487/1,047) and David (1/339/1,280); David's reveal is notably delayed.
   The [Robbie](blender/recess_robbie_smile.png)
   and [David](blender/recess_david_smile.png) Blender fronts looked better
   than the earlier closed frown, but the tooth line was still too uniform.

2. The candidate normal and subdivided near heads were exported into an
   isolated project copy under ignored `build/`, then reimported by Godot
   4.6.3. The first native portrait still used the old near head; its metadata
   identified `heads/near/robbie_roden.glb`. The
   [isolated exporter](../../../../../tools/blender/beechlawn/export_br022_oral_pilot.py)
   was corrected to build both normal and near packages. The subsequent
   [Robbie](native/robbie_head_detail.png) and
   [David](native/david_head_detail.png) 1280 × 720 Forward+ captures used the
   candidate near heads and both passed the runner's import/render checks.
   Visually, the mouth became a dark oval with flat, squared teeth and a
   greyish lip border. This fails the likeness and natural-expression gate;
   Blender geometry visibility was not enough. The [capture metadata](native/manifest.json)
   records Linux llvmpipe, not Mac Metal performance.

3. [`pilot_br022_topology_mouth.py`](../../../../../tools/blender/beechlawn/pilot_br022_topology_mouth.py)
   tested a genuine opening while keeping the source vertex order, weights,
   UVs and expression keys. It removed 53 front bridge faces, creating 82
   mouth boundary edges. Pulling the neutral boundary together hid the dental
   row but left a straight dark slit. A separately skinned lip strip sampled
   the head's anatomical UV material and moved with Smile, yet the
   [neutral](blender/cut_robbie_neutral.png) and
   [smile](blender/cut_robbie_smile.png) views show a visible patch seam and
   jagged, dark mouth corners. This version failed the Blender gate and was
   not exported to Godot.

## Decision and next source requirement

Neither approach improved the playable model. The strict production scores
remain Shane 6, John 7, player Des 6, referee Des Sr. 4, Robbie 5 and David
6/20. A convincing open smile needs a new head source with continuous facial
skin flowing into **ordered upper and lower lip loops**, a sealed inner mouth,
appropriate dental and gum forms, and a neutral-to-smile deformation that
retains those loops. The six identities then need individual eyelid, cheek,
and expression sculpting against the original photos. Transfer the shared
65-bone bind, neck normals/UVs/weights and runtime material maps explicitly
if the head topology changes; retain the current close-up and normal LOD
budget. Review neutral, partial smile and full smile in fixed Blender views
and actual native Forward+ before promotion.

BR-022 is item **22 of 27, in progress**. Its next acceptance is six-person
photo and native likeness review, including an actual match roster import.
BR-025 is item **25 of 27, in progress**, and remains the later packaged
target-Mac appearance and sustained 1080p60 check. No new Mac version is
claimed; the published version remains v0.5.10 / CFBundleVersion 21.
