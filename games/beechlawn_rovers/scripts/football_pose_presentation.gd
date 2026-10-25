extends SkeletonModifier3D
class_name FootballPosePresentation
## Render between fixed-tick poses. Physics/contact readers use the retained
## tick pose; SkeletonModifier3D's temporary output is presentation only.
var skeleton: Skeleton3D
var body: Node3D
var tick_positions: Array[Vector3] = []
var tick_rotations: Array[Quaternion] = []
var tick_scales: Array[Vector3] = []
var tick_globals: Array[Transform3D] = []
var previous_positions: Array[Vector3] = []
var previous_rotations: Array[Quaternion] = []
var previous_scales: Array[Vector3] = []
var _tick := -1
var _origin := Vector3.ZERO
var _snap := true
var enabled := true

func watch(target: Skeleton3D, actor: Node3D, mixers: Array) -> void:
	skeleton = target
	body = actor
	for mixer: AnimationMixer in mixers:
		if not mixer.mixer_applied.is_connected(_capture): mixer.mixer_applied.connect(_capture)
	_capture()

func snap() -> void:
	_snap = true

func _capture() -> void:
	if not is_instance_valid(skeleton): return
	var frame := Engine.get_physics_frames()
	var new_tick := frame != _tick
	var placed := _snap or tick_positions.size() != skeleton.get_bone_count()
	placed = placed or body.global_position.distance_to(_origin) > 1.0
	# Explicit seek/prime outside the tick is a placement, not elapsed motion.
	placed = placed or not Engine.is_in_physics_frame()
	if new_tick:
		previous_positions = tick_positions.duplicate()
		previous_rotations = tick_rotations.duplicate()
		previous_scales = tick_scales.duplicate()
	tick_positions.clear(); tick_rotations.clear(); tick_scales.clear(); tick_globals.clear()
	for bone in skeleton.get_bone_count():
		tick_positions.append(skeleton.get_bone_pose_position(bone))
		tick_rotations.append(skeleton.get_bone_pose_rotation(bone))
		tick_scales.append(skeleton.get_bone_pose_scale(bone))
		tick_globals.append(skeleton.get_bone_global_pose(bone))
	if placed:
		previous_positions = tick_positions.duplicate()
		previous_rotations = tick_rotations.duplicate()
		previous_scales = tick_scales.duplicate()
	_tick = frame; _origin = body.global_position; _snap = false

func bone_world_position(bone: int) -> Vector3:
	if bone >= 0 and bone < tick_globals.size():
		return skeleton.global_transform * tick_globals[bone].origin
	return skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)

func draw_between(fraction: float) -> void:
	if previous_positions.size() != tick_positions.size(): return
	var f := clampf(fraction, 0, 1)
	for bone in tick_positions.size():
		skeleton.set_bone_pose_position(bone, previous_positions[bone].lerp(tick_positions[bone], f))
		skeleton.set_bone_pose_rotation(bone, previous_rotations[bone].slerp(tick_rotations[bone], f))
		skeleton.set_bone_pose_scale(bone, previous_scales[bone].lerp(tick_scales[bone], f))

func _process_modification() -> void:
	if not enabled or not is_instance_valid(body) or not body.is_physics_interpolated_and_enabled(): return
	if tick_positions.size() == skeleton.get_bone_count():
		draw_between(Engine.get_physics_interpolation_fraction())
