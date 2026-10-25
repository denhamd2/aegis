# Beechlawn Rovers 27 — title screen

User-requested presentation slice within **BR-024 (item 24 of 25)**. The title
screen is implemented; BR-024's remaining audio and event-direction scope stays
open. Next gameplay priority remains **BR-021 (item 21 of 25, in progress)**:
final-mesh foot planting, reception/contact and moving transitions, with the
current BR-002 ball work as a dependency. Native M1 acceptance stays open.

## Reference and design brief

Reviewed the reference index, art implementation plan, original Shane #8 and
Robbie #10 character sheets and the existing supplied-kit crest. The owner then
supplied direct photos for David Murray and Robbie Roden, followed by a Derek
Mitchell photo to replace Robbie in the artwork. The current art uses David Murray’s supplied photo and the owner’s selfie for
Derek Mitchell (#3); the gameplay roster remains unchanged. Both
shirts retain Uhlsport branding. Originals are archived under
`references/source_uploads/chat_attachments/title_player_photos/`.
Used `blender-director`
for reference/discipline routing and the GPT Image tool to create the static
campaign art. No Blender geometry was required or changed in this 2D UI task.
See [`../../assets/ui/README.md`](../../assets/ui/README.md) for provenance and
free font licensing.

Current target: native Godot menu titled **Beechlawn Rovers 27**, using the
owner-supplied white/red wordmark and red/black/white controls. Players and worn
Sunday-league park occupy the right; the dark left side holds the title,
match-mode selection, Start Game and Options. Native crest/text/buttons remain
separate from the generated background. The generated chest marks and venue
are illustrative approximations, not approved 3D kit/venue assets.

The hero title lockup uses the original `69668.jpg` lettering through an atlas
crop and dark-background mask. It replaces the former native Anton title and
lime season badge. The title remains free of the previous “FC 27” suffix;
the small crest-side wordmark is shortened to “BEECHLAWN ROVERS.” The player
captions identify David Murray (#5) and Derek Mitchell (#3).

## Implemented behavior

- Main scene: `scenes/title_screen.tscn`. No match actors are instantiated until
  Start Game. Static 1672×941 artwork uses roughly 6 MiB decoded memory, plus
  fonts and UI; no animation, IK, physics or 3D draw loop in the menu.
- Play selects keyboard vs AI; Watch selects a completely AI-controlled match.
  Both launch the existing three-minute 11v11 scene, with one keeper per team
  and a separate official. No match rules or AI strategy were replaced.
- Watch disables human assignment/selection rings and keyboard switching,
  starts kickoffs automatically for either side, and preserves AI control
  after goals and boundary restarts. Directly opened match fixtures keep their
  existing human-controlled default, independent of retained menu selection.
- Native buttons support mouse, Tab/Shift-Tab, arrows and Enter. Focus remains
  inside Options while it is open; Escape saves/closes Options. The logical
  1600×900 UI scales uniformly to fit other aspect ratios.
- Master volume changes the real AudioServer master bus and persists through
  `user://presentation.cfg`. Native fullscreen also persists. Web exposes the
  browser fullscreen instruction instead of a nonfunctional native checkbox.
  This adds a volume control, not a new crowd/music audio library.
- Escape in a match returns directly to the title and releases match actors;
  it is a return action, not a resumable pause menu. Full-time shows the hint.
- The existing football release workflow now includes the menu/mode smoke
  check; football export presets include the new font license notices.

## Validation and limitations

Godot checks: `title_screen_smoke.gd`, `eleven_v_eleven_smoke.gd`,
`full_match_restarts_smoke.gd`, and `hud_layout_smoke.gd` passed. The new test
exercises real scene changes in both directions, exactly zero/one human actors,
autonomous kickoff after either team scores, switching isolation, full time,
focus, real volume and save/load. It also checks the title releases all actors.

Browser automation: `tools/check_title_web.py` exports no data remotely; it
serves a local Web build and uses Chromium/SwiftShader to click Options and
both modes, take the human kickoff, and return to title. Evidence lives in
[`title_screen_evidence/`](title_screen_evidence/), including a JSON check
report and screenshots at 1280×720 and 640×480. Initial review caught missing
arrow glyphs and light text on the focused lime button; plain navigation text
and explicit dark focused text correct them.

Software WebGL is functional/layout evidence only. Mac fullscreen behavior,
native appearance, sound mixing on speakers, M1 Pro 1080p/60 fps and full match
balance require the real target device. Promotional art does not prove player
mesh likeness, skin, cloth or environment realism in gameplay.

The later photo/manufacturer revision changes the background and David caption
only. [`title_screen_evidence/title_screen_revised.png`](title_screen_evidence/title_screen_revised.png)
captures the revised menu; the earlier Play/Watch
integration evidence still applies to the unchanged launch code.

The later `69032.jpg` crest upload supersedes the old kit crop for the native
menu badge and guides both chest patches. The native badge uses the original
uploaded JPEG, cropped in an AtlasTexture with its 692:974 aspect preserved;
one tiny CanvasItem shader masks only the exterior white corners. The shader
does not recolor or regenerate its lettering. Shirt badges are reference-led
generated artwork and retain fabric perspective. Sponsor lettering remains
THOMAS LOOMES & CO and manufacturer remains Uhlsport.

## Manual QA

- At 1280×720, 1920×1080 and 4:3: title, crest, cards and footer fit; no text is
  clipped; focused Start Game uses dark text and the white focus outline.
- Navigate Play/Watch/Start/Options with keyboard only. Options traps focus;
  Escape returns to the menu. Change volume, save, relaunch and check it persists.
- Native Mac: toggle fullscreen and back; recheck focus and layout.
- Play: exactly one marker, E/Q kickoff, movement, shooting and Tab switching.
- Watch: no human marker, automatic home/away kickoff and post-goal restart;
  keyboard movement/Tab must not claim a player. Both keepers remain AI.
- Let the match reach full time; Escape returns to menu. Launch the other mode.
  Repeat after a goal and boundary restart; actors/officials must not accumulate.

## Photorealistic artwork revision — 19 October 2026

Replaced the illustrated key art with photographic styling from the original David Murray and owner portraits. Both faces are clear, naturally lit and unobscured. Cloth and skin share the same photographic treatment; the manufacturer, sponsor spelling, oval crest, title and native controls remain. Provenance is in `assets/ui/title_key_art.provenance.json`. Fresh actual Web menu captures are in `title_photoreal_evidence/`; generated artwork does not certify in-game player realism.

The latest browser checks distinguish release-menu evidence from debug match
evidence. Full SwiftShader match captures need the debug-only software shadow/FPS
and freeze hooks; a release build deliberately retains full rendering. The checker
now fails with a clear message if a release is used for those full software
captures. Run `check_title_web.py <release-web> <evidence> --menu-only` for the
actual shipped menu, and the normal command against a debug export for Play/Watch.
