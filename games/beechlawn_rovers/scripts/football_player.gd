extends CharacterBody3D
class_name FootballPlayer
## Responsive 60 Hz locomotion and buffered ball actions for the M1 prototype.

signal status_changed(message: String)
signal shot_charge_changed(amount: float)
signal foul_committed(player: FootballPlayer, opponent: FootballPlayer)

@export var tuning: FootballTuning
@export var attack_sign := 1.0
@export var controlled_by_human := true
@export var team_name: StringName = &"Beechlawn Rovers"
@export var profile: FootballerProfile

@onready var ball: FootballBall = get_node("../Ball")
@onready var camera: Camera3D = get_node("../BroadcastCamera/Camera3D")

var stamina := 100.0
var _stick := Vector2.ZERO
var _aim := Vector2.ZERO
var _flat_direction := Vector3(1.0, 0.0, 0.0)
var _shot_charge := -1.0
var _pending_pass: float = 0.0
var _pending_through := false
var _pending_shot: float = 0.0
var _leg_time := 0.0
var _debug := false
var _kick_time := -1.0
var _kick_duration := 0.0
var _kick_side := 1.0
var _tackle_cooldown := 0.0
var _slide_tackle_time := 0.0
var _slide_contact_time := 0.0
var _slide_tackle_direction := Vector3.ZERO
var _slide_contact_pending := false
var _shoulder_cooldown := 0.0
var _balance_stagger_time := 0.0
var _balance_stagger_direction := Vector3.ZERO
var _save_pose_time := 0.0
var _goalkeeper_controller: GoalkeeperController
var ai_move_direction := Vector3.ZERO
var ai_sprinting := false
var ai_action_cooldown := 0.0
var receive_target := Vector3.ZERO
var receive_target_time := 0.0
var _ignore_pass_until_released := false
var _footballer_visual: FootballerVisual
var _visual_pass_pending := false
var _visual_pass_through := false
var _visual_pass_direction := Vector3.ZERO
var _visual_shot_pending := false
var _visual_shot_direction := Vector3.ZERO
var _visual_shot_speed := 0.0
var _visual_shot_lift := 0.0
var _last_receive_action_serial := -1

func _ready() -> void:
	if tuning == null:
		tuning = FootballTuning.new()
	if profile == null:
		rotation.y = -PI * 0.5 * attack_sign
	elif profile.role == "goalkeeper":
		_goalkeeper_controller = GoalkeeperController.new()
		_goalkeeper_controller.configure(self, ball)
	var visual := get_node_or_null("Visual") as FootballerVisual
	if visual != null:
		bind_footballer_visual(visual)


func bind_footballer_visual(visual: FootballerVisual) -> void:
	if is_instance_valid(_footballer_visual):
		if _footballer_visual.action_contact.is_connected(_on_visual_action_contact):
			_footballer_visual.action_contact.disconnect(_on_visual_action_contact)
		if _footballer_visual.action_finished.is_connected(_on_visual_action_finished):
			_footballer_visual.action_finished.disconnect(_on_visual_action_finished)
	_footballer_visual = visual
	if is_instance_valid(_footballer_visual):
		_footballer_visual.jog_reference_speed = tuning.jog_speed
		_footballer_visual.sprint_reference_speed = tuning.sprint_speed
		_footballer_visual.action_contact.connect(_on_visual_action_contact)
		_footballer_visual.action_finished.connect(_on_visual_action_finished)

func _physics_process(delta: float) -> void:
	receive_target_time = maxf(0.0, receive_target_time - delta)
	ai_action_cooldown = maxf(0.0, ai_action_cooldown - delta)
	_tackle_cooldown = maxf(0.0, _tackle_cooldown - delta)
	_shoulder_cooldown = maxf(0.0, _shoulder_cooldown - delta)
	_balance_stagger_time = maxf(0.0, _balance_stagger_time - delta)
	if _slide_tackle_time > 0.0:
		_slide_tackle_time = maxf(0.0, _slide_tackle_time - delta)
	if _slide_contact_pending:
		_slide_contact_time -= delta
		if _slide_contact_time <= 0.0:
			_resolve_slide_tackle_contact()
	_save_pose_time = maxf(0.0, _save_pose_time - delta)
	_sample_input()
	if _goalkeeper_controller != null:
		_goalkeeper_controller.update_before_move(delta)
		if ball.goalkeeper_is_holding(self):
			_stick = Vector2.ZERO
	_update_locomotion(delta)
	move_and_slide()
	if ball.use_terrain:
		global_position.x=clampf(global_position.x,-55.0,55.0)
		global_position.z=clampf(global_position.z,-36.0,36.0)
	_update_dribble(delta)
	_try_shoulder_challenge()
	if _goalkeeper_controller != null:
		_goalkeeper_controller.try_save()
	if not controlled_by_human:
		_try_ai_tackle()
	_update_actions(delta)
	_try_play_receive_animation(delta)
	_update_visual_pose(delta)

