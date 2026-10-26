extends SceneTree
## Actual match event wiring, cue priority and venue isolation (not listening QA).
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var audio := root.get_node("GameAudio")
	var session := root.get_node("MatchSession")
	session.launched_from_menu = false
	audio.set_process(false)
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/provenance.json"))
	assert(provenance.recorded_sources.size() == 13 and provenance.recorded_clips.size() == 20)
	assert(provenance.original_effects.clips.size() == 1 and provenance.original_effects.clips[0].file == "ui.wav")
	for clip in provenance.recorded_clips:
		assert(clip.seconds > .05 and clip.peak < .95 and clip.rms > .001)
	for venue in [&"kilmore_drive", &"rovers_arena"]:
		session.venue_id = venue
		session.weather_preset = &"rain" if venue == &"rovers_arena" else &"sunny"
		var game = load("res://scenes/match_11v11.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.set_physics_process(false); game._set_players_physics_enabled(false)
		assert(audio.crowd.playing and not audio.music.playing)
		assert(audio.rain.playing == (venue == &"rovers_arena"))
		var bed: String = "stadium_bed" if venue == &"rovers_arena" else "park_bed"
		assert(is_equal_approx(audio.crowd.stream.get_length(), audio.streams[bed].get_length()))
		assert(audio.crowd.stream.loop and audio.crowd.stream.get_length() > 20)
		# Exercise the actual ball signal and restart controller, including its
		# production action spelling, rather than only fabricated events.
		game.ball.kick(Vector3.RIGHT, 24, 1, &"shot", &"Beechlawn Rovers", game.player)
		var after_kick: int = audio.event_count
		game.restart.begin("CORNER RESTART", &"Beechlawn Rovers", Vector3(52,0,33))
		assert(audio.last_reaction == "chance" and audio.event_count == after_kick, "Real corner-after-shot produces crowd reaction without a whistle")
		game.restart.cancel()
		game._set_players_physics_enabled(false)
		audio.bind_match(game, game.events)
		var before_ball: Transform3D = game.ball.transform
		var before_velocity: Vector3 = game.ball.linear_velocity
		var before_score := Vector2i(game._home_score, game._away_score)
		var before_time: float = game._remaining_time
		var before: int = audio.event_count
		var event: FootballMatchEvent = game.events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT, &"shot", game.player, Vector3.ZERO, 25)
		assert(audio.event_count == before+1 and audio.last_cue == "kick")
		assert(not audio.sound("kick", Vector3.ZERO), "Contact cooldown prevents machine-gun repeats")
		audio._advance_layers(.08, false)
		game.events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT, &"shot", game.player, Vector3.ZERO, 25)
		assert(audio.last_cue == "kick_alt", "Successive strikes use separate recordings")
		before = audio.event_count
		audio._on_event(event)
		assert(audio.event_count == before, "Repeated/out-of-order event cannot duplicate audio")
		game.ball.last_strike_part = &"head"
		game.events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT, &"shot", game.player, Vector3.ZERO, 19)
		assert(audio.last_cue == "header")
		game.events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT, &"goalkeeper_save", game.player, Vector3.ZERO, 18)
		assert(audio.last_cue == "catch" and audio.last_reaction == "save")
		var reactions: int = audio.crowd_event_count
		game.events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT, &"goalkeeper_save", game.player, Vector3.ZERO, 18)
		assert(audio.crowd_event_count == reactions, "Save cooldown prevents overlapping crowd loops")
		game.events.emit_event(FootballMatchEvent.Kind.POST, &"post", game.player, Vector3.ZERO, 22)
		assert(audio.last_cue == "post" and audio.last_reaction == "post", "Post preempts the quieter save reaction")
		game.events.emit_event(FootballMatchEvent.Kind.GOAL, &"Beechlawn Rovers", game._away_players[2], Vector3.ZERO)
		assert(audio.last_reaction == "goal" and audio.reaction.stream == audio.streams["stadium_goal" if venue == &"rovers_arena" else "park_goal"])
		assert(audio.reaction.volume_db == (0 if venue == &"rovers_arena" else -1), "Own goal uses awarded team, not last toucher")
		assert(audio.reaction.pitch_scale == 1 and audio.reaction is AudioStreamPlayer)
		reactions = audio.crowd_event_count
		game.presentation.phase = FootballMatchPresentation.Phase.REPLAY
		game.events.emit_event(FootballMatchEvent.Kind.GOAL, &"Beechlawn Rovers", game.player, Vector3.ZERO)
		assert(audio.crowd_event_count == reactions, "Replay must not score another audible goal")
		game.presentation.phase = FootballMatchPresentation.Phase.IDLE
		audio.reaction.stop(); audio._reaction_until = 0; audio._duck = 0
		audio._advance_layers(29, true)
		assert(audio.chant.playing == (venue == &"rovers_arena"), "Park must never receive a stadium chant")
		if venue == &"rovers_arena":
			audio._advance_layers(2, true)
			assert(audio.chant.volume_db > -14)
		game.events.emit_event(FootballMatchEvent.Kind.FOUL, &"foul", game.player, Vector3.ZERO)
		audio._advance_layers(.3, false)
		assert(audio.crowd.volume_db <= -13 and audio.chant.volume_db < -20, "Whistle ducks crowd and fades chant")
		for voice in audio.voices:
			voice.stream = audio.streams.stadium_goal; voice.set_meta("priority", 0); voice.play()
		audio._cooldowns.clear()
		assert(audio.sound("whistle", Vector3.ZERO), "Full footstep pool cannot drop a whistle")
		for voice in audio.voices: voice.set_meta("priority", 4)
		assert(not audio.sound("step", Vector3.ZERO), "Footsteps cannot steal important voices")
		game.events.emit_event(FootballMatchEvent.Kind.FULL_TIME, &"full_time", null, Vector3.ZERO)
		assert(audio.last_cue == "whistle_full" and not audio.chant.playing)
		before = audio.event_count
		game.events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT, &"shot", game.player, Vector3.ZERO, 25)
		assert(audio.event_count == before, "No match contacts after full time")
		assert(game.ball.transform == before_ball and game.ball.linear_velocity == before_velocity)
		assert(Vector2i(game._home_score, game._away_score) == before_score and game._remaining_time == before_time, "Audio cannot change score, clock or ball")
		audio.stop_match()
		assert(not audio.crowd.playing and not audio.rain.playing and not audio.reaction.playing and not audio.chant.playing)
		game.events.emit_event(FootballMatchEvent.Kind.GOAL, &"Boardeaux", game.player)
		assert(audio.event_count == before, "Old match is disconnected on return to menus")
		game.free()
	session.venue_id = &"kilmore_drive"; session.weather_preset = &"sunny"
	audio.set_process(true)
	print("RECORDED_AUDIO PASS: 20 recorded clips, two venue beds, event variants/cooldowns, own-goal/replay isolation, priority stealing, chant spacing, ducking, weather, full-time and clean teardown")
	quit()
