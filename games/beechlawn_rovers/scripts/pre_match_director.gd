extends Node
## Presentation-only vignettes. The frozen match stays authoritative at kickoff.
const WALK := &"AN_Beechlawn_WalkOn"
const JOG := &"AN_Beechlawn_WarmupJog"
const IDLE := &"AN_Beechlawn_Idle"
const BOLD := preload("res://assets/ui/fonts/BarlowSemiCondensed-SemiBold.ttf")
const REGULAR := preload("res://assets/ui/fonts/BarlowSemiCondensed-Regular.ttf")
var match_scene: Node3D
var camera: Camera3D
var overlay: CanvasLayer
var title_label: Label
var subtitle_label: Label
var fade: ColorRect
var shots: Array[Dictionary] = []
var shot_index := -1
var shot_time := 0.0
var active := false
var _actors: Array[FootballPlayer] = []
var _lineup: Dictionary = {}
var _entry: Dictionary = {}
var _warmup: Array[FootballPlayer] = []
var _referee: CharacterBody3D
var _referee_transform := Transform3D.IDENTITY
var _interpolation_modes: Dictionary = {}
var _hud_visible := true
var _shane: FootballPlayer
var _keeper: FootballPlayer
var _review_callback: JavaScriptObject

func start(game: Node3D) -> void:
	match_scene = game
	_actors.assign(game._home_players + game._away_players)
	_hud_visible = game.get_node("HUD").visible
	game.get_node("HUD").hide()
	game.camera_rig.presentation_override = true
	game._set_players_physics_enabled(false)
	for actor in _actors:
		_interpolation_modes[actor.get_instance_id()] = actor.physics_interpolation_mode
		actor.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.ball.freeze = true
	_referee = game.get_node_or_null("Referee") as CharacterBody3D
	if _referee != null:
		_referee_transform = _referee.global_transform
		_interpolation_modes[_referee.get_instance_id()] = _referee.physics_interpolation_mode
		_referee.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_referee.set_physics_process(false)
	var home: Array[FootballPlayer] = game._home_players.duplicate()
	var away: Array[FootballPlayer] = game._away_players.duplicate()
	for team in [home, away]:
		team.sort_custom(func(a: FootballPlayer, b: FootballPlayer): return a.profile.jersey_number < b.profile.jersey_number)
		var home_side: bool = team[0].team_name == &"Beechlawn Rovers"
		for index in team.size():
			var actor: FootballPlayer = team[index]
			_lineup[actor.get_instance_id()] = Vector3((-11.2 if home_side else 2.0) + index * 0.92, 0, 5)
			_entry[actor.get_instance_id()] = Vector3(-1.1 if home_side else 1.1, 0, 31 + index * 0.9)
			if actor.profile.player_id == &"shane_denham":
				_shane = actor
			if home_side and actor.profile.role == "goalkeeper":
				_keeper = actor
	_shane = home[1] if _shane == null else _shane
	_keeper = home[0] if _keeper == null else _keeper
	_warmup = [_shane, away[away.size() - 1]]
	camera = Camera3D.new()
	camera.name = "PreMatchCamera"
	camera.near = 0.035
	camera.far = 350.0
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	camera.make_current()
	_build_overlay()
	_build_shots()
	active = true
	_enter_shot(0)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BEECHLAWN_INTRO_ACTIVE = true; window.BEECHLAWN_INTRO_DONE = false")
		if OS.has_feature("debug"):
			_review_callback = JavaScriptBridge.create_callback(_review_shot)
			JavaScriptBridge.get_interface("window").BEECHLAWN_INTRO_SHOT = _review_callback

