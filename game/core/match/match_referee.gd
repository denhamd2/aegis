class_name MatchReferee
extends Node
## Drives pin resolution and declares the win condition. Grey-box version
## of the "ref" system: watches for a downed wrestler being covered, runs
## the deterministic kickout minigame, and ends the match on a three-count.
##
## A match ends on a pinfall. The submission path (_tick_submission and
## friends below) is still wired and still tested, but nothing starts one
## any more -- see _check_for_downed_opponent_action().

signal match_won(winner: WrestlerController, method: String)
## A pin or a hold broken because the man under it got to the ropes.
signal rope_break(defender: WrestlerController, was_pin: bool)

## Rope breaks (gauntlet/refs/animation_gap.md, Phase 4: position). A man
## pinned or held within reach of the ropes gets to them, and the count or the
## hold is broken -- unless it is a finisher he is under, which is the point of
## a finisher. Whether he can reach them is decided as the cover or the hold
## starts (WrestlerController.rope_within_reach()), off where he lies.
##
## Pinned: a man lying where he can reach the ropes gets a hand or foot on
## them at once -- he starts reaching as the cover starts, and the referee
## stops the count the moment he touches (ROPE_REACH_TICKS later), before the
## first slap, not after a two-count. A kickout before that still ends it first.
const ROPE_REACH_START_TICK := 36
const ROPE_REACH_TICKS := 24
## Held: he fights the hold this long before he stretches for the rope.
const SUBMISSION_ROPE_REACH_AFTER := 60

## Tick each hand-slap lands on, measured rather than divided evenly.
##
## gauntlet/refs/timings.md frame-stepped a real three-count at native 30fps
## with no sampling gaps (Byron Breakker vs Oba Femi, ~1093s): "1" to "2" is
## ~1.25s and "2" to "3" ~1.00s. A real count is *uneven* -- the referee
## hangs on the first slap and speeds up into the third -- and this was an
## even 1.00s apart, which is the one thing the reference says it is not.
##
## The lead-in from the cover to "1" is measured now too, by walking the
## same pinfall backwards to the cover (timings.md, "Cover -> count '1'"):
## 3.60s in the footage, of which ~2.07s is the referee walking across the
## ring. There is no referee actor here -- a cover in this project starts
## at what the footage calls "referee in position" -- so the comparable
## half is the ~1.53s from there to the first slap, i.e. 92 ticks. It was
## 60, so the count used to start about half a second early.
const COUNT_TICKS: Array[int] = [92, 167, 227]
const PIN_COUNT_TICKS := 227
## Only a finisher wins (the owner: "a wrestler can only finish the match
## using their finisher -- the Spear or the Cross Rhodes"). A cover off
## anything else is a near-fall: he gets a shoulder up this many ticks before
## the third slap, the "2.9" a crowd comes out of its seats for.
const NEAR_FALL_KICKOUT_TICK := 219

## How long each digit stays on screen, also frame-stepped: "1" is visible
## ~0.63-0.67s and "2" ~0.37-0.43s, with a silent gap of ~0.55s before the
## next one pops in. So the count is not a number that sits there changing
## -- it flashes, goes away, and comes back, which is most of what makes a
## three-count tense to watch.
const COUNT_VISIBLE_TICKS: Array[int] = [39, 24, 999]
const COVER_RANGE := 1.2

## A cover is legal only with both men inside the ropes: the pinned man's hips,
## torso, shoulders and head, and the man covering him. Lying with his head
## under the bottom rope, over the apron or out on the floor, he is not covered
## (the referee does not count it) -- the man who put him there has to drag him
## to the middle. Points are in the pinned man's own frame (his head up -Z, the
## same frame WrestlerController.ROPE_REACH_POINTS is measured in).
const COVER_ROPES := 2.98
const COVER_BODY_POINTS: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0),                       # hips
	Vector3(0.0, 0.0, -0.55),                     # torso
	Vector3(0.28, 0.0, -0.8), Vector3(-0.28, 0.0, -0.8),   # shoulders
	Vector3(0.0, 0.0, -1.05),                     # head
]
## Lying lower than this he is on the floor outside, not on the mat.
const COVER_MAT_FLOOR := -0.3


## How fast a man is dragged to the middle for a legal cover, metres a second,
## and how many times one has been (for the probes).
const DRAG_SPEED := 1.3
var drags := 0


