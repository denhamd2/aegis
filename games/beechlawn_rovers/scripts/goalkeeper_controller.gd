extends RefCounted
class_name GoalkeeperController
## Goal-angle positioning and physical shot responses, shared by both teams.

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
var _intercept_seconds := 0.0
var _save_animation_started := false
var _save_elapsed := 0.0
var _save_facing := 0.0
var _gather_pending := false
var _gather_elapsed := 0.0
var _original_shape: Shape3D
var _original_shape_position := Vector3.ZERO
var _recovery_remaining := 0.0

func configure(player: FootballPlayer, match_ball: FootballBall) -> void:
	keeper = player
	ball = match_ball

func update_before_move(delta: float) -> void:
	if not is_instance_valid(keeper) or not is_instance_valid(ball):
		return
	_recovery_remaining = maxf(0.0, _recovery_remaining - delta)
	if not is_recovering(): _restore_dive_shape()
	if ball.goalkeeper_is_holding(keeper):
		keeper.ai_move_direction = Vector3.ZERO
		keeper.ai_sprinting = false
		_distribution_remaining = maxf(0.0, _distribution_remaining - delta)
		if _distribution_remaining <= 0.0:
			_distribute_to_teammate()
		return
	_observe_action()
	if _gather_pending:
		_gather_elapsed+=delta
		if _gather_elapsed>.7: _gather_pending=false;_save_animation_started=false
	if _save_animation_started and _shot_active:
		_save_elapsed += delta
		if _save_elapsed<.2: keeper.rotation.y=lerp_angle(keeper.rotation.y,_save_facing,1-exp(-delta*24))
		if _save_elapsed > 1.3:
			_shot_active = false
			_recovery_remaining = .2
	if _shot_active:
		_has_intercept = _predict_goalmouth_intercept()
		if not _has_intercept and ball.last_action in [&"cross",&"lofted_pass"]: _has_intercept = _predict_cross_claim()
		_reaction_remaining = maxf(0.0, _reaction_remaining - delta)
	if not is_recovering() and _shot_active and _has_intercept and _reaction_remaining <= 0.0 \
			and _intercept_seconds <= 0.45 and not _save_animation_started:
		_save_facing=atan2(ball.linear_velocity.x,ball.linear_velocity.z)
		var style := _save_style()
		_set_dive_shape(style)
		keeper._start_goalkeeper_save_pose(style, maxf(.09,_intercept_seconds-.04))
		_save_animation_started = true
	if _save_animation_started and _shot_active and not _has_intercept and ball.position.x * keeper.attack_sign < keeper.position.x * keeper.attack_sign:
		_shot_active = false
		_recovery_remaining = .35
	if is_recovering():
		keeper.ai_move_direction = Vector3.ZERO
		keeper.ai_sprinting = false
		return
	if keeper.controlled_by_human:
		return

	var target := _goal_line_position()
	if _can_follow_rebound() and keeper.global_position.distance_to(ball.global_position) < 3.0:
		target = Vector3(ball.global_position.x, keeper.global_position.y, ball.global_position.z)
	if _shot_active and _has_intercept and _reaction_remaining <= 0.0:
		target.x = keeper.global_position.x if ball.last_action == &"shot" else _predicted_intercept.x
		var width := GOAL_WIDTH*.5-.45 if ball.last_action == &"shot" else 18.0
		target.z = clampf(_predicted_intercept.z,-width,width)
	var offset := target - keeper.global_position
	offset.y = 0.0
	keeper.ai_move_direction = offset.normalized() if offset.length() > 0.18 else Vector3.ZERO
	keeper.ai_sprinting = offset.length() > 2.2
	keeper.set_meta("goalkeeper_target", target)