func _sample_input() -> void:
	if not controlled_by_human:
		_stick = Vector2.RIGHT if ai_move_direction.length_squared() > 0.01 else Vector2.ZERO
		_aim = Vector2.ZERO
		return
	_stick = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_aim = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if _aim.length_squared() < 0.02:
		_aim = _stick
	if Input.is_action_just_pressed("debug"):
		_debug = not _debug
		set_meta("debug_enabled", _debug)

func _update_locomotion(delta: float) -> void:
	var camera_right := camera.global_basis.x
	var camera_forward := -camera.global_basis.z
	camera_right.y = 0.0
	camera_forward.y = 0.0
	camera_right = camera_right.normalized()
	camera_forward = camera_forward.normalized()
	var recovering := is_instance_valid(_footballer_visual) and _footballer_visual.is_recovery_active()
	var sliding := _slide_tackle_time > 0.0
	var desired := Vector3.ZERO if recovering else (_slide_tackle_direction if sliding else (ai_move_direction if not controlled_by_human else (camera_right * _stick.x - camera_forward * _stick.y)))
	desired.y = 0.0
	if desired.length_squared() > 1.0:
		desired = desired.normalized()
	var sprint_requested := not recovering and (Input.is_action_pressed("sprint") if controlled_by_human else ai_sprinting) and _stick.length() > 0.1
	var sprint_input := sprint_requested
	var close_control := Input.is_action_pressed("close_control") if controlled_by_human else false
	var speed_scale := 0.56 if close_control else 1.0
	var is_ai_goalkeeper := not controlled_by_human and profile != null and profile.role == "goalkeeper"
	var target_speed := 0.0 if recovering else (4.8 if sliding else (tuning.goalkeeper_move_speed if is_ai_goalkeeper else (tuning.sprint_speed if sprint_input else tuning.jog_speed)))
	if _balance_stagger_time > 0.0:
		target_speed *= lerpf(0.68, 1.0, 1.0 - _balance_stagger_time / 0.38)
	if sprint_requested and not is_ai_goalkeeper:
		# Exhaustion slows a held sprint smoothly rather than locking movement.
		target_speed *= lerpf(0.72, 1.0, clampf(stamina / tuning.stamina_max, 0.0, 1.0))
	target_speed *= speed_scale * (1.0 if sliding else clampf(_stick.length(), 0.0, 1.0))
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := tuning.acceleration if target_speed > horizontal.length() else tuning.braking
	var target_velocity := desired * target_speed
	if _balance_stagger_time > 0.0:
		target_velocity += _balance_stagger_direction * 0.75
	horizontal = horizontal.move_toward(target_velocity, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	if sprint_requested:
		stamina = maxf(0.0, stamina - tuning.sprint_drain * delta)
	else:
		stamina = minf(tuning.stamina_max, stamina + tuning.stamina_recovery * delta)
	if desired.length_squared() > 0.015:
		var intended_direction := desired.normalized()
		# Keep locomotion cycling through a moving change of direction. The
		# authored Turn90 clips plant a foot and belong to stationary pivots;
		# playing them here dragged that planted pose through the moving world.
		var target_yaw := atan2(-intended_direction.x, -intended_direction.z)
		var turn_scale := tuning.sprint_turn_scale if sprint_input else 1.0
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-tuning.turn_rate * turn_scale * delta))
	# Input chooses the destination immediately; grounded touches follow the
	# body's actual facing while its turn catches up, including after stopping.
	_flat_direction = -global_basis.z
	_flat_direction.y = 0.0
	_flat_direction = _flat_direction.normalized()
	_leg_time += horizontal.length() * delta * (1.15 if sprint_input else 0.85)
	set_meta("braking", desired.length_squared() <= 0.015 and horizontal.length() > 0.8)
	set_meta("sprinting", sprint_input)
	set_meta("close_control", close_control)
	set_meta("move_speed", horizontal.length())

func _update_dribble(delta: float) -> void:
	if ball == null:
		return
	var flat_distance := Vector2(ball.global_position.x - global_position.x,
		ball.global_position.z - global_position.z).length()
	if flat_distance <= tuning.control_radius and _stick.length() > 0.05:
		ball.dribble_touch(self, _flat_direction, bool(get_meta("sprinting", false)),
			bool(get_meta("close_control", false)), tuning.dribble_touch_interval,
			tuning.close_touch_distance, tuning.sprint_touch_distance)
	elif flat_distance <= tuning.control_radius and velocity.length() < 0.45 and ball.linear_velocity.length() < 0.7:
		# Gentle recovery to a playable foot distance, still applied as force.
		ball.dribble_touch(self, _flat_direction, false, true,
			tuning.dribble_touch_interval, tuning.close_touch_distance,
			tuning.sprint_touch_distance)