func _build_shots() -> void:
	_add_shot("venue", "KILMORE DRIVE", "Dublin  ·  Sunday league football", 2.8,
		Vector3(12, 5.2, 40), Vector3(7, 5.0, 38), Vector3(0, 0.7, 0), Vector3(0, 0.7, 0), 53)
	_add_shot("walk", "HERE COME THE TEAMS", "Beechlawn Rovers  /  Boardeaux", 7.5,
		Vector3(4.8, 1.65, 26), Vector3(4.8, 1.65, 17), Vector3(0, 1.15, 31), Vector3(0, 1.15, 22), 52)
	_add_shot("goal", "THE FRAME", "Weathered steel. Seven metres of possibility.", 3.0,
		Vector3(49.2, 2.1, 5), Vector3(50.0, 1.8, 4.6), Vector3(52.5, 1.7, 2.5), Vector3(52.5, 1.7, 2.3), 45)
	_add_shot("net", "EVERY GOAL STARTS HERE", "Kilmore Drive  ·  Matchday details", 2.8,
		Vector3(55.1, 1.6, 2.8), Vector3(54.8, 1.4, 2.6), Vector3(53.4, 1.3, 1.3), Vector3(53.4, 1.3, 1.1), 43)
	_add_shot("fans", "THE TOUCHLINE", "Local football. Familiar faces.", 2.8,
		Vector3(-18.4, 1.6, -31.8), Vector3(-19.4, 1.6, -32.2), Vector3(-20, 1.3, -36.7), Vector3(-20, 1.3, -36.7), 43)
	_add_shot("lineup", "BEECHLAWN ROVERS  vs  BOARDEAUX", "Starting elevens  ·  Kilmore Drive", 4.2,
		Vector3(-9, 1.65, 10), Vector3(8, 1.65, 10), Vector3(-7, 1.35, 5), Vector3(10, 1.35, 5), 52)
	var shane_pos: Vector3 = _lineup[_shane.get_instance_id()]
	_add_shot("portrait", _shane.profile.display_name.to_upper(), "BEECHLAWN ROVERS  /  %d" % _shane.profile.jersey_number, 3.0,
		shane_pos + Vector3(0.6, 1.55, 2.4), shane_pos + Vector3(0.15, 1.57, 2.2),
		shane_pos + Vector3(0, 1.45, 0), shane_pos + Vector3(0, 1.45, 0), 31)
	var keeper_pos: Vector3 = _lineup[_keeper.get_instance_id()]
	_add_shot("keeper", _keeper.profile.display_name.to_upper(), "GOALKEEPER  /  %d" % _keeper.profile.jersey_number, 2.8,
		keeper_pos + Vector3(-0.6, 1.35, 3), keeper_pos + Vector3(-0.1, 1.4, 2.7),
		keeper_pos + Vector3(0, 1.1, 0), keeper_pos + Vector3(0, 1.1, 0), 40)
	_add_shot("pitch", "SUNDAY LEAGUE. PROPER FOOTBALL.", "Grass, chalk and the details that make a home ground.", 2.4,
		Vector3(1.2, 0.32, 1.6), Vector3(0.8, 0.28, 1.3), Vector3(0, 0.02, 0), Vector3(0, 0.02, 0), 43)
	_add_shot("ball", "READY TO ROLL", "Beechlawn Rovers 27", 2.4,
		Vector3(0.7, 0.28, 0.6), Vector3(0.55, 0.26, 0.5), Vector3(0, 0.11, 0), Vector3(0, 0.11, 0), 37)
	_add_shot("warmup", "FINAL PREPARATIONS", "The short match is about to begin.", 4.0,
		Vector3(0.1, 1.5, 10), Vector3(0.1, 1.5, 1.2), Vector3(-2.4, 1.0, 14), Vector3(-2.4, 1.0, 5.2), 51)
	_add_shot("handoff", "BEECHLAWN ROVERS  vs  BOARDEAUX", "Three minutes. All to play for.", 2.0,
		Vector3(0, 5, 16), Vector3(0, 12, 26), Vector3.ZERO, Vector3.ZERO, 50)

func _add_shot(id: String, title: String, subtitle: String, duration: float,
		from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, fov: float) -> void:
	shots.append({"id": id, "title": title, "subtitle": subtitle, "duration": duration,
		"from": from, "to": to, "look_from": look_from, "look_to": look_to, "fov": fov})

func _place(actor: Node3D, position: Vector3, yaw: float) -> void:
	position.y = PitchSurface.height_at(position.x, position.z) + 0.004 if match_scene.terrain_enabled else 0.0
	actor.global_position = position
	actor.rotation.y = yaw