func try_save() -> bool:
	if not is_instance_valid(keeper) or not is_instance_valid(ball):
		return false
	if _recovery_remaining > 0 or not _inside_handling_area():
		return false
	if _try_gather_rebound():
		return true
	if ball.last_action not in [&"shot", &"cross", &"lofted_pass"] or ball.last_touch == keeper.team_name:
		return false
	_observe_action()
	if _reaction_remaining > 0.0:
		return false
	var to_keeper := keeper.global_position - ball.global_position
	to_keeper.y = 0.0
	if ball.linear_velocity.x * keeper.attack_sign >= -0.2 \
			or to_keeper.dot(Vector3(ball.linear_velocity.x, 0, ball.linear_velocity.z)) <= 0.0:
		return false
	var torso_center := keeper.global_position + Vector3.UP * 1.0
	var separation := ball.global_position - torso_center
	var flat_separation := Vector2(separation.x, separation.z).length()
	var reach := keeper.tuning.goalkeeper_save_reach if keeper.tuning != null else 0.95
	# A close physical contact window avoids remote or full-field save assistance.
	var height := ball.global_position.y - keeper.global_position.y
	if flat_separation > reach + .5 or height < 0.04 or height > 2.25:
		return false
	if not _hands_reach_ball(): return false
	var handling := 50.0
	if keeper.profile != null and keeper.profile.attributes != null:
		handling = keeper.profile.attributes.goalkeeper_handling
	var catch_speed := lerpf(4.5, 8.0, clampf(handling / 100.0, 0.0, 1.0))
	if ball.last_action in [&"cross",&"lofted_pass"]: catch_speed+=2.0
	var catch_width := keeper.tuning.goalkeeper_catch_half_width if keeper.tuning != null else 0.42
	# A two-handed catch needs the ball supported in front of the body. A slow
	# ball at full lateral stretch is still a parry, not a secure catch.
	if absf(separation.z) <= catch_width and height >= 0.55 and height <= 2.15 \
			and ball.linear_velocity.length() <= catch_speed and ball.goalkeeper_claim(keeper):
		_commit_recovery(false)
		_distribution_remaining = 0.58
		_begin_save_pose()
		keeper.status_changed.emit("Goalkeeper claims the ball")
		_shot_active = false
		_has_intercept = false
		return true
	var side := _safe_parry_side()
	var parry_direction := Vector3(keeper.attack_sign, 0.0, side * 1.15).normalized()
	var parry_speed := keeper.tuning.goalkeeper_parry_speed if keeper.tuning != null else 8.0
	parry_speed = clampf(ball.linear_velocity.length() * 0.42, parry_speed * 0.65, parry_speed * 1.25)
	if not ball.goalkeeper_save(keeper, parry_direction, parry_speed, 1.2):
		return false
	_commit_recovery(absf(separation.z) > catch_width or height < 0.55)
	_begin_save_pose()
	keeper.status_changed.emit("Goalkeeper parries the shot")
	_shot_active = false
	_has_intercept = false
	return true

func _save_style() -> StringName:
	var target := _predicted_intercept if _has_intercept else ball.global_position
	var local := keeper.to_local(target)
	var height := target.y - keeper.global_position.y
	if height > 1.65: return &"KeeperHigh"
	if height < .55:
		if absf(local.x) < .35: return &"KeeperLowCenter"
		return &"KeeperLowLeft" if local.x < 0 else &"KeeperLowRight"
	if absf(local.x) > .45:
		return &"KeeperDiveLeft" if local.x < 0 else &"KeeperDiveRight"
	return &"KeeperCatch"

func _hands_reach_ball() -> bool:
	var visual := keeper.get_node_or_null("Visual") as FootballerVisual
	if visual == null: return true # Retained physics-only fixture.
	if not _save_animation_started: return false
	var hands := visual.hand_positions()
	for hand in hands:
		# A bounded swept contact catches a fast ball crossing a glove between
		# fixed ticks. No body-radius save or relocation of keeper/ball.
		var from := ball.global_position - ball.linear_velocity / 60.0
		var near := Geometry3D.get_closest_point_to_segment(hand, from, ball.global_position)
		if hand.distance_to(near) <= .34: return true
	return false

func _can_follow_rebound() -> bool:
	# Own physical parries only. A teammate's deliberate back-pass must never
	# become a hand claim through this recovery path.
	var gather_speed := keeper.tuning.goalkeeper_rebound_gather_speed if keeper.tuning != null else 3.0
	var height := ball.global_position.y - keeper.global_position.y
	return ball.last_action == &"goalkeeper_save" and ball.last_touch_player == keeper \
		and ball.linear_velocity.length() <= gather_speed and height >= 0.04 and height <= 0.65 \
		and _inside_handling_area()

