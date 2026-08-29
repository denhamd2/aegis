class_name WrestlerController
extends CharacterBody3D
## Grey-box wrestler controller (Phase 2). Wires WrestlerFSM + CombatSystem +
## GrappleRig + MoveDef into a playable, deterministic loop: locomotion,
## strikes, tie-up -> grapple -> move -> down -> pin/submission -> getup,
## plus irish whip / running attack. Visuals are placeholder capsules —
## this exists purely to give the gauntlet loop something on-brief to
## improve (see ARCHITECTURE.md, "grey-box MVP").
##
## Runs entirely off ReplaySystem.get_input() so live play and replay
## playback exercise the same code path (determinism contract).

signal knocked_down(wrestler: WrestlerController)
signal pin_started(attacker: WrestlerController, defender: WrestlerController)
signal move_landed(attacker: WrestlerController, defender: WrestlerController, move: MoveDef)

const MOVE_SPEED := 3.5
const RUN_SPEED := 7.0
const TIE_UP_RANGE := 1.4
const GETUP_TICKS := 90 # 1.5s
const HIT_REACT_TICKS := 20
const STUNNED_TICKS := 45
const TIE_UP_RESOLVE_TICKS := 30

@export var player_index: int = 0
@export var is_ai: bool = false
@export var strike_move: MoveDef
@export var grapple_move: MoveDef
@export var signature_move: MoveDef
@export var finisher_move: MoveDef
@export var weight_class: int = 1
@export var ai: WrestlerAI
@export var opponent_path: NodePath
@export var grapple_rig_path: NodePath

var opponent: WrestlerController
var fsm: WrestlerFSM
var combat: CombatSystem
var grapple_rig: GrappleRig

var _move_ticks_remaining: int = 0
var _active_move: MoveDef
var _tie_up_ticks: int = 0
var _is_grapple_attacker: bool = false
var _pin_minigame: PinMinigame
var _submission_minigame: SubmissionMinigame

func _ready() -> void:
	fsm = WrestlerFSM.new()
	add_child(fsm)
	combat = CombatSystem.new()
	if ai:
		ai.controller = self

func _resolve_paths() -> void:
	if opponent_path != NodePath():
		opponent = get_node(opponent_path)
	if grapple_rig_path != NodePath():
		grapple_rig = get_node(grapple_rig_path)
	if ai:
		ai.target = opponent

func _physics_process(delta: float) -> void:
	var live_input := _poll_live_input()
	var input := ReplaySystem.get_input(player_index, live_input) if ReplaySystem else live_input
	fsm._physics_process(delta)

	match fsm.current_state:
		WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN:
			_process_free_movement(delta, input)
		WrestlerFSM.State.STRIKE:
			_process_active_move(input)
		WrestlerFSM.State.TIE_UP:
			_process_tie_up()
		WrestlerFSM.State.GRAPPLE_HOLD:
			_process_grapple_hold(input)
		WrestlerFSM.State.MOVE_EXEC:
			_process_active_move(input)
		WrestlerFSM.State.HIT_REACT, WrestlerFSM.State.STUNNED:
			_process_timed_state(input, WrestlerFSM.State.IDLE)
		WrestlerFSM.State.DOWN:
			_process_down(input)
		WrestlerFSM.State.GETUP:
			_process_timed_state(input, WrestlerFSM.State.IDLE)
		WrestlerFSM.State.RUNNING_ATTACK:
			_process_active_move(input)
		WrestlerFSM.State.PIN_ATTACKER, WrestlerFSM.State.PIN_DEFENDER:
			pass # driven by MatchReferee
		WrestlerFSM.State.SUBMISSION_ATTACKER, WrestlerFSM.State.SUBMISSION_DEFENDER:
			pass # driven by MatchReferee

	move_and_slide()

func _poll_live_input() -> Dictionary:
	if is_ai:
		return ai.poll_input() if ai else {}
	return {
		"move": Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		"strike": Input.is_action_just_pressed("strike"),
		"grapple": Input.is_action_just_pressed("grapple"),
		"run": Input.is_action_pressed("run"),
		"reversal": Input.is_action_just_pressed("reversal"),
		"submission_hold": Input.is_action_pressed("submission_hold"),
	}

func _process_free_movement(delta: float, input: Dictionary) -> void:
	var move_vec: Vector2 = input.get("move", Vector2.ZERO)
	var running: bool = input.get("run", false) and move_vec.length() > 0.1
	var speed := RUN_SPEED if running else MOVE_SPEED
	var direction := Vector3(move_vec.x, 0.0, move_vec.y)

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)
		fsm.transition_to(WrestlerFSM.State.RUN if running else WrestlerFSM.State.LOCOMOTION)
	elif fsm.current_state != WrestlerFSM.State.IDLE:
		fsm.transition_to(WrestlerFSM.State.IDLE)

	if input.get("strike", false) and strike_move:
		_start_move(WrestlerFSM.State.STRIKE, strike_move)
	elif input.get("grapple", false) and opponent and _in_range(TIE_UP_RANGE):
		fsm.transition_to(WrestlerFSM.State.TIE_UP)
		opponent.fsm.transition_to(WrestlerFSM.State.TIE_UP)
		_tie_up_ticks = 0

func _in_range(range_m: float) -> bool:
	return opponent != null and global_position.distance_to(opponent.global_position) <= range_m

