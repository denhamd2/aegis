# camera.md — measured, not remembered

Status: **two sources, and they are not the same promotion.**

Everything under "Subject fill" and below is measured off **WWE 2K gameplay
stills and one WWE 2K clip** (`gauntlet/refs/raw/` — see `timings.md` for the
citation format and the multi-match-compilation caveat). That is what was in
the repo when this file was written, and those numbers still describe the
build's ringside handheld, which is what they were used to solve.

They do **not** describe what this project is matched to. `ring.md`,
`stage.md`, `arena.md` and `lighting.md` are all measured against **AEW
*Dynamite*** photographs supplied by the project owner. The camera was the one
subsystem calibrated against a different promotion *and* a different medium —
a video game rather than a television broadcast — and nothing in the file said
so. The section immediately below is the AEW material, and it is the one that
governs.

**Caveat on the WWE 2K material:** those are individual promotional/gameplay
screenshots, not a frame-stepped clip — there's no timestamp, source video, or
frame-step method to cite per-number the way `ARCHITECTURE.md`'s
"Reference-driven tuning" section expects for `timings.md`. Treat everything
below as composition/framing observations, not hard numbers.
Frames cited: `gauntlet/refs/frames/wide_standoff_broadcast_angle.jpg`,
`mid_strike_exchange.jpg`, `close_impact_table_spot.jpg`,
`wide_establishing_stage.jpg`.

## AEW broadcast framing (measured)

Source: `gauntlet/refs/lighting/aew_grand_slam_broadcast.png` (1366x768), a
frame off an AEW *Dynamite* Grand Slam broadcast, already in the repo as
lighting reference. `lighting.md` measures its luminance distribution; nobody
had measured its **framing**.

Method: the same pixel-grid read the subject-fill table below uses. The
referee's standing figure was read off a 6x zoom of the crop
(500,400)-(580,480); the mat's corners off a 2x zoom of (400,380)-(920,640)
with a 40px grid.

| quantity | value | how |
| --- | --- | --- |
| subject fill | **0.072** | the standing referee spans rows 412–467 of 768 |
| camera depression | **~40°** | the mat is a square seen corner-on; its two projected diagonals give 42.5° and 38.5° |
| stage side | **frame left** | the Grand Slam screen and portal sit left of the ring, crowd behind, commentary desk right |

What this frame is: an **establishing/overhead** shot from high in the bowl,
not the shot a match is called over. `aew_elevated_blue_beams.jpg` and
`aew_wide_bowl_magenta.jpg` are the same family (both are elevated wides from
the stands) and `aew_low_angle_led_wall.jpg` is a floor-level shot of ringside
rather than of the ring. So:

**There is still no AEW reference for the framing a match is actually covered
in.** Four AEW stills, none of them an action framing. That is the gap, it is
named here rather than papered over, and a frame-stepped AEW clip is what
closes it. What the four *do* establish — and what the build now takes from
them — is the arrangement: an elevated camera on the side, looking down, with
the stage frame left and the commentary desk frame right.

### The hard camera, and what its lens is worth

`MatchCamera.Mode.HARD_CAM` is anchored at (-28.5, 8.3, 0). That is **not a
framing choice** — it is a seat in the building `arena.md` already measures:
`BOWL_STRAIGHT_X` 4.425 + `BOWL_FIRST_ROW` 10.13 puts row 1 at 14.56 out on
the -X side, twelve rows of `ROW_RUN` 0.95 plus `CONCOURSE_DEPTH` 2.6 reach
28.56, and twelve rises of `ROW_RISE` 0.48 over `FLOOR_Y` -1.10 reach 8.26.
It looks down at **14.4°**, inside the band a hard camera lives in and well
short of this frame's 40°, which is the establishing shot's angle.

The lens follows from the anchor and a fill, and that is the whole reason the
lens had to stop being a property of the camera:

| lens | fill at 29.7m | full-frame equivalent |
| --- | --- | --- |
| 9° | 0.385 | 152mm |
| **14°** | **0.247** | **98mm** |
| 16° | 0.216 | 85mm |

14° is what ships. It is a **derived** number and is marked as such: no AEW
action fill has been measured, so it is not solved from one. What it is solved
from is the anchor plus the requirement that the ring, not the hall, fills the
frame — 0.247 sits between this frame's 0.072 establishing fill and the
handheld's measured 0.32–0.41 standoff, which is where a master belongs.

**When an AEW action fill is measured, re-solve `hard_cam_fov` from it and
delete this paragraph.** The arithmetic is the table above run backwards;
nothing else in the rig has to move, because the anchor is the building's and
only the lens is inferred.

### What this does not fix

Cut *duration* and ease curves. `MatchCamera`'s shot clock holds the master
7.0s and the handheld 4.5s, and those are **project values, not measurements**
— a still cannot carry a duration, and all four AEW references are stills.
What is defended is the shape (master longer than handheld, both in seconds
rather than tens of seconds). A frame-stepped clip could measure them and
should.

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

## Side (project direction, not a measurement)
- The money shot sits off-axis on -X/+Z, facing the stage side of the hall:
  the entrance stage reads frame-left, the crowd at frame center. None of
  the reference stills pins which side they were shot from, so this is a
  stated direction, not a cited number — fill, FOV and height above are
  side-agnostic and unaffected.

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

**All of the above is now the RINGSIDE HANDHELD, not the master.** The rig
covers a match from `Mode.HARD_CAM` and cuts to `Mode.RINGSIDE` on a shot
clock; the fill fit, the 41° lens, the 1.45m eye height and the containment
guard are all properties of that handheld shot. That is also why the near
ropes crossing the frame at 1.45m is no longer a defect to be designed
around: a ringside handheld shoots *through* the ropes, and it is the master
30m away and 8m up that has to see over them.

Still placeholder, and marked as such in the source: `follow_speed`,
`cut_speed`, the cut's aim point, and the shot clock's two hold times. Cut
*duration* for the event cuts is not invented — a finisher cut lasts as long
as its paired move and a three-count cut as long as the pin — but the ease
curves this file marks pending are still pending.
