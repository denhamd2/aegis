# Ambulance reference analysis and production brief

13 November 2026. Specialist: Blender. Await baseline independent judgement before modifying the model. The owner requests exactly three render → independent judgement → revision loops; scores remain the judge's assessment, with no promised 10/10.

## Reference and camera

Primary: owner attachment `72065.jpg`, a clear closed rear-left three-quarter view. Additional owner images, described by the coordinator, show a higher rear-left view and open doors/interior. These are the visual target supplied for the WWE 2K ambulance request; do not infer exact real-world dimensions from perspective.

The primary fills nearly the full frame, with the rear panel occupying the right third and the long left side receding left. The roof is only slightly visible; the bumper and rear wheel are clearly readable. Match this view before comparing details, then use a higher view for roof stripes and an open rear view for interior/door motion. Neutral diagnostic lighting must accompany presentation lighting: amber lamps and warm arena reflections must not turn the white paint orange in its base colour.

## Visible construction and priority gaps

| Priority | Reference evidence | Present authoring source | Planned correction |
| --- | --- | --- | --- |
| P0 | Full-height polished ladder beside the rear corner; two curved returns over the roof edge, approximately seven visible rungs | No ladder | Continuous round rails with curved top returns, evenly spaced rungs and shallow mounting standoffs; visual-only detail outside the corridor |
| P0 | Broad red side belt, thin lower pinstripes, large stepped triangular graphic rising toward the rear | Narrow straight belt only | Continuous non-emissive red livery on thin conforming surface geometry; preserve panel boundaries and wheel aperture |
| P0 | Yellow/red chevrons cover nearly the entire rear door field and meet at the central seam | Five tiny red/white marks near the bottoms | Clip continuous diagonal red bands against a non-emissive yellow door field, preserving windows, hinges and door frame; match the apex direction |
| P0 | Two tall rounded dark rear windows, near the centre of each leaf, with bright metal surrounds | Short wide windows high on leaves | Taller, narrower glazing with black gasket and restrained metal reveal; exterior is visibly opaque/dark in the supplied reference |
| P0 | Large amber upper corner lamps, three amber top-centre lamps above three clear flood lamps; small red roof markers | Small red lamps and a front lightbar | Separate amber emission from yellow paint; clear floods use existing pale non-emissive lens/metal unless the selected reference view calls for illumination |
| P1 | Full-width diamond-plate rear bumper face and step; two red/amber/clear triplets low on rear | Thin plain step, sparse tread marks, no rear triplets | Plate-shaped bumper/step with map-scale diamond tread and inset lamp clusters; maintain the established lip and landing path |
| P1 | Warm cream/yellow cabinets and dark red bench in coordinator-described open views | Grey cabinets and green seating | Recolour existing dedicated interior surfaces, refine panels and handles without narrowing the victim corridor |
| P1 | Two longitudinal red roof bands in coordinator-described elevated view | Plain roof and metal rails | Thin paint bands matching the existing roof crown; no new global shell dimensions |
| P2 | Side access door, small upper vents, lamp mounts, bright latch/hinge hardware and plausible metal wheel hub | Generic low cabinet seams and simple fittings | Correct a few large panel breaks and functional fittings after the major rear/side features; avoid unseen front-detail inflation |

Primary masses are a tall rectangular patient module, lower sloping cab and exposed rear step. Preserve the existing game-scale envelope: module x ±1.1 m, z −4.3…0 m, roof approximately y 3.08 m; full front reaches z −5.9 m. Ladder tubes, surface livery, lamp lenses and bumper relief may project modestly beyond the shell as documented visual detail; do not change the collision or gameplay approach dimensions.

## Palette and materials

Palette targets separate material colour from warm scene lighting: white paint `#DCDDD5`, deep red paint `#A20C13`, safety yellow `#E2DE39`, dark glazing `#20262A`, rubber `#19191B`, bright metal `#A9ADB0`, warm cream interior `#CBC5A2`, dark red upholstery `#5A1C22`, amber lens `#FFB51B`. Values are approximate visual swatches, not calibrated reflectance measurements. Paint uses a restrained clear coat; rubber remains rough; ladder/chrome and patterned plate have distinct roughness/normal response. Only emergency lamp materials emit. Livery, interior and white hull must not emit.

## Production constraints

