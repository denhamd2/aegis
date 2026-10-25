extends SceneTree
## Actual Forward+ production review; stills do not establish target frame rate.
var output:="/tmp/stadium-production"
var group:="architecture"
var isolate_no_crowd:=false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):output=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--group="):group=arg.trim_prefix("--group=")
		if arg=="--isolate-no-crowd":isolate_no_crowd=true
	call_deferred("_run")
func _run() -> void:
	assert(RenderingServer.get_current_rendering_method()=="forward_plus")
	var session:=root.get_node("MatchSession");session.venue_id=&"rovers_arena";session.mode=1;session.launched_from_menu=true;session.show_intro=true
	var game:Node3D=(load("res://scenes/match_11v11.tscn") as PackedScene).instantiate();root.add_child(game);current_scene=game
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	var director:Node=game._pre_match;director.set_process(false)
	var crowd:=game.find_child("AnimatedSupporters",true,false) as FootballSupporterCrowd
	crowd.set_process(false);crowd._bind()
	if isolate_no_crowd:crowd.hide()
	game.get_node("HUD").hide()
	DirAccess.make_dir_recursive_absolute(output)
	var ids:Array=["stadium_waterfront","stadium_facade","stadium_bowl","montage_goal"]
	if group=="tifo":ids=["stadium_tifo_unfurl_start","stadium_tifo_unfurl_half","stadium_tifo_unfurl","stadium_tifo_close","stadium_tifo_angle"]
	if group=="single":ids=["stadium_waterfront"]
	if group=="crowd":ids=["stadium_crowd_seated","stadium_crowd_attention","stadium_crowd_rise","stadium_crowd_cheer"]
	var report:Array=[]
	for id:String in ids:
		print("PRODUCTION_REVIEW_BEGIN ",id)
		var base:=id
		if id.begins_with("stadium_crowd_"):base="stadium_crowd"
		if id.begins_with("stadium_tifo_unfurl_"):base="stadium_tifo_unfurl"
		for i in director.shots.size():
			if director.shots[i].id==base:director._enter_shot(i);break
		var at:=float(director.shots[director.shot_index].duration)*.5
		if id=="stadium_tifo_unfurl_start":at=.1
		if id=="stadium_tifo_unfurl_half":at=3.4
		if id=="stadium_tifo_unfurl":at=6.8
		if id.begins_with("stadium_crowd_"):
			var state:="Seated" if id.ends_with("seated") else "Attention" if id.ends_with("attention") else "Rise" if id.ends_with("rise") else "Cheer"
			for role in FootballSupporterCrowd.ROLES:crowd._set_state(role,state,100)
			crowd.clock+=.38 if state=="Rise" else 1.8
		print("PRODUCTION_REVIEW_ENTERED ",id)
		director._update_shot(at);print("PRODUCTION_REVIEW_CAMERA ",id)
		crowd._selection_time=1;crowd._process(0);print("PRODUCTION_REVIEW_CROWD ",id)
		for frame in 3:
			await RenderingServer.frame_post_draw
			print("PRODUCTION_REVIEW_DRAW ",id," ",frame)
		var name:=id+".png";assert(root.get_texture().get_image().save_png(output.path_join(name))==OK)
		report.append({"image":name,"camera":str(director.camera.global_position),"attendance":crowd.attendance,"active_hero_fans":crowd.active_heroes.size(),"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
		print("STADIUM_PRODUCTION_SAVED ",id)
	var file:=FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"resolution":str(DisplayServer.window_get_size()),"views":report,"diagnostic_no_crowd":isolate_no_crowd,"scope":"Actual Forward+ assets; Linux software adapter; Mac graphics/timing acceptance pending"},"  "));file.close()
	game.free();await process_frame
	print("STADIUM_PRODUCTION_COMPLETE ",group)
	quit()
