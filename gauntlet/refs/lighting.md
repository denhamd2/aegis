# lighting.md — measured, not remembered

Arena lighting reference, measured off the stills in `gauntlet/refs/lighting/`.

## What these are, and what may be taken from them

Four photographs of AEW Dynamite shows in hockey-plan arenas — the same
building class `arena.md` already measures the bowl against.

They are used here the way every other file in `gauntlet/refs/` is used: as a
**measurement of how a televised wrestling hall is lit**. Colour temperature,
contrast ratio, beam angle, haze density and the luminance distribution are
physical properties of a lighting design, and they are what this file records.

Nothing else is taken from them. The project's assets stay original — no AEW
marks, no LED-wall content, no stage-portal shapes, no ring-skirt graphics.
That line is the reason the reference-matching skills were deleted (see
CLAUDE.md): footage here is a measurement, and the build is not a
reconstruction.

## Measure them with

    python3 tools/refs/measure_look.py --refs [our_frame.png]

`measure_frame.py` reads named rectangles and is the right tool once you know
where the mat is. It is the wrong tool for "does this look like a televised
arena", because that answer is not in any one region — it is in how the whole
frame is distributed. The first attempt at this measured a "mat" patch on
`aew_elevated_blue_beams.jpg` at sd 0.234, which is a rectangle straddling
three different things.

## The measurement

| frame | p50 | p90 | p99 | bright >0.5 | dark <0.01 | mean sat | coloured |
| --- | --- | --- | --- | --- | --- | --- | --- |
| elevated, blue beams | 0.024 | 0.323 | 0.944 | 6.1% | 38.4% | 0.487 | 71.9% |
| Grand Slam broadcast | 0.011 | 0.088 | 0.644 | 1.5% | 47.5% | 0.640 | 91.0% |
| low angle, LED wall | 0.012 | 0.139 | 0.899 | 3.0% | 45.0% | 0.665 | 94.9% |
| wide bowl, magenta | 0.010 | 0.262 | 0.651 | 2.4% | 50.0% | 0.580 | 82.9% |
| **ours** (`arena_shot`, forward_plus) | 0.023 | **0.501** | 0.665 | **10.1%** | **1.9%** | **0.297** | **52.2%** |

### What it says

**1. A televised arena is mostly dark.** 38–50% of every reference frame is
essentially black. Ours is 1.9%. This is the single largest structural
difference and it is the prerequisite for everything else: beams, haze, rim
separation and bloom are all effects that need darkness to read against.

**2. The bright fraction is small and very bright.** The references put
1.5–6.1% of the frame above 0.5, with p99 up at 0.64–0.94 — a small number of
genuinely hot sources. Ours puts 10.1% above 0.5 but tops out at p99 0.67:
more of the frame is bright, and nothing in it is actually hot. Our p90 of
0.501 sits where their p99 range begins.

**3. The hall is saturated colour, not neutral.** Mean saturation 0.49–0.67
and 72–95% of pixels meaningfully coloured, against our 0.30 and 52%. The
signature of this look is magenta / purple / deep blue wash across the bowl,
the truss and the crowd, with the ring itself the one broadcast-neutral pool
in the middle. Ours is a single navy.

## What this does NOT license

`VISUAL_BAR.md` already measures the exposure anchor off
`frames/wide_standoff_broadcast_angle.jpg`, and it wins:

- the mat renders at **0.43–0.49** relative luminance;
- a wrestler sits **0.24–0.31 below** it;
- the crowd sits at **0.014**, dim but ~5x above the void floor.

So "make the hall dark" means **darken everything that is not the ring**. Any
change that moves the mat off its anchor, or closes the mat↔wrestler gap, has
broken the bar that actually governs — the priority-1 silhouette measurement —
in pursuit of the priority-2 one. `measure_silhouette.py` is the check.

Note the crowd's 0.014 and this file's "38–50% below 0.01" are consistent: the
crowd should sit just above the void floor, which is roughly where our 1.9%
says it currently does not.

## Volumetric fog

Already implemented — `ArenaLighting._build_fog_volumes()` builds a ring haze
and a hall haze, every key fixture carries a `light_volumetric_fog_energy`, and
there is a `forward_plus` guard with a depth-fog fallback for
`gl_compatibility` (FogVolume is forward_plus only; a `shader_type fog`
material fails to compile on the OpenGL renderer).

It is therefore not the next lever. Fog renders light shafts by scattering
light through a volume, and a shaft is only visible as a *contrast* against
what is behind it — so adding density to a hall that is 1.9% dark buys almost
nothing. Contrast first, then the fog that already exists starts to read.

No performance claim can be made about it from this environment:
ARCHITECTURE.md's renderer rule voids frame-cost numbers taken off a software
rasteriser, and volumetric fog is exactly the kind of effect that misleads
there.
