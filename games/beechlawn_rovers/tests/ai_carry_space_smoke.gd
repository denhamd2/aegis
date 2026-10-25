extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var passed := true
	var ball := game.get_node("Ball") as FootballBall
	for team: Array[FootballPlayer] in [game._home_players, game._away_players]:
		var opposition: Array[FootballPlayer] = game._away_players if team == game._home_players else game._home_players
		for actor in team + opposition:
			actor.controlled_by_human = false
			actor.ai_action_cooldown = 0.0
			actor.global_position = Vector3(-80, 0, 40)
		var carrier: FootballPlayer = game._nearest_outfielder(team, Vector2.ZERO)
		var support: FootballPlayer
		var defender: FootballPlayer = game._nearest_outfielder(opposition, Vector2.ZERO)
		for candidate in team:
			if candidate != carrier and candidate.profile.role == "outfield":
				support = candidate
				break
		carrier.global_position = Vector3(20.0 * carrier.attack_sign, 0, 0)
		support.global_position = Vector3(17.0 * carrier.attack_sign, 0, 10)
		ball.global_position = carrier.global_position + Vector3(carrier.attack_sign * 0.6, 0.11, 0)
		ball.last_touch = carrier.team_name
		for distance in [-4.0, 4.0, 1.8]:
			defender.global_position = ball.global_position + Vector3(distance * carrier.attack_sign, -0.11, 0)
			var choice: Dictionary = game._player_decisions.choose_carrier_action(carrier, team, opposition, ball)
			var expected := &"short_pass" if distance < 2.0 and distance > 0.0 else &"carry"
			print("CARRY_SPACE team=",carrier.team_name," defender_distance=",distance," choice=",choice.get("type"))
			passed = passed and choice.get("type") == expected
		support.global_position.x = 26.0 * carrier.attack_sign
		defender.global_position = ball.global_position + Vector3(4.0 * carrier.attack_sign, -0.11, 0)
		var progressive: Dictionary = game._player_decisions.choose_carrier_action(carrier, team, opposition, ball)
		passed = passed and progressive.get("type") == &"short_pass"
		defender.position = ball.position - Vector3(2.5*carrier.attack_sign, .11, 0)
		var trailing: Dictionary = game._player_decisions.choose_carrier_action(carrier, team, opposition, ball)
		if trailing.type != &"carry":
			push_error("Tight trailing pressure forced a pass despite an open goalward lane")
			game.free();quit(1);return
	game.free()
	if not passed:
		push_error("A carrier with four metres of space and a trailing defender recycles instead of progressing")
	quit(0 if passed else 1)
