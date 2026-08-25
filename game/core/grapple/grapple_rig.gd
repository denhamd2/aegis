class_name GrappleRig
extends Node3D
## Drives a paired grapple move: takes ownership of both wrestlers, aligns
## them to a shared anchor, plays one matched AnimationPlayer track that
## moves both skeletons in lockstep, then hands control back via root motion.
##
## Rigid-body sim (ragdoll/rope wobble) never feeds gameplay state, so this
## rig only ever reads/writes CharacterBody3D transforms and animation
## playback — cosmetic-only physics can't desync a replay.

signal grapple_started(attacker: Node3D, defender: Node3D, move: MoveDef)
signal grapple_finished(attacker: Node3D, defender: Node3D)

@export var anchor: Marker3D
@export var animation_player: AnimationPlayer

var _attacker: Node3D
var _defender: Node3D
var _attacker_body: CharacterBody3D
var _defender_body: CharacterBody3D
var _move: MoveDef
var _active: bool = false

func begin(attacker: Node3D, defender: Node3D, move: MoveDef) -> void:
	assert(not _active, "GrappleRig.begin() called while a grapple is already active")
	_attacker = attacker
	_defender = defender
	_move = move
	_attacker_body = attacker as CharacterBody3D
	_defender_body = defender as CharacterBody3D

	_suspend(_attacker_body)
	_suspend(_defender_body)
	_align_to_anchor(attacker, defender)

	_active = true
	grapple_started.emit(attacker, defender, move)

	if animation_player and move.animation_pair_id != &"":
		animation_player.play(move.animation_pair_id)
		animation_player.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)

func _align_to_anchor(attacker: Node3D, defender: Node3D) -> void:
	if not anchor:
		return
	attacker.global_transform = anchor.global_transform
	defender.global_transform = anchor.global_transform.rotated_local(Vector3.UP, PI)

func _suspend(body: CharacterBody3D) -> void:
	if body:
		body.set_physics_process(false)

func _resume(body: CharacterBody3D) -> void:
	if body:
		body.set_physics_process(true)

func _on_animation_finished(_anim_name: StringName) -> void:
	_apply_root_motion()
	_resume(_attacker_body)
	_resume(_defender_body)
	_active = false
	grapple_finished.emit(_attacker, _defender)

func _apply_root_motion() -> void:
	if not animation_player:
		return
	var root_delta := animation_player.get_root_motion_position()
	if _attacker_body:
		_attacker_body.global_position += _attacker_body.global_transform.basis * root_delta

func is_active() -> bool:
	return _active
