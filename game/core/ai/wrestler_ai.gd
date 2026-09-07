class_name WrestlerAI
extends Node
## Minimal grey-box AI: closes distance, then either ties up or strikes
## once close enough to do either. Deterministic — driven off the same
## fixed-tick loop as the player, no bare RNG calls.

@export var controller: WrestlerController
@export var target: WrestlerController
@export var tie_up_range: float = 1.3
@export var strike_cooldown_ticks: int = 40
## How often a close-range decision comes out as a strike instead of a
## tie-up. First-pass: high enough that punches and kicks are a real part
## of a match rather than an opening flourish, low enough that the grapple
## chain -- which is where the damage and the momentum actually are --
## still drives the match to a finish. Not traced to reference footage;
## gauntlet/refs/timings.md has nothing on strike-to-grapple ratio.
@export var close_strike_chance: float = 0.45
## Counts close-range decisions, so successive ones can differ. Part of the
## RNG seed only, never of gameplay state.
var _close_decisions: int = 0

## Kickout mashing: reaction delay before the first press attempt, and the
## minimum ticks between two presses — a stand-in for physical mash-rate
## limits (an engineering judgment call, not a cited realism claim).
## First-pass values; see test_pin_minigame_kickout.gd.
@export var kickout_reaction_ticks: int = 10
@export var kickout_press_interval_ticks: int = 5

## Tie-up mashing: same reaction-delay/press-interval shape as the kickout
## tunables above. First-pass values; see test_tie_up_minigame.gd.
##
## These are the *baseline* rates. setup_jitter() shifts them once per match
## so two identical AI opponents don't mash in lockstep, and
## _roll_tie_up_timing() then re-rolls around them at every tie-up -- see
## its doc comment for why once per match was not enough.
@export var tie_up_reaction_ticks: int = 10
@export var tie_up_press_interval_ticks: int = 8

## This tie-up's actual reaction delay and press interval, rolled fresh at
## each tie-up by _roll_tie_up_timing(). -1 means "not rolled" and the
## exported baselines are used instead, which is what direct
## WrestlerAI.new() unit tests (test_tie_up_minigame.gd) exercise.
var _this_tie_up_reaction: int = -1
var _this_tie_up_interval: int = -1
## Number of tie-ups this AI has contested this match — seeds the per-tie-up
## roll, the same way _grapple_attempts seeds the whip roll.
var _tie_up_attempts: int = 0

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
		if _tie_up_tick == 0:
			_tie_up_attempts += 1
			_roll_tie_up_timing()
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
		# Strike or tie up, rather than always tying up.
		#
		# Strikes used to be possible only in the shell outside tie_up_range,
		# which a closing wrestler crosses in a couple of ticks -- and once
		# inside it grappled, every time. An instrumented match bore that
		# out exactly: one strike exchange at tick 20 during the opening
		# approach, then 20 grapples and not another punch thrown all match.
		# Strikes also could not land from out there any more once
		# STRIKE_HIT_RANGE was measured down to the distance a fist actually
		# reaches -- which is why that shell no longer throws one at all,
		# and this is now the only branch that strikes.
		# Only when it can actually connect. tie_up_range (1.3m) reaches
		# further than a fist does (WrestlerController.STRIKE_HIT_RANGE,
		# 1.15m, measured off the jab's own contact frame), so a strike
		# thrown at the edge of tie-up range would swing through air.
		if _cooldown <= 0 and distance <= WrestlerController.STRIKE_HIT_RANGE \
				and _should_strike_in_close():
			input["strike"] = true
			_cooldown = strike_cooldown_ticks
		else:
			input["grapple"] = true
	else:
		# Outside tie-up range: close, and *only* close.
		#
		# This branch used to also throw a strike anywhere inside
		# strike_range (1.6m). That strike could never connect: a fist
		# reaches STRIKE_HIT_RANGE (1.15m, measured off the jab's own
		# contact frame -- see gauntlet/refs/timings.md), which is nearer
		# than tie_up_range (1.3m), so everything this branch ever sees is
		# already out of reach. The close-range branch above had been
		# gated on the measured reach; this one was still gated on
		# strike_range, and the two disagreed about the same fact.
		#
		# The cost was not a wasted press. Entering STRIKE zeroes velocity
		# (WrestlerController._start_move()) and the STRIKE branch of
		# _physics_process never processes movement, so every whiff also
		# *stopped the approach* for the move's whole duration -- 31 ticks
		# for strike_jab, 35 for strike_kick, roughly half a second of not
		# closing, up to once per strike_cooldown_ticks. The AI was
		# interrupting its own walk to punch air. The reachability probe
		# measured 7 of 31 strikes (23%) thrown from outside hit range
		# across seeds 1-3 before this change.
		#
		# So there is no "strike while approaching" any more, and there is
		# no range at which one would be legal: strikes belong to the close
		# branch, which is the only place the opponent is reachable. Note
		# this is a reachability fix, not a spacing mechanic -- the AI
		# still has no neutral or circling game (see the locomotion slice
		# in gauntlet/status/slices.json).
		var dir := to_target.normalized()
		input["move"] = Vector2(dir.x, dir.z)

	return input

## Whether this close-range decision is a strike rather than a tie-up.
##
## Seeded, like every other AI decision that affects the match: the same
## (match_seed, player_index, attempt count) must always choose the same
## way or replays stop reproducing. Deliberately uses different multipliers
## from _should_whip() so the two decisions don't move in lockstep.
func _should_strike_in_close() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = _match_seed * 6151 + _player_index * 71 + _close_decisions
	_close_decisions += 1
	return rng.randf() < close_strike_chance

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
	var reaction := _this_tie_up_reaction if _this_tie_up_reaction >= 0 else tie_up_reaction_ticks
	var interval := _this_tie_up_interval if _this_tie_up_interval >= 0 else tie_up_press_interval_ticks
	if tick <= reaction:
		return false
	if tick - _last_tie_up_press_tick < interval:
		return false
	_last_tie_up_press_tick = tick
	return true

## Rolls this tie-up's mash rate, once, as it begins.
##
## setup_jitter() alone was not enough. It shifts the two mash tunables once
## per match from (match_seed, player_index), and _should_press_tie_up()
## then presses on a fixed cadence forever -- so whoever drew the shorter
## interval wins *every* tie-up in that match, by an identical margin. The
## reachability probe measured exactly that: across seeds 1-3, one wrestler
## took every tie-up in all three matches, and every single resolution
## reported the same progress pair -- (6,10) four times, (7,10) three times,
## (10,6) five times. The tie-up was not a contest; it was a coin flipped
## once at setup and then re-read.
##
## That is a different defect from the scene-order bug already fixed in
## WrestlerController._wants_tie_up_this_tick: *entry* is neutral now, both
## wrestlers start mashing on the same tick. It is the *outcome* that was
## constant.
##
## So each tie-up gets its own roll around the jittered baseline,
## deterministic per (match_seed, player_index, _tie_up_attempts) -- the
## same shape as _should_whip()'s per-attempt seeding, and just as replay-
## safe: the same match still replays identically, only the contest varies
## within it.
func _roll_tie_up_timing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _match_seed * 8209 + _player_index * 131 + _tie_up_attempts
	_this_tie_up_reaction = maxi(1,
		tie_up_reaction_ticks + rng.randi_range(-TIE_UP_JITTER_TICKS, TIE_UP_JITTER_TICKS))
	_this_tie_up_interval = maxi(1,
		tie_up_press_interval_ticks + rng.randi_range(-TIE_UP_JITTER_TICKS, TIE_UP_JITTER_TICKS))

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
