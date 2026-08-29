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
	if controller.fsm.current_state == WrestlerFSM.State.PIN_DEFENDER:
		# Mash to kick out every tick — grey-box stand-in for a timed
		# button prompt (see WrestlerController's PIN_DEFENDER handling).
		return {"strike": true}
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

	# Opponent is down: walk in for the cover instead of continuing to
	# strike/grapple decisions below. MatchReferee triggers the pin once
	# this wrestler is within its cover range and idle/moving.
	if target.fsm.current_state == WrestlerFSM.State.DOWN:
		if distance > 0.3:
			var dir := to_target.normalized()
			input["move"] = Vector2(dir.x, dir.z)
		return input

	if distance <= tie_up_range:
		input["grapple"] = true
	else:
		# Keep closing all the way to tie_up_range even once already inside
		# strike_range — tie_up_range < strike_range, so a wrestler that
		# stopped advancing the moment it could strike would settle at
		# strike_range forever and never reach tie_up_range at all. Strike
		# opportunistically while still approaching (matches this class's
		# own doc comment: "strikes when not in [tie-up] range"), not as a
		# reason to stop.
		var dir := to_target.normalized()
		input["move"] = Vector2(dir.x, dir.z)
		if distance <= strike_range and _cooldown <= 0:
			input["strike"] = true
			_cooldown = strike_cooldown_ticks

	return input
