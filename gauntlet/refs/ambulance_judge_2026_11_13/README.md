# Ambulance: three reference-led Blender revisions

Owner request13November2026: after the deployed cell work, remodel the ambulance
in Blender toward10/10 likeness with the supplied WWE2K references. The latest
cell batchb40f772 is published and verified. Its remaining walking-strip study
is deferred while this request takes priority. No score is guaranteed.

## Reference and scope

[Primary attachment72065](reference/owner-72065.jpg) is a closed rear-left
three-quarter view. Three additional embedded owner screenshots show the side,
roof, open doors and warm interior. The independent ambulance judge has the
latest user images in its context and can inspect all supplied references.
No reference pixels are used as game textures; geometry and maps are original
Blender/procedural work. [Production brief](../ambulance_remodel_2026_11_13/reference_analysis.md).

## Locked comparison

Five views: rear closed, rear open, rear detail, higher side/roof and an
additional head-on open-interior diagnostic added before the first revision. Camera setup
is frozen after baseline framing; use `ambulance_likeness_shot` in Godot4.6.3
Forward+ at960x540, default4xMSAA+TAA, neutral studio reflections and fixed
lighting. Each round records cameras, real gameplay contract and asset cost.
These isolated renders do not establish full-arena appearance, exact camera
reconstruction, wholly unseen cab detail or native M1 performance.

Fixed rubric: visible silhouette/proportions30%, panel/ladder/door layout25%,
lights/livery20%, fabrication detail15%, materials10%. One independent read-only
judge evaluates the baseline and all three revisions; the modeling specialist
implements its highest-confidence corrective feedback. Preserve working doors,
shut-in corridor, collision and mouth/bed/lip contracts.

## Judge ledger

| State | Proportions | Layout | Lights/livery | Fabrication | Materials | Weighted /10 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Baseline | 6.0 | 3.0 | 2.0 | 3.0 | 4.0 | **3.8** |
| After revision1 | 6.5 | 7.5 | 7.0 | 6.0 | 5.5 | **6.7** |
| After revision2 | 6.5 | 8.0 | 7.5 | 7.5 | 6.0 | **7.2** |
| After revision3 | 6.5 | 8.0 | 7.5 | 8.0 | 7.0 | **7.4** |

Baseline judge: generic box/cab masses are recognizable but most identity cues
are absent. Prioritise curved full-height ladder and lower/taller rear windows;
stepped side/roof livery and complete rear chevrons/lamps; then substantial
diamond-plate bumper, side service hatch/window and material response. Do not
bake warm arena colour into white paint. Exactly three revisions follow this baseline, with supported scores and gaps.


## Revision feedback

Revision1 (15,548triangles/10materials/23surfaces): full ladder/curvedreturns,
stepped livery and roof bands, rear chevrons, lower tall windows, fixed amber/clear
header bank, plate bumper/lamp triplets and service window/flag. Judge6.7: identity
improves strongly, but window reveals/floods/plate still lack manufacturing depth;
forward interior cabinet missing.

Revision2 (17,662triangles/10materials/23surfaces): profiled window reveals,
projecting flood housings, dense alternating raised plate tread, skirt/pinstripe
refinements, forward cream double cabinet and thicker red padding. Judge7.2:
reveals now too thick/deep, lenses still flat, wheels simplified. Thin the window
rims and refine lenses/tyres/hubs in the third revision. Preserve global bounds
and fixed comparison lighting; unknown cab/front areas cannot earn exact-match
certification from these views.

The native Blender scene now displays doors assembled at their actual hinges;
the builder exports their existing identity-root local frames for Godot. Use
the builder to regenerate exports. Casket exports remain unchanged.

## Gameplay compatibility checks in progress

Each revision retains exact Body/DoorLVisual/DoorRVisual root frames and the
real mouth/bed/lip/collision snapshot. Conservative triangle-AABB tests show no
new geometry in the existing lying-wrestler corridor. A separate actual-trajectory
head-joint sphere diagnostic identified close contact with the fixed header's
inner underside during escape; a local inner bevel/recess is planned for the
final revision, preserving the visible lamp bank. This proxy is a clearance
check, not exhaustive skinned-body collision or native performance evidence.

## Final verdict: SHIP WITH NOTES

All three requested revisions are complete. Final independent judge score is
**7.4/10** (raw7.35), with improved thin rolled window rims, authored optical
ribbing/roughness and tyre/hub mounting detail. Final cost18,210triangles,
10materials and23surfaces; GLB1,105,916bytes. This is improved reference likeness,
not completed AAA acceptance or10/10.

Remaining visual differences: approximate cab/module contour and proportions;
stripe cadence and several fittings; comparatively dim/opaque amber optics and
simplified clear-lens, window and rubber response. Reference interiors are partly
occluded. Locked studio views cannot certify arena appearance or native M1/16GB
frame time. No fourth cosmetic loop was performed or claimed.

## Final validation

- **6/6 focused shut-in/container cases pass**, zero GdUnit failures/errors/
  orphans; [report](regression-tests.xml). The raw [log](regression.log) records
  non-fatal Godot dummy-renderer null-material cleanup diagnostics, including
  the unchanged casket scenario. Do not describe the entire engine log as clean.
- Mouth/bed/lip, ramp placement, collision snapshot and three identity GLB roots
  match baseline exactly. The reserved lying-wrestler corridor has no triangle
  AABB candidates. Native Blender doors are assembled at the actual hinges;
  [portable source check](blend_validation.json) passes with30relative images.
- Fixed header now has a higher sloping inner underside; flood projection is
  shortened. [Actual-triangle head-joint proxy check](header_proxy_clearance.json)
  gives minimum154.2mm for140mm proxy, zero intersections on the recorded path.
  [CPU-skinned head sampling](skinned_head_clearance.json) covers10entry/escape
  states with23,647Head-dominated vertices each, with zero header/flood candidates.
  These bounded checks are not exhaustive skin-triangle collision certification.
- Godot import, Python compilation and five-view Forward+ captures pass. Casket
  source/export hashes remain unchanged. No gameplay timing or animation changed.

Published at `fa5c06d54cf068a387b56884a10390016e7044d8`.
[Mac workflow43511629112](https://github.com/denhamd2/aegis/actions/runs/43511629112)
succeeded; `mac-latest` resolves to that exact commit and `Aegis.zip` is
1,056,141,834bytes. [Download](https://github.com/denhamd2/aegis/releases/tag/mac-latest).

Exact-commit [CI43511629150](https://github.com/denhamd2/aegis/actions/runs/43511629150)
has1316cases,4failures,2errors,5orphans. The pre-ambulance
[CI43502575462](https://github.com/denhamd2/aegis/actions/runs/43502575462) has
the identical totals and failing cases: stale Kenny/Cody model assertion,
prop-handoff body separation, paired-move clearance, realism event dictionary,
and carnage fire-material access (two cases include runtime errors). No new
failing case is introduced by this ambulance batch. These baseline issues remain
open; the stale model assertion belongs to the next Kenny independence work.

## Next owner request

After this batch deploys, review Kenny's repo references (head/face/hair/body),
run three likeness revisions, and audit that his model/source/visual assets are
independent from Cody. Do not start character asset mutations before this Mac
publication is verified. The cell walking-strip study remains deferred.
