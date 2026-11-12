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
## The man the story is not for passes on a chance to lead (initiative()):
## he waits this share of a strike cooldown, moving, before the next chance.
const PASS_COOLDOWN_SCALE := 1.0
var _initiative_rolls := 0


## Whether he takes this chance to lead the exchange: always when the phase
## is his or he has fired up, otherwise MatchFlow.initiative()'s share of the
## time. Seeded per man and per roll, like every other choice here.
func _takes_initiative() -> bool:
	if controller.flow == null or controller.combat.is_fired_up():
		return true
	var lead := controller.flow.initiative(controller)
	if lead >= 1.0:
		return true
	var rng := RandomNumberGenerator.new()
	rng.seed = _match_seed * 52711 + _player_index * 389 + _initiative_rolls
	_initiative_rolls += 1
	return rng.randf() < lead


## A string is this many blows; then a reset of RESET_TICKS, moving.
const STRING_BLOWS := 3
const RESET_TICKS := Vector2i(60, 110)
var _string_blows := 0


## Short post-move pause. The move animation and hit selling already create
## visible recovery; stacking several seconds of AI-only cooldown on top made
## both wrestlers stand idle between exchanges.
@export var strike_cooldown_ticks: int = 24
## strike_cooldown_ticks during a comeback (CombatSystem.is_fired_up()).
@export var comeback_strike_cooldown_ticks: int = 8
## Between strikes on a man trapped in a corner (Phase 4, position): he is
## worked over while he hangs there, not sized up.
@export var corner_strike_cooldown_ticks: int = 18
## Chance, each time he would strike a man hanging in a corner who has
## already taken a blow there, that he runs in with his corner move instead
## (when he has one).
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
## Of his charges as the other man rises, the share he takes off the ropes
## instead (WrestlerController.begin_rope_run).
const ROPE_RUN_SHARE := 0.55
var _rope_run_this_rise := false
## Times he ran the ropes (flow_probe).
var rope_runs := 0
## The other man running the ropes at him: met with a rebound move this
## share of the time; otherwise he takes the running attack.
const ROPE_RUN_COUNTER := 0.3
var _counter_rope_run := -1
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
var _charge_ticks := 0
const CHARGE_MAX_TICKS := 120
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
	if _charging:
		_charge_ticks += 1
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
		if not (controller.fsm.current_state == WrestlerFSM.State.TAUNT and controller._stalking):
			_spear_stalk = STALK_OFF


## Called only after the controller accepted the attack, rather than when the
## AI merely pressed strike at a target that might be busy or out of reach.
func _running_attack_started() -> void:
	_charging = false
	_charge_ticks = 0
	_run_cooldown = running_attack_cooldown_ticks
	_make_room_cooldown = make_room_cooldown_ticks

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


## Chain wrestling. How many links the opening lock-up runs to -- one or
## two, seeded -- and nothing out of any later one: the power and signature
## lock-ups are the business end of a match, and the chain is its opening.
##
## Fight Forever has no chain wrestling at all -- its tie-up reads in about
## 0.3 s and the move follows (gauntlet/refs/aew_ff_animation_review.md) --
## and each link here is 1.8 s, so the opening ran 1-3 links, 3.2 s on
## average, before anybody threw anything. Now it is one link four times in
## five and never three: the opening still reads as wrestling, and is over
## in about two seconds (the owner, 25 Oct: "faster lock-ups").
const CHAIN_LINK_WEIGHTS := [4, 1, 0]
## The read tick the holder picks on, and the one the held man reads it on
## (inside WrestlerController.CHAIN_REVERSAL_WINDOW).
const CHAIN_PICK_TICK := 6
const CHAIN_READ_TICK := 8
## Chance the man in a hold reverses the next one, at full stamina; it falls
## with his stamina like a strike reversal's does.
const CHAIN_REVERSAL_CHANCE := 0.3
## How often a hold the AI has the better of ends in an Irish whip.
## 0.18 -> 0.45 (the owner, 9 Nov: "Irish whips are not working, I never see
## them"): the whip itself works end to end (rope_return_probe), but at 0.18
## of the few holds after the opening a match went by with none (moveset_tally
## seed 1, 70 s: no whip). A whip, then the lariat or big boot off the ropes,
## is a staple of the match, not a rarity.
const WHIP_CHANCE := 0.45
## Of those whips, the share sent into a corner rather than the ropes, by a
## man with something to do to him there (a corner strike or a corner move).
const CORNER_WHIP_SHARE := 0.4


func _wants_corner_whip() -> bool:
	if controller.corner_strike_move == null and controller.corner_move == null:
		return false
	if controller.outside_ring or target.outside_ring:
		return false
	return _chain_rng().randf() < CORNER_WHIP_SHARE
## How often the heel in control turns a lock-up into a rest hold: a
## headlock held two or three links (MatchFlow.wants_stall).
const REST_HOLD_CHANCE := 0.45
var _rest_hold := false
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
		_rest_hold = false
		# The heel in control slows it down: a headlock, held link after
		# link, the man in it fighting to get out -- the rest hold of the
		# heat (gauntlet/refs/ff_ai_flow.md). His hope spot is the reversal.
		# The Casket, the Ambulance: on the floor with him in his hands
		# and it there, he sends him at it (ShutIn decides if it holds).
		if _wants_shut_in_whip():
			return {"run": true, "shut_in": true}
		if _opening_grapple_done() and controller.flow \
				and controller.flow.wants_stall(controller) \
				and _chain_rng().randf() < REST_HOLD_CHANCE:
			_rest_hold = true
			_chain_plan = _chain_rng().randi_range(2, WrestlerController.CHAIN_LINKS_MAX)
		# Now and then, with a man in his hands after the opening, he sends him
		# into the ropes instead (the Irish whip) -- and is waiting when he
		# comes off them. Seeded, like every other roll.
		elif _opening_grapple_done() and _chain_rng().randf() < WHIP_CHANCE:
			var corner := _wants_corner_whip()
			# Into the steel: the Steel Cage's walls from in the ring, Hell
			# in a Cell's from the floor (always there: no ropes to run).
			var cell := MatchRules.mode_of(controller) == MatchRules.Mode.HELL_IN_A_CELL
			return {"run": true, "corner": corner, "cage": not corner \
					and MatchRules.caged(controller) \
					and (controller.outside_ring if cell else not controller.outside_ring) \
					and (cell or _chain_rng().randf() < CAGE_WHIP_SHARE)}
		# The opening lock-up is a lock-up into a grapple, not a chain-wrestling
		# exchange (the owner, 12 Nov: "They should start with a lockup
		# grapple, not chain wrestling"): _chain_plan stays 0 for it. The
		# chain's holds are for later lock-ups (rest holds, CHAIN_LINK_WEIGHTS).
	if c._chain_links >= _chain_plan:
		return {"chain": "none"}
	if c._chain_read != CHAIN_PICK_TICK:
		return {} # picked once; the controller holds on to it
	if _rest_hold:
		return {"chain": "headlock"}
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
	_run_far_outside(input)
	# Pacing: a worn man walks slower. Not a run -- a charge is a charge.
	if controller and input.has("move") and not input.get("run", false):
		input["move"] = (input["move"] as Vector2) * fatigue_walk_scale(
				controller.combat.total_damage())
	return input


## Going somewhere outside the ring -- up the ramp to the stage's weapons,
## back down it, round the ring to the desk -- he runs (the owner, 2 Nov:
## "The wrestlers don't run down the ramp, they walk quickly"): MOVE_SPEED is
## 3.5 m/s, a jog on a walk cycle. On the ramp or the stage, or bound for
## them, moving, empty-handed or carrying something light, and the other man
## more than RUN_TO_FROM away -- near him it is the fight's own pace. Only in
## the free states: in a hold, run is the Irish whip.
const RUN_TO_FROM := 4.0


func _run_far_outside(input: Dictionary) -> void:
	if controller == null or target == null or not controller.outside_ring or input.get("run", false):
		return
	if not controller.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION,
			WrestlerFSM.State.RUN]):
		return
	var move: Vector2 = input.get("move", Vector2.ZERO)
	if move.length() < 0.5:
		return
	if controller.has_weapon() and controller.held_weapon.def.set_piece:
		return
	var me := controller.global_position
	var on_the_way := ArenaBuilder.in_entrance_way(me) \
			or (_weapon_plan == WeaponPlan.FETCH and _fetch_from_stage)
	if not on_the_way:
		return
	if _flat(target.global_position - me).length() <= RUN_TO_FROM:
		return
	input["run"] = true


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
## Ticks spent walking to a ladder's foot this knockdown, and the most he
## spends before he leaves it for the cover.
var _ladder_walk_ticks := 0
const LADDER_WALK_GIVE_UP := 240
## Ladder dives he goes up for in a match: the spot, not a routine.
const LADDER_CLIMBS_MAX := 2
var ladder_climbs := 0


## On his way to the foot of a ladder he stood up, for the dive.
func going_for_ladder() -> bool:
	return _ladder_walk_ticks > 0 and not _ladder_attempted_for_down


# --- Hell in a Cell's roof (CellRoof) ----------------------------------------
#
# Once a match, off a big knockdown past CELL_DUE_AT, he decides to take it to
# the roof (CELL_ROOF_CHANCE, seeded): the cutters from under the ring, the
# chain cut, out of the door and up the front wall. The other man follows him
# out and up. Up there they fight as anywhere; the edge and the panels
# (CellRoof) do the rest. After a fall, the man left up there climbs down.

const CELL_DUE_AT := 90.0
const CELL_ROOF_CHANCE := 0.5
const CELL_ROLLS := 3
var _cell_rolls := 0
var _cell_rolled_for := -1
var _cell_plan := -1        # -1 undecided, 0 no, 1 the roof
## Ticks alone on the roof waiting for him; past ROOF_WAIT_TICKS, down.
var _roof_alone := 0
const ROOF_WAIT_TICKS := 60 * 7
## Been up and come back down: the roof is spent for this man.
var _roof_done := false
var _cell_ticks := 0
const CELL_GIVE_UP := 60 * 40


var _high_dive_rolled := false
var _high_dives := 0


