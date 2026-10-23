extends SceneTree
## Scripted presentation fixture on actual roster assets, not a natural match claim.
var output: String
var game: Node3D
var manager: FootballMatchPresentation
var sequence: Array[Dictionary]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):output=arg.trim_prefix("--capture-dir=")
	call_deferred("_run")
func step(ticks: int) -> void:
	for tick in ticks:
		game._physics_process(1.0/60)
		if not manager.replaying():
			for actor in manager.buffer.actors:
				var visual:=actor.get_node("Visual") as FootballerVisual
				visual.animation_player.advance(1.0/60)
func save_frame(filename: String) -> void:
	for frame in 2:await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(filename))==OK)
	sequence.append({"file":filename,"phase":manager.phase,"elapsed":manager.elapsed,"score":[game._home_score,game._away_score],"shot":manager.director.current_shot,"camera":str(manager.camera.global_position),"fov":manager.camera.fov,"playhead":manager._playhead,"obstruction":manager.director.obstruction})
func _run() -> void:
	game=load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game);current_scene=game
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	game.camera_rig.set_process(false)
	manager=game.presentation
	for actor in manager.buffer.actors:actor.get_node("Visual").process_mode=Node.PROCESS_MODE_DISABLED
	for detector in game.get_node("Goals").find_children("GoalDetector","Node3D",true,false):detector.set_physics_process(false)
	var actor: FootballPlayer=game.player
	var visual:=actor.get_node("Visual") as FootballerVisual
	visual.play_presentation(&"AN_Beechlawn_Jog")
	for frame in 210:
		actor.position=Vector3(30+float(frame)*.06,0,-2)
		actor.position.y=PitchSurface.height_at(actor.position.x,actor.position.z)
		visual.animation_player.seek(fmod(float(frame)/30,.8),true)
		game.ball.position=actor.position+Vector3(.6,.15,0)
		if frame >= 180:
			game.ball.position=Vector3(40.8+float(frame-180)*.44,.6,-2+float(frame-180)*.1)
		manager.buffer.sample(1.0/30,true)
	game.ball.last_touch_player=actor;game.ball.last_touch=actor.team_name
	game.ball.position=Vector3(54,.8,1)
	game._on_goal("Beechlawn Rovers",1)
	step(75)
	await save_frame("goal_celebration.png")
	step(90)
	await save_frame("goal_medium.png")
	step(120)
	await save_frame("goal_close.png")
	step(80)
	assert(manager.replaying())
	step(75)
	await save_frame("goal_replay.png")
	step(ceili((manager._wide_duration-manager.elapsed+.3)*60))
	await save_frame("goal_replay_detail.png")
	var skip:=InputEventKey.new();skip.keycode=KEY_SPACE;skip.pressed=true
	manager.handle_key(skip)
	game._home_players[2].position=Vector3(0,0,0);game._away_players[2].position=Vector3(3,0,0)
	game._home_score=2;game._away_score=1;game._update_score()
	game._finish_match();step(145)
	await save_frame("full_time_winners.png")
	step(100)
	await save_frame("full_time_medium.png")
	step(255)
	await save_frame("handshakes.png")
	step(240)
	assert(manager.phase==manager.Phase.RESULTS)
	await save_frame("match_broadcast.png")
	var report:={"rendering_method":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),
		"display_server":DisplayServer.get_name(),"home_players":11,"away_players":11,"officials":1,
		"frames":sequence,"pose_data_bytes":manager.buffer.data_bytes(),"ghost_physics_bodies":0,
		"scope":"Scripted native celebration/replay/results fixture using actual roster poses; not natural match or M1 performance evidence"}
	var file:=FileAccess.open(output.path_join("match_broadcast.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("BEECHLAWN_NATIVE_CAPTURE ",JSON.stringify(report))
	quit()
