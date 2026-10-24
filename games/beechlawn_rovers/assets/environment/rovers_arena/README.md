# Rovers Arena

Original procedural Blender geometry for Beechlawn Rovers, authored 2026-10-24.
No third-party stadium model or bundled external textures were used.
Source: `tools/blender/beechlawn/author_rovers_arena.py` and `rovers_arena.blend`.

The BlendSwap CC0 candidate (https://blendswap.com/blend/10567, MrChimp2313)
requires sign-in and returned HTTP 403 in this environment. The approved original
modular-arena fallback was used. The smaller CC0 candidate is
https://blendswap.com/blend/7488. These are research links, not incorporated assets.

The GLB contains the structure/apron only. Godot uses the shared functional pitch,
goals and animated nets. `seating.json` contains 50,032 reusable seat transforms,
partitioned into 24 spatial sections. Chair meshes use near/far visibility LOD;
crowd cards have no skeletons or shadows. The source .blend also contains a
preview-only collection for framing which is deliberately excluded from GLB.

Turf uses the project's already credited ambientCG CC0 Grass005 material; the
existing park mud masks remain exclusive to Kilmore Drive. Stadium materials and
crowd shader are original. No paid or extracted PES/FIFA assets are included.

Seating alignment correction (v0.3.1): straight-bank columns share a fixed
0.6 m lateral grid and continuous perpendicular stair aisles. Rows retain their
normal rise; inward chair orientation explicitly accounts for Blender XY to
Godot XZ conversion. Both LODs use the same upright placement function.
