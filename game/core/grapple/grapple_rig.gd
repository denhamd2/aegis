class_name GrappleRig
extends Node3D
## Drives a paired grapple move: takes ownership of both wrestlers, aligns
## them to a shared anchor, plays one matched AnimationPlayer track that
## moves both bodies in lockstep, then hands control back via root motion.
##
## Paired clips animate the two CharacterBody3D root transforms only — the
## throw trajectory. Each wrestler's own AnimationTree keeps posing its
## skeleton throughout, so bodies stay fully posed mid-move; the two never
## fight because they write to different things (root transform vs bones).
## Do not add bone tracks to a paired clip without also handling that
## overlap: an earlier pass did, silenced the AnimationTrees to stop the
## conflict, and left every bone the clip *didn't* animate stuck on the
## rig's bind pose (arms straight out, legs straight) for the whole move.
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

## Paired clips are authored once against fixed node names -- "WrestlerA" is
## always the grounded/lifting role's track, "WrestlerB" always the thrown/
## carried role's, see paired_moves.tres -- not against "attacker"/
## "defender". Played unmodified, the clip's motion lands on whichever
## physical node is literally named WrestlerA, regardless of who's actually
## attacking. Confirmed live with a direct-invocation probe: with WrestlerB
## as the real attacker, the unmodified clip lifted the *attacker* into the
## air and left the defender standing -- exactly backwards, for every
## existing paired move (suplex/backbreaker/piledriver), not just a new one.
## _play_retargeted() plays a duplicated copy of the clip with its two
## wrestler tracks' NodePaths rewritten to the real attacker/defender nodes,
## so the authored motion always maps lifter-track -> attacker and
## thrown-track -> defender, whichever physical node that is this call. The
## original clip is restored into the shared AnimationLibrary afterward
## (never mutated in place -- it's one Resource instance shared by every
## match/replay, same hazard MoveDef's own shared-Resource doc comment
## already flags elsewhere in this codebase).
var _retargeted_anim_name: StringName
var _original_anim: Animation

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

	if animation_player and move.animation_pair_id != &"" and animation_player.has_animation(move.animation_pair_id):
		_play_retargeted(move.animation_pair_id, attacker, defender)
		animation_player.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)
	else:
		# Grey-box fallback (Phase 2/3 gap): no paired animation library yet,
		# so resolve on the move's own frame count instead of an anim signal.
		var ticks_to_wait := move.total_frames() if move else 1
		await Engine.get_main_loop().create_timer(ticks_to_wait / float(Engine.physics_ticks_per_second)).timeout
		_on_animation_finished(&"")

func _play_retargeted(anim_name: StringName, attacker: Node3D, defender: Node3D) -> void:
	var library := animation_player.get_animation_library("")
	var source := library.get_animation(anim_name)
	var root := animation_player.get_node(animation_player.root_node)
	var retargeted := source.duplicate() as Animation
	for i in retargeted.get_track_count():
		var path := retargeted.track_get_path(i)
		var node_name := String(path.get_name(path.get_name_count() - 1))
		if node_name == "WrestlerA":
			retargeted.track_set_path(i, root.get_path_to(attacker))
		elif node_name == "WrestlerB":
			retargeted.track_set_path(i, root.get_path_to(defender))
	_original_anim = source
	_retargeted_anim_name = anim_name
	library.remove_animation(anim_name)
	library.add_animation(anim_name, retargeted)
	animation_player.play(anim_name)

func _restore_original_animation() -> void:
	if not _original_anim:
		return
	var library := animation_player.get_animation_library("")
	if library.has_animation(_retargeted_anim_name):
		library.remove_animation(_retargeted_anim_name)
	library.add_animation(_retargeted_anim_name, _original_anim)
	_original_anim = null

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
	_restore_original_animation()
	_resume(_attacker_body)
	_resume(_defender_body)
	_active = false
	grapple_finished.emit(_attacker, _defender)

func _apply_root_motion() -> void:
	if not animation_player or not animation_player.has_animation(_move.animation_pair_id if _move else &""):
		return
	var root_delta := animation_player.get_root_motion_position()
	if _attacker_body:
		_attacker_body.global_position += _attacker_body.global_transform.basis * root_delta

func is_active() -> bool:
	return _active
