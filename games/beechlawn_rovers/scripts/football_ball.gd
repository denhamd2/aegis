extends RigidBody3D
class_name FootballBall
## Free rolling size-five ball. Control assistance adds forces/impulses; it
## never parents or teleports the authoritative ball to a player's foot.

signal touched(kind: StringName, speed: float)
signal actor_touched(actor: Node3D, serial: int)
signal post_contact(point: Vector3, velocity: Vector3)
var _last_post_frame := -100
signal net_contact(body: Node3D, point: Vector3, velocity: Vector3)
var last_touch_player: Node3D
var _last_physical_actor: Node3D
var _last_net_frame := -100
var _velocity_before_contact := Vector3.ZERO

const RADIUS := 0.11
@export var tuning: FootballTuning
@export var use_terrain := false
var wet_surface: WetPitchSurface
var surface_wetness := 0.0
var last_touch: StringName = &"none"
var last_action: StringName = &"none"
var last_strike_part: StringName = &"foot"
var last_strike_style: StringName = &"standard"
var seconds_since_bounce := 99.0
var _curve_seconds := 0.0
var _curve_airborne := false
var action_serial := 0
var goalkeeper_holder: Node3D
var _dribble_cooldowns: Dictionary[int, float] = {}
var _holder_collision_exception: PhysicsBody3D
var _dribble_controller: Node3D
var _dribble_force_frame := -1
var _kick_control_release := 0.0
var _dribble_control_lease := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 5
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
	seconds_since_bounce = minf(99, seconds_since_bounce + delta)
	_curve_seconds = maxf(0, _curve_seconds - delta)
	_kick_control_release = maxf(0.0, _kick_control_release - delta)
	_dribble_control_lease = maxf(0.0, _dribble_control_lease - delta)
	if is_instance_valid(goalkeeper_holder):
		var forward := -goalkeeper_holder.global_basis.z
		forward.y = 0.0
		var hold_target := goalkeeper_holder.global_position + Vector3.UP * 1.05 \
			+ forward.normalized() * 0.45
		var visual := goalkeeper_holder.get_node_or_null("Visual") as FootballerVisual
		if visual != null:
			var hands := visual.hand_positions()
			if hands.size()==2: hold_target=(hands[0]+hands[1])*.5+forward.normalized()*.10+Vector3.UP*.05
		var spring_force := ((hold_target - global_position) * 40.0 - linear_velocity * 12.0 + Vector3.UP*9.81) * mass
		apply_central_force(spring_force.limit_length(20.0))
	elif goalkeeper_holder != null:
		_release_goalkeeper_holder()
	# Editable ground resistance. The PhysicsMaterial handles surface collision,
	# bounce and contact friction; this small force prevents endless coasting.
	var ground_height := PitchSurface.height_at(global_position.x,global_position.z) if use_terrain else 0.0
	if global_position.y > ground_height + RADIUS + .035 and _curve_seconds > 0.0 and last_action == &"shot":
		_curve_airborne = true
		var curve_acceleration := (angular_velocity.cross(linear_velocity) * tuning.finesse_magnus).limit_length(3.5)
		apply_central_force(curve_acceleration * mass)
	if global_position.y <= ground_height + RADIUS + 0.035:
		if _curve_airborne: _curve_seconds = 0.0
		var horizontal := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
		if wet_surface != null and not is_instance_valid(goalkeeper_holder):
			apply_central_force(wet_surface.drag_force(global_position, horizontal, mass, surface_wetness, delta))
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
	if is_instance_valid(goalkeeper_holder) \
			or global_position.y - player.global_position.y > tuning.dribble_max_height:
		return false
	var player_id := player.get_instance_id()
	var can_emit_touch: bool = _dribble_cooldowns.get(player_id, 0.0) <= 0.0
	var flat_delta := global_position - player.global_position
	flat_delta.y = 0.0
	if flat_delta.length() > 1.38:
		return false
	if not _within_dribble_touch_arc(player, flat_delta):
		return false
	var touch_team := StringName(player.get("team_name"))
	if _kick_control_release > 0.0 and touch_team == last_touch:
		return false
	# A fast shot remains a shot while it is travelling; close control should not
	# immediately absorb it and erase the goalkeeper's shot read.
	if last_action == &"shot" and last_touch == touch_team and linear_velocity.length() > 3.0:
		return false
	# A different team must make close physical contact to take the ball. This
	# keeps distant touch assistance from acting like an invisible tackle.
	if last_touch != &"none" and last_touch != touch_team and flat_delta.length() > 0.55:
		return false
	if not _claim_dribble_control(player, flat_delta.length()):
		return false
	var physics_frame := Engine.get_physics_frames()
	if _dribble_force_frame == physics_frame:
		return false
	_dribble_force_frame = physics_frame
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
	last_strike_part = &"foot"
	action_serial += 1
	record_touch(player)
	touched.emit(&"dribble", linear_velocity.length())
	return true

