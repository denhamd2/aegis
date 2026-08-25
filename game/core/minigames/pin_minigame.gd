class_name PinMinigame
extends RefCounted
## Deterministic shrinking-target-zone kickout contest.
##
## Fully driven by fixed-tick input (device or replay) and a seeded RNG,
## so identical seed+replay pairs always produce identical outcomes —
## required for the capture harness's end-state hash check.

const TICKS_PER_ATTEMPT := 90 # 1.5s at 60 Hz

var target_start: float
var target_width: float
var rng: RandomNumberGenerator

func _init(window_fraction: float, seed_value: int) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	target_width = clamp(window_fraction, 0.05, 1.0)
	target_start = rng.randf_range(0.0, 1.0 - target_width)

## marker_position in [0, 1], moving back and forth over TICKS_PER_ATTEMPT.
static func marker_position(tick: int) -> float:
	var t := float(tick % TICKS_PER_ATTEMPT) / float(TICKS_PER_ATTEMPT)
	return 0.5 - 0.5 * cos(t * TAU)

func is_kickout(tick: int) -> bool:
	var pos := marker_position(tick)
	return pos >= target_start and pos <= target_start + target_width