func _try_gather_rebound() -> bool:
	if not _can_follow_rebound():
		_gather_pending=false
		return false
	var offset := ball.global_position - keeper.global_position
	var reach := keeper.tuning.goalkeeper_save_reach if keeper.tuning != null else 0.95
	var width := keeper.tuning.goalkeeper_catch_half_width if keeper.tuning != null else 0.42
	if Vector2(offset.x, offset.z).length() > reach or absf(offset.z) > width \
			or offset.x * keeper.attack_sign < 0.0:
		return false
	if not _gather_pending:
		_gather_pending=true;_gather_elapsed=0;_save_animation_started=true
		keeper._start_goalkeeper_save_pose(&"KeeperLowCenter",.2)
		return false
	if not _hands_reach_ball() or not ball.goalkeeper_claim(keeper): return false
	_gather_pending=false
	_commit_recovery(false)
	_distribution_remaining = 0.58
	_save_animation_started = true
	_save_elapsed = 0.0
	_shot_active = false
	_has_intercept = false
	keeper.status_changed.emit("Goalkeeper gathers the rebound")
	return true

func is_recovering() -> bool:
	return _recovery_remaining > 0.0 or _gather_pending or (_save_animation_started and _shot_active)

func reset_for_stoppage() -> void:
	_gather_pending=false
	_restore_dive_shape()
	_recovery_remaining = 0.0
	_shot_active = false
	_has_intercept = false
	_save_animation_started = false
	_save_elapsed = 0.0
	_distribution_remaining = 0.0
	_observed_action_serial = ball.action_serial if is_instance_valid(ball) else -1

func _commit_recovery(stretched: bool) -> void:
	_recovery_remaining = 0.65 if stretched else 0.24
	if keeper.tuning != null:
		_recovery_remaining = keeper.tuning.goalkeeper_stretch_recovery_seconds if stretched else keeper.tuning.goalkeeper_standing_recovery_seconds
	var visual := keeper.get_node_or_null("Visual") as FootballerVisual
	if visual != null: _recovery_remaining = maxf(_recovery_remaining,visual.sustain_keeper_recovery())

func _set_dive_shape(style: StringName) -> void:
	if not String(style).begins_with("KeeperDive"): return
	var collider := keeper.get_node("CollisionShape3D") as CollisionShape3D
	if _original_shape == null:
		_original_shape=collider.shape;_original_shape_position=collider.position
	var shape := CapsuleShape3D.new();shape.radius=.34;shape.height=.8
	collider.shape=shape
	collider.position=Vector3(-.4 if style==&"KeeperDiveLeft" else .4,.4,-.05)
func _restore_dive_shape() -> void:
	if _original_shape == null: return
	var collider := keeper.get_node("CollisionShape3D") as CollisionShape3D
	collider.shape=_original_shape;collider.position=_original_shape_position
	_original_shape=null
func _predict_cross_claim() -> bool:
	for step in range(2,16):
		var seconds := step*.1
		var point := ball.position+ball.linear_velocity*seconds-Vector3.UP*4.905*seconds*seconds
		var depth := (point.x+52.5*keeper.attack_sign)*keeper.attack_sign
		if depth<0 or depth>16.5 or absf(point.z)>20 or point.y<.65 or point.y>2.25: continue
		var distance := Vector2(point.x-keeper.position.x,point.z-keeper.position.z).length()
		if distance>seconds*keeper.tuning.goalkeeper_move_speed+.65: continue
		_predicted_intercept=point;_intercept_seconds=seconds;return true
	return false

func _inside_handling_area() -> bool:
	# Handling legality follows the ball, not the keeper's feet. Use mirrored
	# own-penalty-area bounds and never claim a ball beyond the goal line.
	var depth := (ball.global_position.x + FIELD_LENGTH * 0.5 * keeper.attack_sign) * keeper.attack_sign
	return depth >= 0.0 and depth <= 16.5 and absf(ball.global_position.z) <= 20.16

