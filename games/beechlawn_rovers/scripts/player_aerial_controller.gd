extends RefCounted
class_name PlayerAerialController
## Context, prediction and marker-gated aerial contacts. No attached ball and
## no animation root motion. The actor's CharacterBody executes the short jump.

var actor: FootballPlayer
var ball: FootballBall
var _requested_header := 0.0
var _header_aim := Vector3.ZERO
var _requested_action: StringName = &"header"
var _strike_power := .55
var _active: StringName = &""
var _serial := -1
var _incoming_kind: StringName = &""
var _elapsed := 0.0
var _contact_seconds := .3
var _takeoff_seconds := .1
var _contact_window := 0.0
var _takeoff_pending := false
var _jump_started := false
var _charge := -1.0
var _charge_kind: StringName = &"lofted_pass"
var _charge_variant: StringName = &"standard"
var _capsule_exception := false
var _capsule_release := -1.0
var facing := Vector3.ZERO

func configure(player: FootballPlayer, match_ball: FootballBall) -> void:
	actor = player
	ball = match_ball

func reset() -> void:
	_restore_capsule()
	_requested_header = 0.0
	_requested_action = &"header"
	_strike_power = .55
	_active = &""
	_contact_window = 0.0
	_takeoff_pending = false
	_jump_started = false
	_charge = -1.0
	facing = Vector3.ZERO

func committed() -> bool:
	return _active != &""

func cancel_input() -> void:
	_charge = -1.0
	_requested_header = 0.0

func handle_input(delta: float) -> bool:
	if committed(): return true
	if Input.is_action_just_pressed("lofted_pass") or Input.is_action_just_pressed("cross"):
		_charge_kind = &"cross" if Input.is_action_just_pressed("cross") else &"lofted_pass"
		_charge_variant = ShotPlanner.cross_style() if _charge_kind == &"cross" else &"standard"
		_charge = 0.0
	if _charge >= 0.0:
		if Input.is_action_pressed(String(_charge_kind)):
			_charge = minf(1.0, _charge + delta / actor.tuning.lofted_pass_charge_seconds)
			actor.shot_charge_changed.emit(_charge)
		else:
			if actor._can_kick() and actor._can_start_ball_action():
				var direction := actor._action_direction()
				if _charge_kind == &"cross" and Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down").length_squared() < .01:
					direction = Vector3(43 * actor.attack_sign, ball.position.y, 0) - ball.position
				actor._do_pass(false, direction, false, 1.0, null, _charge_kind, maxf(.2, _charge), _charge_variant)
			else:
				actor.status_changed.emit("Aerial pass unavailable: get the ball within kicking reach")
			_charge = -1.0
			actor.shot_charge_changed.emit(0.0)
		return true
	if Input.is_action_just_pressed("shoot") and _flat_gap(ball.position) < 9.0 and not is_instance_valid(ball.goalkeeper_holder):
		var height := ball.position.y - actor.position.y
		var aerial_ball := ball.last_action in [&"cross", &"lofted_pass", &"header_clearance"] or absf(ball.linear_velocity.y) > 1.5 or ball.seconds_since_bounce < .25
		if height > .7 or (height > .15 and aerial_ball):
			var head := FootballBallFlight.descending_contact(ball, actor.position.y + actor.tuning.header_contact_height, .85)
			var low := FootballBallFlight.descending_contact(ball, actor.position.y + actor.tuning.volley_contact_height, .85)
			var rebound := FootballBallFlight.after_bounce_contact(ball, actor.position.y + actor.tuning.half_volley_contact_height)
			var action: StringName = &"header" if height > 1.45 and not head.is_empty() else &"volley"
			if action != &"header" and (height < .65 or (not low.is_empty() and float(low.time) < .24 and not rebound.is_empty())): action = &"half_volley"
			request_strike(action, actor._action_direction() if actor._aim.length_squared() > .01 else _default_header_direction(), .35)
			return true
	return _requested_header > 0.0

func request_header(direction: Vector3) -> void:
	request_strike(&"header", direction)

func request_strike(action: StringName, direction: Vector3, power := .55) -> void:
	if action not in [&"header", &"volley", &"half_volley"]: return
	_requested_header = .85
	_requested_action = action
	_strike_power = clampf(power, .2, 1.0)
	_header_aim = Vector3(direction.x, 0, direction.z).normalized()

