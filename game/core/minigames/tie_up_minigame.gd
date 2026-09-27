class_name TieUpMinigame
extends RefCounted
## Symmetric mash contest for who wins the tie-up and becomes the grapple
## attacker. Both wrestlers press "grapple"; first to accumulate
## PROGRESS_THRESHOLD qualifying presses wins. No RNG — a pure function of
## each side's press ticks, so MatchReferee can arbitrate it deterministically.

## Ticks of qualifying presses needed to win. gauntlet/refs/timings.md's
## tie-up section is a lower bound only (contest reticle visible >=1.07s
## before the reference clip cuts away, unresolved) — this first-pass value
## lands in that neighborhood, not a precise measurement; confirm/retune via
## test_tie_up_minigame.gd and a live probe.
const PROGRESS_THRESHOLD := 10.0

var a_progress: float = 0.0
var b_progress: float = 0.0

## a_weight/b_weight: what one press is worth. 1.0, except against a man in
## the middle of his comeback -- see MatchReferee._tie_up_weight().
func tick(a_pressed: bool, b_pressed: bool, a_weight: float = 1.0, b_weight: float = 1.0) -> void:
	if a_pressed:
		a_progress += a_weight
	if b_pressed:
		b_progress += b_weight

func a_wins() -> bool:
	return a_progress >= PROGRESS_THRESHOLD

func b_wins() -> bool:
	return b_progress >= PROGRESS_THRESHOLD
