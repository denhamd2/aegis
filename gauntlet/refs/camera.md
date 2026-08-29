# camera.md — measured, not remembered

Status: **partially seeded from static reference screenshots, plus one real
gameplay clip** (`gauntlet/refs/raw/video/wwe2k26_footage_01.mp4` — see
`timings.md` for its citation format and the multi-match-compilation
caveat). The clip's continuous camera behavior during the tie-up/getup
sequences cited in `timings.md` broadly confirms the standoff/mid-fight
framing described below, but cut *duration* and ease curves for
finisher/three-count cuts specifically haven't been isolated from it yet —
still pending. See `timings.md` for the footage-drop / No Mercy fallback
note that still applies to everything else.

**Caveat on this source material:** these are individual promotional/gameplay
screenshots, not a frame-stepped clip — there's no timestamp, source video, or
frame-step method to cite per-number the way `ARCHITECTURE.md`'s
"Reference-driven tuning" section expects for `timings.md`. Treat everything
below as composition/framing observations, not hard numbers, and prefer real
frame-stepped footage to replace this once Phase 1 footage capture happens.
Frames cited: `gauntlet/refs/frames/wide_standoff_broadcast_angle.jpg`,
`mid_strike_exchange.jpg`, `close_impact_table_spot.jpg`,
`wide_establishing_stage.jpg`.

## FOV
- (pending — not derivable from a still without known sensor/lens metadata)

## Height
- Default "standoff" framing (`wide_standoff_broadcast_angle.jpg`): camera
  sits roughly at chest-to-head height of the wrestlers, just outside the
  near ropes — a broadcast ringside angle, not a top-down or eye-level
  first-person view.
- Impact/spot framing (`close_impact_table_spot.jpg`): camera drops lower,
  closer to mat height, for a grounded, low-angle look during a table/ground
  spot — noticeably lower than the standoff height above.

## Distance (min/max, and how it scales with wrestler separation)
- Standoff framing keeps both wrestlers fully in frame head-to-toe with
  visible headroom and ring rope in the foreground — reads as the *far* end
  of a follow-cam's range (comparable to this project's `max_distance`).
- Strike-exchange framing (`mid_strike_exchange.jpg`) pulls in noticeably
  closer once wrestlers are within grapple/strike range — both figures fill
  roughly half the frame height, consistent with `MatchCamera`'s existing
  `separation * 1.6` distance scaling being the right *shape* of response
  (closer wrestlers -> closer camera), though the exact multiplier and
  min/max meters still need a real frame-stepped measurement to confirm.
- Impact/spot framing pulls in tighter still and low — this reads as a
  scripted move-triggered cut, not the continuous follow-cam, matching
  `MatchCamera.Mode.FINISHER_CUT` conceptually (exact trigger conditions
  unconfirmed from stills alone).

## Framing behavior
- Cut triggers (finisher, three-count, reversal): stills confirm *that*
  high-impact moments get a distinct closer/lower framing
  (`close_impact_table_spot.jpg`) from the standard follow-cam, and that a
  wide establishing shot exists for entrances/stage
  (`wide_establishing_stage.jpg`) — but not cut *duration* or the exact
  trigger list. (pending real footage)
- How the rig keeps both wrestlers in frame during grapples/strikes: in
  `mid_strike_exchange.jpg` both wrestlers stay centered and fully visible
  even mid-strike, with the camera oriented along the axis between them —
  consistent with this project's existing midpoint-follow approach.
  Contextual UI (a move-list overlay, top-left) appears during this framing
  without displacing the HUD corners — see `hud.md`.

Placeholder constants currently live in `game/core/camera/match_camera.gd`
(`min_distance`, `max_distance`, `height`, `follow_speed`) — the *shape* of
the current implementation (midpoint follow, distance scales with
separation) now has weak screenshot-level support; the actual numbers still
need real footage before replacing the placeholders, and this file should be
re-cited once frame-stepped clips exist.
