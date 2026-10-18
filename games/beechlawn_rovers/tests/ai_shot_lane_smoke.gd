extends SceneTree
## A nearby defender behind the ball must not veto an open shooting lane.

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
	for team in [game._home_players, game._away_players]:
		var carrier: FootballPlayer
		for actor in team:
			if actor.profile.role == "outfield":
				carrier = actor
				break
		var opposition: Array[FootballPlayer] = game._away_players if team == game._home_players else game._home_players
		for actor in game._home_players + game._away_players:
			actor.global_position = Vector3(0.0, 0.0, 28.0)
		var sign_x := carrier.attack_sign
		carrier.global_position = Vector3(sign_x * 35.8, 0.0, 0.0)
		carrier.ai_action_cooldown = 0.0
		ball.global_position = Vector3(sign_x * 36.5, FootballBall.RADIUS, 0.0)
		ball.last_touch = carrier.team_name
		var defender: FootballPlayer
		for actor in opposition:
			if actor.profile.role == "outfield":
				defender = actor
				break
		# Two metres behind the ball: pressure exists, but the goalward lane is open.
		defender.global_position = Vector3(sign_x * 34.5, 0.0, 0.0)
		var open: Dictionary = game._player_decisions.choose_carrier_action(carrier, team, opposition, ball)
		print("SHOT_LANE team=", carrier.team_name, " behind_defender_choice=", open.get("type"))
		if open.get("type") != &"shoot":
			_fail(game, "AI rejected an open 16 m shot because a defender was behind the ball");return
		# The same defender directly ahead should still discourage a speculative shot.
		defender.global_position = Vector3(sign_x * 38.5, 0.0, 0.0)
		var blocked: Dictionary = game._player_decisions.choose_carrier_action(carrier, team, opposition, ball)
		if blocked.get("type") == &"shoot":
			_fail(game, "AI ignored a defender blocking its shooting corridor");return
		carrier.controlled_by_human = true
		if game._player_decisions.choose_carrier_action(carrier, team, opposition, ball).get("type") != &"none":
			_fail(game, "AI shot targeting overrode human control");return
	print("AI shooting-lane PASS: open shot under trailing pressure, frontal block, both directions and human control")
	game.free()
	quit(0)

func _fail(game: Node, message: String) -> void:
	push_error(message)
	game.free()
	quit(1)
