extends SceneTree
## Run the complete short clock with both teams on AI, at a preserved 60 Hz dt.
var shot_status_counts: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node("MatchSession")
	session.launched_from_menu=true
	session.mode=session.MatchMode.WATCH
	session.show_intro=false
	Engine.time_scale=6.0
	Engine.physics_ticks_per_second=360
	Engine.max_physics_steps_per_frame=64
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var actors: Array=game._home_players+game._away_players
	for actor in actors:
		actor.controlled_by_human=false
		actor.status_changed.connect(_on_player_status)
	var kickoff_team := OS.get_environment("BEECHLAWN_KICKOFF_TEAM")
	if kickoff_team == "Boardeaux":
		game._prepare_kickoff(&"Boardeaux")
	var ball := game.get_node("Ball") as FootballBall
	var last_ball := ball.global_position
	var travelled := 0.0
	var max_still := 0
	var still := 0
	var samples := 0
	# Count actual contacts, including events superseded within the same tick.
	var shots := {&"Beechlawn Rovers": 0, &"Boardeaux": 0}
	var contested_shots := {&"Beechlawn Rovers": 0, &"Boardeaux": 0}
	var saves := {&"Beechlawn Rovers": 0, &"Boardeaux": 0}
	var shot_decisions := {&"Beechlawn Rovers": 0, &"Boardeaux": 0}
	var max_attack_progress := {&"Beechlawn Rovers": 0.0, &"Boardeaux": 0.0}
	var closest_goal_distance := {&"Beechlawn Rovers": INF, &"Boardeaux": INF}
	var closest_goal_lateral := {&"Beechlawn Rovers": 0.0, &"Boardeaux": 0.0}
	var decision_counts := {
		&"Beechlawn Rovers": {&"none": 0, &"carry": 0, &"short_pass": 0, &"through_pass": 0, &"shoot": 0},
		&"Boardeaux": {&"none": 0, &"carry": 0, &"short_pass": 0, &"through_pass": 0, &"shoot": 0},
	}
	ball.touched.connect(func(kind: StringName, _speed: float):
		if kind == &"shot":
			shots[ball.last_touch] = int(shots.get(ball.last_touch, 0)) + 1
			for actor in actors:
				if actor.team_name != ball.last_touch and actor.profile.role == "outfield" \
						and actor.global_position.distance_to(ball.global_position) <= 5.0:
					contested_shots[ball.last_touch] += 1
					break
		elif kind in [&"goalkeeper_save", &"goalkeeper_catch"]:
			saves[ball.last_touch] += 1)
	while not game._full_time and samples<18000:
		if game._kickoff_pending:game._start_kickoff(false)
		await physics_frame
		samples+=1
		var distance := ball.global_position.distance_to(last_ball)
		travelled+=distance
		last_ball=ball.global_position
		if ball.last_touch in [&"Beechlawn Rovers", &"Boardeaux"]:
			var attack_sign := 1.0 if ball.last_touch == &"Beechlawn Rovers" else -1.0
			var goal_distance := Vector2(ball.global_position.x - attack_sign * 52.5,
				ball.global_position.z).length()
			if goal_distance < float(closest_goal_distance[ball.last_touch]):
				closest_goal_distance[ball.last_touch] = goal_distance
				closest_goal_lateral[ball.last_touch] = ball.global_position.z
		assert(ball.global_position.is_finite() and ball.global_position.y>-0.25,"Ball escaped terrain")
		for actor in actors:
			assert(actor.global_position.is_finite() and actor.global_position.y>-0.5,"Player escaped terrain")
		if samples%60==0:
			still=still+1 if ball.linear_velocity.length()<0.1 and not ball.freeze else 0
			max_still=maxi(max_still,still)
		# Observe available options at 5 Hz without changing the live simulation.
		# These samples are not executed-action counts; touched counts contacts.
		if samples%12==0 and ball.last_touch in [&"Beechlawn Rovers", &"Boardeaux"]:
			var attacking: Array[FootballPlayer] = game._home_players if ball.last_touch == &"Beechlawn Rovers" else game._away_players
			var defending: Array[FootballPlayer] = game._away_players if ball.last_touch == &"Beechlawn Rovers" else game._home_players
			var ball_position := Vector2(ball.global_position.x, ball.global_position.z)
			var interception: Vector2 = game._best_interception_position(attacking, ball_position)
			var chaser: FootballPlayer = game._nearest_outfielder(attacking, interception)
			if chaser != null:
				var choice: Dictionary = game._player_decisions.choose_carrier_action(chaser, attacking, defending, ball)
				var action_type: StringName = choice.get("type", &"none")
				decision_counts[ball.last_touch][action_type] = int(decision_counts[ball.last_touch][action_type]) + 1
				if action_type == &"shoot":
					shot_decisions[ball.last_touch] = int(shot_decisions[ball.last_touch]) + 1
			var attack_sign := 1.0 if ball.last_touch == &"Beechlawn Rovers" else -1.0
			max_attack_progress[ball.last_touch] = maxf(float(max_attack_progress[ball.last_touch]), ball_position.x * attack_sign)
	assert(game._full_time,"Full short match did not reach full time")
	assert(ball.freeze,"Ball was not held at full time")
	assert(travelled>50.0,"AI match did not progress the ball")
	print("11v11 SOAK match_seconds=", game.short_match_seconds, " physics_ticks=", samples,
		" ball_travel_m=", snappedf(travelled, 0.1),
		" shots=", shots[&"Beechlawn Rovers"], "/", shots[&"Boardeaux"],
		" contested_shots=", contested_shots[&"Beechlawn Rovers"], "/", contested_shots[&"Boardeaux"],
		" saves=", saves[&"Beechlawn Rovers"], "/", saves[&"Boardeaux"],
		" shot_status=", shot_status_counts,
		" sampled_options=", decision_counts,
		" sampled_shot_options=", shot_decisions[&"Beechlawn Rovers"], "/", shot_decisions[&"Boardeaux"],
		" sampled_max_attack_x=", snappedf(max_attack_progress[&"Beechlawn Rovers"], 0.1), "/",
		snappedf(max_attack_progress[&"Boardeaux"], 0.1),
		" closest_goal_xz_m=", snappedf(closest_goal_distance[&"Beechlawn Rovers"], 0.1), "/",
		snappedf(closest_goal_distance[&"Boardeaux"], 0.1),
		" at_lateral=", snappedf(closest_goal_lateral[&"Beechlawn Rovers"], 0.1), "/",
		snappedf(closest_goal_lateral[&"Boardeaux"], 0.1),
		" goals=", game._home_score, "/", game._away_score,
		" longest_stationary_samples_s=", max_still)
	if OS.get_environment("BEECHLAWN_REQUIRE_SHOT") == "1":
		if shots[&"Beechlawn Rovers"] + shots[&"Boardeaux"] == 0:
			push_error("AI match produced zero physical shot contacts in 180 seconds")
			game.free()
			quit(1)
			return
	game.free()
	quit(0)

func _on_player_status(message: String) -> void:
	if message.begins_with("Shot"):
		shot_status_counts[message] = int(shot_status_counts.get(message, 0)) + 1
