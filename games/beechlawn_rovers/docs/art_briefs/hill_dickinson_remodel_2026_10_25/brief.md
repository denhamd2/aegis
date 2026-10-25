# Hill Dickinson reference-led stadium remodel — BR-023 (23/27)

Approved: replace the entire Rovers Arena building (bowl, roof, interior and external shell), retain Rovers branding/current occupancy; no Liverpool docks. Improve turf in both venues while preserving Kilmore terrain, paint, mud and puddles. Deliver universal Mac v0.4.0 after validation; no football Web build.

## Reference analysis and gap list

Archived owner screenshot 70060.jpg remains the broadcast hierarchy/scale reference. New empty Hill Dickinson views show close rectangular stands, a continuous South end, tiered sides and North, tapered corner wings, dark hospitality ribbons, blue seats, radial stairs, grey steel roof trusses and daylight glazing. The external shell has red brick, curved silver barrel cladding and glazed ends. Existing octagonal three-tier rings, constant-width diagonal corners and plain materials do not match these features. The old 0.76 m straight tread becomes 1.07 m in corners; the new true-normal offsets use 0.78 m throughout.

Use 105x68 m field as scale reference. Front seating approximately 6.5 m from sidelines/8.3 m from goal lines; remaining photographic reconstruction dimensions are inferred, not construction-survey measurements. Blender XY/Z-up to Godot XZ/Y-up conversion is explicit.

Turf: short dense blades, directional cross-cut mowing, natural tonal/roughness variation, painted crowns and strong roof shade. Existing hard 7 m colour bands/readable repeating texture need replacement. Kilmore retains its rougher pigment, wear, terrain and wet surface.

## Tools and budgets

Headless Blender 4.3 bpy; blender-director, environment-artist, procedural-modeling, realistic-style, blender-materials, texture-workflow, lod-pipeline, godot-export. Original geometry and authored PBR maps plus previously licensed CC0 grass/sky. Shared five-value seat records with descriptive section/row manifest. Spatially centred seat/crowd MultiMeshes, near/far geometry and building LOD. Turf stays under 240k visible detail triangles. Native Forward+ captures for appearance; Linux llvmpipe does not establish M1 frame rate.

## Required evidence

Geometry/data and engine checks; normal broadcast, four corners, each end, pitch-level grass/paint, external elevations; sunny/cloudy and wet grass, plus Kilmore comparison. Native GPU seating readback, no floating chairs/blocked stairs, both 22-player packaged venues. Compare render statistics with v0.3.1. Mac 1080p60/appearance acceptance remains BR-025 (25/27, in progress).

## Refinement findings

First native pass caught a visibility-band hole at the seat LOD transition: independent default hysteresis hid both tiers at some initial distances. Spatial block origins now use overlapping self-fades and a shared imported chair material. Geometry-only GPU readback does not cover visibility, so inspect all four corner images too.

Low turf inspection caught a player occluding the test camera and rectangular dark chunk edges. The evidence camera moved to a clear area; the same 19,200 near tufts are packed into a smaller, denser footprint (12–17 mm blades). Intermediate fins use hashed fades at exposed residency boundaries, with an upward average normal and matching base pigment. Geometry residency/budget remain bounded.

Exterior review prompted curved/smoothed metal cladding, reflective opaque outer glazing, regular facade subdivisions, brick piers/recessed latticework, entrance canopies and original Rovers signage. Interior glazing remains transmissive and non-shadowing. Building proportions remain photographic approximations.

## Final validation outcome

25 final Forward+ views cover normal broadcast, both ends, all four corners, all four building elevations, low turf/paint/mud/puddle views, sunny/cloudy arena and sunny/rain Kilmore. Actual GPU readback checks 3,837 seat transforms without error; Blender BVH checks 2,915 actual tread supports without error. Three independent exported-data tests pass. Eleven relevant unique smoke checks plus a complete unskipped 180-second arena presentation match pass; both sides score twice, with physical shots, crosses and saves. Existing exit-time resource cleanup warnings are retained in logs; they are not gameplay/render assertion failures.

The final model has 49,554 seat positions, 71 spatial blocks and a 204,080-triangle building shell. Captured near turf peaks at 205,568 triangles within 240k. Normal broadcast reports 1,020 draw calls / 943,476 primitives versus v0.3.1's 908 / 500,176. The more detailed roof/building increases geometry and shadow work; these software-renderer statistics are not frame-time proof. M1 Pro 1080p60 remains a required BR-025 gate. Exact architectural likeness remains open to owner review.

No player identity/kit/animation or ball/pitch collision changes were made. Kilmore wear, wet masks, grass buffer and original rough paint remain. Portable Blender source image paths use checkout-relative locations. Universal Mac package identity/startup verification is performed by the release workflow.
