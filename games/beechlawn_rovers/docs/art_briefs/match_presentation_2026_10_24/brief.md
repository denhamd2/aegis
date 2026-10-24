# Match presentation and Rovers Arena production brief

Reference: original owner screenshot `references/source_uploads/chat_attachments/match_hud_stadium/70060.jpg` (preserved unedited). It shows compact monochrome score cells, timer below, two bottom identity/stamina strips, central transparent radar; blue multi-tier stadium seating directly around a rectangular striped football field. Study proportions and hierarchy, never reproduce game logos.

Current gaps: inline oversized blue scoreboard, permanent controls list, sequential-only Tab control, hard-coded Kilmore environment and venue text. Approved: assisted receiver/defensive switching with manual override, monochrome match HUD, selectable large arena while preserving park fidelity and blue intro graphics.

Blender director reference analysis: long-side elevated broadcast, sun-lit short turf, pale concrete risers, #184c83 blue plastic, #777e83 concrete, #b6bdc2 roof cladding, #161c25 rails; seating terraces and aisle breaks define large bowl silhouette. Target 105x68m regulation field, no running track; three tiers surrounding pitch, covered upper seats. Original clean-frame functional goal/net reuse; four original corner flags, dugouts, access tunnel, perimeter boards.

Source route: https://blendswap.com/blend/10567 (MrChimp2313, CC0, old Blender 2.6x). HTTP download returned 403 here; public page requires sign-in. Approved fallback used: original procedural modular Blender arena, no unverified third-party geometry/textures. Smaller CC0 alternative: https://blendswap.com/blend/7488. External grass/sky of those candidates are not adopted.

Skills: blender-director -> environment-artist -> lod-pipeline -> godot-export. Headless Blender 4.3.2 bpy, no Blender MCP. Source script and .blend retained; GLB import has no Blender runtime dependency.

Budgets: shell under 100k triangles, at most eight shared shell materials; blue seating grouped in spatial sections with near-chair/far-card LOD; crowd cards (not 60,000 skeletons), no crowd shadows. Combined stadium seats/crowd under 500k triangles at broadcast distance; existing player/grass budgets unchanged. Maintain target 1080p60 on owner's Mac, explicitly unproven until measured there.

Validation: native Forward+ broadcast views in both venues, stadium wide and pitch-level detail, HUD at 720p/1080p/ultrawide; deterministic switching/venue persistence and physical-contact regression checks. Venue surface profile must feed collision, render height and ball forecasts identically, no global terrain state.

## Validation outcome

31 unique smoke checks and twelve complete 180-second AI matches pass. Both teams qualify in 6/6 scenarios at each venue; shot share is 38.2/61.8% at Kilmore and 46.9/53.1% in the arena. Ground/through/loft/cross handover, off-ball manual override, sent-off replacement and AI keeper goal kicks are exercised. Native Forward+ stills cover both fields, arena wide/goal views, options and blue intro graphics; software Vulkan is explicitly not Mac performance proof. The first-time-shot regression found during development was fixed by scoping auto-run to true handovers; its earlier failing log is retained. Original reference image/crest proportions are preserved. Native M1 and further crowd/stadium art polish remain open.
