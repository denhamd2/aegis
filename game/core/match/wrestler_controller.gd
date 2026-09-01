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
## Reach for a strike/running-attack to connect. Must stay >= WrestlerAI's
## default strike_range (1.6m) — an AI that throws from further out than
## this can land is a strike that always whiffs.
const STRIKE_HIT_RANGE := 1.8
const GETUP_TICKS := 90 # 1.5s
const HIT_REACT_TICKS := 20
const STUNNED_TICKS := 45
## States WrestlerFSM.LEGAL_TRANSITIONS actually allows a TIE_UP transition
## from — both sides of a grapple attempt must be in one of these, or the
## attempt is silently dropped (see the gate in _process_free_movement()).
## Public (not underscore-prefixed) so MatchReferee can gate its own
## tie-up-entry decision with the same legality check — see
## _wants_tie_up_this_tick's doc comment for why entry moved there.
const CAN_ENTER_TIE_UP: Array[WrestlerFSM.State] = [
	WrestlerFSM.State.IDLE,
	WrestlerFSM.State.LOCOMOTION,
]

@export var player_index: int = 0
@export var is_ai: bool = false
@export var strike_move: MoveDef
@export var grapple_move: MoveDef
@export var power_move: MoveDef
@export var signature_move: MoveDef
@export var finisher_move: MoveDef
@export var weight_class: int = 1
@export var opponent_path: NodePath
@export var grapple_rig_path: NodePath

var ai: WrestlerAI
var opponent: WrestlerController
var fsm: WrestlerFSM
var combat: CombatSystem
var grapple_rig: GrappleRig
## Retargeted CC0 base mesh's own AnimationPlayer (see
## assets/characters/CREDITS.md).
var anim_player: AnimationPlayer
## Drives anim_player through an AnimationNodeStateMachine built in
## _build_animation_tree() — one state-machine node per WrestlerFSM state,
## wired with a transition for every LEGAL_TRANSITIONS edge, cross-fading
## over ANIMATION_BLEND_TICKS. This is the real ARCHITECTURE.md blend graph
## (not a direct AnimationPlayer.play() switch): _on_fsm_state_changed()
## calls playback.travel() so xfades and state ordering are the engine's
## job, not hand-rolled here.
var anim_tree: AnimationTree
var _anim_playback: AnimationNodeStateMachinePlayback

## FSM state -> clip from the base mesh's library. Every state gets *some*
## plausible clip from the single-character library on hand — no paired
## grapple animation exists yet (see README's Phase 3 notes), so
## grapple-adjacent states borrow the closest single-character clip as a
## placeholder rather than left in bind pose:
## TIE_UP/GRAPPLE_HOLD -> Interact, MOVE_EXEC -> Punch_Cross,
## PIN_ATTACKER -> Crouch_Idle, PIN_DEFENDER/DOWN -> Death01,
## SUBMISSION_ATTACKER -> Crouch_Idle, SUBMISSION_DEFENDER -> Death01,
## FINISHER -> Sword_Attack, GETUP -> Roll (imperfect — the only
## on-the-ground-to-standing clip in this library).
const STATE_ANIMATIONS := {
	WrestlerFSM.State.IDLE: "Idle",
	WrestlerFSM.State.LOCOMOTION: "Walk",
	WrestlerFSM.State.RUN: "Sprint",
	WrestlerFSM.State.STRIKE: "Punch_Jab",
	WrestlerFSM.State.TIE_UP: "Interact",
	WrestlerFSM.State.GRAPPLE_HOLD: "Interact",
	WrestlerFSM.State.MOVE_EXEC: "Punch_Cross",
	WrestlerFSM.State.HIT_REACT: "Hit_Chest",
	WrestlerFSM.State.DOWN: "Death01",
	WrestlerFSM.State.GETUP: "Roll",
	WrestlerFSM.State.IRISH_WHIP: "Push",
	WrestlerFSM.State.RUNNING_ATTACK: "Punch_Cross",
	WrestlerFSM.State.STUNNED: "Hit_Head",
	WrestlerFSM.State.PIN_ATTACKER: "Crouch_Idle",
	WrestlerFSM.State.PIN_DEFENDER: "Death01",
	WrestlerFSM.State.SUBMISSION_ATTACKER: "Crouch_Idle",
	WrestlerFSM.State.SUBMISSION_DEFENDER: "Death01",
	WrestlerFSM.State.FINISHER: "Sword_Attack",
}
## Ticks (at 60Hz) to cross-fade between clips.
const ANIMATION_BLEND_TICKS := 6

