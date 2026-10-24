extends Node
## Presentation-only vignettes. The frozen match stays authoritative at kickoff.
const WALK := &"AN_Beechlawn_WalkOn"
const JOG := &"AN_Beechlawn_WarmupJog"
const IDLE := &"AN_Beechlawn_Idle"
const BOLD := preload("res://assets/ui/fonts/BarlowSemiCondensed-SemiBold.ttf")
const REGULAR := preload("res://assets/ui/fonts/BarlowSemiCondensed-Regular.ttf")
const LINEUP_GRAPHIC := preload("res://scripts/ui/lineup_graphic.gd")
const REFEREE_GRAPHIC := preload("res://assets/ui/lineups/referee_lower_third.png")
const BROADCAST := preload("res://scripts/ui/broadcast_style.gd")
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
var _des: FootballPlayer
var _review_callback: JavaScriptObject
var _lineup_graphic: Control
var _lower_third: Panel
var _referee_lower_third: Control
var _referee_name: Label
var _referee_role: Label

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
	for actor in away:
		if actor.profile.jersey_number == 9: _des=actor
	_des=away[1] if _des==null else _des
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
	# A directed eighteen-second cold open, before the teams enter the pitch.
	_add_shot("montage_goal", match_scene.venue.display_name.to_upper(), "Sunday league football", 3.0,
		Vector3(49.3,.55,4.4), Vector3(49.8,.60,4.0), Vector3(52.5,1.12,2.0), Vector3(52.5,1.12,1.8), 48)
	_add_shot("montage_net", "MATCHDAY", "Weathered posts. Familiar ground.", 3.0,
		Vector3(55.0,.8,1.5),Vector3(54.8,.9,1.2),Vector3(53.9,.8,.2),Vector3(53.9,.9,0),38)
	_add_shot("montage_ball", "BEECHLAWN ROVERS 27", "The match ball", 3.0,
		Vector3(.65,.3,.65),Vector3(.5,.25,.55),Vector3(0,.11,0),Vector3(0,.11,0),35)
	var keeper_pos := Vector3(-47,0,-1)
	var des_pos := Vector3(6,0,10)
	_add_shot("montage_john", _keeper.profile.display_name.to_upper(), "BEECHLAWN ROVERS · GOALKEEPER", 3.0,
		keeper_pos+Vector3(.35,1.68,2.35),keeper_pos+Vector3(.15,1.68,2.2),keeper_pos+Vector3(0,1.62,0),keeper_pos+Vector3(0,1.62,0),19)
	_add_shot("montage_des", _des.profile.display_name.to_upper(), "BOARDEAUX · PLAYER MANAGER", 3.0,
		des_pos+Vector3(-.35,1.67,2.35),des_pos+Vector3(-.15,1.67,2.2),des_pos+Vector3(0,1.59,0),des_pos+Vector3(0,1.59,0),19)
	var puddle := _puddle_target()
	var wet: bool = match_scene.ball.surface_wetness > .05 and match_scene.venue.worn_surface
	_add_shot("montage_puddles", "THE GOALMOUTH", "Mud, water and Sunday football" if wet else "Worn grass and Sunday football", 3.0,
		puddle+Vector3(-1.6,.20,1.5),puddle+Vector3(-1.3,.23,1.4),puddle+Vector3(.2,.03,0),puddle+Vector3(.35,.03,0),48)
	if not match_scene.venue.worn_surface:
		# Replace the park's muddy-goalmouth vignette with maintained arena turf.
		var detail: Dictionary = shots.back()
		detail["title"] = "THE PLAYING SURFACE"
		detail["subtitle"] = "Matchday at Rovers Arena"
	_add_shot("venue", match_scene.venue.display_name.to_upper(), "Dublin  ·  Sunday league football", 2.8,
		match_scene.venue.camera_anchor(&"wide"), match_scene.venue.camera_anchor(&"wide_end"), Vector3(0, 0.7, 0), Vector3(0, 0.7, 0), 53)
	# Two readable eleven-second team cards; keep the live walk visible to
	# their right and retain the authored 1.2 m/s player walking speed.
	_add_shot("walk", "HERE COME THE TEAMS", "Beechlawn Rovers  /  Boardeaux", 22.0,
		Vector3(10.8, 1.65, 26), Vector3(10.8, 1.65, -0.4), Vector3(6, 1.15, 31), Vector3(6, 1.15, 4.6), 52)
	# A close, face-forward official reveal follows the home/away lineup cards.
	_add_shot("referee", "DES FEENEY", "MATCH OFFICIAL  /  REFEREE", 4.2,
		Vector3(0.58, 1.73, 7.7), Vector3(0.48, 1.73, 7.55),
		Vector3(0, 1.62, 5.0), Vector3(0, 1.62, 5.0), 19)
	_add_shot("fans", "THE TOUCHLINE", "Local football. Familiar faces.", 2.8,
		Vector3(-18.4, 1.6, -31.8), Vector3(-19.4, 1.6, -32.2), Vector3(-20, 1.3, -36.7), Vector3(-20, 1.3, -36.7), 43)
	# Keep the full team sweep readable instead of racing past the faces.
	_add_shot("lineup", "BEECHLAWN ROVERS  vs  BOARDEAUX", "Starting elevens  ·  "+match_scene.venue.display_name, 12.0,
		Vector3(-9, 1.65, 10), Vector3(8, 1.65, 10), Vector3(-7, 1.35, 5), Vector3(10, 1.35, 5), 52)
	var shane_pos: Vector3 = _lineup[_shane.get_instance_id()]
	_add_shot("portrait", _shane.profile.display_name.to_upper(), "BEECHLAWN ROVERS  /  %d" % _shane.profile.jersey_number, 3.0,
		shane_pos + Vector3(0.6, 1.55, 2.4), shane_pos + Vector3(0.15, 1.57, 2.2),
		shane_pos + Vector3(0, 1.45, 0), shane_pos + Vector3(0, 1.45, 0), 31)
	_add_shot("warmup", "FINAL PREPARATIONS", "The short match is about to begin.", 4.0,
		Vector3(0.1, 1.5, 10), Vector3(0.1, 1.5, 1.2), Vector3(-2.4, 1.0, 14), Vector3(-2.4, 1.0, 5.2), 51)
	_add_shot("handoff", "BEECHLAWN ROVERS  vs  BOARDEAUX", "Three minutes. All to play for.", 2.0,
		Vector3(0, 5, 16), Vector3(0, 12, 26), Vector3.ZERO, Vector3.ZERO, 50)

