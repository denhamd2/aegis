extends RefCounted
class_name PlayerSkillController
## Possession skills use authored foot markers and one bounded physical touch.
## Shielding trades speed for body position; it never grants ball ownership.

const ACTIONS := {"ball_roll": "BallRoll", "step_over": "StepOver", "body_feint": "BodyFeint",
	"drag_back": "DragBack", "skill_turn": "SkillTurn", "fake_shot": "FakeShot"}
const SPEEDS := {"ball_roll": 2.2, "step_over": 3.5, "body_feint": 2.8,
	"drag_back": 2.4, "skill_turn": 3.2, "fake_shot": 1.8}
var actor: FootballPlayer
var ball: FootballBall
var active: StringName = &""
var shielding := false
var facing := Vector3.ZERO
var exit_direction := Vector3.ZERO
var side := 1.0
var cooldown := 0.0
var contacted := false
var _serial := -1
var _window := 0.0
var _forward := Vector3.ZERO
var _capsule_exception := false
var _capsule_release := 0.0

func configure(player: FootballPlayer, match_ball: FootballBall) -> void:
	actor = player
	ball = match_ball

func owns_close_ball() -> bool:
	if ball == null or is_instance_valid(ball.goalkeeper_holder) or actor.profile == null or actor.profile.role != "outfield": return false
	var offset := ball.global_position-actor.global_position
	return ball.last_touch == actor.team_name and ball.last_touch_player == actor \
		and Vector2(offset.x, offset.z).length() <= .90 and offset.y >= -.15 and offset.y <= .45 \
		and ball.linear_velocity.length() <= (5.0 if active == &"" else 9.0) and not actor._aerial_controller.committed()

func nearest_pressure() -> FootballPlayer:
	var best: FootballPlayer
	var gap := 1.8
	for node in actor.get_tree().get_nodes_in_group("football_players"):
		var other := node as FootballPlayer
		if other == null or other.team_name == actor.team_name: continue
		var distance := other.global_position.distance_to(actor.global_position)
		if distance < gap:
			best = other
			gap = distance
	return best

func before_move(delta: float) -> void:
	cooldown = maxf(0, cooldown-delta)
	if _capsule_exception:
		_capsule_release -= delta
		var offset := ball.global_position-actor.global_position
		if _capsule_release <= 0 or Vector2(offset.x,offset.z).length() > .65: _restore_capsule()
	if active != &"" and (not is_instance_valid(ball) or ball.action_serial != _serial):
		cancel()
	shielding = false
	if active == &"" and owns_close_ball() and actor._can_start_ball_action() \
			and not actor._visual_pass_pending and not actor._visual_shot_pending and actor._shot_charge < 0:
		if actor.controlled_by_human:
			shielding = Input.is_action_pressed("shield") and not Input.is_action_pressed("sprint")
		else:
			var pressure := nearest_pressure()
			shielding = pressure != null and Vector2(actor.velocity.x,actor.velocity.z).length() < 2.0 \
				and (-actor.global_basis.z).dot(pressure.global_position-actor.global_position) < -.35
	if shielding:
		var pressure := nearest_pressure()
		facing = actor.global_position-pressure.global_position if pressure != null else -actor.global_basis.z
		facing.y = 0
		facing = facing.normalized()
	elif active != &"":
		facing = exit_direction if contacted and active in [&"drag_back", &"skill_turn"] else _forward
	else:
		facing = Vector3.ZERO
	if is_instance_valid(actor._footballer_visual): actor._footballer_visual.set_shielding(shielding, delta)

func handle_input() -> bool:
	if Input.is_action_just_pressed("pass") and actor._shot_charge >= 0:
		if request(&"fake_shot", actor._action_direction()):
			actor.consume_pass_input_until_released()
			return true
	for action in ACTIONS:
		if Input.is_action_just_pressed(action) and request(StringName(action), actor._action_direction()): return true
	return active != &"" and not contacted

