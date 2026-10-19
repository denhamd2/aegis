# Kilmore Drive park setback correction — 19 October 2026

Backlog: BR-023, item 23/25, in progress. Scope: site placement and spatial
composition, retaining the current reusable Blender modules and gameplay pitch.

## Reference analysis and brief

Reviewed the original uploaded Drive satellite screenshot, the archived Google
Maps estate overview (zoom 18), field view (19), close field view (20), and the
OSM placement screenshot. The western public-park field lies within a larger
open green, southwest of Kilmore Drive/Beechlawn Close. A substantial unmarked
grassy band separates the northern/road-facing touchline from the roadside
footpath. Houses and parked cars belong beyond that path/road. The separate
formal grounds east of the target field are not the placement source.

Sources: `references/google_captures/satellite/`,
`references/source_uploads/drive_folder/Screenshot_20261016_223354_com_google_android_apps_maps_MapsActivity.jpg`,
`references/source_uploads/chat_attachments/openstreetmap/69078.jpg`.

Gap: the old layout placed the footpath only 5.75 m and the near asphalt edge
8.5 m beyond the touchline. Roadside context was consequently almost adjacent
to the pitch in broadcast/intro views. Trees also used repeated depths.

Plan: retain the 105 x 68 m playable surface, ball/goals, shared assets and close
broadcast settings. Author 35 m of grass before the footpath (37.75 m to the
near asphalt edge). Shift the related street, cars, lamps, service poles,
cables, houses and front-garden verge together. Extend park ground northward
so the wider band remains continuous grass. Place park-edge trees outside the
asphalt corridor, with a sparse inner western cluster. Keep spectators by the
touchline. Maintain the neighboring eastern boundary and southern back edge.

These distances are artistic layout settings informed by the visible
proportions, not surveyed dimensions. The photos establish broad open grass
and relative placement; faint overlapping linework and map UI prevent an exact
boundary survey. Remaining park-outline/road-bend and final asset fidelity
remain open.

Skills: Blender director, environment artist, scene assembly; direct headless
Blender module-bound inspection and a metre-scale layout review; actual Godot
layout checks plus WebGL broadcast, intro and overhead comparison. No extra
character assets, new textures, physics bodies or per-frame environment work.

## Corrections and validation

The regression reproduced the old 5.75 m path / 8.5 m asphalt clearances before
editing. Current runtime bounds verify 35 m / 37.75 m, with cars and lamps still
at the street, houses beyond it, trees off the asphalt, and all eight spectators
at the touchline. The same 105 x 68 m field, goal and team setup remains.

Removing the old below-pitch box exposed a pre-existing terrain rendering bug:
the pitch triangles were backwards for Godot's clockwise front-face rule. Its
old underlay had been the visible grass. The relief mesh and new open-centre
apron now have clockwise winding and upward lighting normals. The apron has no
triangles inside the playing footprint, so it cannot hide the field's subtle
height variation. Park grass texture coordinates now come from world position
in the vertex stage, avoiding view-dependent texture movement. A shared grass-pigment function now matches the playing surface at the touchline,
then blends into the surrounding park over 10 m; the extra grass has no hard
rectangular pigment boundary; field and apron also share the same roughness
and specular response. It reuses the existing turf texture. Height samples,
collision data, goals, ball, gameplay camera defaults and player mechanics are
unchanged.

Validation includes actual triangle-facing checks, at-grade apron/field
separation, street placement, 4v4 environment compatibility, full 11v11 terrain
and restart, pre-match staging/cleanup and all nine gameplay camera checks.
The separate Blender source `tools/blender/beechlawn/kilmore_site_layout_review.blend`
instances the existing mesh data at positions exported from Godot's layout
manifest. The top-down render is a metre-scale layout study with a flat pitch
for legibility; it does not replace the runtime terrain. Original module bounds
are recorded in `kilmore_setback_evidence/blender_module_bounds.json`.

Review images:
- [Before: intro venue view](kilmore_setback_evidence/before_intro_venue.png)
- [After: same intro camera](kilmore_setback_evidence/after_intro_venue.png)
- [After: close gameplay broadcast](kilmore_setback_evidence/after_broadcast.png)
- [After: whole-site engine view](kilmore_setback_evidence/after_site_overhead.png)
- [Blender layout study](kilmore_setback_evidence/blender_site_layout.png)

Cloud WebGL review passes with all 22 player rigs, successful intro skip into
AI kickoff, visible grass, and no browser console errors. The same intro,
broadcast and whole-site views are archived in `kilmore_setback_evidence/`;
`web_review.json` records the rendering checks. This is a software-rendered
visual/layout check, not a native Mac frame-time measurement.

The main remaining BR-023 acceptance is the irregular western park outline,
road bends and exact neighboring-property placements, followed by final
house/tree/car/ground fidelity against the archived photos. Native M1 frame
time remains an open measurement; this pass reduces tree instances from 26 to
20 and adds no per-frame simulation or textures.