func _wants_high_dive() -> bool:
	if _high_dives >= 1:
		return false
	if _high_dive_rolled:
		return false
	_high_dive_rolled = true
	if _cell_rng().randf() >= 0.55:
		return false
	_high_dives += 1
	return true


func going_for_the_roof() -> bool:
	return _cell_plan == 1


func _cell_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _match_seed * 4813 + _player_index * 97 + 31
	return rng


func _cell_input(distance: float) -> Dictionary:
	if Engine.get_physics_frames() % 1800 == 0:
		print("DBGCELLIN ", controller.name, " t=", controller.flow.seconds() if controller.flow else -1.0, " roof=", CellRoof.of(controller) != null, " busy=", CellRoof.of(controller).busy(controller) if CellRoof.of(controller) else false, " plan=", _cell_plan, " rolls=", _cell_rolls)
	var roof := CellRoof.of(controller)
	if roof == null or roof.busy(controller):
		return {}
	var p := controller.global_position
	# Up there alone: wait a while for him to follow (he is on his way up
	# when he is out on the floor); then -- or at once, after he went over --
	# back down, and the roof is done with (flow_probe seed 1, 11 Nov: up,
	# straight down, up again, 28 times, the other man never reaching it).
	if controller.on_roof and not target.on_roof and not roof.busy(target):
		_roof_alone += 1
		var coming := roof.is_outside_cell(target) and roof.falls == 0 \
				and target.fsm.current_state != WrestlerFSM.State.DOWN
		if coming and _roof_alone < ROOF_WAIT_TICKS:
			return {"move": Vector2.ZERO}
		_cell_plan = 0
		_roof_done = true
		if roof.at_roof_front_edge(p):
			return {"cell_route": true}
		return _to_cell_point(roof, _roof_front_point(roof), false)
	_roof_alone = 0
	if controller.on_roof:
		return _roof_fight(roof, distance)
	# On the floor, on the other side of the walls from him: round to the
	# door and through it (it is open once the chain has been cut).
	if not target.on_roof and not roof.busy(target) and not roof.door_locked \
			and roof.is_outside_cell(controller) != roof.is_outside_cell(target):
		return _through_cell_door(roof)
	var other: WrestlerAI = target.ai if target else null
	var following := not _roof_done and other != null and other.going_for_the_roof() \
			and (target.on_roof or roof.busy(target) or _outside_cell(roof, target.global_position))
	# Both out on the floor, round the walls from each other: round the
	# outside lane to him -- unless one of them is on his way up.
	if not target.on_roof and not roof.busy(target) and roof.is_outside_cell(controller) \
			and roof.is_outside_cell(target) and not following \
			and (_cell_plan != 1 or roof.falls > 0):
		var round := _round_the_cell(roof, target.global_position)
		if not round.is_empty():
			return round
	# Rolled once a knockdown, a few times a match, past CELL_DUE_AT.
	if _cell_plan < 1 and _cell_rolls < CELL_ROLLS and controller.flow \
			and controller.flow.seconds() > CELL_DUE_AT \
			and target.fsm.current_state == WrestlerFSM.State.DOWN \
			and target.knockdown_tier >= CombatSystem.Tier.POWER:
		var knockdown := Engine.get_physics_frames() - target.fsm.ticks_in_state
		if knockdown != _cell_rolled_for:
			_cell_rolled_for = knockdown
			_cell_rolls += 1
			var rng := _cell_rng()
			for i in _cell_rolls:
				rng.randf()
			_cell_plan = 1 if rng.randf() < CELL_ROOF_CHANCE else 0
			print("DBGPLAN ", controller.name, " roll ", _cell_rolls, " plan ", _cell_plan, " t=", controller.flow.seconds())
	if _cell_plan == 1 and roof.falls > 0:
		_cell_plan = 0
	if _roof_done:
		_cell_plan = 0
		following = false
	if _cell_plan != 1 and not following:
		return {}
	_cell_ticks += 1
	if _cell_ticks > CELL_GIVE_UP:
		_cell_plan = 0
		return {}
	# Out on the ramp side: up the front wall (the leader's side of the door,
	# the follower's the other).
	if _outside_cell(roof, p):
		if roof.at_climbable_wall(p):
			return {"cell_route": true}
		return _to_cell_point(roof, _climb_foot(roof, -1.0 if following and _cell_plan != 1 else 1.0), false)
	# In the ring: out of it toward the door.
	if not controller.outside_ring:
		var out := _through_ropes_toward(roof.door_axis() * (roof.half() - 0.7))
		return {"move": out, "rope_cross": controller.can_cross_ropes(), "run": true}
	# Locked, no cutters in hand: get them.
	if roof.door_locked and not (controller.has_weapon()
			and controller.held_weapon.def.id == &"wire_cutters"):
		if controller.has_weapon():
			return {"grapple": true}          # drops what he has
		var cutters := _loose_cutters()
		if cutters == null:
			return {}
		var to := _flat(cutters.global_position - p)
		if to.length() <= WeaponStock.PICKUP_REACH * 0.9:
			return {"weapon": true}
		return {"move": Vector2(to.normalized().x, to.normalized().z), "run": to.length() > 2.0}
	return _to_cell_point(roof, roof.door_axis() * (roof.half() - 0.75)
			+ Vector3.UP * WrestlerController.FLOOR_LEVEL, true)


## Up there with him: no ropes, no ring to go back to -- close in and work
## him over: strikes, and the grapples that dent the panels or put him over
## the edge (CellRoof). Every ROOF_BEAT ticks a choice, seeded.
const ROOF_BEAT := 24
const ROOF_GRAPPLE_SHARE := 0.4
var _roof_beat := 0


func _roof_fight(roof: CellRoof, distance: float) -> Dictionary:
	if not target.on_roof:
		return {}
	if target.fsm.current_state == WrestlerFSM.State.DOWN:
		# The referee's ground work (stomps, the haul up) takes it from here;
		# just stand over him.
		var to_him := _flat(target.global_position - controller.global_position)
		if to_him.length() > 1.1:
			return {"move": Vector2(to_him.normalized().x, to_him.normalized().z)}
		return {"move": Vector2.ZERO}
	var to := _flat(target.global_position - controller.global_position)
	if distance > WrestlerController.STRIKE_HIT_RANGE - 0.1:
		return {"move": Vector2(to.normalized().x, to.normalized().z)}
	_roof_beat += 1
	if _roof_beat % ROOF_BEAT != 0:
		return {"move": Vector2.ZERO}
	var rng := _cell_rng()
	for i in _roof_beat / ROOF_BEAT % 37:
		rng.randf()
	if rng.randf() < ROOF_GRAPPLE_SHARE:
		return {"grapple": true}
	return {"strike": true}


func _through_cell_door(roof: CellRoof) -> Dictionary:
	var p := controller.global_position
	var a := roof.door_axis()
	if roof.is_outside_cell(controller):
		if roof.in_door_lane_outside(p):
			return {"cell_route": true}
		var door_out := a * (roof.half() + 0.9)
		# Round the corner on his side first, then along the front.
		if p.dot(a) < roof.half() + 0.2:
			var lat := Vector3(absf(a.z), 0.0, absf(a.x))
			var side := signf(p.dot(lat)) if p.dot(lat) != 0.0 else 1.0
			return _to_cell_point(roof, a * (roof.half() + 0.55) + lat * side * (roof.half() + 0.55), false)
		return _to_cell_point(roof, door_out, false)
	if not controller.outside_ring:
		var out := _through_ropes_toward(a * (roof.half() - 0.7))
		return {"move": out, "rope_cross": controller.can_cross_ropes()}
	if roof.in_door_lane_inside(p):
		return {"cell_route": true}
	return _to_cell_point(roof, a * (roof.half() - 0.75), false)


## Toward `goal` round the outside of the walls: straight when the wall is
## not between, else to the outside corner that shortens the way most. {}
## when the way is clear (the ordinary chase takes it).
func _round_the_cell(roof: CellRoof, goal: Vector3) -> Dictionary:
	var p := controller.global_position
	var h := roof.half()
	if not _cell_between(h, p, goal) or _flat(goal - p).length() < 1.6:
		return {}
	# The corner a man can stand at: in from the barricade's chamfer.
	var c := h + 0.3
	var best := Vector3.ZERO
	var cost := INF
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner := Vector3(sx * c, p.y, sz * c)
			if _flat(corner - p).length() < 0.8 or _cell_between(h, p, corner):
				continue
			var k := _flat(corner - p).length() + _flat(goal - corner).length() \
					+ (6.0 if _cell_between(h, corner, goal) else 0.0)
			if k < cost:
				cost = k
				best = corner
	if cost == INF:
		return {}
	var to := _flat(best - p)
	return {"move": Vector2(to.normalized().x, to.normalized().z), "run": to.length() > 2.5}


## Does the cell (half `h`) stand between a and b on the floor?
static func _cell_between(h: float, a: Vector3, b: Vector3) -> bool:
	var lim := h + 0.1
	for i in 9:
		var q := a.lerp(b, (i + 1) / 10.0)
		if absf(q.x) < lim and absf(q.z) < lim:
			return true
	return false


func _outside_cell(roof: CellRoof, p: Vector3) -> bool:
	return roof.is_outside_cell(controller) and not controller.on_roof


func _climb_foot(roof: CellRoof, side := 1.0) -> Vector3:
	var a := roof.door_axis()
	var lat := Vector3(absf(a.z), 0.0, absf(a.x))
	return a * (roof.half() + 0.45) + lat * (1.45 * side)


func _roof_front_point(roof: CellRoof) -> Vector3:
	var a := roof.door_axis()
	var lat := Vector3(absf(a.z), 0.0, absf(a.x))
	return a * (roof.half() - 0.6) + lat * 1.45


## Walk to `goal`, then push at the route there (`cell_route`).
func _to_cell_point(roof: CellRoof, goal: Vector3, route: bool) -> Dictionary:
	var to := _flat(goal - controller.global_position)
	if to.length() <= 0.6 and route:
		return {"cell_route": true}
	return {"move": Vector2(to.normalized().x, to.normalized().z), "run": to.length() > 2.5}


