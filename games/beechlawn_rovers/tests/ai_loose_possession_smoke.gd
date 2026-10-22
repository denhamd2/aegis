extends SceneTree
## Last touch is a rules fact, not proof of present tactical control.
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	for actor in game._home_players + game._away_players:
		actor.controlled_by_human = false;actor.position = Vector3(-40,0,30)
	var ball: FootballBall = game.ball
	for team: Array[FootballPlayer] in [game._home_players, game._away_players]:
		var opposition: Array[FootballPlayer] = game._away_players if team == game._home_players else game._home_players
		ball.position = Vector3(12, .11, 0);ball.linear_velocity = Vector3.ZERO
		ball.last_touch = team[0].team_name;ball.last_action = &"deflection"
		var chaser: FootballPlayer = game._nearest_outfielder(team, Vector2(12,0))
		chaser.position = Vector3(8,0,0)
		game._update_team_ai(team, chaser, Vector2(12,0), Vector2(12,0), opposition)
		if chaser.get_meta("ai_role_intent") != "press":
			push_error("Stale last touch claims tactical possession of a loose ball four metres away")
			game.free();quit(1);return
		chaser.position = Vector3(-40,0,30)
	print("PASS: both teams pursue loose balls without claiming possession from last touch")
	game.free();quit(0)
