extends RefCounted
class_name TeamTacticsController
## Converts match context and player roles into tactical world-space targets.
## FootballPlayer remains responsible for movement execution and animation.

const FIELD_LENGTH := 105.0
const FIELD_WIDTH := 68.0

func update_team_targets(team_players: Array[FootballPlayer], chaser: FootballPlayer,
		ball_position: Vector2, interception_position: Vector2,
		opponents: Array[FootballPlayer], transition_team: StringName,
		transition_time_left: float, in_possession: bool,
		secondary_presser: FootballPlayer, counterpress_active: bool,
		context: Dictionary) -> Dictionary:
	var marking_assignments := assign_defensive_marks(team_players, chaser, opponents,
		ball_position, secondary_presser) if not in_possession else {}
	var decisions := {}
	for actor in team_players:
		if actor.controlled_by_human or actor.profile == null:
			continue
		var target: Vector2
		var mark: FootballPlayer
		if actor.profile.role == "goalkeeper":
			var goal_x := -FIELD_LENGTH * 0.5 * actor.attack_sign + actor.attack_sign * 3.0
			target = Vector2(goal_x, clampf(ball_position.y * 0.14, -3.2, 3.2))
		elif actor.receive_target_time > 0.0:
			target = Vector2(actor.receive_target.x, actor.receive_target.z)
		elif in_possession and actor == chaser:
			var ball_gap := Vector2(actor.global_position.x, actor.global_position.z).distance_to(ball_position)
			if ball_gap <= 1.7:
				var carry_push := 4.5 if actor.team_name == transition_team and transition_time_left > 0.0 else 3.0
				target = ball_position + Vector2(actor.attack_sign * carry_push, 0.0)
			else:
				target = interception_position
		elif in_possession:
			target = attacking_support_position(actor, ball_position,
				actor.team_name == transition_team and transition_time_left > 0.0)
		elif actor == chaser or actor == secondary_presser:
			var side := -1.0 if actor.global_position.z < ball_position.y else 1.0
			var pressure_offset := 0.8 if actor == chaser else 1.6
			var lateral_offset := 0.65 if actor == chaser else 1.3
			target = interception_position + Vector2(-actor.attack_sign * pressure_offset,
				side * lateral_offset)
		else:
			target = defensive_shape_position(actor, ball_position,
				float(context.get("late_lead_depth", 0.0)))
			mark = marking_assignments.get(actor.get_instance_id()) as FootballPlayer
			if mark != null:
				target = marking_position(actor, mark, ball_position, target)
		var intent := "support" if in_possession else "cover"
		if in_possession and actor == chaser:
			intent = "carry"
		elif not in_possession and actor == chaser:
			intent = "press"
		elif not in_possession and actor == secondary_presser:
			intent = "counterpress" if counterpress_active else "second_press"
		elif not in_possession and marking_assignments.has(actor.get_instance_id()):
			intent = "mark"
		decisions[actor.get_instance_id()] = {
			"target": target,
			"intent": intent,
			"assigned_mark": mark.profile.player_id if mark != null else &"",
		}
	return decisions

func assign_defensive_marks(team_players: Array[FootballPlayer], chaser: FootballPlayer,
		opponents: Array[FootballPlayer], ball_position: Vector2,
		secondary_presser: FootballPlayer = null) -> Dictionary:
	var candidates: Array[FootballPlayer] = []
	for opponent in opponents:
		if opponent.profile != null and opponent.profile.role == "outfield":
			candidates.append(opponent)
	var opponent_chaser := nearest_outfielder(opponents, ball_position)
	var available: Array[FootballPlayer] = []
	for candidate in candidates:
		if candidate != opponent_chaser:
			available.append(candidate)
	var defenders: Array[FootballPlayer] = []
	for actor in team_players:
		if actor == chaser or actor == secondary_presser or actor.controlled_by_human \
				or actor.profile == null or actor.profile.role != "outfield":
			continue
		defenders.append(actor)
	var assignments := {}
	for defender in defenders:
		var best: FootballPlayer
		var best_cost := INF
		for opponent in available:
			var distance := defender.global_position.distance_to(opponent.global_position)
			var slot_lane := defender.profile.starting_position.y
			if team_players.size() == 11 and (distance > 18.0 or absf(opponent.global_position.z-slot_lane)>14.0):
				continue
			var lane_cost := absf(opponent.global_position.z - slot_lane) * 0.28
			var danger_reward := maxf(0.0, ball_position.x * defender.attack_sign
				- opponent.global_position.x * defender.attack_sign) * 0.08
			var cost := distance + lane_cost - danger_reward
			if cost < best_cost:
				best_cost = cost
				best = opponent
		if best != null:
			assignments[defender.get_instance_id()] = best
			available.erase(best)
	return assignments

