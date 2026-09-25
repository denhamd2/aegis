# lighting.md — measured, not remembered

Arena lighting reference, measured off the stills in `gauntlet/refs/lighting/`.

## What these are, and what may be taken from them

Four photographs of AEW Dynamite shows in hockey-plan arenas — the same
building class `arena.md` already measures the bowl against.

They are used here the way every other file in `gauntlet/refs/` is used: as a
**measurement of how a televised wrestling hall is lit**. Colour temperature,
contrast ratio, beam angle, haze density and the luminance distribution are
physical properties of a lighting design, and they are what this file records.
What is taken from these four stills is those numbers and nothing else.

What the project's policy on marks and likeness actually is, this file does not
say, because the repository does not currently agree with itself:
`VISUAL_BAR.md` says likeness, moveset and branding are "nothing is off
limits", while `CLAUDE.md` says footage is a measurement and "the assets stay
original". The build ships AEW marks and real wrestler names, so it follows the
first. That contradiction wants resolving somewhere with the authority to
resolve it; a lighting reference is not that place.

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
| ours, `wide_broadcast` | 0.025 | 0.454 | 0.723 | 5.5% | 16.3% | 0.293 | 52.1% |
| ours, `ring_corner` | 0.010 | 0.023 | 0.625 | 2.4% | 50.7% | 0.379 | 58.6% |
| ours, `crowd_bank` | 0.016 | 0.023 | 0.454 | 0.1% | 3.1% | 0.372 | 86.7% |
| ours, `arena_shot` (close) | 0.023 | 0.501 | 0.665 | 10.1% | 1.9% | 0.297 | 52.2% |

Compare like framings. The first pass at this measured only `arena_shot`, a
close match-camera view that is most mat and skin, and read its 1.9% dark and
0.297 saturation as a whole-hall verdict. It is not one: `ring_corner` measures
50.7% dark, inside the reference band, and `crowd_bank` measures 86.7%
coloured, also inside it. The art shotlist
(`--art-shots`) is the fair comparison because it holds framing fixed.

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

**3. Colour is closer than it first looked, and dynamic range is not.** Mean
saturation 0.49–0.67 against our 0.29–0.38 is a real gap, but the *coloured
fraction* of our bowl (86.7% on `crowd_bank`) already sits inside the
references' 72–95%. What the bowl has no trace of is range: `crowd_bank` runs
p50 0.016 to p90 0.023 — the entire stand lives inside a 0.007 band, with 0.08%
of it above 0.5. The references put bright fixtures, an LED wall and beams
through a dark crowd, spanning p50 0.011 to p99 0.64–0.94. Ours is a uniform
dim field of one hue, which is a different defect from "not colourful enough"
and has a different fix.

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
crowd should sit just above the void floor, and `crowd_bank`'s p50 of 0.016
says it roughly does. Void fraction currently measures 0.000–0.003 against the
references' 0.010–0.066, so there is headroom to darken — being under that band
is not itself a failure, but it is where the room is.

## Measured: where the hall's light actually comes from

Before tuning anything, four renders settled where the brightness in our own
frames originates. They are worth recording because the answer is not the light
rig, and every plausible lighting fix was aimed at the wrong subsystem.

`wide_broadcast`, relative luminance, with `house_energy` ablated:

| region | shipped (0.20) | ablated (0.0) | 60x (12.0) |
| --- | --- | --- | --- |
| bowl_mid | 0.042 | 0.042 | 0.042 |
| roof | 0.041 | 0.041 | 0.041 |

**The twenty-fixture house wash contributes nothing measurable to the stands.**
Turning it off entirely and turning it up sixty-fold produce the same frame to
three decimal places. The bowl is lit by `ArenaBuilder._house_lit()` emission
and by nothing else — which is the exact arrangement `arena_lighting.gd`'s own
header describes as the thing it replaced. The fixtures reach the near rows in
`crowd_bank` slightly (mean saturation moves 0.372 to 0.395 at 60x) and the far
bowl not at all.

So the hall's contrast is governed by `ArenaBuilder.HOUSE_TARGET` (0.006) and
the per-part `reach` multipliers in `BOWL_MODEL_MATERIALS`, not by anything in
the lighting rig. A darker or more saturated house wash changes a flat
self-illuminated field into a slightly different flat self-illuminated field.

### And there is no crowd

`crowd_bank` renders empty seating. The four reference frames are 60%+ densely
packed people, and people are most of what a televised bowl's texture, colour
variation and mid-tone mass actually are. This is the largest single difference
between our frames and the references, it is geometry rather than lighting, and
no lighting change addresses it.

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

## Round: beams and a coloured crowd wash

Two things the four stills carry and the build did not, both off the ring so
the anchor cannot move.

**The crowd sat in white light.** Its hue was already right -- 94% of
`crowd_bank`'s saturated pixels at hue 210, the same family as the stills'
210-240 -- but its coloured-pixel mean was (0.14, 0.18, 0.22) against the Grand
Slam frame's (0.09, 0.14, 0.27): blue-grey, not blue. `ArenaBuilder.CROWD_WASH`
tints the crowd's house light, normalised to Rec.709 luminance ~1.0 so the
level (VISUAL_BAR.md's 0.014) is unchanged. Alone: sat 0.408 -> 0.438.

**There were no beams.** Every still has shafts of blue, violet and magenta
standing in the haze over the crowd. `ArenaLighting._build_beams()` hangs
sixteen 6-degree moving heads on the roof grid, aimed out over the bowl. The
first two attempts showed nothing at energy 6 and 200 -- `_spot()`'s 1.6
falloff over a 20m throw delivers ~1/120 of a fixture, which is also why the
house wash ablation above measured zero. The beams use 0.8 and put most of
their energy into the haze (`beam_fog_energy`). Sweep in the constant's
comment.

| frame | | mean sat | dark <0.01 | p50 |
| --- | --- | --- | --- | --- |
| `crowd_bank` | before | 0.408 | 6.7% | 0.0198 |
| | after | **0.493** | 7.2% | 0.0247 |
| `ring_corner` | before | 0.342 | 44.6% | 0.0107 |
| | after | 0.412 | 41.2% | 0.0113 |
| `stage_wide` | before | 0.378 | 2.6% | 0.0304 |
| | after | 0.419 | 2.6% | 0.0337 |
| `wide_broadcast` | before | 0.369 | 9.5% | 0.0345 |
| | after | 0.401 | 9.6% | 0.0377 |
| references | | 0.487-0.665 | 38-50% | 0.010-0.024 |

`crowd_bank` is inside the reference saturation band for the first time.
Anchor, `measure_silhouette.py`: mat 0.453 -> 0.450 (band 0.43-0.49), both
wrestlers unchanged to three places. `test_arena_beams.gd` holds the
renderer-free half: no beam within five cone-widths of the mat, no
green-dominant beam, the wash leaves the crowd's level alone.

### Still open, and not lighting

- **Dark fraction on the wide framings** (`wide_broadcast` 9.6%,
  `stage_wide` 2.6%) is framing, as above: those shots are ring and set, the
  stills are mostly bowl.
- **The overhead rig itself.** The stills show the lit grid -- truss, fixture
  bodies, LED edge strips -- and ours is a black roof. That is geometry.
- **Beams are static.** A real moving head sweeps; frame-stable captures are
  worth more than that.
- **Web build** has no beams, since it has no volumetric fog to put them in.
