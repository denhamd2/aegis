# UCL 26/27 League size-5 appearance

Original procedural geometry/UV artwork for the owner's personal football project,
following the supplied adidas League replica photos. Trademarks belong to their
owners; this file grants no trademark licence. No PES/EA assets are used.

Rebuild from repo root with:
`python3 tools/blender/beechlawn/author_ucl_ball.py` (Blender 4.3.2, numpy/Pillow/scipy).
Editable source: `tools/blender/beechlawn/ucl_26_27_league.blend`.
Photo authority/provenance: `references/source_uploads/chat_attachments/ucl_26_27_ball/`.

One closed 7,040-triangle mesh, identity transforms, centre pivot, diameter 0.22 m.
Godot generates screen-size mesh LODs at import. One dielectric Principled material,
2K sRGB albedo, non-colour roughness and OpenGL tangent normals. The seam normal
and small 16-repeat TPU tile are retained for editing; the combined normal is
exported so the runtime does not require Blender-specific nodes. `.glb` includes
only the prop, without camera/lights. Render evidence and gap review are in
`docs/art_briefs/ucl_ball_2026_10_25/`.

`FootballBallCatalog` chooses this or the unchanged owner-supplied worn GLB.
Physics are shared: radius 0.11 m, mass 0.43 kg. Do not attach a mesh collider.
