class_name Inertializer
extends SkeletonModifier3D
## Clip switches without the crossfade (gauntlet/refs/animation_gap.md,
## Phase 3 "transitions").
##
## A crossfade plays the old clip and the new one at once and averages them:
## for its whole length the man is in neither pose, a mush of both -- a punch
## half thrown while he is already reeling from the counter. Inertialization
## is what current games do instead (Bollo, "Inertialization: High-Performance
## Animation Transitions in Gears of War", GDC 2018). The new clip plays from
## its first frame at once; what is carried over is only the DIFFERENCE
## between the pose that was on screen and the one the new clip starts in, and
## that difference fades to nothing over a few ticks. On the first frame he is
## exactly where he was, so nothing pops; from then on he is moving the way
## the new clip moves, so nothing mushes.
##
## The difference is taken per bone, in the bone's own space: a rotation for
## every bone and a translation for those the clips move (the pelvis). It
## fades on Bollo's quintic, which starts at the difference AND at the speed
## the bone was already moving -- a running arm swinging forward keeps
## swinging into the walk rather than stopping dead on the switch tick -- and
## arrives at nothing with no speed and no acceleration. A bone that was
## moving AWAY from the new pose starts from rest instead, so the fade never
## overshoots.
##
## It runs FIRST among the skeleton's modifiers -- the animation layer only.
## The grip IK, FootPlant and the eyes then work on top of the smoothed pose,
## as they did on the clip's.
##
## Presentation only: it moves bones on the model and reads nothing back into
## the match, so the replay hash cannot see it (ARCHITECTURE.md).

## Past this the whole pose is cut, not carried (see _capture): a man turned round on the mat, or
## an entrance clip that faces the other way, changes them by half a turn on
## purpose, and fading that out spins him on the spot. Only the root and the
## bone under it: a limb can legitimately change more than this between two
## clips -- a running arm hangs, a stalking one is up in a guard -- and it
## was cutting exactly those that made RUN > LOCOMOTION pop 1.2 m.
const MAX_CARRY := deg_to_rad(100.0)

var _bones := 0
var _start := 0
var _active := false
var _ticks := 9
var _playback: AnimationNodeStateMachinePlayback
var _machine: AnimationNodeStateMachine
## The switch window: requests open it, and any clip change the mixer shows
## inside it is carried.
var _asked := -1000
## What the mixer was playing on its last tick, to see a switch land.
var _last_node := StringName()
var _last_clip := StringName()
var _last_time := 0.0
## What was drawn on the last two mixer ticks: where each bone was, and so
## how fast it was going.
var _drawn_rot: Array[Quaternion] = []
var _drawn_pos: Array[Vector3] = []
var _prior_rot: Array[Quaternion] = []
var _prior_pos: Array[Vector3] = []
## Per bone, the carried difference as a direction and a fade curve along it:
## the rotation's axis and the translation's direction, each with Bollo's
## coefficients [x0, v0, a0, A, B, C, t1] in radians or metres, and ticks.
var _rot_axis: Array[Vector3] = []
var _pos_dir: Array[Vector3] = []
var _rot_curve: Array[PackedFloat32Array] = []
var _pos_curve: Array[PackedFloat32Array] = []
var _longest := 0.0

## --- Hit-stop ---------------------------------------------------------------
## The drawn pose held still while the clip runs on underneath, then carried
## into wherever the clip has got to. Holding the clip itself -- the tree
## switched off, or its clock stopped -- reset its state machine: the man came
## out of the freeze playing nothing for the rest of his reaction.
var _freeze_until := -1
var _frozen_rot: Array[Quaternion] = []
var _frozen_pos: Array[Vector3] = []
## Ticks to carry the held pose back into the clip.
const UNFREEZE_TICKS := 5

## --- Facing ---------------------------------------------------------------
## The body's own turn, carried the same way. Facing is gameplay -- it decides
## whether a strike lands -- and the match snaps it: look_at() on the way he
## is running turns him half round in one tick at the ropes, and back again
## as he slows to a walk (transition_pops --world: 2.3 m at a hand on RUN <>
## LOCOMOTION). The body keeps its snap; the drawn man turns into it.
var body: Node3D
var _last_yaw := NAN
var _last_origin := Vector3.ZERO
var _skip_turn := false
var _yaw_sign := 1.0
var _yaw_curve := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0])
var _yaw_start := 0
## A turn faster than this per tick is a snap, not a turn: TURN_RATE_PER_TICK
## is 0.12 rad.
const SNAP_YAW := 0.2
## A body moved further than this in a tick was placed, not turned.
const TELEPORT := 0.5