var _move_ticks_remaining: int = 0
var _active_move: MoveDef
var _is_grapple_attacker: bool = false
var _pin_minigame: PinMinigame
var _submission_minigame: SubmissionMinigame

## Hits queued against this wrestler this tick, resolved by MatchReferee
## after every wrestler has run its own _physics_process. Godot processes
## scene-tree children in a fixed order every tick (WrestlerA before
## WrestlerB), so applying a hit synchronously — mid opponent's own strike
## resolution — let whichever wrestler updates first always land first and
## silently overwrite the other's in-flight attack. Queuing defers the
## effect to end-of-tick so both wrestlers' decisions this tick are made
## from the same starting state, regardless of node order.
var _pending_hits: Array[MoveDef] = []

## Whether the current _active_move has already landed its hit this
## attempt. This must live here, not on the MoveDef resource (previously
## tracked via _active_move.set_meta("applied", ...)) — a MoveDef loaded
## from a .tres is one shared Resource instance referenced by both
## wrestlers (e.g. both assigned the same strike_jab.tres), so metadata
## set on it was a single flag fought over by both attackers: whichever
## wrestler's strike landed first marked it "applied" and permanently
## blocked the other wrestler's independent attack from ever landing.
var _active_move_hit_applied: bool = false
var _kickout_input_this_tick: bool = false
var _submission_defender_input_this_tick: bool = false
var _tie_up_input_this_tick: bool = false
## Set by _process_free_movement() whenever this wrestler pressed grapple
## this tick; consumed by MatchReferee (which runs after every wrestler's
## own _physics_process, see _resolve_pending_hits()'s doc comment for why
## that ordering matters) to decide whether to start a tie-up. Entry used to
## happen inline here via a direct opponent.fsm.transition_to(TIE_UP) call —
## but since only one wrestler's _process_free_movement() actually executes
## that branch each tick (whichever comes first in the scene tree), the
## *other* wrestler's FSM state changed mid-tick, before its own
## _physics_process() ran — so its WrestlerAI.poll_input() saw TIE_UP
## already in effect and started counting tie-up mash ticks one tick early,
## every single time, regardless of either wrestler's actual behavior. In an
## AI-vs-AI match with identical, jitter-free mash timing (no RNG in that
## policy by design) that one-tick head start silently decided every single
## tie-up — confirmed live: TieUpMinigame progress at resolution was always
## exactly (9.0, 10.0), the "loser" one tick behind, never closer. Deferring
## the actual transition to MatchReferee (which runs strictly after both
## wrestlers this tick) makes entry happen on a fresh tick for both sides
## uniformly, the same fix shape already used for pin/submission entry.
var _wants_tie_up_this_tick: bool = false

## Whether MatchReferee._check_for_cover() may start a new pin on this
## wrestler right now. True by default and after a genuine knockdown (an
## attacker walking over to cover a freshly-downed opponent is intended to
## work immediately) — but a kickout resets straight back to DOWN with the
## same attacker already standing in cover range, so without this gate
## _check_for_cover() re-matches the very next tick, before GETUP_TICKS or
## the GETUP state ever run, and the wrestler is re-covered forever without
## a real chance to recover or take a fresh hit. Cleared by
## MatchReferee._end_pin() on a kickout, restored once this wrestler
## actually reaches IDLE again (see _process_timed_state()).
var _cover_eligible: bool = true

