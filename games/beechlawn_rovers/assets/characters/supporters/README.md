# Animated Beechlawn supporters

Twelve Microsoft Rocketbox adults and motion sources, MIT, pinned commit
`0943055db6ec570bcef9f2c8b41c9e5467c808f9`. The adjacent license must ship.
Sources: https://github.com/microsoft/Microsoft-Rocketbox . Raw FBX/TGA sources
are fetched into a scratch cache by `fetch_supporter_sources.py`, verified
against their Git blob SHA-1. Author with bounded `author_supporter.py --index N`.
These are crowd assets; footballers keep their existing shared 65-bone rig.

The football-owned Blender recipe retains 80 source bones, authors nine clips,
fits a 0.44 m chair pan and 0.78 m tread, and solves planted ankles during
rise/sit. Root location keys are converted through the root bone's rest basis.
The editable blends are under `tools/blender/beechlawn/supporter_NN.blend`.
The wrestling helper is imported read-only; its lighting, exports and game
remain unchanged. Daylight photographic colour is not wrestling's 0.45 level.

Rigged near models use a shared 1024² photographic atlas, interpolated at the
render cadence. GPU body meshes use three tiers: <=600, <=100 and <=64 triangles
(the last targets 32; small disconnected face/hair components impose a floor).
All tiers are actual volumetric geometry. There are no spectator billboards.
Far-body vertex colours avoid needing photographic detail below pixel size.
Small row groups prevent distant section centres choosing crude geometry for
nearby front-row fans. Promotion retains the same photographic garment colour.
Animation positions/normals are half-float EXR, sampled at 15 Hz with GPU
interpolation. EXR row addressing reverses Blender's bottom-up pixel order. The ArrayMesh
UV V coordinate is also flipped, matching the GLTF exporter used for rigged
models; omitting it samples the blank atlas quadrant and makes faces grey.
Set `compress/hdr_compression=0`: RGBE cannot preserve signed positions/normals.
The tests compare imported float pixels against authored vertex positions.

A bounded 32-rig pool promotes at most 16 near fans in play or 32 for cinematic
shots. Each rig follows its seat's current clip, phase, transition and clock;
its VAT counterpart is masked. Distant people keep real full-body silhouettes.
Chairs face local -Z; avatars face +Z, so crowd placements add PI to chair yaw.
Flags follow baked hand samples from the same clips. Goal reactions use score
deltas (including own goals), never change rules or ball state, and are restored
with compact replay state. Kilmore retains eight casual standing supporters.

This is a performance architecture, not proof of 60 fps on a Mac. Use
`tools/benchmark_mac.py` for native Metal frame timing and resident memory.
