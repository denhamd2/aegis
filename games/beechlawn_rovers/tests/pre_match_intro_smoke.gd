extends SceneTree
## Exercise actual intro staging, natural completion and skip-to-kickoff isolation.
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
func _run() -> void:
	var session := root.get_node("MatchSession")
	session.launched_from_menu = true
	session.show_intro = true
	for mode in [0, 1]:
		session.mode = mode
		var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
		root.add_child(game)
		await process_frame
		var director: Node = game._pre_match
		check(game._intro_active and director.active, "Menu match starts intro")
		check(game.ball.freeze and game._kickoff_pending, "Ball remains frozen at kickoff")
		var elapsed: float = game._remaining_time
		game._physics_process(5.0)
		game._update_kickoff_input(5.0)
		check(is_equal_approx(game._remaining_time, elapsed) and game._kickoff_pending, "Intro cannot consume clock/kickoff")
		for actor in game._home_players + game._away_players:
			check(not actor.is_physics_processing(), "Actor physics frozen")
		for index in director.shots.size():
			director._enter_shot(index)
			director.shot_time = float(director.shots[index]["duration"]) * 0.5
			director._update_shot(director.shot_time)
			check(director.camera.global_transform.is_finite(), "Finite intro camera")
			if director.shots[index]["id"] == "referee":
				check(director._referee_lower_third.visible, "Referee lower third follows team graphics")
				check(director._referee_name.text == "DES FEENEY", "Official name is typeset in lower third")
				check(director._referee_role.text.contains("REFEREE"), "Official role is typeset in lower third")
				check(director._referee_lower_third.modulate.a > 0.99, "Referee lower third fades in smoothly")
				var referee_head: Vector3 = director._referee.global_position + Vector3.UP * 1.58
				check(director.camera.global_position.distance_to(referee_head) < 4.5, "Referee is shown in a face close-up")
				check(director.camera.fov <= 20.0 and not game.ball.visible, "Tight referee portrait keeps kickoff ball out of frame")
				check(director._actors.all(func(actor: FootballPlayer): return not actor.visible), "Referee close-up keeps lineup players out of frame")
			if director.shots[index]["id"] == "goal":
				check(not director._referee_lower_third.visible, "Referee card clears on the next intro cut")
				check(director._actors.all(func(actor: FootballPlayer): return actor.visible), "Lineup actors return after the referee close-up")
			if director.shots[index]["id"] == "lineup":
				var duration := float(director.shots[index]["duration"])
				var distance := (director.shots[index]["to"] as Vector3).distance_to(director.shots[index]["from"])
				# Smoothstep's peak speed is 1.5 times the average. Protect a
				# readable pan through the faces, including its fastest midpoint.
				check(distance * 1.5 / duration <= 2.2, "Lineup camera peak speed stays readable")
			if director.shots[index]["id"] in ["walk", "warmup"]:
				var expected: StringName = director.WALK if director.shots[index]["id"] == "walk" else director.JOG
				var actor: FootballPlayer = director._actors[0] if expected == director.WALK else director._warmup[0]
				var visual := actor.get_node("Visual") as FootballerVisual
				check(visual.animation_player.current_animation == expected, "Original walk/jog clip plays")
				check(visual.animation_player.get_animation(expected).length > 0.5, "Imported presentation animation has duration")
				if expected == director.JOG:
					for time in [0.0, 2.0, 4.0]:
						director._update_shot(time)
						for runner in director._warmup:
							for other in director._actors:
								if other != runner:
									check(runner.global_position.distance_to(other.global_position) > 0.8, "Warm-up lane stays clear through the shot")
			print("INTRO_SHOT ", director.shots[index]["id"], " at=", director.camera.global_position)
		var initial_preset: StringName = game.camera_rig.preset_id
		for preset in preload("res://scripts/gameplay_camera_presets.gd").PRESETS:
			game.camera_rig.preset_id = preset
			game.camera_rig.apply_settings()
			director._enter_shot(director.shots.size() - 1)
			if preset != &"blimp":
				var start: Vector3 = director.shots[-1]["from"]
				var finish: Vector3 = director.shots[-1]["to"]
				check(Vector2(start.x, start.z).dot(Vector2(finish.x, finish.z)) > 0.0, "Handoff stays on selected camera side " + str(preset))
			director._update_shot(2.0)
			check(director.camera.global_basis.z.dot(game.camera_rig.camera.global_basis.z) > 0.999, "Handoff preserves selected camera orientation " + str(preset))
		game.camera_rig.preset_id = initial_preset
		game.camera_rig.apply_settings()
		if mode == 0:
			# Traverse the real sequence, including every automatic cut and
			# final completion. Match simulation stays frozen throughout.
			director._enter_shot(0)
			var steps := 0
			var duration := 0.0
			for shot in director.shots: duration += float(shot["duration"])
			var max_steps: int = ceili(duration / 0.25) + director.shots.size() + 4
			check(duration <= 80.0, "Broadcast intro remains a skippable short sequence")
			while director.active and steps < max_steps:
				game._physics_process(0.25)
				director._process(0.25)
				steps += 1
			check(not director.active and is_equal_approx(game._remaining_time, elapsed), "Full intro advances presentation only")
		else:
			# Skip midway through moving actors, then verify restoration.
			director._enter_shot(1)
			director._update_shot(3.0)
			var skip := InputEventKey.new()
			skip.keycode = KEY_ENTER
			skip.pressed = true
			game._unhandled_key_input(skip)
		check(not game._intro_active and game._kickoff_pending, "Natural finish/skip restores pending kickoff")
		check(game.get_node("HUD").visible and game.ball.freeze, "HUD restored, ball still pending")
		check(not game.camera_rig.presentation_override and game.camera_rig.camera.current, "Gameplay camera restored")
		check(game.get_node("Referee").is_physics_processing(), "Referee restored")
		for actor in game._home_players + game._away_players:
			var visual := actor.get_node("Visual") as FootballerVisual
			check(not visual._presentation_active and visual.animation_tree.active, "Gameplay AnimationTree restored")
			check(actor.velocity.is_zero_approx(), "No presentation velocity leaks")
			check(actor.physics_interpolation_mode == director._interpolation_modes[actor.get_instance_id()], "Player interpolation mode restored")
		check(game.ball.position.distance_to(Vector3(0, game.ball.position.y, 0)) < 0.05, "Ball at centre spot")
		await process_frame
		check(not is_instance_valid(director), "Intro camera/overlay released")
		if mode == 0:
			game._update_kickoff_input(1.2)
			check(game._kickoff_pending, "Play waits for user kickoff")
			Input.action_press("pass")
			game._update_kickoff_input(0.02)
			Input.action_release("pass")
		else:
			game._update_kickoff_input(1.2)
		check(not game._kickoff_pending, "Match can kick off after intro")
		game._on_goal("Beechlawn Rovers", 1)
		check(not game._intro_active, "Goal does not replay the intro")
		game.free()
		await process_frame
	session.show_intro = false
	var direct := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(direct)
	await process_frame
	check(not direct._intro_active and direct._pre_match == null and direct._kickoff_pending, "Disabled intro launches directly into pending kickoff")
	direct.free()
	session.show_intro = true
	session.launched_from_menu = false
	if not failures.is_empty():
		push_error("Intro checks: " + "; ".join(failures))
	print("Intro natural/skip, staging, original clips, freeze, cleanup, Play/Watch kickoff failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