func _add_shot(id: String, title: String, subtitle: String, duration: float,
		from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, fov: float) -> void:
	shots.append({"id": id, "title": title, "subtitle": subtitle, "duration": duration,
		"from": from, "to": to, "look_from": look_from, "look_to": look_to, "fov": fov})

func _place(actor: Node3D, position: Vector3, yaw: float) -> void:
	position.y = match_scene.surface_height(position.x, position.z) + 0.004 if match_scene.terrain_enabled else 0.0
	actor.global_position = position
	actor.rotation.y = yaw

func _stage_lineup() -> void:
	for index in _actors.size():
		var actor := _actors[index]
		actor.show()
		_place(actor, _lineup[actor.get_instance_id()], PI)
		(actor.get_node("Visual") as FootballerVisual).play_presentation(IDLE, float(index % 7) * 0.17)
	if _referee != null:
		_place(_referee, Vector3(0, 0, 5), PI)
		(_referee.get_node("Visual") as FootballerVisual).play_presentation(IDLE)

func _enter_shot(index: int) -> void:
	shot_index = index
	shot_time = 0.0
	var shot := shots[index]
	_lineup_graphic.hide()
	match_scene.ball.visible = shot["id"] != "referee"
	_lower_third.visible = shot["id"] in ["venue", "lineup"]
	_referee_lower_third.visible = shot["id"] == "referee"
	title_label.text = match_scene.venue.display_name.to_upper() if shot["id"] == "venue" else "BEECHLAWN ROVERS"
	subtitle_label.hide()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = float(shot["fov"])
	match str(shot["id"]):
		"montage_goal", "montage_net", "montage_ball", "montage_john", "montage_des", "montage_puddles":
			for actor in _actors: actor.hide()
			if _referee!=null: _referee.hide()
			if shot["id"]=="montage_john":
				_keeper.show()
				_place(_keeper,Vector3(-47,0,-1),PI)
				(_keeper.get_node("Visual") as FootballerVisual).play_presentation(&"AN_Beechlawn_KeeperSet")
			elif shot["id"]=="montage_des":
				_des.show()
				_place(_des,Vector3(6,0,10),PI)
				(_des.get_node("Visual") as FootballerVisual).play_presentation(IDLE)
		"venue", "walk":
			for actor in _actors: actor.show()
			if _referee!=null: _referee.show()
			for rank in _actors.size():
				var actor := _actors[rank]
				_place(actor, _entry[actor.get_instance_id()], 0.0)
				(actor.get_node("Visual") as FootballerVisual).play_presentation(WALK if shot["id"] == "walk" else IDLE, float(rank % 5) * 0.13)
			if _referee != null:
				_place(_referee, Vector3(0, 0, 29), 0.0)
				(_referee.get_node("Visual") as FootballerVisual).play_presentation(WALK if shot["id"] == "walk" else IDLE)
		"goal", "lineup", "portrait", "keeper":
			_stage_lineup()
		"referee":
			if _referee!=null: _referee.show()
			for actor in _actors:
				actor.hide()
			if _referee != null:
				_place(_referee, Vector3(0, 0, 5), PI)
				(_referee.get_node("Visual") as FootballerVisual).play_presentation(IDLE)
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
			# Approach from the selected camera's side instead of crossing the
			# whole pitch from the old fixed positive-Z broadcast location.
			shots[index]["from"] = gameplay.global_position - Vector3(0, 10, 0) \
				if gameplay.projection == Camera3D.PROJECTION_ORTHOGONAL \
				else Vector3(gameplay.global_position.x * 0.6, maxf(2.0, gameplay.global_position.y - 7.0), gameplay.global_position.z * 0.6)
			shots[index]["look_to"] = gameplay.global_position - gameplay.global_basis.z * 20.0
			camera.projection = gameplay.projection
			camera.size = gameplay.size
			camera.fov = gameplay.fov
	if match_scene.grass_detail != null:
		match_scene.grass_detail.prewarm(shot["from"])
		if index + 1 < shots.size(): match_scene.grass_detail.prepare(shots[index + 1]["from"])
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
	if _lower_third.visible:
		var caption_time := time
		var caption_duration := float(shot["duration"])
		if shot["id"] == "lineup":
			caption_duration *= 0.5
			title_label.text = "BEECHLAWN ROVERS" if time < caption_duration else "BOARDEAUX"
			caption_time = fmod(time, caption_duration)
		(_lower_third as FootballLowerThird).reveal(caption_time)
		_lower_third.modulate.a *= 1.0 - smoothstep(caption_duration - 0.4, caption_duration, caption_time)
	var linear := clampf(time / float(shot["duration"]), 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, linear)
	camera.global_position = (shot["from"] as Vector3).lerp(shot["to"], eased)
	var up := Vector3.UP
	if shot["id"] == "handoff":
		up = (match_scene.camera_rig.get_node("Camera3D") as Camera3D).global_basis.y
	camera.look_at((shot["look_from"] as Vector3).lerp(shot["look_to"], eased), up)
	FootballCameraOptics.for_camera(camera).shot(StringName(shot["id"]), (shot["look_from"] as Vector3).lerp(shot["look_to"], eased), float(shot["fov"]), 1.0/60)
	# Walk/jog paths stay linear at their authored nominal speed. Only camera
	# dollies ease; easing actor translation would introduce visible foot slip.
	if shot["id"] == "walk":
		_lineup_graphic.present_walk(time, float(shot["duration"]))
		for actor in _actors:
			_place(actor, (_entry[actor.get_instance_id()] as Vector3) + Vector3(0, 0, -1.2 * time), 0.0)
		if _referee != null:
			_place(_referee, Vector3(0, 0, 29 - 1.2 * time), 0.0)
	elif shot["id"] == "referee":
		var duration := float(shot["duration"])
		(_referee_lower_third as FootballLowerThird).reveal(time)
		_referee_lower_third.modulate.a *= 1.0 - smoothstep(duration - 0.38, duration, time)
		if OS.has_feature("web") and OS.has_feature("debug"):
			JavaScriptBridge.eval("window.BEECHLAWN_REFEREE_STATE = " + JSON.stringify({
				"visible": _referee_lower_third.visible, "alpha": _referee_lower_third.modulate.a,
				"name": _referee_name.text, "role": _referee_role.text}))
	elif shot["id"] == "warmup":
		for index in _warmup.size():
			_place(_warmup[index], Vector3(-2.4 if index == 0 else 3.5, 0, 14 - 2.2 * time), 0.0)
	fade.color.a = maxf(0.0, 1.0 - time / 0.16)

