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
## 40 -> 70 (match flow to 2K26, gauntlet/refs/match_engine_2k26.md): a move
## landed every 1.1 s against 2K26's 4-6 s. The longer downs carry most of
## that; this spaces the standing exchange so a blow is sold before the next.
@export var strike_cooldown_ticks: int = 70
## strike_cooldown_ticks during a comeback (CombatSystem.is_fired_up()).
@export var comeback_strike_cooldown_ticks: int = 12
## Between strikes on a man trapped in a corner (Phase 4, position): he is
## worked over while he hangs there, not sized up.
@export var corner_strike_cooldown_ticks: int = 18
## Chance, each time he would strike a man hanging in a corner, that he runs
## in with his corner move instead (when he has one).
const CORNER_MOVE_CHANCE := 0.35
## How far away the AI stops walking in and charges instead.
##
## A STARTING VALUE, not a searched minimum. Its justification is the ring's
## geometry rather than tuning: ArenaBuilder.RING_HALF_EXTENT is 3.3m, the two
## spawn 3.0m apart (scenes/match.tscn), and tie_up_range is 1.3m -- so 2.5m
## leaves roughly 1.35m of actual sprint at WrestlerController.RUN_SPEED (7.0).
## That is a short run-up, and it is the most the ring offers: a real charge
## across the ring needs the AI to make distance first, which is the separate
## "there is still no neutral" item in gauntlet/status/roman_reigns_next.md.
## How close the AI is willing to stand. Nearer than this and it gives ground
## instead of crowding.
##
## Measured with tools/probe/contact_probe.tscn: without this the two men
## spent essentially the whole match at 0.801 m centre-to-centre, against a
## capsule-touching distance of 0.80 m -- jammed against the floor the physics
## engine enforces, for 1455 of 1458 free ticks. The capsules never overlap
## (they cannot), but the capsule is radius 0.4 and models nothing above the
## waist, so two men at 0.80 m have their arms and shoulders fully inside each
## other. On footage they read as one body, and a punch thrown at that range
## goes PAST the opponent rather than into him.
##
## 1.05 m sits inside the shortest strike's reach on purpose: back off any
## further and the AI could no longer connect with the strike it just stepped
## away from.
## Circling: how far apart to hold while waiting, and how long a wrestler keeps
## going the same way round before he switches.
##
## 1.10 m is the middle of the only band that works: nearer than min_standoff
## (1.05 m) and they are inside each other, further than the SHORTEST strike in
## the pool and the next strike cannot reach. The upper edge used to be quoted
## as STRIKE_HIT_RANGE (1.15 m), which was every strike's reach while there was
## only one number; reach is now per-move and read through
## WrestlerController.shortest_strike_reach() -- 1.17 m, the jab, with the
## cross at 1.20 and both kicks past 1.35.
##
## That distinction is load-bearing, and it was briefly wrong. When the contact
## volumes first landed the cross reached only 1.07 m, so the AI held 1.10 and
## every cross it drew missed by three centimetres. The fix was to extend the
## clip (Strike_Forearm's contact pose in tools/blender/wrestling_clips.py),
## not to pull the standoff in: a rear-hand cross should out-reach a jab.
## test_ai_spacing.gd is what keeps the band and the measured reaches agreeing.
@export var circle_distance: float = 1.10
## How hard the radial correction pulls back to circle_distance against the
## lateral motion. 1.0 would walk straight at him; 0 would spiral away.
@export var circle_radial_pull: float = 0.55
## Ticks before the direction is re-rolled, so two men do not orbit in
## lockstep for a whole match.
@export var circle_bout_ticks: int = 90
@export var min_standoff: float = 1.05
@export var run_engage_distance: float = 2.5
## Ticks after a running attack before another charge may start. A running
## attack is 69 ticks committed (18 startup + 5 active + 46 recovery) against a
## strike's 31, so without this it would crowd out the strike trading the
## match is made of.
@export var running_attack_cooldown_ticks: int = 90
## How long after a charge before this AI will back off to make room for
## another. Backing off on every getup put 4.5 running attacks in a match and
## cut its strikes from 15 to 6 -- the middle of a match is strikes
## (MATCH_FLOW.md), and a running attack is the punctuation. 12 s.
@export var make_room_cooldown_ticks: int = 720
var _make_room_cooldown: int = 0
## The knockdown routine, varied. Backing off while the other man rises and
## charging him as he straightens was what every knockdown led to, and a
## routine is the first thing a viewer reads as AI. Each rise is rolled once:
## a charge CHARGE_CHANCE of the time, never two rises running; otherwise he
## walks in and goes back to work.
const CHARGE_CHANCE := 0.45
var _rise_rolled := false
var _charge_this_rise := false
var _charged_last_rise := false
## The heel in control plays to the crowd now and then (MatchFlow.wants_stall):
## a taunt between holds, no oftener than this many ticks.
const STALL_EVERY_TICKS := 1500
var _stall_cooldown: int = 600
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
## Whether this AI has already locked up once to throw its power move. One
## try a match, won or lost: a man who loses that tie-up does not get to
## chase it with another, or the middle of the match turns back into the
## grapple loop this AI was rewritten to get away from.
var _power_attempt_spent: bool = false

## The working lock-up (2K26's match is grapple-led: a collar-and-elbow, a
## hold, a suplex, then the strikes again -- gauntlet/refs/match_engine_2k26.md).
## The AI used to lock up only to open the match, once for its power move and
## for the finish, so a nine-minute match showed about four grapples and was
## otherwise punches. Now, every WORK_TIE_UP_MIN-MAX blows (a string of three
## is one beat), it reaches for a lock-up to work a grapple or a power move --
## capped there (WrestlerController.tie_up_rung_cap), so a meter that could
## afford a signature does not throw one in the middle of the match.
const WORK_POWER_SHARE := 0.5
const WORK_TIE_UP_MIN := 5
const WORK_TIE_UP_MAX := 9
var _blows_since_lock_up := 0
var _work_tie_up_after := 7


