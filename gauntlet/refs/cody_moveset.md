# cody_moveset.md — Cody Rhodes's moveset, and what the game gives him

Research for Cody's own moveset (`Roster.Entry.moveset`), written the way the
other refs are: every claim says where it came from.

## Sources

- [All Elite Moves, Cody Rhodes](https://allelitemoves.com/men/Cody%20Rhodes/) —
  the fullest list: finishers Cross Rhodes, Tiger Driver '98, Vertebreaker;
  signatures Cody Cutter, Disaster Kick, Dropdown Uppercut; and a full
  moveset including the Bionic Elbow, Alabama Slam, Powerslam, Vertical
  Suplex, Figure-Four Leglock, Tope Suicida, Moonsault, Gourdbuster,
  Superplex and more (his whole career, all promotions).
- [The Sportster, Cody Rhodes' best moves](https://www.thesportster.com/wwe-cody-rhodes-best-wrestling-moves/)
  and the WWE 2K24 signature/finisher set (Cody Cutter, Pedigree; Cross
  Rhodes).
- The WWE.com entrance clips measured in `entrances.md` (for his build,
  gear and pace; they show no moves).

## What he hits in nearly every current match, and what the game does

The WWE-era core, 2023–25. Tier is the grapple-ladder rung the game draws
it from (`WrestlerController`); **[built]** is authored, baked and wired.

| Move | How he does it | Game tier | Status |
|---|---|---|---|
| Cross Rhodes | Rolling cutter into a pumphandle-style driver | finisher | **[built]** (earlier round) |
| Cody Cutter | Leaping cutter off the ropes | signature (his own, thrown first) | **[built]** (earlier round) |
| Disaster Kick | Spinning heel kick, often springboard/apron | signature | **[built]** standing version (`signature_disaster_kick`) |
| Bionic Elbow | Dusty's: the shimmy, then the elbow down on the head | strike | **[built]** (`strike_bionic_elbow`) |
| Dropdown Uppercut | Drops under a charging man, pops up into the chin | strike | **[built]** (`strike_dropdown_uppercut`) |
| Vertical suplex, delayed | Held upside down for the crowd, then over | grapple | **[built]** (`grapple_vertical_suplex`) |
| Powerslam | Carried across the chest, fallen on | power | **[built]** (`power_powerslam`, the body slam's lift) |
| Alabama Slam | Upside down over the shoulders, slammed back-first | power | **[built]** (`power_alabama_slam`) |
| Dropkick | Running | running | shared `running_single_leg_dropkick` |
| Figure-Four Leglock | Ankles grabbed, left shin crossed over the right knee, sits back and bridges | submission (his own hold) | **[built]** (`submission_figure_four`, `Figure_Four_*` clips) |
| Tope suicida; springboard/apron Disaster Kick | Dives to the floor, off the apron | — | **next** — needs outside-the-ring positioning the match does not have |

## Checks

- Every built move rendered through `tools/probe/paired_shot.tscn` and
  measured by `tools/probe/move_qa.tscn --roster`: within the house figures
  the shipped body slam and Cody Cutter already carry.
- Strikes' contact points measured by `tools/anim/measure_contact_offsets.gd`
  (Bionic Elbow 0.649 m, uppercut 0.620 m, both peaking on the contact tick).
- `tools/probe/moveset_tally.tscn`, 16 seeds Roman vs Cody: Bionic Elbow 56,
  uppercut 38, vertical suplex 11, Cody Cutter 17, Cross Rhodes 8, Alabama
  Slam 2, powerslam 1, Disaster Kick 3. The power rung is the rarest the
  momentum ladder reaches, so its two moves are thrown least.

## The Figure-Four in a match

Played by the two SUBMISSION_* states, not GrappleRig: the man is already
down. `MatchReferee` takes it once a match, on the first man Cody has down
that a finisher did not put there (a finisher knockdown is always pinned);
`WrestlerController._place_figure_four()` walks him to the man's boots,
measured off the downed man's own skeleton, and the contest waits out the
application (`startup_frames` 124 = the clip's 62 authored frames) before
either ring fills; the leg damage lands on the lock. Escaped, Cody turns
round on the mat and gets up like a thrown man. The tap only comes on a leg
past `SUBMISSION_ESCAPE_LIMB`, so the match still ends on a pin: 8 seeded
Roman-vs-Cody matches, the hold in 5, all 8 won by pinfall.
Rendered through `tools/probe/hold_shot.tscn`.
