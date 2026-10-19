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

## The 2026 set (the owner, 18 October 2026) -- supersedes the portals

Eight stills of the updated AEW *Dynamite* set, committed as
`gauntlet/refs/stage/dynamite_2026_1.jpg` .. `_8.jpg`. They replace the
portal set below wherever the two disagree.

| property | reference | build |
| --- | --- | --- |
| entrances | **no portals**: the men walk out of the centre, in front of the centre screen | `ArenaBuilder.ENTRANCE_X/Z`; every entrance routine starts there |
| side walls | two tall LED walls either side of the centre screen, splayed slightly away from the ring (inner edges nearest the camera, per the Omega and Copeland close-ups), playing the video wall's picture | `StageSideScreens` (`SIDE_SCREEN_*`), 4.9 m wide, 5.4 m tall, splayed 10 degrees (`SIDE_SCREEN_TOE_DEG` -10), inner edges 1.2 m off the back wall; `StageVideo.mirror` crops the clip to their shape at 0.28 of the wall's level |
| video wall, centre screen | unchanged | unchanged |
| ramp | plain black, no coloured edge strips | `RampLeds` removed |
| beyond the walls | black | LED dot columns and lit side panels removed; drape from the walls outward |
| floor | a row of small red cans along each wall's foot | `StageFloorCans`, red, over the glow threshold |
| beams | white shafts fanning up and out from the deck around the walls | four deck moving heads (`Accent*`), 7-degree beams; the entrance cues still tint each man's side |
| spots | a line of hard white lamps on the truss over the screens, shafts down onto the stage | eight `StageSpot*` on the truss, range-limited off the mat |
| beams | tight white pencils crossing in the haze, bright at the lamp and fading along the throw (`dynamite_2026_beams.jpg`, 18 Oct) | deck heads 3.5 degrees, truss spots 4; each drawn as a soft additive cone (`BeamShafts`) because the volumetric fog grid smeared narrow beams into broad wedges; fog energy cut to a faint halo |
| beam timing | show lighting: the movers and truss spots fire for the open and the entrances, chasing the music, and are dark and parked once the bell goes (the owner, 19 Oct) | `ArenaLighting.set_look`: entrance look restores them and `_move_stage_beams` fans the deck heads on the music; the match look parks them at zero |
| ring and crowd balance | broadcast frame: canvas luminance 0.54, saturation 0.15 (a light grey carrying the show's colour); crowd 0.18; ring to crowd 3:1 | was 0.62 / 0.03 and crowd 0.10 (6.4:1). Now `CANVAS_WHITE` 0.66 (the silhouette guard's floor), violet/blue `RingTint` washes, crowd light 9.0: wide canvas 0.53 / 0.07, crowd 0.15 (3.5:1); hard camera canvas 0.76 -> 0.72. Review: `stage/review/step1_ring_beams_skin.png` |
| overhead rig | not seen on a broadcast wide: the roof is black and the rig reads only as its lamps (the owner, 18 Oct) | `ArenaBuilder.RIG_HIDDEN` hides the truss, roof steel, speakers and PAR can bodies; roof fixtures show only their lenses (`ArenaLighting.BODY_SHOWN_BELOW`). Review: `stage/review/stage_beams_splay_no_rig.png` |

The portal notes that follow are kept as the record of the set this replaced.

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

## The ramp — extent and edge lighting

Added when the ramp was rebuilt as a wedge.

**Where it stops.** At the **barrier line**, not at the ring. Ringside is
floored in black matting from the barrier in to the apron (see `ring.md`), and
the entrance comes down onto the edge of that. The version that ended one
metre short of the ring also ran straight through the barricade line.

**The edge strips, measured rather than remembered.**
`dynamite_stage_low_angle.jpg` shows a lit strip running the leading edge of
the deck. Sampling the brightest pixel per column across the lower band of
that photograph, in 8-pixel steps:

| hue family | columns | example |
| --- | --- | --- |
| **violet-magenta (287–295°)** | **67** | `(235, 163, 255)`, `(249, 178, 255)` |
| white / desaturated (the strip's blown core) | 51 | `(255, 255, 246)` |
| blue (250–259°) | 9 | `(173, 152, 255)` |
| cyan (184–194°) | 5 | `(117, 223, 255)` |

So the strip is the **same magenta the portals carry**, blowing to white at
its core — not the white or the blue an unmeasured guess would have reached
for. The build dresses `RampLeds` from `arena_portal_magenta`, the key the
west portal already uses.

It runs at level 0.72 rather than the portals' 1.12: the strips are 24 m long
and sit far closer to the broadcast camera than the portals do, so the same
level puts two hard magenta lines through the middle of every wide shot.

Method: brightest pixel per column in the band 0.83–0.95 of image height,
classified by HSV hue, columns under luminance 90 discarded.
