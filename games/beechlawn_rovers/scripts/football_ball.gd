extends RigidBody3D
class_name FootballBall
## Free rolling size-five ball. Control assistance adds forces/impulses; it
## never parents or teleports the authoritative ball to a player's foot.

signal touched(kind: StringName, speed: float)

const RADIUS := 0.11
@export var tuning: FootballTuning
var last_touch: StringName = &"none"
var last_action: StringName = &"none"
var action_serial := 0
var goalkeeper_holder: Node3D
var _dribble_cooldowns: Dictionary[int, float] = {}
var _holder_collision_exception: PhysicsBody3D

func _ready() -> void:
	if tuning == null:
		tuning = FootballTuning.new()
	mass = 0.43
	continuous_cd = true
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 8
	linear_damp = 0.07
	angular_damp = 0.035

func _physics_process(delta: float) -> void:
	if is_instance_valid(goalkeeper_holder):
		var forward := -goalkeeper_holder.global_basis.z
		forward.y = 0.0
		var hold_target := goalkeeper_holder.global_position + Vector3.UP * 1.05 \
			+ forward.normalized() * 0.32
		var spring_force := ((hold_target - global_position) * 28.0 - linear_velocity * 9.0) * mass
		apply_central_force(spring_force.limit_length(20.0))
	elif goalkeeper_holder != null:
		_release_goalkeeper_holder()
	# Editable ground resistance. The PhysicsMaterial handles surface collision,
	# bounce and contact friction; this small force prevents endless coasting.
	if global_position.y <= RADIUS + 0.035:
		var horizontal := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
		if horizontal.length_squared() > 0.0025:
			apply_central_force(-horizontal.normalized() * minf(
				horizontal.length() * tuning.ground_rolling_resistance,
				tuning.ground_rolling_force_limit))
	for player_id in _dribble_cooldowns.keys():
		_dribble_cooldowns[player_id] = maxf(0.0, _dribble_cooldowns[player_id] - delta)

func dribble_touch(player: Node3D, move_direction: Vector3, sprinting: bool,
		close_control: bool, interval: float, close_distance: float,
		sprint_distance: float) -> bool:
	if not is_instance_valid(player):
		return false
	var player_id := player.get_instance_id()
	var can_emit_touch: bool = _dribble_cooldowns.get(player_id, 0.0) <= 0.0
	var flat_delta := global_position - player.global_position
	flat_delta.y = 0.0
	if flat_delta.length() > 1.38:
		return false
	var touch_team := StringName(player.get("team_name"))
	# A fast shot remains a shot while it is travelling; close control should not
	# immediately absorb it and erase the goalkeeper's shot read.
	if last_action == &"shot" and last_touch == touch_team and linear_velocity.length() > 3.0:
		return false
	# A different team must make close physical contact to take the ball. This
	# keeps distant touch assistance from acting like an invisible tackle.
	if last_touch != &"none" and last_touch != touch_team and flat_delta.length() > 0.55:
		return false
	var direction := move_direction.normalized() if move_direction.length_squared() > 0.01 else Vector3.ZERO
	if direction == Vector3.ZERO:
		direction = -player.global_basis.z
		direction.y = 0.0
		direction = direction.normalized()
	var distance := close_distance if close_control else (sprint_distance if sprinting else 0.70)
	var target := player.global_position + direction * distance
	target.y = RADIUS
	var correction := target - global_position
	var desired_velocity := direction * (2.4 if close_control else (4.5 if sprinting else 3.1))
	# Capped control force keeps the ball independent and lets hard touches,
	# tackles and sprint turns break possession naturally.
	var force := (correction * 19.0 + (desired_velocity - linear_velocity) * 2.1)
	force.y = 0.0
	apply_central_force(force.limit_length(22.0))
	# Apply the capped spring force on every in-range physics call. The cooldown
	# throttles touch events/ownership updates, not possession assistance.
	if not can_emit_touch:
		return false
	_dribble_cooldowns[player_id] = interval * (1.35 if sprinting else (0.8 if close_control else 1.0))
	last_touch = touch_team
	last_action = &"dribble"
	action_serial += 1
	touched.emit(&"dribble", linear_velocity.length())
	return true

