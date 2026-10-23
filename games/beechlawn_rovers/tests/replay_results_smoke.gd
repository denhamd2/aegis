extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("_run")
func check(value: bool,message: String) -> void:
	if not value: failures.append(message);push_error(message)
func _run() -> void:
	var session:=root.get_node("MatchSession")
	session.launched_from_menu=false
	var game=load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game);current_scene=game
	await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	var manager: FootballMatchPresentation=game.presentation
	var actor: FootballPlayer=game.player
	var visual:=actor.get_node("Visual") as FootballerVisual
	visual.play_presentation(&"AN_Beechlawn_Jog")
	for frame in 400:
		actor.position=Vector3(float(frame)*.04,0,0)
		visual.animation_player.seek(fmod(float(frame)/30,.8),true)
		game.ball.position=Vector3(float(frame)*.06,.15,0)
		manager.buffer.sample(1.0/30,true)
	check(manager.buffer.history.size()==360,"Bounded twelve-second ring")
	var entry:=manager.buffer.bookmark(&"goal")
	if entry.is_empty():quit(1);return
	for index in 5:manager.buffer.bookmark(&"save")
	check(manager.buffer.bookmarks.size()==3 and manager.buffer.data_bytes()<64*1024*1024,"Bounded bookmarks and pose budget")
	game.restart.begin("FREE KICK",&"Beechlawn Rovers",Vector3(20,0,4))
	var live: Transform3D=game.ball.global_transform
	var velocity: Vector3=game.ball.linear_velocity
	var serial: int=game.ball.action_serial
	var clock: float=game._remaining_time
	var score:=Vector2i(game._home_score,game._away_score)
	var events: Array[FootballMatchEvent]=[]
	game.events.occurred.connect(func(event: FootballMatchEvent):events.append(event))
	check(manager.start_replay(entry),"Recorded replay starts")
	check(manager.ghosts.size()==23,"Replay includes both full teams and referee")
	for index in manager.ghosts.size():
		var source_meshes:=manager.buffer.actors[index].get_node("Visual").find_children("*","MeshInstance3D",true,false)
		var copies:=manager.ghosts[index].get_node("Visual").find_children("*","MeshInstance3D",true,false)
		check(source_meshes.size()==copies.size(),"Ghost retains actual roster mesh count")
		for mesh_index in mini(source_meshes.size(),copies.size()):
			check(copies[mesh_index].mesh==source_meshes[mesh_index].mesh and copies[mesh_index].material_override==source_meshes[mesh_index].material_override,"Ghost retains actual head/kit resources")
	check(manager.ghost_world.find_children("*","PhysicsBody3D",true,false).is_empty(),"Ghosts have no physics bodies")
	check(get_nodes_in_group("football_players").size()==22,"Ghosts do not enter gameplay groups")
	var first: Vector3=manager.ghosts[0].position
	for tick in 90:game._physics_process(1.0/60)
	check(manager.ghosts[0].position.distance_to(first)>.5,"Replay interpolates recorded movement")
	check(game.ball.global_transform.is_equal_approx(live) and game.ball.action_serial==serial,"Live ball unchanged by playback")
	check(Vector2i(game._home_score,game._away_score)==score and is_equal_approx(game._remaining_time,clock),"Replay cannot score or consume clock")
	check(events.is_empty(),"Replay cannot fire gameplay/audio events")
	var skip:=InputEventKey.new();skip.keycode=KEY_SPACE;skip.pressed=true
	check(manager.handle_key(skip),"Replay skip accepted")
	check(not manager.active() and not is_instance_valid(manager.ghost_world),"Ghosts and override clear on skip")
	check(game.ball.global_transform.is_equal_approx(live) and game.ball.linear_velocity.is_equal_approx(velocity),"Exact live ball restoration")
	check(game.restart.active() and game.restart.phase==game.restart.Phase.PREPARE and game.ball.freeze,"Exact pending restart retained")
	game.restart.cancel()
	# An own goal celebrates the scoring side, never the conceding last toucher.
	game.ball.last_touch_player=game._away_players[2]
	game.ball.last_touch=&"Boardeaux"
	for frame in 60: manager.buffer.sample(1.0/30,true)
	game._on_goal("Beechlawn Rovers",1)
	manager.update(.02)
	game._on_goal("Beechlawn Rovers",1)
	check(game._home_score==1,"Celebration cannot award a duplicate goal")
	check(manager.phase==manager.Phase.GOAL and manager._focus.team_name==&"Beechlawn Rovers","Own-goal focus belongs to scoring team")
	for tick in 241: manager.update(1.0/60)
	check(manager.phase==manager.Phase.REPLAY,"Goal automatically enters its recorded replay")
	check(manager.handle_key(skip),"Goal replay skips to kickoff")
	check(game._kickoff_pending and game._home_score==1 and not game._presentation_active,"Goal restart and score preserved")
	# Nearby opponents walk to a handshake rather than teleporting into a line.
	game._home_players[2].position=Vector3(0,0,0)
	game._away_players[2].position=Vector3(3,0,0)
	game._home_score=2;game._away_score=1
	game._finish_match();manager.update(.02)
	check(manager.phase==manager.Phase.FULL_TIME and manager._pairs.size()>0,"Winner sequence includes nearby handshake pairs")
	for tick in 121:manager.update(.1)
	check(manager.phase==manager.Phase.RESULTS and manager.results.visible,"Full time reaches results naturally")
	var buttons:=manager.results.find_children("*","Button",true,false)
	check(buttons.size()==2,"Results offer Rematch and Title")
	buttons[0].pressed.emit()
	for frame in 5:await process_frame
	game=current_scene
	check(game!=null and game.name=="Beechlawn11v11" and not game._full_time,"Rematch launches a fresh full match")
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	manager=game.presentation
	var dismissed: FootballPlayer=game._away_players[-1]
	game._away_players.erase(dismissed);dismissed.hide();dismissed.set_physics_process(false)
	game._home_score=0;game._away_score=0
	game._finish_match();manager.update(.02)
	check(not dismissed.visible,"Reduced-team outro retains dismissal")
	check(manager.caption.text.contains("DRAW"),"Draw has neutral full-time treatment")
	check(manager.handle_key(skip),"Full-time sequence skips to results")
	buttons=manager.results.find_children("*","Button",true,false)
	buttons[1].pressed.emit()
	for frame in 5:await process_frame
	check(current_scene!=null and current_scene.name=="TitleScreen" and get_nodes_in_group("football_players").is_empty(),"Title return releases live and ghost actors")
	print("REPLAY_RESULTS failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