## One tick of dragging `defender` toward the middle of the ring.
func _drag_toward_centre(defender: WrestlerController) -> void:
	var to_centre := Vector3(-defender.global_position.x, 0.0, -defender.global_position.z)
	if to_centre.length() < 0.05:
		return
	drags += 1
	defender.global_position += to_centre.normalized() \
			* minf(DRAG_SPEED * get_physics_process_delta_time(), to_centre.length())


## Whether a cover of a man lying at `defender` by a man at `attacker` can be
## counted. Static and position-only, so the AI, the human and the tests all
## ask the same question.
static func cover_is_legal(attacker: Vector3, defender: Transform3D) -> bool:
	if absf(attacker.x) > COVER_ROPES or absf(attacker.z) > COVER_ROPES:
		return false
	if defender.origin.y < COVER_MAT_FLOOR:
		return false
	for p in COVER_BODY_POINTS:
		var q := defender * p
		if absf(q.x) > COVER_ROPES or absf(q.z) > COVER_ROPES:
			return false
	return true
## Absolute safety cap on a tie-up contest, not the primary mechanism (see
## _tick_tie_up()) — TieUpMinigame.PROGRESS_THRESHOLD is what actually
## decides it in practice.
const TIE_UP_MAX_TICKS := 200

@export var wrestler_a_path: NodePath
@export var wrestler_b_path: NodePath
@export var match_seed: int = 0

var wrestler_a: WrestlerController
var wrestler_b: WrestlerController

var _pin_ticks: int = 0
## Which count is on screen; see pin_count().
var _pin_count_shown: int = 0
var _pinning: bool = false
var _pin_attacker: WrestlerController
var _pin_defender: WrestlerController
## Counts submission dead heats so successive ones can differ; seed input
## only. Was _finish_choices, which also counted the referee's pin-versus-
## submission decisions -- those are gone (every finish is a cover now), so
## this counts the one thing left that needs a varying seed.
var _submission_ties: int = 0
var _submissioning: bool = false
var _submission_attacker: WrestlerController
var _submission_defender: WrestlerController
var _tying_up: bool = false
var _tie_up_ticks: int = 0
var _tie_up_minigame: TieUpMinigame
var _match_over: bool = false
## The rope side the man under the current pin or hold can reach, or ZERO.
var _rope_side := Vector3.ZERO
var _submission_fight_ticks := 0
## Rope breaks this match, pins and holds together (probes, tests).
var rope_breaks := 0
## Each man's finisher window: wrestler -> the finisher that put him down,
## while a cover off it can still win. Opened when the finisher lands, and
## shut by anything else -- any other damage, by any path (CombatSystem.
## damaged: a tope or a chain hold used to slip past, and Cody pinned a man
## off a dive after a kicked-out Cross Rhodes), getting back to his feet,
## or kicking out of the cover. So the match only ever ends on a cover that
## follows the finisher.
var _finished := {}
## Covers kicked out of because they were not off a finisher.
var near_falls := 0

func _ready() -> void:
	wrestler_a = get_node(wrestler_a_path)
	wrestler_b = get_node(wrestler_b_path)
	for w: WrestlerController in [wrestler_a, wrestler_b]:
		w.move_landed.connect(_on_move_landed)
		w.fsm.state_changed.connect(_on_state_changed.bind(w))
		w.combat.damaged.connect(_on_damaged.bind(w))


func _on_move_landed(attacker: WrestlerController, defender: WrestlerController,
		move: MoveDef) -> void:
	if not defender:
		return
	# A finisher ends the match only once the story has got there (MatchFlow);
	# before that the cover is a near-fall, kicked out of at two and nine tenths.
	if attacker.is_finisher(move):
		attacker.combat.spend_finisher()
	if attacker.is_finisher(move) and (attacker.flow == null or attacker.flow.finish_allowed()):
		_finished[defender] = move
	else:
		_finished.erase(defender)


## Damage that is not the finisher itself shuts the window.
func _on_damaged(move: MoveDef, w: WrestlerController) -> void:
	if _finished.get(w) != move:
		_finished.erase(w)


## Back on his feet: the finisher has worn off.
func _on_state_changed(_from: int, to: int, w: WrestlerController) -> void:
	if to == WrestlerFSM.State.IDLE or to == WrestlerFSM.State.LOCOMOTION:
		_finished.erase(w)


## Whether a cover on `defender` can end the match: only straight off the
## pinning man's own finisher.
func can_be_finished(defender: WrestlerController) -> bool:
	return _finished.has(defender)