var _cooldown: int = 0
## Latched while closing at a run, from the moment the charge starts until the
## running attack fires (or the charge is abandoned).
##
## A latch rather than a plain `distance >= run_engage_distance` test, and that
## is the whole mechanism. Tested per tick, the AI drops back to a walk the
## instant it crosses the threshold -- which leaves RUN, and
## WrestlerController._maybe_start_running_attack() is only called while IN
## RUN (_process_free_movement). It would stop running at exactly the distance
## where the attack becomes possible, so the attack could never fire at all.
var _charging: bool = false
var _run_cooldown: int = 0
## Ticks this AI has been alive, used only to number the circling bouts so the
## direction roll has something to vary on. Advances once per physics tick, so
## a replay re-rolls identically.
var _circle_tick: int = 0
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
	if _run_cooldown > 0:
		_run_cooldown -= 1
	if _make_room_cooldown > 0:
		_make_room_cooldown -= 1
	if _signature_retry > 0:
		_signature_retry -= 1
	if _stall_cooldown > 0:
		_stall_cooldown -= 1
	if _weapon_roll > 0:
		_weapon_roll -= 1
	_circle_tick += 1
	# A charge only survives while the man is actually free to run. If he is
	# struck out of it, poll_input() returns early for the whole of HIT_REACT
	# and the latch would otherwise still be set when he recovers -- resuming
	# the charge from close range, with no run-up, as a running attack out of
	# nowhere.
	if not controller.fsm.is_in([WrestlerFSM.State.IDLE,
			WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN]):
		_charging = false

## Reversals (Phase 4): once per strike thrown at him, at a moment inside
## its window, he reads it or he does not. The chance is his stamina's: fresh,
## REVERSAL_CHANCE; spent, a third of it -- the 2K26 rule that a worn-down man
## stops countering. Seeded per attempt, so a replay reads the same strikes.
const REVERSAL_CHANCE := 0.45
## What is left of it spent: a third. Squaring stamina left a tired man no
## reversals at all, which made the long exchanges one-sided.
const REVERSAL_SPENT_SHARE := 0.35
var _reversal_rolls := 0
var _reversal_roll_frame := -1
var _reversal_decided := false
var _reversal_intent := false


## Chain wrestling. How many links the opening lock-up runs to -- one to
## three, seeded -- and nothing out of any later one: the power and signature
## lock-ups are the business end of a match, and the chain is its opening.
const CHAIN_LINK_WEIGHTS := [2, 2, 1]
## The read tick the holder picks on, and the one the held man reads it on
## (inside WrestlerController.CHAIN_REVERSAL_WINDOW).
const CHAIN_PICK_TICK := 6
const CHAIN_READ_TICK := 8
## Chance the man in a hold reverses the next one, at full stamina; it falls
## with his stamina like a strike reversal's does.
const CHAIN_REVERSAL_CHANCE := 0.3
## How often a hold the AI has the better of ends in an Irish whip.
const WHIP_CHANCE := 0.18
var _chain_plan := -1
var _chain_rolls := 0


func _chain_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _match_seed * 4099 + _player_index * 131 + _chain_rolls
	_chain_rolls += 1
	return rng


func _chain_input() -> Dictionary:
	var c := controller
	if not c._is_grapple_attacker:
		# In it: read the hold coming, and maybe take it over.
		if c.opponent and c.opponent._chain_enabled and c.opponent.chain_hold == "" \
				and c.opponent._chain_read == CHAIN_READ_TICK:
			var stamina: float = c.combat.stamina
			var go := _chain_rng().randf() < CHAIN_REVERSAL_CHANCE \
					* (REVERSAL_SPENT_SHARE + (1.0 - REVERSAL_SPENT_SHARE) * stamina)
			return {"reversal": go}
		return {}
	if not c._chain_enabled:
		return {}
	if c._chain_pick != "":
		return {} # a reversal already chose it; let the read run out
	if _chain_plan < 0:
		_chain_plan = 0
		# Now and then, with a man in his hands after the opening, he sends him
		# into the ropes instead (the Irish whip) -- and is waiting when he
		# comes off them. Seeded, like every other roll.
		if _opening_grapple_done() and _chain_rng().randf() < WHIP_CHANCE:
			return {"run": true}
		if not _opening_grapple_done():
			var roll := _chain_rng().randi_range(1, 5)
			_chain_plan = 1 if roll <= CHAIN_LINK_WEIGHTS[0] else (
					2 if roll <= CHAIN_LINK_WEIGHTS[0] + CHAIN_LINK_WEIGHTS[1] else 3)
	if c._chain_links >= _chain_plan:
		return {"chain": "none"}
	if c._chain_read != CHAIN_PICK_TICK:
		return {} # picked once; the controller holds on to it
	var holds := WrestlerController.CHAIN_HOLDS.keys()
	return {"chain": holds[_chain_rng().randi_range(0, holds.size() - 1)]}


func _roll_reversal() -> bool:
	if target.fsm.current_state != WrestlerFSM.State.STRIKE or target._active_move == null \
			or target._active_move == WrestlerController.REVERSAL_MOVE:
		_reversal_decided = false
		_reversal_intent = false
		return false
	var move: MoveDef = target._active_move
	if not _reversal_decided:
		# Decided once, as the swing starts: hold and read it, or not. Holding
		# is what makes a read possible at all -- measured before this, 68 of
		# 75 strikes were thrown into a man already swinging back, with nothing
		# free to parry them (tools/probe/reversal_tally.tscn).
		_reversal_decided = true
		var rng := RandomNumberGenerator.new()
		rng.seed = _match_seed * 7331 + _player_index * 97 + _reversal_rolls
		_reversal_rolls += 1
		var stamina: float = controller.combat.stamina
		_reversal_intent = rng.randf() < REVERSAL_CHANCE \
				* (REVERSAL_SPENT_SHARE + (1.0 - REVERSAL_SPENT_SHARE) * stamina) \
				* (controller.flow.reverse_scale(controller) if controller.flow else 1.0)
		# A reaction time inside the window, not its first frame.
		_reversal_roll_frame = move.reversal_window_start - WrestlerController.REVERSAL_LEAD \
				+ rng.randi_range(0, WrestlerController.REVERSAL_LEAD)
	return _reversal_intent and target.strike_frame() == _reversal_roll_frame


## True while he is holding to read the strike coming at him: he does not
## throw into it.
func is_reading() -> bool:
	return _reversal_intent


func poll_input() -> Dictionary:
	var input := _poll_input()
	# Pacing: a worn man walks slower. Not a run -- a charge is a charge.
	if controller and input.has("move") and not input.get("run", false):
		input["move"] = (input["move"] as Vector2) * fatigue_walk_scale(
				controller.combat.total_damage())
	return input


