# Four-player finishing pass — BR-022 (22/25)

Scope: Shane Denham #8, John O'Rourke #1, Boardeaux player Des Feeney #9
(all away aliases) and referee Des Feeney Sr. Improve original playable assets,
preserving the common body, tailored kits, 65-bone rig and current clip library.
The latest original portraits in the archived Shane/John/Boardeaux/referee
folders are primary likeness evidence; sheets inform side/rear silhouettes.
Fair, untanned skin remains the owner's colour direction. Originals stay intact.

Five visible priorities: facial silhouette and feature planes; fitted eyes/lids;
clean resting lips and muzzle; directional scalp/facial hair with soft edges;
skin/eye material response that retains detail in match daylight. John's old
lip-closing field crosses the mouth centre line and must be replaced by a
monotonic deformation. Des's goatee needs a softer, narrower chin distribution;
the older referee needs a distinct jowl/nose/brow shape and grey moustache groom.
Shane needs his fuller photographed cheeks and brown short-crop silhouette.

Use create-player and its head-production gates plus director/reference-match,
character artist, modeler, hair, UV/material and Godot-export guides. Preserve
neutral/expression offsets and the complete neck interface. Record protected
body/source hashes, immutable before images, per-head source/export comparison
and actual pitch-side Godot portrait/turned/profile/motion views. Debug Web
captures establish Compatibility appearance; native Mac execution is separate.
Build and publish Web/Mac after relevant regression and package checks. Report
visible remaining gaps honestly; passing imports alone cannot certify AAA art.

## Implementation and integrity

The four recipes now live in `tools/blender/beechlawn/head_pipeline/deltas/`.
`author_four_head_finish.py -- --apply` rebuilds the individual editable
sources from the unchanged shared master. `build_roster_heads.py` validates
and exports these recipes, fits the four separate grooms and patches every
intended roster alias. The older individual authoring commands delegate to the
new entry point. `refresh_roster_skin.py` also uses the current materials.
Shane's individual changes no longer mutate the generic teammate head.

Facial widths and vertical placement use bounded adjustments guided by
original-portrait landmarks normalized to the eye line. The measurements are
an offline production aid, not a scan or a reconstruction of hidden anatomy.
`landmarks/measurements.json` records reference hashes, crops, detector/model
provenance and the intermediate measurements; `fitted_measurements.json`
records the fitted source. Three intermediate input renders are archived;
Shane's intermediate image was superseded before archival, which is explicitly
recorded rather than misidentifying his current fitted image as that baseline.
The MediaPipe Apache-2.0 tool and official task model remain in ignored build
storage and are not dependencies or assets of either game.

Materials use original anatomical UV pigment, restrained normal relief, a
separate roughness map and fitted iris/sclera pigment. They retain the master
neck texels. Source photos are not pasted onto the meshes. Full-haired root
surfaces are clipped along the hairline; curved opaque fibres follow the actual
sculpt. Referee grey moustache/side hair is a separate package from the away
player's receded dark hair/goatee. John's scalp has a separate dark-blonde/wheat
palette; the beard/brow material factors and deterministic fibre placement are
retained from the brown-beard pass.

`export_audit.json` proves all four neutral heads and both eyes match the
saved Blender sources within 0.000002 m, preserves neck vertices/UVs and checks
frontal lip winding and four embedded image names. `protected_before.json`
protects the shared body GLB/source by hash. `groom_audit.json` records opaque
geometry/surface cost and the independent John palettes. The imported roster,
shared resources/playback, head binds/Smile, standing poses, pre-match intro
and lineup checks pass. Skin pigment/neck probes also pass; these scoped
regressions do not measure artistic likeness.

## Review and remaining quality work

`blender/<identity>/` contains front/turned/profile diagnostics. Actual Godot
Compatibility pitch-side views are under `web/<player>/`, with fixed settings
and browser reports. Before images remain under `before/`. The original
before/after lighting is not fully identical across historical runs, so use
source/geometry measurements for quantitative change and current matched
camera views for visual review.

This pass improves the playable assets but does **not** meet the requested
AAA/exact-likeness bar. The current base still reads too generic and symmetric;
the lower cheek/muzzle planes and lid/lip anatomy need more individual shaping.
Hair is dimensional but still too regular and cap-like at close range, and
skin needs richer reference-led variation without painted lighting. Referee
age detail needs better structural folds rather than relying on relief alone.
Smile is retained and the head follows the existing body actions, but a
convincing individual expression/blink rig is not delivered by this pass.
Profiles hidden by the original portraits remain estimates. These are concrete
BR-022 finishing tasks, not approved final faces.

The next BR-022 acceptance check (item 22 of 25) is a focused manual form pass
on cheek/jowl, eyelids, nose and mouth using the archived original photos,
followed by the same pitch-side turns and a hair-silhouette pass. Shared kit,
keeper gloves and save animation remain separate open work. Mac package
integrity can be checked here; native Metal appearance and the M1 1080p/60 fps
target require hardware execution and remain unmeasured.

## Fine-strand Web aliasing follow-up

A fixed John beard crop showed dark single-pixel speckles in Compatibility.
The hair-shadow-only ablation left adjacent-pixel RMS essentially unchanged
(44.83 vs 44.81); enabling 4x MSAA reduced it to 22.68 and the fraction of very
dark pixels from 6.1% to 0.5%. `hair_diagnostics/summary.json` and its actual
captures preserve this differential check. The football project now enables
4x MSAA; scalp/beard material factors and cast shadows are retained. This
improves sampling, not facial anatomy or the remaining close-up groom design.
The added native GPU cost still needs M1 measurement.

The release gallery uses `web_final/<player>/` portraits: these are fresh
captures with normal maps and sun shadows enabled and MSAA enum 2 (4x),
recorded in each report. The earlier multi-angle `web/` set is retained as
pre-antialiasing evidence. All four new portrait logs are free of browser
errors. The cloud validates appearance/integration, not native Mac parity.

## Current follow-up

The [23 October broadcast/turf/four-head follow-up](../broadcast_turf_refresh_2026_10_23/brief.md)
supersedes the old no-blink and uniform-roughness status above. It retains this
pass's historical images and limitations; new evidence has its own directory.
Reference-driven finishing and native M1 visual acceptance remain open.
