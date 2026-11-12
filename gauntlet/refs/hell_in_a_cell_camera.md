# Hell in a Cell — the camera plan

The owner, 11 Nov: "the cell is blocking some of the entrance shots and also
blocking much of the views during the match. Act as our camera director to
come up with a hell in a cell specific camera plan so the cell doesn't spoil
the view and playability of the match." Then: "the cell should lower after
the entrances", and "find online any sources around the light effects which
happen during the lowering".

## What the research found

- **2K keeps its default camera outside the cell, on the hard-camera side.**
  In WWE 2K23 the only breakable wall panels are "the two at the front-left
  corner and the two at the front-right corner (the ones closest to the
  camera)". (VGC, WWE 2K23 Hell in a Cell guide.)
- **2K25 added a player-controlled third-person camera** and named scaling
  the cell as a case it suits. (God is a Geek, WWE 2K25: 13 details.)
- **The descent is a tension beat.** WWE's own write-ups describe the cell
  being lowered as the moment the tension "reached a boil", with the
  wrestlers "staring up" at it (2016). It was lowered over the ring before the
  opening match in 2018. In 2011 it was raised and lowered again after a
  match, as a story beat.
- **No source describes a standard lighting cue for the lowering.** The red
  lighting and strobes reported at Hell in a Cell 2019 belonged to The Fiend's
  entrance and match, not the descent. So the lowering's lighting below is
  our own design, not a measurement.

## Why ours was blocked

- Every coverage stands 6–9 m from the pair. The cell's walls are 4.7 m from
  the centre, so every shot looked through a wall.
- The default coverage (Fight Forever) is 4.4 m up and 7–9.5 m out. Its line
  of sight crossed the near wall about 2.7 m up, right at the upper rail
  (3.0 m).
- The posts, every 2.35 m, crossed the frame. The mesh greyed whatever it
  covered.

## The plan

1. **Entrances: the cell hangs over the ring and comes down after them.**
   - It hangs at `CageBuilder.HOIST_LIFT` 10.6 m up: the foot of its walls is
     above the 9.2 m truss, so no entrance shot looks through it. Four chains
     run up to the roof steel.
   - After the two corner introductions, `EntranceDirector._add_cell_lowering`
     brings it down over 30 s (the owner, 12 Nov: "much slower"), eased, then holds 1.4 s.
   - **Shot:** low on the hard camera's side, tilting down with it
     (`cell_lower_shot`).
   - **Lighting (our design):**
     - the house goes down (`CELL_HOUSE_DIM` 0.28);
     - white strobe hits go off round the truss corners in turn every 0.55 s,
       so the light walks round the steel;
     - when it lands: one big white flash, the walls rattle, the crowd pops,
       the camera takes a jolt, and the house comes back up.
   - The referee's padlock goes on when it lands. With the entrances skipped,
     it lands at the bell.
2. **In the match, inside the cell: the camera comes in with them.**
   - When both men are inside the walls, the camera comes in along its own
     line of sight until it is 0.4 m inside the walls (`cell_pull_in`). Its
     angle is unchanged.
   - The lens widens by the same ratio, capped at 74°, so the pair fill the
     frame as before. It is the TV handheld in the cell with them.
   - This applies to every coverage, the hard camera included.
3. **Outside the cell: the crowd side of the wall they are at.**
   - When both men are in the lane between the cell and the barricade, the
     camera's bearing is that wall's outward axis. It looks back over the
     barricade at them and the steel, never across the cell through two
     walls.
4. **Up the cell and on the roof: as before.**
   - `ROOF_DISTANCE`, `ROOF_LIFT`: back and up, looking down on the roof. The
     roof edge sits below the lens, so nothing blocks it.
5. **Still to do:**
   - a hard cut to a floor-level camera looking up at the edge for a fall;
   - a cut to inside the ring, looking up through the hole, for a panel
     giving way;
   - a near-wall fade, and the cell's posts in the camera's post avoidance,
     if renders show the inside camera still catching steel.

Renders: `tools/probe/gimmick_shot.gd --only cellcam,lowering`.
