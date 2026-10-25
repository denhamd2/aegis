extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.get_node("MatchSession").launched_from_menu=false
	var game=load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game);await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	var manager:FootballMatchPresentation=game.presentation
	var actor:FootballPlayer
	for item in game._home_players:
		if item.profile.player_id==&"shane_denham":actor=item
	var face:=actor.get_node("Visual").find_child("Skin_Head",true,false) as MeshInstance3D
	var blink:=face.find_blend_shape_by_name("Blink")
	for index in 60:
		face.set_blend_shape_value(blink,.2 if index<30 else .8)
		manager.buffer.sample(1.0/30,true)
	face.set_blend_shape_value(blink,.15)
	assert(manager.start_replay(manager.buffer.bookmark(&"save")))
	var ghost:=manager.ghosts[manager.buffer.actors.find(actor)].get_meta("replay_head") as MeshInstance3D
	assert(absf(ghost.get_blend_shape_value(blink)-.2)<.001)
	manager.update(1.2)
	assert(absf(ghost.get_blend_shape_value(blink)-.8)<.001)
	assert(absf(face.get_blend_shape_value(blink)-.15)<.001)
	manager._finish_replay()
	assert(absf(face.get_blend_shape_value(blink)-.15)<.001)
	print("RECORDED_FACES PASS: recorded blink interpolation and exact live weight restoration")
	game.free();quit()