## In-between behaviour (Phase 4): how much slower a man walks, and how much
## longer he waits between strikes, worn down by `damage` -- BodyLife's
## "spent" scale, so he moves as tired as he looks.
const FATIGUE_WALK_MIN := 0.7
## How much longer a man waits between strikes than strike_cooldown_ticks says
## (comeback and corner flurries aside). The measured match was landing a move
## every 0.7 s against 2K26's 4-6 s between beats (gauntlet/refs/
## match_engine_2k26.md section 3); a string of three blows is one beat.
## 2.2 -> 3.2 with the working lock-ups in: beat gap 2.5-2.8 s at 2.2,
## 3.1-3.6 s at 2.8 (flow_probe seeds 1-4). 3.2 -> 4.0 for the middle of
## 2K26's range: 3.7-4.0 s at 3.2, 4.0-4.4 at 3.6, 4.4-4.8 at 4.0, matches
## 7.7-9.6 min, every win a pinfall off the winner's finisher.
const ACTION_GAP_SCALE := 4.0
const FATIGUE_COOLDOWN_MAX := 1.5

static func fatigue_of(damage: float) -> float:
	return clampf(damage / BodyLife.DAMAGE_FULL, 0.0, 1.0)

static func fatigue_walk_scale(damage: float) -> float:
	return lerpf(1.0, FATIGUE_WALK_MIN, fatigue_of(damage))

static func fatigue_cooldown_scale(damage: float) -> float:
	return lerpf(1.0, FATIGUE_COOLDOWN_MAX, fatigue_of(damage))


## Playing to the crowd (WrestlerController.begin_taunt): over a man just put
## down, once to set up the finisher -- it is ready and he wants them to know
## it -- and once after his power move lands. Decided in the first
## TAUNT_WINDOW ticks he is down, or not at all for that knockdown.
const TAUNT_WINDOW := 12
var _setup_taunted := false
var _power_taunted := false


func _wants_taunt() -> bool:
	if not controller.can_taunt() or target.fsm.current_state != WrestlerFSM.State.DOWN \
			or target.fsm.ticks_in_state > TAUNT_WINDOW:
		return false
	if controller.combat.can_finisher() and controller.finisher_move and not _setup_taunted:
		_setup_taunted = true
		return true
	if controller.last_landed_tier == CombatSystem.Tier.POWER and not _power_taunted:
		_power_taunted = true
		return true
	return false


## The strut (owner's 2K26 Cody vs Roman, gauntlet/refs/cody_roman_2k26.md):
## the man who has just put the other down does not always walk straight in
## for the cover. He walks off a couple of metres, turns to the crowd and
## plays to them -- the heel in control most of all -- then goes back to work.
## Rolled once per knockdown, deterministic off the match seed.
## Raised with the longer downs (WrestlerController.DOWN_TICKS_*): there is
## time to play to the crowd, and 2K26's man in control does (0.55 / 0.2).
const STRUT_CHANCE_HEEL := 0.8
const STRUT_CHANCE := 0.5
const STRUT_DISTANCE := 2.0
## Inside the ropes with room to spare.
const STRUT_LIMIT := 2.3
## How long he stands and soaks it in if he cannot taunt.
const STRUT_HOLD_TICKS := 45
var _strut_point := Vector3.INF
var _strut_hold := 0
## Re-armed whenever the other man is up, so each knockdown gets one roll.
var _strut_armed := true


func _strut_input(input: Dictionary) -> Dictionary:
	# One roll per knockdown.
	if _strut_armed:
		_strut_armed = false
		var heel := controller.flow != null and controller.flow.wants_stall(controller)
		_strut_point = Vector3.INF
		if _opening_grapple_done() and _chain_rng().randf() < (STRUT_CHANCE_HEEL if heel else STRUT_CHANCE):
			var away := controller.global_position - target.global_position
			away.y = 0.0
			if away.length() < 0.1:
				away = Vector3(-controller.global_position.x, 0.0, -controller.global_position.z)
			var p := controller.global_position + away.normalized() * STRUT_DISTANCE
			p.x = clampf(p.x, -STRUT_LIMIT, STRUT_LIMIT)
			p.z = clampf(p.z, -STRUT_LIMIT, STRUT_LIMIT)
			_strut_point = Vector3(p.x, controller.global_position.y, p.z)
			_strut_hold = STRUT_HOLD_TICKS
	if _strut_point == Vector3.INF:
		return {}
	var to := _strut_point - controller.global_position
	to.y = 0.0
	if to.length() > 0.2:
		var dir := to.normalized()
		input["move"] = Vector2(dir.x, dir.z)
		return input
	# There: to the crowd, then back to work.
	if controller.can_taunt():
		input["taunt"] = true
		_strut_point = Vector3.INF
		return input
	_strut_hold -= 1
	if _strut_hold <= 0:
		_strut_point = Vector3.INF
	return input


