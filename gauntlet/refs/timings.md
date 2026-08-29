# timings.md — measured, not remembered

Every number here must trace to a frame-stepped source clip under
`gauntlet/refs/raw/`. Format: `value — source clip, timestamp, frame-step
method (e.g. "ffmpeg -vf select, 30fps source")`.

Status: **seeded with real frame-stepped measurements.** Source clip:
`gauntlet/refs/raw/video/wwe2k26_footage_01.mp4` (WWE 2K26 gameplay,
640x360 30fps, ~13min, user-supplied download — gitignored, stays local).
Method throughout: `ffmpeg -ss <t> -to <t> -vf fps=30 out%04d.png`, then
visual inspection frame-by-frame. Timestamps below are absolute position in
that file. **This file is one clip's worth of measurement, not a
cross-checked corpus** — treat single-instance numbers as a first data
point to refine with more clips/matches, not a settled constant.

**Note on clip structure:** this file is a multi-match compilation with
hard cuts between different pairings (confirmed at ~227.2s, where a visible
mid-grapple cut jumps to an entirely different match) — always confirm a
measured sequence doesn't straddle a cut before citing a number from it.

## Getup duration
- **~2.10s (63 frames @ 30fps)**, rise-start to standing/fight-ready —
  `wwe2k26_footage_01.mp4`, 366.07s (`frames/getup_rise_start.jpg`, first
  visible push-off-the-mat frame) to 368.20s (`frames/getup_standing.jpg`,
  first frame both feet planted in a fighting stance), Goldberg vs. Brock
  Lesnar, SmackDown. This is the *animation* duration only — the wrestler
  was actually prone from ~358.6s to 366.07s (~7.5s), but most of that gap
  is the attacker's own taunt animation playing out, not a fixed
  knockdown timer, so it isn't cited as "getup duration" here.
- Compare: `WrestlerController.GETUP_TICKS = 90` (1.5s @ 60Hz) in
  `game/core/match/wrestler_controller.gd` is faster than this one
  measurement — worth another data point before retuning, but a real gap
  worth flagging for whoever owns that constant later.

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

## Reversal window length
- (pending — needs a frame-stepped reversal input-to-window sequence, not
  found yet in this clip)

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
- (pending — this clip's visible finish (~750s) cuts to a slow-motion
  finisher **replay package** — confirmed by an on-screen "REPLAY" badge,
  which is broadcast-edited slow-motion, not the actual live pace, so it's
  explicitly excluded rather than mismeasured. Need a clip with an
  on-screen pinfall count that isn't inside a replay package.)

## Ring-crossing run speed
- (pending — needs a running sequence across a known ring dimension; not
  yet isolated from this clip)