func _update_actions(delta: float) -> void:
	if not controlled_by_human:
		return
	if _slide_tackle_time > 0.0 or (is_instance_valid(_footballer_visual) and _footballer_visual.is_recovery_active()):
		return
	if _ignore_pass_until_released:
		if not Input.is_action_pressed("pass") and not Input.is_action_pressed("through_pass"):
			_ignore_pass_until_released = false
		return
	if Input.is_action_just_pressed("pass"):
		_queue_pass(false)
	if Input.is_action_just_pressed("through_pass"):
		_queue_pass(true)
	if Input.is_action_just_pressed("tackle"):
		_attempt_tackle()
	if Input.is_action_just_pressed("slide_tackle"):
		_attempt_slide_tackle()
		if _slide_tackle_time > 0.0:
			_pending_pass = 0.0
			_pending_shot = 0.0
			_shot_charge = -1.0
			return
	_pending_pass = maxf(0.0, _pending_pass - delta)
	var receive_eta := _time_to_kick_window() if _pending_pass > 0.0 else -1.0
	var pass_contact_time := _footballer_visual.action_contact_time(&"pass") \
		if is_instance_valid(_footballer_visual) else -1.0
	var first_time_contact_ready := receive_eta > 0.0 and pass_contact_time > 0.0 \
		and receive_eta <= pass_contact_time
	if _pending_pass > 0.0 and (_can_kick() or first_time_contact_ready):
		var playback_speed := 1.0
		if first_time_contact_ready:
			playback_speed = clampf(pass_contact_time / maxf(receive_eta, 0.04), 1.0, 5.0)
		_do_pass(_pending_through, Vector3.ZERO, false, playback_speed)
		_pending_pass = 0.0
		_pending_through = false
	elif _pending_pass <= 0.0:
		_pending_through = false
	if Input.is_action_just_pressed("shoot"):
		_pending_shot = tuning.action_input_buffer
	var shot_buffer_was_active := _pending_shot > 0.0
	_pending_shot = maxf(0.0, _pending_shot - delta)
	if _shot_charge < 0.0 and _pending_shot > 0.0 and _can_kick():
		_shot_charge = 0.0
		_pending_shot = 0.0
	elif shot_buffer_was_active and _pending_shot <= 0.0 and _shot_charge < 0.0:
		status_changed.emit("Shot input expired: get closer to the ball")
	if _shot_charge >= 0.0:
		if Input.is_action_pressed("shoot"):
			_shot_charge = minf(1.0, _shot_charge + delta / tuning.shot_charge_duration)
			shot_charge_changed.emit(_shot_charge)
		elif _can_kick():
			_do_shot(_shot_charge)
			_shot_charge = -1.0
			shot_charge_changed.emit(0.0)
		else:
			_shot_charge = -1.0
			shot_charge_changed.emit(0.0)
			status_changed.emit("Shot lost: ball moved out of reach")

func _can_kick() -> bool:
	if ball == null:
		return false
	var flat := ball.global_position - global_position
	flat.y = 0.0
	return flat.length() <= tuning.kick_assist_radius and ball.global_position.y < 0.62

func _ball_will_reach_kick_window() -> bool:
	return _time_to_kick_window() > 0.0

func _time_to_kick_window() -> float:
	if ball == null or ball.last_touch != team_name or ball.linear_velocity.length_squared() < 1.0 or ball.global_position.y > 0.62:
		return -1.0
	var offset := ball.global_position - global_position
	offset.y = 0.0
	var relative_velocity := ball.linear_velocity - Vector3(velocity.x, 0.0, velocity.z)
	relative_velocity.y = 0.0
	var speed_squared := relative_velocity.length_squared()
	if speed_squared < 0.5 or offset.dot(relative_velocity) >= 0.0:
		return -1.0
	var closest_time := clampf(-offset.dot(relative_velocity) / speed_squared,
		0.0, tuning.incoming_pass_prediction_window)
	var closest_offset := offset + relative_velocity * closest_time
	if closest_time <= 0.04 or closest_offset.length() > tuning.kick_assist_radius * 0.82:
		return -1.0
	return closest_time

func _queue_pass(through: bool) -> void:
	_pending_pass = tuning.first_time_pass_buffer if _ball_will_reach_kick_window() else tuning.action_input_buffer
	_pending_through = through

func _try_ai_tackle() -> void:
	if _tackle_cooldown > 0.0 or ball == null or ball.last_touch == team_name \
			or (is_instance_valid(_footballer_visual) and _footballer_visual.is_recovery_active()):
		return
	var offset := ball.global_position - global_position
	offset.y = 0.0
	if offset.length() > _slide_tackle_reach() or ball.global_position.y >= 0.8:
		return
	# A team-level last-touch marker also remains set after a pass or loose-ball
	# deflection. Do not repeatedly tackle the free ball: only challenge when an
	# opposing outfielder is close enough to plausibly still control it.
	var carrier_gap := _nearest_ball_carrier_gap()
	if carrier_gap <= 1.35 and offset.length() <= _tackle_reach():
		_attempt_tackle()
	elif carrier_gap <= 1.55 and ball.global_position.y < 0.65 \
			and _ai_should_slide_tackle(offset):
		_attempt_slide_tackle()

