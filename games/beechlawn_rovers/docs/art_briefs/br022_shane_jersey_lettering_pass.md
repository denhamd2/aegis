# Shane jersey lettering — 2026-10-17

BR-022, item 22 of 25, remains in progress. This pass changes the existing
prototype's jersey graphics and their UV registration, not its anatomy or rig.

## Reference decisions

- Owner explicitly requests **S. DENHAM** above **8**. This supersedes the
  earlier number-only back assumption.
- Shane's archived character board
  `file_00000000d76881f48f576ff4249aa3b2.png` supplies the tall, white,
  chamfered athletic eight and its approximate collar-to-hem proportions.
- Shared home-kit board `file_000000000da0824386b7ef8edd3a9c79.png`
  supplies the condensed uppercase back-name treatment and the original
  **THOMAS LOOMES / & CO** artwork. The name is typeset; the number's angular
  outline is redrawn from the sheet, not an exact licensed-font identification.

## Changes

- Added centred white S. DENHAM across the upper back, with a gap above #8.
- Replaced the small rounded generic eight with a taller chamfered block
  eight. Compensated the atlas glyph's proportions for the existing torso UV
  projection using the actual back render.
- Removed transparent padding from the supplied sponsor crop and increased
  its visible atlas width from approximately 220 to 350 pixels. Retained the
  original two-line letterforms and their aspect ratio.
- Fixed back-centre UV interpolation: negative U coordinates now remain
  continuous through zero, with repeat sampling handling the wrap. Previously
  a seam-crossing face could interpolate through the atlas's front panel.
- Moved sleeve sampling to an undecorated blue atlas stripe so the wider back
  name cannot also appear on a sleeve.
- Rebuilt the editable Blender source and embedded-texture GLB. No animation
  keyframes, skeleton, weights, runtime logic, or texture dimensions changed.

## Evidence and limits

Actual Blender/Eevee neutral views:
[front](shane_denham_08_neutral_front.png),
[back](shane_denham_08_neutral_back.png).
Godot's import was refreshed before the Shane import smoke check. The export
retains 37,716 triangles, 10 surfaces, 65 bones, 15 actions and a 1024-square
shirt atlas. Foundation validation records the current GLB checksum.

This is a graphics pass on the existing fit-test garment. Collar/shoulder
construction, local cloth distortion and the broader likeness/kit acceptance
gates remain open. Import validation does not establish final broadcast
readability or Mac performance. Next BR-022 acceptance check remains the
body/head proportion gate followed by reference-specific garment construction
and animated Godot review before roster integration.
