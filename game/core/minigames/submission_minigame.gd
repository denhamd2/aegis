class_name SubmissionMinigame
extends RefCounted
## Deterministic dual-ring breaking-point contest: attacker and defender
## each push a ring toward the other's break point at a rate derived from
## CombatSystem.submission_break_rate(). Ticks at the fixed 60 Hz rate.

const BREAK_POINT := 100.0

var attacker_progress: float = 0.0
var defender_progress: float = 0.0
var attacker_rate: float
var defender_rate: float

func _init(attacker_break_rate: float, defender_break_rate: float) -> void:
	attacker_rate = attacker_break_rate
	defender_rate = defender_break_rate

func tick(attacker_input_held: bool, defender_input_held: bool, delta_ticks: int = 1) -> void:
	if attacker_input_held:
		attacker_progress += attacker_rate * delta_ticks
	if defender_input_held:
		defender_progress += defender_rate * delta_ticks
	attacker_progress = min(attacker_progress, BREAK_POINT)
	defender_progress = min(defender_progress, BREAK_POINT)

func attacker_wins() -> bool:
	return attacker_progress >= BREAK_POINT

func defender_escapes() -> bool:
	return defender_progress >= BREAK_POINT
