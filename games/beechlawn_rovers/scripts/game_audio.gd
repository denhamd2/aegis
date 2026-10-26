extends Node
## Recorded football Foley and venue-aware broadcast mix. Never changes play.
const VOICE_LIMIT := 12
const FILES := {
	"pass":"pass.wav", "pass_alt":"pass_alt.wav", "kick":"kick.wav", "kick_alt":"kick_alt.wav",
	"header":"header.wav", "catch":"catch.wav", "post":"post.wav", "net":"net.wav",
	"step":"step.wav", "step_alt":"step_alt.wav", "whistle":"whistle.wav", "whistle_full":"whistle_full.wav",
	"ui":"ui.wav", "stadium_bed":"stadium_bed.ogg", "park_bed":"park_bed.ogg", "rain_bed":"rain_bed.ogg",
	"stadium_goal":"stadium_goal.ogg", "stadium_reaction":"stadium_reaction.ogg",
	"stadium_chant":"stadium_chant.ogg", "park_goal":"park_goal.ogg", "park_reaction":"park_reaction.ogg"
}
var music: AudioStreamPlayer
var crowd: AudioStreamPlayer
var rain: AudioStreamPlayer
var reaction: AudioStreamPlayer
var chant: AudioStreamPlayer
var voices: Array[AudioStreamPlayer3D] = []
var ui_voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var game: Node3D
var _events: FootballMatchEvents
var _step_times: Dictionary = {}
var _cooldowns: Dictionary = {}
var _variants: Dictionary = {}
var _tick := 0.0
var _clock := 0.0
var _chant_wait := 28.0
var _chant_gain := 0.0
var _duck := 0.0
var _excitement := 0.0
var _shot_window := 0.0
var _reaction_until := 0.0
var _reaction_priority := 0
var _reaction_gain := -12.0
var _last_event_serial := 0
var _stadium := false
var _ended := false
var event_count := 0
var crowd_event_count := 0
var chant_count := 0
var last_cue := ""
var last_reaction := ""

func _ready() -> void:
	for name in ["Music", "Match", "UI"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1, name)
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1
	limiter.threshold_db = -3
	AudioServer.add_bus_effect(0, limiter)
	for name in FILES:
		streams[name] = load("res://assets/audio/" + FILES[name])
	streams["menu_music"] = preload("res://assets/audio/cool_rock.ogg")
	for index in 4:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"UI"; voice.stream = streams.ui; voice.volume_db = -7
		add_child(voice); ui_voices.append(voice)
	music = _loop("menu_music", "Music", -8)
	crowd = _loop("park_bed", "Match", -10)
	rain = _loop("rain_bed", "Match", -12)
	reaction = _layer()
	chant = _layer()
	for index in VOICE_LIMIT:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = &"Match"; voice.max_distance = 100; voice.unit_size = 28
		add_child(voice); voices.append(voice)

func _layer() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Match"
	add_child(player)
	return player

func _loop(name: String, bus: String, volume: float) -> AudioStreamPlayer:
	var player := _layer()
	player.stream = _loop_stream(name); player.bus = StringName(bus); player.volume_db = volume
	return player

func _loop_stream(name: String) -> AudioStream:
	var stream := streams[name].duplicate() as AudioStream
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	return stream

func set_music(enabled: bool) -> void:
	if enabled and not music.playing: music.play()
	elif not enabled: music.stop()

func bind_match(match_scene: Node3D, events: FootballMatchEvents) -> void:
	stop_match()
	game = match_scene; _events = events
	_step_times.clear(); _cooldowns.clear(); _variants.clear()
	_tick = 0; _clock = 0; _duck = 0; _excitement = 0; _shot_window = 0
	_reaction_until = 0; _reaction_priority = 0; _last_event_serial = 0
	_chant_wait = 28; _chant_gain = 0; _ended = false
	_stadium = match_scene.venue.id == &"rovers_arena"
	events.occurred.connect(_on_event)
	crowd.stream = _loop_stream("stadium_bed" if _stadium else "park_bed")
	crowd.volume_db = -13 if _stadium else -14; crowd.play()
	if MatchSession.weather_preset == &"rain": rain.play()
	else: rain.stop()
	set_music(false)

