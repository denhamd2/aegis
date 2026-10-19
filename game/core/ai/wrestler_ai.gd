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
## Short post-move pause. The move animation and hit selling already create
## visible recovery; stacking several seconds of AI-only cooldown on top made
## both wrestlers stand idle between exchanges.
@export var strike_cooldown_ticks: int = 24
## strike_cooldown_ticks during a comeback (CombatSystem.is_fired_up()).
@export var comeback_strike_cooldown_ticks: int = 8
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
## The preferred striking distance. The AI should correct range directly,
## without orbiting the opponent during every strike cooldown.
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
## How strongly range corrections pull toward circle_distance.
@export var circle_radial_pull: float = 0.55
@export var min_standoff: float = 1.05
@export var run_engage_distance: float = 2.5
## Ticks after a running attack before another charge may start. A running
## attack is 69 ticks committed (18 startup + 5 active + 46 recovery) against a
## strike's 31, so without this it would crowd out the strike trading the
## match is made of.
@export var running_attack_cooldown_ticks: int = 48
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
## An AI wrestler avoids stacking a long staged getup onto every knockdown.
## Give him a brief selling beat, then let him trigger the measured quick
## recovery in either AI-vs-AI or human-vs-AI matches.
const AI_DOWN_RECOVERY_DELAY_TICKS := WrestlerController.QUICK_DOWN_RECOVERY_DELAY_TICKS
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
## 10/8 -> 6/6 with the tie-up's threshold (TieUpMinigame), for Fight
## Forever's quick lock-up.
@export var tie_up_reaction_ticks: int = 6
@export var tie_up_press_interval_ticks: int = 6

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
## 5-9 -> 3-5 (the owner, 19 Oct: AI v AI was "a lot of repetitive punching
## and kicking"). Fight Forever's matches are grapple-led: a short exchange of
## strikes, then a lock-up.
const WORK_TIE_UP_MIN := 3
const WORK_TIE_UP_MAX := 5
var _blows_since_lock_up := 0
var _work_tie_up_after := 7


var _cooldown: int = 0
## A brief, occasional lateral step after an exchange. The old neutral was
## either a continuous orbit or a perfectly frozen stare; this gives each AI
## a small, replayable bit of footwork without turning range-keeping into a
## circling routine.
const FOOTWORK_CHANCE := 0.45
const FOOTWORK_DELAY_TICKS := Vector2i(42, 76)
const FOOTWORK_DURATION_TICKS := Vector2i(8, 15)
var _footwork_wait := 0
var _footwork_ticks := 0
var _footwork_side := 1.0
var _footwork_rolls := 0
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
	if controller.outside_ring:
		_outside_ticks += 1
	else:
		if _outside_ticks > 0 and (_heading_in or _use_in_ring or _fetch_inside):
			_hold_ring_ticks = HOLD_RING_TICKS      # he brought it in here: wait for him
		_outside_ticks = 0
		_outside_spell = -1
		_heading_in = false
	if _hold_ring_ticks > 0:
		_hold_ring_ticks -= 1
	_circle_tick += 1
	# Footwork is presentation/gameplay input, so its timer shares the fixed
	# match tick and pauses through committed moves, hit reactions and grapples.
	if controller.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION,
			WrestlerFSM.State.RUN]):
		if _footwork_wait > 0:
			_footwork_wait -= 1
		elif _footwork_ticks > 0:
			_footwork_ticks -= 1
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
var _guard_rolls := 0
var _guard_decided := false
var _guard_intent := false


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