func _ai_should_slide_tackle(to_ball: Vector3) -> bool:
	if to_ball.length_squared() < 0.01:
		return false
	var direction := to_ball.normalized()
	var closing_speed := Vector3(velocity.x, 0.0, velocity.z).dot(direction)
	var planned_approach := ai_move_direction.normalized().dot(direction) if ai_move_direction.length_squared() > 0.01 else 0.0
	if closing_speed < 1.4 and planned_approach < 0.72:
		return false
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.normalized().dot(direction) < 0.5:
		return false
	return true

func _nearest_ball_carrier_gap() -> float:
	if ball == null:
		return INF
	var carrier_gap := INF
	for node in get_tree().get_nodes_in_group("football_players"):
		var carrier := node as FootballPlayer
		if carrier == null or carrier.team_name != ball.last_touch or carrier.profile == null \
				or carrier.profile.role != "outfield":
			continue
		var gap := carrier.global_position.distance_to(ball.global_position)
		if gap < carrier_gap:
			carrier_gap = gap
	return carrier_gap

func _attempt_slide_tackle() -> bool:
	if ball == null or _tackle_cooldown > 0.0 or _slide_tackle_time > 0.0:
		return false
	if is_instance_valid(_footballer_visual) and _footballer_visual.is_recovery_active():
		return false
	if ball.last_touch == team_name:
		status_changed.emit("Slide missed: opponent does not have possession")
		return false
	var to_ball := ball.global_position - global_position
	to_ball.y = 0.0
	var distance := to_ball.length()
	if distance > _slide_tackle_reach() or ball.global_position.y > 0.65:
		status_changed.emit("Slide missed: get closer to the ball")
		return false
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if distance > 0.001 and forward.dot(to_ball / distance) < -0.1:
		status_changed.emit("Slide missed: turn toward the ball")
		return false
	_slide_tackle_direction = (to_ball.normalized() * 0.78 + forward * 0.22).normalized()
	_slide_tackle_time = 0.62
	_slide_contact_time = 0.18
	_slide_contact_pending = true
	_tackle_cooldown = 1.35
	_pending_pass = 0.0
	_pending_shot = 0.0
	_shot_charge = -1.0
	if is_instance_valid(_footballer_visual):
		_footballer_visual.play_slide_tackle()
	set_meta("last_tackle_result", &"committed")
	status_changed.emit("Committed slide tackle")
	return true

func _resolve_slide_tackle_contact() -> bool:
	_slide_contact_pending = false
	if ball == null:
		return false
	var ball_offset := ball.global_position - global_position
	ball_offset.y = 0.0
	var ball_gap := ball_offset.length()
	var nearest_opponent: FootballPlayer
	var opponent_gap := INF
	for node in get_tree().get_nodes_in_group("football_players"):
		var candidate := node as FootballPlayer
		if candidate == null or candidate == self or candidate.team_name == team_name:
			continue
		var gap := candidate.global_position.distance_to(global_position)
		if gap < opponent_gap:
			opponent_gap = gap
			nearest_opponent = candidate
	if nearest_opponent != null and opponent_gap <= 0.95 and ball_gap > 0.9 \
			and nearest_opponent.global_position.distance_to(ball.global_position) < ball_gap:
		set_meta("last_tackle_result", &"foul")
		status_changed.emit("Foul — late slide challenge")
		foul_committed.emit(self, nearest_opponent)
		return false
	if ball_gap > 1.2 or ball.global_position.y > 0.8:
		set_meta("last_tackle_result", &"missed")
		status_changed.emit("Slide missed: ball moved away")
		return false
	var tackling := 50.0
	if profile != null and profile.attributes != null:
		tackling = profile.attributes.tackling
	var speed := 7.0 + clampf(tackling, 0.0, 100.0) * 0.018
	if ball.tackle_touch(self, _slide_tackle_direction, speed):
		set_meta("last_tackle_result", &"won")
		status_changed.emit("Slide tackle — ball won")
		return true
	set_meta("last_tackle_result", &"missed")
	return false

func _slide_tackle_reach() -> float:
	var tackling := 50.0
	if profile != null and profile.attributes != null:
		tackling = profile.attributes.tackling
	return tuning.slide_tackle_reach + clampf(tackling, 0.0, 100.0) * 0.002