func _physics_process(_delta: float) -> void:
	if _match_over:
		return
	_resolve_tick()
	# Closes the tick for the replay. This is the one place in the frame
	# where every wrestler has already read its input for tick N (they run
	# earlier in the scene tree; that ordering is load-bearing enough to
	# have its own doc comment on _try_start_tie_up()), so it is the only
	# correct place to move the counter to N+1.
	#
	# Nothing called this before, anywhere, so ReplaySystem.current_tick sat
	# at 0 for entire matches: a recording overwrote frame 0 thousands of
	# times and kept only the last tick's input, and playback fed that one
	# frame to every tick of the match. The replay system has never actually
	# recorded or replayed a match, despite ARCHITECTURE.md making
	# same-seed-same-replay a hard requirement.
	#
	# Gameplay is untouched by this: in LIVE and RECORDING mode
	# ReplaySystem.get_input() returns the live input regardless of
	# current_tick. Only the recorded data changes -- from wrong to right.
	if ReplaySystem:
		ReplaySystem.advance_tick()

## The tick's actual decisions, split out from _physics_process so its
## several early returns can't skip closing the tick above.
func _resolve_tick() -> void:
	# MatchReferee runs after both wrestlers in the scene tree, so this is
	# the single point each tick where queued hits (see
	# WrestlerController._pending_hits) are resolved — after every
	# wrestler has made its own decision for the tick, symmetrically,
	# regardless of node order.
	wrestler_a._resolve_pending_hits()
	wrestler_b._resolve_pending_hits()
	_update_comebacks()

	if _pinning:
		_tick_pin()
		return
	if _submissioning:
		_tick_submission()
		return
	if _tying_up:
		_tick_tie_up()
		return
	if _try_start_tie_up():
		return
	_check_for_downed_opponent_action()

## Starts a tie-up once either wrestler pressed grapple this tick (captured
## by WrestlerController._wants_tie_up_this_tick — see its doc comment for
## why entry lives here rather than inline in the wrestler, mirroring
## PIN_DEFENDER/SUBMISSION_DEFENDER's "driven by MatchReferee" pattern: this
## runs strictly after both wrestlers' own _physics_process for the tick, so
## neither side gets a scene-tree-order head start on the mash contest that
## follows. Also the sole gate against an illegal TIE_UP transition (only
## legal from IDLE/LOCOMOTION per WrestlerFSM.LEGAL_TRANSITIONS) — checked
## for both wrestlers before touching either FSM, same protection the old
## inline version had.
func _try_start_tie_up() -> bool:
	if not (wrestler_a._wants_tie_up_this_tick or wrestler_b._wants_tie_up_this_tick):
		return false
	if wrestler_a.global_position.distance_to(wrestler_b.global_position) > WrestlerController.TIE_UP_RANGE:
		return false
	if not WrestlerController.CAN_ENTER_TIE_UP.has(wrestler_a.fsm.current_state) \
			or not WrestlerController.CAN_ENTER_TIE_UP.has(wrestler_b.fsm.current_state):
		return false
	wrestler_a.fsm.transition_to(WrestlerFSM.State.TIE_UP)
	wrestler_b.fsm.transition_to(WrestlerFSM.State.TIE_UP)
	_tying_up = true
	_tie_up_ticks = 0
	_tie_up_minigame = TieUpMinigame.new()
	return true

