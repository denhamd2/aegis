# The referee: Aubrey Edwards

What `RefereeActor` (on `AubreyModel`) does and why, from how AEW referees
work a match on a broadcast.

## Look

- The AEW referee shirt (`scratchpad` reference drawing, recorded here):
  black and white vertical stripes about 5 cm wide, a black stripe on the
  front centre-line where the placket is, a black collar, short sleeves with
  black cuff bands, the gold-lettered ALL ELITE / AEW / WRESTLING patch on the
  left chest.
- Black trousers with a black belt, the shirt tucked in; black shoes.
- About 1.70 m; dark brown shoulder-length hair.
- A referee's shirt is cut loose: it hangs off the chest and shoulder blades
  and falls straight to the tuck, blousing slightly over the belt. The first
  cut followed the body like paint, and the owner flagged it; see
  `tools/blender/referee_aubrey.py` (CHEST_LO, LEG_AXIS, WAISTBAND).

## Positioning

- With both men up: a couple of metres off the pair, square to the line
  between them, on the far side from the hard camera. She is in the back of
  the shot, never in front of it.
- A man down: bent forward, hands on the knees, watching the mat.
- Before the bell: waiting by the far ropes, off the centre line.

## The count

- A jog to the pinned man's head, down on both knees past it, chest low,
  the left hand posted and the right arm coming high to slap the canvas.
- The palm lands ON the count: each slap starts `SLAP_LEAD` ticks before
  `MatchReferee.COUNT_TICKS[i]`, the tick the HUD digit and the slap sound
  (`MatchAudio`) also use.
- A kick-out: straight back up. The three: up, the arm waved over the head
  for the bell, then to the winner's side (her right, facing the hard camera)
  and his hand raised.

## Recommendation: Aubrey to 2K26 standard

Research: 2K26's own material on referees is thin. Its patch notes
(1.05: "addressed reported concerns over the referee placement during
matches"; a Watch Show option to hide the referee's count HUD) and broadcast
footage of AEW referees are what there is. What 2K-series referees, and real
ones, do that ours does not yet:

| # | Behaviour | Why it matters | Effort |
| --- | --- | --- | --- |
| R1 | **Clearance with prediction.** Step off the line of a running man or an Irish whip *before* he arrives, not when he is within 1 m. | The 2K26 patch was about exactly this: a ref in the way reads as a bug. | Small |
| R2 | **Rope-break count.** Point at the rope, count 1-5 on her fingers, then pull the attacker off. | Today the rope break happens with her standing still. | Medium (2 clips) |
| R3 | **Submission check.** Down on one knee at the trapped man's face, asking "do you give up?", hand ready to call it. | A submission is the second way a match is decided. | Small (pose exists) |
| R4 | **Check on a downed man.** Crouch, a hand on his shoulder after a big bump. | Sells the bump; 2K refs do it every time. | Small |
| R5 | **Ring-out count.** At the ropes, arm up, counting with her fingers to ten when a man is outside. | Our dives put men on the floor; nobody counts. | Medium |
| R6 | **Signals.** "Ring the bell" circle (done), "no!" wave-off on a pinfall that was not a finisher, a five-count finger chop on a corner. | The vocabulary that makes a ref read as officiating, not standing. | Medium |
| R7 | **Ref bump.** Rarely, caught by a missed strike and down for a few seconds, so a cover goes uncounted. | 2K's most dramatic ref beat; optional. | Large (changes the match) |
| R8 | **Look-at.** Her head and eyes follow the action (EyeAim, as the wrestlers have). | Cheap, and a ref staring into space is the tell. | Small |

Recommended next: R1, R3, R4 and R8 together (all presentation-only, no
new clips beyond the poses we have), then R2/R5/R6 with three new clips.
R7 changes how matches end and is the owner's call.

Gloves: no. Nothing in her interviews, profiles or the AEW figure of her
shows gloves; AEW referees work bare-handed, and so does she.
