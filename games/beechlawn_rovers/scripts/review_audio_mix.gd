extends SceneTree
## Movie Maker captures the real AudioServer mix, including a muted second half.
var output: String
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
	call_deferred("_run")
func _run() -> void:
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game);current_scene=game
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	var audio := root.get_node("GameAudio")
	audio.set_music(true)
	for frame in 120:
		if frame==20: audio.set_music(false)
		if frame in [24,30,36,42,48]:
			game.events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT,&"shot",game.player,game.ball.position,24)
		if frame==35: game.events.emit_event(FootballMatchEvent.Kind.FOUL,&"foul",game.player,game.ball.position)
		if frame==45: game.events.emit_event(FootballMatchEvent.Kind.NET,&"net",game.player,game.ball.position,18)
		if frame==52: game.events.emit_event(FootballMatchEvent.Kind.POST,&"post",game.player,game.ball.position,20)
		if frame==60:
			for bus in ["Music","Match","UI"]: AudioServer.set_bus_mute(AudioServer.get_bus_index(bus),true)
		if frame==90: audio.play_ui()
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png(output.path_join("match_broadcast.png"))==OK)
	var report := {"rendering_method":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),
		"display_server":DisplayServer.get_name(),"home_players":11,"away_players":11,"officials":1,"audio_events":audio.event_count,
		"movie_frames":120,"muted_from_frame":60,"scope":"Original AudioServer music/Foley with bus mute check; no native Mac performance claim"}
	var file := FileAccess.open(output.path_join("match_broadcast.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("BEECHLAWN_NATIVE_CAPTURE ",JSON.stringify(report))
	quit()
