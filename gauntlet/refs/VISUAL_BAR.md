# VISUAL_BAR.md — one-page anchor

The single page every visual-quality gauntlet critic holds in mind. Keep it
short. Update it only from measured reference material (`gauntlet/refs/`),
never from memory of "what WWE games look like."

**Status: placeholder, partially informed.** `gauntlet/refs/frames/` and
`gauntlet/refs/hud/` now have labeled reference stills (see `camera.md` /
`hud.md`) — enough to ground the priorities below, not enough to close
Phase 1: those are individual screenshots, not frame-stepped clips, so
nothing timing-based (`timings.md`, `feel.md`) is covered yet. Treat this
bar as informed-placeholder, not final, until real footage lands.

## What "ours" must match, in priority order

1. Silhouette readability at match-camera distance (both wrestlers legible
   mid-grapple, not just in idle poses).
2. Lighting consistency: ring lighting reads as one scene, not
   independently-lit props.
3. Material believability at the resolution/distance the match camera
   actually uses — not close-up turntable quality.
4. HUD legibility against the ring background across the a full match's
   lighting range (entrance flash, ring lights, replay/finisher cuts).

## Silhouette separation, measured

Priority 1 above was a phrase a critic had to judge by eye, which is the
kind of claim `ARCHITECTURE.md`'s reference-driven-tuning rule exists to
stop. It is a number now. `tools/refs/measure_frame.py` reads relative
luminance (Rec. 709, on linearised sRGB) out of named regions of any frame
— a reference still or one of our own captures — so both are measured the
same way.

Off `frames/wide_standoff_broadcast_angle.jpg`:

| pair | ΔL |
| --- | --- |
| mat ↔ wrestler (left) | 0.310 |
| mat ↔ wrestler (right) | 0.240 |
| wrestler ↔ wrestler | 0.070 |

Two different mechanisms, and this is the part worth holding on to: a
wrestler separates **from the mat by value** (0.24–0.31 apart, both darker
than it) and **from the other wrestler by hue**, not by brightness — 0.07
in value is nothing. A build that gives both men the same value as each
other is following the reference; one that gives either of them the mat's
value is not.

### Reading the same numbers off our own frames

The table above is measured off *rendered pixels*. For a while ours were
checked in *albedo* instead -- `test_wrestler_colorway.gd` asserted a
wrestler's albedo sat 0.24-0.31 from the mat's albedo and passed, while the
build's actual frames measured 0.161. Two different quantities wearing the
same number.

`tools/refs/measure_silhouette.py` closes that. The capture harness's
`--silhouette-shot <prefix>` mode renders the spawn standoff plus a
segmentation mask that keys the mat and each wrestler (gear included); the
script averages the beauty frame inside each key and reports the same three
pairings. A mask rather than rectangles, because a rectangle over a wrestler
also catches mat, rope and shadow.

    xvfb-run -a godot4 --path game --rendering-driver vulkan \
        --resolution 1280x720 scenes/match.tscn -- --silhouette-shot /tmp/shot
    python3 tools/refs/measure_silhouette.py /tmp/shot

**Read the driver flag above carefully, and do not change it back.** That
command said `opengl3` for two rounds, and the numbers it produced were
`gl_compatibility` numbers -- a renderer `project.godot` does not ship. The
same scene, measured the same way, one frame apart:

| pair | `gl_compatibility` | `forward_plus` (ships) | reference |
| --- | --- | --- | --- |
| mat luminance | 0.458 | **0.172** | 0.46 |
| mat <-> wrestler A | 0.290 | **0.094** | 0.24-0.31 |
| mat <-> wrestler B | 0.291 | **0.044** | 0.24-0.31 |
| wrestler <-> wrestler | 0.001 | **0.050** | 0.00-0.07 |

So the round-2 result -- "all four figures inside the reference band" -- was
true of a renderer nobody plays on. On the shipping one, three of the four
are outside it and the mat is at 37% of its anchor. The exposure anchor has
to be re-solved on `forward_plus`, and that is a lighting job, not a
material one. One thing did get *better*: A<->B is 0.050 against the
reference's own 0.070, where `gl_compatibility` flattened it to 0.001.

**The mat's own number is an exposure anchor, not a bar.** The wrestler
figures are absolute luminances, and comparing those between a broadcast
still and our render only means anything once the brightest surface both
share is matched. Ours reached 0.458 only after the ring rig went from 2.2 to
4.5; before that the mat rendered at 0.276, and a 0.24-0.31 gap *below* it
was arithmetically impossible -- the ceiling was 0.276.

`test_wrestler_colorway.gd` now asserts the renderer-independent mechanisms
instead: skin darker than the mat, the two complexions within 0.07 of each
other, hue separation, and that the gear carrying the colourway exists.

## Background presence, measured

The same tool reports `void_fraction`: the share of the frame that is both
dark and *flat* — pixels below a luminance floor, with the frame's standard
deviation reported alongside so "dark" and "nothing modelled there" can be
told apart. The reference frames measure 0.010–0.066 in-frame (the wide
standoff reads 0.251, but that shot is letterboxed and the bars are most of
it). A real arena is dark above the ring; it is not *empty* above the ring.

This is a coverage measurement, not a lighting-quality one, so it is one of
the few visual numbers a software render can legitimately move.

## What it explicitly does not require

- Photorealism. The bar is WWE 2K's presentation *language* (framing,
  lighting consistency, HUD clarity), not its polygon/texture budget.
- Matching any specific WWE 2K wrestler's likeness, moveset, or branding.
  The reference frames are here for framing, lighting and HUD measurements;
  a critic that flags "doesn't look like [real wrestler]" is measuring
  something this bar does not ask for.

## Known gap sources to check first

- **Check the pipeline, not the rasteriser** — see ARCHITECTURE.md. A
  `gl_compatibility` capture cannot judge this bar (no SSAO/SSR/SDFGI/
  volumetric fog, different tonemapping); a `forward_plus` capture can, even
  if a CPU rasterised it. Confirm `pipeline` in the manifest before citing a
  visual gap, and never cite a software capture for frame cost.