## A wrestler sometimes braces for a quick strike instead of trading punches.
## The read is made once per attack and is more likely when he has the health
## advantage; committed heavy moves and weapons are deliberately excluded.
func _roll_guard() -> bool:
	if target.fsm.current_state != WrestlerFSM.State.STRIKE \
			or not DefenseSystem.is_guardable_strike(target._active_move,
					target._is_weapon_swing(target._active_move)) \
			or not target._strike_reaches(target._active_move):
		_guard_decided = false
		_guard_intent = false
		return false
	if not _guard_decided:
		_guard_decided = true
		var rng := RandomNumberGenerator.new()
		rng.seed = _match_seed * 15401 + _player_index * 977 + _guard_rolls
		_guard_rolls += 1
		_guard_intent = rng.randf() < DefenseSystem.ai_guard_chance(
				controller.combat.health(), target.combat.health(), controller.combat.stamina)
	return _guard_intent


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
## The animation and hit reaction provide the dramatic beat. Keep the extra
## neutral pause short so AI-vs-AI exchanges maintain Fight Forever's brisk
## arcade rhythm instead of waiting several seconds between attempts.
const ACTION_GAP_SCALE := 1.0
const FATIGUE_COOLDOWN_MAX := 1.15

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
var _ladder_attempted_for_down := false


func _wants_taunt() -> bool:
	if not controller.can_taunt() or target.fsm.current_state != WrestlerFSM.State.DOWN \
			or target.fsm.ticks_in_state > TAUNT_WINDOW:
		return false
	# Fight Forever: full meter, he plays to the crowd to fire up to the
	# finisher (CombatSystem.taunted) -- or, already lit, to set it up
	var combat := controller.combat
	if controller.finisher_move and (combat.can_signature() and not combat.finisher_lit
			or combat.can_finisher() and not _setup_taunted):
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
	if controller.fsm.current_state == WrestlerFSM.State.LADDER_CLIMB:
		if controller.can_start_ladder_aerial():
			return {"grapple": true}
		var axis := -1.0 if controller.ladder_climb_progress() < 0.92 else 1.0
		return {"move": Vector2(0.0, axis)}
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
	if controller.fsm.current_state == WrestlerFSM.State.DOWN \
			and controller.is_ai and not controller.dead:
		return {"strike": controller.fsm.ticks_in_state >= AI_DOWN_RECOVERY_DELAY_TICKS}
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
	if input["reversal"]:
		return input
	if _roll_guard():
		return {"guard": true}
	# No Holds Barred: out for a weapon, or using the one in his hands.
	var armed := _weapon_input(input, to_target, distance)
	if not armed.is_empty():
		return armed
	# He took it back into the ring: there he waits for the other man.
	if _hold_ring_ticks > 0 and not controller.outside_ring and target.outside_ring:
		return input
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
		_ladder_attempted_for_down = false
		_strut_armed = true
		_strut_point = Vector3.INF
	if target.fsm.current_state == WrestlerFSM.State.DOWN:
		if not target.dead and not _ladder_attempted_for_down and not controller.outside_ring \
				and controller.climbable_ladder_nearby() != null:
			_ladder_attempted_for_down = true
			return {"climb_ladder": true}
		# A dead opponent is a finish, not an invitation to play to the crowd.
		# Walk straight to the cover so the referee can count the pin.
		if not target.dead:
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
			if controller.outside_ring:
				var up := _entrance_way_move(controller.global_position, spot)
				if up != Vector2.ZERO and to_spot.length() > 1.5:
					input["move"] = up
		return input
	# If both wrestlers are on the floor, approach along the open ringside lane.
	# The ring deck blocks a straight path between opposite sides; feeding that
	# vector to both controllers made them push into the apron indefinitely.
	# Weapon fetch/use decisions above still take priority, but neutral movement
	# always closes distance by routing around a clear corner.
	if controller.outside_ring and target.outside_ring and _back_in_the_ring_now():
		return _into_the_ring(input)
	if controller.outside_ring and target.outside_ring and distance > tie_up_range:
		input["move"] = _outside_opponent_move(target.global_position)
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
			else:
				_schedule_footwork()
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
			# strike_cooldown_ticks (24 ticks, 0.4 seconds) of a man
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
## Outside fights go around the apron on a square route. A waypoint only 0.4m
## beyond the deck put both corner waypoints in the steel-steps collision
## boxes; two wrestlers approaching around the ring could meet those boxes and
## push in place forever. Clear the full diagonal flight plus a body margin,
## while staying inside the ringside barricade.
const STEP_ROUTE_CLEARANCE := RingBuilder.APRON_OUT \
		+ (RingBuilder.STEP_PLATFORM + RingBuilder.STEP_RUN * RingBuilder.STEP_TREADS \
		+ RingBuilder.STEP_APRON_GAP + 0.15) * sqrt(0.5) \
		+ RingBuilder.STEP_WIDTH * sqrt(0.5) * 0.5
