extends SceneTree
## Checks possession-change windows for counterpress and forward transition runs.

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var scene := load("res://scenes/training_ground.tscn") as PackedScene
	assert(scene != null, "Sunday-league match scene failed to load")
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game._start_kickoff(false)

	var ball := game.get_node("Ball") as FootballBall
	var home: Array = game.get("_home_players")
	var away: Array = game.get("_away_players")
	for actor in home + away:
		actor.set_physics_process(false)
		actor.controlled_by_human = false
		actor.receive_target_time = 0.0
	for actor in home:
		if actor.profile.role == "outfield":
			match actor.profile.starting_slot:
				"center": actor.global_position = Vector3(10.0, 0.0, 0.0)
				"left": actor.global_position = Vector3(15.0, 0.0, -4.0)
				"right": actor.global_position = Vector3(17.0, 0.0, 5.0)

	# A turnover starts one short transition window; the losing side counterpresses
	# with two players in the opponent half, retaining a third player to cover.
	game.set("_possession_team", &"Beechlawn Rovers")
	game.set("_transition_time_left", 0.0)
	game.set("_ai_tick", 0.0)
	ball.global_position = Vector3(10.0, FootballBall.RADIUS, 0.0)
	ball.last_touch = &"Boardeaux"
	game._update_ai(0.016)
	assert(game.get("_possession_team") == &"Boardeaux"
		and game.get("_transition_team") == &"Boardeaux",
		"Possession change was not recorded")
	assert(is_equal_approx(float(game.get("_transition_time_left")), 1.35),
		"Turnover did not start the transition timer")
	var counterpressers := 0
	var coverers := 0
	for actor in home:
		var intent := String(actor.get_meta("ai_role_intent", ""))
		if intent == "press" or intent == "counterpress":
			counterpressers += 1
		elif intent == "cover" or intent == "mark":
			coverers += 1
	assert(counterpressers == 2 and coverers >= 1,
		"Turnover counterpress did not retain cover behind its two pressers")

	# If the nearest support player is too far away, avoid a second press and
	# keep the team in shape rather than sending a player across the field.
	for actor in home:
		if actor.profile.role == "outfield":
			actor.global_position.x = -30.0
	game.set("_ai_tick", 0.0)
	game._update_ai(0.016)
	var distant_counterpressers := 0
	for actor in home:
		var intent := String(actor.get_meta("ai_role_intent", ""))
		if intent == "counterpress":
			distant_counterpressers += 1
	assert(distant_counterpressers == 0,
		"Counterpress sent a secondary defender into an unsafe long chase")

	# Put the players near the ball again for the remaining transition checks.
	for actor in home:
		if actor.profile.role == "outfield":
			match actor.profile.starting_slot:
				"center": actor.global_position = Vector3(10.0, 0.0, 0.0)
				"left": actor.global_position = Vector3(15.0, 0.0, -4.0)
				"right": actor.global_position = Vector3(17.0, 0.0, 5.0)

	# Re-touching by the same team does not repeatedly restart the window.
	game.set("_transition_time_left", 0.5)
	game.set("_ai_tick", 0.0)
	game._update_ai(0.1)
	assert(float(game.get("_transition_time_left")) < 0.5,
		"Same-team touch incorrectly reset the transition timer")
	game.set("_transition_time_left", 0.05)
	game.set("_ai_tick", 0.0)
	game._update_ai(0.1)
	var expired_counterpressers := 0
	for actor in home:
		if String(actor.get_meta("ai_role_intent", "")) == "counterpress":
			expired_counterpressers += 1
	assert(expired_counterpressers == 0 and is_zero_approx(float(game.get("_transition_time_left"))),
		"Counterpress continued after the transition interval expired")

	# Winning possession gives the support run a more direct, temporary target.
	ball.last_touch = &"Beechlawn Rovers"
	ball.global_position = Vector3(0.0, FootballBall.RADIUS, 0.0)
	var carrier: FootballPlayer = game.get_node("Player")
	var support: FootballPlayer
	for actor in home:
		if actor.profile.starting_slot == "left":
			support = actor
			break
	assert(support != null, "No Beechlawn support runner found")
	var ball_position := Vector2.ZERO
	var normal_target: Vector2 = game._attacking_support_position(support, ball_position, false)
	var transition_target: Vector2 = game._attacking_support_position(support, ball_position, true)
	assert(transition_target.x > normal_target.x + 1.0,
		"Possession win did not increase the forward support run")
	game._update_team_ai(home, carrier, ball_position, ball_position, away,
		&"Beechlawn Rovers", 1.1)
	assert(String(support.get_meta("ai_role_intent")) == "support",
		"Transition support runner did not remain an attacking support role")

	print("Beechlawn possession transition checks passed")
	quit(0)