func _start_move(state: WrestlerFSM.State, move: MoveDef) -> void:
	_active_move = move
	_move_ticks_remaining = move.total_frames()
	fsm.transition_to(state)

func _process_active_move(input: Dictionary) -> void:
	if not _active_move:
		fsm.transition_to(WrestlerFSM.State.IDLE)
		return
	var frame_offset := _active_move.total_frames() - _move_ticks_remaining
	var in_active_frames := frame_offset >= _active_move.startup_frames \
		and frame_offset < _active_move.startup_frames + _active_move.active_frames

	if in_active_frames and opponent and _in_range(TIE_UP_RANGE) and not _active_move.get_meta("applied", false):
		_apply_move_to_opponent(_active_move)
		_active_move.set_meta("applied", true)

	_move_ticks_remaining -= 1
	if _move_ticks_remaining <= 0:
		_active_move.set_meta("applied", false)
		fsm.transition_to(WrestlerFSM.State.IDLE)
		_active_move = null

func _apply_move_to_opponent(move: MoveDef) -> void:
	opponent.combat.apply_move(move)
	move_landed.emit(self, opponent, move)
	if opponent.combat.total_damage() >= CombatSystem.MAX_LIMB_DAMAGE * 2.0:
		opponent._go_down()
	else:
		opponent._start_move(WrestlerFSM.State.HIT_REACT, _timed_stub(HIT_REACT_TICKS))

func _timed_stub(ticks: int) -> MoveDef:
	var stub := MoveDef.new()
	stub.startup_frames = ticks
	stub.active_frames = 0
	stub.recovery_frames = 0
	return stub

func _process_tie_up() -> void:
	_tie_up_ticks += 1
	if _tie_up_ticks < TIE_UP_RESOLVE_TICKS:
		return
	# Deterministic resolution: whichever wrestler entered the tie-up first
	# (lower player_index, as a stand-in for a reaction-time contest) wins.
	var attacker := self if player_index < opponent.player_index else opponent
	var defender := opponent if attacker == self else self
	attacker._is_grapple_attacker = true
	defender._is_grapple_attacker = false
	attacker.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	defender.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)

func _process_grapple_hold(input: Dictionary) -> void:
	if not _is_grapple_attacker:
		return
	var move := grapple_move
	if not move or opponent.weight_class < move.weight_class_min or opponent.weight_class > move.weight_class_max:
		return
	if combat.can_finisher() and finisher_move:
		move = finisher_move
	elif combat.can_signature() and signature_move:
		move = signature_move

	_active_move = move
	if grapple_rig:
		grapple_rig.begin(self, opponent, move)
		grapple_rig.grapple_finished.connect(_on_grapple_finished, CONNECT_ONE_SHOT)
	else:
		_resolve_grapple_move(move)

func _on_grapple_finished(_attacker: Node3D, _defender: Node3D) -> void:
	var move := _active_move
	_active_move = null
	_resolve_grapple_move(move)

func _resolve_grapple_move(move: MoveDef) -> void:
	fsm.transition_to(WrestlerFSM.State.MOVE_EXEC)
	# Defender rides the same paired move (GrappleRig drove both skeletons in
	# lockstep) so it must also be in MOVE_EXEC before taking a hit reaction —
	# GRAPPLE_HOLD -> HIT_REACT/DOWN is not a legal transition on its own.
	opponent.fsm.transition_to(WrestlerFSM.State.MOVE_EXEC)
	_apply_move_to_opponent(move)
	fsm.transition_to(WrestlerFSM.State.IDLE)

func _go_down() -> void:
	if fsm.current_state == WrestlerFSM.State.HIT_REACT or fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN, WrestlerFSM.State.STRIKE]):
		fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	fsm.transition_to(WrestlerFSM.State.DOWN)
	_move_ticks_remaining = GETUP_TICKS
	knocked_down.emit(self)

func _process_down(input: Dictionary) -> void:
	_move_ticks_remaining -= 1
	if input.get("strike", false) or _move_ticks_remaining <= 0:
		fsm.transition_to(WrestlerFSM.State.GETUP)
		_move_ticks_remaining = 20

func _process_timed_state(input: Dictionary, next_state: WrestlerFSM.State) -> void:
	_move_ticks_remaining -= 1
	if _move_ticks_remaining <= 0:
		fsm.transition_to(next_state)

## Called by MatchReferee when the attacker covers a downed opponent.
func begin_pin(defender: WrestlerController, seed_value: int) -> void:
	fsm.transition_to(WrestlerFSM.State.PIN_ATTACKER)
	defender.fsm.transition_to(WrestlerFSM.State.PIN_DEFENDER)
	var fraction := defender.combat.kickout_window_fraction(combat.momentum)
	defender._pin_minigame = PinMinigame.new(fraction, seed_value)
	pin_started.emit(self, defender)

func begin_submission(defender: WrestlerController, target_limb: CombatSystem.Limb) -> void:
	fsm.transition_to(WrestlerFSM.State.SUBMISSION_ATTACKER)
	defender.fsm.transition_to(WrestlerFSM.State.SUBMISSION_DEFENDER)
	var attacker_rate := combat.submission_break_rate(target_limb)
	var defender_rate := 0.9 # baseline escape rate; tuned in gauntlet rounds
	_submission_minigame = SubmissionMinigame.new(attacker_rate, defender_rate)
