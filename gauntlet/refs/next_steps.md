# Next steps -- the roadmap

What is done, what comes next, and in what order. Updated at the end of each
round; the README is the detailed log of how each piece was built.

Last updated 2026-10-14, after the blood round (main `afd3c06`, Mac build run
30 on the `mac-latest` release).

## Done and on the Mac build

- **Crowd audio and chants**, all free sources: an arena crowd at broadcast
  loudness, chants checked by a speech recogniser (Co-dy, O-T-C, This is
  awesome, Holy shit!, the count), and louder entrances.
- **Weapons phase 1, grips**: hands on the handles of every weapon, carried
  within 3 cm (the table within 4).
- **Weapons phase 2, pickups**: the lift fits the weapon (one hand, two hands,
  or a squat for the heavy ones); his hands close on it where it lies, and it
  never jumps into his hand.
- **Selling**: every hit, by weapon or by move, is sold to its size and to how
  much he has left -- light, medium, heavy, to the knee, or down.
- **Blood**: the dangerous weapons cut him, more for a bigger shot and a more
  beaten man. It starts as a cut at the hairline and builds to a crimson mask,
  then dries. The tacks cut his back. The canvas gets drips, pools, spatter and
  smears. On by default; OPTIONS > BLOOD > OFF to turn it off.

## Next: weapons phase 3, the swings

Each family gets its own body clip (in `game/tools/blender/wrestling_clips.py`)
and its own swing path (`WeaponCatalog.SWING_PATHS`), so the weapon travels
with his hands rather than the hands chasing a generic swing.

| Family | Weapons | The swing |
| --- | --- | --- |
| Bat | baseball bat, barbed-wire bat, lead pipe, sledgehammer | two hands stacked, step in, hips turn through |
| Slapshot | hockey stick | a slapshot (the owner's pick) |
| Chop | kendo stick | two-hand overhead chop |
| Chair | steel chair, barbed-wire chair | held by the legs, high overhead |
| Two-handed slam | trash can, steel steps, briefcase | overhead, both hands |
| Shovel | shovel | flat of the blade, overhead |
| Crutch | crutch | held by the foot end, overhead |
| Bonk | ring bell, frying pan | overhand |
| Flat face | championship belt, cookie sheet | the flat face into him |
| Fist | chain | wrapped round the fist for a punch (the owner's pick) |

- Overhead swings stop at head height, never in the mat.
- **Done when:** `KNOWN_SWING_SLIPS` in
  `game/tests/test_weapon_grip_contact.gd` is empty -- every swing keeps
  both palms within 3 cm of the handles -- and the clip gates pass (pose lint,
  body deformation, clip authoring).
- One review sheet per family, sent to the owner.

## Then: weapons phases 4 and 5

- **Set-piece spots**: through the table, onto the tacks, the ladder, the
  barbed-wire board, each a paired move with its own bump and sell.
- **AI weapon use**: when a man goes outside for a weapon, which one he picks,
  when he uses it, and when he sets a piece up.
- **Camera cuts** on the big weapon spots, and **sound** for each weapon and
  each break.
- This also closes out No Holds Barred phase 0: the rules, fighting outside
  the ring, crossing the ropes, and the referee.

## The older open items

Each is small to medium.

- Ring details matched to the reference still.
- Authentic movesets for Roman and Cody.
- Entrance cameras for Roman and Cody to the 2K26 storyboard -- no low
  up-angle on Roman.
- Aubrey holding the props in her hands, not floating at her head.
- The lights coming up during the staredown, after the second entrance.
- Health bars missing on the Mac, and a small controls overlay.
- A body morph audit and fix plan for Roman and Cody.
- After the match: the loser stays on the mat, Aubrey raises the winner's arm,
  and the winner's music starts from the chorus.
- The black circle under Cody's smoke.

## Rough size

- Weapon swings: about one session.
- Phases 4 and 5: about one session.
- The older items: about one session.

## How every step is checked

1. gdUnit tests for the behaviour, run headless.
2. A rendered review sheet, looked at before it is sent to the owner.
3. The full test suite before every push.
4. Shipped to `main`, which rebuilds the Mac app on the `mac-latest` release.
