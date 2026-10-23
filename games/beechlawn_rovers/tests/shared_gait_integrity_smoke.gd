extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	var actor: FootballPlayer = game.player
	var visual := actor.get_node("Visual") as FootballerVisual
	var source := (load("res://assets/characters/shared/footballer_base.glb") as PackedScene).instantiate()
	var original := source.get_node("AnimationPlayer") as AnimationPlayer
	var tracks := 0
	for name in [&"AN_Beechlawn_Jog",&"AN_Beechlawn_Sprint",&"AN_Beechlawn_WarmupJog"]:
		var motion := visual.animation_player.get_animation(name)
		var baseline := original.get_animation(name)
		for index in baseline.get_track_count():
			var path := baseline.track_get_path(index)
			if "Leg" not in String(path) and "Foot" not in String(path) and "Toe" not in String(path) and "Hips" not in String(path): continue
			var current := motion.find_track(path,baseline.track_get_type(index))
			assert(current >= 0 and motion.track_get_key_count(current)==baseline.track_get_key_count(index), "Preserve shipping leg/root keys")
			for key in baseline.track_get_key_count(index):
				assert(motion.track_get_key_value(current,key)==baseline.track_get_key_value(index,key),"Arm edit changed a leg/root key")
			tracks+=1
		visual.animation_tree.active=false
		visual.animation_player.play(name,0)
		for tick in 8:
			visual.animation_player.seek(float(tick)*motion.length/8,true)
			for hand in visual.hand_positions():
				assert(actor.to_local(hand).z < .025, "Running wrist swung behind torso")
	print("GAIT_INTEGRITY preserved leg/root tracks=",tracks)
	source.free();game.free();quit()
