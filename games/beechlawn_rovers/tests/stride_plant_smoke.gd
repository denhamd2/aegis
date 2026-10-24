extends SceneTree
## Actual shared human feet in world space during steady authoritative movement.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	Engine.time_scale=4
	Engine.physics_ticks_per_second=240
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var actor: FootballPlayer
	for candidate in game._home_players:
		if candidate.profile.player_id==&"shane_denham":actor=candidate
	assert(actor!=null)
	for other in game._home_players+game._away_players:other.position=Vector3(140,0,140)
	game.ball.release_for_restart()
	game.ball.freeze=true
	game.ball.position=Vector3(100,.2,100)
	var visual:=actor._footballer_visual
	var skeleton:=visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var report: Array[Dictionary]=[]
	var cases: Array[Dictionary]=[]
	for speed in [1.5,3.0,4.5,6.0,7.3,8.6]:cases.append({"speed":speed,"close":false})
	cases.append({"speed":3.36,"close":true})
	for scenario in cases:
		var speed: float=scenario.speed
		var close: bool=scenario.close
		actor.set_physics_process(false)
		actor.position=Vector3(-18,PitchSurface.height_at(-18,0)+.005,0)
		actor.rotation.y=-PI/2
		actor.reset_for_stoppage()
		actor.controlled_by_human=close
		actor.ai_move_direction=Vector3.RIGHT
		actor.ai_sprinting=speed>6.01
		# The real controller still moves the actor; the case changes only its
		# maximum pace to exercise calibrated steady speeds.
		var old_jog:=actor.tuning.jog_speed
		var old_sprint:=actor.tuning.sprint_speed
		actor.tuning=actor.tuning.duplicate()
		actor.tuning.jog_speed=6.0 if close else speed
		actor.tuning.sprint_speed=8.6 if close else speed
		if close:
			game.camera_rig.set_process(false)
			game.camera_rig.set_physics_process(false)
			actor.camera.global_transform=Transform3D(Basis.IDENTITY,actor.position+Vector3(0,4,10))
			game.ball.last_touch=actor.team_name
			Input.action_press("move_right")
			Input.action_press("close_control")
		actor.set_physics_process(true)
		var samples: Array[Dictionary]=[]
		for tick in 200:
			await physics_frame
			if tick<50:continue
			var feet: Dictionary={}
			for side in ["Left","Right"]:
				var point:=skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_"+side+"Toe_End")).origin)
				feet[side]={"world":[point.x,point.y,point.z],"height":point.y-PitchSurface.height_at(point.x,point.z)}
			samples.append({"tick":tick,"root":[actor.position.x,actor.position.y,actor.position.z],"speed":Vector2(actor.velocity.x,actor.velocity.z).length(),"feet":feet})
		actor.set_physics_process(false)
		Input.action_release("move_right")
		Input.action_release("close_control")
		actor.tuning.jog_speed=old_jog
		actor.tuning.sprint_speed=old_sprint
		var slips: Array[float]=[]
		var min_height:=INF
		var max_height:=-INF
		for side in ["Left","Right"]:
			var low:=INF
			for row in samples:low=minf(low,float(row.feet[side].height))
			min_height=minf(min_height,low)
			for i in range(1,samples.size()):
				var a: Array=samples[i-1].feet[side].world
				var b: Array=samples[i].feet[side].world
				var height: float=samples[i].feet[side].height
				max_height=maxf(max_height,height)
				if height<low+.035 and samples[i-1].feet[side].height<low+.035 and absf(float(b[1])-float(a[1]))*60<.20:
					slips.append(Vector2(float(b[0])-float(a[0]),float(b[2])-float(a[2])).length()*60)
		var mean:=0.
		for slip in slips:mean+=slip/maxi(1,slips.size())
		var result: Dictionary={"requested_speed":speed,"close_control":close,"mean_stance_slip_mps":mean,"stance_samples":slips.size(),"min_toe_height":min_height,"max_toe_height":max_height,"samples":samples}
		report.append(result)
		print("STRIDE_PLANT ",speed," stance_slip=",mean,"m/s stance_samples=",slips.size()," toe_height=",min_height,"..",max_height)
	var path:=OS.get_environment("BEECHLAWN_STRIDE_REPORT")
	if path!="":
		var file:=FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify({"cases":report},"  ")+"\n")
	var valid:=true
	for result in report:
		if result.stance_samples<12 or result.mean_stance_slip_mps>1.0 or result.min_toe_height<-.025:valid=false
	game.free()
	if not valid:
		push_error("Planted boots slide against the pitch; inspect STRIDE_PLANT")
		quit(1)
		return
	print("STRIDE_PLANT PASS")
	quit()
