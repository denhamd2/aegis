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

func tick(a_pressed: bool, b_pressed: bool) -> void:
	if a_pressed:
		a_progress += 1.0
	if b_pressed:
		b_progress += 1.0

func a_wins() -> bool:
	return a_progress >= PROGRESS_THRESHOLD

func b_wins() -> bool:
	return b_progress >= PROGRESS_THRESHOLD