func _loose_cutters() -> WeaponActor:
	var stock := WeaponStock.of(controller)
	for a in stock.actors:
		if is_instance_valid(a) and a.def.id == &"wire_cutters" and a.mode == WeaponActor.Mode.FLOOR:
			return a
	return null


# --- the Casket and Ambulance matches (ShutIn) ------------------------------
#
# Fought out to it, he whips the other man at it from the floor. Before the
# story's finish it is a near-miss (ShutIn), so he can go for it whenever it
# is there, up to SHUT_IN_TRIES a match; the man down is hauled up to be
# sent. Away from it on the floor, he heads for it when he has the upper hand.

const SHUT_IN_TRIES := 5
const SHUT_IN_FROM := 5.5
const SHUT_IN_WHIP_CHANCE := 0.75


func _wants_shut_in_whip() -> bool:
	var shut := ShutIn.of(controller)
	if shut == null or shut.busy() or shut.attempts >= SHUT_IN_TRIES or not controller.outside_ring \
			or not target.outside_ring or not _opening_grapple_done():
		return false
	var m: Vector3 = shut.container.mouth()
	if _flat(m - target.global_position).length() > SHUT_IN_FROM:
		return false
	return _chain_rng().randf() < SHUT_IN_WHIP_CHANCE


## On the floor, the man down or groggy: toward the casket (the ambulance),
## taking him with him by hauling him up near it. {} to fall through.
func _shut_in_input(distance: float) -> Dictionary:
	var shut := ShutIn.of(controller)
	if shut == null or shut.busy() or shut.attempts >= SHUT_IN_TRIES:
		return {}
	if not controller.outside_ring or not target.outside_ring or controller.has_weapon():
		return {}
	var m: Vector3 = shut.container.mouth()
	var him_to := _flat(m - target.global_position).length()
	# He is down by it: up on his feet to be sent in.
	if target.fsm.current_state == WrestlerFSM.State.DOWN and him_to <= SHUT_IN_FROM \
			and not target.dead:
		if controller.can_pickup(target):
			controller.begin_pickup(target)
			return {"move": Vector2.ZERO}
		var to_him := _flat(target.global_position - controller.global_position)
		return {"move": Vector2(to_him.normalized().x, to_him.normalized().z)}
	# Standing by it: in to grab him.
	if him_to <= SHUT_IN_FROM and distance > 1.0 and target.fsm.current_state != WrestlerFSM.State.DOWN:
		var to := _flat(target.global_position - controller.global_position)
		return {"move": Vector2(to.normalized().x, to.normalized().z)}
	return {}


# --- the Ladder match (HangingPrize; gauntlet/refs/ladder_match.md) ---------
#
# A ladder stood up under the belt is climbed when the other man is down or
# out of the ring; the other man gets up to stop him and tips the ladder, or
# hits him off it. Only when the story gives the finish to the climber
# (MatchFlow.finish_allowed, flow.winner) does the man down stay down.

var _going_for_prize := false
## Climbs he makes for it in a match before he gives up and fights on.
const PRIZE_CLIMBS_MAX := 12
var prize_climbs := 0


func going_for_prize() -> bool:
	return _going_for_prize


func _prize_finish_for(climber: WrestlerController) -> bool:
	var flow := climber.flow
	return flow != null and flow.finish_allowed() and flow.winner == climber


func _climbing_for_prize() -> bool:
	if not MatchRules.prize_hangs(controller):
		return false
	if controller.is_unhooking():
		return true
	var ladder := _ladder_under_prize()
	return ladder != null and controller._ladder_actor == ladder


## The ladder stood up under the belt, or null.
func _ladder_under_prize() -> WeaponActor:
	if not MatchRules.prize_hangs(controller) or controller.get_parent() == null:
		return null
	var stock := WeaponStock.of(controller)
	if stock == null:
		return null
	for a in stock.set_up_pieces():
		if a.def.id != &"ladder" or not a.is_climbable_ladder():
			continue
		var mount := WrestlerController.ladder_top_stand(a)
		if Vector2(mount.x - HangingPrize.AT.x, mount.z - HangingPrize.AT.z).length() \
				<= HangingPrize.REACH_XZ:
			return a
	return null


func _nearest_ring_ladder() -> WeaponActor:
	var best: WeaponActor = null
	var best_d := INF
	for a in WeaponStock.of(controller).set_up_pieces():
		if a.def.id != &"ladder":
			continue
		var p := a.global_position
		if absf(p.x) > WrestlerController.RING_KEEP_IN or absf(p.z) > WrestlerController.RING_KEEP_IN:
			continue
		var d := _flat(p - controller.global_position).length()
		if d < best_d:
			best = a
			best_d = d
	return best


func _prize_input(distance: float) -> Dictionary:
	_going_for_prize = false
	if not MatchRules.prize_hangs(controller) or controller.outside_ring:
		return {}
	var prize := HangingPrize.of(controller)
	if prize == null or prize.won_by:
		return {}
	# He is up there: tip it, or get to it.
	if target.fsm.current_state == WrestlerFSM.State.LADDER_CLIMB:
		if controller.can_tip_ladder():
			return {"tip_ladder": true}
		var ladder: WeaponActor = target._ladder_actor
		if is_instance_valid(ladder):
			var to := _flat(ladder.global_position - controller.global_position)
			return {"move": Vector2(to.normalized().x, to.normalized().z), "run": to.length() > 2.0}
		return {}
	var under := _ladder_under_prize()
	# None under it and none left under the ring: the one lying in the ring
	# (knocked flat off the last climb) is picked up and stood up again.
	if under == null and not controller.has_weapon() and _weapon_plan == WeaponPlan.NONE \
			and not WeaponStock.of(controller).in_stock(&"ladder"):
		var flat := _nearest_ring_ladder()
		if flat:
			var to := _flat(flat.global_position - controller.global_position)
			if to.length() <= WeaponStock.PICKUP_REACH * 0.9:
				_weapon_plan = WeaponPlan.FETCH
				_weapon_ticks = 0
				_fetch_inside = true
				return {"weapon": true}
			return {"move": Vector2(to.normalized().x, to.normalized().z)}
	if under == null or controller.has_weapon() or prize_climbs >= PRIZE_CLIMBS_MAX:
		return {}
	var clear := target.fsm.current_state == WrestlerFSM.State.DOWN or target.outside_ring \
			or distance > 3.2
	if not clear:
		return {}
	_going_for_prize = true
	if controller.climbable_ladder_nearby() == under:
		prize_climbs += 1
		return {"climb_ladder": true}
	var foot := under.global_transform * Vector3(0.0, 0.0, -WrestlerController.LADDER_FRONT_OFFSET)
	var to_foot := _flat(foot - controller.global_position)
	return {"move": Vector2(to_foot.normalized().x, to_foot.normalized().z), "run": to_foot.length() > 2.0}


# --- the cage (Steel Cage: gauntlet/refs/steel_cage.md) ----------------------
#
# 2K's advice is the AI's rule: go for the cage only with the other man down
# off something big. Off a signature he rallies (CageEscape.RALLY_*) and gets
# to the wall in time -- the near-escape, pulled off the top. Off a finisher
# he does not, and that is how a cage match the story gives to this man ends
# by escape (ESCAPE_FINISH_SHARE of them). The rest end on the pin.

## Escape attempts in a match: near-escapes, and the one that wins.
const CAGE_ATTEMPTS_MAX := 3
## The chance, off a signature before the finish, that he goes for the cage.
const NEAR_ESCAPE_CHANCE := 0.5
## Of the cage matches the story gives him, the share he ends by escaping.
const ESCAPE_FINISH_SHARE := 0.4
## Decided as the man goes down: no later than this into the knockdown.
const ESCAPE_DECIDE_WINDOW := 40
## Walking to the wall longer than this, he gives it up.
const CAGE_WALK_GIVE_UP := 240
## At the wall: this close to his spot.
const CAGE_SPOT_REACH := 0.3
var cage_attempts := 0
var _cage_going := false
var _cage_door := false
var _cage_spot := Vector3.INF
var _cage_walk := 0
var _cage_decided_for := -1
var _escape_finish := -1
var _cage_rolls := 0
## Of his whips at a side in a cage, the share sent into the steel.
const CAGE_WHIP_SHARE := 0.5


## On his way to the cage wall (or the door) to get out.
func going_for_escape() -> bool:
	return _cage_going


