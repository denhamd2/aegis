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

## Kickout mashing: reaction delay before the first press attempt, and the
## minimum ticks between two presses — a stand-in for physical mash-rate
## limits (an engineering judgment call, not a cited realism claim).
## First-pass values; see test_pin_minigame_kickout.gd.
@export var kickout_reaction_ticks: int = 10
@export var kickout_press_interval_ticks: int = 5

var _cooldown: int = 0
var _pin_defender_tick: int = 0
var _last_kickout_press_tick: int = -1000

func _physics_process(_delta: float) -> void:
	if not controller or not target:
		return
	if _cooldown > 0:
		_cooldown -= 1

func poll_input() -> Dictionary:
	if not controller or not target:
		return {}
	if controller.fsm.current_state == WrestlerFSM.State.PIN_DEFENDER:
		_pin_defender_tick += 1
		return {"strike": _should_press_kickout(_pin_defender_tick, controller._pin_minigame)}
	_pin_defender_tick = 0
	_last_kickout_press_tick = -1000
	if controller.fsm.current_state == WrestlerFSM.State.SUBMISSION_DEFENDER:
		# Held every tick, not rate-limited: SubmissionMinigame is a genuine
		# continuous-hold rate race (see submission_minigame.gd), unlike
		# PinMinigame's press-limited fill-meter, so there's no discrete-press
		# semantic to model here.
		return {"submission_hold": true}
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

## Whether to press the kickout button this PIN_DEFENDER tick. Rate-limited
## to mirror a human's Input.is_action_just_pressed semantics (a real press
## every tick isn't physically achievable) rather than the AI simply
## holding the button, and only presses when the marker is actually inside
## the target window — the same information a human sees on the minigame UI.
func _should_press_kickout(tick: int, minigame: PinMinigame) -> bool:
	if tick <= kickout_reaction_ticks:
		return false
	if tick - _last_kickout_press_tick < kickout_press_interval_ticks:
		return false
	if minigame == null or not minigame.marker_in_window(tick):
		return false
	_last_kickout_press_tick = tick
	return true
