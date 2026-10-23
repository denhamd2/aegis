extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var session:=root.get_node("MatchSession");session.launched_from_menu=false
	var game=load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game);await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	var a:FootballPlayer=game._home_players[2]
	var b:FootballPlayer=game._away_players[2]
	game._home_players.assign([a]);game._away_players.assign([b])
	a.position=Vector3.ZERO;b.position=Vector3(2.4,0,0)
	var manager:FootballMatchPresentation=game.presentation
	manager._start_full_time()
	for tick in 500:
		manager.update(1.0/60)
		for actor in [a,b]: actor.get_node("Visual").animation_player.advance(1.0/60)
	var va:=a.get_node("Visual") as FootballerVisual
	var vb:=b.get_node("Visual") as FootballerVisual
	print("HANDSHAKE_POSE ",JSON.stringify({"a_clip":va.animation_player.current_animation,"b_clip":vb.animation_player.current_animation,"a":str(a.position),"b":str(b.position),"a_hands":str(va.hand_positions()),"b_hands":str(vb.hand_positions())}))
	assert(va.animation_player.current_animation==&"AN_Beechlawn_Handshake" and vb.animation_player.current_animation==&"AN_Beechlawn_Handshake")
	var gap:=va.hand_positions()[1].distance_to(vb.hand_positions()[1])
	print("HANDSHAKE_WRIST_GAP ",gap)
	assert(gap<.25,"Opposing right hands meet plausibly")
	game.free();quit()