func _within_dribble_touch_arc(player: Node3D, offset: Vector3) -> bool:
	# A ball beneath the feet can be gathered from either side. Farther away,
	# the body must turn before a forward touch can reach behind it; otherwise
	# the spring pulls the ball through the capsule during a 180-degree turn.
	if offset.length_squared() <= 0.42 * 0.42:
		return true
	var forward := -player.global_basis.z
	forward.y = 0.0
	return offset.dot(forward.normalized()) >= -0.10

func _claim_dribble_control(player: Node3D, player_gap: float) -> bool:
	# Only one spring may act on the ball in a tick. Keep an established actor
	# stable; select the nearest plausible actor only when control is released.
	if _dribble_cooldowns.is_empty() or _dribble_control_lease <= 0.0:
		_dribble_controller = null
	if is_instance_valid(_dribble_controller):
		var owner_offset := global_position - _dribble_controller.global_position
		owner_offset.y = 0.0
		if owner_offset.length() > 1.38 or StringName(_dribble_controller.get("team_name")) != last_touch:
			_dribble_controller = null
		elif _dribble_controller != player:
			var same_team: bool = player.get("team_name") == _dribble_controller.get("team_name")
			if same_team or player_gap + 0.12 >= owner_offset.length():
				return false
			_dribble_controller = null
	if not is_instance_valid(_dribble_controller):
		var best := player
		var best_gap := player_gap
		var team_gaps := {StringName(player.get("team_name")): player_gap}
		for node in get_tree().get_nodes_in_group("football_players"):
			var candidate := node as FootballPlayer
			if candidate == null or candidate == player:
				continue
			var wants_moving_touch := candidate._stick.length_squared() > 0.0025
			var can_gather_stationary := candidate.velocity.length() < 0.45 and linear_velocity.length() < 0.7
			if not wants_moving_touch and not can_gather_stationary:
				continue
			if candidate.team_name == last_touch and (_kick_control_release > 0.0 \
					or (last_action == &"shot" and linear_velocity.length() > 3.0)):
				continue
			var offset := global_position - candidate.global_position
			if offset.y > tuning.dribble_max_height:
				continue
			offset.y = 0.0
			var gap := offset.length()
			if not _within_dribble_touch_arc(candidate, offset):
				continue
			if last_touch != &"none" and candidate.team_name != last_touch and gap > 0.55:
				continue
			team_gaps[candidate.team_name] = minf(float(team_gaps.get(candidate.team_name, INF)),gap)
			var same_team_tie := candidate.team_name == StringName(best.get("team_name")) and absf(gap-best_gap) < .001
			var best_footballer := best as FootballPlayer
			var candidate_slot := candidate.profile.starting_slot if candidate.profile != null else str(candidate.name)
			var best_slot := best_footballer.profile.starting_slot if best_footballer != null and best_footballer.profile != null else str(best.name)
			if gap < best_gap - .001 or (same_team_tie and candidate_slot < best_slot):
				best = candidate;best_gap = gap
		# Equal opposing reaches are a contest, not an award to the first node
		# processed. Physical contact/tackles or separation must resolve it.
		for team in team_gaps:
			if team != StringName(best.get("team_name")) and absf(float(team_gaps[team])-best_gap) <= .03:
				return false
		_dribble_controller = best

	if _dribble_controller == player:
		_dribble_control_lease = 0.12
	return _dribble_controller == player