func _observe_action() -> void:
	if ball.action_serial == _observed_action_serial:
		return
	_observed_action_serial = ball.action_serial
	_shot_active = ball.last_action in [&"shot", &"cross", &"lofted_pass"] and ball.last_touch != keeper.team_name
	_reaction_remaining = _reaction_time() if _shot_active else 0.0
	_has_intercept = false
	_save_animation_started = false
	_save_elapsed = 0.0

func _begin_save_pose() -> void:
	if not _save_animation_started:
		keeper._start_goalkeeper_save_pose(_save_style(), maxf(.09,_intercept_seconds-.04))
		_save_animation_started = true

func _safe_parry_side() -> float:
	var natural_side := signf(ball.global_position.z - keeper.global_position.z)
	if is_zero_approx(natural_side): natural_side = 1.0 if keeper.global_position.z <= 0.0 else -1.0
	var best_side := natural_side
	var best_risk := INF
	for side in [natural_side, -natural_side]:
		var target := keeper.global_position + Vector3(keeper.attack_sign * 2.0, 0, side * 4.0)
		var risk := 0.0 if side == natural_side else 0.03
		for node in keeper.get_tree().get_nodes_in_group("football_players"):
			var opponent := node as FootballPlayer
			if opponent == null or opponent.team_name == keeper.team_name \
					or opponent.profile == null or opponent.profile.role != "outfield":
				continue
			var distance := Vector2(opponent.global_position.x - target.x, opponent.global_position.z - target.z).length()
			if distance < 12.0: risk += 1.0 / maxf(distance, 0.75)
		if risk < best_risk:
			best_risk = risk
			best_side = side
	return best_side

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
	var goal_x := -FIELD_LENGTH * 0.5 * keeper.attack_sign
	var distance_from_goal := maxf((ball.global_position.x - goal_x) * keeper.attack_sign, 1.0)
	var depth := minf(3.0, distance_from_goal * 0.45)
	return Vector3(goal_x + keeper.attack_sign * depth, keeper.global_position.y,
		clampf(ball.global_position.z * depth / distance_from_goal, -3.2, 3.2))

func _predict_goalmouth_intercept() -> bool:
	var velocity := ball.linear_velocity
	if velocity.x * keeper.attack_sign >= -1.5:
		return false
	var goal_plane := -FIELD_LENGTH * 0.5 * keeper.attack_sign
	var time_to_goal := (goal_plane - ball.global_position.x) / velocity.x
	if time_to_goal <= 0.0 or absf(ball.global_position.z + velocity.z * time_to_goal) > GOAL_WIDTH * 0.5 + FootballBall.RADIUS \
			or _shot_height(time_to_goal) > GOAL_HEIGHT + FootballBall.RADIUS:
		return false
	var goal_line := keeper.global_position.x
	var time_to_line := (goal_line - ball.global_position.x) / velocity.x
	if time_to_line <= 0.02 or time_to_line > 1.65:
		return false
	var predicted_y := _shot_height(time_to_line)
	var predicted_z := ball.global_position.z + velocity.z * time_to_line
	if predicted_y < -0.3 or predicted_y > GOAL_HEIGHT + 0.2 \
			or absf(predicted_z) > GOAL_WIDTH * 0.5 + 0.6:
		return false
	_predicted_intercept = Vector3(goal_line, maxf(predicted_y, FootballBall.RADIUS), predicted_z)
	_intercept_seconds = time_to_line
	return true

func _shot_height(seconds: float) -> float:
	var ground := PitchSurface.height_at(ball.global_position.x, ball.global_position.z) if ball.use_terrain else 0.0
	var floor_y := ground + FootballBall.RADIUS
	if ball.global_position.y <= floor_y + 0.04 and ball.linear_velocity.y <= 0.3:
		return floor_y
	return maxf(floor_y, ball.global_position.y + ball.linear_velocity.y * seconds - 0.5 * GRAVITY * seconds * seconds)

func _reaction_time() -> float:
	var base := keeper.tuning.goalkeeper_reaction_seconds if keeper.tuning != null else 0.22
	var reflexes := 50.0
	if keeper.profile != null and keeper.profile.attributes != null:
		reflexes = keeper.profile.attributes.goalkeeper_reflexes
	return base * lerpf(1.25, 0.72, clampf(reflexes / 100.0, 0.0, 1.0))