const OUTSIDE_ROUTE_RADIUS := minf(WrestlerController.BARRICADE_KEEP_IN - 0.15,
		maxf(WrestlerController.DECK_KEEP_OUT + 0.4, STEP_ROUTE_CLEARANCE + 0.15))


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


## Approach another wrestler while both are on the floor. A straight line
## between wrestlers on opposite sides runs into the solid ring deck, where
## both AIs can push forever without making progress. Walk along the outside
## edge to the next corner on the shorter safe arc; the entrance steps occupy
## the (+X, -Z) corner, so prefer the other arc whenever it is available.
func _outside_opponent_move(him: Vector3) -> Vector2:
	var me := controller.global_position
	var up := _entrance_way_move(me, him)
	if up != Vector2.ZERO:
		return up
	return _ringside_move(me, him)


## Whether he takes the floor fight back into the ring: both out a spell,
## him empty-handed and free, and the other man on his feet to follow.
func _back_in_the_ring_now() -> bool:
	if not controller.outside_ring or controller.has_weapon() or _weapon_plan != WeaponPlan.NONE:
		return false
	if _heading_in:
		return true
	if _outside_spell < 0:
		_outside_spell = _weapon_rng().randi_range(OUTSIDE_SPELL.x, OUTSIDE_SPELL.y)
	if _outside_ticks < _outside_spell:
		return false
	if target.fsm.current_state in [WrestlerFSM.State.DOWN, WrestlerFSM.State.GETUP] \
			or target.is_crossing_ropes():
		return false
	_heading_in = true
	return true


## Up the ramp and back down it: through the barricade's gap at the ramp
## foot, and onto the deck's wide back by way of its lip, never straight at
## a barricade. ZERO when neither end is up the entrance way.
func _entrance_way_move(me: Vector3, goal: Vector3) -> Vector2:
	var me_up := ArenaBuilder.in_entrance_way(me)
	var goal_up := ArenaBuilder.in_entrance_way(goal)
	if not me_up and not goal_up:
		return Vector2.ZERO
	var lane := ArenaBuilder.RAMP_HALF_WIDTH - WrestlerController.BODY_RADIUS - 0.25
	var gap_z := -ArenaBuilder.BARRICADE_RADIUS
	var lip := Vector3(0.0, 0.0, ArenaBuilder.STAGE_FRONT - 1.2)
	var me_deck := ArenaBuilder.is_match_stage(me)
	var goal_deck := ArenaBuilder.is_match_stage(goal)
	var via := goal
	if me_up and goal_up:
		if me_deck != goal_deck and absf((me if me_deck else goal).x) > lane:
			via = lip
	elif goal_up:
		# on the ringside floor: round the ring to the gap, then through it
		if me.z < -WrestlerController.DECK_KEEP_OUT - 0.3 and absf(me.x) < lane + 0.3:
			via = Vector3(clampf(goal.x, -lane, lane), 0.0, gap_z - 1.5)
		else:
			return _ringside_move(me, Vector3(0.0, 0.0, gap_z + 1.1))
	else:
		# up there, going back down: off the deck by its lip, then down the
		# ramp to its foot
		via = lip if me_deck and absf(me.x) > lane else Vector3(clampf(me.x, -lane, lane) * 0.5,
				0.0, gap_z + 0.8)
	var move := Vector2(via.x - me.x, via.z - me.z)
	return move.normalized() if move.length() > 0.01 else Vector2(0.0, signf(goal.z - me.z))


