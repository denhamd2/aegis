extends SceneTree
## A stationary capture of the actual 11v11 scene and shipping broadcast camera.
## No review lighting, replacement stadium or gameplay camera is substituted.
var options: Dictionary = {}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair := argument.substr(2).split("=", true, 1)
			options[pair[0]] = pair[1]
	call_deferred("_capture")

func _capture() -> void:
	if RenderingServer.get_current_rendering_method() != "forward_plus" or not options.has("capture-dir"):
		push_error("Native match capture requires Forward+ and --capture-dir=...")
		quit(2)
		return
	if str(options.get("setup-preview","0")) == "1":
		var menu = load("res://scenes/title_screen.tscn").instantiate()
		root.add_child(menu)
		menu.open_options()
		for frame in 2: await RenderingServer.frame_post_draw
		var folder := str(options["capture-dir"])
		DirAccess.make_dir_recursive_absolute(folder)
		assert(root.get_texture().get_image().save_png(folder.path_join("options.png")) == OK)
		menu.free()
	var session := root.get_node("MatchSession")
	session.launched_from_menu = false
	session.camera_preset = &"close_broadcast"
	session.camera_height = 0.0
	session.camera_zoom = 0.0
	session.camera_angle = 0.0
	session.weather_preset = MatchWeather.valid_id(StringName(options.get("weather","sunny")))
	root.get_node("MatchSession").venue_id = FootballMatchVenue.valid_id(StringName(options.get("venue","kilmore_drive")))
	var game := load("res://scenes/match_11v11.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.call("_set_players_physics_enabled", false)
	var rig := game.get_node("BroadcastCamera")
	rig.call("reset_tracking")
	rig.set_process(false)
	var view := str(options.get("venue-view","broadcast"))
	var camera: Camera3D = rig.get_node("Camera3D")
	if view == "turf":
		await _capture_turf(game,camera)
		return
	if view in ["wide","detail"]:
		camera.global_position = Vector3(-42,29,52) if view == "wide" else Vector3(47,.38,3.5)
		camera.look_at(Vector3(0,2,0) if view == "wide" else Vector3(53,1.1,0))
		camera.fov = 65 if view == "wide" else 48
	for _frame in range(3):
		await RenderingServer.frame_post_draw
		print("NATIVE_MATCH_DRAW ", _frame + 1)
	var seating_audit := _audit_stadium_seating(game) if game.venue.id == &"rovers_arena" else {}
	if seating_audit.get("errors",0) > 0:
		push_error("Native stadium seating buffer audit failed: "+JSON.stringify(seating_audit))
		quit(2)
		return
	paused = true
	var output := str(options["capture-dir"])
	DirAccess.make_dir_recursive_absolute(output)
	var image := root.get_texture().get_image()
	if image.save_png(output.path_join("match_broadcast.png")) != OK:
		quit(2)
		return
	var primary_draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var primary_primitives := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var primary_turf: int = game.grass_detail.draw_triangle_count() if game.grass_detail != null else 0
	var extra_views: Array = []
	var view_groups := {"all":["wide","detail","north_end","south_end","grass"],"corners":["corner_ne","corner_nw","corner_se","corner_sw"],"exterior":["exterior_east","exterior_west","exterior_north","exterior_south"],"pitch":["grass","paint","puddle"],"ball":["ball_hero","ball_quarter","ball_reverse","ball_side","ball_emboss"]}
	if view_groups.has(view):
		if view == "ball":
			# Explicit stationary prop inspection, after the unchanged match still.
			# Keep grass rather than centre-circle paint beneath the ball and clear
			# the HUD/selection ring from the macro. Do not alter normal match views.
			game.get_node("HUD").hide()
			game.ball.position = Vector3(9,game.surface_height(9,14)+FootballBall.RADIUS,14)
			game.ball.reset_physics_interpolation()
			for actor in game._home_players+game._away_players:
				actor.get_node("ControlMarker").hide()
		var shots := {
		 "wide":[Vector3(-42,29,52),Vector3(0,2,0),65],
		 "detail":[Vector3(47,.38,3.5),Vector3(53,1.1,0),48],
		 "north_end":[Vector3(-38,2.0,4),Vector3(74,15,0),58],
		 "south_end":[Vector3(38,2.0,-4),Vector3(-74,15,0),58],
		 "grass":[Vector3(9,.16,14),Vector3(9.8,.02,12.7),48],
		 "paint":[Vector3(1,.17,8),Vector3(0,.02,6.8),48],
		 "puddle":[Vector3(46,.24,3),Vector3(50.7,.01,.5),45],
		 "corner_ne":[Vector3(38,2.0,16),Vector3(67,13,46),58],
		 "corner_nw":[Vector3(38,2.0,-16),Vector3(67,13,-46),58],
		 "corner_se":[Vector3(-38,2.0,16),Vector3(-67,13,46),58],
		 "corner_sw":[Vector3(-38,2.0,-16),Vector3(-67,13,-46),58],
		 "exterior_east":[Vector3(-55,17,140),Vector3(0,18,72),58],
		 "exterior_west":[Vector3(55,17,-140),Vector3(0,18,-72),58],
		 "exterior_north":[Vector3(157,21,45),Vector3(92,18,0),58],
		 "exterior_south":[Vector3(-157,21,-45),Vector3(-92,18,0),58]}
		for extra in view_groups[view]:
			if extra.begins_with("ball_"):
				var angles := {"ball_hero":0.0,"ball_quarter":PI*.5,"ball_reverse":PI,"ball_side":PI*1.5,"ball_emboss":0.0}
				game.ball.rotation = Vector3(0,angles[extra],0)
				game.ball.reset_physics_interpolation()
				var close: bool = extra == "ball_emboss"
				shots[extra] = [game.ball.global_position+Vector3(.02,.20 if close else .24,.28 if close else .65),game.ball.global_position+Vector3(0,.02,0),35]
			var shot: Array = shots[extra]
			camera.global_position = shot[0]
			camera.look_at(shot[1])
			camera.fov = shot[2]
			camera.reset_physics_interpolation()
			if game.grass_detail != null: game.grass_detail.prewarm(camera.global_position)
			for frame in 3: await RenderingServer.frame_post_draw
			var filename: String = "match_"+extra+".png"
			assert(root.get_texture().get_image().save_png(output.path_join(filename)) == OK)
			var turf_triangles: int = game.grass_detail.draw_triangle_count() if game.grass_detail != null else 0
			assert(turf_triangles<=240000,"Turf exceeded its visible geometry budget")
			extra_views.append({"image":filename,"camera_position":str(camera.global_position),"fov":camera.fov,"ball_rotation":str(game.ball.rotation),"ball_position":str(game.ball.global_position),"turf_triangles":turf_triangles,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
	# The team's arrays are the authoritative actor inventory, independent of groups.
	var home: Array = game.get("_home_players")
	var away: Array = game.get("_away_players")
	var official_count := get_nodes_in_group("match_officials").size()
	var report := {
		"rendering_method":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),
		"vendor":RenderingServer.get_video_adapter_vendor(),
		"api":RenderingServer.get_video_adapter_api_version(),
		"display_server":DisplayServer.get_name(), "godot":Engine.get_version_info().string,
		"resolution":[image.get_width(),image.get_height()], "msaa_3d":root.msaa_3d,
		"scene":"res://scenes/match_11v11.tscn", "camera":"close_broadcast",
		"weather":str(session.weather_preset), "sun_shadows":game.get_node("Sun").shadow_enabled,
		"ball_id":str(game.ball.get_node("BallVisual").get_meta("appearance_id")),
		"home_players":home.size(), "away_players":away.size(), "officials":official_count,
		"seating_audit":seating_audit, "venue":str(game.venue.id), "venue_view":view, "extra_views":extra_views, "phase":"stationary kickoff",
		"draw_calls":primary_draw_calls,
		"primitives":primary_primitives, "warmup_frames":3,
		"turf_triangles":primary_turf,
		"scope":"Actual Forward+ match still; no native Mac timing or graphics parity claim.",
	}
	assert(home.size() == 11 and away.size() == 11 and official_count == 1)
	var file := FileAccess.open(output.path_join("match_broadcast.json"), FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(report,"  ") + "\n")
	print("BEECHLAWN_NATIVE_CAPTURE ", JSON.stringify(report))
	quit()

func _capture_turf(game: Node3D, camera: Camera3D) -> void:
	# Minimized material diagnostic: the production pitch, weather, sky and sun,
	# with other geometry hidden before rendering. Full-match captures remain the
	# appearance gate; this isolates actual shader response from roof/actor shadows.
	game.get_node("HUD").hide()
	for child in game.get_children():
		if child is Node3D and child.name not in [&"Pitch",&"Sun",&"BroadcastCamera"]:
			child.hide()
			child.process_mode = Node.PROCESS_MODE_DISABLED
	for child in game.get_node("Pitch").get_children():
		if child is Node3D and child.name != &"SundayLeagueTurf": child.hide()
	var turf: MeshInstance3D = game.get_node("Pitch/SundayLeagueTurf")
	var material := turf.material_override as ShaderMaterial
	var original := material.shader
	var diffuse := Shader.new()
	diffuse.code = original.code.strip_edges().trim_suffix("}")+"\nSPECULAR=0.0;\n}\n"
	var folder := str(options["capture-dir"])
	DirAccess.make_dir_recursive_absolute(folder)
	var cases: Array = []
	var positions := [Vector3(0,24,-45),Vector3(0,24,45),Vector3(-45,24,0),Vector3(45,24,0)]
	for index in positions.size():
		camera.global_position = positions[index]
		camera.look_at(Vector3.ZERO); camera.fov=60
		camera.reset_physics_interpolation()
		var images: Array[Image] = []
		for variant in [&"surface",&"diffuse"]:
			material.shader = original if variant == &"surface" else diffuse
			for frame in 2: await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var filename := "turf_%d_%s.png"%[index,variant]
			assert(image.save_png(folder.path_join(filename)) == OK)
			if index == 0 and variant == &"surface":
				assert(image.save_png(folder.path_join("match_broadcast.png")) == OK)
			images.append(image)
		var length_groups := [[],[]]
		var cross_groups := [[],[]]
		var specular_sum := 0.0
		var diffuse_sum := 0.0
		var samples := 0
		for x_band in range(-4,4):
			for z_band in range(-3,3):
				var point := Vector3((float(x_band)+.5)*7.5,0,(float(z_band)+.5)*8.5)
				if camera.is_position_behind(point): continue
				var pixel := camera.unproject_position(point)*Vector2(images[0].get_size())/root.get_visible_rect().size
				if not Rect2(Vector2(4,4),Vector2(images[0].get_size())-Vector2(8,8)).has_point(pixel): continue
				var values: Array[float] = []
				for image in images:
					var value := 0.0
					for dx in range(-2,3):
						for dy in range(-2,3):
							var c := image.get_pixel(int(pixel.x)+dx,int(pixel.y)+dy).srgb_to_linear()
							value += c.r*.2126+c.g*.7152+c.b*.0722
					values.append(value/25.0)
				length_groups[posmod(x_band,2)].append(values[0])
				cross_groups[posmod(z_band,2)].append(values[0])
				specular_sum += maxf(0,values[0]-values[1]); diffuse_sum+=values[1]; samples+=1
		cases.append({"camera":str(positions[index]),"samples":samples,"length_contrast":_turf_contrast(length_groups),
			"cross_contrast":_turf_contrast(cross_groups),"specular_fraction":specular_sum/maxf(.0001,diffuse_sum)})
	material.shader = original
	var report := {"rendering_method":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"display_server":DisplayServer.get_name(),
		"home_players":game._home_players.size(),"away_players":game._away_players.size(),"officials":get_nodes_in_group("match_officials").size(),"other_geometry_hidden":true,
		"resolution":[root.size.x,root.size.y],"venue":str(game.venue.id),"weather":str(options.get("weather","sunny")),"cases":cases,
		"scope":"Minimized production surface, sun, sky and weather; other geometry hidden. Diffuse diagnostic changes SPECULAR only. Not Mac performance/parity evidence."}
	FileAccess.open(folder.path_join("match_broadcast.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("BEECHLAWN_NATIVE_CAPTURE ",JSON.stringify(report))
	root.close_requested.emit()

func _turf_contrast(groups: Array) -> float:
	var means: Array[float] = []
	for group in groups:
		var total := 0.0
		for value in group: total+=float(value)
		means.append(total/maxi(1,group.size()))
	return absf(means[0]-means[1])/maxf(.0001,(means[0]+means[1])*.5)

func _audit_stadium_seating(game: Node3D) -> Dictionary:
	var arena := game.get_node("ParkEdge/RoversArena")
	var layout := RoversArena.layout()
	var checked := 0
	var errors := 0
	for section: Dictionary in layout.sections:
		var id := int(section.id)
		var near := arena.get_node("SeatsNear%02d"%id) as MultiMeshInstance3D
		var far := arena.get_node("SeatsFar%02d"%id) as MultiMeshInstance3D
		for index in range(0,near.multimesh.instance_count,13):
			var pose := near.global_transform*near.multimesh.get_instance_transform(index)
			var other := far.global_transform*far.multimesh.get_instance_transform(index)
			if not pose.is_equal_approx(other) or not StadiumGeometryAudit.check_pose(pose,section,layout): errors += 1
			checked += 1
	return {"sampled_seats":checked,"errors":errors,"scope":"Actual GPU buffers: centred blocks, supported level rows, inward chairs, straight/radial aisles, identical near/far transforms"}