## Hold the pose on screen for `ticks` physics ticks (hit-stop).
func freeze(ticks: int) -> void:
	if ticks <= 0 or _bones == 0:
		return
	if _freeze_until < 0:
		_frozen_rot = _drawn_rot.duplicate()
		_frozen_pos = _drawn_pos.duplicate()
	_freeze_until = maxi(_freeze_until, Engine.get_physics_frames() + ticks)


func is_frozen() -> bool:
	return _freeze_until >= 0


## The next snap of the body's facing is meant to show at once: the man being
## turned round on the mat, whose pose flips with him.
func skip_next_turn() -> void:
	_skip_turn = true


## How long a snap of `angle` radians takes to turn out, in ticks: quick for
## a small one, about a quarter of a second for half a turn.
static func turn_ticks(angle: float) -> float:
	return 4.0 + 10.0 * absf(angle) / PI


## How long after a request a switch may land and still be carried, in ticks.
const PENDING_TICKS := 3


## The mixer whose output this smooths, and the state machine that switches
## it.
##
## A switch is carried on the mixer tick it LANDS on, seen from the mixer's
## side -- a different state, a different clip in it, or the clip back at its
## start -- not on the tick it was asked for. Measured
## (tools/probe/transition_pops.tscn): a travel() with no crossfade can land a
## tick late, and a state can be restarted on the tick after it is entered.
## Taken on the request, the difference was the old clip against itself,
## nothing was carried, and the new clip popped in a tick later -- 0.5 m at a
## foot on RUN > LOCOMOTION.
func watch(mixer: AnimationMixer, playback: AnimationNodeStateMachinePlayback) -> void:
	_playback = playback
	if mixer is AnimationTree:
		_machine = (mixer as AnimationTree).tree_root as AnimationNodeStateMachine
	if not mixer.mixer_applied.is_connected(_on_mixer_applied):
		mixer.mixer_applied.connect(_on_mixer_applied)


func is_blending() -> bool:
	return _active


## The clip is about to switch: carry the pose on screen into the new one over
## `ticks` physics ticks, when the switch lands.
func inertialize(ticks: int, _target := StringName()) -> void:
	if ticks <= 0:
		return
	_ticks = ticks
	_asked = Engine.get_physics_frames()


## Ticks since the carried difference was taken, fraction included.
func _elapsed() -> float:
	return float(Engine.get_physics_frames() - _start) + Engine.get_physics_interpolation_fraction()


func _on_mixer_applied() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var fresh := _ensure(sk)
	var node := _playback.get_current_node() if _playback else StringName()
	var clip := StringName()
	if _machine and _machine.has_node(node) and _machine.get_node(node) is AnimationNodeAnimation:
		clip = (_machine.get_node(node) as AnimationNodeAnimation).animation
	var time := _playback.get_current_play_position() if _playback else 0.0
	# A state machine with no crossfade reports the new state at time 0 a tick
	# BEFORE it outputs it: that tick still shows the old pose, and the new
	# clip's first pose arrives on the next, at time 0 again. Measured on
	# GRAPPLE_HOLD > IDLE > LOCOMOTION. Both ticks count as landing; carrying
	# from what was drawn keeps the second capture continuous with the first.
	var restarting := time <= 1e-4 and _last_time <= 1e-4
	var switched := node != _last_node or clip != _last_clip \
			or time < _last_time - 1e-4 or restarting
	_last_node = node
	_last_clip = clip
	_last_time = time
	_track_facing()
	if _freeze_until >= 0:
		if Engine.get_physics_frames() < _freeze_until:
			# Held: what is drawn is the held pose, whatever the clip does.
			for b in _bones:
				_prior_rot[b] = _frozen_rot[b]
				_prior_pos[b] = _frozen_pos[b]
				_drawn_rot[b] = _frozen_rot[b]
				_drawn_pos[b] = _frozen_pos[b]
			return
		# Let go: carry the held pose into the clip as it is now.
		_freeze_until = -1
		_ticks = UNFREEZE_TICKS
		_capture(sk)
	elif not fresh and switched and Engine.get_physics_frames() - _asked <= PENDING_TICKS:
		_capture(sk)
	# What this tick will draw, for the next switch to start from.
	var t := float(Engine.get_physics_frames() - _start)
	for b in _bones:
		var rot := sk.get_bone_pose_rotation(b)
		var pos := sk.get_bone_pose_position(b)
		if _active:
			rot = _carried_rot(b, t) * rot
			pos += _carried_pos(b, t)
		_prior_rot[b] = _drawn_rot[b]
		_prior_pos[b] = _drawn_pos[b]
		_drawn_rot[b] = rot
		_drawn_pos[b] = pos


