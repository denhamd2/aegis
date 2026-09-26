# Props — credits and provenance

## Ula fala (`ula_fala.glb`)

Original: modelled procedurally in `tools/blender/roman_props.py`. No
third-party input.

## AEW title (`aew_title.glb`, `aew_title_art*.png`, `aew_leather*.png`) — THIRD-PARTY MARKS

Geometry original (`tools/blender/roman_props.py`), laid out off the texture
atlas below.

The textures come from `tools/assets/source/aew_title_atlas.png`, a
2172x724 belt texture atlas **supplied by the project owner** (2026-09-26)
as the visual reference for the belt. Its provenance beyond that is not
recorded. It depicts the AEW World Championship, and carries AEW's marks
("AEW", "WORLD CHAMPION") -- a real promotion's trade dress, which is not
this project's. It is a standing exception to the README's "fully original"
claim, on the same terms as the Dynamite video and the other supplied AEW
artwork (`game/assets/environment/CREDITS.md`, `game/assets/ui/CREDITS.md`).

`tools/assets/build_title_textures.py` derives everything from it:
- the plate art: the belt band cut to each plate's outline;
- normal and ORM (roughness/metal) maps from that art's own shading;
- a tiling leather texture from the atlas's close-up leather swatch.

The atlas's swatches (leather, gold, gem, snaps) are used as material
references only; none of them is placed on the belt.
