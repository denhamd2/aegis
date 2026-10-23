extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var audio := root.get_node("GameAudio")
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	var detail: PitchGrassDetail = game.grass_detail
	assert(detail != null)
	assert(detail.tuft.get_aabb().size.y<=.025 and detail.CELL==.75,"Short dense turf replaces tall isolated tufts")
	detail._queue_cells(Vector3.ZERO)
	while not detail._pending.is_empty(): detail._build_cell(detail._pending.pop_front())
	assert(detail.chunks.size()<=16 and detail.tuft_count()>1000 and detail.tuft_count()<=40000)
	var checked := 0
	for chunk in detail.chunks.values():
		assert(chunk.find_children("*","CollisionShape3D",true,false).is_empty())
		var mm := chunk.multimesh as MultiMesh
		for index in range(0,mm.visible_instance_count,31):
			var at := mm.get_instance_transform(index).origin
			assert(absf(at.y-PitchSurface.height_at(at.x,at.z))<.003,"Terrain-aligned grass")
			assert(detail.surface.sample_at(at).y<=.15,"No blades in standing water")
			checked+=1
	var events: Array[FootballMatchEvent]=[]
	game.events.occurred.connect(func(event: FootballMatchEvent): events.append(event))
	var before: int = audio.event_count
	var event: FootballMatchEvent = game.events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT,&"shot",game.player,game.ball.position,25)
	assert(events.size()==1 and event.actor==game.player and event.score==Vector2i.ZERO)
	assert(event.serial>0 and event.match_seconds>=0)
	assert(audio.event_count>before,"Typed match event reaches real sound player")
	assert(audio.voices.size()==12 and audio.ui_voices.size()==4,"Bounded audio pools")
	for name in ["Music","Match","UI"]: assert(AudioServer.get_bus_index(name)>0)
	for stream in audio.streams.values(): assert(stream.get_length()>.05 and stream.data.size()>0)
	audio.set_music(false)
	assert(not audio.music.playing,"No music during match")
	audio.set_music(true)
	assert(audio.music.playing)
	audio.set_music(false)
	var session := root.get_node("MatchSession")
	session.music_volume=.25;session.match_volume=.55;session.ui_volume=.75
	assert(session.save_preferences("user://audio_smoke.cfg")==OK)
	session.music_volume=0;session.load_preferences("user://audio_smoke.cfg");session.apply_preferences()
	assert(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")),.25))
	DirAccess.remove_absolute("user://audio_smoke.cfg")
	audio.stop_match();game.free()
	print("PITCH_AUDIO PASS: tufts <=40k, terrain/water probes=",checked,", typed events, bounded real players, music policy and saved buses")
	quit()
