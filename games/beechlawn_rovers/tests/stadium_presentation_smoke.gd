extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var session:=root.get_node("MatchSession");session.venue_id=&"rovers_arena";session.launched_from_menu=true;session.show_intro=true
	var game:Node3D=load("res://scenes/match_11v11.tscn").instantiate();root.add_child(game);await process_frame
	var director:Node=game._pre_match
	var duration:=0.0
	for shot:Dictionary in director.shots:duration+=shot.duration
	assert(is_equal_approx(duration,93.0))
	assert(director.shots[0].id=="stadium_waterfront" and director.shots[3].id=="stadium_crowd")
	for i in director.shots.size():
		director._enter_shot(i);director._update_shot(float(director.shots[i].duration)*.5)
		assert(director.camera.global_transform.is_finite())
		assert(director._lower_third.visible==(director.shots[i].id in ["stadium_waterfront","lineup"]))
		if director.shots[i].id=="stadium_waterfront":
			assert(director.camera.far>=1500)
			var environment:Environment=game.get_node("WorldEnvironment").environment
			assert(environment.fog_mode==Environment.FOG_MODE_DEPTH and environment.fog_depth_begin>=450 and not environment.volumetric_fog_enabled)
	var tifo:=game.find_child("HomeEndTifo",true,false) as FootballStadiumTifo
	assert(tifo!=null and tifo.profile.quote=="\"I KNOW CATHY CAN BE A BITCH SOMETIMES\"")
	var ink:Texture2D=tifo.material.get_shader_parameter("print_texture")
	var image:=ink.get_image()
	if image.is_compressed():assert(image.decompress()==OK)
	assert(image.get_pixel(0,0).a<.01 and image.get_pixel(image.get_width()-1,0).a<.01,"Portrait needs a transparent silhouette surround")
	for i in director.shots.size():
		if director.shots[i].id=="stadium_tifo_unfurl":
			director._enter_shot(i);director._update_shot(0);assert(tifo.visible and tifo.reveal==0)
			director._update_shot(3.5);assert(tifo.reveal>.4 and tifo.reveal<.6)
			director._update_shot(7);assert(tifo.reveal==1)
	for end in [-1,1]:
		var impact:Dictionary=game._net_impacts[end]
		assert(impact.materials.size()==2,"Near rope and far net share impact state")
		game.set_net_presentation(end,.1,Vector3(.4,.8,-2.15),Vector3(0,0,-.3))
		for material:ShaderMaterial in impact.materials:
			assert(material.get_shader_parameter("impact_age")==.1)
			assert(material.get_shader_parameter("impact_vector")==Vector3(0,0,-.3))
	var remaining:float=game._remaining_time
	director._enter_shot(0)
	var unfolded_in_motion:=false
	for step in 500:
		if not director.active:break
		game._physics_process(.25);director._process(.25)
		if tifo.visible and tifo.reveal>.05 and tifo.reveal<.95:unfolded_in_motion=true
	assert(unfolded_in_motion and not director.active,"Actual timed intro must unfurl and complete")
	assert(is_equal_approx(game._remaining_time,remaining),"Presentation cannot consume match time")
	await process_frame
	assert(not game._intro_active and game._kickoff_pending and game.ball.freeze)
	assert(not tifo.visible and tifo.reveal==0,"Live play must not retain the tifo")
	var replay_director:Node=load("res://scripts/pre_match_director.gd").new()
	game._intro_active=true;game._pre_match=replay_director;game.add_child(replay_director);replay_director.start(game)
	for i in replay_director.shots.size():
		if replay_director.shots[i].id=="stadium_tifo_unfurl":replay_director._enter_shot(i);replay_director._update_shot(3.5);break
	assert(tifo.visible and tifo.reveal>.4 and tifo.reveal<.6)
	var skip:=InputEventKey.new();skip.keycode=KEY_ENTER;skip.pressed=true;game._unhandled_key_input(skip)
	assert(not game._intro_active and not tifo.visible and tifo.reveal==0,"Skipping a half-unfurled display clears it immediately")
	await process_frame
	game.free();await process_frame
	var original:=FootballMatchVenue.from_id(&"rovers_arena");var copy:=FootballMatchVenue.from_id(&"rovers_arena")
	copy.presentation.anchors["bowl"]=Vector3(1,2,3)
	assert(original.presentation.anchors.bowl!=Vector3(1,2,3),"Venue profile changes cannot leak between matches")
	assert(original.goal.stadium_box and original.goal.rear_poles.size()==2)
	assert(FootballMatchVenue.from_id(&"kilmore_drive").goal.model_path.contains("park_goal"))
	print("STADIUM_PRESENTATION PASS: 93s resource-driven opening, limited captions, skip isolation, dual net LODs, profile isolation")
	quit()
