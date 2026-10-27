extends SceneTree
## Actual arena crowd at three detail distances and at live event states.
var options:Dictionary={}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair:=argument.substr(2).split("=",true,1)
			options[pair[0]]=pair[1]
	call_deferred("_capture")

func _capture() -> void:
	assert(RenderingServer.get_current_rendering_method()=="forward_plus")
	var output:String=str(options["capture-dir"])
	DirAccess.make_dir_recursive_absolute(output)
	var session:=root.get_node("MatchSession")
	session.launched_from_menu=false;session.venue_id=&"rovers_arena";session.camera_preset=&"close_broadcast"
	var game:=load("res://scenes/match_11v11.tscn").instantiate() as Node3D
	root.add_child(game);current_scene=game
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	game.get_node("HUD").hide()
	var rig:=game.get_node("BroadcastCamera");rig.set_process(false)
	var camera:=rig.get_node("Camera3D") as Camera3D
	var crowd:=game.find_child("AnimatedSupporters",true,false) as FootballSupporterCrowd
	await process_frame
	var away_index:=-1;var home_index:=-1
	for i in crowd.flags.size():
		if away_index<0 and crowd.flags[i].support_side=="away":away_index=i
		if home_index<0 and crowd.flags[i].support_side=="home" and crowd.flags[i].bank=="South":home_index=i
	assert(away_index>=0 and home_index>=0)
	var frames:Array=[]
	frames.append(await _shot(crowd,camera,crowd.flags[away_index],away_index,3.5,"match_broadcast",output))
	game.events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT,&"shot",game._home_players[0],Vector3(40,1,0),25)
	crowd._process(1.0)
	frames.append(await _shot(crowd,camera,crowd.flags[away_index],away_index,35.0,"crowd_mid_chance",output))
	game._away_score+=1
	game.events.emit_event(FootballMatchEvent.Kind.GOAL,&"Boardeaux",game._home_players[0],Vector3(-53,1,0))
	crowd._process(1.6)
	frames.append(await _shot(crowd,camera,crowd.flags[away_index],away_index,3.5,"crowd_away_goal_close",output))
	frames.append(await _shot(crowd,camera,crowd.flags[away_index],away_index,85.0,"crowd_away_goal_far",output))
	game._home_score+=1
	game.events.emit_event(FootballMatchEvent.Kind.GOAL,&"Beechlawn Rovers",game._away_players[0],Vector3(53,1,0))
	crowd._process(1.6)
	frames.append(await _shot(crowd,camera,crowd.flags[home_index],home_index,3.5,"crowd_home_goal_close",output))
	var report:Dictionary={
		"rendering_method":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_video_adapter_api_version(),
		"display_server":DisplayServer.get_name(),"godot":Engine.get_version_info().string,
		"resolution":[root.get_texture().get_image().get_width(),root.get_texture().get_image().get_height()],
		"scene":"res://scenes/match_11v11.tscn","venue":"rovers_arena","venue_view":"crowd_motion",
		"home_players":game._home_players.size(),"away_players":game._away_players.size(),"officials":get_nodes_in_group("match_officials").size(),
		"draw_calls":frames[0].draw_calls,"primitives":frames[0].primitives,"frames":frames,
		"scope":"Actual Forward+ body/flag and LOD motion; Linux software Vulkan does not establish Mac performance."
	}
	assert(report.home_players==11 and report.away_players==11 and report.officials==1)
	var file:=FileAccess.open(output.path_join("match_broadcast.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	print("BEECHLAWN_NATIVE_CAPTURE ",JSON.stringify(report))
	quit()

func _shot(crowd:FootballSupporterCrowd,camera:Camera3D,record:Dictionary,flag_index:int,distance:float,label:String,output:String) -> Dictionary:
	var target:Vector3=crowd.to_global(record.pose.origin+Vector3(0,1.1,0))
	var front:Vector3=record.pose.basis.z.normalized()
	camera.global_position=crowd.to_global(record.pose.origin+front*distance+Vector3(0,1.5+distance*.04,0))
	camera.look_at(target);camera.fov=52.0 if distance>24 else 48.0
	camera.reset_physics_interpolation()
	crowd._selection_time=1.0;crowd._process(.02)
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	assert(image.save_png(output.path_join(label+".png"))==OK)
	crowd._update_flags()
	var gap:=_flag_hand_gap(crowd,flag_index)
	assert(gap<.05,"Native flag pole must track its animated hand")
	return {"image":label+".png","distance":distance,"flag_hand_gap":gap,
		"flag_bearer_promoted":crowd.active_heroes.has(record.id),"body_state":crowd.states[record.role].to,
		"home_state":crowd.states.home.to,"away_state":crowd.states.away.to,
		"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}

func _flag_hand_gap(crowd:FootballSupporterCrowd,index:int) -> float:
	var record:Dictionary=crowd.flags[index];var state:Dictionary=crowd.states[record.role];var custom:Color=record.custom
	var delay:=custom.g*.65;var phase:=custom.r*2.6
	var blend:=smoothstep(0,.55,crowd.clock-float(state.at)-delay)
	var a:=FootballSupporterAssets.hand(record.avatar,state.from,crowd.clock-float(state.from_time)-delay+(0 if state.from in ["Rise","Sit"] else phase))
	var b:=FootballSupporterAssets.hand(record.avatar,state.to,crowd.clock-float(state.to_time)-delay+(0 if state.to in ["Rise","Sit"] else phase))
	var expected:Vector3=record.pose*a.lerp(b,blend)
	var pole:=crowd._flag_poles.get_instance_transform(index)
	var actual:Vector3=pole.origin-pole.basis*Vector3(0,.5,0)
	return actual.distance_to(expected)