## Why there is no reversal here any more.
##
## A reversal used to cancel an incoming strike and play a paired counter
## animation (reversal_counter.tres and five siblings) with the reverser in
## the attacker role. Those counters were cut along with the power and
## finisher throws -- they did not read on screen, and a counter that does
## not read is a strike that simply vanishes. Nothing replaced the
## mechanic: a strike thrown in this match loop now always resolves, and
## the answer to being struck is to strike back.
##
## MoveDef still carries reversal_window_start/end. Those are measured
## frame numbers, not decoration, so they stay -- but nothing reads them
## today, and a reversal window without a consumer decides nothing.
## Covers a downed opponent. One function, one decision per pair: whoever
## is on his feet and close enough to a downed man goes for the cover.
func _check_for_downed_opponent_action() -> void:
	for pair in [[wrestler_a, wrestler_b], [wrestler_b, wrestler_a]]:
		var attacker: WrestlerController = pair[0]
		var defender: WrestlerController = pair[1]
		# Playing possum (PossumSpot): once a match, the man down sweeps the
		# legs of the one who has come to stand over them.
		if PossumSpot.wants(defender, attacker):
			_start_possum(defender, attacker)
			return
		# Worked before he is covered (Phase 4, position): a stomp or a fist,
		# by where the standing man is -- up to GROUND_ATTACKS_MAX a knockdown,
		# never after a finisher, whose knockdown is the cover.
		if attacker.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION]) \
				and attacker.last_landed_tier < CombatSystem.Tier.FINISHER \
				and attacker.can_ground_attack(defender):
			attacker.begin_ground_attack(defender)
			return
		# Hauled up instead of covered: worked over, not worth a cover, so the
		# man in control picks him up for more.
		if not wants_cover(defender) \
				and attacker.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION]) \
				and attacker.can_pickup(defender):
			attacker.begin_pickup(defender)
			return
		if defender.fsm.current_state == WrestlerFSM.State.DOWN \
				and defender._cover_eligible \
				and wants_cover(defender) \
				and attacker.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION]) \
				and attacker.global_position.distance_to(defender.global_position) <= COVER_RANGE \
				and WrestlerController.is_beside_torso(defender, attacker.global_position):
			# Not countable where he lies (head under the bottom rope, out on
			# the apron): the man covering him drags him toward the middle
			# first, and the cover starts once it is legal.
			if not cover_is_legal(attacker.global_position, defender.global_transform):
				_drag_toward_centre(defender)
				return
			# Every finish is a cover. The submission branch that used to
			# live here is gone from the AI match: a match is meant to end
			# with one wrestler pinning the other, and a seeded coin flip
			# between a pinfall and a tap-out meant most matches ended on
			# the finish nobody asked to watch (measured before this
			# change: 2 of 3 seeds ended by submission).
			#
			# The submission subsystem itself is untouched --
			# SubmissionMinigame, the two SUBMISSION_* states and
			# WrestlerController.begin_submission() all still work, and
			# their tests still cover them. What changed is that the
			# referee no longer reaches for it on a coin flip.
			#
			# The one exception is a man's OWN hold (Cody's Figure-Four,
			# WrestlerController.submission_move): taken once a match, on the
			# first man he has down -- never one a finisher has just put
			# down, who gets the cover. Measured over 8 seeded Roman-vs-Cody
			# matches (tools/probe/moveset_tally.tscn), every cover Cody
			# made followed a signature or a finisher, so a rule that also
			# spared the signature knockdown left the hold in one match in
			# eight. It is a set piece before the finish, not a way to end
			# it: the tap only comes on a leg already past
			# SUBMISSION_ESCAPE_LIMB, and the match goes on to a pinfall.
			# His dives (DiveSpot): once a match, on a man down off the
			# ropes (a knockdown mid-ring takes the hold instead). Gated
			# on the hold first, measured over 8 seeds it never came: the
			# knockdown after the hold is nearly always the finish.
			if _wants_dive(attacker, defender):
				_start_dive(attacker, defender)
				return
			# His moonsault (TopRopeSpot): once a match, on a man down where a
			# corner suits the dive -- after his own hold has had its turn.
			if _wants_top_rope(attacker, defender):
				_start_top_rope(attacker, defender)
				return
			if _wants_own_hold(attacker) \
					and WrestlerController.has_room_for_figure_four(defender):
				_start_own_hold(attacker, defender)
				return
			_pinning = true
			_pin_ticks = 0
			_pin_count_shown = 0
			_pin_attacker = attacker
			_pin_defender = defender
			_rope_side = _reachable_ropes(attacker, defender)
			attacker.begin_pin(defender, _pin_seed())
			return

## Whether a man down is worth covering yet (match flow to 2K26,
## gauntlet/refs/match_engine_2k26.md): 2K26's man in control works a man he
## has put down with strikes -- stomps, a strut -- and covers after the big
## moves. Ours covered every knockdown, so the match was strike, knockdown,
## cover, kickout, over and over. Late in the match (MatchFlow's finish) any
## knockdown is a cover; without a MatchFlow (the bare test scene) every one is.
func wants_cover(defender: WrestlerController) -> bool:
	if defender.knockdown_tier >= CombatSystem.Tier.POWER:
		return true
	if defender.flow == null:
		return true
	return String(defender.flow.phase()["name"]) == "finish"


func _wants_dive(attacker: WrestlerController, defender: WrestlerController) -> bool:
	return not attacker.dive_moves.is_empty() and not attacker._dive_used \
			and attacker.last_landed_tier < CombatSystem.Tier.FINISHER \
			and DiveSpot.near_ropes(defender)

func _start_possum(sweeper: WrestlerController, swept: WrestlerController) -> void:
	sweeper._possum_used = true
	var spot := PossumSpot.new()
	spot.name = "PossumSpot"
	get_parent().add_child(spot)
	spot.begin(sweeper, swept)