func _poll_input() -> Dictionary:
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
			_blows_since_lock_up = 0
			_work_tie_up_after = _chain_rng().randi_range(WORK_TIE_UP_MIN, WORK_TIE_UP_MAX)
			if _wants_power_tie_up():
				_power_attempt_spent = true
		_tie_up_tick += 1
		return {"grapple": _should_press_tie_up(_tie_up_tick)}
	_tie_up_tick = 0
	_last_tie_up_press_tick = -1000
	if controller.fsm.current_state == WrestlerFSM.State.GRAPPLE_HOLD:
		# No whip: the attacker used to roll here for an Irish whip instead
		# of a grapple move; with one grapple in the whole match, spending it
		# on a whip would mean matches that never show a grapple at all. The
		# whip itself is untouched -- WrestlerController._begin_irish_whip()
		# still runs for a player who presses run in a hold.
		#
		# Chain wrestling instead (WrestlerController, "chain wrestling"):
		# the holder picks holds, the man in them may reverse.
		return _chain_input()
	_chain_plan = -1
	if controller.is_rummaging():
		return _rummage_input()
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
	input["reversal"] = _roll_reversal()
	# No Holds Barred: out for a weapon, or using the one in his hands.
	var armed := _weapon_input(input, to_target, distance)
	if not armed.is_empty():
		return armed
	# No Holds Barred: he went through the ropes, so go after him.
	if controller.outside_ring != target.outside_ring and not target.is_crossing_ropes() \
			and controller.can_cross_ropes():
		input["move"] = _follow_through_ropes()
		input["rope_cross"] = true
		return input
	# Opponent is down: walk in for the cover instead of continuing to
	# strike/grapple decisions below. MatchReferee triggers the pin once
	# this wrestler is within its cover range and idle/moving.
	#
	# To the side of his CHEST, not to his pelvis. Walking straight at his
	# root from wherever this wrestler stood -- usually his feet end -- walked
	# the standing man through the downed man's raised legs, which is the
	# clipping the owner flagged off the match video. The spot is on the side
	# he is already on, so the walk in never crosses the body; the footprint
	# guard in WrestlerController slides him round the legs if the straight
	# line would clip them.
	if target.fsm.current_state != WrestlerFSM.State.DOWN:
		_strut_armed = true
		_strut_point = Vector3.INF
	if target.fsm.current_state == WrestlerFSM.State.DOWN:
		if _wants_taunt():
			input["taunt"] = true
			return input
		var strut := _strut_input(input)
		if not strut.is_empty():
			return strut
		var spot := WrestlerController.cover_approach_spot(target,
				controller.global_position)
		var to_spot := spot - controller.global_position
		to_spot.y = 0.0
		if to_spot.length() > 0.12:
			var dir := to_spot.normalized()
			input["move"] = Vector2(dir.x, dir.z)
		return input

	# Making room for a charge. Once the opening lock-up is done the two never
	# stand run_engage_distance apart on their own -- measured over twelve
	# seeds, every charge in a match was the one at the opening bell -- so the
	# running attacks were unreachable. While the other man is getting up, the
	# AI backs off to charge distance; the charge below then fires when he is
	# on his feet. He does not back off from a man he is about to finish.
	if target.fsm.current_state == WrestlerFSM.State.GETUP and not _rise_rolled:
		_rise_rolled = true
		_charge_this_rise = not _charged_last_rise and _chain_rng().randf() < CHARGE_CHANCE
		_charged_last_rise = _charge_this_rise
	elif target.fsm.current_state != WrestlerFSM.State.GETUP:
		_rise_rolled = false
	if target.fsm.current_state == WrestlerFSM.State.GETUP and _charge_this_rise \
			and _opening_grapple_done() and _run_cooldown <= 0 \
			and _make_room_cooldown <= 0 and not _wants_tie_up() and distance < run_engage_distance + 0.3:
		var away := -to_target.normalized()
		input["move"] = Vector2(away.x, away.z)
		return input

	# --- the charge ---------------------------------------------------------
	#
	# This is the whole of "the AI runs in open play", and it deliberately sits
	# BELOW the GRAPPLE_HOLD branch above, which returns {} before the input
	# dict is ever built.
	#
	# That ordering is load-bearing, not incidental: input["run"] means "throw
	# an Irish whip" to WrestlerController._process_grapple_hold(), and "sprint"
	# to _process_free_movement(). The same key, two unrelated meanings, chosen
	# by state. Setting run anywhere that GRAPPLE_HOLD could see it would turn
	# every charge into a whip. Do not hoist this above that branch.
	#
	# Running is not a separate behaviour from closing -- it IS closing, done
	# faster when there is room for it. The attack at the end is the point:
	# RUNNING_ATTACK has two MoveDefs, a reversal window and its own test suite,
	# and before this it fired zero times in a match (measured, ladder_probe
	# seeds 1-3: "running 0" for both men, with RUN absent from every entries
	# dict).
	if _charging and WrestlerController.UNHITTABLE_STATES.has(target.fsm.current_state):
		# He went down, or into a pin, mid-run. Nothing to charge at, and
		# _maybe_start_running_attack() would refuse anyway -- so stop running
		# rather than sprint into him and hold the latch forever.
		_charging = false
	elif not _charging and distance >= run_engage_distance and _run_cooldown <= 0 \
			and _opening_grapple_done():
		# Not before the opening lock-up. The wrestlers spawn 3.0 m apart --
		# past run_engage_distance -- so an AI free to charge from the first
		# tick opened every match with a running attack, and once running
		# attacks became paired moves (1.2-2.0 s, the victim left on the mat)
		# the lock-up MATCH_FLOW.md opens the match with never happened in
		# test_match_loop_reachability's 600 frames. He walks in to lock up;
		# the charges come after.
		_charging = true

	if _charging:
		var dir := to_target.normalized()
		# Both are required to stay in RUN: _process_free_movement() only
		# transitions there when run is pressed AND there is movement to make.
		input["move"] = Vector2(dir.x, dir.z)
		input["run"] = true
		if distance <= WrestlerController.STRIKE_HIT_RANGE:
			# In RUN this press becomes _maybe_start_running_attack(), not a
			# strike -- _process_free_movement() branches on the state before
			# it looks at the input. The cooldown is spent here, on arrival,
			# whether or not the attack's own gate lets it through.
			input["strike"] = true
			_charging = false
			_run_cooldown = running_attack_cooldown_ticks
			_make_room_cooldown = make_room_cooldown_ticks
		return input

	# Too close: give ground -- but keep deciding. This sets the move vector
	# and then FALLS THROUGH to the strike/tie-up logic below, rather than
	# returning, for two reasons. A man can throw a punch while stepping off,
	# and a lock-up is the one moment two wrestlers are supposed to be chest
	# to chest: an early version returned here and the AI refused to tie up at
	# 1.0 m, which broke the opening grapple the whole match is built on.
	#
	# It is not a spacing game. There is still no circling and no neutral (see
	# gauntlet/status/roman_reigns_next.md); this only stops the two standing
	# inside each other, which they otherwise do for essentially every tick of
	# the match.
	if distance < min_standoff and distance > 0.001:
		var back := (controller.global_position - target.global_position)
		back.y = 0.0
		if back.length() > 0.001:
			back = back.normalized()
			input["move"] = Vector2(back.x, back.z)

	# The heel with the match in hand takes his time: a taunt, a look at the
	# crowd, before he goes back to work.
	if _stall_cooldown <= 0 and controller.flow and controller.flow.wants_stall(controller) \
			and distance <= tie_up_range * 1.5 and controller.can_taunt() \
			and target.fsm.current_state != WrestlerFSM.State.DOWN:
		_stall_cooldown = STALL_EVERY_TICKS
		input["taunt"] = true
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
		# The reach gate is the SHORTEST strike in this wrestler's pool, not
		# STRIKE_HIT_RANGE. That constant used to be every strike's reach;
		# since each move carries its own measured contact volume it is only
		# the "close enough to throw at" gate, and the four strikes reach
		# 1.17 / 1.20 / 1.37 / 1.35 m. Gating on the old 1.15 meant throwing
		# from distances the drawn strike could not cover.
		var reach := controller.shortest_strike_reach()
		# A man trapped in the corner cannot be locked up with -- he is not
		# standing to meet it -- so he is struck instead, in a flurry.
		var cornered := target.is_corner_trapped()
		var wants_tie_up := _wants_tie_up()
		if wants_tie_up and cornered:
			# Ready to finish him, and he is hanging in the corner: wait for
			# him to come out and lock up then. Working him over instead kept
			# a man ready for his finisher striking forever -- blows past his
			# limbs' damage cap knock nobody down (reversal_tally seed 1 ran
			# its whole budget).
			pass
		elif wants_tie_up:
			input["grapple"] = true
			# A working lock-up stays a grapple, whoever wins it.
			var cap := -1
			if _is_work_tie_up():
				# Half of them a grapple (the suplex, the knee, the guillotine),
				# half the power move if the meter has earned one.
				cap = CombatSystem.Tier.POWER if _chain_rng().randf() < WORK_POWER_SHARE \
						else CombatSystem.Tier.GRAPPLE
			controller.tie_up_rung_cap = cap
			if target.is_ai:
				target.tie_up_rung_cap = cap
		elif _cooldown <= 0 and distance <= reach and not is_reading():
			# Hanging in the corner, with a corner move to hand: sometimes
			# the flurry gives way to the run-in instead of another blow.
			if cornered and controller.corner_move != null \
					and _chain_rng().randf() < CORNER_MOVE_CHANCE \
					and controller.try_corner_spear():
				return input
			input["strike"] = true
			_blows_since_lock_up += 1
			# Fired up, he does not wait between shots: the comeback is a
			# flurry, and the other man is staggered for most of it.
			_cooldown = comeback_strike_cooldown_ticks \
					if controller.combat.is_fired_up() else int(strike_cooldown_ticks
					* ACTION_GAP_SCALE
					* fatigue_cooldown_scale(controller.combat.total_damage())
					* (controller.flow.tempo_scale(controller) if controller.flow else 1.0))
			if cornered:
				_cooldown = mini(_cooldown, corner_strike_cooldown_ticks)
		elif cornered:
			# Stay square in front of him between shots rather than circle off.
			var toward := to_target.normalized()
			if distance > reach * 0.9:
				input["move"] = Vector2(toward.x, toward.z)
		elif distance > reach:
			# The dead band, and it has to be closed explicitly. tie_up_range
			# is 1.3 m and the shortest strike reaches 1.17 m, so between those
			# AI used to neither close (the closing branch below only fires
			# OUTSIDE tie-up range) nor strike (out of reach) -- it just stood
			# there. This file already admitted as much: "a tick inside tie-up
			# range but outside striking range ... is a tick of standing
			# squared up".
			#
			# That was survivable only because the two men were jammed
			# together at 0.801 m for the whole match and never sat in the
			# band. With min_standoff holding them apart and a landed hit now
			# shoving the victim ~0.1 m back, they land in it constantly --
			# and measured, the match STOPPED FINISHING: all three seeds ran
			# the full 20000-tick budget with 4 hit reactions between them,
			# against 13 in ~1700 ticks before. So: step back in.
			var toward := to_target.normalized()
			input["move"] = Vector2(toward.x, toward.z)
		else:
			# In range with nothing to throw: the strike is on cooldown and he
			# is not reaching for a tie-up. This branch used to issue no input
			# at all -- no move, no press -- so a strike was followed by
			# strike_cooldown_ticks (40, two thirds of a second) of a man
			# standing perfectly still opposite another man standing perfectly
			# still. This file said so itself: "a tick spent on the strike
			# cooldown is a tick of standing squared up".
			input["move"] = _circle_move(to_target, distance)
	else:
		# Outside tie-up range: close, and *only* close.
		#
		# This branch used to also throw a strike anywhere inside
		# strike_range (1.6m). That strike could never connect: the
		# shortest strike reaches 1.17 m (measured per move by
		# tools/anim/measure_contact_offsets.gd), which is nearer than
		# tie_up_range (1.3m), so everything this branch ever sees is
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
## 3. Once a match, in the middle of it, to throw the power move -- see
##    _wants_power_tie_up().
##
## There was briefly a third: a wrestler who lost the opening tie-up had
## landed no rung of the chain, and a signature was gated on the rung below
## it, so he locked up again purely to earn one. Measured, that cost 5.5
## tie-ups a match against 8 strikes -- the grapple loop this AI exists to
## avoid -- and the gate it was serving was the wrong gate.
## CombatSystem.can_signature() asks the meter now, and that reason is gone
## with it.
## Where along the ropes he follows the other man through: inside
## WrestlerController.ROPE_CROSS_LANE, clear of the turnbuckles.
const FOLLOW_LANE := 1.6


