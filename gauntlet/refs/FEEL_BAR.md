# FEEL_BAR.md — one-page anchor

The single page every feel-quality gauntlet critic holds in mind.

## Why this page was rewritten

Its previous priority #1 was **reversal windows**, and that entry was wrong
twice over. The reversal mechanic had been removed from the game — the paired
counter animations were cut because they did not read on screen, and nothing
replaced them, so a strike in this match loop now always resolves. And the
quantity it asked a critic to judge against had never been measured:
`timings.md`'s reversal-window section is still `(pending)`.

So the top line of this project's feel bar described a mechanic that did not
exist, against a number that did not exist, and nobody noticed for several
rounds. Two rules come out of that, and they are the point of this rewrite:

- **A bar names the behaviour the game actually has.** When a mechanic is
  removed, its bar goes with it.
- **A bar names what settles it.** A bar with no test, tool, capture or
  measured reference behind it cannot be judged, only asserted — which is how
  the reversal entry survived. Each item below names its enforcer.

See `gauntlet/anchor/MATCH_FLOW.md` for what the match is *for*; this page is
only about whether it feels right.

## What "ours" must match, in priority order

1. **Strike startup and recovery match the measured cadence**, closely enough
   that trading blows reads like the reference rather than floaty or twitchy.
   Measured in `timings.md`: jab windup-to-contact 0.133s; the isolated heavy
   strike 0.300s startup and 0.73–0.80s contact-to-guard.
   *Settled by:* `tests/test_strike_and_getup_timings.gd`, plus a capture
   frame-cited against `timings.md`.

2. **A strike connects where the limb is.** Each move reaches as far as its own
   limb and no further, forwards only. This is the difference between a punch
   that lands on a man and one that lands on a proximity check — the latter
   shipped for a long time and is most of why strikes read as not connecting.
   *Settled by:* `tests/test_strike_contact_volume.gd`,
   `tools/anim/measure_contact_offsets.gd`.

3. **Getup and stun durations match measured pacing.** This is what gives a
   match weight instead of a button-mash loop. `timings.md` measures two rises,
   not one: ~2.10s default and ~1.14s when the wrestler triggers a quick
   recovery himself.
   *Settled by:* `tests/test_strike_and_getup_timings.gd`.

4. **The three-count is uneven and it flashes.** "1" to "2" is ~1.25s and "2"
   to "3" ~1.00s — a real count hangs on the first slap and speeds into the
   third. The digits pop in and go away again rather than sitting there.
   *Settled by:* `MatchReferee.COUNT_TICKS` / `COUNT_VISIBLE_TICKS` against
   `timings.md`, and a capture's `three_count` beat.

5. **A near-fall reads as a near-fall.** A kickout should land late in the
   count, not before the referee's first slap. When the fall lengthened and the
   kickout threshold did not, every escape moved to before the first slap and
   stopped reading as a near-fall at all.
   *Settled by:* `tests/test_pin_minigame_kickout.gd`.

6. **Feet do not skate and cycles do not pop.** A planted foot travels backward
   at exactly the speed the engine carries the body forward; a looping clip's
   closing pose equals its opening pose.
   *Settled by:* `tools/anim/gait_audit.gd`.

7. **Input-to-action latency is at or below the bar in `feel.md`.**
   *Settled by:* nothing yet — `feel.md` is still empty, and this is the one
   number that is hardest to get from video at all, since video framerate and
   input polling are different clocks. Until it is measured this is an
   aspiration, not a bar, and it is listed last because of that.

## What it explicitly does not require

- **Frame-exact timing.** Within a few ticks of the measured value is a pass.
  The critic's job is to flag drift that is perceptible, not drift that is
  merely measurable.
- **Reversals, submissions, or a neutral game.** None are in the match loop;
  see `MATCH_FLOW.md`, "What is deliberately absent". A critic who marks the
  match down for lacking them is marking it against a game that was
  deliberately not built.

## Judging method

- A capture settles startup/recovery timing and the count cadence, frame-cited
  against `timings.md`.
- The tools and tests named above settle everything mechanical — reach,
  alignment, skate, seams. Run them; do not eyeball them. Every defect they
  catch was invisible in the source tables and obvious in the numbers.
- A capture **cannot** settle input latency or overall feel. Per
  ARCHITECTURE.md, a human plays a match on a gamepad (`godot --path game`)
  before a feel slice is signed off, capture or no capture.

## Known stale references

`tests/test_move_def_reversal_window.gd` still exercises
`MoveDef.is_in_reversal_window()`. The field is kept deliberately — those are
measured frame numbers and re-measuring later is more work than carrying them —
but nothing in the match reads it, so that test guards a function with no
consumer. It is not a feel bar and should not be treated as one.
