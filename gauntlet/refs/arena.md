# arena.md — the hall the bowl's shape and look are matched to

Third companion to `ring.md` and `stage.md`. Those record the external ring
and the external entrance set the build's look is matched to; this one records
the external **arena** the seating bowl and the shell are matched to.

Same standing as both: **reference-only**. The photographs under
`refs/arena/` are measurement material, exactly as the footage under
`refs/raw/` is. No model, texture, logo or mark from that building enters the
build as an asset — the bowl is `tools/blender/arena_bowl.py`'s own geometry,
built to the numbers below.

## The material

Four photographs of an ice-hockey arena, supplied by the project owner,
committed under `gauntlet/refs/arena/`. The promotion this build is matched to
plays hockey and basketball arenas rather than purpose-built halls, so the
room the bowl has to be is a rink bowl with the ice covered:

| file | what it establishes |
| --- | --- |
| `arena_bowl_wide_lit.jpg` | the whole bowl in house light: plan shape, two tiers, seat colour, stair nosings |
| `arena_bowl_wide_ribbons.jpg` | the same bowl with the LED ribbon boards lit, so the ribbons' run and count are readable |
| `arena_bowl_corner.jpg` | the bowl from a corner, where the obround plan is most legible |
| `arena_suite_level_ribbon.jpg` | the storey between the tiers in detail: ribbon board, suite/press windows, the deck above |

## What the photographs establish

### Plan shape — the one thing that made this a model rather than boxes

The bowl is an **obround**: two straight sides joined by semicircular ends,
wrapped around a rink. It is not a rectangle with rounded corners and it is
not an ellipse — `arena_bowl_corner.jpg` shows the rows running dead straight
down the sides and turning through a constant radius at the ends, which is
what an offset from a rectangle does and what an ellipse does not.

That is the shape a rink forces: the ice is 61 x 26m with 8.5m corner radii,
the boards are an obround, and every row outside them is that same curve
pushed further out.

| property | reference | build |
| --- | --- | --- |
| plan | obround: straight sides, semicircular ends | offset of a rectangle of half-extents (`BOWL_STRAIGHT_X` 5.0, `BOWL_STRAIGHT_Z` 0.0) |
| ends | true semicircles, no straight run across the end | `BOWL_STRAIGHT_Z` is zero, so the ends are exactly semicircles |
| tiers | two, split by a concourse and a suite storey | `LOWER_ROWS` 12 + `CONCOURSE_DEPTH` 2.6 + `SUITE_HEIGHT` 3.6 + `UPPER_ROWS` 8 |
| entrance end | the set fills one **end**, not a side | stage on -Z, which is an end; the bowl opens for `STAGE_HALF_WIDTH` either side of centre |

**Not matched, and deliberately.** The reference bowl is far bigger than
ours: a lower tier of roughly twenty rows and an upper of roughly the same,
against our 12 and 8. Ours is sized to the ring in front of it and to what a
backdrop may cost, not to a real building's capacity. The *shape* is the
claim here; the *seat count* is not, and nothing in the repo should cite this
file for one.

### The storey between the tiers

`arena_suite_level_ribbon.jpg` and `arena_bowl_wide_ribbons.jpg` establish the
part of a hockey bowl that the old box-stack had no equivalent of at all:
between the two tiers there is a **wall**, not a continuation of the rake, and
it carries

- an LED **ribbon board** running the whole way round, unbroken through the
  corners — which is most of why the bowl has to be a swept curve: a ribbon
  that turns square corners is a scoreboard, not a ribbon;
- a band of **suite and press windows** above it, dark, because the rooms
  behind them are unlit and the glass is returning the bowl;
- a **second ribbon** at the deck line above, so the storey is bracketed by
  two lines of light rather than one.

The build has all three (`SuiteFascia`, `RibbonBoards`, `SuiteGlass` in
`arena_bowl.glb`), at `RIBBON_HEIGHT` 0.55m over a `SUITE_HEIGHT` of 3.6m.

### Seats and stair nosings — measured

Measured off `arena_bowl_wide_lit.jpg`, crop (150,600)-(750,1000), which is
600 x 400px of unobstructed lower-tier seating. Pixels were linearised and
their Rec. 709 relative luminance taken, the same way `measure_frame.py`
does it, so these sit on the same scale as `VISUAL_BAR.md`'s numbers:

| region | selection | mean sRGB | relative luminance | share of the crop |
| --- | --- | --- | --- | --- |
| seat backs | blue-dominant pixels (B > R, B < 120) | (15, 20, 30) | **0.0070** | 76% |
| stair nosings | yellow pixels (R > 120, B < R-40) | (143, 136, 50) | **0.2374** | **0.4%** |

Two things come out of that pair, and both are in the build:

1. **The seats are dark navy, not blue.** 0.0070 is half the crowd's own
   0.014 (`VISUAL_BAR.md`). `arena_seat` is tinted navy and its house-lit
   floor is set to land on 0.0070 (`reach` 1.17 against `HOUSE_TARGET`
   0.006), so the seat rail reads as colour without becoming a light source.
2. **The nosings are 34x the seats and cover under half a percent of the
   bank.** That ratio is the whole effect: a bank of seats reads as a rake
   with stairs in it because of a very small amount of very bright yellow.
   `arena_nosing` is emissive at 0.28 linear against the seat's 0.0070 — a
   40:1 ratio on geometry that is two triangles per tread per aisle.

The photograph is a house-lights-up daylight-white frame and the build's hall
is a dark show, so the absolute levels above are **not** transferable and are
not transferred. What is taken from them is the two relationships: navy under
the crowd, and a thin very bright line up every aisle.

### What the photographs do not establish

- Ribbon board *content*. The reference boards carry advertising; ours carry
  a flat amber, because at 20-35m a 0.55m board is under two pixels of text
  and what a real one contributes at that size is a band of warm light.
- Roof structure. Every camera in the shotlist is under the truss looking at
  the ring, so the roof stays a slab and the photographs' catwalks, rigging
  and scoreboard are not built.
- Lighting levels, per the note above.
