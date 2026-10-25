extends SceneTree
## Run the exported app with --script res://scripts/benchmark_match.gd --
## --benchmark=/absolute/path/results.csv --benchmark-seconds=900.
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var output:="user://m1_benchmark.csv";var seconds:=900.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--benchmark="):output=arg.trim_prefix("--benchmark=")
		if arg.begins_with("--benchmark-seconds="):seconds=maxf(1,float(arg.trim_prefix("--benchmark-seconds=")))
	var session:=root.get_node("MatchSession")
	session.fullscreen=false;session.graphics_profile=&"balanced_60";session.apply_preferences();root.size=Vector2i(1920,1080)
	var profiler:=FootballFrameProfiler.new();root.add_child(profiler)
	profiler.begin(output,session.graphics,minf(30,seconds*.1))
	var elapsed:=0.0;var stage:=-1;var game:Node3D
	var started_usec:=Time.get_ticks_usec()
	var stress_at:=0.0;var stress_index:=0
	while elapsed<seconds:
		var next:=mini(4,int(elapsed/maxf(1,seconds/5)))
		if stage!=next:
			profiler.mark_loading()
			if is_instance_valid(game):game.free()
			stage=next
			session.venue_id=&"kilmore_drive" if stage==2 else &"rovers_arena"
			session.weather_preset=&"rain" if stage==1 else &"sunny"
			session.mode=1;session.launched_from_menu=true;session.show_intro=stage==3
			game=load("res://scenes/match_11v11.tscn").instantiate()
			root.add_child(game);current_scene=game
			print("BENCHMARK_STAGE ",stage," venue=",session.venue_id," weather=",session.weather_preset)
		if is_instance_valid(game) and stage==4 and elapsed>=stress_at and not game._intro_active:
			stress_at=elapsed+24;stress_index+=1
			if stress_index%2==1:
				game.events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT,&"shot",game._home_players[-1],Vector3(40,1,0),28)
			else:
				var crowd:=game.find_child("AnimatedSupporters",true,false) as FootballSupporterCrowd
				if crowd!=null:
					for role in FootballSupporterCrowd.ROLES:crowd._set_state(role,"Rise",1.5)
		await process_frame
		elapsed=float(Time.get_ticks_usec()-started_usec)/1000000.0
	var result:=profiler.finish()
	print("BENCHMARK_RESULT ",JSON.stringify(result))
	quit()
