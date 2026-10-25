# Rovers Arena — Hill Dickinson reference-led remodel

Original Blender geometry and procedural PBR texture maps, authored 25 October 2026. The entire building is reconstructed from public photographs with Rovers branding. Photographic proportions are inferred, not construction-survey measurements. No third-party stadium mesh or research photograph is shipped as a texture.

Source: `tools/blender/beechlawn/author_rovers_arena.py`, pure layout parameters in `arena_layout.py`, editable `rovers_arena.blend`. The source includes a preview-only collection excluded from GLB. `asset_audit.json` records actual geometry totals.

The bowl has a continuous 63-row South bank, tiered sides, a 50-row North end, and fanned corners with tapered northern upper wings. True-normal tread depth is 0.78 m throughout; chair pitch 0.55 m. Openings, half-step stairs, hospitality fascias, trusses, barrel canopy, end glazing, brick podium and external entrances are modelled. The building has a paved base and original boards/signage.

`seating.json` keeps `[x,y,z,yaw,section]` in Godot space. `seating_layout.json` version 1 describes banks, row levels/spans, spatial block centres, roles, counts and an actual-mesh support audit. Runtime groups derive from metadata, not fixed section counts/modulo facing. Section-local MultiMeshes have meaningful culling/LOD origins. Near chairs and folded distant silhouettes use the same imported blue material. Crowd occupancy retains 70% home end, 15% away end, 40% elsewhere, without skeletons or crowd shadows. Roof microstructure has a 230 m visibility limit; imported meshes retain generated LODs.

Godot owns the live field, markings, functional clean-frame goals, animated nets and corner flags. Cross-cut turf shares world coordinates/material response between distant surface, fins and near short blades. Existing credited ambientCG Grass005/Poly Haven sky and Kilmore mud remain CC0 assets. New concrete/brick maps and geometry are original project work. Grass detail remains capped at 240k triangles.

References and credits: `references/hill_dickinson_2026_10_25/provenance.json`. Native evidence, limitations and Mac acceptance status are in `docs/art_briefs/hill_dickinson_remodel_2026_10_25/`. Mac-only delivery.