func _wants_top_rope(attacker: WrestlerController, defender: WrestlerController) -> bool:
	return attacker.top_rope_move != null and not attacker._top_rope_used \
			and attacker.last_landed_tier < CombatSystem.Tier.FINISHER \
			and (attacker.submission_move == null or attacker._submission_move_used) \
			and TopRopeSpot.can_dive_on(defender)

func _start_top_rope(attacker: WrestlerController, defender: WrestlerController) -> void:
	attacker._top_rope_used = true
	var spot := TopRopeSpot.new()
	spot.name = "TopRopeSpot"
	get_parent().add_child(spot)
	spot.begin(attacker, defender)

func _start_dive(attacker: WrestlerController, defender: WrestlerController) -> void:
	attacker._dive_used = true
	var spot := DiveSpot.new()
	spot.name = "DiveSpot"
	get_parent().add_child(spot)
	spot.begin(attacker, defender)

func _wants_own_hold(attacker: WrestlerController) -> bool:
	return attacker.submission_move != null and not attacker._submission_move_used \
			and attacker.last_landed_tier < CombatSystem.Tier.FINISHER

func _start_own_hold(attacker: WrestlerController, defender: WrestlerController) -> void:
	attacker._submission_move_used = true
	_submissioning = true
	_submission_attacker = attacker
	_submission_defender = defender
	_rope_side = _reachable_ropes(attacker, defender)
	_submission_fight_ticks = 0
	attacker.begin_submission(defender, CombatSystem.Limb.LEGS, attacker.submission_move)


## The rope side `defender` can get to under `attacker`, or ZERO -- never
## under a finisher.
func _reachable_ropes(attacker: WrestlerController, defender: WrestlerController) -> Vector3:
	if attacker.last_landed_tier >= CombatSystem.Tier.FINISHER:
		return Vector3.ZERO
	return WrestlerController.rope_within_reach(defender)


## Ticks the rope reach for a pin or a hold; true once he has the rope.
func _tick_rope_reach(tick: int, start: int) -> bool:
	if _rope_side == Vector3.ZERO or tick < start:
		return false
	var defender := _pin_defender if _pinning else _submission_defender
	if tick == start:
		defender.reach_for_rope(_rope_side, ROPE_REACH_TICKS)
	if tick < start + ROPE_REACH_TICKS:
		return false
	rope_breaks += 1
	rope_break.emit(defender, _pinning)
	return true

## Seed for this pin's kickout minigame. Every pin in a match needs its own
## target window, so the seed has to vary -- but only with match state.
##
## This used to be `match_seed + Engine.get_physics_frames()`, and
## get_physics_frames() is a *process*-global counter, not a per-match one.
## Replay the same recording in a process that reaches the pin at a
## different global frame -- a capture that plays a replay after a menu, or
## simply the second match run in one process -- and the defender gets a
## different kickout window, so the same inputs produce a different match.
## That is precisely the guarantee ARCHITECTURE.md calls a hard requirement,
## and the capture pipeline is built on top of it.
##
## ReplaySystem.current_tick is the same quantity the seed wanted (how far
## into the match this pin is) except that it resets with the match and is
## reproduced exactly by playback.
func _pin_seed() -> int:
	var tick: int = ReplaySystem.current_tick if ReplaySystem else _pin_ticks
	return match_seed + tick

## Read-only views of referee state, for the HUD.
##
## The HUD polls these in _process rather than being pushed to, so it stays
## entirely off the physics tick -- it can never change what a tick does,
## which is the whole reason it is allowed to read gameplay state at all.

## Which hand-slap the referee is on: 0 before the first, up to 3. Digits
## pop in with no fade (gauntlet/refs/hud.md, frame-stepped), so this is a
## plain step function and the HUD needs no easing.
## Latched rather than derived from _pin_ticks, because the third count and
## the end of the pin land on the same tick: _tick_pin() sees 180 ticks,
## declares the pinfall and clears _pinning in one call, so a count computed
## live would blink "3" for zero frames and the winning count -- the one
## moment the number matters most -- would never be on screen. Cleared when
## a new pin starts or the defender kicks out; held afterwards, the way a
## broadcast leaves the count up over the finish.
func pin_count() -> int:
	return _pin_count_shown

func is_pin_active() -> bool:
	return _pinning

func is_submission_active() -> bool:
	return _submissioning

