# Rovers Arena — Hill Dickinson reference-led remodel

Original Blender geometry and procedural PBR texture maps, authored 25 October 2026. The entire building is reconstructed from public photographs with Rovers branding. Photographic proportions are inferred, not construction-survey measurements. No third-party stadium mesh or research photograph is shipped as a texture.

Source: `tools/blender/beechlawn/author_rovers_arena.py`, pure layout parameters in `arena_layout.py`, editable `rovers_arena.blend`. The source includes a preview-only collection excluded from GLB. `asset_audit.json` records actual geometry totals.

The bowl has a continuous 63-row South bank, tiered sides, a 50-row North end, and fanned corners with tapered northern upper wings. True-normal tread depth is 0.78 m throughout; chair pitch 0.55 m. Openings, half-step stairs, hospitality fascias, trusses, barrel canopy, end glazing, brick podium and external entrances are modelled. The building has a paved base and original boards/signage.

`seating.json` keeps `[x,y,z,yaw,section]` in Godot space. `seating_layout.json` version 1 describes banks, row levels/spans, spatial block centres, roles, counts and an actual-mesh support audit. Runtime groups derive from metadata, not fixed section counts/modulo facing. Section-local MultiMeshes have meaningful culling/LOD origins. Near chairs and folded distant silhouettes use the same imported blue material. Crowd occupancy is 95% home, 85% away and 90% side/corner (44,685 fans). Football-owned MIT Rocketbox supporters replace flat cards with animated 3D LODs, smaller row groups, a 16/32-rig camera pool, hand-following flags and score/replay reactions; see `assets/characters/supporters/README.md`. Roof microstructure has a 230 m visibility limit; imported meshes retain generated LODs.

Godot owns the live field, markings, dedicated white stadium box goals with rear tension poles, animated near/far nets and corner flags. Cross-cut turf shares world coordinates/material response between distant surface, fins and near short blades. Existing credited ambientCG Grass005/Poly Haven sky and Kilmore mud remain CC0 assets. New concrete/brick maps and geometry are original project work. Grass detail remains capped at 240k triangles.

References and credits: `references/hill_dickinson_2026_10_25/provenance.json`. Native evidence, limitations and Mac acceptance status are in `docs/art_briefs/hill_dickinson_remodel_2026_10_25/`. Mac-only delivery.

The original dockside addition is authored by `build_stadium_docks.py` and saved
in `stadium_docks.blend`: water/channel, quay walls, terrace steps, bridges,
railings, bollards, stone paving, hydraulic tower/engine house, eastern plaza,
historic rails, road/dock wall and simpler industrial context. North is +X and
West is -Z, verified against the actual imported seating bank centres. The old
oversized concrete base is hidden when this public realm is instantiated.

Water uses a cheap PBR surface and a one-shot structural reflection probe. Its
volume is restricted to the water level, and its mask excludes the entire crowd
and water itself. It cannot darken the metallic roof/facade or render 44,685 fans
six more times at startup. Distant land/water extend to the horizon; only exterior
intro cameras use a larger far plane. No volumetric fog has been introduced.

`data/venues/rovers_arena.tres` owns goal, camera and optional tifo resources.
The illustrated, white-outlined home-end tifo is a transparent cutout print on
an unfolding GPU cloth grid. It is shown in three intro angles and clears before
kickoff. New sources/validation: `docs/art_briefs/stadium_supporters_2026_10_25/`.
