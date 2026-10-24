# Match controls, HUD and venue selection

In **Options → Match Setup**, select **Kilmore Drive** or **Rovers Arena** and
**Assisted** or **Manual** player switching, then Save & Back. Start Game uses
these settings for Play and Watch. Kilmore Drive and Assisted are the defaults;
unknown saved venue IDs fall back to Kilmore. Weather remains selectable for
either ground.

Assisted control follows the actual recipient when a ground, through, lofted or
crossed pass is physically released. On a turnover/loose ball it chooses an
outfielder by predicted arrival, with stability margins to avoid cursor flicker.
Tab chooses another suitable outfielder and preserves that override briefly.
The intended receiving run continues until arrival or fresh directional/action
input. No control switch grants possession or applies a ball impulse.
Goalkeepers (including home goal kicks) stay automatic. Manual mode keeps Tab
switching and deliberate restart-taker selection; Watch has no human controller.

The black/white scorebug uses BEE / BOA, real team crests and the existing
three-minute countdown. The bottom strips show number/name and actual stamina;
shot power appears as a separate coloured strip. Left is the controlled player
(or relevant home actor in Watch); right is the opposition carrier/challenger.
The radar rotates with the broadcast side and hides with live player strips
during incident presentation. F1 toggles keyboard help. Blue pre-match lineups,
venue/referee graphics and lower thirds keep their existing presentation style.

Rovers Arena uses original Blender geometry with 49,370 seat positions and
spatially grouped seat/crowd LOD. It reuses the live 105×68m field dimensions,
regulation markings, goal collisions/detectors and animated nets; imported
static copies do not compete with the match systems. Kilmore's relief, wear,
mud and puddles remain venue-specific. Arena turf is maintained, with mowing
bands, clean markings and four corner flags; rain has a small uniform rolling
resistance rather than park puddles.

Native evidence: `art_briefs/match_presentation_2026_10_24/`. Capture explicitly:

```sh
python3 tools/capture_native.py /tmp/arena-review --match --venue rovers_arena --venue-view all
python3 tools/run_smoke_tests.py player_selection_smoke.gd receiver_selection_pass_types_smoke.gd venue_selection_smoke.gd hud_layout_smoke.gd
python3 tools/check_ai_chances.py /tmp/arena-ai --venue rovers_arena
```

Reference/Blender source, original-vs-model gap analysis, licences and export
audit remain alongside the art. Linux Forward+ captures and headless match
checks do not establish target-Mac frame rate. Native Mac input, likeness and
1080p60 acceptance remain open under BR-025.