func before_move(delta: float) -> void:
	var charging_foot := (_requested_header > 0.0 and _requested_action in [&"volley", &"half_volley"]) or (_active in [&"volley", &"half_volley"] and ball.action_serial == _serial)
	if actor.controlled_by_human and charging_foot and Input.is_action_pressed("shoot"):
		_strike_power = minf(1, _strike_power + delta / actor.tuning.shot_charge_duration)
		actor.shot_charge_changed.emit(_strike_power)
	_requested_header = maxf(0.0, _requested_header - delta)
	if _capsule_release >= 0.0:
		_capsule_release = maxf(0.0, _capsule_release - delta)
		if _capsule_release <= 0.0: _restore_capsule()
	if committed():
		_elapsed += delta
		_prepare_anatomical_contact()
		if _active == &"header" and not _jump_started and _elapsed >= _takeoff_seconds:
			_takeoff_pending = true
			_jump_started = true
		return
	facing = Vector3.ZERO
	var surface := PitchSurface.height_at(ball.position.x, ball.position.z) if ball.use_terrain else 0.0
	if ball.position.y <= surface + FootballBall.RADIUS + .05 and absf(ball.linear_velocity.y) < .75 and ball.seconds_since_bounce > .30:
		# A rut can put the actor root below the adjacent ball. Ground/air
		# classification belongs to the ball's turf, not that root-height gap.
		if _requested_header > 0.0: actor.shot_charge_changed.emit(0.0)
		_requested_header = 0.0
		return
	var intended_receiver := ball.last_touch == actor.team_name and actor.receive_target_time > 0.0 \
		and ball.last_action in [&"lofted_pass", &"cross"]
	if actor.profile == null or actor.profile.role != "outfield" \
			or is_instance_valid(ball.goalkeeper_holder) or ball.position.y - actor.position.y < (.15 if _requested_header > 0.0 or ball.last_action == &"cross" else .65) \
			or (not intended_receiver and _flat_gap(ball.position) > 9.0) or not actor._can_start_ball_action():
		return
	var wants_header := _requested_header > 0.0
	var incoming_cross := ball.last_action == &"cross"
	var defending := ball.last_touch != actor.team_name and actor.position.x * actor.attack_sign < -24.0
	var attacking := incoming_cross and actor.position.x * actor.attack_sign > 27.0
	var has_reception := ball.last_touch == actor.team_name and actor.receive_target_time > 0.0
	var is_chaser := String(actor.get_meta("ai_role_intent", "")) in ["press", "aerial_press"]
	var can_intercept := is_chaser and ball.last_touch != actor.team_name \
		and ball.last_action in [&"lofted_pass", &"cross", &"header_clearance"]
	if not actor.controlled_by_human:
		wants_header = attacking or (defending and is_chaser)
		if not wants_header and not has_reception and not can_intercept: return
	elif not wants_header and not has_reception:
		return
	var action: StringName = &"header" if wants_header else &"chest_control"
	if _requested_header > 0.0: action = _requested_action
	elif wants_header and attacking and ((ball.position.y - actor.position.y < 1.5 and ball.linear_velocity.y < 0) \
			or ball.last_strike_style == &"driven_cross" or FootballBallFlight.descending_contact(ball, actor.position.y + actor.tuning.header_contact_height, 1.7).is_empty()):
		action = &"half_volley" if ball.position.y - actor.position.y < .6 else &"volley"
	if not actor.controlled_by_human and action == &"volley":
		var low := FootballBallFlight.descending_contact(ball, actor.position.y + actor.tuning.volley_contact_height, .85, true)
		var rebound := FootballBallFlight.after_bounce_contact(ball, actor.position.y + actor.tuning.half_volley_contact_height)
		if (low.is_empty() or float(low.time) < .24) and not rebound.is_empty() and float(rebound.time) >= .24: action = &"half_volley"
	if not actor.controlled_by_human: _strike_power = .55
	var strike := action in [&"volley", &"half_volley"]
	var height := actor.position.y + actor.tuning.header_contact_height
	if action == &"chest_control": height = chest_point().y
	elif action == &"volley": height = actor.position.y + actor.tuning.volley_contact_height
	elif action == &"half_volley": height = actor.position.y + actor.tuning.half_volley_contact_height
	var prediction := FootballBallFlight.after_bounce_contact(ball, height) if action == &"half_volley" else FootballBallFlight.descending_contact(ball, height, 1.7, strike)
	if prediction.is_empty(): return
	var direction := _header_aim if _requested_header > 0.0 else _default_header_direction()
	if not wants_header:
		var incoming := Vector3(-ball.linear_velocity.x, 0, -ball.linear_velocity.z)
		direction = incoming.normalized() if incoming.length() > .1 else -actor.global_basis.z
	if float(prediction.time) < .55:
		facing = direction
	var target: Vector3 = prediction.position - direction * (.60 if strike else (.14 if wants_header else .16))
	if strike: target -= direction.cross(Vector3.UP) * .09
	var offset := Vector3(target.x - actor.position.x, 0, target.z - actor.position.z)
	if not actor.controlled_by_human and (has_reception or is_chaser or attacking) \
			and float(prediction.time) < 1.5:
		var steering := offset
		if strike:
			var horizontal := Vector3(actor.velocity.x, 0, actor.velocity.z)
			steering -= horizontal * (horizontal.length() / (2.0 * maxf(actor.tuning.braking, .1)))
		actor.ai_move_direction = steering.normalized() * clampf(offset.length() / 1.2, 0.0, 1.0)
		actor.ai_sprinting = offset.length() > 7.0
		actor.set_meta("aerial_target", target)
	var contact := actor._footballer_visual.action_contact_time(action) if is_instance_valid(actor._footballer_visual) else -1.0
	if contact <= 0.0 or float(prediction.time) > contact + delta or float(prediction.time) < contact * (.70 if strike else .86):
		return
	# Anticipate the small braking drift, but do not let prediction authorize
	# contact. The evaluated forehead/chest must meet the real ball at the marker.
	var drift := Vector3(actor.velocity.x, 0, actor.velocity.z) * contact * .35
	if strike:
		var horizontal := Vector3(actor.velocity.x, 0, actor.velocity.z)
		var brake := maxf(actor.tuning.braking, .1)
		var moving_seconds := minf(float(prediction.time), horizontal.length() / brake)
		drift = horizontal.normalized() * maxf(0, horizontal.length() * moving_seconds - .5 * brake * moving_seconds * moving_seconds)
	if (offset - drift).length() > (.22 if strike else .40): return
	var contact_eta := float(prediction.time)
	if action == &"volley":
		# The parent actor samples before the child's animation physics step.
		# Schedule the boot marker on the preceding whole tick; a fast delivery
		# otherwise passes the boot while the marker waits for the next tick.
		var tick := Engine.time_scale / float(Engine.physics_ticks_per_second)
		contact_eta = maxf(.1, floorf((contact_eta - tick) / tick) * tick - .0001)
		if contact_eta < contact / 1.35: return
	var playback := clampf(contact / maxf(contact_eta, .1), .90, 1.35 if strike else 1.17)
	if actor._footballer_visual.play_aerial(action, playback):
		_active = action
		_serial = ball.action_serial
		_incoming_kind = ball.last_action
		_elapsed = 0.0
		_contact_seconds = contact / playback
		_takeoff_seconds = .10 / playback
		_jump_started = false
		_header_aim = direction
		facing = direction
		_requested_header = 0.0
		actor._pending_pass = 0.0
		actor._pending_shot = 0.0
		actor._shot_charge = -1.0

