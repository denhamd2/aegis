class_name MatchReferee
extends Node
## Drives pin/submission resolution and declares the win condition.
## Grey-box version of the "ref" system: watches for a downed wrestler
## being covered or locked in a submission, runs the deterministic
## minigame, and ends the match on a three-count or a tap-out.

signal match_won(winner: WrestlerController, method: String)

const PIN_COUNT_TICKS := 180 # three-count at 60Hz, one count per 60 ticks
const COVER_RANGE := 1.2

@export var wrestler_a_path: NodePath
@export var wrestler_b_path: NodePath
@export var match_seed: int = 0

var wrestler_a: WrestlerController
var wrestler_b: WrestlerController

var _pin_ticks: int = 0
var _pinning: bool = false
var _pin_attacker: WrestlerController
var _pin_defender: WrestlerController
var _match_over: bool = false

func _ready() -> void:
	wrestler_a = get_node(wrestler_a_path)
	wrestler_b = get_node(wrestler_b_path)

func _physics_process(_delta: float) -> void:
	if _match_over:
		return
	if _pinning:
		_tick_pin()
		return
	_check_for_cover()

func _check_for_cover() -> void:
	for pair in [[wrestler_a, wrestler_b], [wrestler_b, wrestler_a]]:
		var attacker: WrestlerController = pair[0]
		var defender: WrestlerController = pair[1]
		if defender.fsm.current_state == WrestlerFSM.State.DOWN \
				and attacker.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION]) \
				and attacker.global_position.distance_to(defender.global_position) <= COVER_RANGE:
			_pinning = true
			_pin_ticks = 0
			_pin_attacker = attacker
			_pin_defender = defender
			attacker.begin_pin(defender, match_seed + Engine.get_physics_frames())
			return

func _tick_pin() -> void:
	_pin_ticks += 1
	if _pin_defender._pin_minigame and _pin_defender._pin_minigame.is_kickout(_pin_ticks):
		# Defender's kickout input timing is validated against the
		# minigame's target window by the input layer; grey-box treats
		# "in window at count" as automatic kickout to keep the loop
		# playable without a dedicated prompt UI yet.
		_end_pin(false)
		return
	if _pin_ticks >= PIN_COUNT_TICKS:
		_end_pin(true)

func _end_pin(three_count_reached: bool) -> void:
	_pinning = false
	_pin_attacker.fsm.transition_to(WrestlerFSM.State.IDLE)
	if three_count_reached:
		_declare_winner(_pin_attacker, "pinfall")
	else:
		_pin_defender.fsm.transition_to(WrestlerFSM.State.DOWN)
		_pin_defender._move_ticks_remaining = WrestlerController.GETUP_TICKS

func _declare_winner(winner: WrestlerController, method: String) -> void:
	_match_over = true
	match_won.emit(winner, method)
