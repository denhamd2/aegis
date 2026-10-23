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
var keeper_contacts: Array[Dictionary] = []
var review_keeper: FootballPlayer
var review_actor: FootballPlayer
var aerial_events: Array[Dictionary] = []
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair:=argument.substr(2).split("=",true,1)
			options[pair[0]]=pair[1]
	call_deferred("_capture")
func _physics_step() -> void:
	tick+=1
	if mode.begins_with("attack_") or mode.begins_with("cross_"):game._update_ai(1.0/60.0)
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
		"keeper":str(review_keeper.position) if is_instance_valid(review_keeper) else "",
		"keeper_recovering":review_keeper._keeper_is_recovering() if is_instance_valid(review_keeper) else false,
		"ball_action":str(game.ball.last_action),"ball_velocity":str(game.ball.linear_velocity),
		"aerial_actor":str(review_actor.position) if is_instance_valid(review_actor) else "",
		"player_velocity":str(game.player.velocity),"shot_contacts":shot_contacts.duplicate(true),"score":[game._home_score,game._away_score]})
	print("REPAIR_FRAME ",filename," ",label)
func _capture() -> void:
	assert(RenderingServer.get_current_rendering_method()=="forward_plus")
	output=str(options["capture-dir"])
	mode=str(options.get("review-mode","movement"))
	DirAccess.make_dir_recursive_absolute(output)
	var session:=root.get_node("MatchSession")
	session.launched_from_menu=false;session.weather_preset=&"sunny"
	if mode.begins_with("attack_") or mode.begins_with("cross_") or mode in ["header_close", "chest_close"]:
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
		elif mode.begins_with("cross_"):
			var team: Array[FootballPlayer] = game._home_players if mode=="cross_home" else game._away_players
			var opponents: Array[FootballPlayer] = game._away_players if mode=="cross_home" else game._home_players
			var passer: FootballPlayer = team[2]
			for actor in team:
				if actor.profile.starting_slot=="striker_left":review_actor=actor
			var sx:=passer.attack_sign
			passer.position=Vector3(33*sx,PitchSurface.height_at(33*sx,21)+.005,21)
			review_actor.position=Vector3(42*sx,PitchSurface.height_at(42*sx,2)+.005,2)
			review_actor.rotation.y=-PI/2*sx;review_actor.controlled_by_human=false
			review_actor.set_physics_process(true)
			var defender: FootballPlayer=opponents[2]
			defender.position=Vector3(44*sx,PitchSurface.height_at(44*sx,2.9)+.005,2.9)
			defender.set_physics_process(true)
			opponents[3].position=passer.position+Vector3(sx,0,1.8)
			for actor in opponents:
				if actor.profile.role=="goalkeeper":
					actor.position=Vector3(49.5*sx,0,0);actor.set_physics_process(true)
			var toward:=review_actor.position-passer.position;toward.y=0
			passer.rotation.y=atan2(-toward.x,-toward.z)
			game.ball.position=passer.position+toward.normalized()*.6+Vector3.UP*.13
			game.ball.freeze=false;game.ball.last_action=&"dribble"
			game.ball.last_touch=passer.team_name;game.ball.last_touch_player=passer
			game._kickoff_pending=false
			game.player=review_actor;game.camera_rig.set("player",review_actor)
			camera.queue_free();camera=game.camera_rig.camera
			game.camera_rig.presentation_override=false;camera.make_current();game.camera_rig.reset_tracking()
			game.ball.touched.connect(_record_aerial)
			passer._do_pass(false,toward,false,1.0,review_actor,&"cross",.72)
		elif mode in ["header_close", "chest_close"]:
			for actor in game._home_players:
				if actor.profile.player_id==&"shane_denham":review_actor=actor
			review_actor.position=Vector3(32,PitchSurface.height_at(32,0)+.005,0)
			review_actor.rotation.y=-PI/2;review_actor.controlled_by_human=true
			game.player=review_actor;game._kickoff_pending=false
			game.ball.position=review_actor.position+Vector3(2.5,2.2 if mode=="header_close" else 1.7,0)
			var destination:=review_actor.position+Vector3(.14,review_actor.tuning.header_contact_height,0) if mode=="header_close" else review_actor._aerial_controller.chest_point()
			game.ball.freeze=false
			# Isolated incoming-ball setup. Full winger kicks are reviewed in the
			# separate cross modes, not inferred from this scripted launch.
			game.ball.kick_velocity(FootballBallFlight.launch(game.ball,destination,.31 if mode=="header_close" else .235),&"cross" if mode=="header_close" else &"lofted_pass",review_actor.team_name,null)
			game.ball.touched.connect(_record_aerial)
			if mode=="header_close":review_actor._aerial_controller.request_header(Vector3.RIGHT)
			else:review_actor.receive_target_time=1.0
			review_actor.set_physics_process(true)
			camera.position=review_actor.position+Vector3(2.7,1.6,2.6)
			camera.look_at(review_actor.position+Vector3(.1,1.05,0));camera.fov=45
		elif mode.begins_with("keeper_"):
			var team: Array[FootballPlayer] = game._home_players if mode=="keeper_home" else game._away_players
			for candidate in team:
				if candidate.profile.role=="goalkeeper":review_keeper=candidate
			var sx:=review_keeper.attack_sign
			review_keeper.position=Vector3(-49.5*sx,0,0)
			review_keeper.rotation.y=-PI/2*sx
			review_keeper.controlled_by_human=false
			review_keeper._goalkeeper_controller.reset_for_stoppage()
			review_keeper.set_physics_process(true)
			game._kickoff_pending=false
			game.ball.position=review_keeper.position+Vector3(5*sx,.16,.6)
			game.ball.freeze=false
			camera.position=review_keeper.position+Vector3(6*sx,2.0,5.5)
			camera.look_at(review_keeper.position+Vector3(1.4*sx,.7,0));camera.fov=52
			game.ball.touched.connect(func(kind: StringName, _speed: float):
				if kind in [&"goalkeeper_save", &"goalkeeper_catch", &"goalkeeper_distribution"]:
					keeper_contacts.append({"tick":tick,"kind":str(kind),"team":str(game.ball.last_touch),"ball":str(game.ball.position)}))
			game.ball.kick(Vector3(-sx,0,0),12,0,&"shot",&"Boardeaux" if sx>0 else &"Beechlawn Rovers")
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
		var frames:=30 if mode.begins_with("cross_") else (12 if mode in ["header_close", "chest_close"] else 24)
		for index in frames:
			for f in 6:await physics_frame
			if mode=="movement":
				camera.position=game.player.position+Vector3(-3.4,1.6,-5.7)
				camera.look_at(game.player.position+Vector3(.3,.85,0))
			await _save(mode)
		physics_frame.disconnect(_physics_step)
	if mode.begins_with("attack_") and shot_contacts.is_empty():
		push_error("Native attack fixture produced no physical AI shot contact")
		quit(1);return
	if mode.begins_with("keeper_") and keeper_contacts.is_empty():
		push_error("Native keeper fixture produced no physical save/catch contact")
		quit(1);return
	if mode.begins_with("cross_") or mode in ["header_close", "chest_close"]:
		var valid:=false
		for event in aerial_events:
			if event.part in ["head", "chest"]:valid=true
		if not valid:
			push_error("Native aerial fixture produced no validated head/chest contact")
			quit(1);return
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	paused=true
	var primary:=1 if mode=="montage" else 0
	for event in aerial_events:
		if event.part in ["head","chest"]:
			for index in sequence.size():
				if sequence[index].tick>=event.tick:primary=index;break
			break
	var first:=Image.load_from_file(output.path_join(sequence[primary].file))
	assert(first.save_png(output.path_join("match_broadcast.png"))==OK)
	var report:={"rendering_method":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),
		"api":RenderingServer.get_video_adapter_api_version(),"display_server":DisplayServer.get_name(),
		"godot":Engine.get_version_info().string,"resolution":[first.get_width(),first.get_height()],
		"msaa_3d":root.msaa_3d,"home_players":game._home_players.size(),"away_players":game._away_players.size(),
		"officials":get_nodes_in_group("match_officials").size(),"review_mode":mode,"frames":sequence,"shot_contacts":shot_contacts,"keeper_contacts":keeper_contacts,"aerial_events":aerial_events,
		"fixture_setup":"scripted incoming ball" if mode in ["header_close", "chest_close"] else ("winger delivery through foot marker" if mode.begins_with("cross_") else mode),
		"scope":"Actual native Forward+ controllers and assets; accelerated simulated time, software GPU, no Mac performance claim."}
	var file:=FileAccess.open(output.path_join("match_broadcast.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	print("BEECHLAWN_NATIVE_CAPTURE ",JSON.stringify(report))
	quit()

func _record_aerial(kind: StringName, _speed: float) -> void:
	var ball: FootballBall=game.ball
	if kind not in [&"lofted_pass", &"cross", &"aerial_control", &"shot", &"header_clearance"]:return
	if kind==&"shot" and ball.last_strike_part!=&"head":return
	var actor:=ball.last_touch_player as FootballPlayer
	var point:=ball.position
	if actor!=null and ball.last_strike_part==&"head":point=actor._aerial_controller.forehead_point()
	elif actor!=null and ball.last_strike_part==&"chest":point=actor._aerial_controller.chest_point()
	elif actor!=null and ball.last_strike_part==&"foot":point=actor._receive_contact_position()
	aerial_events.append({"tick":tick,"kind":str(kind),"part":str(ball.last_strike_part),
		"team":str(ball.last_touch),"player_id":str(actor.profile.player_id) if actor!=null else "",
		"ball":str(ball.position),"contact":str(point),"gap":point.distance_to(ball.position)})