func stop_match() -> void:
	if is_instance_valid(_events) and _events.occurred.is_connected(_on_event):
		_events.occurred.disconnect(_on_event)
	_events = null; game = null
	crowd.stop(); rain.stop(); reaction.stop(); chant.stop()
	for voice in voices: voice.stop()

func play_ui() -> void:
	for player in ui_voices:
		if not player.playing: player.play(); return

func _variant(name: String) -> String:
	if name not in ["pass", "kick", "step"]: return name
	var index := int(_variants.get(name, 0))
	_variants[name] = index + 1
	return name if index % 2 == 0 else name + "_alt"

func sound(name: String, at: Vector3, volume := 0.0) -> bool:
	if not streams.has(name): return false
	var family := name.trim_suffix("_alt")
	if _clock < float(_cooldowns.get(family, -1.0)): return false
	var priority := 4 if family.begins_with("whistle") else (3 if family in ["post", "net"] else (0 if family == "step" else 2))
	var selected: AudioStreamPlayer3D
	for voice in voices:
		if not voice.playing: selected = voice; break
	if selected == null:
		# A footstep must never displace a strike or whistle. Important events
		# can replace the oldest, lowest-priority voice in the bounded pool.
		for voice in voices:
			if int(voice.get_meta("priority", 0)) > priority: continue
			if selected == null or int(voice.get_meta("priority", 0)) < int(selected.get_meta("priority", 0)) \
				or (voice.get_meta("priority", 0) == selected.get_meta("priority", 0) and float(voice.get_meta("started", 0)) < float(selected.get_meta("started", 0))): selected = voice
	if selected == null: return false
	var cue := _variant(name)
	selected.stop(); selected.stream = streams[cue]; selected.global_position = at; selected.volume_db = volume
	selected.unit_size = 10 if family == "step" else 28
	selected.max_distance = 28 if family == "step" else 100
	selected.pitch_scale = 1.0 if family.begins_with("whistle") else 1.0 + sin(float(event_count)*1.71)*.025
	selected.set_meta("priority", priority); selected.set_meta("started", _clock)
	selected.play(); event_count += 1; last_cue = cue
	_cooldowns[family] = _clock + (.11 if family == "step" else (1.2 if family.begins_with("whistle") else .055))
	if family.begins_with("whistle"): _duck = maxf(_duck, selected.stream.get_length() + .25)
	return true

func _react(kind: String, priority: int, volume: float) -> bool:
	if priority < 4 and _clock < _reaction_until and priority <= _reaction_priority: return false
	var cue := ("stadium_" if _stadium else "park_") + ("goal" if kind == "goal" else "reaction")
	reaction.stop(); reaction.stream = streams[cue]; reaction.pitch_scale = 1
	_reaction_gain = volume; reaction.volume_db = volume; reaction.play()
	_reaction_priority = priority
	_reaction_until = _clock + (reaction.stream.get_length() if kind == "goal" else 5.0)
	crowd_event_count += 1; last_reaction = kind
	_excitement = maxf(_excitement, 1.0)
	return true

func _start_chant() -> bool:
	if not _stadium or _ended or chant.playing or reaction.playing or _duck > 0: return false
	chant.stream = streams.stadium_chant; chant.volume_db = -60; chant.pitch_scale = 1
	chant.play(); _chant_gain = 0; chant_count += 1
	_chant_wait = 42 + float(chant_count % 4)*5
	return true

func _replaying() -> bool:
	return is_instance_valid(game) and game.presentation != null and game.presentation.replaying()

