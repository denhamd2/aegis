# Animated supporters, dockside stadium and M1 60 fps — v0.5.0

Approved owner plan: BR-021 (21/27), BR-023 (23/27), BR-024 (24/27),
BR-025 (25/27), all in progress. Target M1 Pro-class 16 GB, steady 60 fps,
1080p 3D budget with 80–100% adaptive quality; native Mac acceptance remains open.
Nearly full attendance, Rovers branding, immediate dockside landscape and a
simpler distant waterfront. Free/MIT or original assets; Mac-only delivery.

## Reference and gap contract

Owner frames 70145/70149/70150 show individually readable full bodies, seated
supporters, standing reactions and white box nets with separate rear poles.
Existing stadium spectators are flat cards, park fans are paused player meshes,
and the arena reuses a cleaned park goal selected through a terrain flag.
Existing shell lacks its docks/plaza/tower and intro anchors are pitch-specific.

Archive: `references/stadium_supporters_2026_10_25/`. Public architectural
photographs are study references, excluded from export; original Blender
geometry uses the existing North +X / West −Z site orientation. Preserve the
49,554 valid chair placements, player likenesses/kits, 65-bone shared rest,
contact markers, independent ball and all existing Kilmore environmental assets.
Inspect actual Godot motion/normal exports before changing player source curves.

## Production

Use headless Blender 4.3.2 bpy with director/reference match, character/rigging,
animation, prop, environment, material, LOD and Godot-export guides. Reuse the
wrestling Rocketbox loading/posing principles through football-owned recipes;
preserve wrestling files and its lighting/palette. Twelve avatars, detailed rig
pool 16 gameplay/32 cinematic, VAT 3D crowd, 128 MiB animation-texture ceiling.
Source FBX/TGA stay in a pinned scratch cache; editable recipes, blends, metadata,
authored GLBs/textures and MIT notice are retained with this project.

Work order: baseline/counters → graphics profile and benchmark → animated crowd
section → stadium goals/docks → venue-driven stadium intro (79 s plus the owner's 14 s tifo addition) → full regression,
native comparisons and universal Mac v0.5.0 package. Runtime shader/budget changes
do not establish M1 frame rate. Check chair contact, full transitions, flags,
near/far continuity, both goal ends, net anchors, weather, replays and skips.

## Implementation findings

The source importer root translation needed full rest-basis conversion; a plain
translation subtraction left seated legs straight. Offline ankle IK fits the
actual chair pan/tread. GPU data preserves signed half floats, reverses EXR row
addresses, and flips UV V to match GLTF. Small row groups prevent a whole stand
centre choosing coarse geometry for its nearby front rows. Promotion shares
clip/phase/garment colour and can recast the bounded pool to the required avatar.
Distant tiers omit animated-normal fetches; total authored VAT data is 36.55 MiB.

The water reflection probe excludes crowd/water render layers and only influences
water-level surfaces. Rendering the whole crowd into six probe faces slowed cloud
startup, and a probe spanning the roof darkened metal cladding. Water now uses
restrained filtered waves. No volumetric fog was added. Stone paving has original
colour/normal/roughness maps and physical-scale joints; distant ground reaches
the horizon instead of ending visibly behind floating warehouses.

Balanced 60 caps physical window pixels, not the already-scaled target (which
would feed resolution back into its own Retina limit). The frame benchmark uses
monotonic wall time; engine delta may be clamped or time-scaled. Known scene-load
frames remain in CSV but do not masquerade as live frame-pacing samples. Actual
resident memory is measured outside Godot by the Mac benchmark launcher.

The final goal view also exposed the new land slab covering the old apron by
2 cm. The site base is now below the interior surfaces, and the stadium uses a
world-aligned grass runoff ring behind the nets and beyond the touchlines.
Field dimensions, markings, collisions and rules are unchanged. Kilmore's new
standing spectators retain the correct +Z facing toward the playing field.

Exterior-only aerial perspective uses Godot 4.6's built-in depth fog from 450 to
1600 m, sampling the sky radiance to blend distant land. The original weather
fog is restored for interior shots and on finish/skip; the pitch/players are
unaffected. No volumetric pass is used. API/behaviour verified against the
engine's `4.6-stable/doc/classes/Environment.xml` source on GitHub.