## The walk to the ropes on the side the other man is on, then into them
## until WrestlerController takes him through (ROPE_PUSH_TICKS). Outside and
## on a different side of the ring, round the corner first -- straight
## across would be through the ring deck.
func _follow_through_ropes() -> Vector2:
	return _through_ropes_toward(target.global_position)


## The walk to the ropes on the side of `him` (a point), then into them --
## out to the floor, or back in.
func _through_ropes_toward(him: Vector3) -> Vector2:
	var me := controller.global_position
	var axis := Vector3(signf(him.x), 0.0, 0.0) if absf(him.x) >= absf(him.z) \
			else Vector3(0.0, 0.0, signf(him.z))
	if axis == Vector3.ZERO:
		axis = Vector3.RIGHT
	var lat := Vector3(absf(axis.z), 0.0, absf(axis.x))
	var lane := clampf(him.dot(lat), -FOLLOW_LANE, FOLLOW_LANE)
	var goal: Vector3
	if controller.outside_ring:
		goal = axis * (WrestlerController.DECK_KEEP_OUT + 0.05) + lat * lane
		var mine := Vector3(signf(me.x), 0.0, 0.0) if absf(me.x) >= absf(me.z) \
				else Vector3(0.0, 0.0, signf(me.z))
		if mine.dot(axis) < 0.5:
			# Round the corner on his side nearest me -- and from the far
			# side, round the corner on mine first.
			var round_by := WrestlerController.DECK_KEEP_OUT + 0.6
			var side := signf(me.dot(lat))
			if side == 0.0:
				side = 1.0
			goal = (axis + lat * side) * round_by
			var behind := (-axis + lat * side) * round_by
			if mine.dot(axis) < -0.5 and Vector2(me.x - behind.x, me.z - behind.z).length() > 0.5:
				goal = behind
			elif Vector2(me.x - goal.x, me.z - goal.z).length() < 0.5:
				goal = axis * (WrestlerController.DECK_KEEP_OUT + 0.05) + lat * lane
	else:
		goal = axis * (WrestlerController.RING_KEEP_IN - 0.1) + lat * lane
	var to_goal := goal - me
	to_goal.y = 0.0
	var at_ropes := goal.is_equal_approx(axis * (WrestlerController.DECK_KEEP_OUT + 0.05) + lat * lane) \
			if controller.outside_ring else true
	if to_goal.length() < 0.15 and at_ropes:
		# There: lean into the ropes (in) or the apron (out).
		var push := -axis if controller.outside_ring else axis
		return Vector2(push.x, push.z)
	var dir := to_goal.normalized()
	return Vector2(dir.x, dir.z)


