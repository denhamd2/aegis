class_name PinMinigame
extends RefCounted
## Deterministic shrinking-target-zone kickout contest.
##
## Fully driven by fixed-tick input (device or replay) and a seeded RNG,
## so identical seed+replay pairs always produce identical outcomes —
## required for the capture harness's end-state hash check.
##
## A single tick of "marker inside window" is not a win condition: the
## marker sweeps the entire [0,1] range every TICKS_PER_ATTEMPT ticks, so
## it passes through any nonzero-width window at least once regardless of
## input — which would make every pin attempt an automatic kickout before
## a three-count could ever land. Instead this is a fill meter: progress
## accumulates only on ticks where the marker is in-window AND the
## defender is pressing, and needs to cross PROGRESS_THRESHOLD. A narrow
## window (high damage/attacker momentum, see CombatSystem.kickout_window_
## fraction) means fewer in-window ticks per sweep, so it genuinely takes
## longer — or fails to fill before MatchReferee.PIN_COUNT_TICKS runs out.

const TICKS_PER_ATTEMPT := 90 # 1.5s at 60 Hz
## Ticks of held in-window input needed to kick out.
const PROGRESS_THRESHOLD := 30.0

var target_start: float
var target_width: float
var rng: RandomNumberGenerator
var progress: float = 0.0

func _init(window_fraction: float, seed_value: int) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	target_width = clamp(window_fraction, 0.05, 1.0)
	target_start = rng.randf_range(0.0, 1.0 - target_width)

## marker_position in [0, 1], moving back and forth over TICKS_PER_ATTEMPT.
static func marker_position(tick: int) -> float:
	var t := float(tick % TICKS_PER_ATTEMPT) / float(TICKS_PER_ATTEMPT)
	return 0.5 - 0.5 * cos(t * TAU)

func _marker_in_window(tick: int) -> bool:
	var pos := marker_position(tick)
	return pos >= target_start and pos <= target_start + target_width

## Advances the fill meter for one tick and returns true once the
## defender has kicked out (crossed PROGRESS_THRESHOLD).
func tick(tick_index: int, input_pressed: bool) -> bool:
	if input_pressed and _marker_in_window(tick_index):
		progress += 1.0
	return progress >= PROGRESS_THRESHOLD
