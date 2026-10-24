extends SceneTree
## Fast deceleration must keep stepping before the final planted stop pose.
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var game=load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var actor: FootballPlayer=game.player
	actor.position=Vector3(0,PitchSurface.height_at(0,0)+.005,0)
	actor.rotation.y=-PI/2
	actor.reset_for_stoppage()
	actor.controlled_by_human=false
	actor.ai_move_direction=Vector3.RIGHT
	actor.ai_sprinting=true
	game.ball.freeze=true
	game.ball.position=Vector3(100,.3,100)
	actor.set_physics_process(true)
	for frame in 60:await physics_frame
	assert(Vector2(actor.velocity.x,actor.velocity.z).length()>8,"Fixture must reach a real sprint")
	actor.ai_move_direction=Vector3.ZERO
	actor.ai_sprinting=false
	var fast_steps:=0
	var planted_stop:=false
	var valid:=true
	for frame in 50:
		await physics_frame
		var speed:=Vector2(actor.velocity.x,actor.velocity.z).length()
		if speed>3:
			fast_steps+=1
			if not actor._footballer_visual.animation_tree.active:valid=false
		if actor._footballer_visual._active_action==&"stop":planted_stop=true
	print("BRAKING_GAIT fast_steps=",fast_steps," kept_gait=",valid," final_stop_pose=",planted_stop)
	game.free()
	if not valid or fast_steps<10 or not planted_stop:
		push_error("Fast braking played a planted stop while the body was still translating")
		quit(1)
		return
	print("BRAKING_GAIT PASS")
	quit()