func _wants_tie_up() -> bool:
	if not _opening_grapple_done():
		return true
	if _wants_power_tie_up():
		return true
	if _wants_signature_tie_up():
		return true
	return _wants_work_tie_up()


## The finish: a signature to put him down. Not again for SIGNATURE_RETRY_TICKS
## after one lands -- a man does not throw his big move at the same man over
## and over (2K26: one to three a match). Measured at a 30 s wait after only
## the ones that left him standing: thirteen in a nine-minute match, seed 3.
const SIGNATURE_RETRY_TICKS := 2700
var _signature_retry := 0


func _wants_signature_tie_up() -> bool:
	if not _opponent_is_ripe():
		return false
	# The finisher is never held back: it is how the match ends.
	if controller.combat.can_finisher() and controller.finisher_move:
		return true
	return _signature_retry <= 0 and controller.combat.can_signature()


## Called by the controller when one of this man's signatures lands.
func signature_landed(_knocked_down: bool) -> void:
	_signature_retry = SIGNATURE_RETRY_TICKS


## Time for a working lock-up: enough blows since the last one, a grapple-tier
## move to work, and nothing better to do -- not mid-comeback (that is a flurry
## of strikes), and not at a man hanging in the corner (he cannot lock up).
func _wants_work_tie_up() -> bool:
	if not _opening_grapple_done() or _blows_since_lock_up < _work_tie_up_after:
		return false
	# A man with his finisher in hand does not lock up to work a hold.
	if controller.combat.can_finisher() and controller.finisher_move:
		return false
	if controller.grapple_move == null and controller.grapple_move_pool.is_empty():
		return false
	return not controller.combat.is_fired_up() and not target.is_corner_trapped()


## Whether the lock-up this AI wants is the working kind rather than the power
## move's or the finish's.
func _is_work_tie_up() -> bool:
	return not _wants_power_tie_up() and not _wants_signature_tie_up() \
			and _wants_work_tie_up()

## The middle of the match: one lock-up to throw the power move, the body
## slam, and back to strikes.
##
## Only inside the power band -- momentum past POWER_THRESHOLD and short of
## SIGNATURE_THRESHOLD -- because WrestlerController._process_grapple_hold()
## draws the highest rung the meter affords. Past the signature threshold the
## same tie-up would throw a signature in the middle of the match, which is
## exactly what _opponent_is_ripe() exists to prevent. Momentum only moves on
## a landed move, and an AI that wants to lock up does not strike on the way
## in, so the band read here is the band the hold is resolved in.
func _wants_power_tie_up() -> bool:
	if _power_attempt_spent or not _opening_grapple_done():
		return false
	if controller.power_move == null and controller.power_move_pool.is_empty():
		return false
	var combat := controller.combat
	# Not in the feeling-out: nothing big in the first minute.
	if controller.flow and controller.flow.rung(controller) == "none":
		return false
	return combat.can_power() and not combat.can_signature() \
			and combat.tier_reached < CombatSystem.Tier.POWER

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
			- (target.combat.wear - target._damage_at_last_knockdown)
	# Fired up, his moves land harder (CombatSystem.COMEBACK_DAMAGE_SCALE),
	# so the same signature closes a bigger gap.
	var scale := CombatSystem.COMEBACK_DAMAGE_SCALE if controller.combat.is_fired_up() else 1.0
	# And the story scales what he takes (MatchFlow: the man being beaten down
	# is beaten down slowly). Unscaled, a signature that "closes the gap" left
	# him standing, he was still ripe, and the heel threw it again every ten
	# seconds -- fifteen Superman Punches in three and a half minutes
	# (flow_probe seed 3).
	scale *= target.combat.damage_taken_scale
	return remaining <= _weakest_signature_damage() * scale

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


## Sidestep around the opponent while holding striking range.
##
## Tangent plus a radial correction: the tangent of a circle centred on him
## carries the sidestep, and the radial term pulls back toward circle_distance
## so the orbit neither spirals in (inside him) nor out (past the reach of the
## next strike).
func _circle_move(to_target: Vector3, distance: float) -> Vector2:
	if distance < 0.001:
		return Vector2.ZERO
	var inward := to_target.normalized()
	var tangent := inward.cross(Vector3.UP).normalized() * _circle_direction()
	# Positive when he is too far away, so the radial term points inward.
	var radial := inward * clampf((distance - circle_distance) / circle_distance,
			-1.0, 1.0)
	var move := tangent + radial * circle_radial_pull
	if move.length() < 0.001:
		return Vector2.ZERO
	move = move.normalized()
	return Vector2(move.x, move.z)


