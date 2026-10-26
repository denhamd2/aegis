extends SceneTree
## Close with a playing stream through the real application window path,
## without calling stop_match() in the test and masking a missing cleanup hook.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var audio := root.get_node("GameAudio")
	audio.set_process(false)
	var mode := "park"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audio-probe="): mode = arg.trim_prefix("--audio-probe=")
	match mode:
		"park": audio.crowd.play()
		"stadium": audio.crowd.stream = audio._loop_stream("stadium_bed"); audio.crowd.play()
		"rain": audio.rain.play()
		"music": audio.set_music(true)
	for frame in 3: await process_frame
	assert(audio.music.playing if mode == "music" else audio.rain.playing if mode == "rain" else audio.crowd.playing)
	print("AUDIO_SHUTDOWN probe=", mode)
	root.close_requested.emit()
	assert(audio._quitting and not audio.sound("kick", Vector3.ZERO), "Contacts must stay silent while the close drains")
