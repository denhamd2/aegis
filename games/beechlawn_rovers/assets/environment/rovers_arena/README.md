# Rovers Arena

Original procedural Blender geometry for Beechlawn Rovers, authored 2026-10-24.
No third-party stadium model or bundled external textures were used.
Source: `tools/blender/beechlawn/author_rovers_arena.py` and `rovers_arena.blend`.

The BlendSwap CC0 candidate (https://blendswap.com/blend/10567, MrChimp2313)
requires sign-in and returned HTTP 403 in this environment. The approved original
modular-arena fallback was used. The smaller CC0 candidate is
https://blendswap.com/blend/7488. These are research links, not incorporated assets.

The GLB contains the structure/apron only. Godot uses the shared functional pitch,
goals and animated nets. `seating.json` contains 49,370 reusable seat transforms,
partitioned into 24 spatial sections. Chair meshes use near/far visibility LOD;
crowd cards have no skeletons or shadows. The source .blend also contains a
preview-only collection for framing which is deliberately excluded from GLB.

Turf uses the project's already credited ambientCG CC0 Grass005 material; the
existing park mud masks remain exclusive to Kilmore Drive. Stadium materials and
crowd shader are original. No paid or extracted PES/FIFA assets are included.