func _ready() -> void:
	fsm = WrestlerFSM.new()
	add_child(fsm)
	combat = CombatSystem.new()
	ai = get_node_or_null("AI")
	if ai:
		ai.controller = self

	anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	fsm.state_changed.connect(_on_fsm_state_changed)
	if anim_player:
		_build_animation_tree()

## Builds the AnimationNodeStateMachine blend graph: one AnimationNodeAnimation
## per WrestlerFSM state that has a usable clip (STATE_ANIMATIONS), and one
## AnimationNodeStateMachineTransition per WrestlerFSM.LEGAL_TRANSITIONS edge
## between two such states, cross-fading over ANIMATION_BLEND_TICKS. Runtime-
## built rather than authored as a .tscn sub-resource graph so it always
## matches WrestlerFSM's state/transition tables instead of drifting from
## them by hand.
func _build_animation_tree() -> void:
	var state_machine := AnimationNodeStateMachine.new()
	for state_id in STATE_ANIMATIONS:
		var clip_name: String = STATE_ANIMATIONS[state_id]
		if not anim_player.has_animation(clip_name):
			continue
		var anim_node := AnimationNodeAnimation.new()
		anim_node.animation = clip_name
		state_machine.add_node(WrestlerFSM.State.keys()[state_id], anim_node)

	var blend_seconds := ANIMATION_BLEND_TICKS / float(Engine.physics_ticks_per_second)
	for from_id in WrestlerFSM.LEGAL_TRANSITIONS:
		var from_name: String = WrestlerFSM.State.keys()[from_id]
		if not state_machine.has_node(from_name):
			continue
		for to_id in WrestlerFSM.LEGAL_TRANSITIONS[from_id]:
			var to_name: String = WrestlerFSM.State.keys()[to_id]
			if to_name == from_name or not state_machine.has_node(to_name):
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = blend_seconds
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			state_machine.add_transition(from_name, to_name, transition)

	anim_tree = AnimationTree.new()
	add_child(anim_tree)
	anim_tree.tree_root = state_machine
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)
	# Advance on the physics tick, not idle/wall-clock frames (the default) —
	# animation is presentation-only and doesn't feed gameplay state, but an
	# idle-clocked tree would still make playback speed (and therefore what a
	# given tick *looks like*) depend on render framerate, which undermines
	# frame-labeled captures (ARCHITECTURE.md's capture/evidence pipeline)
	# expecting a specific tick to reliably show a specific pose.
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	anim_tree.active = true
	_anim_playback = anim_tree["parameters/playback"]
	var idle_name: String = WrestlerFSM.State.keys()[WrestlerFSM.State.IDLE]
	if state_machine.has_node(idle_name):
		_anim_playback.start(idle_name)

func _on_fsm_state_changed(_previous: WrestlerFSM.State, current: WrestlerFSM.State) -> void:
	if not _anim_playback:
		return
	var state_name: String = WrestlerFSM.State.keys()[current]
	if not (anim_tree.tree_root as AnimationNodeStateMachine).has_node(state_name):
		return
	_anim_playback.travel(state_name)

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
			# MatchReferee drives the actual contest (TieUpMinigame) once both
			# wrestlers are in TIE_UP — mirrors PIN_DEFENDER's input capture.
			_tie_up_input_this_tick = input.get("grapple", false)
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
		WrestlerFSM.State.PIN_ATTACKER:
			pass # driven by MatchReferee
		WrestlerFSM.State.PIN_DEFENDER:
			# MatchReferee reads this each tick against PinMinigame's target
			# window — a kickout needs the button pressed AND the marker in
			# the window at that instant, not just the marker passing
			# through the window on its own (the marker sweeps the whole
			# range every cycle, so without an input gate every pin would
			# resolve as an automatic kickout before reaching a three-count).
			_kickout_input_this_tick = input.get("strike", false)
		WrestlerFSM.State.SUBMISSION_ATTACKER:
			pass # driven by MatchReferee; no continued attacker input needed,
			# same as PIN_ATTACKER's three-count
		WrestlerFSM.State.SUBMISSION_DEFENDER:
			# Mirrors the PIN_DEFENDER case above, but held rather than
			# just-pressed — SubmissionMinigame is a genuine continuous-hold
			# rate race, not a press-limited fill-meter, so no input gating
			# is needed here beyond reading the raw hold state each tick.
			_submission_defender_input_this_tick = input.get("submission_hold", false)

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

	_wants_tie_up_this_tick = false
	if input.get("strike", false) and strike_move:
		_start_move(WrestlerFSM.State.STRIKE, strike_move)
	elif input.get("grapple", false):
		_wants_tie_up_this_tick = true