func _cage_rng(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _match_seed * 7919 + _player_index * 613 + salt
	return rng


func _ends_by_escape() -> bool:
	if _escape_finish < 0:
		_escape_finish = 1 if _cage_rng(1).randf() < ESCAPE_FINISH_SHARE else 0
	return _escape_finish == 1


func _wants_cage_escape() -> bool:
	if not MatchRules.escape_wins(controller) or cage_attempts >= CAGE_ATTEMPTS_MAX \
			or controller.outside_ring or target.dead \
			or target.fsm.current_state != WrestlerFSM.State.DOWN \
			or target.fsm.ticks_in_state > ESCAPE_DECIDE_WINDOW \
			or target.knockdown_tier < CombatSystem.Tier.SIGNATURE:
		return false
	# Once a knockdown. The frame only tells knockdowns apart; the roll is
	# salted by a count, so a replay rolls the same whatever frame it is.
	var knockdown := Engine.get_physics_frames() - target.fsm.ticks_in_state
	if _cage_decided_for == knockdown:
		return false
	_cage_decided_for = knockdown
	_cage_rolls += 1
	var flow := controller.flow
	if flow == null:
		return true
	if flow.finish_allowed():
		return flow.winner == controller and _ends_by_escape() \
				and target.knockdown_tier >= CombatSystem.Tier.FINISHER
	return target.knockdown_tier == CombatSystem.Tier.SIGNATURE \
			and _cage_rng(100 + _cage_rolls).randf() < NEAR_ESCAPE_CHANCE


## The cage, for the AI: stopping the other man getting out (up the wall after
## him, or a blow at the door), or going for it himself.
func _cage_input(distance: float) -> Dictionary:
	var escape := controller.cage_escape()
	if escape == null:
		return {}
	if escape.is_escaping(target) and escape.is_stoppable(target):
		_cage_going = false
		var c := escape.climb_of(target)
		if c.route == CageEscape.Route.DOOR:
			if distance <= WrestlerController.STRIKE_HIT_RANGE:
				return {"strike": true}
			var to_him := _flat(target.global_position - controller.global_position).normalized()
			return {"move": Vector2(to_him.x, to_him.z), "run": distance > 2.0}
		return _to_cage_spot(escape.chase_spot(target, controller.global_position), c.axis,
				"cage_climb")
	if not _cage_going and _wants_cage_escape():
		_cage_going = true
		_cage_walk = 0
		cage_attempts += 1
		_plan_cage_route(escape)
	if not _cage_going:
		return {}
	_cage_walk += 1
	if target.fsm.current_state != WrestlerFSM.State.DOWN or _cage_walk > CAGE_WALK_GIVE_UP:
		_cage_going = false
		return {}
	var axis := CageBuilder.wall_axis(_cage_spot)
	var got := _to_cage_spot(_cage_spot, axis, "cage_door" if _cage_door else "cage_climb")
	if got.has("cage_climb") or got.has("cage_door"):
		_cage_going = false
	return got


## The door when it is about as near as the nearest wall (it is quicker, and
## a man at it is also easier to stop), otherwise straight up the nearest
## wall, kept off the corner posts.
const DOOR_PREFERENCE := 0.5


func _plan_cage_route(escape: CageEscape) -> void:
	var spec := escape.cage.spec if escape.cage else CageBuilder.Spec.steel_cage()
	var me := _flat(controller.global_position)
	var door_spot := spec.door_axis * WrestlerController.RING_KEEP_IN
	var axis := CageBuilder.wall_axis(me)
	var lat := CageBuilder.lateral_of(axis)
	var keep := spec.half - CageEscape.CORNER_KEEP - 0.1
	var wall_spot := axis * WrestlerController.RING_KEEP_IN + lat * clampf(me.dot(lat), -keep, keep)
	if axis == spec.door_axis:
		# On the door's own wall, the door is the way.
		wall_spot = door_spot
	_cage_door = _flat(door_spot - me).length() <= _flat(wall_spot - me).length() + DOOR_PREFERENCE
	_cage_spot = door_spot if _cage_door else wall_spot


func _to_cage_spot(spot: Vector3, axis: Vector3, intent: String) -> Dictionary:
	var to := _flat(spot - controller.global_position)
	if to.length() <= CAGE_SPOT_REACH:
		return {intent: true, "move": Vector2(axis.x, axis.z)}
	var dir := to.normalized()
	return {"move": Vector2(dir.x, dir.z), "run": to.length() > 1.6}


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


## Roman's build to the Spear (gauntlet/refs/ff_moves_and_gameplay_plan.md, AI
## staples 6). With the finish his to take and the man down, he does not lock
## him up for it: he backs off SPEAR_STALK_DISTANCE, drops into his set-up
## (WrestlerController.begin_spear_setup: the canvas pounded, the roar, the
## coil) and waits there; the man gets up into the Spear
## (WrestlerController.try_running_finisher).
const SPEAR_STALK_DISTANCE := 3.0
## Inside the ropes with room to spare, as the strut.
const SPEAR_STALK_LIMIT := 2.3
## The walk back to the spot and the charge are each given this long.
const SPEAR_STALK_TICKS := 240
enum { STALK_OFF, STALK_BACK, STALK_SET, STALK_CHARGE }
var _spear_stalk := STALK_OFF
var _spear_spot := Vector3.INF
var _spear_ticks := 0


## The Spear out of nowhere (2 Nov: in flow_probe seed 1 Cody, the story's
## winner, had the whole comeback and never stayed down long enough for the
## stalk, and the Spear never came). In the comeback or the finish, with it
## up, both men in the ring and the other man on his feet SPEAR_NOWHERE_MAX
## away, he runs at him -- at most once per SPEAR_NOWHERE_COOLDOWN.
const SPEAR_NOWHERE_MAX := 7.0
const SPEAR_NOWHERE_COOLDOWN := 600
var _nowhere_cooldown := 0


func _wants_spear_from_nowhere(distance: float) -> bool:
	if _nowhere_cooldown > 0:
		_nowhere_cooldown -= 1
		return false
	if controller.finisher_run_move == null or target.dead or controller.flow == null:
		return false
	if controller.outside_ring or target.outside_ring or not controller.combat.can_finisher():
		return false
	if String(controller.flow.phase()["name"]) not in ["comeback", "finish"]:
		return false
	if distance > SPEAR_NOWHERE_MAX:
		return false
	var standing := WrestlerController.RUNNING_PAIRED_TARGET_STATES
	return controller.fsm.is_in(standing) and target.fsm.is_in(standing)


## The terms on which he would go for the finish by a lock-up
## (_wants_signature_tie_up), with a man down in the ring and a Spear to run.
func _wants_spear_stalk() -> bool:
	if controller.finisher_run_move == null or target.dead:
		return false
	if controller.outside_ring or target.outside_ring:
		return false
	if not controller.combat.can_finisher():
		return false
	var flow := controller.flow
	if flow and flow.winner == controller and flow.finish_allowed():
		return true
	# The comeback's near-fall: his finisher is up and the man is down --
	# build to it, ripe or not (MatchFlow gives each man one).
	if flow and String(flow.phase()["name"]) == "comeback":
		return true
	return _opponent_is_ripe()


func _begin_spear_stalk() -> void:
	_spear_stalk = STALK_BACK
	_spear_ticks = SPEAR_STALK_TICKS
	var away := controller.global_position - target.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(-target.global_position.x, 0.0, -target.global_position.z)
	if away.length() < 0.1:
		away = Vector3.RIGHT
	var p := target.global_position + away.normalized() * SPEAR_STALK_DISTANCE
	_spear_spot = Vector3(clampf(p.x, -SPEAR_STALK_LIMIT, SPEAR_STALK_LIMIT),
			controller.global_position.y, clampf(p.z, -SPEAR_STALK_LIMIT, SPEAR_STALK_LIMIT))


## Empty when the stalk is over and the rest of the brain should decide.
func _spear_stalk_input(input: Dictionary, to_target: Vector3, distance: float) -> Dictionary:
	_spear_ticks -= 1
	if target.dead or target.outside_ring or controller.outside_ring or _spear_ticks <= 0 \
			or not controller.combat.can_finisher():
		_spear_stalk = STALK_OFF
		return {}
	var up := target.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION,
			WrestlerFSM.State.RUN])
	match _spear_stalk:
		STALK_BACK:
			if up:
				_spear_stalk = STALK_CHARGE
				_spear_ticks = SPEAR_STALK_TICKS
			else:
				var to := _spear_spot - controller.global_position
				to.y = 0.0
				if to.length() > 0.2:
					var dir := to.normalized()
					input["move"] = Vector2(dir.x, dir.z)
					return input
				_spear_stalk = STALK_SET
				return {"spear_setup": true}
		STALK_SET:
			# Out of the set-up (the controller holds it until he is up).
			_spear_stalk = STALK_CHARGE
			_spear_ticks = SPEAR_STALK_TICKS
	# STALK_CHARGE: run it in as he stands.
	if not up:
		return input
	if controller.try_running_finisher():
		_spear_stalk = STALK_OFF
		return {"move": Vector2.ZERO}
	var dir := to_target.normalized() if distance > 0.01 else Vector3.ZERO
	input["move"] = Vector2(dir.x, dir.z)
	input["run"] = true
	return input


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
	# Up the cage or on the Cell's roof over the man down below: off it onto
	# him, once a match (the owner, 11 Nov: "jump off each").
	if controller.can_high_dive() and _wants_high_dive():
		return {"dive": true}
	if controller.fsm.current_state == WrestlerFSM.State.LADDER_CLIMB:
		# The Ladder match: up to the belt, and he stays there tugging.
		if _climbing_for_prize():
			return {"move": Vector2(0.0, -1.0)}
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
		# He sells while the other man goes up the ladder over him: up in the
		# second it took to reach its foot, the dive never came (nhb seed 4).
		# ...except when it is the belt he is going up for: then he gets up
		# to stop him, unless the story says this is the finish.
		if MatchRules.prize_hangs(controller) and target.ai \
				and (target.fsm.current_state == WrestlerFSM.State.LADDER_CLIMB
					or target.ai.going_for_prize()):
			return {"strike": controller.fsm.ticks_in_state >= AI_DOWN_RECOVERY_DELAY_TICKS / 2
					and not _prize_finish_for(target)}
		if target.fsm.current_state == WrestlerFSM.State.LADDER_CLIMB \
				or (target.ai and target.ai.going_for_ladder()):
			return {"strike": false}
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
	# Coming back off the ropes from a whip: that is the ropes' momentum, not
	# his choice, and the man who sent him there decides what happens next.
	if controller.is_whip_returning():
		# Off the ropes he ran himself: his running attack as he reaches him.
		if controller.rope_running:
			var gap := _flat(target.global_position - controller.global_position).length()
			return {"strike": gap <= maxf(WrestlerController.STRIKE_HIT_RANGE + 0.4,
					controller.running_attack_reach())}
		return {}
	# He sent the other man into the ropes: he stands his ground and meets him
	# coming back with his rebound move (WrestlerController.try_rebound_move()
	# times it).
	if not target.rope_running:
		_counter_rope_run = -1
	elif _counter_rope_run < 0:
		_counter_rope_run = 1 if _chain_rng().randf() < ROPE_RUN_COUNTER else 0
	if target.is_whip_returning() and not controller.rebound_moves.is_empty() \
			and (not target.rope_running or _counter_rope_run == 1):
		return {"rebound": true}

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
	# He is reaching under the apron for a weapon: nothing cuts that off
	# (WrestlerController.is_digging_for_weapon), so no swing -- close in and
	# be waiting for him when he comes up with it.
	if target.is_digging_for_weapon() and not controller.has_weapon():
		var to_dig := _flat(target.global_position - controller.global_position)
		if to_dig.length() > 1.6:
			return {"move": Vector2(to_dig.normalized().x, to_dig.normalized().z)}
		return {"move": Vector2.ZERO}
	# The cage: stop him getting out, or get out himself.
	var caged := _cage_input(distance)
	if not caged.is_empty():
		return caged
	# Hell in a Cell: out of it with the cutters, and up onto the roof.
	var cell := _cell_input(distance)
	if not cell.is_empty():
		return cell
	# The Casket, the Ambulance: him up and at it.
	var shut := _shut_in_input(distance)
	if not shut.is_empty():
		return shut
	# The Ladder match: up for the belt, or stop the man going up for it.
	var prize := _prize_input(distance)
	if not prize.is_empty():
		return prize
	# No Holds Barred: out for a weapon, or using the one in his hands --
	# unless a ladder he stood up is ready for its dive: then up it, not off
	# for another weapon (nhb_weapon_probe seed 1, 2 Nov: he stood it up
	# over Cody and walked away to fetch a chair).
	if not controller.has_weapon() and _weapon_plan == WeaponPlan.FETCH \
			and not _ladder_attempted_for_down and _ladder_to_climb() != null:
		_weapon_plan = WeaponPlan.NONE
	var armed := {} if _weapon_plan == WeaponPlan.NONE and not controller.has_weapon() \
			and not _ladder_attempted_for_down and _ladder_to_climb() != null \
			else _weapon_input(input, to_target, distance)
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
	# Building to the Spear: backing off, set, or running it in.
	if _spear_stalk > 0:
		var stalk := _spear_stalk_input(input, to_target, distance)
		if not stalk.is_empty():
			return stalk
	# Or out of nowhere: the man is standing across the ring, the Spear is
	# there, and Roman runs it in (_wants_spear_from_nowhere).
	if _spear_stalk == 0 and _wants_spear_from_nowhere(distance):
		_spear_stalk = STALK_CHARGE
		_spear_ticks = SPEAR_STALK_TICKS / 2
		_nowhere_cooldown = SPEAR_NOWHERE_COOLDOWN
		var charge := _spear_stalk_input(input, to_target, distance)
		if not charge.is_empty():
			return charge
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
		_ladder_walk_ticks = 0
		_strut_armed = true
		_strut_point = Vector3.INF
	if target.fsm.current_state == WrestlerFSM.State.DOWN:
		# A ladder stood up by him, the dive on (_ladder_to_climb): to its
		# foot and up. It used to be one press from wherever he stood, and
		# from 1.2 m off the ladder that press missed its foot and he never
		# tried again (nhb_weapon_probe seed 4, 2 Nov).
		var climb := _ladder_to_climb() if not target.dead and not _ladder_attempted_for_down else null
		if climb:
			var foot := climb.global_transform * Vector3(0.0, 0.0, -WrestlerController.LADDER_FRONT_OFFSET)
			var to_foot := _flat(foot - controller.global_position)
			_ladder_walk_ticks += 1
			if _ladder_walk_ticks > LADDER_WALK_GIVE_UP:
				_ladder_attempted_for_down = true
			# Within the climb's own reach is enough -- begin_ladder_climb sets
			# him on the foot. Held off it by the man lying beside it, he
			# stood 1.4 m off at 0.7 x the reach and never pressed (seed 1).
			elif to_foot.length() <= WrestlerController.LADDER_INTERACT_REACH - 0.1:
				_ladder_attempted_for_down = true
				ladder_climbs += 1
				return {"climb_ladder": true}
			else:
				# Round the ladder, not into it: from behind it the straight
				# line to its foot ran into its legs and he walked on the spot
				# (nhb_weapon_probe seed 1, 2 Nov). To its side first.
				var front := _flat(foot - climb.global_position).normalized()
				var rel := _flat(controller.global_position - climb.global_position)
				var goal := foot
				if rel.dot(front) < 0.3:
					var side := front.cross(Vector3.UP).normalized()
					if rel.dot(side) < 0.0:
						side = -side
					goal = climb.global_position + side * 1.0 + front * 0.4
				var step := _flat(goal - controller.global_position).normalized()
				return {"move": Vector2(step.x, step.z)}
		# A dead opponent is a finish, not an invitation to play to the crowd.
		# Walk straight to the cover so the referee can count the pin.
		# Off his own finisher he covers at once: no taunt, no strut. Measured,
		# Roman's Spear in the finish went unpinned while he played to the
		# crowd, and the match ran out with no winner.
		var off_finisher := controller.last_landed_tier >= CombatSystem.Tier.FINISHER
		if _spear_stalk == 0 and not off_finisher and _wants_spear_stalk():
			_begin_spear_stalk()
			return _spear_stalk_input(input, to_target, distance)
		if not target.dead and not off_finisher:
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
	# On the floor it is a chase, not two men jogging face to face (the owner,
	# 3 Nov: "it feels more like a synchronized dance. I would expect one to be
	# running facing away from the other, and the other wrestler chasing him,
	# and if close enough to attack him from behind").
	var chase := _floor_chase_input(input, to_target, distance)
	if not chase.is_empty():
		return chase
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
		_rope_run_this_rise = _charge_this_rise and _chain_rng().randf() < ROPE_RUN_SHARE
	elif target.fsm.current_state != WrestlerFSM.State.GETUP:
		_rise_rolled = false
	# Or he runs the ropes as the man gets to his feet, and meets him coming
	# off them (the owner, 3 Nov: "the wrestlers didn't run the ropes").
	if _charge_this_rise and _rope_run_this_rise and _run_cooldown <= 0 \
			and target.fsm.current_state == WrestlerFSM.State.GETUP \
			and controller.can_rope_run():
		_rope_run_this_rise = false
		_charge_this_rise = false
		_run_cooldown = running_attack_cooldown_ticks
		rope_runs += 1
		return {"rope_run": true}
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
	if _charging and (WrestlerController.UNHITTABLE_STATES.has(target.fsm.current_state)
			or _charge_ticks >= CHARGE_MAX_TICKS):
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
		_charge_ticks = 0

	if _charging:
		var dir := to_target.normalized()
		# Both are required to stay in RUN: _process_free_movement() only
		# transitions there when run is pressed AND there is movement to make.
		input["move"] = Vector2(dir.x, dir.z)
		input["run"] = true
		if distance <= controller.running_attack_reach():
			# Keep the request latched until the controller accepts a legal
			# running attack. A temporarily busy target must not consume it.
			input["strike"] = true
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
		elif wants_tie_up and _is_work_tie_up() and _cooldown <= 0 and not _takes_initiative():
			# Not his part of the match to lead: no lock-up of his own just now.
			_cooldown = int(strike_cooldown_ticks * PASS_COOLDOWN_SCALE)
			input["move"] = _circle_move(to_target, distance)
		elif wants_tie_up and _is_work_tie_up() and _cooldown > 0:
			input["move"] = _circle_move(to_target, distance)
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
		elif _cooldown <= 0 and distance <= reach and not is_reading() and not cornered \
				and not _takes_initiative():
			# Not his part of the match to lead (MatchFlow.initiative): he
			# squares up and lets the other man come, and answers in his bursts.
			_cooldown = int(strike_cooldown_ticks * PASS_COOLDOWN_SCALE)
			input["move"] = _circle_move(to_target, distance)
		elif _cooldown <= 0 and distance <= reach and not is_reading():
			# Hanging in the corner, with a corner move to hand: sometimes
			# the flurry gives way to the run-in instead of another blow --
			# after one at least, so Cody's chops come before his knee and
			# Roman's lariats before his Spear (both rolled the run-in first
			# in a tally, and the man never took a blow in the buckle).
			if cornered and controller.corner_move != null \
					and target._corner_hits >= 1 \
					and _chain_rng().randf() < CORNER_MOVE_CHANCE \
					and controller.try_corner_spear():
				return input
			input["strike"] = true
			_blows_since_lock_up += 1
			_string_blows += 1
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
			# A string of blows, then a reset: he steps off, squares up and
			# goes again, the way an exchange breathes. Not when fired up --
			# the comeback is a flurry.
			if _string_blows >= STRING_BLOWS and not controller.combat.is_fired_up():
				_string_blows = 0
				var rng := _chain_rng()
				_cooldown = maxi(_cooldown, rng.randi_range(RESET_TICKS.x, RESET_TICKS.y))
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
	# The finish is his (MatchFlow.winner) and the match may end: with the
	# finisher in hand he goes for it, ripe or not.
	var flow := controller.flow
	if flow and flow.winner == controller and flow.finish_allowed() \
			and controller.combat.can_finisher() and controller.finisher_move:
		return true
	if not _opponent_is_ripe():
		return false
	# The finisher is never held back: it is how the match ends.
	if controller.combat.can_finisher() and controller.finisher_move:
		return true
	return _signature_retry <= 0 and controller.combat.can_signature()


