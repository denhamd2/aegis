class_name ReplayBuffer
extends Node
## The instant replay's memory (camera_aaa_plan.md C2): the last WINDOW
## seconds of how everyone in the ring LOOKED -- each body's transform and
## every bone's pose on every skeleton under it -- so the finish can be shown
## again from new angles at half speed.
##
## Presentation only. It reads poses after they are drawn and writes nothing
## while the match runs; playback happens after the bell, when the match is
## already frozen, and restore() puts every pose back exactly as it was. The
## deterministic replay system (core/replay) is a different thing: that
## records INPUTS to re-run a match; this records PICTURES to re-show one.

const WINDOW := 14.0
## Sampled at broadcast rate, not every frame: playback is at half speed and
## interpolation is not needed at this rate.
const RATE := 30.0

## [time, [per body: [global_transform, local model transform,
##   [per skeleton: [PackedVector3Array positions, PackedFloat32Array quats]]]]]
var _frames: Array = []
var _bodies: Array[Node3D] = []
var _skeletons: Array = []   # per body: Array[Skeleton3D]
var _clock := 0.0
var _marks := {}
var _playing := false
var _saved: Array = []
var _paused: Array = []
var _since := 0.0


func _ready() -> void:
	# Nobody watches a replay headless, and the probes run at thousands of
	# frames a second.
	if DisplayServer.get_name() == "headless":
		set_process(false)


func track(bodies: Array) -> void:
	for b: Node3D in bodies:
		if b == null:
			continue
		_bodies.append(b)
		var sks: Array[Skeleton3D] = []
		for sk in b.find_children("", "Skeleton3D", true, false):
			sks.append(sk)
		_skeletons.append(sks)


## Remember "now" under a name (the finisher starting, the cover).
func mark(what: String) -> void:
	_marks[what] = _clock


func mark_time(what: String) -> float:
	return float(_marks.get(what, -1.0))


func now() -> float:
	return _clock


func _process(delta: float) -> void:
	if _playing:
		return
	_clock += delta
	_since += delta
	if _since < 1.0 / RATE:
		return
	_since = 0.0
	_frames.append([_clock, _snapshot()])
	while not _frames.is_empty() and _clock - float(_frames[0][0]) > WINDOW:
		_frames.pop_front()


func _snapshot() -> Array:
	var bodies := []
	for i in _bodies.size():
		var b := _bodies[i]
		if not is_instance_valid(b):
			bodies.append(null)
			continue
		var sk_poses := []
		for sk: Skeleton3D in _skeletons[i]:
			var pos := PackedVector3Array()
			var rot := PackedFloat32Array()
			pos.resize(sk.get_bone_count())
			rot.resize(sk.get_bone_count() * 4)
			for j in sk.get_bone_count():
				pos[j] = sk.get_bone_pose_position(j)
				var q := sk.get_bone_pose_rotation(j)
				rot[j * 4] = q.x
				rot[j * 4 + 1] = q.y
				rot[j * 4 + 2] = q.z
				rot[j * 4 + 3] = q.w
			sk_poses.append([pos, rot])
		bodies.append([b.global_transform, sk_poses])
	return bodies


func has_window(from: float, to: float) -> bool:
	return not _frames.is_empty() and float(_frames[0][0]) <= from + 0.05 \
			and float(_frames[-1][0]) >= to - 0.05


## Takes the stage: stops everything that animates the bodies, and saves
## how they are now so restore() can hand them back.
func begin_playback() -> void:
	if _playing:
		return
	_playing = true
	_saved = _snapshot()
	_paused.clear()
	for b in _bodies:
		if not is_instance_valid(b):
			continue
		for m in b.find_children("", "AnimationMixer", true, false):
			_paused.append([m, (m as AnimationMixer).active])
			(m as AnimationMixer).active = false
		_paused.append([b, b.is_processing(), b.is_physics_processing()])
		b.set_process(false)
		b.set_physics_process(false)


## Shows the moment `at` seconds on the buffer's clock.
func show(at: float) -> void:
	if _frames.is_empty():
		return
	var i := _frames.bsearch_custom(at, func(f, t): return float(f[0]) < float(t))
	i = clampi(i, 0, _frames.size() - 1)
	_apply(_frames[i][1])


func restore() -> void:
	if not _playing:
		return
	_apply(_saved)
	for p: Array in _paused:
		if p[0] is AnimationMixer:
			(p[0] as AnimationMixer).active = p[1]
		elif is_instance_valid(p[0]):
			(p[0] as Node).set_process(p[1])
			(p[0] as Node).set_physics_process(p[2])
	_paused.clear()
	_playing = false


func _apply(bodies: Array) -> void:
	for i in mini(bodies.size(), _bodies.size()):
		var b := _bodies[i]
		var data = bodies[i]
		if data == null or not is_instance_valid(b):
			continue
		b.global_transform = data[0]
		var sks: Array = _skeletons[i]
		for k in mini(sks.size(), (data[1] as Array).size()):
			var sk: Skeleton3D = sks[k]
			var pos: PackedVector3Array = data[1][k][0]
			var rot: PackedFloat32Array = data[1][k][1]
			for j in mini(sk.get_bone_count(), pos.size()):
				sk.set_bone_pose_position(j, pos[j])
				sk.set_bone_pose_rotation(j, Quaternion(rot[j * 4], rot[j * 4 + 1],
						rot[j * 4 + 2], rot[j * 4 + 3]))
