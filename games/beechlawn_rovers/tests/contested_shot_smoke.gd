extends SceneTree
## A frontal defender blocks one lane, not every visible part of the goal.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var ball := game.get_node("Ball") as FootballBall
	for actor in game._home_players + game._away_players:
		actor.set_physics_process(false)
		actor.controlled_by_human = false
		actor.global_position = Vector3(0, 0, 30)
	for sign_value in [1.0, -1.0]:
		var attacking: Array[FootballPlayer] = game._home_players if sign_value > 0 else game._away_players
		var defending: Array[FootballPlayer] = game._away_players if sign_value > 0 else game._home_players
		var carrier: FootballPlayer
		var blocker: FootballPlayer
		for actor in attacking:
			if actor.profile.role == "outfield":
				carrier = actor
				break
		for actor in defending:
			if actor.profile.role == "outfield":
				blocker = actor
				break
		carrier.global_position = Vector3(sign_value * 35.85, 0, 0)
		carrier.rotation.y = -PI / 2.0 * sign_value
		carrier._flat_direction = Vector3.RIGHT * sign_value
		carrier.ai_action_cooldown = 0.0
		ball.freeze = true
		ball.global_position = Vector3(sign_value * 36.5, 0.13, 0)
		ball.linear_velocity = Vector3.ZERO
		ball.last_touch = carrier.team_name
		ball.last_action = &"dribble"
		blocker.global_position = ball.global_position + Vector3(sign_value * 5.0, -0.13, 0)
		await physics_frame
		var decision: Dictionary = game._player_decisions.choose_carrier_action(carrier, attacking, defending, ball)
		var direction: Vector3 = decision.get("direction", Vector3.ZERO)
		print("CONTESTED_SHOT team=", carrier.team_name, " choice=", decision.get("type"), " direction=", direction)
		if decision.get("type") != &"shoot" or absf(direction.z) < 0.08:
			failures.append("%s rejected an open corner beside a central defender" % carrier.team_name)
		# The same defender within immediate body-contact range should force a
		# different choice; this is not a blanket instruction to shoot more.
		blocker.global_position = ball.global_position + Vector3(sign_value, -0.13, 0)
		var blocked: Dictionary = game._player_decisions.choose_carrier_action(carrier, attacking, defending, ball)
		if blocked.get("type") == &"shoot":
			failures.append("%s shot through a defender blocking all immediate lanes" % carrier.team_name)
		blocker.global_position = ball.global_position + Vector3(sign_value * 5.0, -0.13, 0)
		blocker.ai_move_direction = Vector3.LEFT * sign_value
		blocker.rotation.y = PI / 2.0 * sign_value
		blocker.velocity = Vector3.ZERO
		blocker.set_physics_process(true)
		carrier.ai_move_direction = Vector3.ZERO
		carrier.velocity = Vector3.ZERO
		carrier.set_physics_process(true)
		var physical := {"shots": 0, "gap": INF}
		var observe := func(kind: StringName, _speed: float):
			if kind == &"shot":
				physical["shots"] += 1
				physical["gap"] = carrier._receive_contact_position().distance_to(ball.global_position)
		ball.touched.connect(observe)
		ball.freeze = false
		game._apply_carrier_action(carrier, attacking, defending)
		for tick in 45:
			await physics_frame
			if int(physical["shots"]) > 0: break
		print("CONTESTED_CONTACT team=", carrier.team_name, " physical_shots=", physical["shots"], " gap_m=", physical["gap"])
		if int(physical["shots"]) != 1 or float(physical["gap"]) > carrier.tuning.kick_foot_contact_radius:
			failures.append("%s failed to execute its contested shot at physical boot contact" % carrier.team_name)
		ball.touched.disconnect(observe)
		ball.freeze = true
		carrier.set_physics_process(false)
		blocker.set_physics_process(false)
		carrier.global_position = Vector3(0, 0, 30)
		blocker.global_position = Vector3(0, 0, 30)
		var outlet: FootballPlayer
		for actor in attacking:
			if actor != carrier and actor.profile.role == "outfield":
				outlet = actor
				break
		carrier.global_position = Vector3(sign_value * 29.85, 0, 0)
		carrier.ai_action_cooldown = 0.0
		ball.global_position = Vector3(sign_value * 30.5, 0.13, 0)
		ball.last_touch = carrier.team_name
		ball.last_action = &"dribble"
		blocker.global_position = ball.global_position - Vector3(sign_value * 1.8, 0.13, 0)
		outlet.global_position = ball.global_position + Vector3(-sign_value * 10.0, -0.13, 8.0)
		await physics_frame
		var escape: Dictionary = game._player_decisions.choose_carrier_action(carrier, attacking, defending, ball)
		if escape.get("type") not in [&"carry", &"shoot"]:
			failures.append("%s recycled backwards into trailing pressure despite an open goalward route" % carrier.team_name)
		carrier.global_position = Vector3(sign_value * 31.35, 0, 0)
		ball.global_position = Vector3(sign_value * 32.0, 0.13, 0)
		blocker.global_position = ball.global_position - Vector3(sign_value * 1.8, 0.13, 0)
		await physics_frame
		var edge_shot: Dictionary = game._player_decisions.choose_carrier_action(carrier, attacking, defending, ball)
		if edge_shot.get("type") != &"shoot":
			failures.append("%s declined a clear 20.5 m attempt under trailing pressure" % carrier.team_name)
		carrier.global_position = Vector3(sign_value * 35.85, 0, 0)
		ball.global_position = Vector3(sign_value * 36.5, 0.13, 0)
		blocker.global_position = ball.global_position - Vector3(sign_value * 1.8, 0.13, 0)
		var visual := carrier.get_node("Visual") as FootballerVisual
		visual.animation_player.stop()
		visual._active_action = &""
		visual.play_get_up()
		carrier.ai_action_cooldown = 0.0
		game._apply_carrier_action(carrier, attacking, defending)
		if carrier.ai_action_cooldown > 0.0:
			failures.append("%s consumed its shot cooldown while committed recovery prevented the action" % carrier.team_name)
		visual.animation_player.stop()
		visual._active_action = &""
		visual.animation_tree.active = true
		carrier.global_position = Vector3(0, 0, 30)
		blocker.global_position = Vector3(0, 0, 30)
		outlet.global_position = Vector3(0, 0, 30)
	for message in failures: push_error(message)
	game.free()
	quit(0 if failures.is_empty() else 1)
