extends SceneTree
## Reversals keep the touch in front of the body; one actor controls each tick.

func _initialize() -> void:
	call_deferred("_run")

func _fail(game: Node, message: String) -> void:
	push_error(message)
	game.free()
	quit(1)

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	for actor in get_nodes_in_group("football_players"):
		actor.set_physics_process(false)
		actor.global_position=Vector3(100,0,100)
	var player := game.get_node("Player") as FootballPlayer
	var teammate: FootballPlayer=game._home_players[2]
	var ball := game.get_node("Ball") as FootballBall
	# Reverse the world-right run using the current camera's screen direction.
	var reverse_action: StringName = &"move_left" if player.camera.global_basis.x.x > 0.0 else &"move_right"
	for human in [false,true]:
		player.global_position=Vector3.ZERO
		player.rotation.y=-PI/2
		player._flat_direction=Vector3.RIGHT
		player.velocity=Vector3.RIGHT*6.0
		player.controlled_by_human=human
		player.ai_move_direction=Vector3.LEFT
		if human:Input.action_press(reverse_action)
		player._sample_input()
		player._update_locomotion(1.0/60.0)
		Input.action_release(reverse_action)
		var heading_gap := rad_to_deg((-player.global_basis.z).angle_to(player._flat_direction))
		print("REVERSAL human=",human," touch_heading_gap_degrees=",snappedf(heading_gap,0.01))
		if heading_gap>35.0:
			_fail(game,"Touch direction jumped across the body during a reversal");return
		if player.velocity.x<=0 or player.velocity.x>=6.0:
			_fail(game,"Reversal must start braking promptly while retaining momentum");return
	player.global_position = Vector3.ZERO
	player.rotation.y = -PI / 2.0
	ball.freeze = true
	ball.global_position = Vector3(-0.7, FootballBall.RADIUS, 0)
	ball.last_touch = &"none"
	ball.last_action = &"none"
	ball._dribble_cooldowns.clear()
	ball._dribble_controller = null
	await physics_frame
	if ball.dribble_touch(player, Vector3.RIGHT, false, false, 0.23, 0.48, 1.05):
		_fail(game,"A forward touch pulled a ball from behind the player through the body");return
	for reverse_order in [false,true]:
		player.global_position=Vector3(-0.5,0,0)
		teammate.global_position=Vector3(0.85,0,0)
		ball.freeze=true
		ball.global_position=Vector3(0,FootballBall.RADIUS,0)
		ball.linear_velocity=Vector3.ZERO
		ball.angular_velocity=Vector3.ZERO
		ball.last_touch=&"none"
		ball.last_action=&"none"
		ball._dribble_cooldowns.clear()
		await physics_frame
		ball.freeze=false
		var serial := ball.action_serial
		var order: Array=[teammate,player] if reverse_order else [player,teammate]
		for actor in order:
			ball.dribble_touch(actor,Vector3.RIGHT if actor==player else Vector3.LEFT,false,false,0.23,0.48,1.05)
		if ball.action_serial!=serial+1:
			_fail(game,"Two nearby teammates both claimed the same ball in one physics tick");return
		for frame in 2:await physics_frame
		if ball.linear_velocity.x<=0.05:
			_fail(game,"The farther teammate overrode the nearer actor's dribble assistance");return
	ball.freeze=true
	ball.global_position=player.global_position+Vector3(0.5,FootballBall.RADIUS,0)
	ball.linear_velocity=Vector3.ZERO
	ball.kick(Vector3.RIGHT,12,0,&"pass",player.team_name)
	var pass_serial := ball.action_serial
	if ball.dribble_touch(player,Vector3.RIGHT,false,false,0.23,0.48,1.05) \
			or ball.action_serial!=pass_serial or ball.last_action!=&"pass":
		_fail(game,"Dribble assistance reclaimed a pass before its release window ended");return
	for frame in 9:await physics_frame
	ball.freeze=true
	ball.global_position=player.global_position+Vector3(0.5,1.2,0)
	ball.last_touch=&"none"
	ball._dribble_cooldowns.clear()
	if ball.dribble_touch(player,Vector3.RIGHT,false,false,0.23,0.48,1.05):
		_fail(game,"Ground dribble assistance claimed an airborne ball above foot reach");return
	var visual := player.get_node("Visual") as FootballerVisual
	visual.animation_player.stop()
	visual._active_action=&""
	visual.animation_tree.active=true
	if not visual.play_turn(true) or not visual.play_pass():
		_fail(game,"A harmless turn recovery blocked a buffered pass action");return
	if visual._active_action!=&"pass":
		_fail(game,"Pass did not take priority over the turn recovery");return
	print("Turn/dribble control PASS: weighted reversals for human and AI, nearest-actor ownership, no competing force or airborne foot claim")
	game.free()
	quit(0)
