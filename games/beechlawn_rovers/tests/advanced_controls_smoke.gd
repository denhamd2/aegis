extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = down
	Input.parse_input_event(event)
func _run() -> void:
	Engine.time_scale = 1; Engine.physics_ticks_per_second = 60; Engine.max_physics_steps_per_frame = 8
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game); await process_frame
	game.set_process(false); game.set_physics_process(false); game._set_players_physics_enabled(false)
	for frame in 3: await process_frame
	for node in game._home_players + game._away_players:
		node.position = Vector3(0, 0, 90); node.controlled_by_human = false
	var actor: FootballPlayer = game._home_players[2]
	var receiver: FootballPlayer
	for node in game._home_players:
		if node.profile.starting_slot == "striker_left": receiver = node
	var ball: FootballBall = game.ball
	var observed: Array[Dictionary] = []
	ball.touched.connect(func(kind: StringName, _speed: float):
		if kind in [&"shot", &"cross"]: observed.append({"kind": kind, "style": ball.last_strike_style}))
	for crossing in [false, true]:
		for modifier: Key in [KEY_Z, KEY_X, KEY_V]:
			actor.reset_for_stoppage(); actor.controlled_by_human = true
			actor.position = Vector3(33, .005, 21) if crossing else Vector3(32, .005, 0)
			receiver.position = Vector3(42, 0, 2) if crossing else Vector3(0, 0, 90)
			var direction := (Vector3(43, 0, 0) - actor.position).normalized() if crossing else Vector3.RIGHT
			direction.y = 0; direction = direction.normalized()
			actor.rotation.y = atan2(-direction.x, -direction.z); actor._flat_direction = direction
			ball.freeze = true; ball.release_for_restart()
			ball.position = actor.position + direction * .6 + Vector3.UP * .13
			ball.last_touch = actor.team_name; ball.last_action = &"dribble"
			await physics_frame
			ball.freeze = false
			actor.set_physics_process(true)
			key(modifier, true)
			for frame in 2: await physics_frame
			var action: Key = KEY_T if crossing else KEY_SPACE
			var before := observed.size()
			key(action, true)
			for frame in 20: await physics_frame
			check(observed.size() == before, "Strike occurred before charge release")
			key(modifier, false) # The original style must survive modifier release.
			for frame in 2: await physics_frame
			key(action, false)
			for frame in 52: await physics_frame
			var expected: StringName = (&"lofted_cross" if modifier == KEY_Z else &"driven_cross" if modifier == KEY_X else &"early_cross") if crossing else (&"finesse" if modifier == KEY_Z else &"power" if modifier == KEY_X else &"low")
			check(observed.size() == before + 1 and observed[-1].style == expected, "Keyboard style lost or did not contact: " + str(expected))
			actor.set_physics_process(false); actor.reset_for_stoppage(); actor.position = Vector3(0, 0, 90)
	for message in failures: push_error(message)
	print("ADVANCED_CONTROLS observed=", observed, " failures=", failures.size())
	game.free(); quit(0 if failures.is_empty() else 1)
