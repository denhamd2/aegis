# Weapon review (19 Oct): models, swings, reactions, blood

The owner asked for a thorough review of every weapon -- its model, its swing
animation, and whether the man it hits reacts in proportion to what it does --
with the swings brought to Fight Forever's style and smooth, and the blood
checked for realism. This page is the audit and the plan, step by step.

## What the code does today

- **35 weapons** in `WeaponCatalog.TABLE`, six families. Each has head and
  torso damage, a swing kind (`SWINGS`: startup, active, recovery ticks) and,
  for 15 of them, a swing profile with its own body clip and weapon path.
- **The victim's reaction is one of two things.** Every weapon whose head
  damage is 8 or more sets `leaves_defender_down`, and every one of those plays
  the same `strikes/bump_back` fall and the same time down. A frying pan (9), a
  chair (9), a sledgehammer (14), the steel steps (15) and a sword (17) all
  drop a man identically. Under 8 (cookie sheet, banana, extinguisher) it is a
  flinch. Nothing in between -- no stagger clutching the head, no drop to a
  knee, no hard spill for the heaviest, no collapse for a blade.
- **Swing timing** is two sizes: one-hand 12-16 ticks of startup, two-hand 18;
  recoveries 20-26. Fight Forever's weapon swings are quicker and more
  committed: a short wind-up, a hard stop on contact, a quick recovery.
- **Blood** (`core/materials/blood.gd`): a cut opens by weapon (`CUT`, now
  including the blades at 1.0), the bleed builds with damage and health and
  creeps while it is open, and stains the canvas. Not yet checked on a close
  frame against real broadcast blood.

## Reaction tiers (planned)

| Tier | Weapons (head damage) | Reaction | Down time |
| --- | --- | --- | --- |
| Light | banana, cookie sheet, extinguisher (≤ 6) | flinch | -- |
| Rocks him | kendo stick, crutch, hockey stick, belt, weight belt, chain, frying pan, ring bell, stop sign, trash can, briefcase, baseball bat (8-9) | heavy stagger, hand to the head; a knee when hurt | knocked down only by the build-up |
| Drops him | chair, lead pipe, shovel, table, ladder, light tubes, barbed-wire bat, 2x4 with nails, brass knuckles, guitar, barbed-wire chair and board (10-13) | the back bump | normal |
| Wipes him out | sledgehammer, steel steps, rocket launcher (14+) | a hard spill, further back | x1.6 |
| Blades | knife, sword | clutches the wound, drops to a knee, then down | x1.4, heavy bleed |
| Gun | handgun | fatal (unchanged) | the match |

## Swing timing to Fight Forever (planned)

| Swing | Now (startup/active/recovery) | FF-style target |
| --- | --- | --- |
| side (one-hand) | 16 / 4 / 24 | 12 / 4 / 18 |
| overhead (light) | 18 / 4 / 26 | 14 / 4 / 20 |
| chop | 12 / 4 / 22 | 10 / 4 / 16 |
| thrust | 12 / 4 / 20 | 10 / 4 / 16 |
| whip | 14 / 4 / 22 | 11 / 4 / 17 |
| punch (knuckles) | 12 / 4 / 24 | 9 / 4 / 17 |
| heavy (sledgehammer, steps, table, ladder) | 18 / 4 / 26 | 18 / 4 / 24 (weight kept) |

Each clip is retimed to its new length, given in-between keys where the
cadence gate (`test_clip_cadence`) finds a jerk spike, and reviewed on a
contact sheet.

## Order

1. Reaction tiers (code + tests), proportion table above.
2. Swing retime and in-betweens, cadence gate, contact sheet per weapon.
3. Model pass: a five-angle sheet of all 35 (`tools/probe/weapon_shot`),
   fixing anything that reads wrong.
4. Blood: close frames after blade and barbed-wire hits against broadcast
   reference; tune colour, wetness, run and canvas stains.
