# Title-screen assets

`title_key_art.png` is GPT Image-generated promotional artwork created for
Beechlawn Rovers 27 on 2026-10-18. It is a static menu illustration, not a
render of the gameplay meshes or evidence of their likeness/quality.

Current face reference inputs, preserved unchanged in the archive:

- `references/source_uploads/chat_attachments/title_player_photos/1-69003.jpg`
  — supplied David Murray photo, replacing the foreground Shane likeness.
- `references/source_uploads/chat_attachments/title_player_photos/2-69005.jpg`
  — supplied Derek Mitchell photo (`3-69001.jpg`), the roster identity for the rear position; the current image uses the owner’s selfie as Derek’s likeness.
- `assets/characters/textures/uhlsport_wordmark_from_kit_reference.png`
  — Uhlsport manufacturer reference. Both shirts use a white `uhlsport`
  wordmark centered on the shirt fronts above the sponsor; the original artwork's incorrect Umbro marks were removed.

The final lettering correction reads **THOMAS LOOMES & CO** on both shirts,
with a clear M in LOOMES. Preserve that spelling in all subsequent image edits.

The authoritative crest is the later upload `69032.jpg`, archived under
`references/source_uploads/chat_attachments/club_crest/`. Its narrow vertical
oval is approximately 0.71 wide per unit height, with the leafless green tree,
EST 2004 and green/white bars. The artwork's two shirt badges now follow that
reference. `club_crest_source.jpg` is a byte-identical runtime copy. The native
header shows those original pixels through an AtlasTexture and a small oval
exterior mask; it preserves interior white and source aspect without a
generated replacement logo or a white rectangular background.

Initial composition and kit reference inputs:

- `references/source_uploads/chat_attachments/character_roster_sheets/1-69014.jpg`
  — Shane Denham, #8, facial proportions and blue/black striped home kit.
- `references/source_uploads/chat_attachments/character_roster_sheets/3-69006.jpg`
  — Robbie Roden, #10, was the previous rear-player reference; the current image uses Derek Mitchell, #3.
- `assets/characters/textures/beechlawn_crest_from_kit_reference.png`
  — initial supplied-kit crop, superseded in the menu by the later `69032.jpg`.

Art direction: wide photographic sports campaign composition, both players
on the right, cool daylight/rim light, worn local-park pitch and residential
backdrop, a dark quiet left side for live UI. No baked title/buttons. The
generated chest marks are approximate; the native header uses the later
uploaded crest artwork directly. This artwork does not change any 3D character
or kit texture.

The original and revised generated images remain in the execution workspace's
`generated_images` directory; this copy is the durable current project asset.
1672×941 RGB, approximately 6 MiB decoded, lossless 2D import. One static
TextureRect; no scene rendering, shader animation, runtime cloth or IK.

`fonts/` contains free SIL Open Font License typefaces from Google Fonts:

- [Anton](https://github.com/google/fonts/tree/main/ofl/anton): display titles.
- [Barlow Semi Condensed](https://github.com/google/fonts/tree/main/ofl/barlowsemicondensed):
  regular and semibold menu text.

The full license notices accompany the font files. No paid assets were added.

## Photorealistic revision, 19 October 2026

The current key art replaces the illustrated treatment with natural-light, photographic styling for David Murray and the owner. Both faces are unobscured and sharp, based on their archived original photos. Skin and kit share the same photographic treatment. Centred uhlsport, THOMAS LOOMES & CO, the oval crest, native title and Play/Watch controls are retained. See `title_key_art.provenance.json` for inputs and hash. This remains generated promotional artwork, separate from playable character likeness.
