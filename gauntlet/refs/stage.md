# stage.md — the entrance set the build's look is matched to

Companion to `ring.md`. That file records the external ring the ring's *look*
is matched to; this one records the external **entrance set** the stage, the
portals and the video wall are matched to.

Same standing as `ring.md`: reference-only. The photographs under
`refs/stage/` are measurement material, exactly as the footage under
`refs/raw/` is. No model, texture, logo or mark from that set enters the
build as an asset.

## The material

Five photographs of the AEW *Dynamite* set, supplied by the project owner,
committed under `gauntlet/refs/stage/`:

| file | what it establishes |
| --- | --- |
| `dynamite_stage_wide.jpg` | the whole set square-on: screen, portals, backdrop, deck |
| `dynamite_stage_head_on.webp` | portal spacing and the screen's overhang either side of them |
| `dynamite_stage_from_the_seats.jpg` | how the set reads from a seat, i.e. at the distance `stage_wide` shoots it |
| `dynamite_stage_low_angle.jpg` | the screen's curvature, read against the truss line behind it |
| `dynamite_portals_close.jpg` | the portals in detail — the circle, the cut, the slat fans |

Plus the graphics-package clip that plays on the wall, supplied with them and
committed as `game/assets/environment/video/dynamite_tron.ogv`. See
`game/assets/environment/CREDITS.md` for its provenance.

## What the photographs establish

Proportions, read off `dynamite_stage_wide.jpg` and
`dynamite_stage_head_on.webp`:

| property | reference | build |
| --- | --- | --- |
| screen aspect | about 3:1 | 18.0 x 6.0 = 3.0:1 |
| screen curve | gently wrapped, concave toward the crowd; not a cylinder | 1.6m of sagitta over 18m, about 5 degrees of toe-in per end |
| screen overhang | wider than the two portals together | portals span 0.63–5.97 either side; screen spans ±9.0 |
| portal shape | **a circle with the bottom cut off** by the deck | circle sunk 0.25m into the deck; 308 degrees of tube, ending where it meets the floor |
| portal count and colour | two, one magenta, one amber | `arena_portal_magenta` / `arena_portal_amber` |
| slat fan | straight lit strips inside each portal, on its outboard side, clear of the walkway | 13 slats over 45 degrees, centred on the outboard horizontal |
| backdrop | perforated dark panel, uplit in the portals' colours | `arena_stage_panel` plus four uplights |
| deck | dark and reflective; the set is legible in it | roughness 0.14 plus `ssr_enabled` |

Palette, sampled off the photographs: a cool violet house wash, with warm
magenta and amber accents carried by the portals and thrown onto the deck,
the slats and the backdrop. Warm and cool at the same time is the set's whole
look, and the coloured shafts standing in the haze around the portals are
most of what carries it.

## What this does not govern

The bowl, the barricade, the ringside slab, the truss and the ring itself.
Those are `ring.md`'s and `VISUAL_BAR.md`'s, and nothing here may be used to
argue for moving a number either of them owns — in particular the mat's
0.43–0.49 exposure anchor, which every fixture added for this set is
range-limited specifically to stay away from.

The set's *scale relative to the hall* is also not governed here. The
reference set spans the whole end of a real arena; this hall's seating bowl
comes within six metres of the stage line, so the backdrop is mostly hidden
behind the portals and the near rows. That is a property of the bowl, not a
failure to match the photographs.

### One shape worth being explicit about

A portal is **a circle with the bottom cut off by the deck**. Nothing more
complicated than that, and it took three wrong shapes to arrive at it:

- a **closed ring**, which has no doorway in it and reads as a neon hoop hung
  on a wall;
- an **omega**, which is what you get by opening a ring with a gap at the
  bottom -- the curve carries past the sides and round toward the floor, the
  ends finish pointing inward, and the outward feet needed to plant them are
  an omega's serifs;
- an **arch on two straight legs**, which is a different piece of set again:
  it stops curving at the sides, so it never reads as a circle.

The correct construction is to place the circle so its lowest point is *below*
the deck and let the tube stop wherever it meets the floor. The cut angle is
then derived rather than chosen, and the shape is a circle by construction
rather than by resemblance. `dynamite_portals_close.jpg` is the frame that
settles it.