func after_locomotion() -> void:
	if _takeoff_pending:
		actor.velocity.y = actor.tuning.header_jump_speed
		_takeoff_pending = false

func on_marker(action: StringName) -> void:
	if action != _active: return
	_contact_window = actor.tuning.kick_contact_grace_seconds
	resolve_contact(0.0)

func resolve_contact(delta: float) -> void:
	if _contact_window <= 0.0: return
	_contact_window -= delta
	# A real collision with this actor may already have recorded its touch.
	# Another player/action invalidates the attempt; an own body contact at the
	# authored moment still needs the same evaluated head/chest proximity.
	var own_body_contact := ball.last_touch_player == actor and ball.last_action == _incoming_kind
	if (ball.action_serial != _serial and not own_body_contact) or is_instance_valid(ball.goalkeeper_holder):
		_contact_window = 0.0
		_restore_capsule()
		return
	var point := contact_point()
	if point.distance_to(ball.position) > actor.tuning.aerial_contact_radius:
		return
	if _active == &"half_volley" and ball.seconds_since_bounce > .30: return
	if _active in [&"volley", &"half_volley"]:
		var style := _active
		var shot := ShotPlanner.plan(actor, _strike_power, _header_aim, style)
		var launch: Vector3 = shot.direction * shot.speed + Vector3.UP * shot.lift
		actor.set_meta("last_air_contact_bounce_age", ball.seconds_since_bounce)
		if ball.kick_velocity(launch, &"shot", actor.team_name, actor, &"foot", _active):
			actor.status_changed.emit("Half-volley" if _active == &"half_volley" else "Volley")
	elif _active == &"header":
		# Simultaneous equal reaches do not reward actor processing order.
		var own_gap := point.distance_to(ball.position)
		for node in actor.get_tree().get_nodes_in_group("football_players"):
			var other := node as FootballPlayer
			if other == actor or other._aerial_controller == null: continue
			var rival := other._aerial_controller
			if not rival._header_contact_due(): continue
			var gap := rival.forehead_point().distance_to(ball.position)
			if gap <= own_gap + .02: return
		var rating := actor._attribute_value(&"heading") / 100.0
		var aim := _header_aim
		var shot := actor.position.x * actor.attack_sign > 27.0 \
			and aim.dot((Vector3(52.5 * actor.attack_sign, actor.position.y, 0) - actor.position).normalized()) > .75
		var speed := actor.tuning.header_speed * lerpf(.82, 1.15, rating)
		var launch := aim * speed + Vector3.UP * (-1.4 if shot else 4.0)
		if ball.kick_velocity(launch, &"shot" if shot else &"header_clearance", actor.team_name, actor, &"head", &"header"):
			actor.status_changed.emit("Header on goal" if shot else "Headed clearance / pass")
	else:
		var retention := lerpf(.22, .10, actor._attribute_value(&"ball_control") / 100.0)
		var cushion := Vector3(actor.velocity.x, 0, actor.velocity.z) * .5 \
			+ Vector3(ball.linear_velocity.x, 0, ball.linear_velocity.z) * retention - actor.global_basis.z * .35 + Vector3.DOWN * 1.2
		if ball.kick_velocity(cushion, &"aerial_control", actor.team_name, actor, &"chest"):
			actor.status_changed.emit("Chest control")
	actor.receive_target_time = 0.0
	actor.shot_charge_changed.emit(0.0)
	_contact_window = 0.0
	_capsule_release = .10