func _try_shoulder_challenge() -> bool:
	if ball == null or _shoulder_cooldown > 0.0 or _slide_tackle_time > 0.0 or profile == null \
			or profile.role != "outfield" or ball.last_touch == &"none" \
			or ball.last_touch == team_name:
		return false
	var own_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if own_velocity.length() < 2.2:
		return false
	var best: FootballPlayer
	var best_gap := INF
	for node in get_tree().get_nodes_in_group("football_players"):
		var carrier := node as FootballPlayer
		if carrier == null or carrier.team_name != ball.last_touch or carrier._shoulder_cooldown > 0.0 \
				or carrier.profile == null or carrier.profile.role != "outfield":
			continue
		var carrier_velocity := Vector3(carrier.velocity.x, 0.0, carrier.velocity.z)
		if carrier_velocity.length() < 2.2:
			continue
		var offset := carrier.global_position - global_position
		offset.y = 0.0
		var gap := offset.length()
		if gap < 0.52 or gap > 1.08 or gap >= best_gap:
			continue
		var shared_direction := own_velocity.normalized() + carrier_velocity.normalized()
		if shared_direction.length_squared() < 0.1:
			continue
		shared_direction = shared_direction.normalized()
		# Shoulder contact should happen across the running lane, not head-on.
		if absf(shared_direction.dot(offset / gap)) > 0.72:
			continue
		if global_position.distance_to(ball.global_position) > 2.0 \
				or carrier.global_position.distance_to(ball.global_position) > 1.35:
			continue
		best = carrier
		best_gap = gap
	if best == null:
		return false
	_resolve_shoulder_contact(best, own_velocity, Vector3(best.velocity.x, 0.0, best.velocity.z))
	return true

func _resolve_shoulder_contact(opponent: FootballPlayer, own_velocity: Vector3,
		opponent_velocity: Vector3) -> void:
	var side := opponent.global_position - global_position
	side.y = 0.0
	if side.length_squared() < 0.001:
		side = Vector3(0.0, 0.0, 1.0)
	side = side.normalized()
	var own_strength := _attribute_value(&"strength")
	var opponent_strength := opponent._attribute_value(&"strength")
	var own_balance := _attribute_value(&"balance")
	var opponent_balance := opponent._attribute_value(&"balance")
	var contact_energy := clampf((own_velocity - opponent_velocity).length() / 7.0, 0.0, 1.0)
	var own_advantage := (own_strength - opponent_strength) * 0.004
	var opponent_advantage := -own_advantage
	var own_impact := clampf(0.16 + contact_energy * 0.12 - own_balance * 0.0015 + opponent_advantage * 0.3, 0.06, 0.32)
	var opponent_impact := clampf(0.16 + contact_energy * 0.12 - opponent_balance * 0.0015 + own_advantage * 0.3, 0.06, 0.32)
	# Both players absorb some contact; the less balanced/stronger-opponent side
	# gets the larger readable loss of stride without ragdoll or physics chains.
	_apply_balance_reaction(-side, own_impact * 0.55)
	opponent._apply_balance_reaction(side, opponent_impact)
	_shoulder_cooldown = 0.78
	opponent._shoulder_cooldown = 0.78

func _apply_balance_reaction(push_direction: Vector3, intensity: float) -> void:
	_balance_stagger_time = maxf(_balance_stagger_time, 0.18 + intensity * 0.5)
	_balance_stagger_direction = push_direction.normalized()
	velocity += _balance_stagger_direction * (0.25 + intensity * 1.35)
	set_meta("last_shoulder_contact", Time.get_ticks_msec())

func _attribute_value(attribute_name: StringName) -> float:
	if profile != null and profile.attributes != null:
		return float(profile.attributes.get(attribute_name))
	return 50.0

func _attempt_tackle() -> bool:
	if ball == null or _tackle_cooldown > 0.0:
		return false
	var to_ball := ball.global_position - global_position
	to_ball.y = 0.0
	var distance := to_ball.length()
	if distance > _tackle_reach() or ball.global_position.y > 0.8:
		status_changed.emit("Tackle missed: get closer to the ball")
		return false
	if distance > 0.001:
		var forward := -global_basis.z
		forward.y = 0.0
		if forward.normalized().dot(to_ball / distance) < -0.25:
			status_changed.emit("Tackle missed: turn toward the ball")
			return false
	var clearance := _action_direction()
	if clearance.length_squared() < 0.01:
		clearance = Vector3(attack_sign, 0.0, 0.0)
	clearance.y = 0.0
	# Blend the player's aimed clearance with the direction the ball is already
	# travelling. A tackle redirects the live rigid body; it never snaps it.
	var current_direction := Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z).normalized()
	if current_direction.length_squared() > 0.01:
		clearance = (clearance.normalized() * 0.72 + current_direction * 0.28).normalized()
	var tackling := 50.0
	if profile != null and profile.attributes != null:
		tackling = profile.attributes.tackling
	var speed := 5.5 + clampf(tackling, 0.0, 100.0) * 0.018
	if ball.tackle_touch(self, clearance, speed):
		_tackle_cooldown = 0.85
		_start_tackle_pose()
		status_changed.emit("Tackle — ball won")
		return true
	return false

