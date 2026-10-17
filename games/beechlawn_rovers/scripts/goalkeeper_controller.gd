extends RefCounted
class_name GoalkeeperController
## Lightweight goalkeeper positioning and shot-response logic for the 4v4 slice.

const FIELD_LENGTH := 105.0
const GOAL_WIDTH := 7.32
const GOAL_HEIGHT := 2.44
const GRAVITY := 9.81

var keeper: FootballPlayer
var ball: FootballBall
var _observed_action_serial := -1
var _reaction_remaining := 0.0
var _shot_active := false
var _predicted_intercept := Vector3.ZERO
var _has_intercept := false
var _distribution_remaining := 0.0

func configure(player: FootballPlayer, match_ball: FootballBall) -> void:
	keeper = player
	ball = match_ball

func update_before_move(delta: float) -> void:
	if not is_instance_valid(keeper) or not is_instance_valid(ball):
		return
	if ball.goalkeeper_is_holding(keeper):
		keeper.ai_move_direction = Vector3.ZERO
		keeper.ai_sprinting = false
		_distribution_remaining = maxf(0.0, _distribution_remaining - delta)
		if _distribution_remaining <= 0.0:
			_distribute_to_teammate()
		return
	if keeper.controlled_by_human:
		return
	if ball.action_serial != _observed_action_serial:
		_observed_action_serial = ball.action_serial
		_shot_active = ball.last_action == &"shot" and ball.last_touch != keeper.team_name
		_reaction_remaining = _reaction_time() if _shot_active else 0.0
		_has_intercept = false
	if _shot_active:
		_has_intercept = _predict_goalmouth_intercept()
		if _has_intercept:
			_reaction_remaining = maxf(0.0, _reaction_remaining - delta)

	var target := _goal_line_position()
	if _shot_active and _has_intercept and _reaction_remaining <= 0.0:
		target.z = clampf(_predicted_intercept.z, -GOAL_WIDTH * 0.5 + 0.45,
			GOAL_WIDTH * 0.5 - 0.45)
	var offset := target - keeper.global_position
	offset.y = 0.0
	keeper.ai_move_direction = offset.normalized() if offset.length() > 0.18 else Vector3.ZERO
	keeper.ai_sprinting = offset.length() > 2.2
	keeper.set_meta("goalkeeper_target", target)

func try_save() -> bool:
	if not is_instance_valid(keeper) or not is_instance_valid(ball):
		return false
	if ball.last_action != &"shot" or ball.last_touch == keeper.team_name:
		return false
	var torso_center := keeper.global_position + Vector3.UP * 1.0
	var separation := ball.global_position - torso_center
	var flat_separation := Vector2(separation.x, separation.z).length()
	var reach := keeper.tuning.goalkeeper_save_reach if keeper.tuning != null else 0.95
	# A close physical contact window avoids remote or full-field save assistance.
	if flat_separation > reach or absf(separation.y) > 1.25:
		return false
	var handling := 50.0
	if keeper.profile != null and keeper.profile.attributes != null:
		handling = keeper.profile.attributes.goalkeeper_handling
	var catch_speed := lerpf(4.5, 8.0, clampf(handling / 100.0, 0.0, 1.0))
	if ball.linear_velocity.length() <= catch_speed and ball.goalkeeper_claim(keeper):
		_distribution_remaining = 0.58
		keeper._start_goalkeeper_save_pose()
		keeper.status_changed.emit("Goalkeeper claims the ball")
		_shot_active = false
		_has_intercept = false
		return true
	var side := signf(ball.global_position.z - keeper.global_position.z)
	if is_zero_approx(side):
		side = 1.0 if keeper.global_position.z <= 0.0 else -1.0
	var parry_direction := Vector3(keeper.attack_sign, 0.0, side * 0.45).normalized()
	var parry_speed := keeper.tuning.goalkeeper_parry_speed if keeper.tuning != null else 8.0
	if not ball.goalkeeper_save(keeper, parry_direction, parry_speed, 1.2):
		return false
	keeper._start_goalkeeper_save_pose()
	keeper.status_changed.emit("Goalkeeper parries the shot")
	_shot_active = false
	_has_intercept = false
	return true

func _distribute_to_teammate() -> void:
	var best: FootballPlayer
	var best_score := INF
	var start := ball.global_position
	for node in keeper.get_tree().get_nodes_in_group("football_players"):
		var candidate := node as FootballPlayer
		if candidate == null or candidate == keeper or candidate.team_name != keeper.team_name \
				or candidate.profile == null or candidate.profile.role != "outfield":
			continue
		var offset := candidate.global_position - start
		offset.y = 0.0
		var distance := offset.length()
		if distance < 6.0:
			continue
		var direction := offset / distance
		var lane_risk := 0.0
		for node_opponent in keeper.get_tree().get_nodes_in_group("football_players"):
			var opponent := node_opponent as FootballPlayer
			if opponent == null or opponent.team_name == keeper.team_name:
				continue
			var relative := opponent.global_position - start
			relative.y = 0.0
			var along := clampf(relative.dot(direction), 0.0, distance)
			var gap := Vector2(opponent.global_position.x - start.x - direction.x * along,
				opponent.global_position.z - start.z - direction.z * along).length()
			if gap < 2.8:
				lane_risk += (2.8 - gap) * 1.4
		var score := distance + lane_risk
		if score < best_score:
			best_score = score
			best = candidate
	if best == null:
		return
	var direction := best.global_position - ball.global_position
	direction.y = 0.0
	var distance := direction.length()
	if distance < 0.1:
		return
	direction /= distance
	var speed := clampf(distance * 0.58, 7.0, 14.0)
	var lift := 0.25 if distance < 16.0 else 0.8
	if ball.goalkeeper_distribute(keeper, direction, speed, lift):
		keeper.status_changed.emit("Goalkeeper distributes to %s" % best.profile.display_name)
		_distribution_remaining = 0.0

func _goal_line_position() -> Vector3:
	var goal_x := -FIELD_LENGTH * 0.5 * keeper.attack_sign + keeper.attack_sign * 3.0
	return Vector3(goal_x, keeper.global_position.y,
		clampf(ball.global_position.z * 0.14, -3.2, 3.2))

func _predict_goalmouth_intercept() -> bool:
	var velocity := ball.linear_velocity
	if velocity.x * keeper.attack_sign >= -1.5:
		return false
	var goal_line := -FIELD_LENGTH * 0.5 * keeper.attack_sign + keeper.attack_sign * 3.0
	var time_to_line := (goal_line - ball.global_position.x) / velocity.x
	if time_to_line <= 0.02 or time_to_line > 1.65:
		return false
	var predicted_y := ball.global_position.y + velocity.y * time_to_line \
		- 0.5 * GRAVITY * time_to_line * time_to_line
	var predicted_z := ball.global_position.z + velocity.z * time_to_line
	if predicted_y < -0.3 or predicted_y > GOAL_HEIGHT + 0.2 \
			or absf(predicted_z) > GOAL_WIDTH * 0.5 + 0.6:
		return false
	_predicted_intercept = Vector3(goal_line, maxf(predicted_y, FootballBall.RADIUS), predicted_z)
	return true

func _reaction_time() -> float:
	var base := keeper.tuning.goalkeeper_reaction_seconds if keeper.tuning != null else 0.22
	var reflexes := 50.0
	if keeper.profile != null and keeper.profile.attributes != null:
		reflexes = keeper.profile.attributes.goalkeeper_reflexes
	return base * lerpf(1.25, 0.72, clampf(reflexes / 100.0, 0.0, 1.0))