## The new clip's first pose is on the skeleton: carry the difference that
## turns it back into the pose last drawn, moving as that pose was moving.
func _capture(sk: Skeleton3D) -> void:
	_longest = 0.0
	# The hips turned by half a turn is the body being turned round on
	# purpose -- the man and his pose flip together, and on screen nothing
	# moves. Every other bone's difference is then relative to hips facing
	# the other way: carried, it swung his legs 0.67 m into the air as he
	# landed from a paired move. So a turn-round cuts the whole pose.
	for b in _bones:
		if _is_hips(sk, b):
			var hips := _drawn_rot[b] * sk.get_bone_pose_rotation(b).inverse()
			if absf(hips.w) < cos(MAX_CARRY * 0.5):
				_active = false
				return
	for b in _bones:
		var target := sk.get_bone_pose_rotation(b)
		var off := _drawn_rot[b] * target.inverse()
		if off.w < 0.0:
			off = -off
		var angle := off.get_angle()
		# A near-zero turn has no usable axis: carry nothing on it.
		var axis := Vector3(off.x, off.y, off.z)
		if axis.length() < 1e-6:
			axis = Vector3.UP
			angle = 0.0
		axis = axis.normalized()
		# How fast the drawn bone was turning, per tick, about that axis --
		# positive is away from the new pose.
		var spin := _drawn_rot[b] * _prior_rot[b].inverse()
		if spin.w < 0.0:
			spin = -spin
		var omega := spin.get_axis() * spin.get_angle() if spin.get_angle() > 1e-6 else Vector3.ZERO
		_rot_axis[b] = axis
		_rot_curve[b] = _bollo(angle, omega.dot(axis), float(_ticks))
		var dp := _drawn_pos[b] - sk.get_bone_pose_position(b)
		var dist := dp.length()
		var dir := dp / dist if dist > 1e-6 else Vector3.UP
		_pos_dir[b] = dir
		_pos_curve[b] = _bollo(dist, (_drawn_pos[b] - _prior_pos[b]).dot(dir), float(_ticks))
		_longest = maxf(_longest, maxf(_rot_curve[b][6], _pos_curve[b][6]))
	_start = Engine.get_physics_frames()
	_active = true


## Bollo's inertialization curve for a difference x0 >= 0 moving at v0 per
## tick, gone in t1 ticks: [x0, v0, a0, A, B, C, t1].
static func _bollo(x0: float, v0: float, t1: float) -> PackedFloat32Array:
	if x0 < 1e-6:
		return PackedFloat32Array([0, 0, 0, 0, 0, 0, 0])
	# Moving away from the new pose: start from rest, or it overshoots.
	if v0 > 0.0:
		v0 = 0.0
	# Arriving faster than t1 allows: shorten it, as Bollo does.
	if v0 < 0.0:
		t1 = minf(t1, -5.0 * x0 / v0)
	var a0 := (-8.0 * v0 * t1 - 20.0 * x0) / (t1 * t1)
	var A := -(a0 * t1 * t1 + 6.0 * v0 * t1 + 12.0 * x0) / (2.0 * pow(t1, 5))
	var B := (3.0 * a0 * t1 * t1 + 16.0 * v0 * t1 + 30.0 * x0) / (2.0 * pow(t1, 4))
	var C := -(3.0 * a0 * t1 * t1 + 12.0 * v0 * t1 + 20.0 * x0) / (2.0 * pow(t1, 3))
	return PackedFloat32Array([x0, v0, a0, A, B, C, t1])


