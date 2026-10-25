# BR-023 — UCL 26/27 League size-5 ball

## Reference analysis / production brief

Primary originals: `references/source_uploads/chat_attachments/ucl_26_27_ball/league_size5/`, four owner-uploaded Elverys screenshots (70119/70118/70117/70116). Supplementary original mini screenshots stay archived separately; do not use their pink branding or MINI label. Additional product views and URLs are in `provenance.json`. The owner explicitly selected the pictured League replica, not the Pro match ball. Personal project; trademarks remain their owners'.

Hero sports prop, real-time Godot Forward+, 0.22 m diameter, centre pivot, smooth spherical silhouette. Current worn model lacks the new ball's white/pearl base, black five-point star borders, cyan/blue/lime/pink/purple fades, halftone ink, black adidas/UCL and LGE markings, shallow thermal seams and embossed TPU. Preserve the worn asset.

Palette: pearl #ebeff1, black #161c22, cyan #05bdd1, royal blue #1673c9, lime #c5df31, pink #eb3989, purple #9e67af. Neutral product camera near frontal/three-quarter with large soft key; validate matched studio Blender render plus rotations, pitch-side macro and live broadcast in native Forward+. Fine texture must read in close-ups without noisy glitter at broadcast distance.

## Pipeline and budget

Blender director/reference matching → prop artist → UV workflow/Blender UV texturing → Principled materials → asset optimization/Godot export. Headless bpy, no MCP. Author continuous spherical graphics with an explicit wrapped UV and padded pole treatment; shallow seam normal relief and a separate tiling micro normal. Editable blend and repeatable builder, 6–8k triangles, 2K primary maps, one surface. Physics collider stays the existing 0.11 m sphere, mass 0.43 kg.

## Integration and gates

Catalogue IDs `ucl_26_27_league` (default) and `worn_sunday_league`. MatchSession saves the choice under match.ball; absent/invalid values choose new. Options places Ball beside Venue. Shared BallVisual wrapper configures once at startup; replay duplicates the chosen hierarchy without scripts. Test old settings, invalid IDs, both choices in both venues/Play/Watch, intro/replay continuity and unchanged kick/keeper/wet physics.

BR-023, item 23/27, remains in progress for wider venue/reference acceptance. Delivery is BR-025, item 25/27, universal Mac v0.4.1. Native Forward+ software Vulkan proves rendered integration only; M1 1080p/60 remains unmeasured.

## Delivered asset and visual review

The exported prop is one closed, manifold, centred 7,040-triangle mesh with identity transforms and exactly 0.22 m bounds. Godot generates screen-size LODs on import. One dielectric material uses 2K colour, roughness and tangent-normal maps. `asset_validation.json` records actual Blender/export checks; the neutral [studio render](blender_studio.png) uses those same maps. The builder is `tools/blender/beechlawn/author_ucl_ball.py`.

Comparison iterations corrected the starball symbol (five-point stars rather than a generic football), increased the FIFA Quality marking to the reference proportion, removed repeated branding on the opposite side, and lowered the pearl albedo to retain more detail in sunny match lighting. No screenshot/browser UI or photographic illumination is baked into the artwork. The black adidas, UCL, LGE and pictured quality labels are authored over the continuous star field. Small typography, irregular print/halftone details and pearl response are reconstructions; this is not a pixel-identical product scan.

Native Forward+ evidence includes [sunny Kilmore close-up](native_kilmore_sunny/match_ball_hero.png), [reverse](native_kilmore_sunny/match_ball_reverse.png), [surface macro](native_kilmore_sunny/match_ball_emboss.png), [cloudy arena](native_arena_cloudy/match_ball_hero.png), [rain](native_kilmore_rain/match_ball_hero.png), [original worn choice](native_worn_kilmore/match_ball_hero.png) and [Options](native_kilmore_sunny/options.png). Five groups provide 26 PNGs with renderer/adapter/scene/ball metadata; `validation.json` hashes every image. Primary broadcast captures use the normal kickoff camera. Inspection close-ups explicitly move the stationary ball onto unmarked grass and clear the HUD/selection ring, with the pose recorded in JSON.

The original worn GLB remains byte-identical (`e5b8643d261940b322f76c6ce1bdd352a17dce0ab8674d4d23ad421ac8868841`). Its slightly irregular sub-millimetre bounds are retained; both choices use the same exact 0.11 m spherical collider.

## Checks and remaining acceptance

`gameplay_checks.log` records menu/Play/Watch, recorded replay/results, ball fundamentals, passing, wet-ground behaviour, goalkeeper response and physical shot-contact passes. `selection_intro_checks.log` adds legacy/missing/invalid settings, the actual GLB/choice in all eight ball/venue/mode combinations, recorded replay copies, menu launch → rematch → title retention, both venues and intro completion. The runner gives the ten full-scene assemblies a bounded 90-second deadline and stops immediately on GDScript errors. Existing ObjectDB exit warnings remain visible in logs.

The universal v0.4.1 Mac release workflow independently repeats selection checks, exports and verifies build/source identity, Apple Silicon/Intel architectures and all four packaged ball/venue startups. Linux llvmpipe Forward+ at 960×540 is appearance evidence; exact M1 output, moving appearance, input feel and sustained 1080p60 remain BR-025 (25/27, in progress). BR-023 (23/27) remains open for wider environment/owner reference approval.
