extends SceneTree
## A blocked straight runner must not hide an open diagonal through-ball lane.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var ball := game.get_node("Ball") as FootballBall
	ball.freeze = true
	for actor in game._home_players + game._away_players:
		actor.set_physics_process(false)
		actor.controlled_by_human = false
	for team: Array[FootballPlayer] in [game._home_players, game._away_players]:
		var opposition: Array[FootballPlayer] = game._away_players if team == game._home_players else game._home_players
		var attackers: Array[FootballPlayer] = []
		var defenders: Array[FootballPlayer] = []
		for actor in game._home_players + game._away_players:
			actor.global_position = Vector3(-40.0, 0.0, 30.0)
			actor.velocity = Vector3.ZERO
		for actor in team:
			if actor.profile.role == "outfield":
				attackers.append(actor)
		for actor in opposition:
			if actor.profile.role == "outfield":
				defenders.append(actor)
		var carrier := attackers[0]
		var blocked_runner := attackers[1]
		var open_runner := attackers[2]
		var direction := Vector3(carrier.attack_sign, 0.0, 0.0)
		carrier.global_position = Vector3.ZERO
		carrier.ai_action_cooldown = 0.0
		blocked_runner.global_position = direction * 20.0
		open_runner.global_position = direction * 17.0 + Vector3(0.0, 0.0, 8.0)
		defenders[0].global_position = Vector3(0.0, 0.0, -2.8)
		defenders[1].global_position = direction * 10.0
		ball.global_position = direction * 0.6 + Vector3.UP * FootballBall.RADIUS
		ball.last_touch = carrier.team_name
		for through in [false, true]:
			var option := carrier._choose_pass_target(direction, through)
			var receiver := option.get("receiver") as FootballPlayer
			if receiver != open_runner:
				push_error("Pass targeting ignored the complete lane for %s" % ("through ball" if through else "ground pass"))
				game.free()
				quit(1)
				return
		var decision: Dictionary = game._player_decisions.choose_carrier_action(carrier, team, opposition, ball)
		print("PASS_LANE team=", carrier.team_name, " selected=", open_runner.profile.display_name,
			" decision=", decision.get("type"))
		if decision.get("type") != &"through_pass" \
				or decision.get("receiver_id") != open_runner.get_instance_id():
			push_error("Blocked straight runner suppressed the safe diagonal through ball")
			game.free()
			quit(1)
			return
	print("PASS: ground and through passes select the open lane in both directions")
	game.free()
	quit(0)
