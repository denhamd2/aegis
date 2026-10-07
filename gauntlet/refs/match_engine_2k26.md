# The match engine vs WWE 2K26: flow, AI, between-moves, and the hard cam

The owner asked for three things:
- research into how 2K26's match engine, AI and match flow work, and what happens between moves;
- a comparison with ours and a plan to close the gap;
- in-match camera angles that match 2K26's, with the hard cam's height, distance and angle matched exactly.

## Sources

- **[M] Measured** off the owner's 2K26 Cody vs Roman (`raw/video/cody_roman_2k26.mp4`, bell 300 s to the three at 775 s):
  - contact sheets at 1 fps across the whole match, timestamped;
  - the camera fitted from rope and turnbuckle positions in three frames (method below);
  - camera angle and zoom tracked at 2 fps.
- **[M] Measured off ours** with `tools/probe/flow_probe.tscn`: AI vs AI, the same metrics, one value a second per man.
- **[R] Reviews and press:**
  - [VGC](https://www.videogameschronicle.com/review/wwe-2k26/), [Gaming Nexus](https://www.gamingnexus.com/Article/16357/WWE-2K26/), [MP1st](https://mp1st.com/reviews/wwe-2k26-review-best-in-the-world), [Operation Sports](https://www.operationsports.com/why-wwe-2k26s-new-purple-stamina-bar-is-a-step-backwards/), [Insider Gaming](https://insider-gaming.com/wwe-2k26-adds-start-of-match-actions-and-advanced-ai-customization/), [TheSmackDownHotel controls guide](https://www.thesmackdownhotel.com/news/wwe2k26/wwe-2k26-controls-scheme-full-guide-for-ps5-xbox-series), [Fightful](https://www.fightful.com/wrestling/wwe-2k26-deep-dive-on-new-match-types-gameplay-mechanics-and-more/), [RealSport101 sliders](https://realsport101.com/article/wwe-2k26-sliders-the-best-settings-for-a-realistic-gameplay-experience).
  - 2K's own Ringside Report refused the fetch (403); its content is covered by the press above.

## 1. How a 2K26 match flows [M]

Read second by second off the sheets:

| t (s) | What happens | Between moves |
| --- | --- | --- |
| 298-310 | Start-of-match action: Cody plays to the crowd on the ropes, Roman in his corner, then they approach, circle and lock up under a timing prompt. | 12 s before the first contact. |
| 311-332 | Takedown, then Cody's leg submission with the HOLD meter. Roman crawls 3 s to the ropes. | — |
| 333-337 | **Both get up slowly, about 5 s.** | Nobody attacks. |
| 338-350 | Roman's strikes, then a lift and drop. | — |
| 351-361 | **Cody down 11 s.** Roman stomps him, walks away and comes back. | The man in control works the downed man. |
| 362-377 | Cody turns it. **Roman down 10 s**: Cody stomps, struts with his arms up, walks the ring. | Strut and taunt. |
| 382-389 | Cody climbs the corner (6 s) and dives. | The climb is a beat of its own. |
| 390-396 | **Both down, then up in stages**: knees, then feet. | Double-down. |
| 396-421 | 25 s of standing exchange: strikes and staggers, circling. | — |
| 422-437 | **Roman down 15 s**, red danger vignette. Cody picks him up, works him and goes up top. | Pick-up. |
| 448-451 | A cut to the cinematic corner angle for a big move. | — |
| 461-488 | The corner sequence; the camera rises to a high wide for the top rope. | — |
| 497-508 | Finisher cinematic, cover, kickout at two. | — |
| 508-520 | **Both sell the finisher for 12 s.** | — |
| 598-625 | 27 s of strike exchange at the ropes, with timing rings over both men. | — |
| 635-657 | Roman's possum attack, then **Cody down 16 s** while Roman works and struts. | — |
| 721-728 | **Double-down, 7 s.** | — |
| 733-760 | **Cody down 27 s** while Roman stomps, sets up and grounds him. | The longest control stretch. |
| 762-777 | Cody's reversal, control, finisher cinematic, the three. | — |

What this adds up to:

1. **A downed man stays down 5-27 s**, and longer after bigger moves. The getup is staged: rolling over, then to the knees, then up.
2. **The time in between belongs to the man in control.** He stomps, picks his man up, struts, walks the ring, climbs the corner. Covers come after the big moves, not after every knockdown.
3. **Long one-man stretches** of 10-27 s, then a turn: a reversal, a possum attack, a comeback.
4. **Double-downs** after big exchanges and finishers, with both men rising together.
5. **Standing exchanges are long and timed** (25-27 s), with prompts over both men. They end on a stagger or a knockdown.
6. **Fatigue is visible.** Late in the match they walk slower and crawl to a cover after a finisher ([R] Gaming Nexus).

## 2. The systems behind it [R]

- **Reversals cost stamina.** Every reversal, dodge or sprint drains one stamina bar. Empty, a man is "blown up" (the purple bar): he can still strike, but can't reverse or run until it refills. This was added to stop "wait and reverse" play and make matches back-and-forth. Critics say it forces breathers after every spot.
- **Momentum meter:** it fuels signatures, paybacks and instant recovery. Landing a signature earns a finisher.
- **Finisher meter:** three stored finishers. Three unlock a Super Finisher, which is very hard to kick out of.
- **Combos:** about 30 per superstar, built from light and heavy chains, ending in a strike or a grapple. They can be broken by guessing the button (a combo breaker).
- **Grapples by position:** front, rear, ground, corner, ropes, apron, top rope, plus Irish whips, running attacks and carries.
- **Stun meter:** a stunned man can't reverse.
- **Start-of-match actions:** play to the crowd, handshake, chain wrestling (rock-paper-scissors), trade blows, or a surprise attack.
- **AI:**
  - more aggressive and reverses more than in 2K25;
  - sliders per reversal type (standing strike, grapple, ground, finisher);
  - new "AI Sequences", which let a moveset tell the AI the order to throw a star's signature moves in.
- **Physics:** heavier bumps, tighter collision, looser ragdoll on uneven objects (steps, tables).

## 3. Ours against it

### Measured: `flow_probe`, AI vs AI

Roman vs Cody over three seeds (`flow_probe -- --seeds 1,2,3 --wrestlers roman,cody`), against the 2K26 match read off the 1 fps sheets above. The 2K26 column is counted by hand, so it is coarse; the ours column is exact.

| | 2K26 | Ours (mean of 3) |
| --- | --- | --- |
| Match length | 475 s | 474 s (428-518) |
| Moves landed a minute | about 10, stomps included | **31.5** |
| Median gap between landed moves | about 4-6 s | **1.1 s** |
| A man down: typical spell | **5-27 s**, median about 12 s | **2.9 s** median, longest 5.8-9.1 s |
| Share of the match with someone down | about half | 31% |
| One man's control run | **10-27 s** | **2.8 s** (2.65 moves), longest 11-17 moves |
| Double-downs | 3 (390, 508, 721 s), 5-12 s each | 2-5 s a match, and only in passing |

Our length is right, but everything inside it is three times too busy. Moves land every second, a man is back up in three, and nobody holds control long enough for a stretch to read as a story. The strips (`--strip`) show why: the time between moves is short tie-ups (`ggg`) and 3-second downs (`DDD`), not a man down being worked.

### What exists and what doesn't

| 2K26 | Ours | Gap |
| --- | --- | --- |
| Downed man stays down 5-27 s, scaled by the move | `GETUP_TICKS` 90 (1.5 s), thrown 0.75 s, plus a getup sell of 75 ticks | **Large.** This is most of "what happens between moves". |
| Staged getup (roll, knees, feet) | One getup clip | Large |
| Attacker works the downed man: stomps, struts, walks, picks him up, climbs | Up to 2 ground attacks, then he covers on every knockdown. TAUNT/stall exists for the heel. No pick-up. | **Large.** Covers are too frequent, and there is no pick-up. |
| Covers after big moves; near-falls build | Every knockdown is a cover | Medium |
| Long control stretches, then a turn | MatchFlow phases (heat, hope, cutoff, comeback) scale damage and tempo by persona | Small: the story arc exists. The beats inside it are missing. |
| Double-downs after big exchanges | DiveSpot only | Medium |
| Standing exchanges of 25 s with timing prompts | Strike strings of 3; AI circles at 1.1 m | Medium |
| Reversals cost stamina; blown-up lockout | Stamina exists; reversal chance scales with it (`REVERSAL_SPENT_SHARE`). No lockout state, no visible bar. | Small/medium |
| Momentum → signature → finisher, stored finishers, paybacks | Momentum ladder, signature, finisher window, comeback (fired up) | Small. No paybacks or stored finishers; both optional. |
| Start-of-match actions | Face-off, then the bell | Medium (a natural fit after the face-off) |
| Irish whips, rebounds, corner whips | Whip at 18% of won holds, after the opening; rope rebound exists | Medium |
| Apron and floor fighting | None (dives only) | Large, and expensive; later |
| Fatigue (slower walk, crawl to cover) | `fatigue_walk_scale` exists | Small |
| AI sequences (signatures in a set order) | Roster tiers and set pieces in a fixed order | Small |

## 4. The in-match camera [M]

### What 2K26 does

**It is a hard cam.** It stays on one side of the ring all match, never walks round, and keeps the far ropes level (square-on). It:
- slides along that side to keep the pair centred;
- moves in and out with the action on one fixed long lens;
- rises to a high wide only for top-rope and corner sequences;
- cuts to close cinematic angles only for finishers, the pin and the replays: 13 cuts in 475 s (`cody_roman_2k26.md`).

**Exact pose, fitted in our ring's own units.** Method:
- The rope rows (far and near top, middle, bottom) and the far rope ends were measured on three square-on frames.
- A pinhole camera was solved for height, distance, tilt and lens against this ring's rope heights (0.50, 0.85, 1.20 m) and rope line (±3.1 m).
- The fit is `tools/refs/fit_hard_cam.py`.

| Frame | Fit error | Lens (vertical FOV) | Height above mat | From ring centre | Outside near ropes | Tilt down |
| --- | --- | --- | --- | --- | --- | --- |
| 340 s (exchange) | 1.3 px | 17.4° | 1.36 m | 7.40 m | 4.30 m | 4.8° |
| 360 s (wide, man down) | 0.4 px | 16.9° | 1.42 m | 9.30 m | 6.20 m | 4.5° |
| 600 s (close exchange) | 0.9 px | 16.9° | 1.58 m | 7.60 m | 4.50 m | 4.8° |

So, in our ring:
- **Lens:** one fixed lens of about 17° vertical, roughly 80 mm full-frame. It does not zoom.
- **Height:** 1.36-1.58 m above the mat, 0.15-0.40 m above the top rope.
- **Distance:** 7.4-9.3 m from the ring centre, 4.3-6.2 m outside the near ropes. It moves in and out, never closer than 7.4 m.
- **Tilt:** about 4.7° down.
- **Bearing:** square to the ring's side, sliding laterally along it.

### What ours does

Our gameplay camera (`MatchCamera`, RINGSIDE in GAMEPLAY coverage, the default):
- **Moves round the ring.** It turns to stay side-on to the line between the two men and pans up to 90° round the ring at up to 20°/s. **That is the "dynamic" feel the owner saw.**
- **Wider lens:** 41° vertical, against 2K26's 17°.
- **Closer:** at least 4.2 m from the *pair*, not the ring, pushed outside the ropes, against 7.4-9.3 m from the ring centre.
- **Higher:** 1.65 m against about 1.45 m.

The wide lens close in is why ours feels "in amongst it" rather than broadcast. The long lens from further out flattens the crowd behind the ring into a wall.

## 5. The plan

In order of what the owner will notice. Each stage closes on a measurement (`flow_probe`, a camera render compared against the 2K26 frames) and the full suite.

### Stage 1: the 2K26 hard cam (camera only, smallest and most visible)

1. **Fixed side.** The gameplay camera keeps one bearing: square to the hard-cam side (-X). No orbit and no swing round the ring. The bearing logic (`_gameplay_bearing`) is replaced by a lateral slide.
2. **Exact pose:**
   - lens 17° vertical;
   - eye 1.45 m above the mat;
   - tilt about 4.7° down;
   - distance 7.4-9.3 m from the ring centre, driven by the pair's separation and their position along the ring.
   - The camera stands outside the ring at the barricade line, so no post is ever in the way.
3. **Lateral tracking:** it slides along its side to keep the pair's midpoint centred, eased like an operator on a dolly. It dollies out when they part and in when they close.
4. **Corner and top-rope beat:** when a man climbs the corner (TopRopeSpot, DiveSpot), the camera rises and widens for the dive, then returns.
5. **Cuts stay as they are:** finisher, pin and replay only.
6. **Gate:**
   - render our frame at the three fitted moments' positions;
   - re-fit our own render with `tools/refs/fit_hard_cam.py`, and the numbers must agree within the fit's own spread;
   - camera tests pinned to the measured values.

### Stage 2: between moves (the largest feel gap)

1. **Down time scaled by the move:**
   - strike knockdown about 4-6 s;
   - slam or signature about 8-12 s;
   - finisher about 12-15 s.
   - Staged getup: roll over, then to the knees (a hands-and-knees sell), then up.
   - New clips in `wrestling_clips.py`: Getup_Roll, Getup_Knees, Getup_Stand.
2. **The man in control works him**, chosen by persona and phase:
   - stomps or ground fists (more than 2);
   - a strut or taunt;
   - a walk round the ring;
   - **picking him up** (a new paired pick-up into a front grapple or a stagger).
   - **Cover only after a signature, finisher or big move**, or late in the match. Not after every knockdown.
3. **Double-downs:** after a big exchange or a finisher kickout, both men down and rising together.
4. **Gate:** `flow_probe` medians against 2K26's:
   - down spells 5-15 s;
   - control runs of 10-25 s;
   - share of the match with a man down.

### Stage 3: the exchanges

1. **Start-of-match action after the face-off:** the owner picks from play to the crowd, lock-up (chain), trade blows, or a cheap shot. The AI picks by persona.
2. **Longer standing exchanges:** strike trades of up to about 20 s, ending in a stagger or a knockdown, with ring prompts for the player.
3. **More whips and rebounds in the AI:** off the ropes into a running move, and corner whips into Roman's clotheslines.

### Stage 4: the systems (optional, rules-level)

1. **Blown-up state:** stamina at zero means no reversals and no running until it refills, shown on the HUD.
2. **Stored finishers and paybacks:** only if the owner wants 2K26's rules as well as its look.
3. **Apron and floor fighting:** last; it is the most expensive.

## Not recommended

- **A star rating, the red danger vignette, or button prompts over the men.** These are 2K26 HUD chrome. The owner has been removing HUD (the title bar and clock).
- **Copying the blown-up state's long breathers.** Reviewers call it the weakest change in 2K26. If we take the lockout, take it with fast regen.
