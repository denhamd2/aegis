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

## Subject fill (measured)

The one framing quantity a still *can* give up, and the one that makes "at
match-camera distance" mean something: how much of the frame's height a
standing wrestler covers. Read off the frames with a pixel grid (the method
is reproducible — `tools/refs/measure_frame.py` shares the luminance
helpers, and the row coordinates below are from a 20px grid overlaid on the
source frame at its native size):

| framing | frame | subject fill |
| --- | --- | --- |
| strike exchange | `mid_strike_exchange.jpg` (739x415) | 0.675, 0.708 |
| wide standoff | `wide_standoff_broadcast_angle.jpg` (640x480, active rows 48–412) | 0.32, 0.41 |

The standoff's two wrestlers differ because one stands further from camera;
both are quoted rather than averaged.

Note this **corrects** the "Distance" section's older reading below, which
called the strike-exchange framing "both figures fill roughly half the
frame height". Measured, it is closer to two-thirds.

## FOV
- Not derivable from a still on its own — and fill does not settle it
  either, because fill is a function of *both* focal length and distance.
  One measured statement pins the pair: the standoff camera sits "just
  outside the near ropes" (see Height below), which in this project's ring
  is ~3.2m from centre. Solving for the lens that puts a 1.8m subject at
  0.69 fill from ~3.5m gives a **vertical FOV of ~41°**, and that is what
  `match.tscn` sets. Godot's 75° default cannot reach the measured fill
  without putting the camera 1.7m from the wrestlers — inside the ring.
- The 41° is therefore *derived from two measurements plus this ring's own
  dimensions*, not measured directly. A frame-stepped clip with a known
  render resolution could measure it properly and should replace it.

## Horizon height (measured)

Where the far edge of the mat sits in frame, which is a proxy for camera
height that a still can actually give up:

| framing | far mat edge |
| --- | --- |
| wide standoff | ~0.66 of frame height |
| strike exchange | ~0.59 |
| impact / spot (`close_impact_table_spot.jpg`) | ~0.49 |

The horizon rises toward frame centre as the camera drops, which is the
measurable form of "the impact framing is lower".

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

`game/core/camera/match_camera.gd` no longer scales separation by a
multiplier. It solves for the distance that produces the measured subject
fill above, taking whichever is further out of "one wrestler fills 0.69 of
the frame" and "both wrestlers fit across 0.55 of its width" — so the
standoff framing is reached by the camera opening out to contain the pair,
not by interpolating toward a separation this file never measured.
`game/tests/test_camera_framing.gd` asserts the achieved fill through
`unproject_position()`, which needs no renderer.

Still placeholder, and marked as such in the source: `follow_speed`,
`cut_speed`, and the cut's aim point. Cut *duration* is not invented — a
finisher cut lasts as long as its paired move and a three-count cut as long
as the pin — but the ease curves this file marks pending are still pending.
