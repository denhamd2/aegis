# FEEL_BAR.md — one-page anchor

The single page every feel-quality gauntlet critic (locomotion & strike
feel, grapple chain quality, reversal windows) holds in mind.

**Status: placeholder — fill in once `gauntlet/refs/timings.md` and
`feel.md` have real measurements from Phase 1.**

## What "ours" must match, in priority order

1. Reversal windows are tight and readable — a defender who reacts within
   the measured window (see `timings.md`) succeeds; outside it, fails,
   with no perceptible slop at the boundary (see
   `game/tests/test_move_def_reversal_window.gd`).
2. Strike/grapple startup and recovery match measured cadence closely
   enough that trading blows feels like the reference, not floaty or
   twitchy.
3. Getup and stun durations match measured pacing — this is what makes a
   match feel like it has weight rather than being a button-mash loop.
4. Input-to-action latency is at or below the measured bar in `feel.md`.

## What it explicitly does not require

- Matching frame data exactly to the integer tick — within a few ticks of
  the measured value is a pass; the critic's job is to flag drift that's
  perceptible, not drift that's measurable.

## Judging method

- A capture settles startup/recovery/reversal-window timing (frame-cited
  against `timings.md`).
- A capture cannot fully settle input latency or overall "feel" — per
  ARCHITECTURE.md, a human plays a match on a gamepad (`godot --path game`)
  before a feel slice is signed off, capture or no capture.
