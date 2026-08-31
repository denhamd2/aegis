class_name MatchReferee
extends Node
## Drives pin/submission resolution and declares the win condition.
## Grey-box version of the "ref" system: watches for a downed wrestler
## being covered or locked in a submission, runs the deterministic
## minigame, and ends the match on a three-count or a tap-out.

signal match_won(winner: WrestlerController, method: String)

const PIN_COUNT_TICKS := 180 # three-count at 60Hz, one count per 60 ticks
const COVER_RANGE := 1.2
## Attacking a downed opponent's most-damaged limb becomes a submission
## attempt instead of a pin once that limb's damage crosses this fraction of
## CombatSystem.MAX_LIMB_DAMAGE (70%). First-pass value; confirm/retune via
## test_submission_minigame.gd and a live multi-seed probe, not by feel.
const SUBMISSION_LIMB_THRESHOLD := 70.0
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
var _pinning: bool = false
var _pin_attacker: WrestlerController
var _pin_defender: WrestlerController
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

## Kept as one function rather than two independent scans so a given
## attacker/defender pair can't match both a pin and a submission check the
## same tick — each pair gets exactly one decision.
func _check_for_downed_opponent_action() -> void:
	for pair in [[wrestler_a, wrestler_b], [wrestler_b, wrestler_a]]:
		var attacker: WrestlerController = pair[0]
		var defender: WrestlerController = pair[1]
		if defender.fsm.current_state == WrestlerFSM.State.DOWN \
				and defender._cover_eligible \
				and attacker.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION]) \
				and attacker.global_position.distance_to(defender.global_position) <= COVER_RANGE:
			var worst_limb: CombatSystem.Limb = defender.combat.most_damaged_limb()
			if defender.combat.limb_damage[worst_limb] >= SUBMISSION_LIMB_THRESHOLD:
				_submissioning = true
				_submission_attacker = attacker
				_submission_defender = defender
				attacker.begin_submission(defender, worst_limb)
			else:
				_pinning = true
				_pin_ticks = 0
				_pin_attacker = attacker
				_pin_defender = defender
				attacker.begin_pin(defender, match_seed + Engine.get_physics_frames())
			return

func _tick_pin() -> void:
	_pin_ticks += 1
	if _pin_defender._pin_minigame and _pin_defender._pin_minigame.tick(_pin_ticks, _pin_defender._kickout_input_this_tick):
		_end_pin(false)
		return
	if _pin_ticks >= PIN_COUNT_TICKS:
		_end_pin(true)

func _end_pin(three_count_reached: bool) -> void:
	_pinning = false
	_pin_attacker.fsm.transition_to(WrestlerFSM.State.IDLE)
	if three_count_reached:
		_declare_winner(_pin_attacker, "pinfall")
	else:
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
	if minigame.attacker_wins():
		_end_submission(true)
	elif minigame.defender_escapes():
		_end_submission(false)

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
