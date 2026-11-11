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
| Half-width (walls from the centre) | 4.7 m (barricade at 6.0: 1.3 m outside, 1.5 m to the apron, and a man can still get round the corner past the barricade chamfer) |
| Foot | `ArenaBuilder.FLOOR_Y` (−1.1) |
| Height | 6.1 m |
| Rails | 0, 0.33, 0.66, 1.0 (three rows, as the references) |
| Bays per wall | 4 (a 4×4 roof) |
| Door | −Z (ramp side), 1.4 × 2.3 m, chained and padlocked |
| Roof | chain-link panel with rails, collision |

The cell is built in code, like the Steel Cage, with no downloaded geometry.

## The rules (researched 11 Nov)

- The cell door is locked with a chain and padlock once both men are inside.
- **Win:** pinfall or submission only. Escaping does not win.
- No disqualification, no count-out. Falls count anywhere, the roof included.
- Weapons are legal. Wire cutters (or bolt cutters) are how the chain comes
  off.

## The roof (after WWE 2K22–24)

Sources: the VGC 2K23 guide, Outsider Gaming's 2K22 guide and Sportskeeda's
2K24 guide.

- **Getting out:**
  - The padlocked door (`CageBuilder.set_padlock`) opens only with the wire
    cutters (`wire_cutters`, under the ring on the door side).
  - With them in hand at the door, he cuts the chain (`CellRoof.CUT_TICKS`,
    1.5 s). The lock falls, the door swings, and he walks out.
  - The cutters stay in his hand.
- **Up:**
  - He climbs the outside of the front wall, the ramp side, where there is
    room before the barricade: 3.5 s up, then over the top rail onto the
    roof.
  - Any weapon in his hand goes up with him (`KEEP_WEAPON_STATES` has
    `CELL_CLIMB`).
  - A hit while he is high on the wall knocks him off it.
- **On the roof:**
  - He fights as anywhere, at the roof's height. Paired moves play there,
    kept a metre in from the edge (`GrappleRig`).
  - The camera stands off further and higher (`MatchCamera.ROOF_DISTANCE` /
    `ROOF_LIFT`).
- **The edge:**
  - A man who walks into it teeters there (`whoa_arms`).
  - Near the edge (within 0.95 m), struck toward it, he goes over in two
    cases: a signature-tier blow, or any knockdown when he is spent (health
    under 0.38) or right on the edge.
  - He falls on a ballistic path, body limp (`FallRagdoll`). He lands on the
    floor, or through a table set up below, or onto the announce desk off its
    side.
- **The panels:**
  - The middle four of the 4×4 roof dent with each slam on them: power 1,
    signature 1.5, finisher 2.
  - Each dent sags the panel visibly. At 4 it swings open on its hinge and
    the man drops 6 m into the ring.
- **Off it onto him:** standing at the edge over the man down below, he dives
  onto him (`begin_high_dive`). The same works from the top of the Steel
  Cage's wall into the ring.
- **AI:**
  - Once a match, past 150 s and off a big knockdown, it takes the fight to
    the roof (65%): fetches the cutters, cuts the chain, goes out and up.
  - The other man follows.
  - The man left up there after a fall dives onto him, or climbs down.

## Not yet

- The referee's padlocking walk. The lock is on at the bell.
- Breaking a wall panel out.
