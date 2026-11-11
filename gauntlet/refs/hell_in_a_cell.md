# Hell in a Cell

The owner, 11 Nov: "Hell in a Cell, Ladder, TLC, Casket, Ambulance matches."
`steel_cage.md` (§76–92) left this spec for a follow-up; this file is it.

## The match

- **Win:** pinfall or submission only. Escape does not win, as in WWE, and as
  in AEW's cage matches. There is no disqualification and no count-out, and
  falls count anywhere inside the cell.
- **Structure:** a roofed steel cell that stands on the arena floor and
  encloses the ring and the ringside mats. Measured from footage it is about
  20 ft (6.1 m) tall. The cell door sits on the entrance side and is kept
  shut. The fight takes in the ringside floor, but the stage and the announce
  desk are outside the walls.
- **Weapons:** the under-the-ring weapons are in play, as in Lights Out. The
  stage layout is not.
- **The steel as a weapon:** a man whipped on the floor runs into the cell
  wall. The panel rattles, he takes `CAGE_RAM_MOVE` and goes down
  (`_whipped_into_cage`). Inside the ring, a whip still goes to the ropes.

## Our numbers (`CageBuilder.Spec.hell_in_a_cell`)

| | Value |
|---|---|
| Half-width (walls from the centre) | 5.55 m (barricade at 6.0) |
| Foot | `ArenaBuilder.FLOOR_Y` (−1.1) |
| Height | 6.1 m |
| Rails | 0, 0.18, 0.36, 0.55, 0.78, 1.0 |
| Bays per wall | 6 |
| Door | −Z (ramp side), 1.4 × 2.3 m, shut |
| Roof | chain-link panel with rails, collision |

The cell is built in code, like the Steel Cage, with no downloaded geometry.

## Not yet

- Fighting on the roof, or through it.
- Breaking the door open.