func _tackle_reach() -> float:
	var tackling := 50.0
	if profile != null and profile.attributes != null:
		tackling = profile.attributes.tackling
	return 1.12 + clampf(tackling, 0.0, 100.0) * 0.0024

func _start_tackle_pose() -> void:
	_kick_time = 0.0
	_kick_duration = 0.36
	_kick_side = -1.0

func _start_goalkeeper_save_pose() -> void:
	if is_instance_valid(_footballer_visual):
		_footballer_visual.play_keeper_save()
	_save_pose_time = 0.36

func _action_direction() -> Vector3:
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()
	var direction := right * _aim.x - forward * _aim.y
	if direction.length_squared() < 0.02:
		direction = Vector3(attack_sign, 0.0, 0.0)
	return direction.normalized()

func _do_pass(through: bool, requested_direction := Vector3.ZERO,
		at_animation_contact := false, playback_speed := 1.0) -> void:
	if not at_animation_contact and is_instance_valid(_footballer_visual):
		var predicted_first_time_contact := _pending_pass > 0.0 \
			and _time_to_kick_window() > 0.0
		if _visual_pass_pending or (not _can_kick() and not predicted_first_time_contact):
			return
		_visual_pass_pending = true
		_visual_pass_through = through
		_visual_pass_direction = requested_direction
		if _footballer_visual.play_pass(playback_speed):
			return
		_visual_pass_pending = false
		status_changed.emit("Pass action unavailable: animation is busy or missing")
		return
	var intended_direction := requested_direction.normalized() if requested_direction.length_squared() > 0.01 else _action_direction()
	var option := _choose_pass_target(intended_direction, through)
	var target: FootballPlayer = option.get("receiver") as FootballPlayer
	var target_position: Vector3 = option.get("position", ball.global_position + intended_direction * 12.0)
	var direction := target_position - ball.global_position
	direction.y = 0.0
	var distance := direction.length()
	if distance < 0.1:
		return
	direction /= distance
	var speed := clampf(distance * (1.05 if through else 0.88), 7.0,
		tuning.through_pass_speed if through else tuning.short_pass_speed)
	var lift := clampf(distance * 0.08, 0.35, 1.45) if through else 0.2
	if ball.kick(direction, speed, lift, &"through_pass" if through else &"pass", team_name):
		if is_instance_valid(target):
			target.receive_target = target_position
			target.receive_target_time = clampf(distance / maxf(speed, 1.0) + 0.75, 1.0, 3.5)
		status_changed.emit(("Through ball to " if through else "Pass to ") +
			(target.profile.display_name if is_instance_valid(target) and target.profile != null else "space"))
		if not is_instance_valid(_footballer_visual):
			_start_kick_pose(false)


func _on_visual_action_contact(action: StringName) -> void:
	if action == &"receive":
		if ball.receive_touch(self, _receive_contact_position(), _flat_direction):
			status_changed.emit("First touch")
		return
	if action == &"shot":
		if not _visual_shot_pending:
			return
		_visual_shot_pending = false
		if not _can_kick():
			status_changed.emit("Shot cancelled: ball left the contact window")
			return
		if ball.kick(_visual_shot_direction, _visual_shot_speed, _visual_shot_lift,
				&"shot", team_name):
			status_changed.emit("Shot fired")
		return
	if action != &"pass" or not _visual_pass_pending:
		return
	var through := _visual_pass_through
	var requested_direction := _visual_pass_direction
	_visual_pass_pending = false
	if not _can_kick():
		status_changed.emit("Pass cancelled: ball left the contact window")
		return
	_do_pass(through, requested_direction, true)


func _on_visual_action_finished(action: StringName) -> void:
	if action == &"pass":
		_visual_pass_pending = false
	elif action == &"shot":
		_visual_shot_pending = false
	elif action == &"slide_tackle":
		velocity.x = 0.0
		velocity.z = 0.0

func _try_play_receive_animation(delta: float) -> void:
	if not is_instance_valid(_footballer_visual) or receive_target_time <= 0.0 \
			or ball == null or ball.action_serial == _last_receive_action_serial \
			or ball.last_touch != team_name \
			or ball.last_action not in [&"pass", &"through_pass"] \
			or _pending_pass > 0.0 or _pending_shot > 0.0 or _shot_charge >= 0.0 \
			or _visual_pass_pending or _slide_tackle_time > 0.0:
		return
	var authored_contact := _footballer_visual.action_contact_time(&"receive")
	if authored_contact <= 0.0:
		return
	var time_to_contact := _incoming_receive_contact_time()
	# Start close to the authored foot-contact frame. The short window keeps the
	# clip from playing conspicuously early or after a fast pass has gone by.
	if time_to_contact < authored_contact * 0.88 \
			or time_to_contact > authored_contact + minf(delta, 1.0 / 120.0):
		return
	var playback_speed := clampf(authored_contact / maxf(time_to_contact, 0.01), 0.86, 1.16)
	if _footballer_visual.play_receive(playback_speed):
		_last_receive_action_serial = ball.action_serial