func _in_range(range_m: float) -> bool:
	return opponent != null and global_position.distance_to(opponent.global_position) <= range_m

func _start_move(state: WrestlerFSM.State, move: MoveDef) -> void:
	_active_move = move
	_move_ticks_remaining = move.total_frames()
	_active_move_hit_applied = false
	fsm.transition_to(state)

## States a wrestler cannot be struck out of by an opposing strike/grapple —
## already down, mid-getup, or committed to a pin/submission/finisher
## sequence. Without this gate a standing opponent can keep striking a
## downed wrestler and re-trigger _go_down() every hit, permanently
## resetting the getup timer so the match can never reach a pin.
const UNHITTABLE_STATES: Array[WrestlerFSM.State] = [
	WrestlerFSM.State.DOWN,
	WrestlerFSM.State.GETUP,
	WrestlerFSM.State.PIN_ATTACKER,
	WrestlerFSM.State.PIN_DEFENDER,
	WrestlerFSM.State.SUBMISSION_ATTACKER,
	WrestlerFSM.State.SUBMISSION_DEFENDER,
	WrestlerFSM.State.FINISHER,
	WrestlerFSM.State.MOVE_EXEC,
]

func _process_active_move(input: Dictionary) -> void:
	if not _active_move:
		fsm.transition_to(WrestlerFSM.State.IDLE)
		return
	var frame_offset := _active_move.total_frames() - _move_ticks_remaining
	var in_active_frames := frame_offset >= _active_move.startup_frames \
		and frame_offset < _active_move.startup_frames + _active_move.active_frames

	if in_active_frames and opponent and _in_range(STRIKE_HIT_RANGE) \
			and not UNHITTABLE_STATES.has(opponent.fsm.current_state) \
			and not _active_move_hit_applied:
		_apply_move_to_opponent(_active_move)
		_active_move_hit_applied = true

	_move_ticks_remaining -= 1
	if _move_ticks_remaining <= 0:
		_active_move_hit_applied = false
		fsm.transition_to(WrestlerFSM.State.IDLE)
		_active_move = null

func _apply_move_to_opponent(move: MoveDef) -> void:
	move_landed.emit(self, opponent, move)
	# Momentum belongs to whoever lands the hit (self), not the wrestler
	# taking it — applied immediately since it's this wrestler's own
	# CombatSystem, not shared, so there's no cross-wrestler race here.
	# The damage itself still goes through the deferred queue below.
	combat.apply_momentum(move)
	opponent._pending_hits.append(move)

## Called by MatchReferee once every wrestler has finished its own
## _physics_process for this tick.
func _resolve_pending_hits() -> void:
	if _pending_hits.is_empty():
		return
	# The wrestler may have moved into an unhittable state (e.g. its own
	# pin cover) between when this hit was queued and now — drop the
	# reaction (not the damage numbers, which are harmless) rather than
	# force an illegal FSM transition.
	var moves := _pending_hits.duplicate()
	_pending_hits.clear()
	if UNHITTABLE_STATES.has(fsm.current_state):
		return
	for move in moves:
		combat.apply_damage(move)
	if combat.total_damage() >= CombatSystem.MAX_LIMB_DAMAGE * 2.0:
		_go_down()
	else:
		_start_move(WrestlerFSM.State.HIT_REACT, _timed_stub(HIT_REACT_TICKS))

