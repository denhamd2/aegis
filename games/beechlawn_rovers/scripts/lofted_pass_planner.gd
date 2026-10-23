extends RefCounted
class_name LoftedPassPlanner
## Bounded assistance and real airborne launch velocities for both teams.

static func plan(passer: FootballPlayer, kind: StringName, direction: Vector3,
		power: float, requested_receiver: FootballPlayer = null) -> Dictionary:
	var ball := passer.ball
	var intent := Vector3(direction.x, 0, direction.z).normalized()
	if intent.length_squared() < 0.1: return {}
	var crossing := kind == &"cross"
	var maximum := lerpf(16.0, passer.tuning.lofted_pass_max_range, clampf(power, 0, 1))
	var best: FootballPlayer
	var best_score := INF
	for node in passer.get_tree().get_nodes_in_group("football_players"):
		var candidate := node as FootballPlayer
		if not _eligible(passer, candidate): continue
		if requested_receiver != null and candidate != requested_receiver: continue
		var offset := candidate.global_position - ball.global_position
		offset.y = 0
		var distance := offset.length()
		if distance < 4.0 or distance > maximum or offset.normalized().dot(intent) < 0.60: continue
		if crossing and (candidate.position.x * passer.attack_sign < 27.0 or absf(candidate.position.z) > 14.0): continue
		var role_cost := 0.0 if candidate.profile.tactical_role == "striker" else 0.55
		var score := (1.0 - offset.normalized().dot(intent)) * 5.0 + distance * .025
		score += role_cost if crossing else 0.0
		for opponent in passer.get_tree().get_nodes_in_group("football_players"):
			if opponent.team_name != passer.team_name:
				score += maxf(0, 3.0 - Vector2(opponent.position.x - candidate.position.x,
					opponent.position.z - candidate.position.z).length()) * .7
		if score < best_score - .0001 or (absf(score - best_score) < .0001 and best != null and candidate.profile.starting_slot < best.profile.starting_slot):
			best = candidate
			best_score = score
	if requested_receiver != null and best == null: return {}
	var target := ball.global_position + intent * lerpf(12, maximum, .85)
	if best != null:
		target = best.global_position
		var lead_time := clampf(target.distance_to(ball.position) / 20.0, .3, 1.1)
		var run := Vector3(best.velocity.x, 0, best.velocity.z)
		target += (run * lead_time).limit_length(5.0)
		if crossing and run.length() < .8:
			target.x += passer.attack_sign * minf(1.8, maxf(0, 46.0 - target.x * passer.attack_sign))
	target.x = clampf(target.x, -50.0, 50.0)
	target.z = clampf(target.z, -32.0, 32.0)
	var ground := PitchSurface.height_at(target.x, target.z) if ball.use_terrain else 0.0
	target.y = ground + (passer.tuning.header_contact_height if crossing else FootballBall.RADIUS)
	var flat_distance := Vector2(target.x - ball.position.x, target.z - ball.position.z).length()
	var flight_seconds := clampf(flat_distance / lerpf(13.0, 23.0, power) + (.45 if crossing else .65), .85, 2.65)
	var velocity := FootballBallFlight.launch(ball, target, flight_seconds)
	if not velocity.is_finite() or velocity.length() > 37.0: return {}
	return {"receiver": best, "position": target, "velocity": velocity,
		"flight_seconds": flight_seconds, "kind": kind}

static func _eligible(passer: FootballPlayer, candidate: FootballPlayer) -> bool:
	return is_instance_valid(candidate) and candidate != passer and candidate.team_name == passer.team_name \
		and candidate.profile != null and candidate.profile.role == "outfield"

static func assign_runs(passer: FootballPlayer, option: Dictionary, preparing := false) -> void:
	var receiver := option.get("receiver") as FootballPlayer
	if receiver != null:
		receiver.receive_target = option.position
		receiver.receive_target_kind = option.kind
		receiver.receive_target_time = .65 if preparing else option.flight_seconds + 1.0
	if option.kind != &"cross": return
	# A second attacker occupies the other post; midfield/defensive cover stays
	# in the tactical controller instead of sending the whole team into the box.
	var support: FootballPlayer
	var best_gap := INF
	var side := -1.0 if option.position.z > 0 else 1.0
	var target := Vector3(43.5 * passer.attack_sign, 0, side * 5.5)
	for node in passer.get_tree().get_nodes_in_group("football_players"):
		var actor := node as FootballPlayer
		if not _eligible(passer, actor) or actor == receiver or actor.profile.tactical_role not in ["striker", "winger"]: continue
		var gap := actor.position.distance_to(target)
		if gap < best_gap:
			best_gap = gap
			support = actor
	if support != null:
		support.receive_target = target
		support.receive_target_kind = &"cross_run"
		support.receive_target_time = .65 if preparing else option.flight_seconds + .8