## Both sides of the submission tug-of-war as 0..1 fractions: x is the
## attacker closing on the defender's breaking point, y the defender working
## free. gauntlet/refs/hud.md confirms this as a real on-screen element (a
## centre-bottom red/blue "HOLD" bar) that this project never rendered.
func submission_progress() -> Vector2:
	if not _submissioning or not _submission_defender:
		return Vector2.ZERO
	var minigame: SubmissionMinigame = _submission_defender._submission_minigame
	if not minigame:
		return Vector2.ZERO
	return Vector2(
		minigame.attacker_progress / SubmissionMinigame.BREAK_POINT,
		minigame.defender_progress / SubmissionMinigame.BREAK_POINT)

func _tick_pin() -> void:
	_pin_ticks += 1
	# The finishing stretch: a man who has already kicked out of a finisher
	# since the match was allowed to end has no kickout left in him for the
	# next one (MatchFlow.FINISHER_KICKOUTS_MAX), and the count runs to three.
	var no_kickout_left: bool = can_be_finished(_pin_defender) and _pin_attacker.flow != null \
			and _pin_attacker.flow.no_kickout_left()
	if not no_kickout_left and _pin_defender._pin_minigame \
			and _pin_defender._pin_minigame.tick(_pin_ticks, _pin_defender._kickout_input_this_tick):
		if can_be_finished(_pin_defender) and _pin_attacker.flow != null:
			_pin_attacker.flow.finisher_kickouts += 1
		_end_pin(false)
		return
	if _tick_rope_reach(_pin_ticks, ROPE_REACH_START_TICK):
		_end_pin(false, true)
		return
	_update_count()
	if _pin_ticks >= NEAR_FALL_KICKOUT_TICK and not can_be_finished(_pin_defender):
		near_falls += 1
		_end_pin(false)
		return
	if _pin_ticks >= PIN_COUNT_TICKS:
		_end_pin(true)

## Which digit is on screen this tick, from the measured schedule: a slap
## lands at COUNT_TICKS[i] and its digit is up for COUNT_VISIBLE_TICKS[i],
## then nothing until the next one.
func _update_count() -> void:
	_pin_count_shown = 0
	for i in COUNT_TICKS.size():
		if _pin_ticks < COUNT_TICKS[i]:
			break
		if _pin_ticks < COUNT_TICKS[i] + COUNT_VISIBLE_TICKS[i]:
			_pin_count_shown = i + 1
			break

func _end_pin(three_count_reached: bool, rope := false) -> void:
	_pinning = false
	var double_down := not three_count_reached and not rope \
			and _pin_defender.knockdown_tier >= CombatSystem.Tier.FINISHER
	if not double_down:
		_pin_attacker.fsm.transition_to(WrestlerFSM.State.IDLE)
	if three_count_reached:
		_declare_winner(_pin_attacker, "pinfall")
	else:
		_pin_count_shown = 0
		# Kicked out of: the finisher is spent.
		_finished.erase(_pin_defender)
		_pin_defender.fsm.transition_to(WrestlerFSM.State.DOWN)
		_pin_defender._move_ticks_remaining = WrestlerController.GETUP_TICKS
		# Both men sell a finisher kicked out of: the man who threw it is spent
		# on the mat too, and rises in stages with the man under it.
		if double_down:
			_pin_defender._move_ticks_remaining = WrestlerController.DOUBLE_DOWN_STIR_TICKS
			_pin_attacker._set_state_clip(WrestlerFSM.State.GETUP, "strikes/getup_staged")
			_pin_attacker.fsm.transition_to(WrestlerFSM.State.GETUP)
			_pin_attacker._move_ticks_remaining = WrestlerController.GETUP_STAGED_TICKS
		# The near-fall comeback: he was losing badly, he survived the cover,
		# and he fires up off the mat.
		# Not off a rope break: he did not fight his way out of it.
		if not rope and _pin_defender.combat.earned_kickout_comeback(_pin_attacker.combat):
			_pin_defender.fire_up()
			_pin_defender._move_ticks_remaining = KICKOUT_FIRE_UP_TICKS
		# Not cover-eligible again until this wrestler actually reaches IDLE
		# (DOWN -> GETUP -> IDLE) — otherwise, since the attacker is also
		# reset to IDLE right where it was standing (already in cover
		# range), _check_for_downed_opponent_action() would re-match on the
		# very next tick, forever, with no time for a getup or a fresh hit
		# to ever land.
		_pin_defender._cover_eligible = false

