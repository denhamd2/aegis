# Fight Forever: moves still to update, and gameplay gaps (19 Oct)

The owner asked for:
- the moves we have not yet brought to Fight Forever's style, with a plan for each
- why AI v AI matches repeat themselves
- what FF's gameplay has that ours lacks

This page is that list and plan, in the order the work will land.

## Done so far (FF style)

- **Tiger Driver '98** (Cody): in his power pool.
- **One Winged Angel** (Kenny's finisher).
- **Cody Cutter 4:** mapped to our springboard cutter.
- **Cross Rhodes:** rebuilt as FF's, with the hold, the spin and the spike, about 0.83 s to impact. It is now Cody's finisher.
- **In-between keys on the hero clips:** summed jerk is down from 980.6 to 885.7.

## Moves not yet in FF style (2K26-era clips)

| Family | Moves | What changes for FF |
| --- | --- | --- |
| Strikes | jab, cross, gut punch, kick, heavy kick, bionic elbow, dropdown uppercut, corner clothesline, parry | FF strikes are quick and committed: shorter wind-up, a clear impact frame, a short recovery. Re-time to FF frame data, add in-betweens. |
| Grapples | clinch knee, vertical suplex, guillotine | FF's collar-and-elbow start, a faster hoist, a body-frame landing (as the Vertical Suplex already has). |
| Chain holds | headlock, waistlock, wristlock | Shorter holds, with a visible struggle to break. |
| Power | bodyslam, powerslam, Samoan drop, Alabama slam | FF lifts are snappy, with weight on the landing. Same treatment as the TD98. |
| Signatures | Superman Punch, backbreaker, Pedigree, Disaster Kick, neckbreaker, Cody Cutter | FF timing; the Superman Punch wind-up shorter. |
| Running | clothesline (the lariat), single-leg dropkick, knee lift, drive-by, clothesline from hell, and the ~30 shared running attacks | FF running attacks land on the run with a hard stop. Lariats are named LARIAT on screen, as AEW calls them. |
| Ground | stomps, fist, pickup | Faster, with a crowd-reading pose after. |
| Dives | moonsault, springboard cutter, springboard Disaster Kick, tope | FF's hang time and a camera hold on the landing. |
| Finishers | Spear, Superman Punch into Spear | FF's Spear: lower, faster, with a fold on impact. |
| Submission | Figure Four | FF's hold, with the struggle bar. |

The order follows what is seen most in a match:
1. strikes and the lariat
2. Spear and Superman Punch
3. the power moves
4. signatures
5. everything else

Each move gets the same method as the hero clips:
- frame data read off the owner's FF compilation
- in-between keys
- the cadence, clearance and lint gates
- a review sheet

## Why AI v AI repeats itself, and what's done or planned

1. **Too many strikes between lock-ups.** The AI threw 5 to 9 strikes before each work lock-up.
   - **Done:** now 3 to 5.
2. **The same move drawn twice in a row.** Each tier picked uniformly at random.
   - **Done:** a man's last two picks are held back while anything else in the tier is on offer.
3. **Cody's standing Cody Cutter was never thrown.** His moveset table replaced his own signature.
   - **Done:** it is back in his signature draw.
4. **No Irish whips from the AI.** Whips existed for players only.
   - **Planned:** whip to the ropes with rebound follow-ups: lariat, knee lift, back body drop, and a spinebuster for Roman.
   - **Planned:** whip into the corner, with Roman's corner clotheslines and Spear, and Cody's corner chops (a new Flair-style strike) or a running knee.
5. **Few top-rope moves.** Today only Cody's moonsault, onto a man down mid-ring.
   - **Planned:** climbs onto a standing, stunned man too (a crossbody for Cody). Roman stays grounded, which is authentic.
6. **Roman's build to the Spear.**
   - **Planned:** stalk (a crouch and wait), the corner "ooh-ahh" Superman Punch pose, then the Spear when the man turns. It goes through the existing setup-taunt hook.
7. **Knee strikes for Cody.**
   - **Planned:** from the FF library (flying single-leg knee strike, Shining Wizard).

## FF gameplay we lack

From the FF guides and the owner's compilation:

- **Pins and submissions tied to HP and momentum.** A pin only sticks on a low-HP, low-momentum man; otherwise he kicks out.
  - **Ours:** a referee count with kick-outs. Mid-match near-falls need checking.
- **Taunting builds momentum, and a taunt at full meter unlocks the special.**
  - **Ours:** finisher windows only.
- **Specials only on a groggy opponent,** with an on-screen prompt.
- **Separate strike and grapple reversal buttons,** each with a timing window.
  - **Ours:** one reversal roll.
- **Rope running, whips and rebounds, springboards off the ropes.**
- **Corner, apron and outside spots,** including dives to the floor.
- **A timing mini-game for the player's pin and kick-out.**

**Proposed order:**
1. AI near-falls, taunt-builds-momentum, and groggy-gated specials (small changes, big effect on how a match reads)
2. AI whips and corner spots
3. split strike and grapple reversals
4. the pin mini-game

Each lands as its own step with tests and a match tally (`tools/probe/moveset_tally`).