## Round the ring on the ringside floor to `him`.
func _ringside_move(me: Vector3, him: Vector3) -> Vector2:
	var step_escape := _outside_step_escape_move(me)
	if step_escape.length_squared() > 0.0:
		return Vector2(step_escape.x, step_escape.z)
	var my_side := GrappleRig._outside_side(me)
	var his_side := GrappleRig._outside_side(him)
	if my_side.dot(his_side) > 0.5:
		var direct := him - me
		direct.y = 0.0
		return Vector2(direct.x, direct.z).normalized()

	var radius := OUTSIDE_ROUTE_RADIUS
	var edge := radius * 2.0
	var perimeter := edge * 4.0
	var from_s := _outside_perimeter_s(me, radius)
	var to_s := _outside_perimeter_s(him, radius)
	var clockwise := fposmod(to_s - from_s, perimeter)
	var counter := perimeter - clockwise
	var step_corner_s := edge  # (+X, -Z), where the entrance steps sit.
	var cw_has_steps := _outside_arc_contains(from_s, to_s, step_corner_s,
			perimeter, true)
	var ccw_has_steps := _outside_arc_contains(from_s, to_s, step_corner_s,
			perimeter, false)
	var use_clockwise := clockwise <= counter
	if cw_has_steps != ccw_has_steps:
		use_clockwise = not cw_has_steps
	var next_s := (floorf(from_s / edge) + 1.0) * edge if use_clockwise \
			else (ceilf(from_s / edge) - 1.0) * edge
	var corner := int(roundf(fposmod(next_s, perimeter) / edge)) % 4
	var points := [Vector2(-radius, -radius), Vector2(radius, -radius),
			Vector2(radius, radius), Vector2(-radius, radius)]
	var waypoint: Vector2 = points[corner]
	var move := waypoint - Vector2(me.x, me.z)
	if move.length() < 0.22:
		var next_corner := posmod(corner + (1 if use_clockwise else -1), 4)
		waypoint = points[next_corner]
		move = waypoint - Vector2(me.x, me.z)
	if move.length() < 0.05:
		move = Vector2(his_side.z, his_side.x)
	return move.normalized()


## If the wrestler is in the steps' expanded footprint, peel him away from
## the nearest face before chasing. Otherwise move_and_slide can leave him
## pressed against the step box while the perimeter route is tangent to it.
static func _outside_step_escape_move(point: Vector3) -> Vector3:
	var length := RingBuilder.STEP_PLATFORM + RingBuilder.STEP_RUN * RingBuilder.STEP_TREADS
	var half_length := length * 0.5
	var half_width := RingBuilder.STEP_WIDTH * 0.5
	var safe_radius := WrestlerController.BODY_RADIUS + 0.08
	for corner: Vector2 in RingBuilder.STEP_CORNERS:
		var out := RingBuilder.step_out_dir(corner)
		var across := Vector3(out.z, 0.0, -out.x)
		var apron_corner := Vector3(corner.x * RingBuilder.APRON_OUT, 0.0,
				corner.y * RingBuilder.APRON_OUT)
		var centre := apron_corner + out * (half_length + RingBuilder.STEP_APRON_GAP)
		var delta := Vector3(point.x - centre.x, 0.0, point.z - centre.z)
		var along := delta.dot(out)
		var across_distance := delta.dot(across)
		var clamped_along := clampf(along, -half_length, half_length)
		var clamped_across := clampf(across_distance, -half_width, half_width)
		var away := delta - out * clamped_along - across * clamped_across
		var distance := away.length()
		if distance >= safe_radius:
			continue
		if distance < 0.001:
			# Already within the box: leave through its nearest side.
			var end_clearance := half_length - absf(along)
			var side_clearance := half_width - absf(across_distance)
			away = out * signf(along) if end_clearance < side_clearance \
					else across * signf(across_distance)
		return away.normalized() if away.length_squared() > 0.0 else out
	return Vector3.ZERO