func nearest_outfielder(team_players: Array[FootballPlayer], target: Vector2) -> FootballPlayer:
	var nearest: FootballPlayer
	var nearest_distance := INF
	for actor in team_players:
		if actor.profile == null or actor.profile.role != "outfield":
			continue
		var distance := Vector2(actor.global_position.x, actor.global_position.z).distance_squared_to(target)
		if distance < nearest_distance:
			nearest = actor
			nearest_distance = distance
	return nearest

func marking_position(defender: FootballPlayer, opponent: FootballPlayer,
		ball_position: Vector2, cover_target: Vector2) -> Vector2:
	var threat := Vector2(opponent.global_position.x, opponent.global_position.z)
	var threat_forward := threat.x * defender.attack_sign
	var ball_forward := ball_position.x * defender.attack_sign
	var cover_forward := cover_target.x * defender.attack_sign
	var marked_forward := minf(threat_forward - 2.2, ball_forward - 1.5)
	var target_forward := lerpf(cover_forward, marked_forward, 0.84)
	var target_lateral := lerpf(threat.y, cover_target.y, 0.16)
	return Vector2(target_forward * defender.attack_sign, target_lateral)

func attacking_support_position(actor: FootballPlayer, ball_position: Vector2,
		transition_push := false) -> Vector2:
	if actor.profile.starting_slot not in ["left", "center", "right", "keeper"]:
		return formation_position(actor, ball_position, true, transition_push)
	var slot := actor.profile.starting_slot
	var forward_ball := ball_position.x * actor.attack_sign
	var base_forward := actor.profile.starting_position.x
	var lead := (7.0 if slot == "center" else 4.0) if transition_push else (4.5 if slot == "center" else 2.0)
	var desired_forward := maxf(base_forward, forward_ball + lead)
	var forward := lerpf(base_forward, desired_forward, 0.68 if transition_push else 0.48)
	forward = clampf(forward, -FIELD_LENGTH * 0.5 + 5.0, FIELD_LENGTH * 0.5 - 5.0)
	var lane := actor.profile.starting_position.y
	var lateral := lerpf(lane, ball_position.y, 0.38 if slot == "center" else 0.12)
	if slot == "center":
		lateral = lerpf(lateral, 0.0, 0.32)
	lateral = clampf(lateral, -FIELD_WIDTH * 0.5 + 4.0, FIELD_WIDTH * 0.5 - 4.0)
	return Vector2(forward * actor.attack_sign, lateral)

func defensive_shape_position(actor: FootballPlayer, ball_position: Vector2,
		late_lead_depth: float) -> Vector2:
	if actor.profile.starting_slot not in ["left", "center", "right", "keeper"]:
		return formation_position(actor, ball_position, false, false, late_lead_depth)
	var slot := actor.profile.starting_slot
	var forward_ball := ball_position.x * actor.attack_sign
	var base_forward := actor.profile.starting_position.x
	var ball_side_gap := (6.0 if slot == "center" else 9.0) + late_lead_depth
	var defensive_line := clampf(forward_ball - ball_side_gap,
		-FIELD_LENGTH * 0.5 + 6.0, FIELD_LENGTH * 0.5 - 6.0)
	var forward := minf(lerpf(base_forward, defensive_line, 0.46), defensive_line)
	var lane := actor.profile.starting_position.y
	var shift := 0.3 if slot == "center" else 0.18
	var lateral := lerpf(lane, ball_position.y, shift)
	if slot == "center":
		lateral = lerpf(lateral, 0.0, 0.28)
	lateral = clampf(lateral, -FIELD_WIDTH * 0.5 + 4.0, FIELD_WIDTH * 0.5 - 4.0)
	return Vector2(forward * actor.attack_sign, lateral)

func formation_position(actor: FootballPlayer, ball: Vector2, attacking: bool,
		transition: bool, lead_depth := 0.0) -> Vector2:
	var base := actor.profile.starting_position
	var role := actor.profile.tactical_role
	var forward_ball := ball.x * actor.attack_sign
	var shift := clampf(forward_ball * 0.38, -16.0, 21.0)
	var forward := base.x + shift
	var lane := base.y + ball.y * 0.16
	if attacking:
		match role:
			"centre_back": forward = minf(forward, forward_ball - 13.0)
			"fullback": forward = minf(forward + 7.0, forward_ball - 6.0)
			"central_midfielder": forward = lerpf(base.x + shift, forward_ball - 4.5, 0.55)
			"winger":
				forward = maxf(forward, forward_ball + (9.0 if transition else 5.0))
				lane = base.y * 0.94 + ball.y * 0.06
			"striker": forward = maxf(forward, forward_ball + (12.0 if transition else 8.0))
	else:
		var role_gap := 16.0 if role in ["centre_back", "fullback"] else 7.0 if role != "striker" else 1.5
		forward = minf(forward - lead_depth, forward_ball - role_gap)
		lane = base.y * 0.78 + ball.y * 0.22
	return Vector2(clampf(forward, -46.0, 46.0) * actor.attack_sign, clampf(lane, -29.0, 29.0))
