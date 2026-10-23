extends Node
## Original audio only. Music is confined to menus and the pre-match intro.
const VOICE_LIMIT := 12
var music: AudioStreamPlayer
var crowd: AudioStreamPlayer
var rain: AudioStreamPlayer
var voices: Array[AudioStreamPlayer3D] = []
var ui_voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var game: Node3D
var _step_times: Dictionary = {}
var _cooldowns: Dictionary = {}
var _tick := 0.0
var event_count := 0
func _ready() -> void:
	for name in ["Music","Match","UI"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,name)
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1
	limiter.threshold_db = -3
	AudioServer.add_bus_effect(0,limiter)
	for name in ["pass","kick","header","post","net","step","whistle","ui","crowd","cheer","rain","menu_music"]:
		streams[name] = load("res://assets/audio/"+name+".wav")
	for index in 4:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"UI"; voice.stream = streams.ui; voice.volume_db = -7
		add_child(voice); ui_voices.append(voice)
	music = _loop("menu_music","Music",-7)
	crowd = _loop("crowd","Match",-15)
	rain = _loop("rain","Match",-9)
	for index in VOICE_LIMIT:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = &"Match"; voice.max_distance = 55; voice.unit_size = 10
		add_child(voice); voices.append(voice)
func _loop(name: String, bus: String, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := streams[name].duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0; stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	player.stream = stream; player.bus = StringName(bus); player.volume_db = volume
	add_child(player)
	return player
func set_music(enabled: bool) -> void:
	if enabled and not music.playing: music.play()
	elif not enabled: music.stop()
func bind_match(match_scene: Node3D, events: FootballMatchEvents) -> void:
	game = match_scene
	_step_times.clear(); _cooldowns.clear()
	events.occurred.connect(_on_event)
	crowd.play()
	if MatchSession.weather_preset == &"rain": rain.play()
	else: rain.stop()
	set_music(false)
func stop_match() -> void:
	game = null; crowd.stop(); rain.stop()
	for voice in voices: voice.stop()
func play_ui() -> void:
	for player in ui_voices:
		if not player.playing: player.play(); return
func sound(name: String, at: Vector3, volume := 0.0) -> bool:
	var now := Time.get_ticks_msec()
	if now < int(_cooldowns.get(name,0)): return false
	_cooldowns[name] = now + (140 if name=="step" else 70)
	for voice in voices:
		if voice.playing: continue
		voice.stream = streams[name]; voice.global_position = at; voice.volume_db = volume
		voice.pitch_scale = 1.0 + sin(float(event_count)*1.71)*.04
		voice.play(); event_count+=1; return true
	return false
func _on_event(event: FootballMatchEvent) -> void:
	match event.kind:
		FootballMatchEvent.Kind.GOAL: sound("cheer",event.position,-2)
		FootballMatchEvent.Kind.RESTART,FootballMatchEvent.Kind.FOUL,FootballMatchEvent.Kind.FULL_TIME:
			sound("whistle",event.position,-6)
		FootballMatchEvent.Kind.POST: sound("post",event.position,-2)
		FootballMatchEvent.Kind.NET: sound("net",event.position,-4)
		FootballMatchEvent.Kind.BALL_CONTACT:
			if event.action == &"net": return
			if event.action in [&"dribble", &"first_touch"]: sound("pass",event.position,-18)
			elif event.action in [&"goalkeeper_save", &"goalkeeper_catch"]: sound("pass",event.position,-7)
			elif is_instance_valid(game) and game.ball.last_strike_part == &"head": sound("header",event.position,-3)
			else: sound("kick" if event.speed > 15 else "pass",event.position,-3)
func _process(delta: float) -> void:
	if not is_instance_valid(game):
		if crowd.playing: stop_match()
		return
	if game._intro_active or game._full_time or game._kickoff_pending or game._goal_pause_timer > 0 or game.restart.active(): return
	_tick += delta
	if _tick < .08: return
	var elapsed := _tick; _tick = 0
	for actor: FootballPlayer in game._home_players+game._away_players:
		var speed := Vector2(actor.velocity.x,actor.velocity.z).length()
		if speed < 1 or not actor.visible or actor.position.distance_to(game.camera_rig.camera.global_position)>26: continue
		var id := actor.get_instance_id()
		_step_times[id] = float(_step_times.get(id,0.0)) - elapsed
		if _step_times[id] <= 0:
			_step_times[id] = lerpf(.47,.25,clampf(speed/9,0,1))
			sound("step",actor.position,-9)