- Upgrade `tools/blender/props/match_containers.py` in place. Add backward-compatible `--only ambulance` selection so all three iterations leave casket assets untouched.
- Keep editable `tools/blender/props/ambulance.blend` and reproducible `game/assets/props/ambulance.glb`; all textures remain project-authored portable files.
- Preserve exact `Body`, `DoorLVisual`, `DoorRVisual` roots, local identity transforms and current hinge frames. Doors must close to the same seam and swing through the existing runtime angle.
- Preserve collision, `mouth`, `bed` and `lip`; no fittings in the wrestler landing corridor centred at bed (−0.3, 0.91, −1.55). No runtime/API changes belong to this specialist.
- Start from 12,558 triangles / 8 materials / 20 mesh surfaces. Target ≤20,000 triangles. Permit at most 10 materials only where necessary to separate safety-yellow paint and amber emission; report actual surfaces/draw-call implications rather than equating materials with total draw calls.
- Keep base/ORM/normal maps within roughly 512²–1024² aggregate pixels per map family. Correct the atlas row calculation before exceeding eight entries. Extra pixels must improve readable diamond plate or surface detail, not duplicate flat colours. Use normal/roughness for small tread and grain; model silhouette and major fittings.
- Headless Blender is the available execution path under project guidance. Active guides: Blender Director, Hard Surface, Realistic Style, Asset Optimization and Godot Export. Coordinator owns matched cameras, Godot import/captures, independent judge, gameplay regression and publication.

## Three bounded revisions

1. After baseline judgement, correct the highest-value rear/side identity: ladder, large livery, tall windows, rear amber/clear bank, roof stripes and warm interior palette. Export and report geometry/material/texture counts for matched closed/open/high captures.
2. Apply only the independent judge's most consequential remaining gaps: proportions within fixed bounds, panel depth, bumper/step construction, fittings or surface response. Capture again with unchanged comparison views.
3. Apply the final supported corrections, then validate/export and record remaining mismatches honestly. Do not spend a fourth modelling loop pursuing a score.

Cheap per-revision checks: root names/transforms, evaluated triangles/materials/bounds, valid textures, unchanged casket hashes, and focused GLB import. Coordinator verifies open/half/closed doors, corridor clearance and matched render evidence. Native M1 frame time remains unverified until measured on the target Mac.

## Revision 1 handover

Independent baseline: 3.8/10. Exported 15,548 evaluated triangles (+2,990), 10 materials (+2), 23 mesh surfaces (+3), GLB 1,027,568 bytes. The ten 128×170 tiles use 217,600 pixels per map family, below the prior 512² aggregate budget. Added materials separate non-emissive safety yellow from amber emission; clear lenses reuse the former red-lamp slot. More material surfaces may add draws; no native performance claim is made.

Coordinator and independent judge confirmed the upper lamp carrier is fixed in the open-door references. Revision 1 therefore adds a fixed `Body` brow, with shortened visual leaves below it, while preserving all root transforms, hinge frames, lower seams and gameplay coordinates. Both casket export hashes remain unchanged. Blender export and Python syntax checks passed; coordinator owns Godot import, corridor checks and five locked views. Await independent revision-1 feedback before a second asset pass.

## Revision 2 handover

Independent revision-1 judgement: 6.7/10 (unrounded weighted 6.675). Exported 17,662 evaluated triangles (+2,114 over revision 1), 10 materials, 23 surfaces, GLB 1,118,152 bytes. Texture dimensions and emission separation are unchanged. Profiled metal window reveals and projecting flood reflector housings replace flat layers; dense alternating raised lozenges replace parallel plate marks. Side skirt/white pinstripes and stepped/roof-band cadence are refined. Forward cream double cabinets with vertical pulls sit at z approximately −4.1, safely beyond the reserved corridor; red seat/back pads are more substantial.

The editable native source now opens with leaves mounted at the existing closed hinge positions. Before GLB export their root positions are reset to identity, preserving runtime assembly without duplicated preview geometry or extra shipping nodes. Casket export hashes remain unchanged. Coordinator owns the second independent render comparison and gameplay contract audit; no third asset pass until that feedback.

## Final revision 3 handover

Independent revision-2 judgement: 7.2/10 (unrounded weighted 7.175). Final export: 18,210 evaluated triangles (+548 over revision 2), 10 materials, 23 surfaces, GLB 1,105,916 bytes. No additional material or texture-resolution increase. Window rims are narrowed and recessed; optical ribbing/roughness and subdued tyre sidewall/tread detail have explicit local UVs. Hubs have a rolled/dished profile, recessed vent collars and hex lug mounting reveals. Only the amber lens material emits, now at a restrained 0.24 strength so authored optics can remain visible.

Integration diagnostics identified conservative head-proxy contact risks from the new brow/flood geometry. The final brow has a formed inner underside rising from outer y 2.66 at z +0.068 to inner y 2.82 at z −0.032. Flood fronts retract to z +0.124. Exterior lamp positions, bank proportions, root/hinge frames and gameplay controls remain fixed. Coordinator must recheck actual mesh distances against the recorded entry/escape trajectories; this specialist does not claim full skin/contact clearance from joint proxies.

The final asset is ready for the third independent judgement and focused game validation. No fourth visual modelling loop is planned; record the final score and supported remaining gaps honestly. Both casket export hashes remain unchanged. Native performance remains unverified.
