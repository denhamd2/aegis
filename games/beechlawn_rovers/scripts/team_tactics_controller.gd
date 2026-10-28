extends RefCounted
class_name TeamTacticsController
## Converts match context and player roles into tactical world-space targets.
## FootballPlayer remains responsible for movement execution and animation.

const FIELD_LENGTH := 105.0
const FIELD_WIDTH := 68.0
const CARRIER_CONTROL_RANGE := 1.35

func update_team_targets(team_players: Array[FootballPlayer], chaser: FootballPlayer,
		ball_position: Vector2, interception_position: Vector2,
		opponents: Array[FootballPlayer], transition_team: StringName,
		transition_time_left: float, in_possession: bool,
		secondary_presser: FootballPlayer, counterpress_active: bool,
		context: Dictionary) -> Dictionary:
	var marking_assignments := assign_defensive_marks(team_players, chaser, opponents,
		ball_position, secondary_presser) if not in_possession else {}
	var decisions := {}
	var support_plan := _support_targets(team_players, chaser, ball_position, opponents, context) if in_possession and team_players.size() >= 7 else {}
	# Last touch survives passes and loose deflections. Press an actual nearby
	# carrier; otherwise the primary chaser must reach the loose ball itself.
	var opponent_in_control_range := false
	if not in_possession:
		for opponent in opponents:
			if opponent != null and Vector2(opponent.global_position.x, opponent.global_position.z).distance_squared_to(ball_position) \
					<= CARRIER_CONTROL_RANGE * CARRIER_CONTROL_RANGE:
				opponent_in_control_range = true
				break
	for actor in team_players:
		if actor.controlled_by_human or actor.profile == null:
			continue
		var target: Vector2
		var mark: FootballPlayer
		if actor.profile.role == "goalkeeper":
			var goal_x := -FIELD_LENGTH * 0.5 * actor.attack_sign + actor.attack_sign * 3.0
			target = Vector2(goal_x, clampf(ball_position.y * 0.14, -3.2, 3.2))
		elif in_possession and actor.receive_target_time > 0.0:
			target = Vector2(actor.receive_target.x, actor.receive_target.z)
		elif in_possession and actor == chaser:
			var ball_gap := Vector2(actor.global_position.x, actor.global_position.z).distance_to(ball_position)
			if ball_gap <= 1.7 and context.get("possession_state", &"controlled") == &"controlled":
				var carry_push := 4.5 if actor.team_name == transition_team and transition_time_left > 0.0 else 3.0
				var carry_direction := Vector2(actor.attack_sign, 0.0)
				if team_players.size() >= 7 and absf(ball_position.y) > 12.0:
					# Preserve width in build-up, then improve the shooting angle.
					# Straight-ahead wide carries otherwise finish at the byline.
					var goalward := Vector2(actor.attack_sign * FIELD_LENGTH * 0.5, 0.0) - ball_position
					var turn_in := smoothstep(30.0, 46.0, ball_position.x * actor.attack_sign)
					turn_in *= smoothstep(12.0, 18.0, absf(ball_position.y))
					carry_direction = carry_direction.lerp(goalward.normalized(), turn_in).normalized()
				if team_players.size() >= 7:
					carry_direction = _open_carry_direction(ball_position, carry_direction, opponents)
				target = ball_position + carry_direction * carry_push * (0.8 + 0.4 * float(context.get("tempo", 0.5)))
			else:
				target = interception_position
		elif in_possession:
			target = support_plan.get(actor.get_instance_id(), {}).get("target",
				attacking_support_position(actor, ball_position,
					actor.team_name == transition_team and transition_time_left > 0.0, context))
		elif actor == chaser or actor == secondary_presser:
			if actor == chaser and not opponent_in_control_range:
				target = interception_position
			else:
				var side := -1.0 if actor.global_position.z < ball_position.y else 1.0
				var pressure_offset := 0.8 if actor == chaser else 1.6
				var lateral_offset := 0.65 if actor == chaser else 1.3
				target = interception_position + Vector2(-actor.attack_sign * pressure_offset,
					side * lateral_offset)
		else:
			target = defensive_shape_position(actor, ball_position,
				float(context.get("late_lead_depth", 0.0)), context)
			mark = marking_assignments.get(actor.get_instance_id()) as FootballPlayer
			if mark != null:
				target = marking_position(actor, mark, ball_position, target)
		var intent := "support" if in_possession else "cover"
		if in_possession and support_plan.has(actor.get_instance_id()) and actor != chaser:
			intent = support_plan[actor.get_instance_id()].intent
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

