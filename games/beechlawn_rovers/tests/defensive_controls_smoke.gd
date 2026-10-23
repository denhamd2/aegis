extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	game.ball.freeze = true
	var actor: FootballPlayer = game.player
	actor.position = Vector3.ZERO
	actor.rotation.y = -PI/2
	game.ball.position = Vector3(5,.12,0)
	game.ball.last_touch = &"Boardeaux"
	for action in ["contain", "teammate_pressure", "close_control", "tackle"]:
		assert(InputMap.has_action(action))
	Input.action_press("contain")
	actor._sample_input()
	actor._update_locomotion(.2)
	assert(actor.velocity.x > 0 and Vector2(actor.velocity.x,actor.velocity.z).length() < 4, "Contain approaches at controlled speed")
	Input.action_release("contain")
	var helper: FootballPlayer = game._home_players[2]
	helper.position = Vector3(3,0,0)
	Input.action_press("teammate_pressure")
	game._update_teammate_pressure()
	assert(helper.ai_move_direction.x > .8, "One nearby helper closes down")
	assert(game.player == actor and actor.controlled_by_human, "Teammate pressure preserves independent control")
	Input.action_release("teammate_pressure")
	var visual := actor.get_node("Visual") as FootballerVisual
	for clip in ["KeeperCatch","KeeperLowCenter","KeeperLowLeft","KeeperLowRight","KeeperDiveLeft","KeeperDiveRight","KeeperHigh"]:
		assert(visual.animation_player.has_animation("AN_Beechlawn_"+clip))
		visual.play_keeper_save(StringName(clip))
		visual.animation_player.advance(.25)
		assert(visual.hand_positions().size()==2)
		for hand in visual.hand_positions(): assert(hand.is_finite())
	game.free()
	print("DEFENSIVE_CONTROLS PASS: contain, helper, independent selection, seven shared keeper poses")
	quit()