func _stage_lineup() -> void:
	for index in _actors.size():
		var actor := _actors[index]
		_place(actor, _lineup[actor.get_instance_id()], PI)
		(actor.get_node("Visual") as FootballerVisual).play_presentation(IDLE, float(index % 7) * 0.17)
	if _referee != null:
		_place(_referee, Vector3(0, 0, 5), PI)
		(_referee.get_node("Visual") as FootballerVisual).play_presentation(IDLE)

func _enter_shot(index: int) -> void:
	shot_index = index
	shot_time = 0.0
	var shot := shots[index]
	title_label.text = str(shot["title"])
	subtitle_label.text = str(shot["subtitle"])
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = float(shot["fov"])
	match str(shot["id"]):
		"venue", "walk":
			for rank in _actors.size():
				var actor := _actors[rank]
				_place(actor, _entry[actor.get_instance_id()], 0.0)
				(actor.get_node("Visual") as FootballerVisual).play_presentation(WALK if shot["id"] == "walk" else IDLE, float(rank % 5) * 0.13)
			if _referee != null:
				_place(_referee, Vector3(0, 0, 29), 0.0)
				(_referee.get_node("Visual") as FootballerVisual).play_presentation(WALK if shot["id"] == "walk" else IDLE)
		"goal", "lineup", "portrait", "keeper":
			_stage_lineup()
		"warmup":
			# Clear the running lane before the camera retreats toward kickoff.
			# The lineup's old z=5 row would intersect the runners at shot end.
			for actor in _actors:
				if not _warmup.has(actor):
					_place(actor, (_lineup[actor.get_instance_id()] as Vector3) + Vector3(0, 0, -14), PI)
			if _referee != null:
				_place(_referee, Vector3(0, 0, -9), PI)
			for runner_index in _warmup.size():
				var runner := _warmup[runner_index]
				_place(runner, Vector3(-2.4 if runner_index == 0 else 3.5, 0, 14), 0.0)
				(runner.get_node("Visual") as FootballerVisual).play_presentation(JOG, runner_index * 0.23)
		"handoff":
			_restore_kickoff()
			match_scene.camera_rig.reset_tracking()
			var gameplay := match_scene.camera_rig.get_node("Camera3D") as Camera3D
			shots[index]["to"] = gameplay.global_position
			shots[index]["from"] = gameplay.global_position - Vector3(0, 10, 0) if gameplay.projection == Camera3D.PROJECTION_ORTHOGONAL else Vector3(0, 5, 16)
			shots[index]["look_to"] = gameplay.global_position - gameplay.global_basis.z * 20.0
			camera.projection = gameplay.projection
			camera.size = gameplay.size
			camera.fov = gameplay.fov
	_update_shot(0.0)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BEECHLAWN_INTRO_SHOT_ID = '%s'" % str(shot["id"]))

func _process(delta: float) -> void:
	if not active:
		return
	shot_time += delta
	if shot_time >= float(shots[shot_index]["duration"]):
		if shot_index == shots.size() - 1:
			finish()
			return
		_enter_shot(shot_index + 1)
	_update_shot(shot_time)

func _update_shot(time: float) -> void:
	var shot := shots[shot_index]
	var linear := clampf(time / float(shot["duration"]), 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, linear)
	camera.global_position = (shot["from"] as Vector3).lerp(shot["to"], eased)
	var up := Vector3.UP
	if shot["id"] == "handoff":
		up = (match_scene.camera_rig.get_node("Camera3D") as Camera3D).global_basis.y
	camera.look_at((shot["look_from"] as Vector3).lerp(shot["look_to"], eased), up)
	# Walk/jog paths stay linear at their authored nominal speed. Only camera
	# dollies ease; easing actor translation would introduce visible foot slip.
	if shot["id"] == "walk":
		for actor in _actors:
			_place(actor, (_entry[actor.get_instance_id()] as Vector3) + Vector3(0, 0, -1.2 * time), 0.0)
		if _referee != null:
			_place(_referee, Vector3(0, 0, 29 - 1.2 * time), 0.0)
	elif shot["id"] == "warmup":
		for index in _warmup.size():
			_place(_warmup[index], Vector3(-2.4 if index == 0 else 3.5, 0, 14 - 2.2 * time), 0.0)
	fade.color.a = maxf(0.0, 1.0 - time / 0.16)

