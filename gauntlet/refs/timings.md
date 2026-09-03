# timings.md — measured, not remembered

Every number here must trace to a frame-stepped source clip under
`gauntlet/refs/raw/`. Format: `value — source clip, timestamp, frame-step
method (e.g. "ffmpeg -vf select, 30fps source")`.

Status: **seeded with real frame-stepped measurements.** Two source clips:
`gauntlet/refs/raw/video/wwe2k26_footage_01.mp4` (WWE 2K26 gameplay,
640x360 30fps, ~13min, user-supplied download — gitignored, stays local)
and `gauntlet/refs/raw/video/wwe2k26_footage_02.mp4` (WWE 2K26 gameplay,
640x360 30fps, ~18.8min, WrestleMania-branded hardcore/weapons match,
user-supplied download — gitignored, stays local). Method throughout:
`ffmpeg -ss <t> -to <t> -vf fps=30 out%04d.png`, then visual inspection
frame-by-frame (footage_02's three-count measurement used the same method
at native 30fps with no gaps, i.e. every frame in the window was checked,
not sampled). Timestamps below are absolute position in the clip named
alongside each measurement. **This file is two clips' worth of
measurement, not a cross-checked corpus** — treat single-instance numbers
as a first data point to refine with more clips/matches, not a settled
constant.

**Note on clip structure:** this file is a multi-match compilation with
hard cuts between different pairings (confirmed at ~227.2s, where a visible
mid-grapple cut jumps to an entirely different match) — always confirm a
measured sequence doesn't straddle a cut before citing a number from it.

## Getup duration
- **Instance 1 — ~2.10s (63 frames @ 30fps)**, rise-start to
  standing/fight-ready — `wwe2k26_footage_01.mp4`, 366.07s
  (`frames/getup_rise_start.jpg`, first visible push-off-the-mat frame) to
  368.20s (`frames/getup_standing.jpg`, first frame both feet planted in a
  fighting stance), Goldberg vs. Brock Lesnar, SmackDown. This is the
  *animation* duration only — the wrestler was actually prone from ~358.6s
  to 366.07s (~7.5s), but most of that gap is the attacker's own taunt
  animation playing out, not a fixed knockdown timer, so it isn't cited as
  "getup duration" here.
- **Instance 2 — ~1.14s (34 frames @ 30fps)**, same match, ~35s earlier:
  330.43s (`frames/getup_rise_start_2.jpg`, first hand-plant/push-up frame)
  to 331.57s (`frames/getup_standing_2.jpg`, upright fighting stance).
  **`frames/getup_rise_start_2.jpg` shows why this one's faster:** an
  on-screen "R1 INSTANT RECOVERY" prompt is visible right at rise-start —
  this is a confirmed *player-input-driven* quick recovery, not just
  natural variance. Instance 1 shows no such prompt at its own rise-start.
- **So this isn't two random samples of one fixed animation — it's the
  default getup (~2.10s) vs. an input-triggered fast getup (~1.14s), a
  real two-speed mechanic.** Any getup-duration constant this project
  tunes later should probably be two numbers, not one, if it wants to
  match this.
- Compare: `WrestlerController.GETUP_TICKS = 90` (1.5s @ 60Hz) in
  `game/core/match/wrestler_controller.gd` is a single fixed value sitting
  between the two measured speeds — currently slower than the input-driven
  fast getup and faster than the default one, closer to a middle ground
  than either alone suggested.

## Tie-up → move start
- **Lower bound only, not a full measurement:** lock-up contact at 226.07s,
  grapple-contest reticle UI visible continuously from 226.13s through at
  least 227.20s (`frames/tieup_engaged_reticle.jpg`, mid-sequence) — the
  clip hard-cuts to a different match before the tie-up resolves, so the
  full tie-up → move-start duration is still **(pending — need a tie-up
  that resolves on-camera in this clip or another one).**

