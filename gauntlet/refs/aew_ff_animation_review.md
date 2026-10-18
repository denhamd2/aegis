# AEW Fight Forever: in-match animation review

The owner's request, 18 October: make all in-match animation match the style of
*AEW Fight Forever* (Yuke's, 2023). Review every signature and finisher in the
owner's compilation video, assess a Gemini-written breakdown of it, research
the game's animation, and review our own in-match animation against it.

Fight Forever footage is a **measurement reference** here, in the same way 2K
footage has always been (README): timings, camera grammar, poses to aim at. No
animation data, models or audio are extracted. Our clips stay hand-authored in
`game/tools/blender/wrestling_clips.py`.

## Method

- **Source:** the owner's Drive video, a 15 min 35 s, 1280×720, 59.94 fps
  compilation of every wrestler's signature and special moves.
- **Segmenting:** frames sampled at 2 fps. Moves were segmented on changes in
  the top-left move banner (174 segments), with the gaps between banners swept
  at 1 fps to recover moves whose banner was missed.
- **Reading:** every move name was read from a full-resolution banner crop;
  each performer from the bottom-left nameplate, under its SIGNATURE/SPECIAL
  gauge.
- **Timing:** Cody's and Kenny's moves were timed at 10 fps.
- **Impact behaviour:** measured at the full 60 fps, as frame-to-frame image
  change around five impacts.

## What the style actually is (measured)

1. **Fast lock-up, fast resolution.**
   - The tie-up reads in about 0.3 s, and the move starts straight from it.
   - Cross Rhodes takes about 0.8 s from hoist to impact; Cody is back on his
     feet about 1 s after impact.
   - The One Winged Angel lands 0.9 s into the move, with Kenny up by about
     1.9 s.
2. **The camera does the hitting.** There is no whole-frame hit-stop: across
   five impacts (Cross Rhodes, One Winged Angel, V-Trigger, Superkick 3,
   Spear 2), image change between frames never drops to a freeze. What is
   there, every time, is a **hard cut on or right at the impact frame**.
   - Grapple signatures and specials cut from the high, wide hard camera to a
     **low, close ringside angle** for about 0.5–1.7 s. The giant AEW screens
     fill the background, the impact plays there, and the camera cuts back
     wide for the recovery.
   - The V-Trigger's close-up lasts only about 0.4 s around the knee.
3. **A shared library with numbered variants.** "Spinebuster 5" is used by
   Cash, Jade and Hobbs; "Superkick 5" by Nick and Aubrey Edwards; "Sit-Out
   Powerbomb 2" by Dax and PAC; "Brainbuster 1" by Dax and Malakai; "Spear 2"
   by Christian and Starks; "Diving Shooting Star" by PAC and Sammy. Generic
   moves are one clip set with numbered variants; only specials are unique.
   That is how a large roster gets a consistent feel, and it is the pattern
   to copy.
4. **Two tiers, clearly framed.**
   - A SIGNATURE gauge or a flaming SPECIAL gauge flashes, and the move name
     sits top-left with a body diagram.
   - Specials are the unique, longest moves, and some are followed by an
     **instant replay** (El Idolo cuts to a Dynamite-arena replay with the
     "REPLAY" bug).
5. **Readable downed states.** Many moves start from a seated or kneeling dazed
   opponent, or one draped on the ropes or turnbuckle. Recovery poses are
   short and clear.
6. **Arcade snap, a little stiff.** Reviews agree it is the No Mercy formula:
   weak/strong grapple, then direction plus button, with signatures and specials
   on their own inputs. They describe the motion as "arcade-like fluidness"
   ([Push Square](https://pushsquare.com/reviews/ps5/aew-fight-forever)), but
   also as "passable … many feel pretty stiff"
   ([MP1st](https://mp1st.com/news/aew-fight-forever-review-room-to-become-elite)),
   with a toy-like, stylised look
   ([Cultaholic](https://cultaholic.com/posts/aew-fight-forever-review),
   [GGRecon](https://www.ggrecon.com/articles/aew-fight-forever-is-the-no-mercy-successor-ive-always-wanted),
   [CogConnected](https://cogconnected.com/review/aew-fight-forever-review/)).
   Reports disagree on whether motion capture was used
   ([Antyweb](https://antyweb.pl/aew-fight-forever-recenzja)), so nothing
   here depends on it.

## The moves in the video, as read

S = signature, X = special. Numbers are Fight Forever's variant numbers.

| Wrestler | Moves seen |
| --- | --- |
| Abadon | Cemetery Drive (X) |
| Adam Cole | Snapmare 1, Shining Wizard, Ushigoroshi (S); The Boom, Panama Sunrise 2 (X) |
| Hangman Page | Pop-Up Powerbomb 1, Rope Fallaway Slam Moonsault (S); Rope Fallaway Slam Moonsault, Dead Eye, Buckshot Lariat (X) |
| Andrade | Backbreaker/Final Cut Combo, Jawbreaker, Brutalizer (S); El Idolo 3 (X, with replay) |
| Anna Jay | Jay Kick 1 (S); Queen Slayer (X) |
| Brian Cage | Buckle Bomb, Weapon X (S); Drill Claw, Avalanche Drill Claw (X) |
| Britt Baker | Sling Blade 3, Fisherman Neckbreaker (S); Lock Jaw 2, Strong Stomp 2 (X) |
| Bryan Danielson | Kick Combo, Diving Headbutt 1 (S); LeBell Lock 2, Cattle Mutilation, Flying Single Leg Knee Strike 1 (X) |
| Cash Wheeler | Spinebuster 5 (X) |
| Chris Jericho | Code Breaker 1, Code Breaker 3, Springboard Moonsault 3 (S); Diving / Running / standing Judas Effect (X) |
| Christian Cage | Diving Frog Splash, Inverted DDT 1 (S); Inverted DDT 1, Unprettier, Spear 2 (X) |
| Chuck Taylor | Sit-Out Piledriver 6 (S); Sole Food (X) |
| CM Punk | Scoop Slam 2, Anaconda Vise (S); GTS 2 (X) |
| **Cody Rhodes** | **Cody Cutter 4, Figure Four Leglock (S); Tiger Driver '98, Cross Rhodes (X)** |
| Darby Allin | Code Red 2 (S); Float-Over Stunner, Coffin Drop 1, Neck Crank (X) |
| Dax Harwood | Sit-Out Powerbomb 2 (S); Brainbuster 1 (X) |
| Dustin Rhodes | Code Red 1 (S); Code Red 1, Final Reckoning (X) |
| Eddie Kingston | Sleeper Suplex (S); Spinning Back Fist (X) |
| Hikaru Shida | Falcon Arrow 3, Fireman Carry Backbreaker (S); Snapmare 1, Katana, Tamashi No (X) |
| Jade Cargill | Spinebuster 5, Jaded (X) |
| Jeff Hardy | Gourdbuster 4, Twist of Fate 1, Swanton Bomb (X) |
| John Silver | The Meat Man Combo (S); Spin Doctor, Avalanche Torture Rack Bomb (X) |
| Jon Moxley | Gotch Style Piledriver (S); Arm Trapped Elbow Strikes, Bulldog Choke 2 (X) |
| Jungle Boy | Avalanche Poison 'Rana (S); Poison 'Rana 1 (X) |
| **Kenny Omega** | **Running V-Trigger 3, Powerbomb/V-Trigger Combo, Snap Dragon Suplex 3, Snap Dragon Suplex 2 (S); Running V-Trigger 1, V-Trigger 1, One Winged Angel (X)** |
| Kris Statlander | Electric Chair Facebuster 1 (X) |
| Lance Archer | Chokeslam 1, Old School Moonsault (S); Black Out 1, Black Out 2 (X) |
| Luchasaurus | Fireman Carry Bomb 2 (S and X) |
| Malakai Black | Brainbuster 1 (S); The End (X) |
| Matt Hardy | Side Effect 1 (S); Twist of Fate 2, Middle Rope Twist of Fate (X) |
| Matt Jackson | Locomotion Northern Lights (S); Superkick 3, Wheelbarrow Facebuster (X) |
| Miro | Superkick 1 (S); Game Over (X) |
| MJF | Butterfly Shoulder Breaker, Heat Seeker (S); Salt of the Earth, Dynamite Diamond Ring Punch (X) |
| Nick Jackson | Slingshot Destroyer (S); Superkick 5, 450 Splash 1 (X) |
| Nyla Rose | Draping Diving Knee Drop (S and X) |
| Orange Cassidy | Orange Punch (S and X); Beach Break (X) |
| PAC | Sit-Out Powerbomb 2, Diving Shooting Star (S); Black Arrow, Brutalizer (X) |
| Penta | Penta Driver (S); Package Piledriver 2 (X) |
| Powerhouse Hobbs | Spinebuster 5, Oklahoma Stampede (X) |
| Aubrey Edwards | Superkick 5 (S and X) |
| Fenix | Running Step-Up Tornillo Kick (S); Fenix Driver 1, Fenix Driver 2 (X) |
| Ricky Starks | Spear 2 (S and X); Rochambeau (X) |
| Riho | Diving Foot Stomp 1, Victory Roll Foot Stomp (S); Gannosuke Clutch (X) |
| Ruby Soho | Corner Thrice Superkicks (S); No Future (X) |
| Sammy Guevara | Squatting Samoan Drop, Cody Cutter 5, Diving Shooting Star (S); Cody Cutter 5, 630 Splash (X) |
| Scorpio Sky | Pendulum Backbreaker 5, Slingshot Cutter, TKO, Heel Hook (X) |
| Sting | Stinger Splash 2, Scoop Slam 2 (X) |
| Tay Conti | Modified Lotus Lock, Tay-KO, DD-Tay (X) |
| Thunder Rosa | Running Lariat/Slingshot Meteora Combo (X) |
| Trent | Sit-Out Piledriver 1, Flying Single Leg Knee Strike 2, Strong Zero 1, Basement Single Leg Knee Strike 2 (X) |
| Wardlow | Fireman Carry Buster, Powerbomb 1, Casualty of War (X) |
| Yuka Sakazaki | Sleeper Hold, Magic Girl Splash 1, Crucifix Pin, Hammerlock Airplane Spin, Half-Moon Magic Girl Splash 1, Magic Girl 450 Splash (X) |

A few short moves may sit in sub-four-second banner gaps not swept here. Of
these wrestlers, only **Cody** and **Kenny** are on our roster; Roman Reigns
is not in Fight Forever.

## The Gemini breakdown: verdict

**Useful as a checklist of names, not as a source.** Roughly three-quarters
of the move names are real Fight Forever move names. But the attributions
are often wrong, every number is invented, and the technical brief doesn't
fit this project.

What is wrong:

- **Moves credited to the wrong wrestler:**
  - **Penta's** list (Butterfly Shoulder Breaker, Heat Seeker, Salt of the
    Earth, Dynamite Diamond Ring Punch) is **MJF's**. Penta's moves are the
    Penta Driver and Package Piledriver 2.
  - **Neck Crank** is **Darby Allin's**, not Jericho's.
  - **Code Red 2, Float-Over Stunner and Coffin Drop** are **Darby's**;
    "Dustin Rhodes / Barry" merges two wrestlers. Dustin's moves are Code
    Red 1 and Final Reckoning.
  - **Cemetery Drive** is **Abadon's** move, not Adam Cole's, and Abadon's
    "Kneeling 'Rana Spike DDT" does not appear.
- **Whole wrestlers missing:** Darby Allin, Miro, MJF, Fenix and Aubrey
  Edwards.
- **Moves listed but not in the video:**
  - Jericho's Walls of Jericho
  - both Bucks' Sharpshooter
  - Cash's Gory Facebuster
  - Kenny's middle-rope and standing V-Trigger and Avalanche One Winged Angel
  - Cody Cutter 5 for Cody (it is Sammy's; Cody's is Cody Cutter 4)
- **Invented numbers:** "4-frame wind-up", "2-frame hit-stop", "8-frame
  Bay-Bay wind-up". None of these can be read off a compilation video, and
  the measured footage shows no whole-frame hit-stop at all.
- **Wrong for this project:**
  - "Forward Mobile renderer": we ship Forward+ on Metal.
  - "two-actor IK constraints": our paired moves are authored paired clips
    placed by `GrappleRig`.
  - It specs code for a roster of about 50 wrestlers when we have three, one
    of whom isn't in the game.
- **Pasted citation debris:** the `[span_N](start_span)` markers.

Feeding that "master prompt" to another model to write code would fork the
project away from its own contract (`gauntlet/anchor/ARCHITECTURE.md`) and
its clip pipeline. Use the corrected table above instead.

## Our in-match animation against it

| Area | Ours now | Fight Forever | Gap |
| --- | --- | --- | --- |
| Lock-up | Chain holds 1.8 s (24 / 54 / 30 frames) | Tie-up reads in about 0.3 s, then straight into the move | Far slower |
| Running attacks | **26 running moves all share the same 18 / 5 / 46 frame data** (1.15 s) | Each move has its own timing | Placeholder timing |
| Signature and special timing | Cross Rhodes 50 / 10 / 36; Spear 38 / 10 / 36 | Cross Rhodes hoist to impact about 0.8 s, attacker up about 1 s later | Close; ours is roughly right |
| Impact emphasis | Hit-stop: heavy 2 ticks, medium 0; flinch; selling tiers | No freeze: a hard camera cut on impact, then an exaggerated bounce | Need the cut, not more freeze |
| Camera | 2K26 broadcast grammar (hard camera plus handheld, cuts only) | High wide hard camera; **low close ringside cut for grapples, signatures and specials**, back to wide for recovery; some specials get an instant replay | Missing the grapple close-up cut |
| Move tiers | Strike / grapple / power / running / signature / finisher, drawn per wrestler | Shared numbered library plus a few unique specials per wrestler | Restructure as variants |
| Pacing | Tuned to 2K26: beat gap 4.4–4.8 s, about 8-minute matches | Shorter gaps, faster exchanges | 2K26 calibration conflicts |
| HUD on a big move | None per move | SIGNATURE/SPECIAL gauge flash plus top-left move banner | Missing |
| Cody | Cody Cutter (springboard), Figure Four, Cross Rhodes (from behind), Disaster Kick, Pedigree | Cody Cutter 4, Figure Four, Tiger Driver '98, Cross Rhodes | Tiger Driver '98 missing; the standard Cross Rhodes should be the default |
| Kenny | **No moveset of his own**: shared draws | V-Triggers (running, standing), Snap Dragon 2 and 3, Powerbomb/V-Trigger Combo, One Winged Angel | His whole identity is missing |
| Roman | Superman Punch, Spear, 2K26 moveset | Not in Fight Forever | Restyle his moves to FF timing; keep his moves |

## Recommended order (not started)

1. **Camera first; biggest change for least work.** Add an FF-style grapple
   cut: on a grapple, signature or special, cut to a low ringside close-up
   (the AEW screens behind) on the lock-up or the impact, and back to the high
   wide hard camera for the recovery. Add an instant replay after a special
   that wins or nearly wins. Keep hit-stop tiny.
2. **Faster lock-ups and running attacks.** Take chain tie-ups from 1.8 s
   toward about 0.5 s. Give the 26 running attacks real per-move frame data,
   re-keyed in `wrestling_clips.py`, with the clip gates intact.
3. **Signature/special HUD:** the gauge flash plus the top-left move banner.
4. **Kenny's moveset:** V-Trigger (running and standing), Snap Dragon,
   Powerbomb/V-Trigger Combo and One Winged Angel, authored as paired clips.
5. **Cody to the FF list:** add Tiger Driver '98, and make the standard Cross
   Rhodes the default special.
6. **Pacing:** retune the AI beat gap and match length toward FF only after
   steps 1–5 land, because the 2K26 numbers are pinned by tests and the
   owner's earlier rounds.

Each step closes on rendered frames and a review sheet, as every round has.
