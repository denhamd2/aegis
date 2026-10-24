extends SceneTree
## Native evidence of the real menu and actual intro/HUD, with simulation frozen.
var output: String
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	call_deferred("_run")
func save_frame(filename: String) -> void:
	for frame in 2: await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(filename)) == OK)
	print("BROADCAST_REVIEW_FRAME ",filename)
func _run() -> void:
	assert(not output.is_empty())
	var menu = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await save_frame("title.png")
	menu.open_options()
	await save_frame("options.png")
	menu.free()
	var session := root.get_node("MatchSession")
	session.launched_from_menu = true
	session.show_intro = true
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	var director: Node = game._pre_match
	director.set_process(false)
	for id in ["montage_goal", "montage_puddles", "venue", "lineup", "referee"]:
		for index in director.shots.size():
			if director.shots[index].id == id:
				director._enter_shot(index)
				director._update_shot(float(director.shots[index].duration)*.4)
				await save_frame(id+".png")
	director._lower_third.hide()
	director._referee_lower_third.hide()
	director.camera.global_position = Vector3(15, .16, 12)
	director.camera.fov = 48
	director.camera.look_at(Vector3(15, .02, 9.5))
	game.grass_detail.prewarm(director.camera.global_position)
	await save_frame("turf_close.png")
	var turf_report := {"active_crowns":game.grass_detail.tuft_count(),"active_triangles":game.grass_detail.draw_triangle_count(),"triangle_budget":game.grass_detail.triangle_budget,"active_chunks":game.grass_detail.chunks.size(),"intermediate_chunks":game.grass_detail.mid_chunks.size(),"prepared_chunks":game.grass_detail.prepared.size(),"blade_height_m":[.0119,.0242],"cell_m":game.grass_detail.CELL}
	director.finish()
	game.camera_rig.set_process(false)
	await save_frame("match_broadcast.png")
	var report := {"rendering_method":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),"display_server":DisplayServer.get_name(),
		"home_players":game._home_players.size(),"away_players":game._away_players.size(),"officials":1,
		"turf":turf_report,
		"scope":"Actual title/intro/HUD; software Vulkan stills do not certify M1 performance"}
	var file := FileAccess.open(output.path_join("match_broadcast.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("BEECHLAWN_NATIVE_CAPTURE ",JSON.stringify(report))
	quit()
