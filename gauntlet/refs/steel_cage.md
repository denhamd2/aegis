# Steel Cage (and the shared cage for Hell in a Cell): research, decisions

The owner's brief (9 Nov): new match types, each researched against the real
rules and against how AEW Fight Forever and WWE 2K play them. This file covers
the Steel Cage. Hell in a Cell builds on the same cage (`hell_in_a_cell.md`).

## The real match

- **WWE**: the ring is enclosed by a steel cage standing on the apron edge.
  The match is won by pinfall, by submission, or by **escape**: out through
  the door or over the top, and a man escapes when **both feet touch the
  floor**. The door is kept shut by an official outside it, and opened only
  when a man asks for it. There is no disqualification (the cage is not a
  weapon to be disqualified for) and no count-out (nobody can leave).
- Escape-only rules were the norm before the 1990s (Snuka vs Muraco, MSG
  1983, the leap off the top); the modern WWE default is all three.
- **AEW** cage matches are pinfall or submission only: escaping wins
  nothing.
- The set pieces of the match are: ramming a man's face into the steel and
  raking it along the mesh; whipping him into the cage wall; the near-escape,
  where a man is pulled back down off the top or caught at the door; the
  door slammed on someone's head; and the high spot off the top of the cage.

## AEW Fight Forever

- **Has no cage match.** The launch list had singles, tag, three-way and
  four-way, ladder, falls count anywhere, the exploding barbed-wire
  deathmatch, the Casino battle royal and the Unsanctioned Lights Out match,
  and reviews named the cage as the most obvious omission (ChannelLife,
  Jumpdashroll, Beebom). No DLC added it. AEW FF gives us no mechanics to copy
  here, only its general feel: short, readable interactions, no long button
  menus.

## WWE 2K (2K22-2K24; 2K24 and 2K25 unchanged in substance)

From outsidergaming.com's 2K22/2K23 steel-cage control guides, charlieintel
and sportskeeda on 2K24, and gamepur's 2K Battlegrounds guide:

- **Win conditions**: escape, pinfall, submission by default. Match options
  can turn escape off, and offer the older cage design as an alternative.
- **Climbing**: walk to the cage wall and press the climb button (R1/RB).
  Circle/B climbs back down. Light/heavy attack while climbing kicks an
  approaching opponent away.
- **Over the top**: once on top, a button press starts the escape, which
  takes **two escape mini-games** (mash, or hold if the accessibility option
  is set). Climbing gives you more time to fight off the other man than
  running for the door does.
- **The door**: stand at the door and call for it (L1/LB). The referee takes
  **about 20 s** to open it; walk away and he shuts it again. R1/RB goes
  through. While he is passing through the ropes the opponent can stop him
  (a mini-game); once the exit animation starts it cannot be stopped.
- **Cage as a weapon**: a hammer throw or heavy Irish whip sends a man into
  the cage wall.
- **On top of the cage**: seated, the stick shuffles along the top, strikes
  trade, and a heavy strike rams the man's head into the cage and throws him
  back into the ring. Standing on top, an attack is a dive at the man below
  for big damage.
- **Strategy the game teaches**: "Don't attempt an escape too early. Wait
  until your opponent has taken significant damage", ideally straight after
  a signature or a finisher has left him down.

## What we take, and the numbers

| | 2K | ours | why |
| --- | --- | --- | --- |
| Win conditions | escape / pin / submission | the same | the WWE rules; the AEW variant (pin and submission only) is the HIAC rule set, so it is in the game already |
| DQ / count-out | none | none | nobody can leave the ring; the cage is a weapon |
| Start a climb | climb button at the wall | **push into the cage** (the ropes) for `ROPE_PUSH_TICKS` | the same gesture No Holds Barred uses to go through the ropes; no new button, so the touch controls and the HUD already have it |
| Climb back down | B / Circle | push away from the wall | the same gesture, reversed |
| Over the top | two mash mini-games | a timed straddle, interruptible | the window the other man has to get there is the drama; our mini-games (pin, tie-up) already own mashing |
| Door | call, ~20 s, ropes interruptible, exit unstoppable | call, `DOOR_OPEN_TICKS` 3 s, interruptible until the exit starts | 20 s is a long time in a match that lasts five minutes; the rule of when it can be stopped is 2K's |
| Being stopped | a mini-game | the other man climbs after him and **pulls him off** (or, at the door, hits him first) | a visible set piece instead of a meter |
| Cage as weapon | whip / hammer throw into the wall | an **Irish whip at the ropes rams him into the cage** above them | the real spot, through a mechanic the game already has |
| Escape timing | "after a signature or finisher" | a man down from a signature stays down ~9 s, a finisher ~13 s (`DOWN_TICKS_*`), and a full climb-and-over takes about 9 s | so the strategy 2K teaches falls out of timings we already have |

## The cage

An original design, modelled in code (`core/ring/cage_builder.gd`) the way the
ring's ropes, turnbuckles and posts are: no downloaded asset, nothing to
license, and the same builder makes the Hell in a Cell structure from a
different spec.

- Square, standing on the apron edge, **4.3 m** above the canvas (5.3 m, about
  17 ft, above the arena floor) -- the modern WWE cage stands about 15-17 ft
  from the floor.
- Dark gunmetal frame: four corner posts, a top rail, two intermediate rails
  and a bottom rail on each side. Panels of chain-link mesh between them (a
  generated, deterministic alpha texture), which reads as a translucent haze
  at broadcast distance and as wire up close.
- One door, in the middle of the side nearest the hard camera (-X), hinged on
  one jamb, opening outward.
- No branding of any kind.

Sources: outsidergaming.com/wwe-2k23-cage-match-controls-guide,
charlieintel.com (WWE 2K24 Hell in a Cell guide),
sportskeeda.com (WWE 2K24 Hell in a Cell guide),
gamepur.com (How to win a Steel Cage match in WWE 2K Battlegrounds),
channellife.co.nz and jumpdashroll.com (AEW Fight Forever reviews).