## Which way round the pair is going this bout: +1 or -1.
##
## Deliberately NOT varied by player_index, which is the opposite of what
## _roll_tie_up_timing() does and is the whole reason this works.
##
## The tangent is inward.cross(UP), and the two men's `inward` vectors point at
## each other -- they are opposites. So the SAME sign sends them opposite ways
## in world space, which is two men orbiting the midpoint between them, and
## OPPOSITE signs send them the same way in world space, which is the pair
## crab-walking across the ring together.
##
## The first version seeded on player_index and did exactly that: measured with
## feel_probe, mean separation went 0.97 m -> 1.87 m and max separation hit
## 64.99 m -- in a 6 m ring. They walked out of the arena still circling. Both
## men take the same sign now, so the orbit closes.
##
## Seeded rather than random: ReplaySystem replays a match by re-running its
## inputs, and live randomness here would desync it (ARCHITECTURE.md).
func _circle_direction() -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = _match_seed * 6151 + int(_circle_tick / maxi(circle_bout_ticks, 1))
	return 1.0 if rng.randi() % 2 == 0 else -1.0


# --- No Holds Barred: weapons ------------------------------------------------
#
# Now and then -- the heel twice as often -- he goes and gets one: out through
# the ropes, along to the apron, under it, and out with the weapon he favours
# (WeaponDef.owners: Roman the chair, the steps, the table; Cody the weight
# belt). Then he uses it until it breaks, he has had his swings, or it is
# knocked out of his hands. A table or a bed of tacks he sets up beside the
# man and then works to stand him in front of it, so the next knockdown puts
# him through it. A few runs a match: it is still a wrestling match.
enum WeaponPlan { NONE, FETCH, USE }
## How often the roll comes round, and its chance.
const WEAPON_ROLL_TICKS := 600
const WEAPON_CHANCE_HEEL := 0.5
const WEAPON_CHANCE := 0.25
## The roll comes round faster with the other man down: that is when you go.
const WEAPON_ROLL_DOWN_SCALE := 2.0
const WEAPON_RUNS := 3
## A man's own weapons are this much likelier to come out.
const SIGNATURE_WEIGHT := 4.0
## Swings before he drops it, and how long a fetch may take before he gives up.
const WEAPON_SWINGS := 4
const FETCH_GIVE_UP_TICKS := 1500
const USE_GIVE_UP_TICKS := 1800
## A throwable thrown from this far, this often.
const THROW_FROM := Vector2(2.0, 4.0)
const THROW_CHANCE := 0.3
## A weapon swing waits this many times the strike cooldown.
const WEAPON_COOLDOWN_SCALE := 2.0
## Lining him up in front of a set piece: one this far behind him (flat, from
## its centre), from no further off than LINE_UP_FROM, and near enough the
## charging spot is LINE_UP_THERE.
const LINE_UP_NEAR := Vector2(0.5, 1.5)
const LINE_UP_FROM := 4.5
const LINE_UP_THERE := 0.4
var _weapon_plan := WeaponPlan.NONE
var _weapon_roll := WEAPON_ROLL_TICKS
var _weapon_runs := 0
var _weapon_ticks := 0
var _weapon_swings := 0
var _weapon_pick: StringName = &""
var _throw_rolled := false
## Weapon runs started and weapon swings thrown this match (probes, tests).
var weapon_runs_started := 0
var weapon_swings_thrown := 0


func _weapon_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _match_seed * 92821 + _player_index * 613 + _circle_tick
	return rng


func _is_heel() -> bool:
	return Persona.of(controller.display_name) == Persona.Kind.HEEL


func _owns(def: WeaponDef) -> bool:
	var me := controller.display_name.to_lower()
	for o: StringName in def.owners:
		if me.contains(String(o)):
			return true
	return false


## His pick from under the ring: every weapon in stock, his own weighted up.
## Not the set pieces he has no use for (a ladder, the steps' set-up) --
## everything in the catalogue can be swung, so all are fair.
func choose_weapon(rng: RandomNumberGenerator) -> StringName:
	var stock := WeaponStock.of(controller)
	var ids: Array[StringName] = []
	var weights: Array[float] = []
	var total := 0.0
	for def: WeaponDef in WeaponCatalog.all():
		if not stock.in_stock(def.id):
			continue
		var w := SIGNATURE_WEIGHT if _owns(def) else 1.0
		ids.append(def.id)
		weights.append(w)
		total += w
	if ids.is_empty():
		return &""
	var r := rng.randf() * total
	for i in ids.size():
		r -= weights[i]
		if r <= 0.0:
			return ids[i]
	return ids[ids.size() - 1]


## Under the ring: hold the button, then hand the wheel his pick.
func _rummage_input() -> Dictionary:
	if _weapon_pick == &"":
		_weapon_pick = choose_weapon(_weapon_rng())
	return {"weapon": true, "weapon_pick": _weapon_pick}


## The weapon plan's input this tick, or {} to fall through to the match.
func _weapon_input(input: Dictionary, to_target: Vector3, distance: float) -> Dictionary:
	if not MatchRules.no_holds_barred(controller):
		return {}
	if controller.has_weapon() and _weapon_plan != WeaponPlan.USE:
		_start_use()
	match _weapon_plan:
		WeaponPlan.NONE:
			if _wants_weapon():
				_weapon_plan = WeaponPlan.FETCH
				_weapon_ticks = 0
				_weapon_pick = &""
				_weapon_runs += 1
				weapon_runs_started += 1
			else:
				return _line_up_input(input, to_target, distance)
		WeaponPlan.USE:
			if not controller.has_weapon():
				_weapon_plan = WeaponPlan.NONE
				return {}
			return _use_input(input, to_target, distance)
	# FETCH
	_weapon_ticks += 1
	if _weapon_ticks > FETCH_GIVE_UP_TICKS:
		_weapon_plan = WeaponPlan.NONE
		return {}
	if WeaponStock.of(controller).loose_near(controller.global_position):
		input["weapon"] = true          # one lying at his feet will do
		return input
	if not controller.outside_ring:
		if controller.is_crossing_ropes():
			return input
		input["move"] = _through_ropes_toward(_nearest_apron_out())
		input["rope_cross"] = controller.can_cross_ropes()
		return input
	if controller.can_rummage():
		_weapon_pick = &""
		input["weapon"] = true
		return input
	var to := _apron_spot() - controller.global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.05 else Vector3.ZERO
	input["move"] = Vector2(dir.x, dir.z)
	return input


