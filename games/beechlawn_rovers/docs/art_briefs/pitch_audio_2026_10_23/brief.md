# Close grass, physical net and original audio — bundle 4

Original two-blade bent tufts augment the existing reference-led turf shader
near cameras. A 16-cell pool caps geometry at 40,000 tufts / 240,000 triangles,
regenerates at most two cells per draw and fades away at distance. Tufts follow
terrain normals; shared mud/water masks exclude puddles and thin muddy areas.
Rough chalk is retained with subdued pigment on blades. This improves close
surface depth; it does not establish final hyperreal environment approval.

Physical net contact already drove an anchored local mesh deformation. Native
close sequences now verify it visually with continued independent ball travel.
The mesh has a subdivided sagging surface; post/ground ties remain fixed.

Twelve original synthesized assets provide menu/intro music, kicks, pass/header,
post/net, whistle, footsteps, sideline ambience/cheers, rain and UI feedback.
Source and CC0 provenance accompany them. Typed match events carry actor/team,
position, match time and score. Match sound has a 12-voice pool, UI four voices,
separate persisted Music/Match/UI buses and a master limiter. Music stops on
intro completion. No proprietary PES recording or melody is included.

Logic tests cover terrain/water/budget, typed routing, actual players, volume
preferences, music policy and existing title/intro/weather/net regressions.
Native Forward+ llvmpipe 640×360 captures pass. A real Godot Movie Maker mix
has RMS 0.019508, peak 0.077898, and exactly zero muted-tail RMS. See the mix
report; the repeatable capture/verifier are in tools. These are software
appearance/audio checks, not M1 performance measurements.