func _restore_kickoff() -> void:
	for actor in _actors:
		(actor.get_node("Visual") as FootballerVisual).end_presentation()
		actor.velocity = Vector3.ZERO
		actor.ai_action_cooldown = 0.0
		actor.physics_interpolation_mode = _interpolation_modes[actor.get_instance_id()]
	match_scene._setup_kickoff_positions(match_scene._kickoff_team)
	match_scene._set_players_physics_enabled(false)
	if _referee != null:
		(_referee.get_node("Visual") as FootballerVisual).end_presentation()
		_referee.global_transform = _referee_transform
		_referee.velocity = Vector3.ZERO
		_referee.physics_interpolation_mode = _interpolation_modes[_referee.get_instance_id()]
		_referee.reset_physics_interpolation()

func finish() -> void:
	if not active:
		return
	active = false
	_restore_kickoff()
	match_scene._intro_active = false
	match_scene._kickoff_ai_delay = 1.0 if match_scene._spectator_mode else 0.0
	match_scene.get_node("HUD").visible = _hud_visible
	match_scene.camera_rig.presentation_override = false
	match_scene.camera_rig.reset_tracking()
	(match_scene.camera_rig.get_node("Camera3D") as Camera3D).make_current()
	if _referee != null:
		_referee.set_physics_process(true)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BEECHLAWN_INTRO_ACTIVE = false; window.BEECHLAWN_INTRO_DONE = true; window.BEECHLAWN_INTRO_SHOT = undefined")
		if str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('software')")) == "1":
			Engine.max_fps = 8
	queue_free()

func _review_shot(arguments: Array) -> void:
	if arguments.is_empty() or not active:
		return
	for index in shots.size():
		if shots[index]["id"] == str(arguments[0]):
			_enter_shot(index)
			shot_time = float(shots[index]["duration"]) * 0.5
			_update_shot(shot_time)
			# Debug-only composition review. Freeze the director, not the tree:
			# callbacks can still select another shot and Escape can exit.
			set_process(false)
			Engine.max_fps = 2
			for actor in _actors:
				var visual := actor.get_node("Visual") as FootballerVisual
				if visual._presentation_active:
					visual.animation_player.seek(fposmod(shot_time, visual.animation_player.current_animation_length), true)
					visual.animation_player.pause()
			return

func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.name = "BroadcastIntroOverlay"
	overlay.layer = 20
	add_child(overlay)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(screen)
	var top := ColorRect.new()
	top.color = Color(0.025, 0.04, 0.065, 0.95)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 44
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(top)
	var station := Label.new()
	station.text = "LIVE   /   SUNDAY LEAGUE                                       KILMORE DRIVE · DUBLIN"
	station.position = Vector2(73, 11)
	station.add_theme_font_override("font", BOLD)
	station.add_theme_font_size_override("font_size", 17)
	top.add_child(station)
	var crest := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/ui/club_crest_source.jpg")
	atlas.region = Rect2(294, 134, 692, 974)
	atlas.filter_clip = true
	crest.texture = atlas
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.position = Vector2(26, 4)
	crest.size = Vector2(30, 36)
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/ui/club_crest_mask.gdshader")
	crest.material = material
	top.add_child(crest)
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 26
	panel.offset_right = -26
	panel.offset_top = -137
	panel.offset_bottom = -52
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.085, 0.94)
	style.border_color = Color(0.35, 0.62, 1.0)
	style.border_width_left = 5
	panel.add_theme_stylebox_override("panel", style)
	screen.add_child(panel)
	title_label = Label.new()
	title_label.position = Vector2(22, 10)
	title_label.add_theme_font_override("font", BOLD)
	title_label.add_theme_font_size_override("font_size", 27)
	panel.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.position = Vector2(23, 49)
	subtitle_label.add_theme_font_override("font", REGULAR)
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.modulate = Color(0.76, 0.83, 0.93)
	panel.add_child(subtitle_label)
	var skip := Button.new()
	skip.text = "SKIP INTRO  [SPACE / ENTER]"
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.offset_left = -280
	skip.offset_right = -26
	skip.offset_top = -42
	skip.offset_bottom = -10
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_override("font", BOLD)
	skip.pressed.connect(finish)
	screen.add_child(skip)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(fade)
