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
## Frame the current move plays in — see _compute_pair_transform().
var _pair_transform: Transform3D = Transform3D()

## Half-width of the mat (scenes/ring.tscn's floor is 6m square), minus room
## for a body. Clamps where a paired move is allowed to play out.
const RING_HALF_EXTENT := 2.0

func begin(attacker: Node3D, defender: Node3D, move: MoveDef) -> void:
	assert(not _active, "GrappleRig.begin() called while a grapple is already active")
	_attacker = attacker
	_defender = defender
	_move = move
	_attacker_body = attacker as CharacterBody3D
	_defender_body = defender as CharacterBody3D

	_suspend(_attacker_body)
	_suspend(_defender_body)
	_pair_transform = _compute_pair_transform(attacker, defender)
	_align_to_pair(attacker, defender)

	_active = true
	_play_role_poses(attacker, defender, move)
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

## Starts each wrestler's half of the move's authored bone-level performance.
##
## Done here rather than at either call site because there are two of them --
## WrestlerController._process_grapple_hold() and
## MatchReferee._apply_reversal() -- and both must start the poses on the same
## physics tick as the root trajectory or the halves drift apart. It also
## keeps to ARCHITECTURE.md's rule that GrappleRig is the system that drives
## both bodies of a paired move in lockstep.
##
## Duck-typed rather than typed against WrestlerController so GrappleRig stays
## free of a dependency on it, matching how it already takes Node3D bodies. A
## move with no authored performance simply gets no call-through: both
## wrestlers keep the borrowed single-character clip
## WrestlerController.clip_for_state() gave them.
func _play_role_poses(attacker: Node3D, defender: Node3D, move: MoveDef) -> void:
	if not move:
		return
	for pair: Array in [[attacker, true], [defender, false]]:
		var body: Node3D = pair[0]
		if body and body.has_method("play_paired_pose"):
			body.play_paired_pose(move, pair[1])

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
		else:
			continue
		_transform_track_into_pair_frame(retargeted, i)
	_original_anim = source
	_retargeted_anim_name = anim_name
	library.remove_animation(anim_name)
	library.add_animation(anim_name, retargeted)
	animation_player.play(anim_name)

## Rewrite one wrestler track's keys from the authored origin frame into
## _pair_transform.
##
## The clips write absolute node positions in Match space, so without this
## the move would snap back to the origin on the animation's first frame no
## matter where _align_to_pair() put the wrestlers. Baking the frame into the
## duplicated copy (which _play_retargeted() already makes, and
## _restore_original_animation() already puts back) keeps playback
## deterministic and needs no per-frame hook -- a post-animation offset would
## have to run after the AnimationPlayer child updates, which node order does
## not give us.
func _transform_track_into_pair_frame(anim: Animation, track: int) -> void:
	var track_type := anim.track_get_type(track)
	if track_type == Animation.TYPE_POSITION_3D:
		for k in anim.track_get_key_count(track):
			var pos: Vector3 = anim.track_get_key_value(track, k)
			anim.track_set_key_value(track, k, _pair_transform * pos)
	elif track_type == Animation.TYPE_ROTATION_3D:
		var yaw := Quaternion(_pair_transform.basis.orthonormalized())
		for k in anim.track_get_key_count(track):
			var rot: Quaternion = anim.track_get_key_value(track, k)
			anim.track_set_key_value(track, k, yaw * rot)

func _restore_original_animation() -> void:
	if not _original_anim:
		return
	var library := animation_player.get_animation_library("")
	if library.has_animation(_retargeted_anim_name):
		library.remove_animation(_retargeted_anim_name)
	library.add_animation(_retargeted_anim_name, _original_anim)
	_original_anim = null

## Frame the current paired move plays in: positioned at the pair's own
## midpoint and yawed along the attacker's facing.
##
## Paired clips are authored around the origin, and this used to align both
## wrestlers straight onto the GrappleAnchor -- which has no transform
## override in match.tscn and therefore sits at the world origin. Every
## grapple teleported both wrestlers to the middle of the ring, wherever they
## had been standing, which reads on camera as the pair repeatedly snapping
## together and stacking up. Building a per-call frame instead lets the same
## authored clip play wherever the wrestlers actually are, and along the
## direction the attacker is actually facing.
func _compute_pair_transform(attacker: Node3D, defender: Node3D) -> Transform3D:
	var midpoint := (attacker.global_position + defender.global_position) * 0.5
	# Y comes from the anchor, not the pair: a clip's vertical keys are
	# authored against mat level, and either wrestler may be mid-drift.
	midpoint.y = anchor.global_position.y if anchor else 0.0
	# Keep the move inside the ring. A suspended body ignores collision for
	# the whole clip, so a throw started against the ropes would otherwise
	# sweep straight through them.
	midpoint.x = clampf(midpoint.x, -RING_HALF_EXTENT, RING_HALF_EXTENT)
	midpoint.z = clampf(midpoint.z, -RING_HALF_EXTENT, RING_HALF_EXTENT)

	var facing := defender.global_position - attacker.global_position
	facing.y = 0.0
	if facing.length() < 0.001:
		facing = -attacker.global_transform.basis.z
		facing.y = 0.0
	if facing.length() < 0.001:
		return Transform3D(Basis(), midpoint)
	return Transform3D(Basis(Vector3.UP, atan2(-facing.x, -facing.z)), midpoint)

func _align_to_pair(attacker: Node3D, defender: Node3D) -> void:
	attacker.global_transform = _pair_transform
	defender.global_transform = _pair_transform.rotated_local(Vector3.UP, PI)