## The comeback clock, and the mid-match comeback -- see CombatSystem's
## comeback section and MATCH_FLOW.md.
##
## Here rather than in each wrestler because both halves compare the two
## men, and this runs once a tick after both have acted and every queued hit
## has landed, in a fixed order -- the same reason the tie-up is arbitrated
## here.
func _update_comebacks() -> void:
	for pair in [[wrestler_a, wrestler_b], [wrestler_b, wrestler_a]]:
		var w: WrestlerController = pair[0]
		var other: WrestlerController = pair[1]
		w.combat.tick_comeback(not w.fsm.is_in(COMEBACK_CLOCK_STOPPED))
		w.combat.tick_recovery()
		# The heat comeback fires as the last hit of the beatdown lands --
		# in the flinch, or on his feet -- never mid-grapple or on the mat.
		if w.combat.earned_comeback(other.combat) and w.fsm.is_in([
				WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION,
				WrestlerFSM.State.HIT_REACT]):
			w.fire_up()

## States the comeback clock does not run in: he is not fighting yet.
const COMEBACK_CLOCK_STOPPED: Array = [
	WrestlerFSM.State.DOWN, WrestlerFSM.State.GETUP,
	WrestlerFSM.State.PIN_ATTACKER, WrestlerFSM.State.PIN_DEFENDER,
	WrestlerFSM.State.TIE_UP, WrestlerFSM.State.GRAPPLE_HOLD,
	WrestlerFSM.State.MOVE_EXEC,
]

## After a kickout that fires him up, the beat he stays down before he is
## up on the fast rise -- stirring, not the full GETUP_TICKS.
const KICKOUT_FIRE_UP_TICKS := 20

## Attacker's side of the race needs no continued input (mirrors
## PIN_ATTACKER's automatic three-count) — only the defender's hold state,
## captured each tick by WrestlerController, matters.
func _tick_submission() -> void:
	# A hold is applied before it is fought: nothing fills until it is locked
	# (WrestlerController.begin_submission's move.startup_frames), and the
	# hold's damage lands on the lock.
	if _submission_attacker._submission_lock_ticks > 0:
		_submission_attacker._submission_lock_ticks -= 1
		if _submission_attacker._submission_lock_ticks == 0 \
				and _submission_attacker._submission_hold_move:
			_submission_defender.combat.apply_damage(
					_submission_attacker._submission_hold_move)
		return
	_submission_fight_ticks += 1
	if _tick_rope_reach(_submission_fight_ticks, SUBMISSION_ROPE_REACH_AFTER):
		_end_submission(false)
		return
	var minigame: SubmissionMinigame = _submission_defender._submission_minigame
	minigame.tick(true, _submission_defender._submission_defender_input_this_tick)
	var tapped := minigame.attacker_wins()
	var escaped := minigame.defender_escapes()
	if tapped and escaped:
		# Both rings break on the same tick. Not hypothetical: the referee
		# only starts a hold in a narrow band of limb damage around
		# WrestlerController.SUBMISSION_ESCAPE_LIMB, where the two rates
		# are close, and a limb sitting exactly on the crossover makes them
		# identical -- 2 of 10 measured seeds landed there. Resolved with
		# an explicit seeded flip for the same reason _tick_tie_up() does:
		# left to the if/elif's ordering, "the attacker wins ties" is a
		# rule nobody chose, hidden in the checking order.
		_end_submission(_break_submission_tie())
	elif tapped:
		_end_submission(true)
	elif escaped:
		_end_submission(false)

## Seeded, like the tie-up's own tie-break: same (match_seed, hold count)
## always resolves the same way, so a replay reproduces it, but successive
## dead heats in a match and across seeds do not all go one way.
func _break_submission_tie() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed * 6143 + _submission_ties * 41
	_submission_ties += 1
	return rng.randi_range(0, 1) == 0

func _end_submission(tapped_out: bool) -> void:
	# Only a finisher wins (the owner: "they should always only win by their
	# finisher, eg Cross Rhodes or Spear"), and no man's finisher is a hold.
	# A hold that would have made him tap is fought to the last moment and
	# survived: he gets free, worn, and the match goes on to the finish.
	if tapped_out and not is_finisher_hold(_submission_attacker):
		tapped_out = false
	_submissioning = false
	if _submission_attacker._submission_hold_move and not tapped_out:
		# Worked from flat on his back: he gets up, he does not pop upright.
		_submission_attacker.release_submission_hold()
	else:
		_submission_attacker._submission_hold_move = null
		_submission_attacker.fsm.transition_to(WrestlerFSM.State.IDLE)
	if tapped_out:
		_declare_winner(_submission_attacker, "submission")
	else:
		_submission_defender.fsm.transition_to(WrestlerFSM.State.DOWN)
		_submission_defender._move_ticks_remaining = WrestlerController.GETUP_TICKS
		# Same re-cover-exploit protection proven for kickouts (see _end_pin)
		# — an escaped submission must not instantly re-trigger a new
		# pin/submission on the very next tick either.
		_submission_defender._cover_eligible = false