## Strike startup / active / recovery
- **Startup (windup-begin to first contact): ~4 frames (0.13s @ 30fps)** —
  `wwe2k26_footage_01.mp4`, 668.300s (`frames/strike_windup_start.jpg`, arm
  first pulls back) to 668.433s (`frames/strike_contact.jpg`, fists
  connect), Goldberg vs. Brock Lesnar, same match as the getup measurement
  above but later in. Converted to this project's 60Hz tick basis:
  ~8 ticks, vs. `strike_jab.tres`'s `startup_frames = 6` — close, on the
  same order, current placeholder reads slightly fast but not by much.
- **Active/recovery: not cleanly separable from this instance.** The
  observed exchange was two wrestlers trading rapid jabs — the attacker's
  own recovery pose overlaps the opponent's counter-strike startup, so
  there's no clean single-wrestler "back to neutral" frame to cite.
  `strike_jab.tres` (`active_frames = 4`, `recovery_frames = 10`) stays
  unconfirmed for now — needs an isolated single strike (one wrestler
  attacking a non-retaliating or blocking opponent) from another clip.
  Checked `wwe2k26_footage_02.mp4` 829s–834s (a standing exchange near a
  dropped weapon) frame-by-frame at native 30fps as a candidate — same
  problem as footage_01: it's continuous mutual trading with no isolated
  single-attacker window, so it doesn't resolve this either. Still needs a
  clip with one wrestler striking a non-retaliating/blocking opponent.

## Reversal window length
- (pending — searched several strike/grapple sequences in `wwe2k26_footage_01.mp4`
  for a dedicated reversal-timing indicator; the only persistent icon found
  near the HUD top during strikes is the star/match-quality meter, not a
  reversal prompt. `wwe2k26_footage_02.mp4` didn't add a confirmed instance
  either — it's a two-player hardcore match with continuous mutual
  strike-trading (see the strike-recovery note below) rather than isolated
  attacker/defender exchanges where a reversal prompt would be easy to
  isolate on camera, and no distinct reversal UI cue was spotted in the
  portions reviewed (0–350s, 800–865s). Needs a clip with a confirmed
  reversal happening on camera, ideally one with a visible on-screen
  reversal prompt.)

## Submission hold duration (single attempt, to referee intervention)
- **~2.5s (673.00s–675.5s)** — `wwe2k26_footage_01.mp4`, hold applied at
  673.00s (`frames/submission_hold_applied.jpg`, hold-progress gauge
  appears) to the referee raising both arms at 675.5s
  (`frames/submission_ref_break_signal.jpg`), same match, ~5 minutes after
  the strike measurement above. Read as a rope-break signal (the hold was
  applied near the ropes) rather than a submission win, so this measures
  one hold-to-break cycle, not a full submission-to-tap-out. Not directly
  cited by any existing constant in this project (`SubmissionMinigame`'s
  `attacker_rate`/`defender_rate` in `wrestler_controller.gd` are per-tick
  rates, not a fixed duration this number converts cleanly against) — logged
  as a real data point for whoever tunes that minigame later.

