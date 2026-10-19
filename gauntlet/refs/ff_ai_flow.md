# AI-vs-AI match flow: Fight Forever, wrestling psychology, and ours

The owner, 19 Oct: "lots of repetition of moves between Roman and Cody, it
needs to apply the expanded moveset they now have and the flow of the match
has to make logical sense."

## What is known about Fight Forever's CPU

Yuke's has published nothing on how the CPU picks moves. What follows comes
from reviews, guides and player reports, so treat it as observed behaviour,
not a specification.

- **The No Mercy formula.** Weak and strong strikes, weak and strong
  grapples, blocks that reverse, and signatures and specials on their own
  inputs.
  - Sources: [Push Square](https://pushsquare.com/reviews/ps5/aew-fight-forever),
    [RealSport101 controls](https://realsport101.com/article/aew-fight-forever-controls-guide-grapple-springboard-finishers-full-guide).
- **Momentum, not a life bar.**
  - Varied offence builds momentum faster. Using top-rope moves on a downed
    man is the example given.
  - Taunting at "Signature" turns the meter to "Special".
  - A special has to be used inside a window of about 30 seconds, or the
    momentum drops.
  - Sources: [Wccftech tips](https://wccftech.com/how-to/aew-fight-forever-guide-basic-wrestling-tips/amp/),
    [WePC signatures](https://www.wepc.com/gaming/aew-fight-forever-signatures/),
    [WePC finishers](https://www.wepc.com/gaming/aew-fight-forever-finishers/).
- **Limb damage.** Each body part takes damage separately. Submissions work
  on a limb that has been worn down.
  - Pins and submissions succeed when the man underneath is low on both
    health and momentum.
  - Sources: [Wccftech tips](https://wccftech.com/how-to/aew-fight-forever-guide-basic-wrestling-tips/amp/),
    [SGO preview](https://www.sportsgamersonline.com/featured/aews-moment-a-gameplay-preview-of-aew-fight-forever/).
- **Damage changes the pace.**
  - As a wrestler takes damage, recovery slows and stuns grow longer.
  - Late in a match a downed man stays down for a while. That leaves room
    for a big move or a cover.
  - Source: [Gamecritics](https://gamecritics.com/stevegillham2gc/aew-fight-forever-review/).
- **CPU habits players report.**
  - The CPU opens with a strike and follows with a grapple.
  - Its attacks are mostly short strike strings ending in a grapple.
  - It counters far more on harder difficulties.
  - It goes for its special inside the window.
  - Sources: [GameRant reversals](https://gamerant.com/aew-fight-forever-reverse-counter/),
    [Gamecritics](https://gamecritics.com/stevegillham2gc/aew-fight-forever-review/),
    [Steam discussion](https://steamcommunity.com/app/1913210/discussions/0/3811783264377032065).
- **Its weak spot.** Players say CPU matches "don't behave like a real
  wrestling match"
  ([Steam](https://steamcommunity.com/app/1913210/discussions/0/3811782858770929695)).
  So the game's AI is a floor to clear, not a ceiling.

## What a televised singles match is

TV's match structure is **shine, heat, comeback, finish**
([PWO forums](https://forums.prowrestlingonly.com/topic/14256-break-it-down-2-alternative-match-structures/)).

1. **Shine.** The face gets the early offence.
2. **Heat.** The heel cuts him off and controls the match: slower moves, rest
   holds, working a body part, playing to the crowd.
3. **Hope spots.** The face fights back for a moment, and the heel cuts him
   off again
   ([PWO terms](https://forums.prowrestlingonly.com/topic/21404-terminology-question/)).
4. **Comeback.** The face rallies with his signature strikes, then a big move.
5. **Finish.** Near-falls, signature and finisher kickouts, then the
   finisher.

Wrestling psychology adds a few rules:
- A move earns its place by where it falls in the story.
- The biggest moves come late.
- A man's signature move is seen a handful of times at most.
- Rest holds slow the pace so the next burst lands harder.

Our `MatchFlow` already has these phases (feeling-out, heat, hope, cut-off,
comeback, finish). Move choice does not use them.

## Ours, measured (flow_probe --moves 1, Roman v Cody, 19 Oct, after batch 1)

| | Seed 1 | Seed 2 |
| --- | --- | --- |
| Length | 9.1 min | 11.1 min |
| Result | Cody wins with Cross Rhodes | **No winner** (budget ran out) |
| Moves landed | 343 | 419 |
| Pace | 37.7 a minute | 37.7 a minute |
| Tie-ups | 78 | 76 |
| Average control run | 2.8 moves | 3.4 moves |

Seed 1, who threw what:

- **Cody: 240 moves.**
  - Strikes: Bionic Elbow 44, jab 32, ground punch 25, ...
  - Big moves: **Sit-Out Powerbomb 11, Brainbuster 10, Tiger Driver 6,**
    Alabama Slam 6, Powerslam 6, Cross Rhodes 4.
- **Roman: 103 moves.** Mostly strikes. Spinebuster, Powerbomb, Samoan Drop
  and Superman Punch once each.

What that shows:

1. **Ping-pong, not a story.** In the heel heat (60–210 s), Cody threw most
   of the offence. The man meant to be beaten down was the busier one.
   Control runs average fewer than three moves, so nobody is ever in control.
2. **Big moves from the bell.** The Brainbuster came at 10 s, 20 s and 39 s.
   The Tiger Driver and both powerbombs were spread across the whole match.
   Our phase gate stops only signatures and finishers. Power moves, the FF
   specials among them, are open at any time.
3. **No scarcity.**
   - A move is skipped only if it was one of the last few picks, so
     everything recurs every few minutes.
   - The Bionic Elbow was thrown 44 times.
   - Every grapple is followed by the same ground punch or stomp.
4. **Too busy.** At 38 moves a minute, three quarters of them strikes, the
   match never slows down. That is where the "repetitive punching" comes
   from.
5. **No rest holds, no limb work, no Irish whips or corner spots**, and the
   Figure Four is never used.
6. **The finish can fail.** Seed 2 ran 11 minutes without a winner. This was
   pre-existing (`README`, 19 Oct).

## The match we want: Roman (heel) v Cody (face)

| Phase (`MatchFlow`) | Who leads | What it looks like |
| --- | --- | --- |
| Feeling-out, 0–60 s | Even | Lock-ups and chain holds (headlock, wristlock), a few strikes, a shoulder block or running attack. **No slams or big moves.** |
| Cody's shine | Cody | A short burst: strikes, a dropkick, one suplex. |
| Heat, 60–210 s | Roman (about 70% of moves) | Clubbing blows and stomps. A **rest hold** (chinlock or headlock on the mat) with Cody fighting it. An Irish whip into the corner, then corner clotheslines. **One** power move (Samoan Drop or Spinebuster). A taunt. |
| Hope, 210–245 s | Cody | Two or three strikes and a quick suplex. |
| Cut-off, 245–300 s | Roman | One big move (Powerbomb), a cover for a near-fall, a rest hold. |
| Comeback, 300–390 s | Cody | Fires up: 3–4 Bionic Elbows, the Disaster Kick, one big move (Tiger Driver or Brainbuster), a cover. |
| Finish, 390 s on | Trading | Signatures from both. One finisher kicked out of, then the finish. |

Rules that make it hang together:

1. **Every move has a place in the story.** A move gets an earliest phase
   (basic, mid-match or late) and a cap on how often it's used.
   - Big moves: once a match.
   - Slams and suplexes: about twice.
   - The signature strike: once per burst.
2. **Whoever the phase favours has the initiative.** The other man mostly
   sells, and gets offence only in his hope spots and comeback.
3. **Pace.** Aim for about 15–20 moves a minute, with rest holds and covers
   as the breathing room.
4. **Variety after a big move.** Cover for a near-fall, pick him up, taunt, go
   to the corner, or a ground strike — not the same stomp every time.
5. **Every match has a winner**, every seed.

## Pass marks for the change (flow_probe, three seeds, Roman v Cody)

- Every seed has a winner.
- 15–20 moves a minute.
- Strikes at most 55% of moves.
- No big move before 60 s, and none thrown more than once.
- No non-strike move thrown more than twice.
- No strike more than 15% of a man's moves.
- Roman throws at least 65% of the moves in the heat.
- At least two rest holds and at least two near-falls each match.

## After the rework (19 Oct, same probe, seeds 1–3)

| | Before | After |
| --- | --- | --- |
| Winner | seeds 1 only (2 ran out) | **all three**, the man the story picked |
| Length | 9.1–11.1 min | 7.1 min, each off a finisher |
| Pace | 37.7 / min | 26–29 / min (target 15–20 not yet met) |
| Strikes | 74–77% | 77–79% |
| Cody's vertical suplex | 8–24 a match | 3–5 |
| Specials (Tiger Driver, Brainbuster, Sit-Out Powerbomb) | up to 11 each, from 10 s in | once each, comeback and finish only |
| Roman's share of the heat | 47–53% | 55–63% |

Still open:
- **Pace and strike share.** Holding the leader's strikes back without
  creating idle gaps needs more of what a match spends its time on: longer
  rest holds, covers after big moves, corner and rope spots (task #84).
- **Cody's other grapples repeat once his tier is used up.** Body slam and
  neckbreaker reached five each in seed 2; more moves in the tier is the fix.
- **Limb work and the Figure Four.**
