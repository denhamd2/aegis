# Supplied title logo and red/black/white landing screen — BR-024 (24/25)

The owner supplied `69668.jpg`, a white italic **Beechlawn Rovers** wordmark
with a red **27** on a charcoal/red sports background, and asked for a red,
black and white landing screen while retaining the players' blue/black kits.
The unchanged original and its provenance/hash are archived under
`references/source_uploads/chat_attachments/title_logo/`.

## Reference and gap analysis

The former native Anton title and lime season badge do not match the supplied
lettering. Lime primary/focus states, navy button fills and blue Options
controls also conflict with the requested palette. The existing photographic
player artwork already supplies the approved identities and kits, so it is
retained byte-for-byte rather than regenerated for this palette change.

The title now uses the original uploaded JPEG through an AtlasTexture region
(72,450,1137,333). A static CanvasItem shader reveals its white and red ink
against the dark menu, preserving the lettering, red 27 and source aspect.
The header retains the original oval club crest. The native menu and Options
share local charcoal, white and red styles, including dropdowns, sliders and
on/off controls. Red selection borders plus white text/focus outlines keep
states readable without relying on colour alone. The left wash is neutral
charcoal; the right photographic art and kit colours are unchanged.

This is 2D native Godot UI work; no Blender mesh, garment texture, match HUD,
walkout graphic, squad data or wrestling asset is altered by this slice.

## Acceptance evidence

- `title_screen.png`: actual Godot Web landing at 1280x720.
- `title_small.png`: complete title and controls at 640x480.
- `title_options.png`: local red/black/white Options panel.
- `title_web_check.json`: browser console/layout and Play/Watch control checks.
- The retained key art hash is
  `4875cfba782c0173707bae4211b1ed3869c401d5c80d4c3e72bada22cfa18640`.

Native M1 appearance/performance remains a hardware acceptance check. BR-024
stays in progress for the wider audio/event-direction scope.