## Keeps both wrestlers' grip IK and grip countdown ticking while their own
## _physics_process is suspended.
##
## _suspend() switches physics processing off on both bodies for the whole
## paired move, which is exactly the stretch during which the grip targets
## most need to follow the opponent -- he is being lifted and thrown through
## a metre of arc. Without this the IK freezes on the pose and target it held
## at the last tie-up tick and the hands stay pointed at where the opponent
## used to be, for the whole throw. GrappleRig is not itself suspended, so it
## drives the pair's presentation the same way it drives their transforms.
func _physics_process(_delta: float) -> void:
	if not _active:
		return
	for body: Node3D in [_attacker, _defender]:
		if body and body.has_method("update_paired_presentation"):
			body.update_paired_presentation()

func _suspend(body: CharacterBody3D) -> void:
	if body:
		body.set_physics_process(false)

func _resume(body: CharacterBody3D) -> void:
	if body:
		body.set_physics_process(true)

func _on_animation_finished(_anim_name: StringName) -> void:
	_apply_root_motion()
	_restore_original_animation()
	_level_bodies()
	_separate_bodies()
	_resume(_attacker_body)
	_resume(_defender_body)
	_active = false
	grapple_finished.emit(_attacker, _defender)

## Push the pair apart to at least their combined capsule radii before physics
## resumes.
##
## The paired clips animate root position/rotation directly and are authored
## for how the *move* should look, not for where two solid bodies can legally
## stand: measured, 4 of the 5 clips finish with the wrestlers closer together
## than one capsule diameter (0.8m) -- signature_backbreaker ends 0.28m apart,
## finisher_piledriver 0.14m. Physics is suspended for the whole move, so
## nothing notices until _resume(), at which point Jolt resolves the
## interpenetration the only way it can and the defender climbs on top of the
## attacker -- confirmed live as the defender resting at y=0.4 (exactly one
## capsule radius) for 85% of a match, visibly hovering above the mat.
##
## Fixed here rather than by hand-editing four sets of end keyframes so it
## also covers the 13 paired moves still to be authored.
## Stand both bodies back up before physics resumes, keeping only their yaw.
##
## A paired clip rotates the CharacterBody3D root, and the collision capsule
## is rigidly attached to it -- so a clip that ends with the thrown wrestler
## on his back (grapple_suplex finishes at pitch 90deg, measured) leaves an
## upright capsule lying horizontal, half of it below the mat. The floor then
## depenetrates it upward by exactly one radius: confirmed live, the defender
## popped from y=0 to y=0.400127 over three ticks with zero velocity, the
## contact normal straight up and the collider named "Floor".
##
## The fix is to treat lying down as a *pose*, not a body orientation. The
## physics capsule is always an upright cylinder-ish volume; a downed
## wrestler reads as downed because DOWN's animation clip puts him there.
## Note README already records the same mechanism biting reversal_counter,
## where it was worked around by re-authoring that one clip to recover
## upright; this handles it for every clip, including the 13 unwritten ones.
func _level_bodies() -> void:
	for body: CharacterBody3D in [_attacker_body, _defender_body]:
		if not body:
			continue
		# Rebuild the basis from yaw alone. Reading rotation.y off a basis
		# that's pitched 90deg is unreliable (gimbal-degenerate), so recover
		# the facing from where the body's forward axis points in the XZ
		# plane instead.
		var forward: Vector3 = -body.global_transform.basis.z
		forward.y = 0.0
		if forward.length() < 0.001:
			# Forward is straight up/down (exactly the pitched-over case) --
			# the body's own up axis is then the horizontal facing.
			forward = body.global_transform.basis.y
			forward.y = 0.0
		if forward.length() < 0.001:
			continue
		body.global_transform = Transform3D(
			Basis(Vector3.UP, atan2(-forward.x, -forward.z)),
			body.global_position
		)

## Clearance on top of the two radii. Landing them exactly tangent is not
## enough: measured, at exactly 0.8m apart the defender still climbed to
## y=0.4 over three ticks. move_and_slide() treats the shallow upper part of
## the attacker's lower capsule cap as walkable floor (it's inside
## floor_max_angle), so the defender walks *up* the cap and comes to rest on
## the tangent where cap meets cylinder -- which is exactly one radius up.
const SEPARATION_MARGIN := 0.15

func _separate_bodies() -> void:
	if not _attacker_body or not _defender_body:
		return
	var min_separation := _capsule_radius(_attacker_body) \
			+ _capsule_radius(_defender_body) + SEPARATION_MARGIN
	var offset := _defender_body.global_position - _attacker_body.global_position
	offset.y = 0.0
	if offset.length() < 0.001:
		# Exactly coincident: no separation axis to preserve, so put the
		# defender in front of the attacker rather than picking arbitrarily.
		offset = -_attacker_body.global_transform.basis.z
		offset.y = 0.0
	if offset.length() < 0.001:
		return # attacker somehow facing straight up/down; leave it alone
	if offset.length() >= min_separation:
		return
	var pushed := _attacker_body.global_position + offset.normalized() * min_separation
	# Y is whatever the clip ended on -- only the horizontal overlap is the
	# problem, and rewriting height here would undo a legitimate landing pose.
	_defender_body.global_position = Vector3(
		pushed.x, _defender_body.global_position.y, pushed.z
	)

static func _capsule_radius(body: CharacterBody3D) -> float:
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			return (child.shape as CapsuleShape3D).radius
	return 0.4

func _apply_root_motion() -> void:
	if not animation_player or not animation_player.has_animation(_move.animation_pair_id if _move else &""):
		return
	var root_delta := animation_player.get_root_motion_position()
	if _attacker_body:
		_attacker_body.global_position += _attacker_body.global_transform.basis * root_delta

func is_active() -> bool:
	return _active
