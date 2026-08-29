class_name WrestlerAI
extends Node
## Minimal grey-box AI: closes distance, ties up in range, strikes when
## not in range and off cooldown. Deterministic — driven off the same
## fixed-tick loop as the player, no bare RNG calls.

@export var controller: WrestlerController
@export var target: WrestlerController
@export var strike_range: float = 1.6
@export var tie_up_range: float = 1.3
@export var strike_cooldown_ticks: int = 40

var _cooldown: int = 0

func _physics_process(_delta: float) -> void:
	if not controller or not target:
		return
	if _cooldown > 0:
		_cooldown -= 1

func poll_input() -> Dictionary:
	if not controller or not target:
		return {}
	if not controller.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN]):
		return {}

	var to_target := target.global_position - controller.global_position
	to_target.y = 0.0
	var distance := to_target.length()

	var input := {
		"move": Vector2.ZERO,
		"strike": false,
		"grapple": false,
		"run": false,
	}

	if distance <= tie_up_range:
		input["grapple"] = true
	elif distance <= strike_range and _cooldown <= 0:
		input["strike"] = true
		_cooldown = strike_cooldown_ticks
	elif distance > strike_range:
		var dir := to_target.normalized()
		input["move"] = Vector2(dir.x, dir.z)

	return input
