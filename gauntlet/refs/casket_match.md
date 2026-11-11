# Casket match

- **Win:** shut the other man in the casket. No pinfalls, no submissions, no
  disqualification. The weapons under the ring are in play.
- **The casket:** `CasketProp`, an original design built in code with no
  downloaded geometry. It is black lacquer with brass swing bars, a cream satin
  lining and a pillow at the head. It sits on a low draped bier on the ringside
  floor, hard-camera side, at (−4.75, floor, 1.9). The lid is hinged on the far
  long edge and stands open toward the barricade.
- **Getting him in:** with the other man in his hands on the floor within
  5.5 m of it, he whips him at its open side. The man goes up over the side and
  down into it (`ShutIn`, 34 ticks), and lies there (30 ticks). The whipper
  steps to the lid and shuts it (42 ticks).
- **Near-miss:** before the story's finish (`MatchFlow.finish_allowed`,
  `flow.winner`), the man inside gets a hand to the lid at 72% shut. He shoves
  it back up into the other man, climbs out over the side (50 ticks) and the
  fight goes on. There are at most 5 attempts a match.
- **AI:** on the floor near the casket, a man down is hauled up, then grabbed
  and sent in.