## Called by the controller when one of this man's signatures lands.
func signature_landed(_knocked_down: bool) -> void:
	_signature_retry = SIGNATURE_RETRY_TICKS


## The highest rung a lock-up this man wins may draw when nothing capped it
## (WrestlerController._pick_hold_move): whatever the meter affords only
## when he would lock up for his signature or finisher himself
## (_wants_signature_tie_up: the man ripe and the retry spent, or the finish
## his); otherwise no higher than the power move.
##
## Without it, winning any uncapped lock-up -- the other man going for his
## power move or his own signature, or the opening one -- handed the winner
## his signature whatever state his opponent was in, retry wait or not:
## Roman landed eight in two tallied matches, two backbreakers nine seconds
## apart, while Cody's four signature lock-ups landed him one
## (moveset_tally seeds 1 and 4, 26 Oct).
func lock_up_cap() -> int:
	return -1 if _wants_signature_tie_up() else CombatSystem.Tier.POWER


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
	# Nothing left that the story will show again (MovePlaybook): he keeps
	# working with what is left -- strikes, the corner, the ropes -- rather
	# than lock up to throw the same slam a fifth time.
	if not controller._story_has(controller.grapple_move, controller.grapple_move_pool) \
			and not (controller.power_move and controller._story_has(controller.power_move,
					controller.power_move_pool)):
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
	# The story leans the contest: the man whose part of the match it is
	# wins most of the lock-ups (MatchFlow.initiative). Measured before this,
	# Cody won lock-up after lock-up in Roman's heat and threw his slams.
	if controller and controller.flow:
		var lead := controller.flow.initiative(controller)
		_this_tie_up_interval = maxi(1, int(round(_this_tie_up_interval * lerpf(1.6, 1.0, lead))))


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
## The dangerous ones -- firearms, explosives, wire, nails, glass, fire, the
## ladder -- biased into the card rather than left to a 1-in-35 flat draw.
## The owner (2 Nov, AI vs AI): "tables being taken from under the ring too
## many times, I rarely saw the more dangerous weapons". The table was one of
## these at x10 AND Roman's and Kenny's own at x7: 70 against 10 for each
## dangerous one, near half of their picks. (The knives and swords are laid
## out on the stage several deep, WeaponStock.STAGE_LAYOUT.)
const WILD_WEAPONS: Array[StringName] = [
		&"handgun", &"rpg", &"bed_of_nails", &"thumbtacks", &"barbed_wire_board",
		&"barbed_wire_bat", &"barbed_wire_chair", &"board_with_nails", &"light_tubes",
		&"sledgehammer", &"ladder", &"glass_pane", &"fire_torch"]
