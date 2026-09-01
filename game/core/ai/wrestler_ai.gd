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

## Tie-up mashing: same reaction-delay/press-interval shape as the kickout
## tunables above. First-pass values; see test_tie_up_minigame.gd.
@export var tie_up_reaction_ticks: int = 10
@export var tie_up_press_interval_ticks: int = 8

## Whip decision (attacker, resolving a grapple): chance of whipping instead
## of taking the normal grapple/power/signature/finisher escalation, rolled
## only when below CombatSystem.POWER_THRESHOLD (see _should_whip()) --
## first-pass value, no reference data exists (gauntlet/refs/timings.md
## marks ring-crossing/whip timing "pending"), same caveat as every other
## tuning constant in this project.
@export var whip_chance: float = 0.3
## Reversal reaction delay: ticks the opponent's reversal window must have
## already been open before this AI presses "reversal" -- same shape as
## kickout_reaction_ticks/tie_up_reaction_ticks (a stand-in for human
## reaction time), sized small since the windows this actually has to catch
## are narrow (strike_jab.tres: 4 ticks: 6-9; running_attack_clothesline.tres:
## 6 ticks: 7-12) -- a real but imperfect response, not a guaranteed one.
@export var reversal_reaction_ticks: int = 2

var _cooldown: int = 0
var _pin_defender_tick: int = 0
var _last_kickout_press_tick: int = -1000
var _tie_up_tick: int = 0
var _last_tie_up_press_tick: int = -1000
## Number of times this AI has been the grapple attacker this match --
## gives each grapple's whip roll (see _should_whip()) its own seed rather
## than repeating the same roll every time.
var _grapple_attempts: int = 0
## Ticks the opponent's active move has continuously been inside its own
## reversal window -- reset the instant it isn't (opponent left
## STRIKE/RUNNING_ATTACK, or the window closed). See _maybe_press_reversal().
var _reversal_window_ticks: int = 0
## Set by setup_jitter() -- stored so _should_whip() can derive its own
## seed the same deterministic way (match_seed, player_index, ...) without
## re-plumbing match_seed through poll_input() on every call. Defaults to 0
## for direct WrestlerAI.new() construction (unit tests), same as every
## other setup_jitter()-only field.
var _match_seed: int = 0
var _player_index: int = 0

## Max ticks setup_jitter() may shift tie_up_reaction_ticks/
## tie_up_press_interval_ticks by, either direction.
const TIE_UP_JITTER_TICKS := 2

## Applies a small, deterministic per-instance timing offset to the tie-up
## mash tunables, derived from (match_seed, player_index) rather than raw
## RNG — so two AI opponents with identical exported defaults don't mash on
## the exact same ticks forever (see match_referee.gd's tie-break comment:
## with zero jitter, two such opponents tie on literally every single
## tie-up, and only an explicit rule decides it — this makes that the rare
## case instead of the only case). Deterministic per (match_seed,
## player_index): the same match replays identically (ReplaySystem
## contract), only the seed/slot combination varies. Call once at setup,
## not per-tick — this is a fixed instance property, not live randomness.
## Not called by match_setup.gd for a non-AI wrestler, and not called at all
## by direct WrestlerAI.new() construction (e.g. in unit tests), which is
## intentional — tests get the un-jittered baseline tunables.
func setup_jitter(match_seed: int, player_index: int) -> void:
	_match_seed = match_seed
	_player_index = player_index
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed * 4096 + player_index
	tie_up_reaction_ticks = max(1, tie_up_reaction_ticks + rng.randi_range(-TIE_UP_JITTER_TICKS, TIE_UP_JITTER_TICKS))
	tie_up_press_interval_ticks = max(1, tie_up_press_interval_ticks + rng.randi_range(-TIE_UP_JITTER_TICKS, TIE_UP_JITTER_TICKS))

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
	if controller.fsm.current_state == WrestlerFSM.State.TIE_UP:
		_tie_up_tick += 1
		return {"grapple": _should_press_tie_up(_tie_up_tick)}
	_tie_up_tick = 0
	_last_tie_up_press_tick = -1000
	if controller.fsm.current_state == WrestlerFSM.State.GRAPPLE_HOLD:
		# Only the attacker acts here (mirrors WrestlerController._process_
		# grapple_hold()'s own early return for the non-attacker side) --
		# the defender has nothing to press mid-grapple; MOVE_EXEC's own
		# reversal window is structurally unreachable (see match_referee.gd's
		# _check_for_reversal() doc comment), so there's no decision to make
		# here for the defender either.
		if controller._is_grapple_attacker:
			_grapple_attempts += 1
			return {"run": _should_whip()}
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
	_maybe_press_reversal(input)

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

## Whether to press "grapple" this TIE_UP tick — same rate-limited mash
## policy as _should_press_kickout(), minus the marker-window check (there's
## no target zone here, just a race of qualifying press counts; see
## tie_up_minigame.gd).
func _should_press_tie_up(tick: int) -> bool:
	if tick <= tie_up_reaction_ticks:
		return false
	if tick - _last_tie_up_press_tick < tie_up_press_interval_ticks:
		return false
	_last_tie_up_press_tick = tick
	return true

## Whether to whip instead of taking the normal grapple/power/signature/
## finisher escalation this GRAPPLE_HOLD tick. Never whips once already
## able to reach the power tier or above (WrestlerController._process_
## grapple_hold() would otherwise spend that momentum on a whip that deals
## no direct damage, instead of the stronger escalating move) -- below that,
## a seeded coin flip, deterministic per (match_seed, player_index,
## _grapple_attempts) so each grapple attempt in the match gets its own
## reproducible-but-varying roll (same shape as MatchReferee.
## _break_tie_up_tie()'s match_seed * 4096 + tick seeding, keyed off an
## attempt counter instead since a whip decision is one-shot per grapple,
## not per-tick).
func _should_whip() -> bool:
	if controller.combat.can_power():
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = _match_seed * 4096 + _player_index * 97 + _grapple_attempts
	return rng.randf() < whip_chance

## Whether to press "reversal" this tick -- true only once the opponent's
## STRIKE/RUNNING_ATTACK has already been inside its own reversal window for
## more than reversal_reaction_ticks, a stand-in for human reaction time
## (same shape as _should_press_kickout()'s reaction delay). Resets the
## instant the opponent leaves those states or the window closes, so a
## fresh move needs its own fresh reaction delay -- this can't just hold
## the button down and get every window for free.
func _maybe_press_reversal(input: Dictionary) -> void:
	if not target._active_move or not target.fsm.is_in([WrestlerFSM.State.STRIKE, WrestlerFSM.State.RUNNING_ATTACK]):
		_reversal_window_ticks = 0
		return
	var frame_offset := target._active_move.total_frames() - target._move_ticks_remaining
	if not target._active_move.is_in_reversal_window(frame_offset):
		_reversal_window_ticks = 0
		return
	_reversal_window_ticks += 1
	input["reversal"] = _reversal_window_ticks > reversal_reaction_ticks