func kick(direction: Vector3, speed: float, lift: float, kind: StringName,
		touch_team: StringName = &"Beechlawn Rovers", actor: Node3D = null,
		part: StringName = &"foot", style: StringName = &"standard",
		spin: Vector3 = Vector3.ZERO) -> bool:
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
	last_strike_style = style
	seconds_since_bounce = 99.0
	_curve_seconds = 2.0 if style == &"finesse" else 0.0
	_curve_airborne = false
	_velocity_before_contact = target_velocity
	if spin.length_squared() > .01:
		apply_torque_impulse((spin - angular_velocity) * sphere_inertia)
	last_strike_part = part
	if actor != null: record_touch(actor)
	else: last_touch_player = null
	action_serial += 1
	_dribble_cooldowns.clear()
	_dribble_controller = null
	_kick_control_release = tuning.kick_control_release_seconds
	touched.emit(kind, speed)
	return true

func kick_velocity(target_velocity: Vector3, kind: StringName, touch_team: StringName,
		actor: Node3D, part: StringName = &"foot", style: StringName = &"standard") -> bool:
	if not target_velocity.is_finite() or target_velocity.length() > 38.0:
		return false
	# The ballistic solver specifies absolute launch velocity. Compensate for
	# the inherited-momentum term in kick(), retaining its single real impulse,
	# ownership, rules, audio and control-release path without repositioning.
	var strike := target_velocity - linear_velocity * 0.16
	var flat := Vector3(strike.x, 0, strike.z)
	if not kick(flat.normalized(), flat.length(), strike.y, kind, touch_team, actor, part, style):
		return false
	# Air strikes carry modest spin rather than the ground kick's no-slip roll.
	var axis := Vector3(target_velocity.z, 0, -target_velocity.x).normalized()
	var inertia := 0.4 * mass * RADIUS * RADIUS
	apply_torque_impulse((axis * (28.0 if part == &"foot" else 8.0) - angular_velocity) * inertia)
	return true

func tackle_touch(player: Node3D, direction: Vector3, speed: float) -> bool:
	if not is_instance_valid(player) or direction.length_squared() < 0.01 or speed <= 0.0:
		return false
	var target_velocity := direction.normalized() * speed + Vector3.UP * 0.55 + linear_velocity * 0.12
	apply_central_impulse((target_velocity - linear_velocity) * mass)
	last_touch = StringName(player.get("team_name"))
	last_action = &"tackle"
	last_strike_part = &"foot"
	action_serial += 1
	_dribble_cooldowns.clear()
	record_touch(player)
	touched.emit(&"tackle", speed)
	return true

func receive_touch(player: Node3D, contact_position: Vector3,
		preferred_direction: Vector3) -> bool:
	if not is_instance_valid(player) or last_action not in [&"pass", &"through_pass", &"lofted_pass", &"cross", &"header_clearance"]:
		return false
	var touch_team := StringName(player.get("team_name"))
	if last_touch != touch_team or global_position.distance_to(contact_position) > 0.20 \
			or global_position.y > RADIUS + 0.16:
		return false
	var incoming := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if incoming.length() < 0.35:
		return false
	var actor_velocity := Vector3.ZERO
	if player is CharacterBody3D:
		actor_velocity = Vector3((player as CharacterBody3D).velocity.x, 0.0,
			(player as CharacterBody3D).velocity.z)
	var outlet := preferred_direction
	if outlet.length_squared() > 0.01:
		outlet = outlet.normalized() * 0.65
	else:
		outlet = Vector3.ZERO
	# A first touch cushions the pass while preserving some travel and the
	# player's intent. It changes velocity through an impulse; the ball stays
	# independent and the animation marker never sets its position.
	var target_velocity := (incoming * 0.28 + actor_velocity * 0.32 + outlet).limit_length(4.2)
	target_velocity.y = clampf(linear_velocity.y * 0.12, -0.45, 0.25)
	apply_central_impulse((target_velocity - linear_velocity) * mass)
	last_touch = touch_team
	last_action = &"first_touch"
	last_strike_part = &"foot"
	action_serial += 1
	_dribble_cooldowns.clear()
	record_touch(player)
	touched.emit(&"first_touch", target_velocity.length())
	return true

