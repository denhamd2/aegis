extends SceneTree
## Compare complete imported clips and both actors' independent playback.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false);game.set_physics_process(false);game._set_players_physics_enabled(false)
	var right: FootballPlayer = game._home_players[2]
	var left: FootballPlayer = game._away_players[2]
	for actor in [right,left]: actor.position=Vector3(0,0,90);actor.rotation=Vector3.ZERO
	var vr:=right._footballer_visual
	var vl:=left._footballer_visual
	var sr:=vr.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var sl:=vl.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var maximum:=0.0
	for action: StringName in [&"pass",&"shot",&"volley",&"half_volley"]:
		right.reset_for_stoppage();left.reset_for_stoppage()
		if action==&"pass": assert(vr.play_pass() and vl.play_pass(1,&"left"))
		elif action==&"shot": assert(vr.play_shot() and vl.play_shot(1,&"left"))
		else: assert(vr.play_aerial(action) and vl.play_aerial(action,1,&"left"))
		vr.animation_player.play(vr._active_clip,0)
		vl.animation_player.play(vl._active_clip,0)
		var rclip:=vr.animation_player.get_animation(vr._active_clip)
		var lclip:=vl.animation_player.get_animation(vl._active_clip)
		assert(absf(rclip.length-lclip.length)<.00001,"Bilateral duration preserved")
		var markers:=0
		for track in lclip.get_track_count():
			if lclip.track_get_type(track)==Animation.TYPE_METHOD:
				markers+=lclip.track_get_key_count(track)
		assert(markers==1,"Exactly one authored marker")
		for frame in range(0,roundi(rclip.length*60)+1,2):
			var time:=minf(frame/60.0,rclip.length-.00001)
			vr.animation_player.seek(time,true,true);vl.animation_player.seek(time,true,true)
			for index in sr.get_bone_count():
				var name:=String(sr.get_bone_name(index)).replace("Left","TEMP").replace("Right","Left").replace("TEMP","Right")
				var other:=sl.find_bone(name)
				assert(other>=0)
				var rp:=right.to_local(sr.global_transform*sr.get_bone_global_pose(index).origin)
				var lp:=left.to_local(sl.global_transform*sl.get_bone_global_pose(other).origin)
				rp.x=-rp.x
				var error:=rp.distance_to(lp)
				maximum=maxf(maximum,error)
		assert(vl.strike_foot()==&"left" and vr.strike_foot()==&"right")
		print("LEFT_STRIKE_IMPORT ",action," max_mirrored_joint_error_m=",maximum)
	assert(maximum<.003,"Full imported pose mirrors live right action within 3 mm")
	assert(right.select_strike_foot(right.position+Vector3(-.14,0,-.6))==&"left")
	assert(right.select_strike_foot(right.position+Vector3(.14,0,-.6))==&"right")
	assert(right.select_strike_foot(right.position+Vector3(.001,0,-.6))==&"right","Stable centre tie-break")
	game.free()
	print("LEFT_STRIKES PASS: full-clip symmetry, marker timing, independent actions and contextual selection")
	quit()
