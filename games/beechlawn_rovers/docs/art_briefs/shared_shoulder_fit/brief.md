# BR-022 shared shoulder and underarm fit

Item 22/25 remains in progress. Refine the live shared source, retaining the
current neckline repair, individual heads, kit maps, rig and all 19 actions.

References: archived Beechlawn home kit object sheets
`file_000000000da0824386b7ef8edd3a9c79.png` and
`file_00000000fcac81f4b3870dc4ce96ac38.png`, with Shane's character sheet for
long-sleeve/body context. The kit has a softly sloping raglan yoke, a fitted but
not skin-tight chest, and natural underarm ease. The blue/black panels, centred
Uhlsport, Thomas Loomes & Co, oval crest and identity printing stay registered.

Baseline gaps: raised medial shoulder caps, a sharp arm/torso deformation
boundary, pinched/flipped underarm and lateral-chest triangles, an oversized
armhole impression, and remaining torso fold/hem quality. Prioritise shoulder
slope and deformation before fabric micro-detail. The current source's local
coordinates are centimetres, Y-up; do not change bone rests to fix the garment.

Plan: audit actual mesh weights and posed triangle orientation; replace sharp
shoulder/axilla weight transitions with a continuous envelope, soften the yoke
contour and preserve sewn neck/cuff interfaces. Limit UV repairs to the relaxed front chest patch. Review
identical textured/clay cameras before applying the source and GLB export.
Sample idle, sprint, pass/shot, pivot, slide/get-up and goalkeeper poses, then inspect
actual roster appearances and the 23-actor Godot match. A reduced triangle-fold
count supports review; it does not by itself establish a reference match.

Tools/guides: headless Blender/bpy using create-player, director/reference-match,
character-artist, modeling, rigging and Godot-export guidance. No live Blender
MCP session; no proprietary or purchased assets. Mac hardware acceptance and
individual likeness remain open.


## Implemented pass

`refine_shared_shoulders.py` changes the current source in place: a continuous
upper-arm/axilla weight envelope, a yoke contour reduction of at most 2.3 cm,
local relaxation of the anatomical nipple fold previously retained under
the chest panel, and a flatter cloth envelope over the back. The largest back
vertex adjustment is 6.18 cm; the source still needs rear-armhole tailoring. Seven covered skin vertices follow the shoulder fit; actual
head geometry, all matching neck-interface vertices, skin UVs/weights and neck
corner normals remain protected (maximum normal encoding error below 0.0002).
The collar and cuffs remain unchanged. All 65 bone rests, 19 action curves,
non-shoulder anatomy, independent heads and six kit atlas images are retained.

The flattened chest exposed an old edge-on UV repair as scalloped stripe
borders. Only that front patch is reprojected onto its original atlas chart;
UV corners outside the patch and all supplied graphic images are preserved.
A trial that exposed skin above the lowered yoke was rejected before export.
The final cloth retains 3 mm clearance near the preserved neck interface.

`validation.json` compares a fixed cohort of 11,712 triangles across nine poses.
The inverted-triangle diagnostic decreases in every pose: idle 257 → 117,
sprint 265 → 122, shot 287 → 123, keeper set 259 → 113, keeper save 281 → 157.
The visible chest tear is removed in the matched render. Remaining inversions
concentrate at the rear axilla during strong arm flexion; this is not a claim
of a finished garment or all-pose deformation approval. See the front/back
clay views and pose sheet, and keep rear-armhole pattern/weight refinement open.

The production review fixture accepts `view=kit` and fixed pose/frame selections
for idle, sprint, pass, shot, turn, slide/get-up and keeper set/save. It uses the
actual roster appearance path. Source renders use the old base head strictly
as a garment diagnostic; Web captures use the separate current head and groom.
Documentation has `.gdignore` so evidence images are not treated as runtime
textures during editor import; the files and raw JSON evidence remain saved.

## Runtime validation and remaining acceptance

The exported GLB retains 65 bones, 19 clips, 16 parts and 67,710 triangles
(count includes both sleeve variants). Blender preservation checks and the
serial shared-head, shared-resource, pose-safety and assembled 11v11 checks
pass. Actual Chromium/Compatibility captures include Shane idle/sprint, John
keeper save and Des short sleeves. Asset captures use software-review lighting
with shadows disabled; they validate appearance/pose integration, not final
lighting or M1 performance. Both Play and Watch, keyboard kickoff, return to
menu and options/layout checks pass without browser errors; see `match/`.

Close review still shows rear-armhole pinching, an uneven/torn-looking hem and
dark arm coverage below Bordeaux's short sleeves. Those regions are not signed
off as finished cloth. The next BR-022 acceptance pass should address the
armhole/hem and short-sleeve skin coverage before individual face production.
No new facial-likeness claim is made by this garment pass.

Reproduction: the pre-pass source is repository commit `462015209705` at
`tools/blender/beechlawn/footballer_shared.blend`. The refinement tool accepts
`--source=<baseline.blend>` and `--preview=<review.blend>` for nonproduction
review, or `--apply` to save/export after the preservation and pose gates.
Running against the tagged current source is a no-op to avoid double edits.