static func _outside_perimeter_s(point: Vector3, radius: float) -> float:
	var edge := radius * 2.0
	var side := GrappleRig._outside_side(point)
	if side.x > 0.5:
		return edge + clampf(point.z, -radius, radius) + radius
	if side.x < -0.5:
		return edge * 3.0 + radius - clampf(point.z, -radius, radius)
	if side.z < -0.5:
		return clampf(point.x, -radius, radius) + radius
	return edge * 2.0 + radius - clampf(point.x, -radius, radius)


static func _outside_arc_contains(from_s: float, to_s: float, point_s: float,
		perimeter: float, clockwise: bool) -> bool:
	var distance := fposmod(to_s - from_s, perimeter) if clockwise \
			else fposmod(from_s - to_s, perimeter)
	var along := fposmod(point_s - from_s, perimeter) if clockwise \
			else fposmod(from_s - point_s, perimeter)
	return along > 0.001 and along <= distance + 0.001


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


## Make only a small radial correction when outside the striking band. The old
## tangent term made both AI wrestlers continuously orbit each other while
## waiting on cooldown, which read as comical circling instead of a staredown.
func _circle_move(to_target: Vector3, distance: float) -> Vector2:
	if distance < 0.001:
		return Vector2.ZERO
	if _footwork_wait <= 0 and _footwork_ticks > 0:
		var toward := to_target.normalized()
		var tangent := Vector3(-toward.z, 0.0, toward.x) * _footwork_side
		return Vector2(tangent.x, tangent.z)
	var inward := to_target.normalized()
	var error := distance - circle_distance
	# Avoid foot jitter around the preferred distance. Beyond this dead band he
	# steps in or gives ground, never continuously strafes around the target.
	if absf(error) < 0.12:
		return Vector2.ZERO
	var move := inward * signf(error) * circle_radial_pull
	return Vector2(move.x, move.z)


## One short step, on less than half the cooldowns. The roll belongs to this
## AI's own seeded stream so mirrored opponents do not move in lockstep and a
## replay keeps the same footwork.
func _schedule_footwork() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _match_seed * 13007 + _player_index * 7919 + _footwork_rolls
	_footwork_rolls += 1
	_footwork_ticks = 0
	_footwork_wait = 0
	if rng.randf() >= FOOTWORK_CHANCE:
		return
	_footwork_side = -1.0 if rng.randi_range(0, 1) == 0 else 1.0
	_footwork_wait = rng.randi_range(FOOTWORK_DELAY_TICKS.x, FOOTWORK_DELAY_TICKS.y)
	_footwork_ticks = rng.randi_range(FOOTWORK_DURATION_TICKS.x, FOOTWORK_DURATION_TICKS.y)


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
const WEAPON_ROLL_TICKS := 300
const WEAPON_CHANCE_HEEL := 0.68
const WEAPON_CHANCE := 0.55
## The roll comes round faster with the other man down: that is when you go.
const WEAPON_ROLL_DOWN_SCALE := 2.0
const WEAPON_RUNS := 12
## A man's own weapons are this much likelier to come out.
const SIGNATURE_WEIGHT := 7.0
## Firearms, explosives and hazardous set pieces are scarce, so bias them into
## the card rather than leaving them to a 1-in-35 flat draw. (The knives and
## swords are laid out on the stage several deep, WeaponStock.STAGE_LAYOUT.)
const WILD_WEAPONS: Array[StringName] = [
		&"handgun", &"rpg", &"bed_of_nails", &"table", &"thumbtacks", &"barbed_wire_board"]
