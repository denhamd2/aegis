extends RefCounted
## Chooses low-cost, short-horizon actions for an AI-controlled ball carrier.
## Team shape stays in TeamTacticsController; this only decides shoot/pass/carry.

const SHOOT_RANGE := 22.0
const CLOSE_SHOT_RANGE := 10.0
const PRESSURE_RANGE := 3.2
const MAX_SAFE_PASS_RISK := 0.60
const SHOT_BLOCK_CHECK_DISTANCE := 6.0
const SHOT_BLOCK_HALF_WIDTH := 0.8

func choose_carrier_action(carrier: FootballPlayer, teammates: Array[FootballPlayer],
		opponents: Array[FootballPlayer], ball: FootballBall, directness := 0.5) -> Dictionary:
	if carrier == null or carrier.controlled_by_human or carrier.profile == null \
			or carrier.profile.role != "outfield" or carrier.ai_action_cooldown > 0.0 \
			or ball == null or ball.last_touch != carrier.team_name \
			or ball.global_position.y > 0.62 or not carrier._can_kick() \
			or not carrier._can_start_ball_action():
		return {"type": &"none"}

	var ball_position := Vector2(ball.global_position.x, ball.global_position.z)
	var goal_position := Vector2(carrier.attack_sign * 52.5, 0.0)
	var goal_distance := ball_position.distance_to(goal_position)
	var nearest_forward_defender := INF
	var nearest_action_pressure := INF
	var goalward := (goal_position - ball_position).normalized()
	for opponent in opponents:
		if opponent == null or opponent.profile == null or opponent.profile.role != "outfield":
			continue
		var opponent_position := Vector2(opponent.global_position.x, opponent.global_position.z)
		var offset := opponent_position - ball_position
		# A trailing pursuer is pressure, but an open goalward lane is still
		# usable. Side/front pressure can justify a pass; chasing from directly
		# behind must not force a needless release before shooting range.
		if offset.dot(goalward) >= -0.5 * offset.length():
			nearest_action_pressure = minf(nearest_action_pressure, offset.length())
		if offset.dot(goalward) >= 0.0:
			nearest_forward_defender = minf(nearest_forward_defender, opponent_position.distance_to(ball_position))

	# Compare the goal opening with a reachable box delivery. A nominally
	# in-range shot from a narrow wing angle must not always suppress crossing.
	var shot := {}
	var shot_range := carrier.tuning.ai_shot_range if carrier.tuning != null else SHOOT_RANGE
	if goal_distance <= CLOSE_SHOT_RANGE or (goal_distance <= shot_range and absf(ball_position.y) <= 15.0):
		shot = _best_shot_lane(ball_position, carrier.attack_sign, opponents)
	var shot_quality := _shot_quality(ball_position,carrier.attack_sign)
	if ball_position.x * carrier.attack_sign >= 24.0 and absf(ball_position.y) >= 13.0:
		var cutback := _cutback_option(carrier,teammates,ball_position,shot_quality)
		if not cutback.is_empty() and (shot.is_empty() or shot_quality<.70): return cutback
		var toward_box := Vector3(carrier.attack_sign * 43.0, ball.position.y, 0) - ball.position
		var crossing := LoftedPassPlanner.plan(carrier, &"cross", toward_box, .72)
		var receiver := crossing.get("receiver") as FootballPlayer
		if receiver != null and teammates.has(receiver):
			var space := 6.0
			for opponent in opponents:
				if opponent==null: continue
				space=minf(space,opponent.global_position.distance_to(receiver.global_position))
			var delivery_quality := .28 + clampf((receiver.position.x*carrier.attack_sign-28)/18,0,1)*.32 \
				+ clampf((space-1)/4,0,1)*.20 - receiver.position.distance_to(ball.position)*.003
			if shot.is_empty() or delivery_quality>shot_quality+.08:
				return {"type": &"cross", "direction": toward_box, "power": .72,
					"receiver_id": receiver.get_instance_id(),
					"variant": ShotPlanner.ai_cross_style(carrier, receiver)}
	if not shot.is_empty(): return shot
	# A midfielder can release a genuinely open progressive lane before the
	# challenge arrives. An unopposed carrier still uses the available space.
	if teammates.size()>=7 and nearest_action_pressure>PRESSURE_RANGE \
			and nearest_forward_defender < lerpf(5.0, 11.0, directness):
		var progressive := _progressive_option(carrier,teammates)
		if not progressive.is_empty(): return progressive
	# Under pressure, release the ball into a forward run if a teammate and lane
	# Evaluate a progressive pass before the generic safe outlet. The outlet
	# condition below also matches high pressure, so checking it first otherwise
	# starves this branch whenever any safe teammate is available.
	if nearest_action_pressure <= PRESSURE_RANGE:
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

	# An outlet is an escape from pressure, not a reason to abandon free space.
	# Retain early release for a defender ahead, but do not recycle solely
	# because a trailing defender is four metres behind.
	if teammates.size() >= 7 and (nearest_action_pressure <= PRESSURE_RANGE or nearest_forward_defender < 5.0):
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
			var score := distance * carrier.tuning.ai_pass_distance_weight \
				+ risk * carrier.tuning.ai_pass_risk_weight \
				- offset.x * carrier.attack_sign * carrier.tuning.ai_pass_progress_weight
			if score < best_score - 0.0001 or (absf(score-best_score) < 0.0001 and best != null and candidate.profile.starting_slot < best.profile.starting_slot):
				best = candidate
				best_score = score
		if best != null:
			var forward_gain := (best.global_position.x - carrier.global_position.x) * carrier.attack_sign
			# Recycle backward when a frontal challenge is imminent; otherwise try the
			# tactical controller's open carry lane before giving up progress.
			if forward_gain >= 1.0 or nearest_forward_defender <= 2.0:
				return {"type": &"short_pass", "direction": best.global_position - carrier.global_position,
					"receiver_id": best.get_instance_id()}

	# Lift over an obstructed ground lane toward an open progressive teammate.
	# Existing useful short/through options retain priority.
	if nearest_forward_defender < 4.5:
		var option := LoftedPassPlanner.plan(carrier, &"lofted_pass", Vector3(carrier.attack_sign, 0, 0), .8)
		var receiver := option.get("receiver") as FootballPlayer
		if receiver != null and teammates.has(receiver) \
				and (receiver.position.x - carrier.position.x) * carrier.attack_sign >= 8.0 \
				and carrier._pass_lane_risk(ball.position, receiver.position) > .6:
			return {"type": &"lofted_pass", "direction": receiver.position - carrier.position,
				"power": .8, "receiver_id": receiver.get_instance_id()}
	return {"type": &"carry"}

