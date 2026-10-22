extends RefCounted
## A read-only tactical view. Rules keep FootballBall.last_touch unchanged.
## This never grants control, applies forces or authorizes a remote kick.
func sample(ball: FootballBall, actors: Array[FootballPlayer], stopped := false) -> Dictionary:
	var result := {"state": &"loose", "team": &"none", "carrier": null}
	if stopped:
		result.state = &"stopped"
		return result
	if is_instance_valid(ball.goalkeeper_holder):
		return {"state": &"controlled", "team": ball.goalkeeper_holder.team_name,
			"carrier": ball.goalkeeper_holder}
	var owner := ball._dribble_controller as FootballPlayer if is_instance_valid(ball._dribble_controller) else null
	if is_instance_valid(owner) and ball._dribble_control_lease > 0.0 \
			and owner.team_name == ball.last_touch and _flat_gap(owner, ball) <= 1.38 \
			and ball.global_position.y - owner.global_position.y <= ball.tuning.dribble_max_height:
		return {"state": &"controlled", "team": owner.team_name, "carrier": owner}
	# Present contact takes priority over interception prediction. The opponent
	# still needs its existing 0.55 m physical gather range, not kick assistance.
	var nearest_by_team := {}
	for actor in actors:
		if actor.profile == null or actor.profile.role != "outfield" \
				or ball.global_position.y - actor.global_position.y > ball.tuning.dribble_max_height:
			continue
		if ball.last_action == &"shot" and actor.team_name == ball.last_touch and ball.linear_velocity.length() > 3.0:
			continue
		var gap := _flat_gap(actor, ball)
		var reach := actor.tuning.kick_assist_radius if actor.team_name == ball.last_touch else 0.55
		if gap > reach:
			continue
		var previous: Dictionary = nearest_by_team.get(actor.team_name, {})
		if previous.is_empty() or gap < float(previous.gap) - .0001 \
				or (absf(gap-float(previous.gap)) < .0001 and actor.profile.starting_slot < previous.actor.profile.starting_slot):
			nearest_by_team[actor.team_name] = {"actor": actor, "gap": gap}
	var nearest := nearest_by_team.values()
	nearest.sort_custom(func(a, b): return a.gap < b.gap)
	if nearest.size() > 1 and absf(float(nearest[0].gap)-float(nearest[1].gap)) < .08:
		result.state = &"contested"
		return result
	if not nearest.is_empty():
		var closest: FootballPlayer = nearest[0].actor
		return {"state": &"controlled", "team": closest.team_name, "carrier": closest}
	# A pass in flight gives the receiving side support runs, not a ball carrier.
	if ball.last_action in [&"pass", &"through_pass"] and ball.linear_velocity.length() > 0.7:
		for actor in actors:
			if actor.team_name == ball.last_touch and actor.receive_target_time > 0.0:
				var to_target := actor.receive_target - ball.global_position
				if to_target.dot(ball.linear_velocity) > 0.0:
					return {"state": &"incoming", "team": ball.last_touch, "carrier": null}
	return result

func _flat_gap(actor: FootballPlayer, ball: FootballBall) -> float:
	return Vector2(actor.global_position.x - ball.global_position.x,
		actor.global_position.z - ball.global_position.z).length()
