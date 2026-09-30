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
