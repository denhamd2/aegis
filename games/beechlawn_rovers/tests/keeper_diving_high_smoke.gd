extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	Engine.time_scale=4;Engine.physics_ticks_per_second=240
	var game=load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	for team in [game._home_players,game._away_players]:
		for high in [false,true]:
			for actor in game._home_players+game._away_players:actor.position=Vector3(0,0,90)
			var keeper: FootballPlayer
			for actor in team:
				if actor.profile.role=="goalkeeper":keeper=actor
			var sx:=keeper.attack_sign
			keeper.position=Vector3(-49.5*sx,0,0);keeper.rotation.y=-PI/2*sx;keeper.controlled_by_human=false
			keeper.reset_for_stoppage();keeper.set_physics_process(true)
			game.ball.release_for_restart();game.ball.freeze=true
			game.ball.position=keeper.position+Vector3(5*sx,2.1 if high else 1.1,0 if high else 1.6)
			await physics_frame
			game.ball.freeze=false
			game.ball.kick(Vector3.LEFT*sx,6 if high else 14,4 if high else 2,&"cross" if high else &"shot",&"Boardeaux" if sx>0 else &"Beechlawn Rovers")
			var saved:=false
			var closest:=INF
			var diagnostic: Dictionary={}
			for tick in 100:
				await physics_frame
				for hand in keeper._footballer_visual.hand_positions():
					var distance: float=hand.distance_to(game.ball.position)
					if distance<closest:
						closest=distance;diagnostic={"tick":tick,"ball":str(game.ball.position),"hand":str(hand),"keeper":str(keeper.position),"yaw":keeper.rotation.y,"clip":keeper._footballer_visual.animation_player.current_animation}
				if game.ball.last_action in [&"goalkeeper_save",&"goalkeeper_catch"]:
					var visual:=keeper.get_node("Visual") as FootballerVisual
					if high:assert(game.ball.goalkeeper_is_holding(keeper),"High cross must be supported by a real claim")
					else:
						assert(String(visual.animation_player.current_animation).contains("KeeperDive"),"Wide shot uses a directional dive")
						var skeleton:=visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
						var head:=skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_Head")).origin)
						assert(head.y-keeper.position.y<1.3,"Dive lowers and rolls the whole body")
						assert((keeper.get_node("CollisionShape3D").shape as CapsuleShape3D).height<1,"Dive collision follows low torso")
					print("KEEPER_ADVANCED team=",keeper.team_name," high=",high," contact=",game.ball.position," clip=",visual.animation_player.current_animation)
					saved=true;break
			if not saved:
				push_error("Dedicated keeper failed high="+str(high)+" closest="+str(closest)+" diagnostic="+str(diagnostic))
				game.free();quit(1);return
			keeper.reset_for_stoppage()
			assert((keeper.get_node("CollisionShape3D").shape as CapsuleShape3D).height>1.7,"Stoppage restores standing collider")
			keeper.set_physics_process(false);game.ball.release_for_restart();game.ball.freeze=true
	game.free();print("KEEPER_DIVING_HIGH PASS");quit()