func _on_event(event: FootballMatchEvent) -> void:
	if not is_instance_valid(game) or _replaying() or _ended: return
	if event.serial > 0 and event.serial <= _last_event_serial: return
	_last_event_serial = event.serial
	match event.kind:
		FootballMatchEvent.Kind.GOAL:
			_shot_window = 0
			# action names the awarded team even for an own goal.
			_react("goal", 4, (0.0 if _stadium else -1.0) - (0 if event.action == &"Beechlawn Rovers" else 2))
		FootballMatchEvent.Kind.FOUL:
			sound("whistle", event.position, -10)
		FootballMatchEvent.Kind.FULL_TIME:
			_ended = true; chant.stop()
			for voice in voices: voice.stop()
			sound("whistle_full", event.position, -10)
			_react("full_time", 2, -13)
		FootballMatchEvent.Kind.RESTART:
			if _shot_window > 0 and event.action in [&"GOAL KICK", &"CORNER RESTART"]:
				_react("chance", 2, -14); _shot_window = 0
			if event.action in [&"FREE KICK", &"PENALTY"]: sound("whistle", event.position, -10)
		FootballMatchEvent.Kind.POST:
			sound("post", event.position, -3); _react("post", 3, -10); _shot_window = 0
		FootballMatchEvent.Kind.NET:
			sound("net", event.position, -3)
		FootballMatchEvent.Kind.BALL_CONTACT:
			if event.action == &"net": return
			if event.action in [&"dribble", &"first_touch", &"aerial_control"]:
				sound("pass", event.position, -17)
			elif event.action in [&"goalkeeper_save", &"goalkeeper_catch"]:
				sound("catch", event.position, -7)
				_react("save", 2, -12); _shot_window = 0
			elif event.action != &"throw_in":
				sound("header" if game.ball.last_strike_part == &"head" else ("kick" if event.speed > 15 else "pass"), event.position, -3)
			if event.action in [&"shot", &"volley", &"half_volley"]:
				_shot_window = 4; _excitement = maxf(_excitement, .75)

func _advance_layers(delta: float, live_play: bool) -> void:
	_clock += delta
	_duck = maxf(0, _duck-delta); _shot_window = maxf(0, _shot_window-delta)
	_excitement = maxf(0, _excitement-delta*.22)
	var bed_target: float = (-13.0 if _stadium else -14.0) + (_excitement*2 if _stadium else 0) - (5 if _duck > 0 else (2 if reaction.playing else 0))
	crowd.volume_db = move_toward(crowd.volume_db, bed_target, delta*(30 if bed_target < crowd.volume_db else 12))
	reaction.volume_db = move_toward(reaction.volume_db, _reaction_gain - (6 if _duck > 0 else 0), delta*30)
	var chant_target := 1.0 if live_play and _duck <= 0 and not reaction.playing else 0.0
	_chant_gain = move_toward(_chant_gain, chant_target, delta*(6 if chant_target == 0 else .8))
	chant.volume_linear = _chant_gain*db_to_linear(-9)
	if live_play and _stadium and not _ended:
		_chant_wait -= delta
		if _chant_wait <= 0: _start_chant()

func _process(delta: float) -> void:
	if not is_instance_valid(game):
		if crowd.playing: stop_match()
		return
	var live_play: bool = not (game._intro_active or game._presentation_active or game._full_time or game._kickoff_pending or game._goal_pause_timer > 0 or game.restart.active())
	_advance_layers(delta, live_play)
	if not live_play: return
	_tick += delta
	if _tick < .08: return
	var elapsed := _tick; _tick = 0
	for actor: FootballPlayer in game._home_players+game._away_players:
		var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
		if speed < 1 or not actor.visible or actor.position.distance_to(game.camera_rig.camera.global_position) > 26: continue
		var id := actor.get_instance_id()
		_step_times[id] = float(_step_times.get(id, 0.0)) - elapsed
		if _step_times[id] <= 0:
			_step_times[id] = lerpf(.47, .25, clampf(speed/9, 0, 1))
			sound("step", actor.position, -13)