const WILD_WEIGHT := 4.0
## The ladder on top of that: over four seeded No Holds Barred matches it came
## out once among the wild weapons, and the owner has never seen it climbed.
const LADDER_WEIGHT := 2.5
## The table: still the common set piece, no longer the pick. Its owners'
## bonus is capped at OWNED_SET_PIECE_WEIGHT rather than SIGNATURE_WEIGHT.
const CARNAGE_WEAPONS: Array[StringName] = [&"table"]
const CARNAGE_WEIGHT := 3.0
const OWNED_SET_PIECE_WEIGHT := 2.0
## Each time a weapon has come out this match its weight is divided by this:
## a match is a run of different weapons, not the same table four times.
const REPEAT_WEAPON_DIVISOR := 4.0
## Weapon id -> times picked this match.
var _picked_weapons := {}
## Swings before he drops it, and how long a fetch may take before he gives up.
## (2 Nov: "ensure they don't overuse one weapon": three swings, not four.)
const WEAPON_SWINGS := 3
## A weapon he has used this many times this match he leaves lying: he goes
## for another rather than picking the same chair up again.
const REUSE_MAX := 2
## Weapon id -> times he has had it in his hands this match (rummaged,
## fetched, picked up loose or taken off the other man).
var used_weapons := {}
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
## The powerbomb brings a man's hips down through a table's top this far in
## front of the man throwing it (tools/probe/drop_probe: 1.46-1.49 m for these,
## Roman, Cody and Kenny alike), so he stands this far out from the table,
## facing it, the other man between them.
const POWERBOMB_DROP := 1.48
const TABLE_POWERBOMBS: Array[StringName] = [&"ff_powerbomb_1", &"ff_sit_out_powerbomb_2"]
const TABLE_POWERBOMB := "res://resources/moves/ff/powerbomb_1.tres"
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
## (2 Nov: "more time battling outside the ring ... using the full selection
## of weapons": most weapons are now used where they were found.)
const IN_RING_USE := 0.35
const IN_RING_USE_FROM_STAGE := 0.1
const SLIDE_IN_SHARE := 0.45
## A weapon run goes up to the stage's layout this often (when there is one);
## otherwise he reaches under the ring.
const STAGE_RUN_CHANCE := 0.4
## A loose weapon on his side of the ropes this near is picked up rather than
## fetched from anywhere else.
const LOOSE_FETCH_REACH := 6.0
## With both men out, empty-handed and standing, the one who gets a moment
## takes the fight back into the ring after this long on the floor (ticks).
## The owner, 2 Nov: "the wrestlers are coming back into the ring a little
## too much. I want a bit more time battling outside the ring" -- 20-30 s on
## the floor, from 10-18. (25-40 s put two matches in four outside 70% of
## the time: more than "a bit".)
const OUTSIDE_SPELL := Vector2i(1200, 1800)
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


## The weapons he has had in his hands REUSE_MAX times: left lying.
func _spent_weapons() -> Dictionary:
	var spent := {}
	for id: StringName in used_weapons:
		if int(used_weapons[id]) >= REUSE_MAX:
			spent[id] = true
	return spent


## The owner, 2 Nov: "Ensure there is at least one ladder climb and jump."
## Past LADDER_DUE_AT into a No Holds Barred match with nobody yet having been
## up a ladder, his next weapon run is for one: from under the ring, picked for
## certain, and always taken into the ring (_start_use), where it is stood
## up by the man he puts down and climbed for the dive (_ladder_to_climb).
const LADDER_DUE_AT := 150.0
const LADDER_RUNS_MAX := 2


const TLC_WEIGHT := 4.0


func ladder_due() -> bool:
	# The Ladder match: one to stand under the belt, whenever none is there.
	if MatchRules.prize_hangs(controller):
		return not controller.has_weapon() and _ladder_under_prize() == null \
				and WeaponStock.of(controller).in_stock(&"ladder")
	if not MatchRules.no_holds_barred(controller) or controller.flow == null:
		return false
	if controller.flow.seconds() < LADDER_DUE_AT:
		return false
	# Due until somebody has been up one: a ladder swung and left on the
	# ramp (nhb_weapon_probe seed 3, 2 Nov) is not the spot the owner asked
	# for, so the next run is for another.
	if ladder_climbs > 0 or controller.has_weapon():
		return false
	# Twice each, not every run (seed 3 fetched six before the dive).
	if int(_picked_weapons.get(&"ladder", 0)) >= LADDER_RUNS_MAX:
		return false
	var other: WrestlerAI = target.ai if target else null
	if other and other.ladder_climbs > 0:
		return false
	var stock := WeaponStock.of(controller)
	for a in stock.set_up_pieces():
		if a.def.id == &"ladder" and a.is_climbable_ladder() \
				and absf(a.global_position.x) < WrestlerController.RING_KEEP_IN \
				and absf(a.global_position.z) < WrestlerController.RING_KEEP_IN:
			return false                # one stands in the ring already
	return stock.in_stock(&"ladder")


## His pick from under the ring: every weapon in stock, his own weighted up.
## Not the set pieces he has no use for (a ladder, the steps' set-up) --
## everything in the catalogue can be swung, so all are fair.
func choose_weapon(rng: RandomNumberGenerator) -> StringName:
	if ladder_due():
		return &"ladder"
	var stock := WeaponStock.of(controller)
	var ids: Array[StringName] = []
	var weights: Array[float] = []
	var total := 0.0
	for def: WeaponDef in WeaponCatalog.all():
		if not stock.in_stock(def.id):
			continue
		# The cutters are Hell in a Cell's, for its padlock (CellRoof).
		if def.id == &"wire_cutters":
			continue
		var w := 1.0
		if _owns(def):
			w = OWNED_SET_PIECE_WEIGHT if def.set_piece else SIGNATURE_WEIGHT
		if def.id in WILD_WEAPONS:
			w *= WILD_WEIGHT
			if def.id == &"ladder":
				w *= LADDER_WEIGHT
		elif def.id in CARNAGE_WEAPONS:
			w *= CARNAGE_WEIGHT
		# TLC: the match is named for them.
		if MatchRules.tables_and_chairs(controller) \
				and def.id in [&"table", &"ladder", &"steel_chair"]:
			w *= TLC_WEIGHT
		w /= pow(REPEAT_WEAPON_DIVISOR, float(maxi(int(_picked_weapons.get(def.id, 0)),
				int(used_weapons.get(def.id, 0)))))
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
		_picked_weapons[_weapon_pick] = int(_picked_weapons.get(_weapon_pick, 0)) + 1
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
				# the ladder is under the ring
				_fetch_from_stage = not ladder_due() and _weapon_rng().randf() < STAGE_RUN_CHANCE
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
	var spent := _spent_weapons()
	# The ladder's run is for the ladder: past the chairs lying about, under
	# the ring for it (nhb_weapon_probe seed 3, 2 Nov: every run picked up
	# something loose on the way, and the ladder came out with 90 s left).
	if ladder_due() and not _fetch_inside:
		for def: WeaponDef in WeaponCatalog.all():
			if def.id != &"ladder":
				spent[def.id] = true
	if WeaponStock.of(controller).loose_near(controller.global_position, spent):
		input["weapon"] = true          # one lying at his feet will do
		return input
	if _fetch_inside and controller.outside_ring:
		return _into_the_ring(input)
	var loose := WeaponStock.of(controller).nearest_loose(controller.global_position,
			not controller.outside_ring, LOOSE_FETCH_REACH * (2.0 if _fetch_inside else 1.0), spent)
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
	if MatchRules.prize_hangs(controller) and _weapon_roll <= 0 and _opening_grapple_done() \
			and ladder_due():
		_weapon_roll = WEAPON_ROLL_TICKS
		return true
	if _weapon_runs >= WEAPON_RUNS or _weapon_roll > 0 or not _opening_grapple_done():
		return false
	if controller.combat.can_finisher() and _opponent_is_ripe():
		return false                    # he has the finish in hand: no detours
	if _line_up_ticks < LINE_UP_PATIENCE and (_spot_piece() != null or _desk_spot() or _desk_lead()):
		return false                    # a table up beside him: him through it first
	var down := target.fsm.current_state == WrestlerFSM.State.DOWN
	_weapon_roll = int(WEAPON_ROLL_TICKS / (WEAPON_ROLL_DOWN_SCALE if down else 1.0))
	if ladder_due():
		return true
	return _weapon_rng().randf() < (WEAPON_CHANCE_HEEL if _is_heel() else WEAPON_CHANCE)


## Outside the ropes on the side of the ring nearest him.
func _nearest_apron_out() -> Vector3:
	var p := controller.global_position
	var axis := Vector3(signf(p.x), 0.0, 0.0) if absf(p.x) >= absf(p.z) else Vector3(0.0, 0.0, signf(p.z))
	if axis == Vector3.ZERO:
		axis = Vector3.RIGHT
	return p + axis * 3.0