func _wants_weapon() -> bool:
	if _weapon_runs >= WEAPON_RUNS or _weapon_roll > 0 or not _opening_grapple_done():
		return false
	if controller.combat.can_finisher() and _opponent_is_ripe():
		return false                    # he has the finish in hand: no detours
	var down := target.fsm.current_state == WrestlerFSM.State.DOWN
	_weapon_roll = int(WEAPON_ROLL_TICKS / (WEAPON_ROLL_DOWN_SCALE if down else 1.0))
	return _weapon_rng().randf() < (WEAPON_CHANCE_HEEL if _is_heel() else WEAPON_CHANCE)


## Outside the ropes on the side of the ring nearest him.
func _nearest_apron_out() -> Vector3:
	var p := controller.global_position
	var axis := Vector3(signf(p.x), 0.0, 0.0) if absf(p.x) >= absf(p.z) else Vector3(0.0, 0.0, signf(p.z))
	if axis == Vector3.ZERO:
		axis = Vector3.RIGHT
	return p + axis * 3.0


## Where he kneels to reach under: at the apron on his side, inside the lane.
func _apron_spot() -> Vector3:
	var p := Vector3(controller.global_position.x, 0.0, controller.global_position.z)
	var axis := GrappleRig._outside_side(p)
	var lat := Vector3(absf(axis.z), 0.0, absf(axis.x))
	var lane := clampf(p.dot(lat), -WrestlerController.RUMMAGE_LANE + 0.4, WrestlerController.RUMMAGE_LANE - 0.4)
	return axis * (WrestlerController.DECK_KEEP_OUT + WrestlerController.RUMMAGE_REACH * 0.5) + lat * lane


func _start_use() -> void:
	_weapon_plan = WeaponPlan.USE
	_weapon_ticks = 0
	_weapon_swings = 0
	_throw_rolled = false


func _use_input(input: Dictionary, to_target: Vector3, distance: float) -> Dictionary:
	_weapon_ticks += 1
	var def := controller.held_weapon.def
	var dir := to_target.normalized() if distance > 0.001 else Vector3.ZERO
	# done with it: had his swings, taken too long, or the finish is there
	if _weapon_swings >= WEAPON_SWINGS or _weapon_ticks > USE_GIVE_UP_TICKS or _wants_signature_tie_up():
		_weapon_plan = WeaponPlan.NONE
		input["grapple"] = true          # grapple with it in hand drops it
		return input
	# not the time: he went back through the ropes, or he is on the mat
	if controller.outside_ring != target.outside_ring:
		return {}
	if target.fsm.current_state == WrestlerFSM.State.DOWN:
		if def.set_up != "" and def.set_piece:
			# a table, the tacks: set it down beside him
			var spot := target.global_position + _flat(controller.global_position - target.global_position) * 1.6
			var to_spot := _flat(spot - controller.global_position)
			if to_spot.length() > 0.25:
				input["move"] = Vector2(to_spot.normalized().x, to_spot.normalized().z)
				return input
			input["grapple"] = true
			_weapon_plan = WeaponPlan.NONE
			return input
		return {}
	if target.fsm.current_state in WrestlerController.UNHITTABLE_STATES:
		return {}
	var ranged := def.swing in [WeaponDef.Swing.GUN, WeaponDef.Swing.LAUNCHER, WeaponDef.Swing.SPRAY]
	var swing := WeaponCatalog.swing_move(def)
	var reach: float = float(WeaponCatalog.RANGED[def.swing]) * 0.85 if ranged \
			else Vector2(swing.contact_offset.x, swing.contact_offset.z).length() + swing.contact_radius * 0.5
	# a throw, once an approach, from the right distance
	if def.throwable and not ranged and not _throw_rolled and distance >= THROW_FROM.x and distance <= THROW_FROM.y:
		_throw_rolled = true
		if _weapon_rng().randf() < THROW_CHANCE:
			input["throw"] = true
			weapon_swings_thrown += 1
			return input
	if distance > reach:
		input["move"] = Vector2(dir.x, dir.z)
		return input
	if _cooldown <= 0:
		input["move"] = Vector2(dir.x, dir.z) * 0.05      # square to him
		input["strike"] = true
		_weapon_swings += 1
		weapon_swings_thrown += 1
		_cooldown = int(strike_cooldown_ticks * WEAPON_COOLDOWN_SCALE)
		return input
	if distance < min_standoff and not ranged:
		input["move"] = Vector2(-dir.x, -dir.z)
	elif ranged and distance < 1.6:
		input["move"] = Vector2(-dir.x, -dir.z)       # room to aim
	return input


## A set piece standing near the other man: work round so he is between this
## man and it, back off to charging distance on that line, and run him
## through it -- a running attack carries a man 0.8-1.4 m back
## (nhb_weapon_probe --spear), and a table set across the line catches him
## anywhere in that. {} when there is none, or once the charge is on.
func _line_up_input(input: Dictionary, to_target: Vector3, distance: float) -> Dictionary:
	if _charging or _run_cooldown > 0 or not _opening_grapple_done():
		return {}
	if target.fsm.current_state != WrestlerFSM.State.IDLE and target.fsm.current_state != WrestlerFSM.State.LOCOMOTION:
		return {}
	if controller.outside_ring != target.outside_ring or distance > LINE_UP_FROM:
		return {}
	var stock := controller.get_parent().get_node_or_null("WeaponStock") as WeaponStock
	if stock == null:
		return {}
	var piece: WeaponActor = null
	for a in stock.set_up_pieces():
		var d := _flat(a.global_position - target.global_position).length()
		if a.def.set_piece and d >= LINE_UP_NEAR.x and d <= LINE_UP_NEAR.y:
			piece = a
			break
	if piece == null:
		return {}
	var away := _flat(target.global_position - piece.global_position).normalized()
	var spot := target.global_position + away * (run_engage_distance + 0.2)
	var to_spot := _flat(spot - controller.global_position)
	if to_spot.length() < LINE_UP_THERE:
		_charging = true                 # lined up: through it
		return {}
	# round him, not through him: sidestep while closing on the spot
	var dir := to_spot.normalized()
	if to_target.length() > 0.001 and dir.dot(to_target.normalized()) > 0.3:
		dir = (dir + Vector3.UP.cross(to_target.normalized()) * 0.9).normalized()
	input["move"] = Vector2(dir.x, dir.z)
	return input


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
