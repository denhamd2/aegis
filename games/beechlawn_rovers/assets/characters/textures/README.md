# Beechlawn player texture sources

The current prototype uses `beechlawn_home_tailored_2k_albedo.png`, a 2K kit
atlas with dedicated front, back, sleeve, shorts, sock and binding regions.
`beechlawn_home_tailored_atlas_layout.json` records its pixel rectangles.
The original supplied crest, manufacturer and sponsor are retained; the back
reads S. DENHAM above the reference-style block 8. Normal and roughness maps
are 512-square, shared cloth detail. Regenerate this set with
`python3 tools/blender/beechlawn/build_shane_tailored_textures.py`.

`beechlawn_home_shane_08_albedo.png` is the historical 1K torso atlas. Its
panel colors, badge, sponsor, Uhlsport mark, collar detail and back number are
derived from the archived Beechlawn home-kit object sheet
`references/source_uploads/drive_folder/file_000000000da0824386b7ef8edd3a9c79.png`.
The atlas generator crops the crest, sponsor logo and manufacturer wordmark
from that sheet, and applies low-contrast knit variation from the provided
fabric swatch. It keeps the full shirt design in one Godot/glTF albedo texture.

`shane_denham_face_reference.png` is an antialiased front-face crop from the
archived Shane #8 character sheet
`references/source_uploads/chat_attachments/character_roster_sheets/1-69014.jpg`.
It is retained only as a modeling reference and historical source. The current
Shane head material does not use this crop or `shane_denham_head_albedo.png`.
The current head instead uses `shane_head_anatomical_albedo_2k.png`, whose
pigment follows the head's anatomical UV islands. The exposed body uses
`shane_body_anatomical_albedo.png`; eyes and short hair have their own small
image maps. None is a portrait overlay. The source sculpt/texture pass and
remaining acceptance checks are recorded in
`docs/art_briefs/br022_shane_body_face_tailored_pass.md`.

Regenerate the derived textures with:

```sh
python3 tools/blender/beechlawn/build_shane_kit_texture.py
```

Then regenerate the Blender source and GLB with:

```sh
blender -b --python tools/blender/beechlawn/build_shane_denham_player.py
```

## Likeness/deformation cleanup (2026-10-18)

The current head/body pigment includes the archived **CC0 MargaretToigo** clean
skin base, resampled through the original anatomical UVs and colour-tuned.
Its original and license evidence are in
`references/third_party/makehuman/skin_toigo/`; no source image is needed at
runtime beyond the baked maps. The rejected Aksel comparison has painted
injuries and is not used.

- `shane_head_detail_normal_1k.png`: restrained authored pore/age relief.
- `shane_brown_hazel_eyes_albedo.png`: iris/pupil on curved eyeballs.
- `shane_short_crop_cards_rgba.png`: opaque root region plus strand-card alpha.
- `shane_crop_strand_normal.png`: restrained hair relief.

Hair exports as glTF `MASK`, not blended transparency. See
`docs/art_briefs/br022_shane_likeness_cleanup.md` for actual asset captures,
normal/retarget diagnostics, limitations and costs. Older generated images in
this folder are historical inputs, not evidence of active material bindings.
