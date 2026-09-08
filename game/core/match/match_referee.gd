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

## How long each digit stays on screen, also frame-stepped: "1" is visible
## ~0.63-0.67s and "2" ~0.37-0.43s, with a silent gap of ~0.55s before the
## next one pops in. So the count is not a number that sits there changing
## -- it flashes, goes away, and comes back, which is most of what makes a
## three-count tense to watch.
const COUNT_VISIBLE_TICKS: Array[int] = [39, 24, 999]
const COVER_RANGE := 1.2
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

func _ready() -> void:
	wrestler_a = get_node(wrestler_a_path)
	wrestler_b = get_node(wrestler_b_path)

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
		if defender.fsm.current_state == WrestlerFSM.State.DOWN \
				and defender._cover_eligible \
				and attacker.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION]) \
				and attacker.global_position.distance_to(defender.global_position) <= COVER_RANGE:
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
			# referee no longer reaches for it, so nothing in a match
			# starts one.
			_pinning = true
			_pin_ticks = 0
			_pin_count_shown = 0
			_pin_attacker = attacker
			_pin_defender = defender
			attacker.begin_pin(defender, _pin_seed())
			return

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
	if _pin_defender._pin_minigame and _pin_defender._pin_minigame.tick(_pin_ticks, _pin_defender._kickout_input_this_tick):
		_end_pin(false)
		return
	_update_count()
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

func _end_pin(three_count_reached: bool) -> void:
	_pinning = false
	_pin_attacker.fsm.transition_to(WrestlerFSM.State.IDLE)
	if three_count_reached:
		_declare_winner(_pin_attacker, "pinfall")
	else:
		_pin_count_shown = 0
		_pin_defender.fsm.transition_to(WrestlerFSM.State.DOWN)
		_pin_defender._move_ticks_remaining = WrestlerController.GETUP_TICKS
		# Not cover-eligible again until this wrestler actually reaches IDLE
		# (DOWN -> GETUP -> IDLE) — otherwise, since the attacker is also
		# reset to IDLE right where it was standing (already in cover
		# range), _check_for_downed_opponent_action() would re-match on the
		# very next tick, forever, with no time for a getup or a fresh hit
		# to ever land.
		_pin_defender._cover_eligible = false

## Attacker's side of the race needs no continued input (mirrors
## PIN_ATTACKER's automatic three-count) — only the defender's hold state,
## captured each tick by WrestlerController, matters.
func _tick_submission() -> void:
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
	_submissioning = false
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

## Both sides mash "grapple" (captured per-tick by WrestlerController);
## whoever accumulates more qualifying presses first becomes the grapple
## attacker. Unlike pin/submission there's no pre-existing attacker/defender
## role here — the contest itself decides it.
func _tick_tie_up() -> void:
	_tie_up_ticks += 1
	_tie_up_minigame.tick(wrestler_a._tie_up_input_this_tick, wrestler_b._tie_up_input_this_tick)
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
