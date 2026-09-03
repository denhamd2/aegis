class_name SubmissionMinigame
extends RefCounted
## Deterministic dual-ring breaking-point contest: attacker and defender
## each push a ring toward the other's break point at a rate derived from
## CombatSystem.submission_break_rate(). Ticks at the fixed 60 Hz rate.

## Distance each ring travels before it breaks. Sets how long a hold runs:
## at the crossover rate of 1.6 (see WrestlerController.begin_submission)
## 240 is 150 ticks, i.e. 2.5s at 60Hz.
##
## That is the one submission sequence anyone has measured --
## gauntlet/refs/timings.md frame-stepped a hold applied at 673.00s to the
## referee's break signal at 675.5s. Read the caveat there before treating
## it as a target: it is a rope-break cycle rather than a hold played out
## to a tap, and it is a single instance.
##
## It was 100.0, which at the same rates is 62 ticks -- 1.03s, and
## measured over ten seeds every hold in the project did land in 61-63
## ticks. So holds resolved in well under half the only hold-to-break
## the corpus has ever timed.
const BREAK_POINT := 240.0

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
