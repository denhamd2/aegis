extends SceneTree
var failures: Array[String] = []
var foot: StringName = &"left" if OS.get_environment("BEECHLAWN_STRIKE_FOOT")=="left" else &"right"
var lateral: float = -.09 if foot==&"left" else .09
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _run() -> void:
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240; Engine.max_physics_steps_per_frame = 64
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game); await process_frame
	game.set_process(false); game.set_physics_process(false); game._set_players_physics_enabled(false)
	for node in game._home_players + game._away_players: node.position = Vector3(0, 0, 90)
	var ball: FootballBall = game.ball
	var calibration: FootballPlayer = game._home_players[2]
	for action: StringName in [&"volley", &"half_volley"]:
		calibration.reset_for_stoppage()
		var visual := calibration._footballer_visual
		var clip: Animation = visual.animation_player.get_animation(visual.VOLLEY_CLIPS[action])
		check(absf(clip.length - .8) < .00001, "Exported clip timeline does not start at zero")
		visual.play_aerial(action); visual.animation_player.seek(.30, true, true)
		var local := calibration.to_local(calibration._receive_contact_position())
		var height := calibration.tuning.volley_contact_height if action == &"volley" else calibration.tuning.half_volley_contact_height
		check(absf(local.y - height) < .015 and absf(local.z + .60) < .015, "Authored boot contact and imported marker pose disagree: " + str(action) + " " + str(local))
		calibration.reset_for_stoppage()
	for sx: float in [1.0, -1.0]:
		var team: Array[FootballPlayer] = game._home_players if sx > 0 else game._away_players
		var actor: FootballPlayer = team[2]
		for context: StringName in [&"volley", &"half_volley", &"ai_half_volley"]:
			var action: StringName = &"half_volley" if context == &"ai_half_volley" else context
			actor.reset_for_stoppage(); actor.position = Vector3(32 * sx, PitchSurface.height_at(32 * sx, 0) + .005, 0)
			actor.rotation.y = -PI / 2 * sx; actor.velocity = Vector3.ZERO; actor.controlled_by_human = context != &"ai_half_volley"
			actor._flat_direction = Vector3(sx, 0, 0)
			ball.freeze = true; ball.release_for_restart(); ball.linear_velocity = Vector3.ZERO; ball.angular_velocity = Vector3.ZERO
			var destination := actor.position + Vector3(.60 * sx, actor.tuning.volley_contact_height, lateral * sx)
			ball.position = destination + Vector3(2 * sx, .7, 0) if action == &"volley" else Vector3(35 * sx, 1.9, lateral * sx)
			await physics_frame; ball.freeze = false
			var launch := FootballBallFlight.launch(ball, destination, .31) if action == &"volley" else Vector3(-7 * sx, -5, 0)
			ball.kick_velocity(launch, &"cross", actor.team_name, team[1])
			if action == &"half_volley":
				await physics_frame # The physical impulse becomes visible at integration.
				var forecast := FootballBallFlight.after_bounce_contact(ball, actor.position.y + actor.tuning.half_volley_contact_height)
				check(not forecast.is_empty(), "No low-bounce forecast")
				if not forecast.is_empty(): actor.position.x = forecast.position.x - .60 * sx
			var contacts: Array[Dictionary] = []
			var observe := func(kind: StringName, _speed: float):
				if kind == &"shot": contacts.append({"foot": actor._footballer_visual.strike_foot(), "style": ball.last_strike_style, "gap": actor._receive_contact_position().distance_to(ball.position), "bounce_age": actor.get_meta("last_air_contact_bounce_age", 99)})
			ball.touched.connect(observe)
			actor.set_physics_process(true)
			if actor.controlled_by_human: Input.action_press("shoot")
			await physics_frame
			Input.action_release("shoot")
			var start_y := actor.position.y
			var max_rise := 0.0
			for frame in 65:
				await physics_frame
				max_rise = maxf(max_rise, actor.position.y - start_y)
			actor.set_physics_process(false); ball.touched.disconnect(observe)
			check(contacts.size() == 1 and contacts[0].foot == foot and contacts[0].style == action and contacts[0].gap <= .20, "Actual boot contact failed: " + str(action) + " side=" + str(sx))
			if action == &"half_volley" and not contacts.is_empty(): check(contacts[0].bounce_age < .30, "Half-volley occurred without a recent physical bounce")
			check(max_rise < .12 and not actor._aerial_controller.committed(), "Grounded strike jumped or did not recover")
			print("VOLLEY_CONTACT side=", sx, " context=", context, " action=", action, " contacts=", contacts, " rise=", max_rise)
			ball.freeze = true; actor.reset_for_stoppage()
		actor.position = Vector3(0, 0, 90)
	# A close boot alone must not turn an unbounced airborne ball into a half-volley.
	var actor: FootballPlayer = game._home_players[2]
	actor.reset_for_stoppage(); actor.position = Vector3(32, .01, 0); actor.rotation.y = -PI/2
	var visual := actor._footballer_visual
	visual.play_aerial(&"half_volley")
	visual.animation_player.seek(.30, true, true)
	ball.freeze = true; ball.release_for_restart(); ball.position = actor._receive_contact_position()
	ball.last_action = &"cross"; ball.last_touch = actor.team_name
	var controller := actor._aerial_controller
	controller._active = &"half_volley"; controller._serial = ball.action_serial
	controller._incoming_kind = &"cross"
	var serial := ball.action_serial
	controller.on_marker(&"half_volley")
	check(ball.action_serial == serial, "Unbounced ball was struck as a half-volley")
	actor.reset_for_stoppage()
	for message in failures: push_error(message)
	print("VOLLEY_CONTACT failures=", failures.size())
	game.free(); quit(0 if failures.is_empty() else 1)
