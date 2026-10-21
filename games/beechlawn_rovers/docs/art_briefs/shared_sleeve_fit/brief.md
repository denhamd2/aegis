# BR-022 shared shoulder and sleeve silhouette

Item 22 of 25, in progress. Continue production source 1c48ba9 in place.
Use create-player and the director/reference-match, character, modeling,
rigging and Godot-export guides via headless Blender.

References: archived home kit file_000000000da0824386b7ef8edd3a9c79.png,
Shane file_00000000d76881f48f576ff4249aa3b2.png and Bordeaux
file_000000008a9881f49c8ce1ebe2521b75.png under references/source_uploads/drive_folder.
The references show relaxed raglan shoulders, cloth spanning the upper back,
and tapered sleeves with restrained easing rather than a body-tight muscle cast.
Preserve centered Uhlsport, Thomas Loomes & Co and the oval crest.

Current gaps, in order:
1. Upper back retains paired anatomical ridges and a triangular hollow.
2. Shoulder-to-sleeve transition has a hard anatomical cap.
3. Long sleeve has an inflated forearm contour in the actual idle pose.
4. Short-sleeve opening and armhole need a matching silhouette check.
5. Individual face/keeper graphics and fabric micro-detail remain separate.

Review the unchanged baseline and candidate with fixed neutral clay back,
textured front/kit and nine action poses, followed by actual Web roster views.
Preserve rig rests, all 19 clips, skin including custom neck normals, head
packages, collar/cuffs, atlas images and UVs. Geometry edits only on the two
shirt variants. Do not rerun older character generators. Retain arm-coverage
and posed waistband regression checks. No runtime cloth or extra mesh parts.
Native M1 performance remains unmeasured.

## Result and fixed-pose evidence

The neutral clay back comparison removes the sharp triangular hollow between
paired shoulder-blade ridges. Both shirts receive the same bounded envelope:
1,694 vertices per variant, maximum rearward fill 2.122 cm. The long forearm
is modestly tapered at 2,301 vertices, up to 0.666 cm, using the restored skin
surface to retain at least 3.5 mm radial clearance where the requested taper
would otherwise intrude. Upper arm and wrist/cuff endpoints remain pinned.
The short-sleeve forearm is intentionally exposed skin, not a second taper.

All mesh topology, UV loops, vertex weights and kit image files are retained.
A protected-state hash also compares every other mesh's positions and corner
normals, all bone rests and all animation curves. No body/head source changes,
no new mesh parts or texture allocations; export remains 67,284 all-variant
triangles, 16 mesh parts, 65 bones and 19 clips. This is not a measured per-actor
render cost.

The 11,878-triangle cohort is taken from the current post-hem source and held
fixed for this pass. It differs from the earlier pre-hem cohort, so compare
only the paired numbers below. It is a fold diagnostic, not a proof of perfect
cloth or final visual approval.

| Fixed pose | Before | After |
| --- | ---: | ---: |
| Idle | 73 | 73 |
| Sprint | 81 | 77 |
| PassRight | 123 | 123 |
| ShotRight | 101 | 100 |
| GroundedSlideTackle | 202 | 201 |
| GetUpFromProne | 148 | 135 |
| KeeperSet | 61 | 61 |
| KeeperSave | 130 | 130 |
| Turn90Right | 75 | 75 |

The central rear recess at sampled heights 132–138 cm falls from up to
1.806 cm to at most 0.056 cm; the higher centre becomes a shallow convex cloth
surface. These are mesh-space probes, not measurements of the reference photo.

`before_back.png` / `after_back.png` use the same neutral clay setup; their
combined `before_after.jpg` isolates geometry. `kit_detail.png` checks the
unchanged graphics. `pose_sheet.jpg` and `short_pose_sheet.jpg` cover the same
nine poses with long and short sleeves. Blender review heads are the retained
base diagnostic head; actual Web captures use the current independent roster
head packages. Software Web asset views disable sun shadows, and the sky below
the full-body fixture is its horizontal-camera horizon, not match terrain.

## Integration and next acceptance gate

The source validator retains all 12 arm-skin probes, 20 evaluated waistband
samples, normalized weights, head sculpt compatibility and non-T-pose locomotion.
Shared-head roster, shared resources, pose safety and 11v11 headless checks pass.
Web captures cover Shane front/back/sprint, Bordeaux short sleeves, John save
and the referee, plus a matched previous-source back capture, with no browser
errors. Match UI/Play/Watch evidence is stored in `match/`.

BR-022 (22/25) remains in progress. Next refine the visible collar/raglan edge
against the kit sheets in matching close front/back and moving-arm views;
that check depends on retaining this shared fit and the arm/waist regressions.
Garment micro-detail, exact keeper graphics and individual likeness remain
separate open gates. Native M1 1080p/60 fps has not been measured here.