func kick(direction: Vector3, speed: float, lift: float, kind: StringName,
		touch_team: StringName = &"Beechlawn Rovers") -> bool:
	if direction.length_squared() < 0.01 or speed <= 0.0:
		return false
	var velocity_before := linear_velocity
	var impulse_velocity := direction.normalized() * speed + Vector3.UP * lift
	# Replace some of a slowly rolling ball's component, but preserve spin and
	# useful travelling momentum. A pass is an impulse, never a position snap.
	var target_velocity := impulse_velocity + velocity_before * 0.16
	var delta_velocity := target_velocity - linear_velocity
	apply_central_impulse(delta_velocity * mass)
	# Seed ground-bound kicks with the angular velocity for forward rolling
	# contact. The sign matters: for a +X ball, forward rolling is -Z spin.
	var roll_axis := Vector3(direction.z, 0.0, -direction.x).normalized()
	var sphere_inertia := 0.4 * mass * RADIUS * RADIUS
	apply_torque_impulse(roll_axis * sphere_inertia * (speed / RADIUS))
	last_touch = touch_team
	last_action = kind
	action_serial += 1
	_dribble_cooldowns.clear()
	touched.emit(kind, speed)
	return true

func tackle_touch(player: Node3D, direction: Vector3, speed: float) -> bool:
	if not is_instance_valid(player) or direction.length_squared() < 0.01 or speed <= 0.0:
		return false
	var target_velocity := direction.normalized() * speed + Vector3.UP * 0.55 + linear_velocity * 0.12
	apply_central_impulse((target_velocity - linear_velocity) * mass)
	last_touch = StringName(player.get("team_name"))
	last_action = &"tackle"
	action_serial += 1
	_dribble_cooldowns.clear()
	touched.emit(&"tackle", speed)
	return true

func goalkeeper_save(player: Node3D, direction: Vector3, speed: float, lift: float) -> bool:
	if not is_instance_valid(player) or direction.length_squared() < 0.01 or speed <= 0.0:
		return false
	var target_velocity := direction.normalized() * speed + Vector3.UP * lift
	apply_central_impulse((target_velocity - linear_velocity) * mass)
	last_touch = StringName(player.get("team_name"))
	last_action = &"goalkeeper_save"
	action_serial += 1
	_dribble_cooldowns.clear()
	touched.emit(&"goalkeeper_save", speed)
	return true

func goalkeeper_claim(player: PhysicsBody3D) -> bool:
	if not is_instance_valid(player) or goalkeeper_holder != null:
		return false
	goalkeeper_holder = player
	_holder_collision_exception = player
	add_collision_exception_with(player)
	apply_central_impulse(-linear_velocity * mass * 0.88)
	apply_torque_impulse(-angular_velocity * mass * 0.65)
	last_touch = StringName(player.get("team_name"))
	last_action = &"goalkeeper_catch"
	action_serial += 1
	_dribble_cooldowns.clear()
	touched.emit(&"goalkeeper_catch", linear_velocity.length())
	return true

func goalkeeper_is_holding(player: Node3D) -> bool:
	return is_instance_valid(goalkeeper_holder) and goalkeeper_holder == player

func goalkeeper_distribute(player: PhysicsBody3D, direction: Vector3, speed: float,
		lift: float) -> bool:
	if not goalkeeper_is_holding(player):
		return false
	_release_goalkeeper_holder()
	return kick(direction, speed, lift, &"goalkeeper_distribution", StringName(player.get("team_name")))

func _release_goalkeeper_holder() -> void:
	if is_instance_valid(_holder_collision_exception):
		remove_collision_exception_with(_holder_collision_exception)
	_holder_collision_exception = null
	goalkeeper_holder = null