## Where he kneels to reach under: at the apron on his side, inside the lane,
## and clear of any spot another man has already claimed.
func _apron_spot() -> Vector3:
	var p := Vector3(controller.global_position.x, 0.0, controller.global_position.z)
	var axis := GrappleRig._outside_side(p)
	var lat := Vector3(absf(axis.z), 0.0, absf(axis.x))
	var half := WrestlerController.RUMMAGE_LANE - 0.4
	var desired := clampf(p.dot(lat), -half, half)
	var lane := WrestlerController.nearest_free_apron_lane(axis, lat, desired, half, controller)
	return axis * (WrestlerController.DECK_KEEP_OUT + WrestlerController.RUMMAGE_REACH * 0.5) + lat * lane


func _start_use() -> void:
	_weapon_plan = WeaponPlan.USE
	_weapon_ticks = 0
	_weapon_swings = 0
	if controller.held_weapon:
		var id := controller.held_weapon.def.id
		used_weapons[id] = int(used_weapons.get(id, 0)) + 1
	_throw_rolled = false
	var rng := _weapon_rng()
	var from_stage := ArenaBuilder.in_entrance_way(controller.global_position)
	_use_in_ring = controller.outside_ring and rng.randf() \
			< (IN_RING_USE_FROM_STAGE if from_stage else IN_RING_USE)
	# The ladder always goes in: its dive is off the top in the ring
	# (WrestlerController.can_start_ladder_aerial), and set up on the floor
	# it was only ever swung (the owner, 2 Nov: "I never saw the ladder used
	# or being climbed or jumped off of").
	if controller.held_weapon and controller.held_weapon.def.id == &"ladder" \
			and controller.outside_ring:
		_use_in_ring = true
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
	# A ladder with the other man still up is swung at him first: set down
	# beside a standing man it went down flat like a table, and a flat
	# ladder is never climbed (the owner, 2 Nov: "I never saw the ladder ...
	# climbed or jumped off of"). Once he is down it is stood up by him.
	# The Ladder match: in the ring, stood up under the belt -- with the
	# other man down or out of the way; swung at him if he is on top of him.
	if def.id == &"ladder" and MatchRules.prize_hangs(controller) and not controller.outside_ring \
			and (target.fsm.current_state == WrestlerFSM.State.DOWN or distance > 2.5):
		var under := _flat(HangingPrize.AT - controller.global_position)
		if under.length() > 1.2:
			input["move"] = Vector2(under.normalized().x, under.normalized().z)
			return input
		input["move"] = Vector2.ZERO
		input["grapple"] = true
		input["set_ladder_upright"] = true
		_weapon_plan = WeaponPlan.NONE
		return input
	var ladder_first := def.id == &"ladder" and target.fsm.current_state != WrestlerFSM.State.DOWN \
			and not controller.outside_ring
	if def.set_up != "" and def.set_piece and not target.is_crossing_ropes() and not ladder_first:
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
## Or, the other man nearer the table than that, stand past him with the
## table ahead and powerbomb him through it (POWERBOMB_DROP). While the other
## man is down or getting up he waits on that spot. {} when there is no
## table, or nothing to do about it this tick.
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
	# A ladder stood up in the ring with the other man down beside it: up it,
	# for the dive off the top (WrestlerController.begin_ladder_aerial). Set
	# up beside him and left, nobody ever climbed it.
	var ladder := _ladder_to_climb()
	if ladder:
		if controller.climbable_ladder_nearby() == ladder:
			input["move"] = Vector2.ZERO
			input["climb_ladder"] = true
			ladder_climbs += 1
			return input
		var to_ladder := _flat(ladder.global_position - controller.global_position)
		input["move"] = Vector2(to_ladder.normalized().x, to_ladder.normalized().z)
		return input
	var suplex := _suplex()
	if suplex == null:
		return {}
	# Where he is to come down, and on what: a set piece stood up beside them,
	# or the announce desk.
	var piece := _spot_piece()
	var at := Vector3.INF
	var kind := &""
	if piece:
		at = piece.global_position
		kind = piece.def.id
	elif _desk_spot():
		at = desk_landing(target.global_position)
		kind = &"desk"
	elif _desk_lead():
		# Not near it yet: take the fight there, round the ring, and the
		# other man comes after him.
		_desk_lead_ticks += 1
		var goal := desk_landing(controller.global_position) + Vector3(0.0, 0.0, -DESK_LEAD_OUT)
		input["move"] = _outside_opponent_move(goal)
		input["run"] = _flat(goal - controller.global_position).length() > RUN_TO_FROM
		return input
	else:
		_line_up_ticks = 0
		return {}
	_line_up_ticks += 1
	# A ladder uses a distinct MoveDef for its damage/recovery tuning while
	# reusing the proven paired suplex lift and root arc. Its landing response
	# is ladder-specific in ImpactSell.
	# A heel with a table up and the other man down sometimes sets it alight
	# first (the owner, 19 Oct: "the flaming table"): to its side, and a
	# taunt there lights it (WrestlerController.begin_light). Rolled once a
	# table.
	if piece and piece.can_set_ablaze() and rising and _wants_to_light(piece):
		var side := piece.global_position + _flat(controller.global_position - piece.global_position).normalized() \
				* LIGHT_FROM
		var to_side := _flat(side - controller.global_position)
		if to_side.length() > 0.25 and controller.table_to_light() != piece:
			input["move"] = Vector2(to_side.normalized().x, to_side.normalized().z)
			return input
		input["move"] = Vector2.ZERO
		input["taunt"] = true
		return input
	# Laid out on it, for the dive off the top through him (the owner, 1 Nov:
	# "lay him on the table, then dive off the top rope through him"): a man
	# with a dive off the top, and the table up in the ring where a corner
	# suits a dive onto a man lying on it. Rolled once a table.
	if kind == &"table" and _wants_table_lay(piece):
		return _table_lay_input(input, piece, to_target, distance, rising)
	var spot_move := suplex
	if kind == &"ladder":
		spot_move = load("res://resources/moves/weapon_ladder_slam.tres") as MoveDef
		if spot_move == null:
			return {}
	var out := _flat(target.global_position - at)
	if out.length() < 0.05:
		return {}
	# Up beside a table -- nearer it than he would stand for the suplex -- the
	# other man goes through it the other way: powerbombed, the table in front
	# of the man throwing it and the other man between them (the owner:
	# "powerbomb through"). Both spots are on the line from the table out to
	# him; which side of the thrower he is on picks the move. The announce
	# desk the same.
	var bomb: MoveDef = null
	if kind in [&"table", &"desk"] and out.length() < SUPLEX_DROP:
		bomb = _table_powerbomb()
	if bomb:
		spot_move = bomb
	var spot := at + out.normalized() * (POWERBOMB_DROP if bomb else SUPLEX_DROP)
	if not controller.outside_ring:
		spot.x = clampf(spot.x, -WrestlerController.RING_KEEP_IN, WrestlerController.RING_KEEP_IN)
		spot.z = clampf(spot.z, -WrestlerController.RING_KEEP_IN, WrestlerController.RING_KEEP_IN)
	var to_spot := _flat(spot - controller.global_position)
	if to_spot.length() <= LINE_UP_THERE:
		if rising:
			input["move"] = Vector2.ZERO  # waiting for him, not covering him
			return input
		var facing := _flat(controller.global_position - at).normalized()
		if bomb:
			facing = -facing        # the table ahead of him, past the other man
		if distance <= tie_up_range and to_target.normalized().dot(facing) >= cos(deg_to_rad(LINE_UP_CONE_DEG)):
			# him in front, the table at his back (the suplex) or past him (the
			# powerbomb): lock up for it
			input["move"] = Vector2(to_target.x, to_target.z).normalized() * 0.05
			input["grapple"] = true
			controller.tie_up_rung_cap = CombatSystem.Tier.POWER if bomb else CombatSystem.Tier.GRAPPLE
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


## A set piece standing within LINE_UP_FROM of both men, to put the other man
## through or onto, or null.
func _spot_piece() -> WeaponActor:
	var stock := controller.get_parent().get_node_or_null("WeaponStock") as WeaponStock \
			if controller.get_parent() else null
	if stock == null:
		return null
	for a in stock.set_up_pieces():
		if a.def.set_piece and a.def.landing_damage > 0.0 \
				and _flat(a.global_position - target.global_position).length() <= LINE_UP_FROM \
				and _flat(a.global_position - controller.global_position).length() <= LINE_UP_FROM:
			return a
	return null


## The announce desk as a spot (the owner: "announce table ... powerbomb
## through, smash and flatten"): both men out on the floor by it, the desk
## still standing, and this man the sort to do it -- rolled once a match,
## DESK_CHANCE_HEEL / DESK_CHANCE. The fight is all round the ring; the desk
## is on one side of it, so this is a spot for when the fight comes by.
const DESK_FROM := 4.0
const DESK_CHANCE_HEEL := 0.8
const DESK_CHANCE := 0.45
## The landing aimed along the desk no further than this from its middle
## (the wreck's break slides at most VenueDamage.DESK_BREAK_SHIFT).
const DESK_AIM_X := 0.8
var _desk_roll := -1


## Taking the fight to the desk (the owner, 2 Nov, AI vs AI: "they never did
## an announce table spot"): it came on only when the fight happened by, and
## the floor fight is all round the ring. Both out on the floor, the desk
## standing and his roll for it made, he heads there from wherever they are
## -- for DESK_LEAD_TICKS at most, so a spot that never comes together does
## not hold up the match -- and within DESK_FROM it is _desk_spot's.
const DESK_LEAD_TICKS := 900
## He heads for this far out in front of the desk, in its bay.
const DESK_LEAD_OUT := 2.0
var _desk_lead_ticks := 0


func _desk_lead() -> bool:
	if _desk_lead_ticks >= DESK_LEAD_TICKS or not _desk_area_open():
		return false
	return _desk_rolled()


## Both out on the floor (not up the ramp) and the desk still standing.
func _desk_area_open() -> bool:
	if not (controller.outside_ring and target.outside_ring):
		return false
	if ArenaBuilder.in_entrance_way(controller.global_position) or ArenaBuilder.in_entrance_way(target.global_position):
		return false
	var stock := controller.get_parent().get_node_or_null("WeaponStock") as WeaponStock \
			if controller.get_parent() else null
	return stock != null and not stock.desk_broken