func _shot_quality(at: Vector2, attack_sign: float) -> float:
	var depth := maxf(.5,52.5-at.x*attack_sign)
	var opening := absf(atan2(3.66-at.y,depth)-atan2(-3.66-at.y,depth))
	return clampf(.35+opening*.9-at.distance_to(Vector2(52.5*attack_sign,0))*.012,0,1)

func _cutback_option(carrier: FootballPlayer, teammates: Array[FootballPlayer],
		ball_position: Vector2, current_quality: float) -> Dictionary:
	if ball_position.x*carrier.attack_sign<43: return {}
	var best := {}
	var score := current_quality+.12
	for receiver in teammates:
		if receiver==carrier or receiver.profile.role=="goalkeeper" or absf(receiver.position.z)>9 or receiver.position.x*carrier.attack_sign<34: continue
		var target := receiver.global_position
		if target.distance_to(carrier.global_position)<5 or target.distance_to(carrier.global_position)>21: continue
		var risk := carrier._pass_lane_risk(carrier.ball.position,target)
		if risk>.35: continue
		var quality := _shot_quality(Vector2(target.x,target.z),carrier.attack_sign)-risk*.3
		if quality>score:
			score=quality
			best={"type":&"short_pass","direction":target-carrier.position,"receiver_id":receiver.get_instance_id()}
	return best

func _progressive_option(carrier: FootballPlayer, teammates: Array[FootballPlayer]) -> Dictionary:
	var best := {}
	var score := -INF
	for receiver in teammates:
		if receiver==carrier or receiver.profile.role=="goalkeeper": continue
		var target := receiver.global_position
		var distance := target.distance_to(carrier.global_position)
		var progress := (target.x-carrier.position.x)*carrier.attack_sign
		if distance<8 or distance>28 or progress<6: continue
		var risk := carrier._pass_lane_risk(carrier.ball.position,target)
		if risk>.35: continue
		var value := progress*.10-risk*2-distance*.018
		if value>score:
			score=value
			var running := receiver.velocity.x*carrier.attack_sign>1.5
			best={"type":&"through_pass" if running else &"short_pass","direction":target-carrier.position,"receiver_id":receiver.get_instance_id()}
	return best

func _best_shot_lane(ball_position: Vector2, attack_sign: float,
		opponents: Array[FootballPlayer]) -> Dictionary:
	var best := {}
	var best_score := -INF
	# A central defender may cover the centre while a corner remains open.
	# Keep endpoints safely inside the posts, and reject every lane covered by
	# an immediate body; pressure alone never manufactures an open shot.
	for lateral in [0.0, -2.65, 2.65, -1.35, 1.35]:
		var target := Vector2(52.5 * attack_sign, lateral)
		if _has_close_shot_blocker(ball_position, target, opponents):
			continue
		var score := -absf(lateral) * 0.02
		for opponent in opponents:
			if opponent != null and opponent.profile != null and opponent.profile.role == "goalkeeper":
				score += minf(absf(lateral - opponent.global_position.z), 5.0) * 0.16
		if score > best_score:
			best_score = score
			var direction := (target - ball_position).normalized()
			var charge := clampf(.50 + target.distance_to(ball_position) * .006 + .07 * sin(ball_position.x * .37 + ball_position.y), .48, .82)
			best = {"type": &"shoot", "charge": charge,
				"direction": Vector3(direction.x, 0.0, direction.y)}
	return best

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
