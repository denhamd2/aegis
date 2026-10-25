extends SceneTree
## A travelling shot meets moving gloves; covers timing missed by fixed-pose tests.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	for team in [game._home_players,game._away_players]:
		for actor in game._home_players+game._away_players: actor.position=Vector3(0,0,90)
		var keeper: FootballPlayer
		for actor in team:
			if actor.profile.role == "goalkeeper": keeper=actor
		var sx := keeper.attack_sign
		keeper.position=Vector3(-49.5*sx,0,0);keeper.rotation.y=-PI/2*sx;keeper.controlled_by_human=false
		keeper._goalkeeper_controller.reset_for_stoppage();keeper.set_physics_process(true)
		game.ball.release_for_restart();game.ball.freeze=true
		game.ball.position=Vector3(-44.5*sx,.16,.6)
		await physics_frame
		game.ball.freeze=false
		game.ball.kick(Vector3.LEFT*sx,12,0,&"shot",&"Boardeaux" if sx>0 else &"Beechlawn Rovers")
		var saved := false
		for tick in 70:
			await physics_frame
			if game.ball.last_action == &"goalkeeper_save":
				assert(keeper._goalkeeper_controller.is_recovering())
				print("LIVE_SAVE team=",keeper.team_name," tick=",tick," hands=",keeper._footballer_visual.hand_positions()," ball=",game.ball.position)
				saved=true;break
		assert(saved,"Live rolling shot must meet gloves and produce a physical parry")
		keeper.set_physics_process(false);game.ball.freeze=true
	game.free();quit()