func goalkeeper_save(player: Node3D, direction: Vector3, speed: float, lift: float) -> bool:
	if not is_instance_valid(player) or direction.length_squared() < 0.01 or speed <= 0.0:
		return false
	var target_velocity := direction.normalized() * speed + Vector3.UP * lift
	apply_central_impulse((target_velocity - linear_velocity) * mass)
	last_touch = StringName(player.get("team_name"))
	last_action = &"goalkeeper_save"
	last_strike_part = &"hands"
	action_serial += 1
	_dribble_cooldowns.clear()
	_dribble_controller = null
	# Let a parry escape the keeper's close-control spring. Opponents may still
	# attack the rebound immediately, just as after an ordinary physical kick.
	_kick_control_release = tuning.kick_control_release_seconds
	record_touch(player)
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
	last_strike_part = &"hands"
	action_serial += 1
	_dribble_cooldowns.clear()
	record_touch(player)
	touched.emit(&"goalkeeper_catch", linear_velocity.length())
	return true

func goalkeeper_is_holding(player: Node3D) -> bool:
	return is_instance_valid(goalkeeper_holder) and goalkeeper_holder == player

func goalkeeper_distribute(player: PhysicsBody3D, direction: Vector3, speed: float,
		lift: float) -> bool:
	if not goalkeeper_is_holding(player):
		return false
	_release_goalkeeper_holder()
	return kick(direction, speed, lift, &"goalkeeper_distribution", StringName(player.get("team_name")),player)

func _release_goalkeeper_holder() -> void:
	if is_instance_valid(_holder_collision_exception):
		remove_collision_exception_with(_holder_collision_exception)
	_holder_collision_exception = null
	goalkeeper_holder = null

func record_touch(actor: Node3D) -> void:
	last_touch_player=actor
	last_touch=StringName(actor.get("team_name"))
	actor_touched.emit(actor,action_serial)

func release_for_restart() -> void:
	_curve_seconds = 0.0
	seconds_since_bounce = 99.0
	_release_goalkeeper_holder()
	linear_velocity=Vector3.ZERO; angular_velocity=Vector3.ZERO
	_dribble_controller=null; _dribble_cooldowns.clear()
	_dribble_control_lease=0; _kick_control_release=0
	last_touch_player=null; _last_physical_actor=null

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var ground := PitchSurface.height_at(global_position.x, global_position.z) if use_terrain else 0.0
	var ground_contact := false
	for index in state.get_contact_count():
		var normal := state.get_contact_local_normal(index)
		if normal.y > .6: ground_contact = true
	if ground_contact and global_position.y < ground + RADIUS + .12 and _velocity_before_contact.y < -1.0 and state.linear_velocity.y > .2:
		seconds_since_bounce = 0.0
	var physical_actor: Node3D
	for index in state.get_contact_count():
		var body := state.get_contact_collider_object(index) as Node3D
		if body == null: continue
		if body.has_meta("goal_net_end") and Engine.get_physics_frames()-_last_net_frame>3:
			_last_net_frame=Engine.get_physics_frames()
			net_contact.emit(body,state.get_contact_collider_position(index),_velocity_before_contact)
		elif body.has_meta("goal_frame") and Engine.get_physics_frames()-_last_post_frame>6:
			_last_post_frame=Engine.get_physics_frames()
			post_contact.emit(state.get_contact_collider_position(index),_velocity_before_contact)
		elif body is FootballPlayer:
			physical_actor=body
			if body!=_last_physical_actor and (body!=last_touch_player or _kick_control_release<=0):
				action_serial+=1
				record_touch(body)
	_last_physical_actor=physical_actor
	_velocity_before_contact=state.linear_velocity
