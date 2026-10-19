extends SceneTree
## Run the real 11v11 decision and movement layers from a repeatable midfield
## possession with one trailing defender, then require a physical shot contact.

const SIM_TICKS := 1800 # 30 simulated seconds at 60 Hz.
var _shots := 0
var _max_ball_x := 0.0
var _attack_sign := 1.0
var _attacking_team: StringName
var _touch_counts: Dictionary = {}
var _decision_counts: Dictionary = {
	&"Beechlawn Rovers": {&"none": 0, &"carry": 0, &"short_pass": 0, &"through_pass": 0, &"shoot": 0},
	&"Bordeaux": {&"none": 0, &"carry": 0, &"short_pass": 0, &"through_pass": 0, &"shoot": 0},
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 64
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game._kickoff_pending = false
	game._goal_pause_timer = 0.0
	game._full_time = false
	game._remaining_time = 180.0
	game._ai_tick = 0.0
	game._next_home_ai = true
	var ball := game.get_node("Ball") as FootballBall
	_attack_sign = -1.0 if OS.get_environment("BEECHLAWN_ATTACK_TEAM") == "Bordeaux" else 1.0
	var attackers: Array[FootballPlayer] = game._home_players if _attack_sign > 0.0 else game._away_players
	var defenders: Array[FootballPlayer] = game._away_players if _attack_sign > 0.0 else game._home_players
	_attacking_team = attackers[0].team_name
	var carrier: FootballPlayer = game._nearest_outfielder(attackers, Vector2(22.5 * _attack_sign, 0.0))
	assert(carrier != null, "Home AI carrier missing")
	var support: FootballPlayer
	for actor in attackers:
		if actor != carrier and actor.profile.role == "outfield":
			support = actor
			break
	var trailing_defender: FootballPlayer
	for actor in defenders:
		if actor.profile.role == "outfield":
			trailing_defender = actor
			break
	assert(support != null and trailing_defender != null, "Attack scenario actors missing")

	for actor in game._home_players + game._away_players:
		actor.controlled_by_human = false
		actor.ai_action_cooldown = 0.0
		actor.velocity = Vector3.ZERO
		actor.ai_move_direction = Vector3.ZERO
		actor.set_physics_process(false)
		if actor.profile.role == "goalkeeper":
			actor.global_position = Vector3(-49.5 * actor.attack_sign, 0.0, 0.0)
		elif OS.get_environment("BEECHLAWN_FULL_OPPOSITION") == "1":
			actor.global_position = Vector3(actor.profile.starting_position.x * actor.attack_sign,
				0.0, actor.profile.starting_position.y)
		else:
			actor.global_position = Vector3(-45.0 * _attack_sign, 0.0, 30.0)
		if OS.get_environment("BEECHLAWN_FULL_OPPOSITION") == "1":
			actor.set_physics_process(true)
	carrier.global_position = Vector3(22.5 * _attack_sign, 0.0, 0.0)
	carrier.rotation.y = PI / 2.0 * _attack_sign
	carrier._flat_direction = Vector3.LEFT * _attack_sign
	carrier.set_physics_process(true)
	support.global_position = Vector3(26.0 * _attack_sign, 0.0, 8.0)
	support.set_physics_process(true)
	trailing_defender.global_position = Vector3(19.5 * _attack_sign, 0.0, 0.0)
	trailing_defender.set_physics_process(true)
	var keeper: FootballPlayer
	for actor in defenders:
		if actor.profile.role == "goalkeeper":
			keeper = actor
			break
	if keeper != null:
		keeper.global_position = Vector3(49.5 * _attack_sign, 0.0, 0.0)
		keeper.set_physics_process(true)

	ball.freeze = false
	ball.global_position = Vector3(23.2 * _attack_sign, FootballBall.RADIUS, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.last_touch = carrier.team_name
	ball.touched.connect(_on_ball_touched.bind(ball))
	_max_ball_x = ball.global_position.x * _attack_sign

	for tick in SIM_TICKS:
		game._update_ai(1.0 / 60.0)
		await physics_frame
		_max_ball_x = maxf(_max_ball_x, ball.global_position.x * _attack_sign)
		if OS.get_environment("BEECHLAWN_FULL_OPPOSITION") == "1" and tick % 12 == 0 \
				and ball.last_touch in [&"Beechlawn Rovers", &"Bordeaux"]:
			var team: Array[FootballPlayer] = game._home_players if ball.last_touch == &"Beechlawn Rovers" else game._away_players
			var opposition: Array[FootballPlayer] = game._away_players if ball.last_touch == &"Beechlawn Rovers" else game._home_players
			var nearest: FootballPlayer = game._nearest_outfielder(team, Vector2(ball.global_position.x, ball.global_position.z))
			if nearest != null and nearest._can_kick():
				var action: Dictionary = game._player_decisions.choose_carrier_action(nearest, team, opposition, ball)
				var action_type: StringName = action.get("type", &"none")
				_decision_counts[ball.last_touch][action_type] = int(_decision_counts[ball.last_touch][action_type]) + 1
		if _shots > 0:
			break

	var full_opposition := OS.get_environment("BEECHLAWN_FULL_OPPOSITION") == "1"
	var progressive_passes := int(_touch_counts.get(&"through_pass", 0))
	var scenario_passed := progressive_passes > 0 and _max_ball_x > 30.0 if full_opposition else _shots == 1
	print("AI midfield-to-shot team=",_attacking_team,": shots=", _shots, " max_attack_progress=", snappedf(_max_ball_x, 0.1),
		" carrier_x=", snappedf(carrier.global_position.x, 0.1), " last_action=", ball.last_action,
		" last_touch=", ball.last_touch, " action_counts=", _touch_counts)
	if full_opposition:
		print("AI full-opposition decision samples=", _decision_counts)
	if not scenario_passed:
		push_error("AI midfield scenario failed: full opposition requires a progressive through pass; isolated pressure requires a shot contact")
		game.free()
		quit(1)
		return
	print("PASS: ", "full-formation progressive pass" if full_opposition else "midfield-to-shot under trailing pressure")
	game.free()
	quit(0)

func _on_ball_touched(kind: StringName, _speed: float, ball: FootballBall) -> void:
	_touch_counts[kind] = int(_touch_counts.get(kind, 0)) + 1
	if kind == &"shot" and ball.last_touch == _attacking_team:
		_shots += 1
