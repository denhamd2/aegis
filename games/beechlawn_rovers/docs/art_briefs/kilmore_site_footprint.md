# BR-023 — tapered park footprint and western roadside

Item 23 of 25, in progress. Follows the grass-setback and faded-paint passes.

## Reference analysis and implementation

The archived `estate_overview_zoom_18.png` shows a long western green, a
narrower western tip, an inset back-garden edge and the straight boundary
beside the neighboring grounds to the east. The old rectangular grass apron
and short straight road omitted this structure.

Fourteen boundary points are traced in
`references/research/kilmore_site/site_trace.json`. Two visible goal centres
anchor the authored 105 m gameplay axis; their transformed positions are
(-52.5, 0) and (52.5, 0). The trace stores source pixel coordinates, transform
and image SHA256. This is an approximate modelling alignment, not surveyed
geometry. Faint overlapping markings, source softness and manual point picks
limit accuracy. Original map imagery remains a reference, never a game texture.

Using the Blender director, environment, scene assembly and Godot export
guides, `build_kilmore_site_footprint.py` directly authors:

- A low-poly apron following the irregular outline, with the entire 105 x 68 m
  playing surface left open. Four clipped regions triangulate to 18 triangles;
  the imported area is 20,091.96 m² versus 20,091.94 m² in the authored source.
- A western road continuation with gentle bends, inner/outer footpaths and a
  curb. Its 32 triangles join the existing street without coplanar asphalt overlap.
- A separate editable `.blend`, two GLBs and a Godot layout resource. The
  Blender render is a flat footprint study; the actual field retains relief.

Godot reuses the existing grass, asphalt, wall shaders and house/tree meshes.
Nine additional house instances follow the western street, including setback
and facing. Existing trees spread along the park edge and western green.
Low walls follow eastern and back-garden boundaries; the road-facing lawn
stays open. A distant ground plane stays below -0.1 m so it cannot hide pitch
relief. Road coordinates and wall projection normals now use world space.

The central 35 m lawn-to-footpath / 37.75 m lawn-to-asphalt-edge settings,
faded paint, ball/goals, collision heightfield, all players/referee, touchline
fans and close broadcast presets remain. Only the debug whole-site review
camera widens/recentres to include the western extension.

## Evidence and remaining acceptance

- `kilmore_footprint_evidence/geometry_audit.json`: generated budgets and area.
- `kilmore_footprint_evidence/blender_footprint.png`: Blender layout render.
- `kilmore_footprint_evidence/runtime_layout.json`: actual Godot placements.
- `kilmore_footprint_evidence/after_broadcast.png`: actual gameplay camera.
- `kilmore_footprint_evidence/after_site_overhead.png`: actual engine site view.
- `kilmore_footprint_evidence/web_review.json`: WebGL/browser review.

Checks pass for imported area/orientation, the open playing footprint, road
join, house placement, maintained grass buffer, 4v4 compatibility, 11v11 setup
and all nine gameplay cameras. Actual WebGL intro, broadcast and overhead
captures pass with no browser console errors. There are no additional physics
bodies or texture images. Nine reused house instances add rendering work;
target-Mac frame time remains unmeasured.

This advances layout fidelity; BR-023 remains open. Individual properties,
garden details, branch streets, precise boundaries, tree silhouettes and final
ground/house/car realism need further work. Next compare property/vegetation
silhouettes against archived Street View and environment boards from the
unchanged broadcast camera.
