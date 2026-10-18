# BR-023 — Kilmore Drive environment reference analysis

**Scope:** Make the playable venue read as the saved Kilmore Drive park/local Sunday-league references while retaining the 105 m × 68 m gameplay field and lightweight Godot dressing.

## Sources and layout evidence

- Environment board: `references/source_uploads/drive_folder/file_000000007070824385a7ce63d7e6df85.png`.
- Complementary Beechlawn pitch board: `references/source_uploads/drive_folder/file_000000009d508243a76c4cbae52806fd.png`.
- Broadcast composition reference: `references/source_uploads/chat_attachments/football_reference_upload_round_1/1-69022.jpg`.
- Target-field placement: `references/source_uploads/chat_attachments/openstreetmap/69078.jpg` plus `references/google_captures/satellite/pitch_zoom_19.png` and `pitch_close_zoom_20.png`.
- Broad scale/neighbor context: `references/source_uploads/chat_attachments/google_earth/69084.jpg` and `references/google_captures/satellite/estate_overview_zoom_18.png`. The Google Earth image appears to show the adjacent St John Vianney grounds; it informs the broader site context, not exact target-pitch dimensions.
- Street context: `references/google_captures/street_view/panorama_8_direction_contact_sheet.jpg`.
- Maps are for layout/reference only and must never be shipped as game textures.

## Reference-to-scene feature map

| Feature | Reference evidence | Scene requirement |
|---|---|---|
| Pitch surface | Environment board ground-details strip and aerial captures | Natural uneven green, localized muddy/worn traffic areas, subtle clumps/noise and faded/irregular white chalk. Avoid a uniform flat green plane or obvious repeated texture tile. |
| Pitch markings | Board's faded/local markings and aerial linework | Keep 105 × 68 m gameplay geometry; soften/age visual white lines without changing rule-space. Treat overlapping aerial lines as uncertain, not surveyed markings. |
| Residential edge | Board views 1/4/6; Street View | Low suburban Dublin houses at varied setbacks, rooflines, chimneys, windows, gardens, cars, mature trees; avoid a repeated identical wall of box houses. |
| Boundary | Board rear-boundary detail and map captures | Weathered low wall/hedge/tree boundary with gaps and height variation; preserve the hard linear edge visible near neighboring grounds where appropriate. |
| Roadside | Board views 5/7 and street panorama | Asphalt road, curb/footpath, grass verge, utility poles/overhead cables, a few parked cars; place as a coherent edge, not props scattered evenly. |
| Vegetation | Board tree/park-edge details, satellite | Mature irregular deciduous canopy with varied heights/spacing; some open sightlines and at least one sparser/bare silhouette where season suggests it. |
| Weather/light | Board overcast reference | Soft cloudy daylight, neutral/cool fill, restrained contrast and grounded ambient occlusion; no warm dramatic stadium lighting. |
| Broadcast composition | 69022 broadcast image | Keep action readable and surroundings visible over players; venue details should form a plausible distant backdrop without stealing focus. |

## Current gap and priorities

Before this pass, the Godot dressing used repeated low-detail house/tree/car modules and simple solid-color planes. The ground lacked localized wear and the render read as a modular blockout rather than the irregular, worn local park.

## Active skills and build plan

Use `blender-director`, reference-image analysis, `environment-artist`, `blender-materials`, `realistic-style`, and `godot-export`. Audit the current gameplay camera and geometry before Blender edits; keep reusable venue builder separate from gameplay pitch/collisions. Improve original low-cost Blender modules and Godot placement/material variation. Validate with a captured gameplay camera, fixed environment view, and a Godot import/smoke check. Keep repeated meshes/materials instanced; no runtime foliage physics or high-cost collision meshes.

## Performance target

Steady 60 fps at 1080p on M1 Pro/16 GB is the target but is not established by cloud tests. Favor shared materials/meshes, modest foliage, static backdrop collision or no collision beyond playable boundaries, and restrained shadow casters. Measure scene draw calls/triangles and verify on the Mac later.

## First Kilmore Drive pass — review outcome (2026-10-17)

- The reusable `KilmoreDriveVenue` dressing now has 18 staggered house instances, 26 irregular tree instances, four parked-car variants, wall/hedge, path, curb, road/verge, lamps, utility poles and static overhead lines. Blender sources and low-cost GLBs are under `tools/blender/beechlawn/` and `assets/environment/kilmore/`.
- Fixed a real composition defect: Blender-to-Godot axis conversion meant both house rows were turned outward. The facades now face the pitch on both sides, and the scene smoke test asserts this.
- The lightweight grass shader now blends broad and fine wear variation with the CC0 ambientCG Grass005 color map; the road uses the ambientCG Asphalt033 map. Source and CC0 license are recorded in `assets/environment/surfaces/ambientcg/README.md`. The sky/ambient/sun balance is brighter and softer for the overcast reference. The current Web Compatibility capture is `kilmore_drive_web_first_pass.png`.
- Review result: the capture now exposes the residential facades and roadside, and the grass reads as a textured surface rather than a flat color. It is still visibly stylized, sparse, and far from the photo reference: tree crowns and cars are simple modules, houses have limited facade detail, markings remain clean, and there is no weathered net. Treat this as a better blockout only, not a like-for-like environment.
- Next environment pass: refine the distant silhouettes/facades and tree variety using licensed or original assets, add an irregular faded marking treatment and weathered wall/goal materials, then compare a fixed environment view and gameplay camera against the saved boards. Web Compatibility is only a layout/material check; validate Forward+/Metal look and M1 frame rate on the Mac.
