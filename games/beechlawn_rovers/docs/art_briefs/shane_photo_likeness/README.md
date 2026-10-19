# Shane original-photo pass — BR-022 (22/25, in progress)

See [reference brief](brief.md) and [measured asset report](sculpt_report.json).
The untouched new photo and hash are archived in
`references/source_uploads/chat_attachments/shane_face_photo/`.

The separate head package refines the lower jaw/chin silhouette, medial cheek
volume, upper/lower lid openings, brow/orbital planes, rounded nose tip/alar
wings and lip span/corner planes. The neutral identity has an independent,
editable `Shane_Smile` shape: it is a restrained closed smile, not a copy of the
photo's open smile. Eyeballs remain fitted to the established orbital centres.
The smooth cap/sparse-tuft groom is replaced with 1,800 curved, tapered tufts,
varied directional clumps, a quiet root layer and geometric strand normals.
Scalp intersections and broad white highlights were corrected in the review loop. Anatomically registered skin UVs are retained; brow pigment is
painted through those UVs. No owner-portrait pixels are used as skin.

Source: `tools/blender/beechlawn/shane_photo_head.blend`.
Repeatable build: `tools/blender/beechlawn/refine_shane_photo_head.py`.
It starts from the current shared production source, preserves topology/weights,
exports only the head/eyes/hair with matching bind indices and adds no animation
library. The shared body source and base GLB remain byte-identical. Shane's
11v11 and retained 4v4 resources use the same variant; other players keep their
existing heads. Runtime swaps compatible mesh resources onto the live skeleton,
then discards the temporary package node. Reconfiguration restores base meshes
before applying the next identity, preserving substitutions and independent edits.

## Review evidence

`before/` and `after/` contain matched textured and no-hair clay front, profile
and three-quarter portraits. `smile/` shows the optional closed-smile shape.
[Actual Godot portrait](godot_portrait.png) uses the production FootballerVisual
appearance path and match lighting through a separate review scene. The current
menu Play/Watch captures under `../title_photoreal_evidence/` show the assembled
match. The isolated view is deliberately distinct from generated promotional art.

The variant keeps 4,326 head vertices and five mesh surfaces. Including hair and
eyes it contains 47,236 triangles versus 13,504 for the base head package; the
increase comes primarily from the dimensional groom, applied only to Shane. It adds no bones or animation
clips. The GLB is about 8.8 MiB with embedded textures; import extracts the
images. These are asset counts, not measured GPU residency or native frame times.

## Validation and remaining gaps

`shane_head_variant_smoke.gd` passed: production roster selection, matching skin
bind names/order/inverse transforms, shared-body identity, eyes/hair package,
neutral smile, idle/sprint/pass/shot/turn pose samples, one skeleton per actor,
reconfiguration and unaffected teammate head. Existing title, resource-sharing,
pose-safety and pre-match-intro checks also passed. Godot Web portrait capture
reached the first-draw marker without browser errors. This is structural and
integration evidence, not artistic approval.

This is an incremental reconstruction, **not a finished exact or AAA likeness**.
Cheek-to-mouth transitions, eye/brow expression and fine hair clump flow still
need artistic refinement; profile depth is estimated because the new photo is
primarily frontal. The open photo smile needs proper teeth/oral modelling if it
is to be reproduced. Existing collar/shoulder geometry defects are visible and
remain a separate kit gate. Native Mac appearance and M1 performance are untested.

Next acceptance: BR-022 (22/25) stays in progress. Review the photo beside these
neutral/expressive views, refine remaining face planes and hair flow, then apply
the approved variant workflow to the next individual roster player. Keep the
shared body/rig and the existing camera settings intact.

## Reproduce

From repository root (run Godot checks serially):

```sh
timeout --kill-after=3s 90s blender -b --python-exit-code 1 --python tools/blender/beechlawn/refine_shane_photo_head.py
timeout --kill-after=3s 90s godot --headless --editor --path games/beechlawn_rovers --import
python3 games/beechlawn_rovers/tools/run_smoke_tests.py shane_head_variant_smoke.gd title_screen_smoke.gd shared_roster_resources_smoke.gd shared_pose_safety_smoke.gd pre_match_intro_smoke.gd
timeout --kill-after=3s 90s blender -b --python-exit-code 1 --python tools/blender/beechlawn/render_shane_denham_review.py -- --shared --neutral --face-views --variant=tools/blender/beechlawn/shane_photo_head.blend --out-dir=games/beechlawn_rovers/docs/art_briefs/shane_photo_likeness/after
```

Add `--clay --no-hair` for form checks or `--smile --portrait-only` for the
expression. Render the unchanged shared source without `--variant` into a new
baseline folder when starting another iteration; keep the archived baseline.