func _support_targets(team: Array[FootballPlayer], carrier: FootballPlayer,
		ball: Vector2, opponents: Array[FootballPlayer], context: Dictionary = {}) -> Dictionary:
	if carrier == null:
		return {}
	var result := {}
	var candidates: Array[FootballPlayer] = []
	for actor in team:
		if actor != carrier and actor.profile.role == "outfield" and actor.receive_target_time <= 0.0:
			candidates.append(actor)
	candidates.sort_custom(func(a, b): return a.profile.starting_slot < b.profile.starting_slot)
	var outlet: FootballPlayer
	var outlet_target := Vector2.ZERO
	var best_cost := INF
	var gap := carrier.tuning.ai_support_distance * (0.75 + 0.5 * float(context.get("width", 0.5)))
	for actor in candidates:
		if actor.profile.tactical_role == "centre_back":
			continue
		for side in [-1.0, 1.0]:
			var target := ball + Vector2(-3.5 * carrier.attack_sign, side * gap)
			target = Vector2(clampf(target.x,-46,46),clampf(target.y,-29,29))
			var cost := Vector2(actor.position.x,actor.position.z).distance_to(target)
			for defender in opponents:
				if defender.profile.role == "outfield":
					cost += maxf(0, 4.0-Vector2(defender.position.x,defender.position.z).distance_to(target)) * 2.0
			if cost < best_cost:
				outlet = actor;outlet_target = target;best_cost = cost
	if outlet != null:
		result[outlet.get_instance_id()] = {"target": outlet_target,"intent": "outlet"}
	var runner: FootballPlayer
	var runner_target := Vector2.ZERO
	best_cost = INF
	for actor in candidates:
		if actor == outlet or actor.profile.tactical_role not in ["striker", "winger", "attacking_midfielder"]:
			continue
		var lane := clampf(actor.profile.starting_position.y, -14.0,14.0)
		var target := ball + Vector2(carrier.attack_sign * carrier.tuning.ai_forward_run_distance
			* (0.8 + 0.4 * float(context.get("directness", 0.5))), 0)
		target.y = clampf(lerpf(lane,ball.y,.25),-25,25)
		target.x = clampf(target.x,-46,46)
		var cost := Vector2(actor.position.x,actor.position.z).distance_to(target)
		for defender in opponents:
			if defender.profile.role == "outfield":
				cost += maxf(0, 4.0-Vector2(defender.position.x,defender.position.z).distance_to(target)) * 2.0
		if cost < best_cost:
			runner = actor;runner_target = target;best_cost = cost
	if runner != null:
		result[runner.get_instance_id()] = {"target": runner_target,"intent": "forward_run"}
	# Wide deliveries need runners in the area before a cross can be selected.
	if ball.x * carrier.attack_sign > 22 and absf(ball.y) > 13:
		var forwards := candidates.filter(func(a): return a.profile.tactical_role == "striker")
		for index in forwards.size():
			var forward: FootballPlayer = forwards[index]
			result[forward.get_instance_id()] = {"target": Vector2(43 * carrier.attack_sign, signf(ball.y) * (3.5 if index == 0 else -5.0)), "intent":"box_run"}
	return result

