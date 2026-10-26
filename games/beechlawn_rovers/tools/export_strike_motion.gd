extends SceneTree
## Read-only production capture of the shipping right-foot action evaluation.
func _initialize() -> void: call_deferred("_run")
func matrix_values(t: Transform3D) -> Array:
	return [t.basis.x.x,t.basis.x.y,t.basis.x.z,t.basis.y.x,t.basis.y.y,t.basis.y.z,t.basis.z.x,t.basis.z.y,t.basis.z.z,t.origin.x,t.origin.y,t.origin.z]
func _run() -> void:
	var game=load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game);await process_frame
	game.set_process(false);game.set_physics_process(false);game._set_players_physics_enabled(false)
	var actor: FootballPlayer=game._home_players[2]
	actor.position=Vector3.ZERO;actor.rotation=Vector3.ZERO
	var visual:=actor._footballer_visual
	var skeleton:=visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var frame:=actor.global_transform.affine_inverse()*skeleton.global_transform
	var report:={"fps":60,"coordinates":"Godot actor local; +X right,+Y up,-Z forward","rest":{},"clips":{},"sources":{}}
	for path in ["res://assets/characters/shared/footballer_base.glb","res://assets/characters/shared/advanced_actions.glb"]: report.sources[path]=FileAccess.get_sha256(path)
	for index in skeleton.get_bone_count(): report.rest[skeleton.get_bone_name(index)]=matrix_values(frame*skeleton.get_bone_global_rest(index))
	for action: StringName in [&"pass",&"shot",&"volley",&"half_volley"]:
		actor.reset_for_stoppage()
		if action==&"pass":visual.play_pass()
		elif action==&"shot":visual.play_shot()
		else:visual.play_aerial(action)
		visual.animation_player.play(visual._active_clip,0)
		var length:=visual.animation_player.get_animation(visual._active_clip).length
		var samples:Array=[]
		for tick in roundi(length*60)+1:
			visual.animation_player.seek(minf(tick/60.0,length-.000001),true,true)
			var sample:={}
			for index in skeleton.get_bone_count(): sample[skeleton.get_bone_name(index)]=matrix_values(frame*skeleton.get_bone_global_pose(index))
			samples.append(sample)
		report.clips[action]={"name":visual._active_clip,"duration":length,"samples":samples}
	var file:=FileAccess.open("res://docs/art_briefs/left_foot_ai_2026_10_25/runtime_right_motion.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report));file.close()
	game.free();print("SHIPPING_RIGHT_MOTION_EXPORTED 4 clips at60Hz; source poses only, original assets unchanged");quit()
