# BR-022 keeper kit graphics — 21 October 2026

BR-022, item 22/25, in progress. Follow the shared fabric pass with reference-led
keeper pigment/placement. Keep the shared fit, linear PBR maps, rig and 19 clips.

## Reference analysis and five gaps

Archived authority: `references/source_uploads/drive_folder/`:
`file_00000000fcc481f4a367f1c29ae78bff.png` (John O'Rourke kit) and
`file_00000000654c81f488f863c6c1a412ab.png` (Bordeaux keeper kit).
Use the owner-corrected oval EST 2004 crest, Uhlsport and Thomas Loomes & Co.

1. John's current large chevron lacks the blue/dark-blue, feathered/flame-like
   central graphic, lower pale cutouts and curved gold sweep in the sheet.
2. His manufacturer is incorrectly white on grey; the reference uses black.
3. Both keepers lack the reference's patterned sleeves and dark side/cuff areas.
4. Bordeaux repeats identical arrows instead of overlapping irregular diagonal
   charcoal/dark/mid-grey shards; its manufacturer belongs on the right chest
   (viewer left), and the sponsor/crest proportions need a matched check.
5. Shorts and socks omit reference graphics and trim. Keep identity data separate
   from shared pigments; don't paint a fixed number onto interchangeable players.

John's palette: light grey #C7CEDA, blue #2F5FA8, dark blue #214A86, gold
#E1B949, black #0B0B0B, white. Bordeaux: charcoal #1A1A1A, dark grey #3A3A3A,
mid-grey #6B6B6B, light grey #9E9E9E, black and white. Fine cloth response
comes from the existing data maps, not baked studio lighting or garment folds.
The sheet's flat garment views and detail panels guide pigment; posed views
guide placement. Glove geometry/material and individual likeness are separate
open subtasks, not solved by repainting a shirt.

## Production and checks

Use create-player, blender-director/reference matching, blender-uv-texturing;
use image generation only for flat reference-led pattern artwork. Assemble
against the current atlas, preserving the outfield/referee/spectator pigments.
Retain name/number resources; Bordeaux keeps FEENEY / 1. Rebuild only affected
role data masks if graphic locations change. No skeleton, mesh, head or clip edit.
The one shared UV exception is the sock binding strip: it previously sampled
the blue collar swatch on every role, giving John's white socks blue cuffs.
It now samples the top of each role's sock chart. Geometry, skin weights and
animation state were checked before export.

## Pattern artwork and provenance

Flat, unbranded panel artwork was generated with OpenAI image generation from
the archived John O'Rourke and Bordeaux goalkeeper kit sheets. These are
original approximations of the reference's blue heraldic/flame and irregular
grey shard motifs, not scans of the posed players or claims of exact tracing.
The unchanged generated source files are
`tools/blender/beechlawn/keeper_patterns/beechlawn_panels.png` and
`tools/blender/beechlawn/keeper_patterns/bordeaux_panels.png` (1254² each).
Their SHA-256 hashes and crop coordinates are in the generated
`assets/characters/textures/shared/keeper_atlas_layout.json`.

The atlas assembler applies logos and text separately from the supplied
crest and keeper sheet crops: original tall EST 2004 club crest, existing
Thomas Loomes & Co artwork, Uhlsport glyph and Boards.ie glyph. Dynamic
name/number prints remain profile data. The assembler retains all four other
role pigments by SHA check; the fabric-map builder follows its printed boxes.

Before/after: same source render cameras and idle frame, real roster Web
front/back/keeper-set/save and broadcast view. Include both teams through their
actual profiles (not John with a shader swapped by hand). Use bounded import,
resource-sharing/11v11 checks and Web Play/Watch. Record remaining mismatches;
native Mac appearance/performance cannot be approved from cloud renders.

## Result and evidence

The four `before_source_*` and four `after_source_*` PNGs use matching Blender
front/back cameras and the diagnostic base head; source back views omit runtime
name/number decals. `before_after_front.jpg` compares the actual Godot roster
front view in identical cast-shade lighting. `after_john*` and
`after_away_keeper*` show the real profiles from front, back, goalkeeper save
frame and isolated broadcast-distance review. The review scene is a material
fixture, not the Kilmore Drive match camera. `match/title_play_match.png` and
`match/title_watch_match.png` verify both 11v11 startup modes at match scale.

Visible changes: John has the blue heraldic/flame motif, gold sweep, dark
manufacturer, tall club crest, sponsor, blue patterned long sleeves and white
sock cuffs. Bordeaux has nonrepeating grey shards, the archived badge and
Boards.ie lettering, dark sleeves and socks. The actual Godot back prints are
J. O'ROURKE / 1 and FEENEY / 1; John's white number has a narrow dark edge.

`sock_uv_validation.json` records that only 896 UV corners of the bound sock
hem changed, with 65 bones and 19 clips retained. `keeper_atlas_layout.json`
records all source/atlas hashes and decal boxes. Four unrelated role pigments
are unchanged. The shared character validator passes its skin/waist/pose and
sculpt checks. Godot roster material sharing, heads, pose safety, 11v11 and
Web Play/Watch checks pass; the latter has no browser console errors.

Remaining art gaps: generated motifs are close in structure and palette but
not an exact reconstruction of every mark in the supplied boards. The hands
still use simple mitten-like geometry and a flat glove material. John's and
Feeney's individual head/hair likeness are unfinished. The current save clip
raises/crosses the arms; it does not yet make a believable diving save. Actual
native Mac lighting and M1 frame timing await a Mac run. BR-022 stays open.