static func _eval(c: PackedFloat32Array, t: float) -> float:
	if c[0] <= 0.0 or t >= c[6]:
		return 0.0
	t = maxf(t, 0.0)
	return (((((c[3] * t + c[4]) * t + c[5]) * t + c[2] * 0.5) * t + c[1]) * t) + c[0]


func _carried_rot(b: int, t: float) -> Quaternion:
	var angle := _eval(_rot_curve[b], t)
	return Quaternion(_rot_axis[b], angle) if angle > 1e-6 else Quaternion.IDENTITY


func _carried_pos(b: int, t: float) -> Vector3:
	return _pos_dir[b] * _eval(_pos_curve[b], t)


func _track_facing() -> void:
	if body == null:
		return
	var fwd := -body.global_basis.z
	var yaw := atan2(fwd.x, fwd.z)
	var origin := body.global_position
	if not is_nan(_last_yaw):
		var d := wrapf(yaw - _last_yaw, -PI, PI)
		var placed := origin.distance_to(_last_origin) > TELEPORT
		if absf(d) > SNAP_YAW and not placed and not _skip_turn:
			# Draw him still facing where he was: whatever is still being
			# turned out, less this snap.
			var now := _yaw_sign * Inertializer._eval(_yaw_curve, float(Engine.get_physics_frames() - _yaw_start))
			var left := wrapf(now - d, -PI, PI)
			_yaw_sign = signf(left) if left != 0.0 else 1.0
			_yaw_curve = _bollo(absf(left), 0.0, turn_ticks(left))
			_yaw_start = Engine.get_physics_frames()
		if absf(d) > SNAP_YAW:
			_skip_turn = false
	_last_yaw = yaw
	_last_origin = origin


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _freeze_until >= 0 and _bones == sk.get_bone_count():
		for b in _bones:
			sk.set_bone_pose_rotation(b, _frozen_rot[b])
			sk.set_bone_pose_position(b, _frozen_pos[b])
		_apply_facing(sk)
		return
	_apply_facing(sk)
	if not _active or _bones != sk.get_bone_count():
		return
	var t := _elapsed()
	if t >= _longest:
		_active = false
		return
	for b in _bones:
		var rot := _carried_rot(b, t)
		if rot != Quaternion.IDENTITY:
			sk.set_bone_pose_rotation(b, rot * sk.get_bone_pose_rotation(b))
		var pos := _carried_pos(b, t)
		if pos != Vector3.ZERO:
			sk.set_bone_pose_position(b, sk.get_bone_pose_position(b) + pos)


## Turns the whole drawn body by what is left of a carried snap, about the
## vertical through the body's origin.
func _apply_facing(sk: Skeleton3D) -> void:
	if body == null or _yaw_curve[0] <= 0.0:
		return
	var t := float(Engine.get_physics_frames() - _yaw_start) + Engine.get_physics_interpolation_fraction()
	var angle := _yaw_sign * _eval(_yaw_curve, t)
	if absf(angle) < 1e-5:
		return
	var inv := sk.global_transform.affine_inverse()
	var up := (inv.basis * Vector3.UP).normalized()
	var pivot := inv * body.global_position
	var turn := Transform3D(Basis(up, angle), Vector3.ZERO)
	var about := Transform3D(Basis(), pivot) * turn * Transform3D(Basis(), -pivot)
	for b in sk.get_bone_count():
		if sk.get_bone_parent(b) < 0:
			sk.set_bone_global_pose(b, about * sk.get_bone_global_pose(b))


## Sizes the per-bone arrays to the skeleton; true when it had to, which means
## there is no last pose to carry from yet.
func _ensure(sk: Skeleton3D) -> bool:
	var n := sk.get_bone_count()
	if n == _bones:
		return false
	_bones = n
	for a: Array in [_drawn_rot, _prior_rot]:
		a.resize(n)
		a.fill(Quaternion.IDENTITY)
	for a: Array in [_drawn_pos, _prior_pos, _rot_axis, _pos_dir]:
		a.resize(n)
		a.fill(Vector3.ZERO)
	for a: Array in [_rot_curve, _pos_curve]:
		a.resize(n)
		a.fill(PackedFloat32Array([0, 0, 0, 0, 0, 0, 0]))
	_active = false
	return true


static func _is_hips(sk: Skeleton3D, bone: int) -> bool:
	var parent := sk.get_bone_parent(bone)
	return parent < 0 or sk.get_bone_parent(parent) < 0