## Three-count cadence
- **Filled from footage_02** (`wwe2k26_footage_02.mp4`, Byron Breakker vs.
  Oba Femi, WrestleMania-branded hardcore match, live/non-replay pinfall
  finish at ~1093s). Method: extracted every frame at native 30fps across
  the whole count (`ffmpeg -ss 1086 -to 1096 -vf fps=30`, no sampling gaps)
  and located the exact frame each count digit pops onto the HUD (referee's
  hand-slap count, top-center of screen). Digits appear as an instant pop-in
  (no fade), so onset is bounded to a single 1/30s frame each time:
  - **Count "1" onset: t=1091.000s** (frame index 150 of the 30fps extract;
    still absent one frame earlier at 1090.967s) —
    `frames/count_none_pre1.jpg` (last clean frame, no digit) vs.
    `frames/count_one.jpg` (first frame, "1" fully visible).
  - **Count "1" visible through t=1091.633s**, gone by 1091.667s — on-screen
    duration ≈0.63–0.67s.
  - **Count "2" onset: t≈1092.25s** (faint at frame 187/t=1092.233s, fully
    solid by frame 188/t=1092.267s) — `frames/count_two.jpg`.
  - **Count "2" visible through t=1092.633s**, gone by 1092.667s — on-screen
    duration ≈0.37–0.43s.
  - **Count "3" onset: t≈1093.25s** (absent at frame 217/t=1093.233s, fully
    solid by frame 218/t=1093.267s) — `frames/count_three.jpg`. The
    "WINNER OBA FEMI" banner begins fading in on the very next sampled
    frame (1093.3s), i.e. essentially simultaneous with the "3".
  - **Measured intervals (onset-to-onset): "1"→"2" ≈1.25s, "2"→"3" ≈1.00s.**
    Each digit is also on-screen for noticeably less than the full interval
    (there's a silent ~0.55–0.6s gap between one digit disappearing and the
    next appearing) — so the visible-count time and the count-to-count
    cadence are two different numbers; don't conflate them if tuning a
    three-count timer off this. Onset timestamps carry ±1 frame (±0.033s)
    uncertainty from the frame-step method itself.
  - The "no pinfall system exists to compare against" note this entry
    used to carry is **out of date**: `core/match/match_referee.gd` now
    counts, and its `COUNT_TICKS = [60, 135, 195]` puts "1"->"2" at 1.25s
    and "2"->"3" at 1.00s, i.e. the measured cadence, with
    `COUNT_VISIBLE_TICKS = [39, 24, ...]` matching the measured
    ~0.65s/~0.40s on-screen durations.

## Cover -> count "1" (the pin lead-in)
- **~3.60s (1087.400s -> 1091.000s)** — same pinfall as the three-count
  above (`wwe2k26_footage_02.mp4`, Byron Breakker vs Oba Femi, ~1093s
  finish). Method: `ffmpeg -ss 1082 -to 1088 -vf fps=30` walking back from
  the known "1" onset to the cover. Cover applied at **1087.400s**
  (`frames/pin_cover_applied.jpg`, first frame the attacker is settled
  across the opponent in a lateral press with the opponent flat; the slam
  itself lands 4 frames earlier at 1087.267s, so read this as ±4 frames
  depending on whether you date the cover from impact or from the settled
  press).
- **Most of that 3.60s is the referee walking.** He is standing on the far
  side of the ring when the cover goes on and only settles into counting
  position at **~1089.467s** (`frames/pin_ref_in_position.jpg`, first
  frame his hand is down on the mat; he is still dropping at 1089.333s, so
  ±4 frames again). Split:
  - cover -> referee in position: **~2.07s**
  - referee in position -> "1": **~1.53s**
- **Only the second half is comparable to this project.** `MatchReferee`
  has no referee actor — nobody crosses the ring, so a cover here starts
  at what the footage calls "referee in position". The comparable number
  is therefore ~1.53s (~92 ticks at 60Hz), not 3.60s; `COUNT_TICKS[0]`
  was 60 (1.00s), i.e. the count started faster than the reference by
  about half a second. Adopting the full 3.60s would import ~2s of a
  referee's travel time this project does not simulate.
- Single instance, one pinfall. A referee who happens to be standing next
  to the cover would produce a much shorter lead-in, and nothing here
  measures how much of that ~2.07s is travel versus a fixed pre-count
  beat — that needs a second pinfall with the referee already close.

## Ring-crossing run speed
- (pending — surveyed roughly 400s–600s of `wwe2k26_footage_01.mp4` at 1fps
  looking for a corner-to-corner sprint/Irish whip rebound; this match reads
  as grapple/strike-heavy with big aerial/outside-the-ring spots rather than
  running offense, so no clean instance turned up in the portion reviewed.
  Also checked `wwe2k26_footage_02.mp4` 320s–350s at 5fps (a candidate
  corner sequence) — turned out to be a top-rope/apron dive with a weapon,
  not a ground sprint. footage_02 is a hardcore/weapons match end-to-end
  (confirmed via a 10s-interval survey across its full ~1126s runtime) and
  reads as mat-and-weapons-heavy throughout, not running-offense-heavy, so
  it's a poor candidate for this measurement specifically. Needs a
  non-hardcore clip with a clearer running spot.)
