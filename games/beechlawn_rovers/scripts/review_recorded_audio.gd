extends SceneTree
## Small native AudioServer fixture. Full-match wiring has its own smoke test;
## this deliberately avoids compiling unrelated player/stadium shaders.
class AudioBall extends Node3D:
	var last_strike_part: StringName = &"foot"
class AudioRestart extends RefCounted:
	func active() -> bool: return false
class AudioMatch extends Node3D:
	var venue := {"id": &"kilmore_drive"}
	var ball := AudioBall.new()
	var presentation = null
	var restart := AudioRestart.new()
	var _intro_active := false
	var _presentation_active := false
	var _full_time := false
	var _kickoff_pending := false
	var _goal_pause_timer := 0.0
	var _home_players: Array[FootballPlayer] = []
	var _away_players: Array[FootballPlayer] = []
	var short_match_seconds := 180.0
	var _remaining_time := 180.0
	var _home_score := 0
	var _away_score := 0
var output := ""
var venue := &"kilmore_drive"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--venue="): venue = StringName(arg.trim_prefix("--venue="))
	call_deferred("_run")
func _run() -> void:
	var audio := root.get_node("GameAudio")
	var session := root.get_node("MatchSession")
	session.master_volume = .8; session.match_volume = .8; session.apply_preferences()
	session.weather_preset = &"rain" if venue == &"rovers_arena" else &"sunny"
	var game := AudioMatch.new()
	game.venue.id = venue
	root.add_child(game); game.add_child(game.ball)
	var camera := Camera3D.new()
	game.add_child(camera); camera.position = Vector3(0, 18, 26); camera.look_at(Vector3.ZERO); camera.make_current()
	var events := FootballMatchEvents.new()
	game.add_child(events); events.game = game
	audio.bind_match(game, events)
	for frame in 1500:
		if frame == 120: camera.position = Vector3(0, 2, 5); camera.look_at(Vector3.ZERO)
		if frame == 210: camera.position = Vector3(0, 18, 26); camera.look_at(Vector3.ZERO)
		if frame in [45, 90, 135]:
			game.ball.last_strike_part = &"head" if frame == 135 else &"foot"
			events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT, &"shot" if frame > 45 else &"pass", null, Vector3.ZERO, 24 if frame > 45 else 10)
		if frame == 180: events.emit_event(FootballMatchEvent.Kind.BALL_CONTACT, &"goalkeeper_save", null, Vector3.ZERO, 18)
		if frame == 240: events.emit_event(FootballMatchEvent.Kind.FOUL, &"foul", null, Vector3.ZERO)
		if frame == 300: events.emit_event(FootballMatchEvent.Kind.NET, &"net", null, Vector3.ZERO, 18)
		if frame == 330: events.emit_event(FootballMatchEvent.Kind.POST, &"post", null, Vector3.ZERO, 22)
		if frame == 420: events.emit_event(FootballMatchEvent.Kind.GOAL, &"Beechlawn Rovers", null, Vector3.ZERO)
		if frame == 1080:
			# Deliberately end the goal excerpt to expose an isolated chant in
			# this review clip; the live game uses the full recorded reaction.
			audio.reaction.stop(); audio._reaction_until = 0; audio._start_chant()
		if frame == 1380: events.emit_event(FootballMatchEvent.Kind.FULL_TIME, &"full_time", null, Vector3.ZERO)
		if frame == 1450:
			for bus in ["Music", "Match", "UI"]: AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), true)
			audio.play_ui()
		await RenderingServer.frame_post_draw
	var report := {"venue":venue, "rendering_method":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(), "display_server":DisplayServer.get_name(),
		"audio_events":audio.event_count, "crowd_events":audio.crowd_event_count, "chants":audio.chant_count,
		"frames":1500, "fps":60, "mute_from_seconds":1450.0/60,
		"listener":"Broadcast 31.6m; close-up 5.4m from 2.0 to 3.5s",
		"scope":"Native Forward+ / real AudioServer mix in a minimal 3D listening fixture; no subjective listening or M1 performance claim"}
	var file := FileAccess.open(output.path_join("audio_fixture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ")); file.close()
	audio.stop_match(); game.free()
	print("BEECHLAWN_NATIVE_CAPTURE ", JSON.stringify(report))
	quit()