## Whether the hold this man has on is his finisher -- the only hold that
## may end a match. None is today (Cross Rhodes and the Spear are both
## paired moves), so every tap is survived.
func is_finisher_hold(attacker: WrestlerController) -> bool:
	return attacker != null and attacker._submission_hold_move != null \
			and attacker.is_finisher(attacker._submission_hold_move)

## Both sides mash "grapple" (captured per-tick by WrestlerController);
## whoever accumulates more qualifying presses first becomes the grapple
## attacker. Unlike pin/submission there's no pre-existing attacker/defender
## role here — the contest itself decides it.
func _tick_tie_up() -> void:
	_tie_up_ticks += 1
	_tie_up_minigame.tick(wrestler_a._tie_up_input_this_tick, wrestler_b._tie_up_input_this_tick,
			_tie_up_weight(wrestler_a, wrestler_b), _tie_up_weight(wrestler_b, wrestler_a))
	var a_won := _tie_up_minigame.a_wins()
	var b_won := _tie_up_minigame.b_wins()
	if a_won and b_won:
		# Both sides crossed PROGRESS_THRESHOLD on the exact same tick — now
		# a real, reachable case (not just a hypothetical) once entry-order
		# bias is fixed and two AI opponents mash on genuinely equal
		# footing (see _try_start_tie_up()'s doc comment and
		# WrestlerAI.setup_jitter(), which makes an exact tie rare but not
		# impossible). Resolved with an explicit, seeded coin flip rather
		# than silently falling out of an if/elif's checking order — that
		# was the original bug's own shape (the old placeholder's "lower
		# player_index wins" rule), just relocated, not fixed, if left
		# implicit here too.
		var winner := _break_tie_up_tie()
		_resolve_tie_up(winner, wrestler_b if winner == wrestler_a else wrestler_a)
	elif a_won:
		_resolve_tie_up(wrestler_a, wrestler_b)
	elif b_won:
		_resolve_tie_up(wrestler_b, wrestler_a)
	elif _tie_up_ticks >= TIE_UP_MAX_TICKS:
		# Backstop only — distinct AI/press policies make an exact tie
		# between two independent deterministic mash rates unlikely, but
		# this guarantees the match can't stall here forever.
		var attacker := wrestler_a if _tie_up_minigame.a_progress >= _tie_up_minigame.b_progress else wrestler_b
		_resolve_tie_up(attacker, wrestler_b if attacker == wrestler_a else wrestler_a)

## What one of w's tie-up presses is worth: nothing, against a man in the
## middle of his comeback, when w is not in one himself.
##
## A fired-up man drives through the lock-up. The comeback has to be able to
## end in his big move, and every big move starts here. It was a doubled
## press first, and measured that lost anyway: the AI's mash rates are rolled
## per tie-up and differ by up to three to one, so a man who fired up still
## lost the lock-up straight after, and the leader threw his signature into
## the middle of the comeback. The contest still runs, at the fired-up man's
## own pace, so the lock-up is seen rather than skipped.
func _tie_up_weight(w: WrestlerController, other: WrestlerController) -> float:
	return 0.0 if other.combat.is_fired_up() and not w.combat.is_fired_up() else 1.0

## Seeded, not random-random: same (match_seed, _tie_up_ticks) pair always
## picks the same winner (ReplaySystem determinism), but varies across
## matches/seeds and across repeated ties within one match, unlike a bare
## "lower index wins" rule.
func _break_tie_up_tie() -> WrestlerController:
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed * 4096 + _tie_up_ticks
	return wrestler_a if rng.randi_range(0, 1) == 0 else wrestler_b

func _resolve_tie_up(attacker: WrestlerController, defender: WrestlerController) -> void:
	_tying_up = false
	attacker._is_grapple_attacker = true
	defender._is_grapple_attacker = false
	attacker.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	defender.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)

func _declare_winner(winner: WrestlerController, method: String) -> void:
	_match_over = true
	match_won.emit(winner, method)
