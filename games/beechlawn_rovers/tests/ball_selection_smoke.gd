extends SceneTree
## Cosmetic selection must survive old settings, matches and recorded replay.
var failures := 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _run() -> void:
	var session := root.get_node("MatchSession")
	var cfg := "user://ball_selection_test.cfg"
	DirAccess.remove_absolute(cfg)
	session.ball_id = &"worn_sunday_league"
	session.load_preferences(cfg)
	check(session.ball_id == FootballBallCatalog.DEFAULT,"Missing preferences use new ball")
	var legacy := ConfigFile.new()
	legacy.set_value("match","venue","rovers_arena")
	check(legacy.save(cfg) == OK,"Create legacy settings")
	session.load_preferences(cfg)
	check(session.ball_id == FootballBallCatalog.DEFAULT and session.venue_id == &"rovers_arena","Legacy venue migrates without losing other settings")
	legacy.set_value("match","ball","not_a_ball")
	check(legacy.save(cfg) == OK,"Create invalid settings")
	session.load_preferences(cfg)
	check(session.ball_id == FootballBallCatalog.DEFAULT,"Invalid saved ball falls back")
	check(FootballBallCatalog.valid_id(&"invalid") == FootballBallCatalog.DEFAULT,"Invalid runtime ball falls back")
	for id in FootballBallCatalog.IDS:
		session.ball_id = id
		check(session.save_preferences(cfg) == OK,"Save selected ball")
		session.ball_id = &"invalid"
		session.load_preferences(cfg)
		check(session.ball_id == id,"Selection persists across reload")
		for venue in FootballMatchVenue.IDS:
			for mode in [0,1]:
				session.venue_id = venue
				session.mode = mode
				session.launched_from_menu = true
				session.show_intro = true
				var game = load("res://scenes/match_11v11.tscn").instantiate()
				root.add_child(game)
				current_scene = game
				game.set_physics_process(false)
				game._set_players_physics_enabled(false)
				var visual := game.ball.get_node("BallVisual") as Node3D
				check(visual.get_meta("appearance_id") == id and visual.get_child_count() == 1,"Exactly one chosen ball in both modes/venues")
				check(visual.get_child(0).scene_file_path == FootballBallCatalog.SCENES[id].resource_path,"Correct GLB, not merely matching appearance metadata")
				check(game._intro_active,"Intro uses the selected live ball")
				check(is_equal_approx(game.ball.mass,.43),"Cosmetics preserve mass")
				check(is_equal_approx(game.ball.get_node("CollisionShape3D").shape.radius,.11),"Cosmetics preserve collider")
				var meshes := visual.find_children("*","MeshInstance3D",true,false)
				check(meshes.size() == 1,"One mesh; no old/new overlap")
				if meshes.size() == 1:
					var mesh := meshes[0] as MeshInstance3D
					var bounds := mesh.transform * mesh.get_aabb()
					# Preserve the supplied worn ball's slightly irregular surface.
					check((bounds.size-Vector3.ONE*.22).abs().length()<.002,"Both balls are nominally 22 cm: "+str(bounds.size))
					check(bounds.get_center().length()<.001,"Centred visual pivot")
				# Reconfiguring the same ID must not add an instance.
				FootballBallCatalog.configure(visual,id)
				check(visual.get_child_count() == 1,"Idempotent appearance")
				game._pre_match.finish()
				for frame in 45: game.presentation.buffer.sample(1.0/30,true)
				var entry: Dictionary = game.presentation.buffer.bookmark(&"save")
				check(game.presentation.start_replay(entry),"Selected ball replay starts")
				var clone := game.presentation.ghost_ball.get_node("BallVisual") as Node3D
				check(clone.get_meta("appearance_id") == id,"Replay retains match choice")
				check(clone.find_children("*","MeshInstance3D",true,false).size() == 1,"Replay has one model with no reinitialization")
				check(clone.get_child(0).get_child(0).mesh == visual.get_child(0).get_child(0).mesh,"Replay copies the active mesh resource")
				game.free()
				print("BALL_COMBINATION PASS ",id," ",venue," mode=",mode)
	# Exercise the real menu binding and layout, without touching real preferences.
	session.ball_id = FootballBallCatalog.DEFAULT
	var menu = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	var selector := menu.options_layer.get_node("BallSelect") as OptionButton
	selector.select(1)
	selector.item_selected.emit(1)
	check(session.ball_id == &"worn_sunday_league","Options selects worn ball")
	var venue_control := menu.options_layer.get_node("VenueSelect") as Control
	check(not selector.get_rect().intersects(venue_control.get_rect()),"Venue and Ball do not overlap")
	check(selector.get_rect().end.y < menu.close_button.position.y,"Ball row clears Save & Back")
	check(selector.focus_mode == Control.FOCUS_ALL,"Keyboard-accessible ball selector")
	menu.start_button.pressed.emit()
	for frame in 8: await process_frame
	var launched := current_scene
	check(launched.name == "Beechlawn11v11" and launched.ball.get_node("BallVisual").get_meta("appearance_id") == &"worn_sunday_league","Menu launches the worn choice")
	launched._pre_match.finish()
	launched._finish_match()
	# Presentation consumes the queued full-time event on its update tick.
	launched.presentation.update(.02)
	var skip := InputEventKey.new()
	skip.keycode = KEY_SPACE
	skip.pressed = true
	launched.presentation.handle_key(skip)
	var rematch := launched.presentation.results.find_children("*","Button",true,false)[0] as Button
	rematch.pressed.emit()
	for frame in 5: await process_frame
	check(current_scene.ball.get_node("BallVisual").get_meta("appearance_id") == &"worn_sunday_league","Rematch retains chosen worn ball")
	session.return_to_title()
	for frame in 5: await process_frame
	check(current_scene.name == "TitleScreen" and session.ball_id == &"worn_sunday_league","Title return retains chosen worn ball")
	var returned := current_scene.options_layer.get_node("BallSelect") as OptionButton
	check(returned.selected == 1,"Returning Options displays the retained selection")
	current_scene.free()
	DirAccess.remove_absolute(cfg)
	print("BALL_SELECTION ","PASS" if failures == 0 else "FAIL",": legacy/invalid/missing settings, persistence, 8 mode/venue/ball combinations, intro/replay, scale and physics; failures=",failures)
	quit(0 if failures == 0 else 1)
