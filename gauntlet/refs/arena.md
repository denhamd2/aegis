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
| plan | obround: straight sides, semicircular ends | offset of a rectangle of half-extents (`BOWL_STRAIGHT_X` 4.425, `BOWL_STRAIGHT_Z` 21.95) |
| ends | true semicircles, no straight run across the end | the rectangle's corners carry the whole turn, so every end is exactly a semicircle of the offset's radius |
| tiers | two, split by a concourse and a suite storey | `LOWER_ROWS` 12 + `CONCOURSE_DEPTH` 2.6 + `SUITE_HEIGHT` 3.6 + `UPPER_ROWS` 8 |
| entrance end | the set fills one **end**, not a side | stage beyond the boards on -Z, which is an end; the bowl opens for `STAGE_HALF_WIDTH` either side of centre |

### Scale — the rink is the ruler

The building is dimensioned from a **regulation sheet of ice**, not from the
ring: 200 x 85 feet with 28-foot corners, which is 60.96 x 25.91m with an
8.53m radius. That is an external fact about the sport rather than something
these photographs measure, and it is used as one: the photographs establish
that the room is a rink bowl, and the rulebook says how big a rink is.

The identity that makes it cheap is that **a rink is its own corner radius
offset from a rectangle** — the same construction the bowl already used. So
one rectangle generates the whole building:

| offset from the plan rectangle | what is there |
| --- | --- |
| 8.53m (`RINK_CORNER_RADIUS`) | the boards, and the edge of the decked floor |
| 10.13m (`BOWL_FIRST_ROW`) | the first row of the bowl, with the walkway between |
| +12 x 0.95m | the lower tier |
| +2.6m, +3.6m up | the concourse and the suite storey |
| +8 x 0.95m | the upper tier |
| 33.5m | the shell wall |

which is a hall 76 x 111m on plan, roofed at 21m. A real arena of this rink's
era is 100-120m long. Before this the bowl's first row sat 9m from the ring on
a 28 x 18m plan — about a third of a rink — and the ring filled a room the
size of a sports hall.

**The ring is in the middle of the rink**, which is where it goes and which
`test_arena_bowl.gd` asserts off the shipped mesh rather than off intent. The
barricade is unmoved at 9m from the ring, so what the scale change actually
produced is ~20m of open floor between the barricade and the boards at each
end — and that floor is now full of seats (`_build_floor_seats`, ~1,490
chairs), which is what a real arena does with it.

**Not matched, and deliberately.** The reference bowl still has more rows than
ours: roughly twenty in each tier against our 12 and 8. Its *plan* is now
measured; its *seat count* is not, and nothing in the repo should cite this
file for one. The build seats ~6,700 in the bowl and ~1,490 on the floor,
which is a fraction of a real building's 17,000.

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

1. **The seats are dark navy, not blue.** 0.0070 is half the level
   `VISUAL_BAR.md` measures the *reference footage's* crowd at (0.014).
   `arena_seat` is tinted navy and its house-lit floor is set to land on
   0.0070 (`reach` 1.17 against `HOUSE_TARGET` 0.006), so the seats read as
   colour without becoming a light source.
2. **The nosings are 34x the seats and cover under half a percent of the
   bank.** That ratio is the whole effect: a bank of seats reads as a rake
   with stairs in it because of a very small amount of very bright yellow.
   `arena_nosing` is emissive at 0.28 linear against the seat's 0.0070 — a
   40:1 ratio on geometry that is two triangles per tread per aisle.

The photograph is a house-lights-up daylight-white frame and the build's hall
is a dark show, so the absolute levels above are **not** transferable and are
not transferred. What is taken from them is the two relationships: navy seats
well under the level a crowd would read at, and a thin very bright line up
every aisle.

### Seats, not a slope

The reference photographs are of an **empty** bowl. **The build is not**: the
bowl carries ~5,760 people (`tools/blender/crowd.py`), and has since the crowd
came back. This section used to assert "which is also what the build is now —
there is no crowd in the hall", and that had stopped being true without being
corrected.

The disagreement is real rather than an oversight to tidy away. This file's
photographs are of an empty house; `lighting.md`'s four are of full ones; and
the AEW wide supplied later is of a full one. The build follows the full-house
references, so what this section's measurements still govern is the **seats
themselves** — their colour, their pitch, and the nosing ratio below — not
whether anybody is sitting in them. That makes one more thing
load-bearing: at the crop above, individual seat backs are legible, separated
by a dark gap of roughly a sixth of their pitch, and the rows read as
something countable rather than as a navy ramp.

So the model builds a seat per `SEAT_PITCH` (0.62m) at `SEAT_WIDTH_FRACTION`
0.84 of it, with the aisles left clear, rather than the continuous rail it
carried while a crowd sat in front of it. That is ~6,700 seats at rink scale
and it is most of the model's 102k triangles — spent where the crowd's own
instances used to be, in a hall that no longer draws them.

### What the photographs do not establish

- Ribbon board *content*. The reference boards carry advertising; ours carry
  a flat colour, because at 20-35m a 0.55m board is under two pixels of text
  and what a real one contributes at that size is a band of light.

  **The colour is no longer amber.** These photographs are house-lit and
  empty, and a warm ribbon is what that room has; the AEW wide supplied later
  shows the same class of building with the show running and its ribbons cool
  blue, like every other lit surface in the hall. Measured, ours were also the
  single dominant feature of a wide frame — `bowl_end` at p99 0.4767 with two
  saturated amber hoops carrying most of the hot fraction, against a frame
  mean saturation of 0.673 to the reference's 0.511. `arena_ribbon` is cool
  now; see the note on that key in `material_library.gd`.
- Roof structure. Every camera in the shotlist is under the truss looking at
  the ring, so the roof stays a slab and the photographs' catwalks and
  scoreboard are not built.

  The **rigging** is a partial exception now. The truss grid carries fixture
  bodies (`entrance_set.py:build_truss_fixtures`), because it was hanging ~30
  invisible `Light3D`s and reading as bare pipe — a hall lit from nowhere. The
  bodies and their lenses are built; the catwalks and the roof steel above
  them still are not.
- The **wall above the upper deck**, which these photographs show hung with
  banners and which the build left as bare shell. It carries banners now
  (`arena_bowl.py:build_banners`): our `bowl_end` frame measured 70.8% of
  pixels below 0.01 against the supplied AEW wide's 37.6%, and most of that
  black was this wall.
- Lighting levels, per the note above.