const WILD_WEIGHT := 10.0
## Swings before he drops it, and how long a fetch may take before he gives up.
const WEAPON_SWINGS := 4
const FETCH_GIVE_UP_TICKS := 1500
const USE_GIVE_UP_TICKS := 1800
## A throwable thrown from this far, this often.
const THROW_FROM := Vector2(2.0, 4.0)
const THROW_CHANCE := 0.3
## A weapon swing waits this many times the strike cooldown.
const WEAPON_COOLDOWN_SCALE := 2.0
## The table spot: one within LINE_UP_FROM of both men; he stands SUPLEX_DROP
## in front of it (near enough is LINE_UP_THERE), the other man in front of
## him within LINE_UP_CONE_DEG of the line.
const LINE_UP_FROM := 4.0
const SUPLEX_DROP := 1.3
const LINE_UP_THERE := 0.3
const LINE_UP_CONE_DEG := 30.0
## A set piece is set down from this far from him (it lands 0.95 m in front
## of the man setting it, so about 0.95 m from him: clear of him, and where a
## running attack carries him).
const SET_DOWN_FROM := 1.9
## No Holds Barred is mostly a fight IN the ring (the owner, 19 Oct: the AI
## spent nine-tenths of a match on the ringside floor, nhb_weapon_probe's
## zones). A weapon picked up outside is taken back in this often to be used
## there -- carried through the ropes, or slid under the bottom one first
## SLIDE_IN_SHARE of those times -- and one fetched from the stage less
## often, so the walk back down the ramp is where that fight happens.
const IN_RING_USE := 0.65
const IN_RING_USE_FROM_STAGE := 0.3
const SLIDE_IN_SHARE := 0.45
## A weapon run goes up to the stage's layout this often (when there is one);
## otherwise he reaches under the ring.
const STAGE_RUN_CHANCE := 0.4
## A loose weapon on his side of the ropes this near is picked up rather than
## fetched from anywhere else.
const LOOSE_FETCH_REACH := 6.0
## With both men out, empty-handed and standing, the one who gets a moment
## takes the fight back into the ring after this long on the floor (ticks).
const OUTSIDE_SPELL := Vector2i(600, 1080)
## Having taken it back in, he waits this long in the ring for the other man
## to follow rather than going straight back out after him.
const HOLD_RING_TICKS := 240
var _heading_in := false
var _hold_ring_ticks := 0
var _slid_in := false
var _weapon_plan := WeaponPlan.NONE
var _use_in_ring := false
var _slide_in := false
var _fetch_inside := false
var _fetch_from_stage := false
var _outside_ticks := 0
var _outside_spell := -1
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
		if def.id in WILD_WEAPONS:
			w *= WILD_WEIGHT
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
				_fetch_inside = false
				_fetch_from_stage = _weapon_rng().randf() < STAGE_RUN_CHANCE
				_weapon_runs += 1
				weapon_runs_started += 1
			else:
				return _line_up_input(input, to_target, distance)
		WeaponPlan.USE:
			if not controller.has_weapon():
				if _slid_in:
					# slid in under the bottom rope: in after it, and pick it up
					_slid_in = false
					_slide_in = false
					_weapon_plan = WeaponPlan.FETCH
					_weapon_ticks = 0
					_fetch_inside = true
					return input
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
	if _fetch_inside and controller.outside_ring:
		return _into_the_ring(input)
	var loose := WeaponStock.of(controller).nearest_loose(controller.global_position,
			not controller.outside_ring, LOOSE_FETCH_REACH * (2.0 if _fetch_inside else 1.0))
	if loose:
		var to_loose := _flat(loose.global_position - controller.global_position)
		var toward := to_loose.normalized()
		input["move"] = Vector2(toward.x, toward.z)
		return input
	if _fetch_inside:
		_weapon_plan = WeaponPlan.NONE
		return {}
	var stage_weapon := WeaponStock.of(controller).nearest_stage_weapon(
			controller.global_position) if _fetch_from_stage else null
	if stage_weapon and controller.outside_ring:
		var to_stage_weapon := stage_weapon.global_position - controller.global_position
		to_stage_weapon.y = 0.0
		if to_stage_weapon.length() > WeaponStock.PICKUP_REACH:
			input["move"] = _outside_opponent_move(stage_weapon.global_position)
		else:
			input["weapon"] = true
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
	var rng := _weapon_rng()
	var from_stage := ArenaBuilder.in_entrance_way(controller.global_position)
	_use_in_ring = controller.outside_ring and rng.randf() \
			< (IN_RING_USE_FROM_STAGE if from_stage else IN_RING_USE)
	_slide_in = _use_in_ring and rng.randf() < SLIDE_IN_SHARE