func request(action: StringName, direction := Vector3.ZERO) -> bool:
	if not ACTIONS.has(String(action)) or active != &"" or cooldown > 0 or not owns_close_ball(): return false
	if Vector2(actor.velocity.x,actor.velocity.z).length() > actor.tuning.jog_speed+.1:
		if actor.controlled_by_human: actor.status_changed.emit("Release sprint and bring the ball under control for a skill")
		return false
	var visual := actor._footballer_visual
	if not is_instance_valid(visual) or actor._slide_tackle_time > 0 or actor._keeper_is_recovering(): return false
	var cancelling_shot := action == &"fake_shot" and actor._visual_shot_pending and not visual._action_has_contact
	if not cancelling_shot and not actor._can_start_ball_action(): return false
	if actor._visual_pass_pending or (action != &"fake_shot" and (actor._shot_charge >= 0 or actor._visual_shot_pending)): return false
	if not ball._claim_dribble_control(actor, ball.global_position.distance_to(actor.global_position)): return false
	_forward = -actor.global_basis.z
	_forward.y = 0
	_forward = _forward.normalized()
	var right := actor.global_basis.x
	direction.y = 0
	side = -1.0 if direction.dot(right) < -.15 else 1.0
	exit_direction = (_forward*.35+right*side*.94).normalized()
	if action == &"ball_roll": exit_direction = (right*side+.15*_forward).normalized()
	elif action == &"step_over": exit_direction = (_forward*.65+right*side*.75).normalized()
	elif action == &"drag_back": exit_direction = -_forward
	elif action == &"skill_turn":
		exit_direction = direction.normalized() if direction.length() > .1 and direction.normalized().dot(_forward) < .85 else right*side
	var clip := StringName("AN_Beechlawn_"+ACTIONS[String(action)]+("Right" if side > 0 else "Left"))
	if not visual.play_skill(clip, cancelling_shot): return false
	active = action
	_serial = ball.action_serial
	contacted = false
	_window = 0
	shielding = false
	cooldown = actor.tuning.skill_cooldown
	actor._pending_shot = 0
	actor._pending_pass = 0
	actor._shot_charge = -1
	actor._visual_shot_pending = false
	actor._contact_wait_action = &""
	actor.shot_charge_changed.emit(0)
	actor.status_changed.emit(String(action).replace("_", " ").capitalize())
	return true

func contact_point() -> Vector3:
	return actor._footballer_visual.bone_world_position(&"mixamorig_RightToe_End" if side > 0 else &"mixamorig_LeftToe_End")

func control_setup() -> void:
	if active == &"" or contacted or not owns_close_ball(): return
	var gap := Vector2(ball.global_position.x-actor.global_position.x,ball.global_position.z-actor.global_position.z).length()
	if not ball._claim_dribble_control(actor, gap): return
	var frame := Engine.get_physics_frames()
	if ball._dribble_force_frame == frame: return
	ball._dribble_force_frame = frame
	var target := actor.global_position+_forward*.50+actor.global_basis.x*.09*side
	var carrier_velocity := Vector3(actor.velocity.x,0,actor.velocity.z)
	var force := (target-ball.global_position)*22+(carrier_velocity-ball.linear_velocity)*5
	force.y = 0
	ball.apply_central_force(force.limit_length(18))

func on_marker() -> void:
	if active != &"" and not contacted: _window = actor.tuning.kick_contact_grace_seconds

func resolve_contact(delta: float) -> void:
	if active == &"" or contacted or _window <= 0: return
	_window -= delta
	if not owns_close_ball() or ball.action_serial != _serial:
		cancel()
		return
	var distance := contact_point().distance_to(ball.global_position)
	if distance > actor.tuning.kick_foot_contact_radius:
		if _window <= 0: cancel()
		return
	var gap := Vector2(ball.global_position.x-actor.global_position.x,ball.global_position.z-actor.global_position.z).length()
	if not ball._claim_dribble_control(actor, gap):
		cancel()
		return
	var kind := active
	if active == &"drag_back":
		# The coarse standing capsule fills the space between the legs. Allow
		# only this grounded pull under its owner's planted stance; opponents
		# and terrain retain ordinary collision throughout the brief window.
		ball.add_collision_exception_with(actor)
		_capsule_exception = true
		_capsule_release = .45
	if ball.kick(exit_direction, float(SPEEDS[String(active)]), 0, &"skill", actor.team_name, actor, &"foot", active):
		contacted = true
		_serial = ball.action_serial
		_window = 0
		actor.set_meta("last_skill_contact", {"kind":kind,"distance":distance,"serial":_serial})
		actor.status_changed.emit(String(kind).replace("_", " ").capitalize()+" touch")

func try_ai_skill() -> bool:
	if actor.controlled_by_human or cooldown > 0 or not owns_close_ball() or Vector2(actor.velocity.x, actor.velocity.z).length() > 3.2: return false
	var pressure := nearest_pressure()
	if pressure == null: return false
	var offset := pressure.global_position-actor.global_position
	if offset.length() < 1.1 or (-actor.global_basis.z).dot(offset.normalized()) < .65: return false
	var away := actor.global_position-pressure.global_position
	var right := actor.global_basis.x
	return request(&"ball_roll", right*(-1.0 if away.dot(right) < 0 else 1.0))

func on_finished() -> void:
	active = &""
	_window = 0
	contacted = false
	facing = Vector3.ZERO

func cancel() -> void:
	on_finished()
	if is_instance_valid(actor._footballer_visual): actor._footballer_visual.cancel_skill()

func reset() -> void:
	_restore_capsule()
	on_finished()
	shielding = false
	cooldown = 0
	if is_instance_valid(actor._footballer_visual): actor._footballer_visual.set_shielding(false, 1)

func _restore_capsule() -> void:
	if _capsule_exception and is_instance_valid(ball): ball.remove_collision_exception_with(actor)
	_capsule_exception = false
	_capsule_release = 0
