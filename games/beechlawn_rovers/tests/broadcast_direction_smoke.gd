extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var session := root.get_node("MatchSession")
	session.launched_from_menu=false
	var game=load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game);current_scene=game
	await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	var manager: FootballMatchPresentation=game.presentation
	var banner:=manager.panel as FootballLowerThird
	for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1200,900)]:
		root.size=size
		await process_frame
		banner._layout()
		var rect:=banner.get_global_rect()
		assert(absf(rect.get_center().x-banner.get_viewport_rect().size.x*.5)<1,"Centered at every aspect")
		assert(rect.size.x<=1200 and rect.position.x>=24,"Responsive title-safe width")
		assert(absf(rect.size.y-104)<1 and rect.end.y<=banner.get_viewport_rect().size.y-35,"Safe lower edge")
	for team in ["Beechlawn Rovers","Boardeaux"]:
		manager._start_goal(team)
		manager.update(.1)
		var wide:=manager.camera.global_position
		manager.update(2.1)
		var medium:=manager.camera.global_position
		manager.update(2.0)
		assert(manager.director.cuts==3,"Three intentional celebration cuts for either team")
		assert(wide.distance_to(medium)>1 and medium.distance_to(manager.camera.global_position)>1,"Distinct camera stations")
		assert(String(manager.director.current_shot).begins_with("scorer_close"))
		manager._finish_goal()
	# A marked real timeline, with both forward playback and slow contact detail.
	for index in 210:
		game.ball.position=Vector3(40+float(index)*.06,.3,1)
		manager.buffer.sample(1.0/30,true)
	var event:=FootballMatchEvent.new()
	event.kind=FootballMatchEvent.Kind.GOAL;event.team=&"Beechlawn Rovers";event.actor=game.player
	manager.buffer.mark_incident(event)
	for index in 15: manager.buffer.sample(1.0/30,true)
	var entry:=manager.buffer.bookmark(&"goal")
	assert(entry.has("incident") and entry.incident.actor_index>=0,"Incident carries actor/time metadata")
	assert(manager.start_replay(entry,&"goal"))
	manager.update(.1)
	manager.update(manager._wide_duration)
	var playhead:=manager._playhead
	manager.update(.5)
	assert(absf(manager._playhead-playhead-.25)<.001,"Detail pass plays actual snapshots at half speed")
	assert(String(manager.director.current_shot).begins_with("replay_goal_detail") and manager.director.cuts>=2)
	manager._finish_replay()
	assert(not manager.active() and game._kickoff_pending,"Replay finishes at the pending restart")
	assert(game.grass_detail.chunks.is_empty(),"Headless match does no grass generation")
	game.free()
	print("BROADCAST_DIRECTION PASS: centered safe layouts, mirrored cuts, incident metadata, half-speed poses, exact restart")
	quit()
