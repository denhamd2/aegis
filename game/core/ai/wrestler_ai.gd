class_name WrestlerAI
extends Node
## Minimal grey-box AI: closes distance, ties up once, and then trades
## strikes until somebody stays down. Deterministic — driven off the same
## fixed-tick loop as the player, no bare RNG calls.
##
## The shape of an AI match is deliberate. It opens with a grapple: the
## first time these two are close enough, they lock up, and whoever wins
## the tie-up throws one grapple move. The middle of the match is punches
## and kicks (resources/animations/strike_recipes.gd has four). The end is
## a signature: once the strikes have worn a man down to within one
## signature of a knockdown, the other reaches for a last tie-up, throws
## it, and covers him where he lands. That is the whole match: grapple,
## strikes, signature, pinfall.
##
## It used to be the opposite. Every close-range decision was a seeded coin
## flip between a strike and a tie-up, weighted so the grapple chain -- the
## power/signature/finisher escalation -- carried the match, and measured
## matches bore that out: four tie-ups against 4 to 11 strikes apiece, over
## three seeds. Those escalation moves are gone (see
## resources/animations/paired_recipes.gd), so the grapple chain has
## nowhere to escalate to, and a match made of four identical hip tosses is
## not a better match than one made of strikes.

@export var controller: WrestlerController
@export var target: WrestlerController
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
## roll.
var _tie_up_attempts: int = 0


var _cooldown: int = 0
var _pin_defender_tick: int = 0
var _last_kickout_press_tick: int = -1000
var _tie_up_tick: int = 0
var _last_tie_up_press_tick: int = -1000
## Set by setup_jitter() -- stored so the per-tie-up timing roll can derive
## its own seed the same deterministic way (match_seed, player_index, ...)
## without re-plumbing match_seed through poll_input() on every call.
## Defaults to 0 for direct WrestlerAI.new() construction (unit tests),
## same as every other setup_jitter()-only field.
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
		# Nothing to press either way now. The attacker used to roll here
		# for an Irish whip instead of a grapple move; with one grapple in
		# the whole match, spending it on a whip would mean matches that
		# never show a grapple at all. The whip itself is untouched --
		# WrestlerController._begin_irish_whip() still runs for a player
		# who presses run in a hold.
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
	# Opponent is down: walk in for the cover instead of continuing to
	# strike/grapple decisions below. MatchReferee triggers the pin once
	# this wrestler is within its cover range and idle/moving.
	if target.fsm.current_state == WrestlerFSM.State.DOWN:
		if distance > 0.3:
			var dir := to_target.normalized()
			input["move"] = Vector2(dir.x, dir.z)
		return input

	if distance <= tie_up_range:
		# Grapple, strikes, then a signature to finish him.
		#
		# The first time these two are in range they lock up: nobody has
		# landed a tier yet, so this presses grapple and MatchReferee's
		# tie-up contest decides who throws the move. After that the match
		# is punches and kicks -- until the man across from him is worn
		# down far enough that a signature will put him on the mat, at
		# which point this reaches for one more tie-up and throws it.
		#
		# Strikes only when they can actually connect. tie_up_range (1.3m)
		# reaches further than a fist does
		# (WrestlerController.STRIKE_HIT_RANGE, 1.15m, measured off the
		# jab's own contact frame), so a strike thrown at the edge of
		# tie-up range would swing through air. A tick inside tie-up range
		# but outside striking range, or one spent on the strike cooldown,
		# is a tick of standing squared up -- which is what the cooldown is
		# for.
		if _wants_tie_up():
			input["grapple"] = true
		elif _cooldown <= 0 and distance <= WrestlerController.STRIKE_HIT_RANGE:
			input["strike"] = true
			_cooldown = strike_cooldown_ticks
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

## Whether to reach for a tie-up this tick rather than throw a strike.
##
## Two reasons to lock up, and no others. Everything else in a match is a
## strike.
##
## 1. The opening grapple has not happened yet.
## 2. The opponent is one signature away from the mat and this wrestler can
##    afford one -- see _opponent_is_ripe(). This is the finish.
##
## There was briefly a third: a wrestler who lost the opening tie-up had
## landed no rung of the chain, and a signature was gated on the rung below
## it, so he locked up again purely to earn one. Measured, that cost 5.5
## tie-ups a match against 8 strikes -- the grapple loop this AI exists to
## avoid -- and the gate it was serving was the wrong gate.
## CombatSystem.can_signature() asks the meter now, and that reason is gone
## with it.
func _wants_tie_up() -> bool:
	if not _opening_grapple_done():
		return true
	return controller.combat.can_signature() and _opponent_is_ripe()

## Whether a signature thrown now would knock the opponent down.
##
## A knockdown is an event measured from the last one
## (WrestlerController._damage_at_last_knockdown), so what matters is the
## damage he has taken *since* he was last put down, not his total. Ripe
## means the weakest signature this wrestler could draw closes the
## remaining gap by itself.
##
## The weakest rather than the likeliest: the move is drawn from the pool
## by a seeded pick at the moment the grapple resolves, and reaching for a
## signature that leaves the man standing spends the tie-up for nothing.
##
## This is what puts the signature at the end of the match instead of the
## middle. Momentum crosses SIGNATURE_THRESHOLD after three or four
## strikes -- long before anybody is hurt enough to pin -- so an AI that
## simply threw a signature as soon as it could afford one would throw it
## in the opening exchange and finish the match with jabs.
func _opponent_is_ripe() -> bool:
	var remaining := WrestlerController.KNOCKDOWN_DAMAGE \
			- (target.combat.total_damage() - target._damage_at_last_knockdown)
	return remaining <= _weakest_signature_damage()

## Total damage of the least damaging signature this wrestler can draw --
## his own plus his pool, exactly the set WrestlerController._pick_tier_move()
## picks from.
func _weakest_signature_damage() -> float:
	var weakest := INF
	for move: MoveDef in ([controller.signature_move] + controller.signature_move_pool):
		if move == null:
			continue
		weakest = minf(weakest, move.damage_head + move.damage_torso
				+ move.damage_arms + move.damage_legs)
	return 0.0 if weakest == INF else weakest

## Whether the opening grapple has already happened -- see the class
## comment.
##
## Read off the combat record rather than off a state the AI watches go by:
## WrestlerController records a tier the moment a grapple *lands*
## (_resolve_grapple_move -> record_tier), which is exactly the event this
## needs, and unlike a GRAPPLE_HOLD sighting it cannot be missed on a tick
## this AI did not run. Either man's grapple ends the opening: they were
## both in the same lock-up, and only one of them could win it.
func _opening_grapple_done() -> bool:
	return controller.combat.tier_reached >= 0 or target.combat.tier_reached >= 0

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
## same shape as the strike/whip rolls this file used to carry, and just as replay-
## safe: the same match still replays identically, only the contest varies
## within it.
func _roll_tie_up_timing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _match_seed * 8209 + _player_index * 131 + _tie_up_attempts
	_this_tie_up_reaction = maxi(1,
		tie_up_reaction_ticks + rng.randi_range(-TIE_UP_JITTER_TICKS, TIE_UP_JITTER_TICKS))
	_this_tie_up_interval = maxi(1,
		tie_up_press_interval_ticks + rng.randi_range(-TIE_UP_JITTER_TICKS, TIE_UP_JITTER_TICKS))