## Back into the ring: down off the ramp first if he is up it, then to the
## apron on his side and through the ropes.
func _into_the_ring(input: Dictionary) -> Dictionary:
	if controller.is_crossing_ropes():
		return input
	var me := controller.global_position
	if ArenaBuilder.in_entrance_way(me):
		input["move"] = _entrance_way_move(me, Vector3(0.0, 0.0, -WrestlerController.DECK_KEEP_OUT))
		return input
	input["move"] = _through_ropes_toward(me)
	input["rope_cross"] = controller.can_cross_ropes()
	return input


func _use_input(input: Dictionary, to_target: Vector3, distance: float) -> Dictionary:
	_weapon_ticks += 1
	var def := controller.held_weapon.def
	var dir := to_target.normalized() if distance > 0.001 else Vector3.ZERO
	# done with it: had his swings, taken too long, or the finish is there
	if _weapon_swings >= WEAPON_SWINGS or _weapon_ticks > USE_GIVE_UP_TICKS or _wants_signature_tie_up():
		_weapon_plan = WeaponPlan.NONE
		input["grapple"] = true          # grapple with it in hand drops it
		return input
	# into the ring with it, to use it there: slid under the bottom rope
	# first, or carried through
	if _use_in_ring and not controller.outside_ring:
		_use_in_ring = false                # in: from here it is used wherever he is
	if _use_in_ring and controller.outside_ring:
		if _slide_in and controller.can_slide_weapon_into_ring():
			_slid_in = true
			input["throw"] = true
			return input
		var lane_in := _into_the_ring(input)
		if _slide_in:
			lane_in.erase("rope_cross")         # to the apron, not through it yet
		return lane_in
	# not the time: he went back through the ropes, or he is on the mat
	if controller.outside_ring != target.outside_ring:
		return {}
	if def.set_up != "" and def.set_piece and not target.is_crossing_ropes():
		if def.id == &"ladder" and target.fsm.current_state == WrestlerFSM.State.DOWN:
			var to_ladder := _flat(target.global_position - controller.global_position)
			if to_ladder.length() > 0.9:
				input["move"] = Vector2(to_ladder.normalized().x, to_ladder.normalized().z)
				return input
			input["move"] = Vector2.ZERO
			input["grapple"] = true
			input["set_ladder_upright"] = true
			_weapon_plan = WeaponPlan.NONE
			return input
		# a table, the tacks: not swung -- set down close by him, across
		# the way this man faces him, for _line_up_input to put him through
		var from_him := _flat(controller.global_position - target.global_position)
		var spot := target.global_position + (from_him.normalized() if from_him.length() > 0.05 \
				else Vector3.BACK) * SET_DOWN_FROM
		var to_spot := _flat(spot - controller.global_position)
		if to_spot.length() > 0.3:
			input["move"] = Vector2(to_spot.normalized().x, to_spot.normalized().z)
			return input
		input["move"] = Vector2(-from_him.x, -from_him.z).normalized() * 0.05     # square to him
		input["grapple"] = true
		_weapon_plan = WeaponPlan.NONE
		return input
	if target.fsm.current_state == WrestlerFSM.State.DOWN:
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
		input["move"] = _outside_opponent_move(target.global_position) \
				if controller.outside_ring and target.outside_ring \
				else Vector2(dir.x, dir.z)
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