func _restore_kickoff() -> void:
	match_scene.ball.show()
	for actor in _actors:
		actor.show()
		(actor.get_node("Visual") as FootballerVisual).end_presentation()
		actor.velocity = Vector3.ZERO
		actor.ai_action_cooldown = 0.0
		actor.physics_interpolation_mode = _interpolation_modes[actor.get_instance_id()]
	match_scene._setup_kickoff_positions(match_scene._kickoff_team)
	match_scene._set_players_physics_enabled(false)
	if _referee != null:
		_referee.show()
		(_referee.get_node("Visual") as FootballerVisual).end_presentation()
		_referee.global_transform = _referee_transform
		_referee.velocity = Vector3.ZERO
		_referee.physics_interpolation_mode = _interpolation_modes[_referee.get_instance_id()]
		_referee.reset_physics_interpolation()

func finish() -> void:
	if not active:
		return
	active = false
	FootballCameraOptics.for_camera(camera).clear()
	get_node("/root/GameAudio").set_music(false)
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
	var requested := str(arguments[0])
	var fraction := 0.25 if requested == "teams_home" else (0.75 if requested == "teams_away" else 0.5)
	if requested in ["teams_home", "teams_away"]: requested = "walk"
	for index in shots.size():
		if shots[index]["id"] == requested:
			_enter_shot(index)
			shot_time = float(shots[index]["duration"]) * fraction
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
	station.text = "LIVE   /   SUNDAY LEAGUE                                       "+match_scene.venue.display_name.to_upper()+" · DUBLIN"
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
	var panel := FootballLowerThird.new()
	_lower_third = panel
	screen.add_child(panel)
	title_label = panel.title
	subtitle_label = panel.subtitle
	var referee_banner := FootballLowerThird.new()
	referee_banner.name = "RefereeLowerThird"
	screen.add_child(referee_banner)
	_referee_lower_third = referee_banner
	_referee_name = referee_banner.title
	_referee_name.text = "DES FEENEY"
	_referee_role = referee_banner.subtitle
	_referee_role.text = "MATCH OFFICIAL  ·  REFEREE"
	_referee_lower_third.hide()
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
	_lineup_graphic = LINEUP_GRAPHIC.new()
	_lineup_graphic.name = "StartingElevens"
	screen.add_child(_lineup_graphic)
	_lineup_graphic.configure(match_scene._home_team, match_scene._away_team)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(fade)

func _puddle_target() -> Vector3:
	var best := Vector3(49,0,2)
	var coverage := -1.0
	if match_scene.ball.wet_surface!=null:
		for x in range(46,52):
			for z in range(-5,6):
				var point := Vector3(x,0,z)
				var value: float = match_scene.ball.wet_surface.sample_at(point).y
				if value>coverage: coverage=value; best=point
	best.y=match_scene.surface_height(best.x,best.z)+.015 if match_scene.terrain_enabled else .015
	return best
