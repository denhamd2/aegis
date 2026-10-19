extends RefCounted
## Chooses low-cost, short-horizon actions for an AI-controlled ball carrier.
## Team shape stays in TeamTacticsController; this only decides shoot/pass/carry.

const SHOOT_RANGE := 18.0
const CLOSE_SHOT_RANGE := 10.0
const PRESSURE_RANGE := 3.2
const MAX_SAFE_PASS_RISK := 0.60
const SHOT_BLOCK_CHECK_DISTANCE := 6.0
const SHOT_BLOCK_HALF_WIDTH := 0.8

func choose_carrier_action(carrier: FootballPlayer, teammates: Array[FootballPlayer],
		opponents: Array[FootballPlayer], ball: FootballBall) -> Dictionary:
	if carrier == null or carrier.controlled_by_human or carrier.profile == null \
			or carrier.profile.role != "outfield" or carrier.ai_action_cooldown > 0.0 \
			or ball == null or ball.last_touch != carrier.team_name \
			or ball.global_position.y > 0.62 or not carrier._can_kick():
		return {"type": &"none"}

	var ball_position := Vector2(ball.global_position.x, ball.global_position.z)
	var goal_position := Vector2(carrier.attack_sign * 52.5, 0.0)
	var goal_distance := ball_position.distance_to(goal_position)
	var nearest_defender := INF
	for opponent in opponents:
		if opponent == null or opponent.profile == null or opponent.profile.role != "outfield":
			continue
		var opponent_position := Vector2(opponent.global_position.x, opponent.global_position.z)
		nearest_defender = minf(nearest_defender, opponent_position.distance_to(ball_position))

	# Pressure behind or beside the carrier does not necessarily block a shot.
	# Check the immediate goalward corridor rather than vetoing every attempt
	# whenever any defender is within three metres of the ball.
	var central_enough := absf(ball_position.y) <= 15.0
	var can_take_shot := goal_distance <= CLOSE_SHOT_RANGE \
		or (goal_distance <= SHOOT_RANGE and central_enough \
			and not _has_close_shot_blocker(ball_position, goal_position, opponents))
	if can_take_shot:
		return {"type": &"shoot", "charge": 0.42}
	# Under pressure, release the ball into a forward run if a teammate and lane
	# Evaluate a progressive pass before the generic safe outlet. The outlet
	# condition below also matches high pressure, so checking it first otherwise
	# starves this branch whenever any safe teammate is available.
	if nearest_defender <= PRESSURE_RANGE:
		var forward := Vector3(carrier.attack_sign, 0.0, 0.0)
		var pass_option := carrier._choose_pass_target(forward, true)
		var receiver := pass_option.get("receiver") as FootballPlayer
		if receiver != null and teammates.has(receiver):
			var target: Vector3 = pass_option.get("position", receiver.global_position)
			var forward_gain := (target.x - ball.global_position.x) * carrier.attack_sign
			var lane_risk := carrier._pass_lane_risk(ball.global_position, target)
			if forward_gain >= 2.0 and lane_risk <= MAX_SAFE_PASS_RISK:
				return {"type": &"through_pass", "direction": forward,
					"receiver_id": receiver.get_instance_id()}

	if teammates.size() == 11 and nearest_defender < 5.0:
		var best: FootballPlayer
		var best_score := INF
		for candidate in teammates:
			if candidate == carrier or candidate.profile.role == "goalkeeper":
				continue
			var offset := candidate.global_position - carrier.global_position
			var distance := offset.length()
			if distance < 5.0 or distance > 30.0:
				continue
			var risk := carrier._pass_lane_risk(ball.global_position, candidate.global_position)
			if risk > 0.6:
				continue
			var score := distance * 0.12 + risk * 9.0 - offset.x * carrier.attack_sign * 0.2
			if score < best_score:
				best = candidate
				best_score = score
		if best != null:
			return {"type": &"short_pass", "direction": best.global_position - carrier.global_position}

	return {"type": &"carry"}

func _has_close_shot_blocker(ball_position: Vector2, goal_position: Vector2,
		opponents: Array[FootballPlayer]) -> bool:
	var path := goal_position - ball_position
	var distance := path.length()
	if distance < 0.01:
		return false
	var direction := path / distance
	for opponent in opponents:
		if opponent == null or opponent.profile == null or opponent.profile.role != "outfield":
			continue
		var offset := Vector2(opponent.global_position.x, opponent.global_position.z) - ball_position
		var ahead := offset.dot(direction)
		if ahead <= 0.0 or ahead > minf(distance, SHOT_BLOCK_CHECK_DISTANCE):
			continue
		if (offset - direction * ahead).length_squared() <= SHOT_BLOCK_HALF_WIDTH * SHOT_BLOCK_HALF_WIDTH:
			return true
	return false