func _open_carry_direction(origin: Vector2, preferred: Vector2,
		opponents: Array[FootballPlayer]) -> Vector2:
	var best := preferred
	var best_score := -INF
	for angle in [0.0, 0.65, -0.65]:
		var direction := preferred.rotated(angle * (1.0 if preferred.x >= 0.0 else -1.0))
		var destination := origin + direction * 4.0
		var clearance := 4.0
		for opponent in opponents:
			if opponent == null or opponent.profile == null or opponent.profile.role != "outfield":
				continue
			var offset := Vector2(opponent.global_position.x, opponent.global_position.z) - origin
			var ahead := offset.dot(direction)
			if ahead < 0.0:
				continue
			clearance = minf(clearance, (offset - direction * clampf(ahead, 0.0, 4.0)).length())
		var score := direction.dot(preferred) * 2.0 + clearance * 1.5
		if absf(destination.x) > FIELD_LENGTH * 0.5 - 1.0 or absf(destination.y) > FIELD_WIDTH * 0.5 - 2.0:
			score -= 10.0
		if score > best_score:
			best = direction
			best_score = score
	return best

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
	# Stable role slots make greedy assignment independent of actor creation/order.
	defenders.sort_custom(func(a, b): return a.profile.starting_slot < b.profile.starting_slot)
	available.sort_custom(func(a, b): return a.profile.starting_slot < b.profile.starting_slot)
	var assignments := {}
	for defender in defenders:
		var best: FootballPlayer
		var best_cost := INF
		for opponent in available:
			var distance := defender.global_position.distance_to(opponent.global_position)
			var slot_lane := defender.profile.starting_position.y
			if team_players.size() >= 7 and (distance > 18.0 or absf(opponent.global_position.z-slot_lane)>14.0):
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
		if distance < nearest_distance - .0001 or (absf(distance-nearest_distance) < .0001 and nearest != null and actor.profile.starting_slot < nearest.profile.starting_slot):
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
		transition_push := false, context: Dictionary = {}) -> Vector2:
	if actor.profile.starting_slot not in ["left", "center", "right", "keeper"]:
		return formation_position(actor, ball_position, true, transition_push, 0.0, context)
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
		late_lead_depth: float, context: Dictionary = {}) -> Vector2:
	if actor.profile.starting_slot not in ["left", "center", "right", "keeper"]:
		return formation_position(actor, ball_position, false, false, late_lead_depth, context)
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
		transition: bool, lead_depth := 0.0, context: Dictionary = {}) -> Vector2:
	var base := actor.profile.starting_position
	var role := actor.profile.tactical_role
	var forward_ball := ball.x * actor.attack_sign
	var depth := float(context.get("depth", 0.5))
	var width := float(context.get("width", 0.5))
	var shift := clampf(forward_ball * 0.38, -16.0, 21.0) + (depth - 0.5) * 8.0
	var forward := base.x + shift
	var lane := base.y * (0.75 + 0.5 * width) + ball.y * 0.16
	if attacking:
		match role:
			"centre_back": forward = minf(forward, forward_ball - 13.0)
			"fullback": forward = minf(forward + 7.0, forward_ball - 6.0)
			"defensive_midfielder": forward = minf(forward, forward_ball - 8.0)
			"central_midfielder": forward = lerpf(base.x + shift, forward_ball - 4.5, 0.55)
			"attacking_midfielder": forward = maxf(forward, forward_ball + (5.0 if transition else 2.0))
			"winger":
				forward = maxf(forward, forward_ball + (9.0 if transition else 5.0))
				lane = base.y * (0.75 + 0.5 * width) * 0.94 + ball.y * 0.06
			"striker": forward = maxf(forward, forward_ball + (12.0 if transition else 8.0))
	else:
		var role_gap := 16.0 if role in ["centre_back", "fullback"] else 10.0 if role == "defensive_midfielder" else 5.0 if role == "attacking_midfielder" else 7.0 if role != "striker" else 1.5
		role_gap -= (depth - 0.5) * 8.0
		forward = minf(forward - lead_depth, forward_ball - role_gap)
		lane = base.y * (0.75 + 0.5 * width) * 0.78 + ball.y * 0.22
	return Vector2(clampf(forward, -46.0, 46.0) * actor.attack_sign, clampf(lane, -29.0, 29.0))