func _incoming_receive_contact_time() -> float:
	if ball.last_touch != team_name or ball.global_position.y > 0.62 \
			or ball.linear_velocity.length_squared() < 1.0:
		return -1.0
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	# The authored receive pose meets the ball about 0.55 m in front of the root.
	var contact_target := global_position + forward * 0.55
	var offset := ball.global_position - contact_target
	offset.y = 0.0
	var relative_velocity := ball.linear_velocity - Vector3(velocity.x, 0.0, velocity.z)
	relative_velocity.y = 0.0
	var speed_squared := relative_velocity.length_squared()
	if speed_squared < 0.5 or offset.dot(relative_velocity) >= 0.0:
		return -1.0
	var closest_time := clampf(-offset.dot(relative_velocity) / speed_squared,
		0.0, tuning.incoming_pass_prediction_window)
	if closest_time <= 0.04 or closest_time > tuning.incoming_pass_prediction_window:
		return -1.0
	var closest_offset := offset + relative_velocity * closest_time
	if closest_offset.length() > 0.18:
		return -1.0
	return closest_time

func _receive_contact_position() -> Vector3:
	if is_instance_valid(_footballer_visual):
		var skeleton := _footballer_visual.get_node_or_null("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
		if skeleton != null:
			var toe_index := skeleton.find_bone("mixamorig_RightToe_End")
			if toe_index >= 0:
				return skeleton.to_global(skeleton.get_bone_global_pose(toe_index).origin)
	var forward := -global_basis.z
	forward.y = 0.0
	return global_position + forward.normalized() * 0.55 + Vector3.UP * 0.05

func consume_pass_input_until_released() -> void:
	_ignore_pass_until_released = true

func _choose_pass_target(intended_direction: Vector3, through: bool) -> Dictionary:
	var best: FootballPlayer
	var best_position := Vector3.ZERO
	var best_score := INF
	var intended := intended_direction.normalized()
	for candidate_node in get_tree().get_nodes_in_group("football_players"):
		var candidate := candidate_node as FootballPlayer
		if candidate == null or candidate == self or candidate.team_name != team_name:
			continue
		if candidate.profile != null and candidate.profile.role == "goalkeeper":
			continue
		var offset := candidate.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < 2.0 or distance > 34.0:
			continue
		var direct := offset / distance
		var alignment := direct.dot(intended)
		if alignment < 0.30:
			continue
		var predicted := candidate.global_position
		var travel_time := distance / maxf(tuning.through_pass_speed if through else tuning.short_pass_speed, 1.0)
		if through:
			var receiver_velocity := candidate.velocity
			receiver_velocity.y = 0.0
			var run_direction := receiver_velocity.normalized() if receiver_velocity.length() > 0.5 else Vector3(attack_sign, 0.0, 0.0)
			predicted += run_direction * minf(travel_time, 0.8) * (2.2 if receiver_velocity.length() < 0.5 else receiver_velocity.length())
			predicted.x = clampf(predicted.x, -FIELD_LENGTH_LIMIT, FIELD_LENGTH_LIMIT)
			predicted.z = clampf(predicted.z, -FIELD_WIDTH_LIMIT, FIELD_WIDTH_LIMIT)
		var score := (1.0 - alignment) * 5.0 + distance * (0.055 if through else 0.025)
		if through:
			var forward_gain := (predicted.x - global_position.x) * attack_sign
			score -= clampf(forward_gain, -4.0, 12.0) * 0.10
		score += _pass_lane_risk(candidate.global_position, predicted) * 1.8
		if score < best_score:
			best_score = score
			best = candidate
			best_position = predicted
	return {"receiver": best, "position": best_position} if best != null else {}

func _pass_lane_risk(start: Vector3, finish: Vector3) -> float:
	var segment := finish - start
	segment.y = 0.0
	var length_sq := maxf(segment.length_squared(), 0.001)
	var risk := 0.0
	for opponent_node in get_tree().get_nodes_in_group("football_players"):
		var opponent := opponent_node as FootballPlayer
		if opponent == null or opponent.team_name == team_name:
			continue
		var relative := opponent.global_position - start
		relative.y = 0.0
		var t := clampf(relative.dot(segment) / length_sq, 0.08, 0.92)
		var nearest := start + segment * t
		var gap := Vector2(opponent.global_position.x - nearest.x,
			opponent.global_position.z - nearest.z).length()
		if gap < 2.2:
			risk += (2.2 - gap) / 2.2
	return risk

const FIELD_LENGTH_LIMIT := 51.0
const FIELD_WIDTH_LIMIT := 32.5

func _do_shot(charge: float) -> void:
	var direction := _action_direction()
	var target := Vector3(attack_sign * (tuning.field_length * 0.5 + 3.0), 0.7, 0.0)
	var goal_direction := target - ball.global_position
	goal_direction.y = 0.0
	goal_direction = goal_direction.normalized()
	# Gentle aim help bends intent toward the goal while preserving lateral stick input.
	direction = (direction * 0.56 + goal_direction * 0.44).normalized()
	var speed := lerpf(tuning.shot_min_speed, tuning.shot_max_speed, smoothstep(0.0, 1.0, charge))
	var lift := lerpf(0.55, 2.45, charge)
	if is_instance_valid(_footballer_visual):
		if _visual_shot_pending:
			return
		_visual_shot_direction = direction
		_visual_shot_speed = speed
		_visual_shot_lift = lift
		_visual_shot_pending = _footballer_visual.play_shot()
		if not _visual_shot_pending:
			status_changed.emit("Shot action unavailable: animation is busy or missing")
		return
	if ball.kick(direction, speed, lift, &"shot", team_name):
		status_changed.emit("Shot  %d%%" % roundi(charge * 100.0))
		_start_kick_pose(true)

func _start_kick_pose(power_shot: bool) -> void:
	var legs := get_node_or_null("Visual/Legs")
	if legs != null:
		legs.set_meta("kick_time", 0.0)
		legs.set_meta("kick_duration", 0.48 if power_shot else 0.34)
		legs.set_meta("kick_side", -1.0 if _flat_direction.cross(ball.global_position - global_position).y > 0.0 else 1.0)
	_kick_time = 0.0
	_kick_duration = 0.48 if power_shot else 0.34
	_kick_side = -1.0 if _flat_direction.cross(ball.global_position - global_position).y > 0.0 else 1.0

func _update_visual_pose(delta: float) -> void:
	var visual := get_node_or_null("Visual")
	if visual == null:
		return
	var speed := float(get_meta("move_speed", 0.0))
	if visual is FootballerVisual:
		(visual as FootballerVisual).set_locomotion_speed(speed,
			bool(get_meta("sprinting", false)), bool(get_meta("braking", false)),
			bool(get_meta("close_control", false)), delta)
		return
	var stride := clampf(speed / tuning.sprint_speed, 0.0, 1.0)
	var left_leg := visual.get_node_or_null("LeftLeg") as Node3D
	var right_leg := visual.get_node_or_null("RightLeg") as Node3D
	var left_arm := visual.get_node_or_null("LeftArm") as Node3D
	var right_arm := visual.get_node_or_null("RightArm") as Node3D
	var body := visual.get_node_or_null("Torso") as Node3D
	var idle := sin(Time.get_ticks_msec() * 0.0017) * 0.025
	var leg_swing := sin(_leg_time) * stride * 0.62
	var kick_swing := 0.0
	if _kick_time >= 0.0:
		_kick_time += delta
		var t := clampf(_kick_time / maxf(_kick_duration, 0.01), 0.0, 1.0)
		# Compact backswing, contact, then follow-through. This placeholder
		# presentation never drives the authoritative ball contact.
		kick_swing = sin(t * PI) * 0.95 * _kick_side
		if t >= 1.0:
			_kick_time = -1.0
	if left_leg:
		left_leg.rotation.x = -leg_swing + kick_swing + idle
	if right_leg:
		right_leg.rotation.x = leg_swing - kick_swing + idle
	if left_arm:
		var balance_pose := clampf(_balance_stagger_time / 0.38, 0.0, 1.0)
		left_arm.rotation.x = leg_swing * 0.48 - (0.62 if _save_pose_time > 0.0 else 0.0) \
			- 0.12 * balance_pose
		left_arm.rotation.z = (0.48 if _save_pose_time > 0.0 else 0.0) \
			+ _balance_stagger_direction.x * 0.16 * balance_pose
	if right_arm:
		var balance_pose := clampf(_balance_stagger_time / 0.38, 0.0, 1.0)
		right_arm.rotation.x = -leg_swing * 0.48 - (0.62 if _save_pose_time > 0.0 else 0.0) \
			- 0.12 * balance_pose
		right_arm.rotation.z = (-0.48 if _save_pose_time > 0.0 else 0.0) \
			- _balance_stagger_direction.x * 0.16 * balance_pose
	if body:
		var slide_pose := clampf(_slide_tackle_time / 0.24, 0.0, 1.0)
		var balance_pose := clampf(_balance_stagger_time / 0.38, 0.0, 1.0)
		body.rotation.z = -sin(_leg_time * 2.0) * stride * 0.035 \
			+ (0.08 if _save_pose_time > 0.0 else 0.0) - 0.24 * slide_pose \
			+ _balance_stagger_direction.x * 0.12 * balance_pose
		body.rotation.x = -_balance_stagger_direction.z * 0.12 * balance_pose
	visual.position.y = -0.38 * clampf(_slide_tackle_time / 0.24, 0.0, 1.0)
