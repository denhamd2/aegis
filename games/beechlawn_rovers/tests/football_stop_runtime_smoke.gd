extends SceneTree
## Verifies that releasing movement in the match triggers and can cancel the stop clip.

const MATCH_SCENE := "res://scenes/training_ground.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MATCH_SCENE) as PackedScene
	assert(packed != null, "Could not load the 4v4 match scene")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.set("_kickoff_pending", false)
	game.call("_set_players_physics_enabled", true)
	var player := game.get_node("Player") as FootballPlayer
	var visual := player.get_node("Visual") as FootballerVisual
	player.controlled_by_human = true
	player.velocity = Vector3(0.0, 0.0, 3.0)
	for frame in 3:
		await physics_frame
	if visual.animation_player.current_animation != "AN_Beechlawn_StopFromRun":
		push_error("Stop clip did not start: animation=%s speed=%.3f braking=%s active=%s" % [
			visual.animation_player.current_animation,
			float(player.get_meta("move_speed", -1.0)),
			str(player.get_meta("braking", false)), str(player.is_physics_processing())])
		quit(1)
		return
	player.controlled_by_human = false
	player.ai_move_direction = Vector3(0.0, 0.0, -1.0)
	for frame in 8:
		await physics_frame
		if visual.animation_tree.active and visual._active_action == &"":
			player.ai_move_direction = Vector3.RIGHT
			player.velocity = Vector3(3.0, 0.0, 0.0)
			for settle_frame in 2:
				await physics_frame
			player.ai_move_direction = Vector3(0.0, 0.0, -1.0)
			await physics_frame
			if visual.animation_player.current_animation != "AN_Beechlawn_Turn90Left" \
					and visual.animation_player.current_animation != "AN_Beechlawn_Turn90Right":
				push_error("Sharp in-motion direction change did not start a turn clip: %s" % visual.animation_player.current_animation)
				quit(1)
				return
			print("Beechlawn match actor: braking/resume and sharp in-motion direction change trigger their authored clips")
			quit(0)
			return
	push_error("Renewed movement did not return the match actor to locomotion")
	quit(1)
