extends SceneTree
## Native Forward+ evidence for the P1 development view and keeper hand release.

var output := ""
var mode := ""
var game: Node3D
var camera: Camera3D
var frames: Array[Dictionary] = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--review-mode="): mode = arg.trim_prefix("--review-mode=")
	call_deferred("_run")

func _save(name: String) -> void:
	paused = true
	for frame in 2: await RenderingServer.frame_post_draw
	var filename := name + ".png"
	assert(root.get_texture().get_image().save_png(output.path_join(filename)) == OK)
	frames.append({"file":filename, "mode":mode,
		"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
	paused = false

func _run() -> void:
	assert(not output.is_empty() and mode in ["keeper_distribution", "p1_debug"])
	assert(RenderingServer.get_current_rendering_method() == "forward_plus")
	DirAccess.make_dir_recursive_absolute(output)
	var session := root.get_node("MatchSession")
	session.launched_from_menu = false
	session.weather_preset = &"sunny"
	game = (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game._start_kickoff(false)
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	await RenderingServer.frame_post_draw
	if mode == "p1_debug":
		await _debug_review()
	else:
		await _keeper_review()
	var primary := "debug_on.png" if mode == "p1_debug" else "home_31.png"
	var image := Image.load_from_file(output.path_join(primary))
	assert(image != null and image.save_png(output.path_join("match_broadcast.png")) == OK)
	var report := {"rendering_method":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(), "vendor":RenderingServer.get_video_adapter_vendor(),
		"display_server":DisplayServer.get_name(), "resolution":[image.get_width(), image.get_height()],
		"home_players":game._home_players.size(), "away_players":game._away_players.size(),
		"officials":game.get_tree().get_nodes_in_group("match_officials").size(),
		"mode":mode, "frames":frames, "scope":"Native Forward+ moving/still evidence; cloud renderer does not measure M1 performance"}
	var file := FileAccess.open(output.path_join("match_broadcast.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("BEECHLAWN_NATIVE_CAPTURE ", JSON.stringify(report))
	quit()

func _debug_review() -> void:
	game.camera_rig.set_process(false)
	game._update_ai(0.3)
	var overlay: Control = game.match_hud.debug_overlay
	game._debug_enabled = false
	overlay._process(0)
	assert(not overlay.visible)
	await _save("debug_off")
	game._debug_enabled = true
	overlay._process(0)
	assert(overlay.visible and overlay.camera != null)
	await _save("debug_on")
	frames.back()["projected_actors"] = game._home_players.size() + game._away_players.size()
	var keeper: FootballPlayer
	var receiver: FootballPlayer
	for actor in game._home_players:
		if actor.profile.role == "goalkeeper": keeper = actor
		elif receiver == null: receiver = actor
	keeper.global_position = Vector3(-49.5, 0, 0)
	receiver.global_position = Vector3(-45, 0, 3)
	receiver.receive_target = Vector3(-40, 0, 2)
	receiver.receive_target_time = 2
	game.ball.global_position = Vector3(-43.5, 1.2, 2)
	game.ball.linear_velocity = Vector3(-12, 0, 0.8)
	game.ball.last_touch = &"Boardeaux"
	game.ball.last_action = &"shot"
	game.ball.action_serial += 1
	keeper._goalkeeper_controller.update_before_move(.35)
	assert(keeper._goalkeeper_controller._has_intercept, "Keeper prediction fixture did not project the shot")
	var match_camera := game.camera_rig.get_node("Camera3D") as Camera3D
	match_camera.global_position = Vector3(-43.0, 5.8, 11.0)
	match_camera.look_at(Vector3(-48, 1, 0))
	match_camera.make_current()
	overlay._process(0)
	await _save("debug_keeper")
	frames.back()["keeper_prediction"] = str(keeper._goalkeeper_controller._predicted_intercept)
	frames.back()["pass_target"] = str(receiver.receive_target)

func _keeper_review() -> void:
	game.get_node("HUD").hide()
	game.camera_rig.presentation_override = true
	camera = Camera3D.new()
	game.add_child(camera)
	camera.near = 0.04
	camera.far = 350
	camera.fov = 44
	camera.make_current()
	game.ball.freeze = false
	for actor in game._home_players + game._away_players:
		actor.global_position = Vector3(150, 0, 150)
	var ball: FootballBall = game.ball
	for home in [true, false]:
		var team: Array[FootballPlayer] = game._home_players if home else game._away_players
		var keeper: FootballPlayer
		var teammate: FootballPlayer
		for actor in team:
			if actor.profile.role == "goalkeeper": keeper = actor
			elif teammate == null: teammate = actor
		assert(keeper != null and teammate != null)
		keeper.global_position = Vector3.ZERO
		keeper.rotation.y = -PI * 0.5 * keeper.attack_sign
		teammate.global_position = Vector3(16 * keeper.attack_sign, 0, 0)
		keeper.reset_for_stoppage()
		ball.release_for_restart()
		ball.freeze = true
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
		ball.global_position = Vector3(0, 1.3, -0.35 * keeper.attack_sign)
		ball.reset_physics_interpolation()
		await physics_frame
		ball.freeze = false
		assert(ball.goalkeeper_claim(keeper))
		var controller: GoalkeeperController = keeper._goalkeeper_controller
		controller._distribution_remaining = 0
		controller.update_before_move(1.0 / 60.0)
		assert(controller._distribution_pending)
		camera.global_position = keeper.global_position + Vector3(3.3 * keeper.attack_sign, 1.7, 4.1)
		camera.look_at(keeper.global_position + Vector3.UP * 1.05)
		var visual: FootballerVisual = keeper.get_node("Visual")
		var start_serial := ball.action_serial
		for tick in 58:
			await physics_frame
			if tick in [1, 14, 27, 31, 38, 56]:
				var name := ("home" if home else "away") + "_" + str(tick)
				await _save(name)
				var hands := visual.hand_positions()
				frames.back()["tick"] = tick
				frames.back()["clip"] = str(visual.animation_player.current_animation)
				frames.back()["holding"] = ball.goalkeeper_is_holding(keeper)
				frames.back()["hand_to_ball_m"] = ball.global_position.distance_to(hands[1]) if hands.size() == 2 else -1
				frames.back()["animation_seconds"] = visual.animation_player.current_animation_position
		assert(ball.action_serial == start_serial + 1 and ball.last_action == &"goalkeeper_distribution")
		keeper.global_position = Vector3(150, 0, 150)
		teammate.global_position = Vector3(150, 0, 150)