func on_finished(action: StringName) -> void:
	if action == _active:
		actor.shot_charge_changed.emit(0.0)
		_restore_capsule()
		_active = &""
		_contact_window = 0.0
		facing = Vector3.ZERO

func _header_contact_due() -> bool:
	if _active != &"header": return false
	return _contact_window > 0.0 or absf(_elapsed - _contact_seconds) <= .04

func _prepare_anatomical_contact() -> void:
	var remaining := _contact_seconds - _elapsed
	if remaining < -actor.tuning.kick_contact_grace_seconds:
		if _capsule_release < 0.0: _restore_capsule()
		return
	if _capsule_exception or _capsule_release >= 0.0: return
	var lead := .18 if _active != &"chest_control" else .10
	if remaining < 0.0 or remaining > lead or ball.action_serial != _serial: return
	var point := contact_point()
	# The coarse standing capsule otherwise bounces a ball before the actual
	# forehead/chest can meet it. Bypass only this actor during a predicted close
	# authored contact; other collisions and the independent trajectory remain.
	var forecast := FootballBallFlight.physics_position_from(ball.position, ball.linear_velocity, remaining, FootballBallFlight.damping(ball), FootballBallFlight.gravity(ball)) if _active in [&"volley", &"half_volley"] else FootballBallFlight.position_at(ball, remaining)
	if forecast.distance_to(point) <= actor.tuning.aerial_contact_radius + .08:
		ball.add_collision_exception_with(actor)
		_capsule_exception = true

func _restore_capsule() -> void:
	if _capsule_exception and is_instance_valid(ball) and is_instance_valid(actor):
		ball.remove_collision_exception_with(actor)
	_capsule_exception = false
	_capsule_release = -1.0

func contact_point() -> Vector3:
	if _active in [&"volley", &"half_volley"]: return actor._receive_contact_position()
	return forehead_point() if _active == &"header" else chest_point()

func forehead_point() -> Vector3:
	var skeleton := _skeleton()
	if skeleton != null:
		var index := skeleton.find_bone("mixamorig_Head")
		if index >= 0:
			return actor._footballer_visual.bone_world_position(skeleton.get_bone_name(index)) + Vector3.UP * .14 - actor.global_basis.z * .10
	return actor.position + Vector3.UP * 1.74 - actor.global_basis.z * .10

func chest_point() -> Vector3:
	var skeleton := _skeleton()
	if skeleton != null:
		var index := skeleton.find_bone("mixamorig_Spine2")
		if index >= 0:
			return actor._footballer_visual.bone_world_position(skeleton.get_bone_name(index)) - actor.global_basis.z * .16
	return actor.position + Vector3.UP * 1.32 - actor.global_basis.z * .16

func _skeleton() -> Skeleton3D:
	return actor._footballer_visual.get_node_or_null("Rig/YBot_Armature/Skeleton3D") as Skeleton3D if is_instance_valid(actor._footballer_visual) else null

func _default_header_direction() -> Vector3:
	if actor.position.x * actor.attack_sign > 27.0:
		return (Vector3(52.5 * actor.attack_sign, actor.position.y, -.8 if actor.position.z > 0 else .8) - actor.position).normalized()
	return Vector3(actor.attack_sign, 0, 0)

func _flat_gap(point: Vector3) -> float:
	return Vector2(point.x - actor.position.x, point.z - actor.position.z).length()
