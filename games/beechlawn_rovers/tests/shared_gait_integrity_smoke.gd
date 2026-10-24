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
	var footwork := (load("res://assets/characters/shared/stride_gaits.glb") as PackedScene).instantiate()
	var authored := footwork.get_node("AnimationPlayer") as AnimationPlayer
	for name in [&"AN_Beechlawn_Walk",&"AN_Beechlawn_SlowJog",&"AN_Beechlawn_Jog",&"AN_Beechlawn_Sprint",&"AN_Beechlawn_CloseControl",&"AN_Beechlawn_WarmupJog"]:
		var motion := visual.animation_player.get_animation(name)
		var baseline := original.get_animation(name) if name==&"AN_Beechlawn_WarmupJog" else authored.get_animation(StringName(String(name)+"_Footwork"))
		for index in baseline.get_track_count():
			var path := baseline.track_get_path(index)
			if "Leg" not in String(path) and "Foot" not in String(path) and "Toe" not in String(path) and "Hips" not in String(path): continue
			var current := motion.find_track(path,baseline.track_get_type(index))
			assert(current >= 0 and motion.track_get_key_count(current)==baseline.track_get_key_count(index), "Install authored footwork; preserve unrelated warmup leg/root keys")
			for key in baseline.track_get_key_count(index):
				assert(motion.track_get_key_value(current,key)==baseline.track_get_key_value(index,key),"Runtime gait differs from its authored footwork")
			tracks+=1
		visual.animation_tree.active=false
		visual.animation_player.play(name,0)
		for tick in 8:
			visual.animation_player.seek(float(tick)*motion.length/8,true)
			for hand in visual.hand_positions():
				var limit:=.15 if name==&"AN_Beechlawn_Walk" else .025
				assert(actor.to_local(hand).z < limit, "Excessive wrist backswing: %s pose %d hand %s"%[name,tick,str(actor.to_local(hand))])
	print("GAIT_INTEGRITY authored/preserved leg/root tracks=",tracks)
	footwork.free();source.free();game.free();quit()
