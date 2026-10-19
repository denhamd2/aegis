# Faded Sunday-league pitch paint

BR-023, item 23 of 25, in progress. Small runtime material refinement.

Reference: archived `football_reference_upload_round_1/2-69021.jpg`, especially
the pitch-marking detail and wide match views. The desired finish is matte,
slightly dirty white with uneven coverage, rather than fresh bright paint.

The existing line mesh already has small width and direction irregularities;
its shader already provides worn speckles and distance filtering. Preserve
these rather than introduce more gaps or move the football boundaries.

Changes in `shaders/chalk_paint.gdshader`:
- Add editable `paint_strength`, default 0.78, reducing the previous pigment
  brightness by 22%, plus up to 7% extra fading along the existing wear pattern.
- Keep the existing warm white palette and fully rough finish; reduce specular
  response from the shader default 0.5 to 0.05 to avoid bright paint highlights.
- Retain line widths, terrain alignment, worn edges and distance filtering.

Uses the environment/material guide principles, implemented in the owning
Godot shader. No Blender meshes, new textures, transparency passes or gameplay
rules change. Compare actual same-preset WebGL captures in
`chalk_fade_evidence/before_broadcast.png` and `after_broadcast.png`; verify that
the halfway line, centre circle and touchlines remain readable. Software
rendering verifies appearance and shader compilation, not native M1 performance.

The wider BR-023 acceptance remains reference matching of the park outline,
road bends and environment assets, following the completed grass-setback pass.

Validation: WebGL export and actual intro/broadcast/overhead captures pass with
no browser console errors. Visual review confirms the centre circle, halfway
line and touchlines remain legible with softer paint. The captures use the same camera preset, with slight
tracking-position variation at kickoff; no pixel-exact brightness comparison
is claimed. No new gameplay tests
were needed for this material-only tuning.