## A table standing near them: get between it and the other man with it at
## his back, lock up, and if he wins it, the vertical suplex -- it drops a man
## 1.3 m behind the man throwing it (nhb_weapon_probe --spear), on the table.
## While the other man is down or getting up he waits on that spot. {} when
## there is no table, or nothing to do about it this tick.
func _line_up_input(input: Dictionary, to_target: Vector3, distance: float) -> Dictionary:
	controller.prefer_hold_move = null
	if not _opening_grapple_done():
		return {}
	var standing := target.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION])
	var rising := target.fsm.is_in([WrestlerFSM.State.DOWN, WrestlerFSM.State.GETUP])
	if not standing and not rising:
		return {}
	if controller.outside_ring != target.outside_ring:
		return {}
	var suplex := _suplex()
	if suplex == null:
		return {}
	var stock := controller.get_parent().get_node_or_null("WeaponStock") as WeaponStock
	if stock == null:
		return {}
	var piece: WeaponActor = null
	for a in stock.set_up_pieces():
		if a.def.set_piece and a.def.landing_damage > 0.0 \
				and _flat(a.global_position - target.global_position).length() <= LINE_UP_FROM \
				and _flat(a.global_position - controller.global_position).length() <= LINE_UP_FROM:
			piece = a
			break
	if piece == null:
		return {}
	# A ladder uses a distinct MoveDef for its damage/recovery tuning while
	# reusing the proven paired suplex lift and root arc. Its landing response
	# is ladder-specific in ImpactSell.
	var spot_move := suplex
	if piece.def.id == &"ladder":
		spot_move = load("res://resources/moves/weapon_ladder_slam.tres") as MoveDef
		if spot_move == null:
			return {}
	var out := _flat(target.global_position - piece.global_position)
	if out.length() < 0.05:
		return {}
	var spot := piece.global_position + out.normalized() * SUPLEX_DROP
	if not controller.outside_ring:
		spot.x = clampf(spot.x, -WrestlerController.RING_KEEP_IN, WrestlerController.RING_KEEP_IN)
		spot.z = clampf(spot.z, -WrestlerController.RING_KEEP_IN, WrestlerController.RING_KEEP_IN)
	var to_spot := _flat(spot - controller.global_position)
	if to_spot.length() <= LINE_UP_THERE:
		if rising:
			input["move"] = Vector2.ZERO  # waiting for him, not covering him
			return input
		var facing := _flat(controller.global_position - piece.global_position).normalized()
		if distance <= tie_up_range and to_target.normalized().dot(facing) >= cos(deg_to_rad(LINE_UP_CONE_DEG)):
			# him in front, the table at his back: lock up for the suplex
			input["move"] = Vector2(to_target.x, to_target.z).normalized() * 0.05
			input["grapple"] = true
			controller.tie_up_rung_cap = CombatSystem.Tier.GRAPPLE
			controller.prefer_hold_move = spot_move
			return input
		# there: hold it, square to him, and let him come -- he closes on
		# his own, and walking out to meet him would leave the spot
		input["move"] = Vector2(to_target.x, to_target.z).normalized() * 0.05 if distance > 0.01 else Vector2.ZERO
		return input
	# round him, not through him: sidestep while closing on the spot
	var dir := to_spot.normalized()
	if to_target.length() > 0.001 and dir.dot(to_target.normalized()) > 0.3 and distance < to_spot.length():
		dir = (dir + Vector3.UP.cross(to_target.normalized()) * 0.9).normalized()
	input["move"] = Vector2(dir.x, dir.z)
	return input


## His vertical suplex, or null.
func _suplex() -> MoveDef:
	for m: MoveDef in [controller.grapple_move] + controller.grapple_move_pool:
		if m and String(m.animation_pair_id).contains("vertical_suplex"):
			return m
	return null


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
