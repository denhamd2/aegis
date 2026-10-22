extends SceneTree
## Native Forward+ moving evidence of the actual match assets/controllers.
var options: Dictionary={}
var game: Node3D
var camera: Camera3D
var sequence: Array[Dictionary]=[]
var tick:=0
var output: String
var mode: String
var shot_contacts: Array[Dictionary] = []
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair:=argument.substr(2).split("=",true,1)
			options[pair[0]]=pair[1]
	call_deferred("_capture")
func _physics_step() -> void:
	tick+=1
	if mode.begins_with("attack_"):game._update_ai(1.0/60.0)
	if game.restart.active():game.restart.update(1.0/60.0)
	for impact in game._net_impacts.values():
		impact.age=minf(2,impact.age+1.0/60.0)
		(impact.material as ShaderMaterial).set_shader_parameter("impact_age",impact.age)
func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var filename:="frame_%03d.png"%sequence.size()
	assert(image.save_png(output.path_join(filename))==OK)
	sequence.append({"file":filename,"label":label,"tick":tick,
		"ball":str(game.ball.position),"player":str(game.player.position),
		"player_velocity":str(game.player.velocity),"shot_contacts":shot_contacts.duplicate(true),"score":[game._home_score,game._away_score]})
	print("REPAIR_FRAME ",filename," ",label)
func _capture() -> void:
	assert(RenderingServer.get_current_rendering_method()=="forward_plus")
	output=str(options["capture-dir"])
	mode=str(options.get("review-mode","movement"))
	DirAccess.make_dir_recursive_absolute(output)
	var session:=root.get_node("MatchSession")
	session.launched_from_menu=false;session.weather_preset=&"sunny"
	if mode.begins_with("attack_"):
		session.mode=session.MatchMode.WATCH;session.launched_from_menu=true;session.show_intro=false
	game=load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game);current_scene=game
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	game.camera_rig.presentation_override=true
	camera=Camera3D.new();game.add_child(camera);camera.make_current()
	camera.near=.04;camera.far=350
	if mode=="montage":
		var director:=preload("res://scripts/pre_match_director.gd").new()
		game.add_child(director);director.start(game);director.set_process(false)
		for index in 6:
			director._enter_shot(index)
			for time in [0.0,1.5,2.95]:
				director._update_shot(time)
				await _save(str(director.shots[index].id)+" %.2f"%time)
	else:
		for actor in game._home_players+game._away_players:actor.position=Vector3(150,0,150)
		if mode.begins_with("attack_"):
			var team: Array[FootballPlayer] = game._home_players if mode=="attack_home" else game._away_players
			var opposition: Array[FootballPlayer] = game._away_players if mode=="attack_home" else game._home_players
			var actor: FootballPlayer
			for candidate in team:
				if candidate.profile.starting_slot=="striker_left":actor=candidate
			var sx:=actor.attack_sign
			for candidate in game._home_players+game._away_players:
				candidate.controlled_by_human=false
				candidate.position=Vector3(candidate.profile.starting_position.x*candidate.attack_sign,0,candidate.profile.starting_position.y)
			actor.position=Vector3(35*sx,0,6);actor.rotation.y=-PI/2*sx
			var defender: FootballPlayer=game._nearest_outfielder(opposition,Vector2(35*sx,6))
			defender.position=Vector3(32*sx,0,6.5)
			game.ball.position=Vector3(35.6*sx,.14,6);game.ball.freeze=false
			game.ball.last_touch=actor.team_name;game.ball.last_touch_player=actor
			game.ball.last_action=&"dribble";game._kickoff_pending=false
			game._set_players_physics_enabled(true)
			camera.queue_free();camera=game.camera_rig.camera
			game.camera_rig.presentation_override=false;camera.make_current();game.camera_rig.reset_tracking()
			game.ball.touched.connect(func(kind: StringName, _speed: float):
				if kind==&"shot":shot_contacts.append({"tick":tick,"team":str(game.ball.last_touch),"ball":str(game.ball.position)}))
		elif mode=="movement":
			var actor: FootballPlayer=game.player
			actor.position=Vector3.ZERO;actor.rotation.y=-PI/2
			actor.controlled_by_human=false;actor.ai_move_direction=Vector3.RIGHT
			actor.ai_action_cooldown=100;actor.set_physics_process(true)
			game.ball.position=Vector3(.45,.15,0);game.ball.freeze=false
			camera.fov=51
		elif mode=="throw":
			game.restart.begin("THROW-IN",&"Beechlawn Rovers",Vector3(4,0,-34))
			camera.position=Vector3(1.0,1.8,-29.5)
			camera.look_at(Vector3(4,1.2,-34))
			camera.fov=44
			game.restart.take(.65)
		elif mode=="net":
			game.ball.position=Vector3(50,1.1,0);game.ball.freeze=false
			camera.position=Vector3(50.3,1.8,5.6)
			camera.look_at(Vector3(53.9,1.1,0));camera.fov=48
			game.ball.kick(Vector3.RIGHT,18,0,&"shot",&"Beechlawn Rovers")
		physics_frame.connect(_physics_step)
		# Six real 60 Hz steps per draw: useful slow software rendering evidence,
		# with recorded simulated timing rather than a performance claim.
		Engine.time_scale=6;Engine.physics_ticks_per_second=360
		Engine.max_physics_steps_per_frame=64
		for index in 24:
			for f in 6:await physics_frame
			if mode=="movement":
				camera.position=game.player.position+Vector3(-3.4,1.6,-5.7)
				camera.look_at(game.player.position+Vector3(.3,.85,0))
			await _save(mode)
		physics_frame.disconnect(_physics_step)
	if mode.begins_with("attack_") and shot_contacts.is_empty():
		push_error("Native attack fixture produced no physical AI shot contact")
		quit(1);return
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	paused=true
	var first:=Image.load_from_file(output.path_join(sequence[1 if mode=="montage" else 0].file))
	assert(first.save_png(output.path_join("match_broadcast.png"))==OK)
	var report:={"rendering_method":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),
		"api":RenderingServer.get_video_adapter_api_version(),"display_server":DisplayServer.get_name(),
		"godot":Engine.get_version_info().string,"resolution":[first.get_width(),first.get_height()],
		"msaa_3d":root.msaa_3d,"home_players":game._home_players.size(),"away_players":game._away_players.size(),
		"officials":get_nodes_in_group("match_officials").size(),"review_mode":mode,"frames":sequence,"shot_contacts":shot_contacts,
		"scope":"Actual native Forward+ controllers and assets; accelerated simulated time, software GPU, no Mac performance claim."}
	var file:=FileAccess.open(output.path_join("match_broadcast.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	print("BEECHLAWN_NATIVE_CAPTURE ",JSON.stringify(report))
	quit()