## His once-a-match roll for the desk spot.
func _desk_rolled() -> bool:
	if _desk_roll < 0:
		_desk_roll = 1 if _weapon_rng().randf() < (DESK_CHANCE_HEEL if _is_heel() else DESK_CHANCE) else 0
	return _desk_roll == 1


func _desk_spot() -> bool:
	if not _desk_area_open():
		return false
	var landing := desk_landing(target.global_position)
	if _flat(landing - target.global_position).length() > DESK_FROM \
			or _flat(landing - controller.global_position).length() > DESK_FROM:
		return false
	return _desk_rolled()


## A ladder stood up on the safe part of the mat with the other man down in
## reach of its landing side, or null (can_start_ladder_aerial's terms).
func _ladder_to_climb() -> WeaponActor:
	if ladder_climbs >= LADDER_CLIMBS_MAX or controller.outside_ring or target.outside_ring or controller.has_weapon() \
			or target.fsm.current_state != WrestlerFSM.State.DOWN:
		return null
	var stock := controller.get_parent().get_node_or_null("WeaponStock") as WeaponStock \
			if controller.get_parent() else null
	if stock == null:
		return null
	var keep := WrestlerController.RING_KEEP_IN - 0.75
	for a in stock.set_up_pieces():
		if a.def.id != &"ladder" or not a.is_climbable_ladder():
			continue
		if absf(a.global_position.x) > keep or absf(a.global_position.z) > keep:
			continue
		if _flat(target.global_position - a.global_position).length() <= WrestlerController.LADDER_AERIAL_REACH:
			return a
	return null


## Where on the desk a man by `near` is put down: its middle line, as near
## along it as DESK_AIM_X lets.
static func desk_landing(near: Vector3) -> Vector3:
	return Vector3(clampf(near.x, ArenaBuilder.DESK_X - DESK_AIM_X, ArenaBuilder.DESK_X + DESK_AIM_X),
			ArenaBuilder.FLOOR_Y, ArenaBuilder.DESK_Z)


## With a set piece up beside them he works the spot rather than going off
## for another weapon (nhb_weapon_probe seed 2: Roman set a table up and was
## away under the ring a second later) -- for this long, then as before, so a
## spot that never comes together does not hold up the match.
const LINE_UP_PATIENCE := 1200
var _line_up_ticks := 0


## How often a heel lights a table he has up, and how far from it he stands
## to do it.
const LIGHT_CHANCE := 0.6
const LIGHT_FROM := 1.1
## Tables rolled for lighting: instance id -> lights it.
var _light_rolls := {}


func _wants_to_light(table: WeaponActor) -> bool:
	if not _is_heel():
		return false
	var id := table.get_instance_id()
	if not _light_rolls.has(id):
		_light_rolls[id] = _weapon_rng().randf() < LIGHT_CHANCE
	return bool(_light_rolls[id])


## The table dive's lay (GrappleRig.TABLE_LAY, TopRopeSpot's table): how often
## a man with a dive off the top takes it, a table up where it suits.
const TABLE_LAY_MOVE := "res://resources/moves/table_lay.tres"
const TABLE_LAY_CHANCE := 0.7
## Tables rolled for the lay: instance id -> lays him on it.
var _lay_rolls := {}


func _wants_table_lay(table: WeaponActor) -> bool:
	if controller.outside_ring or target.outside_ring or controller.top_rope_move == null \
			or controller._top_rope_used or controller.grapple_rig == null:
		return false
	if absf(table.global_position.x) > WrestlerController.RING_KEEP_IN \
			or absf(table.global_position.z) > WrestlerController.RING_KEEP_IN:
		return false
	var lay := load(TABLE_LAY_MOVE) as MoveDef
	if lay == null or TopRopeSpot.pick_corner(_laid_on(table, lay)).is_empty():
		return false
	var id := table.get_instance_id()
	if not _lay_rolls.has(id):
		_lay_rolls[id] = _weapon_rng().randf() < TABLE_LAY_CHANCE
	return bool(_lay_rolls[id])


## The pair frame the lay would play in on `table`, as GrappleRig stands it.
func _lay_frame(table: WeaponActor, lay: MoveDef) -> Transform3D:
	return GrappleRig.table_lay_frame(table, controller.grapple_rig.role_end_xz(lay, false),
			controller.global_position, target.global_position)


## Where the man would lie on `table` once laid on it: his root, facing along
## it, head first (the lay's last defender key).
func _laid_on(table: WeaponActor, lay: MoveDef) -> Transform3D:
	var frame := _lay_frame(table, lay)
	var end := controller.grapple_rig.role_end_xz(lay, false)
	return Transform3D(frame.basis * Basis(Vector3.UP, -PI * 0.5), frame * Vector3(end.x, 0.0, end.y))


## To where the lay starts -- beside the table's long side, the other man
## along it from him -- and lock up there for it.
func _table_lay_input(input: Dictionary, table: WeaponActor, to_target: Vector3,
		distance: float, rising: bool) -> Dictionary:
	var lay := load(TABLE_LAY_MOVE) as MoveDef
	var spot := _lay_frame(table, lay) * Vector3(0.40, 0.0, 0.0)
	var to_spot := _flat(spot - controller.global_position)
	if to_spot.length() <= LINE_UP_THERE:
		if rising:
			input["move"] = Vector2.ZERO      # waiting for him, not covering him
			return input
		if distance <= tie_up_range:
			input["move"] = Vector2(to_target.x, to_target.z).normalized() * 0.05
			input["grapple"] = true
			controller.tie_up_rung_cap = CombatSystem.Tier.POWER
			controller.prefer_hold_move = lay
			return input
		input["move"] = Vector2(to_target.x, to_target.z).normalized() * 0.05 if distance > 0.01 else Vector2.ZERO
		return input
	# round him, not through him
	var dir := to_spot.normalized()
	if to_target.length() > 0.001 and dir.dot(to_target.normalized()) > 0.3 and distance < to_spot.length():
		dir = (dir + Vector3.UP.cross(to_target.normalized()) * 0.9).normalized()
	input["move"] = Vector2(dir.x, dir.z)
	return input


## His powerbomb to put a man through a table: his own if it is one measured
## onto a table (TABLE_POWERBOMBS -- Roman's, Cody's sit-out), else the plain
## one. (Kenny's comes with a knee after it, which a man through a table is
## past taking.)
func _table_powerbomb() -> MoveDef:
	for m: MoveDef in [controller.power_move] + controller.power_move_pool:
		if m and TABLE_POWERBOMBS.has(m.animation_pair_id):
			return m
	return load(TABLE_POWERBOMB) as MoveDef


## His vertical suplex, or null.
func _suplex() -> MoveDef:
	for m: MoveDef in [controller.grapple_move] + controller.grapple_move_pool:
		if m and String(m.animation_pair_id).contains("vertical_suplex"):
			return m
	return null


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- The chase on the floor -------------------------------------------------
## Both men out, on their feet and close: the one getting the worse of it
## breaks away and runs (FLEE_CHANCE a roll, once per FLEE_COOLDOWN), along
## the ringside lane, his back to the other man; the other runs him down and,
## once he is close behind him, stops and hits him from behind.
const FLEE_FROM := 3.2
const FLEE_CHANCE := 0.35
const FLEE_TICKS := Vector2i(90, 180)
const FLEE_COOLDOWN := 480
const CATCH_RANGE := 1.3
const FLEE_PACE := 0.8
var _flee_ticks := 0
var _flee_cooldown := 0
var _flee_sign := 1.0
## Times he broke away and ran (nhb_weapon_probe).
var flee_starts := 0


## Running from the other man right now (the chaser reads it).
func is_fleeing() -> bool:
	return _flee_ticks > 0


func _floor_chase_input(input: Dictionary, to_target: Vector3, distance: float) -> Dictionary:
	if _flee_cooldown > 0:
		_flee_cooldown -= 1
	var free := [WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN]
	var out := controller.outside_ring and target.outside_ring \
			and not ArenaBuilder.in_entrance_way(controller.global_position) \
			and not controller.has_weapon() and _weapon_plan == WeaponPlan.NONE
	if not out or not controller.fsm.is_in(free):
		_flee_ticks = 0
		return {}
	# Running for it.
	if _flee_ticks > 0:
		_flee_ticks -= 1
		if _flee_ticks == 0:
			_flee_cooldown = FLEE_COOLDOWN
		var me := controller.global_position
		var side := GrappleRig._outside_side(me)
		var along := Vector3.UP.cross(side).normalized() * _flee_sign
		# a hurt man's run: the other man gains on him
		input["move"] = _ringside_move(me, me + along * 4.0) * FLEE_PACE
		input["run"] = true
		return input
	# Chasing him.
	var other: WrestlerAI = target.ai
	if other and other.is_fleeing():
		if distance > CATCH_RANGE:
			var dir := _outside_opponent_move(target.global_position)
			input["move"] = dir
			input["run"] = true
			return input
		# Caught him: stop, and hit him from behind (a strike pressed mid-run
		# is a running attack, so off the run first).
		input["move"] = Vector2.ZERO
		input["strike"] = controller.fsm.current_state != WrestlerFSM.State.RUN
		return input
	# Breaking away: the man getting the worse of it, close, both standing.
	if _flee_cooldown == 0 and distance < FLEE_FROM and target.fsm.is_in(free) \
			and controller.combat.health() < target.combat.health() - 0.05:
		_flee_cooldown = FLEE_COOLDOWN / 4
		var rng := _chain_rng()
		if rng.randf() < FLEE_CHANCE:
			_flee_ticks = rng.randi_range(FLEE_TICKS.x, FLEE_TICKS.y)
			flee_starts += 1
			# away from him along the lane
			var me := controller.global_position
			var along := Vector3.UP.cross(GrappleRig._outside_side(me)).normalized()
			_flee_sign = -1.0 if along.dot(target.global_position - me) > 0.0 else 1.0
	return {}