func _timed_stub(ticks: int) -> MoveDef:
	var stub := MoveDef.new()
	stub.startup_frames = ticks
	stub.active_frames = 0
	stub.recovery_frames = 0
	return stub

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
	elif combat.can_power() and power_move:
		move = power_move

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
	move_landed.emit(self, opponent, move)
	combat.apply_momentum(move)
	# Applied directly rather than through _apply_move_to_opponent's
	# _pending_hits queue: that queue exists so MatchReferee can arbitrate
	# two wrestlers striking each other the *same* tick regardless of
	# scene-tree node order — irrelevant here, a grapple has one
	# deterministic attacker already fully resolved. Routing through it
	# broke every grapple: _resolve_pending_hits() checks the defender's
	# *own* current state before applying, and the MOVE_EXEC transition
	# just above (required to legally reach HIT_REACT/DOWN from
	# GRAPPLE_HOLD) is also, for an unrelated reason, in UNHITTABLE_STATES
	# (protecting a wrestler already mid-strike-startup from a second
	# simultaneous hit) — so every queued grapple hit was silently dropped
	# the instant it was queued, damage never accumulated, and a match
	# never progressed past tie-up -> grapple -> repeat.
	opponent.combat.apply_damage(move)
	fsm.transition_to(WrestlerFSM.State.IDLE)
	if opponent.combat.total_damage() >= CombatSystem.MAX_LIMB_DAMAGE * 2.0:
		opponent._go_down()
	else:
		opponent._start_move(WrestlerFSM.State.HIT_REACT, opponent._timed_stub(HIT_REACT_TICKS))

func _go_down() -> void:
	if fsm.current_state == WrestlerFSM.State.HIT_REACT or fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN, WrestlerFSM.State.STRIKE]):
		fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	fsm.transition_to(WrestlerFSM.State.DOWN)
	_move_ticks_remaining = GETUP_TICKS
	_cover_eligible = true
	knocked_down.emit(self)

func _process_down(input: Dictionary) -> void:
	_move_ticks_remaining -= 1
	if input.get("strike", false) or _move_ticks_remaining <= 0:
		fsm.transition_to(WrestlerFSM.State.GETUP)
		_move_ticks_remaining = 20

func _process_timed_state(input: Dictionary, next_state: WrestlerFSM.State) -> void:
	_move_ticks_remaining -= 1
	if _move_ticks_remaining <= 0:
		# Also covers GETUP -> IDLE, the only place a wrestler that lost
		# _cover_eligible to a kickout (see the field's own doc comment)
		# gets it back — harmless to set unconditionally for the
		# HIT_REACT/STUNNED -> IDLE case too, since it's already true there.
		_cover_eligible = true
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
	# submission_break_rate() reads whichever CombatSystem it's called on —
	# it must be the defender's (the limb actually being locked), not the
	# attacker's own. Calling it on `combat` (self, the attacker) silently
	# ignored the defender's real damage entirely, since an attacker's own
	# limbs are rarely damaged on the same limb it's targeting: caught live,
	# not by the unit tests below (which exercise SubmissionMinigame's rate
	# math directly, not this call site) — every attempt escaped regardless
	# of how hurt the targeted limb actually was.
	var attacker_rate := defender.combat.submission_break_rate(target_limb)
	# MatchReferee only ever starts a submission once the targeted limb is at
	# or above SUBMISSION_LIMB_THRESHOLD (70), so attacker_rate here is never
	# actually as low as its theoretical floor of 1.0 — it's really gated to
	# [1.7, 2.0] (1.0 + threshold/100 .. 1.0 + MAX_LIMB_DAMAGE/100). A flat
	# 0.9 defender_rate loses that race every time (100/1.0=100 ticks for the
	# attacker's absolute floor vs 100/0.9=111 for the defender — the
	# attacker always arrives first), so it's retuned to sit inside the
	# realistic gated band: defender-favored just above the threshold floor,
	# attacker-favored near a fully-damaged limb. First-pass value, open to
	# retuning like PROGRESS_THRESHOLD was (see test_submission_minigame.gd).
	var defender_rate := 1.8
	defender._submission_minigame = SubmissionMinigame.new(attacker_rate, defender_rate)
