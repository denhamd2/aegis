extends Node3D
## Sunday-league match orchestration; simulation, rules and presentation are separate.

const FIELD_LENGTH := 105.0
const FIELD_WIDTH := 68.0
const GOAL_WIDTH := 7.32
const GOAL_HEIGHT := 2.44
const GOAL_DEPTH := 1.8
const SECOND_PRESS_RANGE := 18.0
signal ai_action_chosen(carrier: FootballPlayer, action: StringName)

@export_range(30.0, 600.0, 30.0) var short_match_seconds := 180.0
@export var home_team_resource: FootballTeam = preload("res://data/teams/beechlawn_rovers.tres")
@export var away_team_resource: FootballTeam = preload("res://data/teams/bordeaux.tres")
@export var use_human_visual := false
@export var referee_enabled := false
@export var terrain_enabled := false

@onready var ball: FootballBall = $Ball
@onready var player: FootballPlayer = $Player
@onready var camera_rig: Node3D = $BroadcastCamera
@onready var score_label: Label = $HUD/Score
@onready var clock_label: Label = $HUD/Clock
@onready var message_label: Label = $HUD/Message
@onready var power_bar: ProgressBar = $HUD/Power
@onready var debug_label: Label = $HUD/Debug

var _home_score := 0
var _away_score := 0
var _remaining_time := 180.0
var _message_time := 0.0
var _full_time := false
var _kickoff_pending := true
var _kickoff_team: StringName = &"Beechlawn Rovers"
var _goal_pause_timer := 0.0
var _kickoff_ai_delay := 0.0
var _ai_tick := 0.0
var _home_team: FootballTeam
var _away_team: FootballTeam
var _home_players: Array[FootballPlayer] = []
var _away_players: Array[FootballPlayer] = []
var _home_control_index := 0
var _possession_team: StringName = &"none"
var _transition_team: StringName = &"none"
var _transition_time_left := 0.0
var _team_tactics := TeamTacticsController.new()
const PlayerDecisionController = preload("res://scripts/player_decision_controller.gd")
var _player_decisions = PlayerDecisionController.new()
var _kit_material_cache: Dictionary = {}
var _next_home_ai := true
var _possession_reader = preload("res://scripts/tactical_possession.gd").new()
var _tactical_possession := {}
var _net_impacts: Dictionary = {}
var _boundary_pending := false
var _boundary_team: StringName = &"none"
var _boundary_spot := Vector3.ZERO
var _boundary_kind := ""
var _capture_callback: JavaScriptObject
var _spectator_mode := false
var _intro_active := false
var _pre_match: Node
var restart = preload("res://scripts/football_restart_controller.gd").new()
var rules = preload("res://scripts/football_rules_controller.gd").new()

func _ready() -> void:
	_spectator_mode = MatchSession.is_spectator()
	if OS.has_feature("web") and OS.has_feature("debug"):
		var software_capture = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('software')")
		if software_capture != null and str(software_capture)=="1":
			var shadow_review = str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('shadows')")) == "1"
			$Sun.shadow_enabled = shadow_review
			Engine.max_fps = 1 if shadow_review else 8
		_capture_callback=JavaScriptBridge.create_callback(_freeze_capture)
		JavaScriptBridge.get_interface("window").BEECHLAWN_FREEZE_FRAME=_capture_callback
	_remaining_time = short_match_seconds
	_home_team = home_team_resource
	_away_team = away_team_resource
	for team in [_home_team, _away_team]:
		var errors: PackedStringArray = team.validate_roster()
		if not errors.is_empty():
			push_error("Invalid match lineup: %s" % errors)
			return
	_assemble_teams()
	restart.name="RestartController"
	add_child(restart)
	restart.setup(self)
	rules.setup(self)
	ball.net_contact.connect(_on_net_contact)
	if _spectator_mode:
		for actor in _home_players + _away_players:
			actor.controlled_by_human = false
			_set_marker_visibility(actor, false)
		_kickoff_ai_delay = 1.0
		$HUD/Controls.text = "WATCHING AI vs AI\nC  Camera   Esc  Title screen"
	else:
		$HUD/Controls.text += "\nC  Camera   Esc  Title screen"
	build_pitch()
	build_goals()
	build_park_edge()
	ball.use_terrain = terrain_enabled
	var weather := MatchWeather.new()
	weather.name = "MatchWeather"
	add_child(weather)
	var weather_id: StringName = MatchSession.weather_preset
	if OS.has_feature("web") and OS.has_feature("debug"):
		var requested = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('weather')")
		if requested != null:
			weather_id = MatchWeather.valid_id(StringName(str(requested)))
	weather.setup(self, weather_id)
	if use_human_visual:
		var radar := Control.new()
		radar.set_script(load("res://scripts/tactical_radar.gd"))
		radar.name = "TacticalRadar"
		radar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		radar.position = Vector2(-112,-152)
		radar.size = Vector2(224,132)
		$HUD.add_child(radar)
	if referee_enabled:
		var official := load("res://scenes/referee.tscn").instantiate() as CharacterBody3D
		official.name = "Referee"
		add_child(official)
	$Goals/PositiveEnd/GoalDetector.goal_scored.connect(_on_goal)
	$Goals/NegativeEnd/GoalDetector.goal_scored.connect(_on_goal)
	_setup_kickoff_positions(_kickoff_team)
	if OS.has_feature("web") and OS.has_feature("debug"):
		# Explicit stationary inspection fixture; never used by normal matches.
		if str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('surface_review')")) == "1":
			ball.position = Vector3(50.9,PitchSurface.height_at(50.9,-1.5)+FootballBall.RADIUS,-1.5)
	ball.freeze = true
	_set_players_physics_enabled(false)
	_bind_controlled_player()
	_update_score()
	_update_clock()
	_set_message("AI vs AI  ·  Kickoff shortly" if _spectator_mode else "KICK OFF  ·  E pass  /  Q through-ball")
	if MatchSession.launched_from_menu and MatchSession.show_intro:
		_intro_active = true
		_pre_match = preload("res://scripts/pre_match_director.gd").new()
		_pre_match.name = "PreMatchDirector"
		add_child(_pre_match)
		_pre_match.start(self)
	if OS.has_feature("web"):
		await RenderingServer.frame_post_draw
		var humans := 0
		var rigs := 0
		for actor in _home_players + _away_players:
			rigs += actor.get_node("Visual").find_children("*", "Skeleton3D", true, false).size()
			if actor.controlled_by_human:
				humans += 1
		JavaScriptBridge.eval("window.BEECHLAWN_MATCH_MODE = '%s'; window.BEECHLAWN_HUMAN_PLAYERS = %d; window.BEECHLAWN_PLAYER_RIGS = %d" % ["watch" if _spectator_mode else "play",humans,rigs])
		JavaScriptBridge.eval("window.BEECHLAWN_MATCH_READY = true")
	print("BEECHLAWN_MATCH_READY actors=",_home_players.size()+_away_players.size()," officials=",get_tree().get_nodes_in_group("match_officials").size())

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _intro_active and event.keycode in [KEY_ENTER, KEY_SPACE]:
			_pre_match.finish()
			get_viewport().set_input_as_handled()
			return
		if not _intro_active and event.keycode == KEY_C:
			_set_message("Camera: %s" % camera_rig.cycle_preset())
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		MatchSession.return_to_title()

func _freeze_capture(_arguments: Array) -> void:
	# Debug export only: hold actual scene state while browser reads the canvas.
	get_tree().paused=true
	Engine.max_fps=1

func _physics_process(delta: float) -> void:
	if _intro_active:
		return
	for entry in _net_impacts.values():
		entry["age"] = minf(2.0,float(entry["age"])+delta)
		(entry["material"] as ShaderMaterial).set_shader_parameter("impact_age",entry["age"])
	if restart.active() and not _full_time:
		restart.update(delta)
		if restart.released and restart.active():
			_update_ai(delta)
			_remaining_time=maxf(0,_remaining_time-delta)
			if _remaining_time<=0: _finish_match()
		_update_clock()
		return
	if not _full_time:
		if _goal_pause_timer > 0.0:
			_goal_pause_timer = maxf(0.0, _goal_pause_timer - delta)
			if _goal_pause_timer == 0.0:
				if _boundary_pending:
					_resume_boundary_restart()
				else:
					_prepare_kickoff(_kickoff_team)
		elif _kickoff_pending:
			_update_kickoff_input(delta)
		else:
			_update_ai(delta)
			if terrain_enabled:
				_check_boundary_restart()
			_remaining_time = maxf(0.0, _remaining_time - delta)
			if _remaining_time <= 0.0:
				_finish_match()
	if _message_time > 0.0 and not _full_time and not _kickoff_pending and _goal_pause_timer <= 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			message_label.text = ""
	_update_clock()
	debug_label.visible = bool(player.get_meta("debug_enabled", false))
	if debug_label.visible:
		debug_label.text = "60 Hz physics  |  Player %.1f m/s  |  Ball %.1f m/s  |  Stamina %d%%" % [
			float(player.get_meta("move_speed", 0.0)), ball.linear_velocity.length(), roundi(player.stamina)]
	if not _spectator_mode and not _full_time and not _kickoff_pending and _goal_pause_timer <= 0.0 \
			and Input.is_action_just_pressed("switch_player"):
		_cycle_controlled_player()

func _update_kickoff_input(delta: float) -> void:
	if _intro_active:
		return
	if _kickoff_team == &"Beechlawn Rovers" and not _spectator_mode:
		if Input.is_action_just_pressed("pass"):
			_start_kickoff(false)
		elif Input.is_action_just_pressed("through_pass"):
			_start_kickoff(true)
	else:
		_kickoff_ai_delay = maxf(0.0, _kickoff_ai_delay - delta)
		if _kickoff_ai_delay <= 0.0:
			_start_kickoff(false)

func _setup_kickoff_positions(kicking_team: StringName) -> void:
	var kicking_players := _home_players if kicking_team == &"Beechlawn Rovers" else _away_players
	var defending_players := _away_players if kicking_team == &"Beechlawn Rovers" else _home_players
	var kickoff_sign := 1.0 if kicking_team == &"Beechlawn Rovers" else -1.0
	if use_human_visual:
		_setup_full_kickoff(kicking_players, defending_players, kickoff_sign)
		return
	for actor in kicking_players:
		actor.receive_target_time = 0.0
		actor.velocity = Vector3.ZERO
		actor.ai_move_direction = Vector3.ZERO
		actor.ai_sprinting = false
		if actor.profile.role == "goalkeeper":
			actor.position = Vector3(-49.5 * kickoff_sign, 0.0, 0.0)
		elif actor.profile.starting_slot == "center":
			actor.position = Vector3(-0.65 * kickoff_sign, 0.0, 0.0)
		else:
			var side := -8.0 if actor.profile.starting_slot == "left" else 8.0
			actor.position = Vector3(-8.0 * kickoff_sign, 0.0, side)
		actor.rotation.y = -PI * 0.5 * actor.attack_sign
	for actor in defending_players:
		actor.receive_target_time = 0.0
		actor.velocity = Vector3.ZERO
		actor.ai_move_direction = Vector3.ZERO
		actor.ai_sprinting = false
		if actor.profile.role == "goalkeeper":
			actor.position = Vector3(49.5 * kickoff_sign, 0.0, 0.0)
		else:
			var side := 0.0
			if actor.profile.starting_slot == "left":
				side = -8.5
			elif actor.profile.starting_slot == "right":
				side = 8.5
			actor.position = Vector3(10.5 * kickoff_sign, 0.0, side)
		actor.rotation.y = -PI * 0.5 * actor.attack_sign
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_position = Vector3(0.0, FootballBall.RADIUS + 0.025, 0.0)
	# Kickoff and goal restarts reposition physics-driven nodes directly. Clear
	# interpolation history so the enabled render interpolation does not sweep
	# players or the ball across the pitch between their old and new positions.
	for actor in _home_players + _away_players:
		actor.reset_physics_interpolation()
	ball.reset_physics_interpolation()
	ball.last_touch = &"none"

func _setup_full_kickoff(kicking: Array[FootballPlayer], defending: Array[FootballPlayer], direction: float) -> void:
	var taker := _kickoff_taker(kicking)
	for actor in kicking + defending:
		var local_position := actor.profile.starting_position
		local_position.x = minf(local_position.x, -10.5) if defending.has(actor) else minf(local_position.x, -2.0)
		if actor == taker:
			local_position = Vector2(-0.65, 0.0)
		elif kicking.has(actor) and actor.profile.tactical_role == "striker":
			local_position = Vector2(-2.0, 4.0)
		actor.position = Vector3(local_position.x * actor.attack_sign, 0.0, local_position.y)
		actor.position.y = PitchSurface.height_at(actor.position.x, actor.position.z) + 0.015 if terrain_enabled else 0.0
		actor.velocity = Vector3.ZERO
		actor.receive_target_time = 0.0
		actor.ai_move_direction = Vector3.ZERO
		actor.ai_sprinting = false
		actor.rotation.y = -PI * 0.5 * actor.attack_sign
		actor.reset_physics_interpolation()
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_position = Vector3(0.0, FootballBall.RADIUS + 0.025, 0.0)
	ball.reset_physics_interpolation()
	ball.last_touch = &"none"

func _prepare_kickoff(kicking_team: StringName) -> void:
	rules.restart_taker=null
	rules.restart_kind=""
	_kickoff_team = kicking_team
	_setup_kickoff_positions(kicking_team)
	_kickoff_pending = true
	_goal_pause_timer = 0.0
	_kickoff_ai_delay = 0.0
	if _spectator_mode:
		_kickoff_ai_delay = 1.0
		_set_message("AI vs AI  ·  %s kickoff" % kicking_team)
	elif kicking_team == &"Beechlawn Rovers":
		var taker := _kickoff_taker(_home_players)
		if taker != null and taker != player:
			_set_controlled_player(taker)
		_set_message("KICK OFF  ·  E pass  /  Q through-ball")
	else:
		_kickoff_ai_delay = 1.0
		_set_message("Boardeaux ready to kick off")

func _kickoff_taker(team_players: Array[FootballPlayer]) -> FootballPlayer:
	var slot := _home_team.kickoff_slot if team_players == _home_players else _away_team.kickoff_slot
	for actor in team_players:
		if actor.profile != null and actor.profile.role == "outfield" and actor.profile.starting_slot == slot:
			return actor
	return _nearest_outfielder(team_players, Vector2.ZERO)

func _start_kickoff(through: bool) -> void:
	if _intro_active:
		return
	if not _kickoff_pending or _full_time:
		return
	var kicking_players := _home_players if _kickoff_team == &"Beechlawn Rovers" else _away_players
	var taker := _kickoff_taker(kicking_players)
	if taker == null:
		return
	var receiver: FootballPlayer
	var receiver_distance := INF
	for teammate in kicking_players:
		if teammate == taker or teammate.profile == null or teammate.profile.role != "outfield":
			continue
		var distance := taker.global_position.distance_squared_to(teammate.global_position)
		if distance < receiver_distance:
			receiver = teammate
			receiver_distance = distance
	if receiver == null:
		return
	var kick_direction := receiver.global_position - taker.global_position
	kick_direction.y = 0.0
	_kickoff_pending = false
	_goal_pause_timer = 0.0
	_set_players_physics_enabled(true)
	ball.freeze = false
	taker._do_pass(through, kick_direction)
	if taker.controlled_by_human and (Input.is_action_pressed("pass") or Input.is_action_pressed("through_pass")):
		taker.consume_pass_input_until_released()
	_set_message("KICK OFF")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BEECHLAWN_MATCH_STARTED = true")

func _set_players_physics_enabled(enabled: bool) -> void:
	for actor in _home_players + _away_players:
		actor.set_physics_process(enabled)

func _set_controlled_player(next_player: FootballPlayer) -> void:
	if _spectator_mode or next_player == null or next_player == player:
		return
	var old_player := player
	old_player._aerial_controller.cancel_input()
	if old_player.status_changed.is_connected(_set_message):
		old_player.status_changed.disconnect(_set_message)
	if old_player.shot_charge_changed.is_connected(_set_power):
		old_player.shot_charge_changed.disconnect(_set_power)
	old_player.controlled_by_human = false
	player = next_player
	player.controlled_by_human = true
	player.ai_move_direction = Vector3.ZERO
	player.ai_sprinting = false
	_set_power(0.0)
	_set_marker_visibility(old_player, false)
	_set_marker_visibility(player, true)
	camera_rig.set("player", player)
	_bind_controlled_player()

func _assemble_teams() -> void:
	if _home_team == null or _away_team == null:
		push_error("Could not load Beechlawn team resources")
		return
	var home_control_profile := _profile_for_slot(_home_team, _home_team.kickoff_slot)
	_configure_player(player, home_control_profile, _home_team, 1.0, true)
	_home_players.append(player)
	for profile in _home_team.roster:
		if profile != home_control_profile:
			_home_players.append(_spawn_player(profile, _home_team, 1.0))
	for profile in _away_team.roster:
		_away_players.append(_spawn_player(profile, _away_team, -1.0))
	_create_control_marker(player, true)
	_home_control_index = _home_players.find(player)
	camera_rig.set("player", player)

func _profile_for_slot(team: FootballTeam, slot: String) -> FootballerProfile:
	for profile in team.roster:
		if profile.starting_slot == slot:
			return profile
	return team.roster[0] if not team.roster.is_empty() else null

func _spawn_player(profile: FootballerProfile,
		team: FootballTeam, direction: float) -> FootballPlayer:
	# Instantiate an unconfigured actor. Duplicating the live template also
	# duplicated its runtime-added human Rig beside the source proxy Rig.
	var actor := preload("res://scenes/football_player.tscn").instantiate() as FootballPlayer
	actor.name = String(profile.player_id)
	_configure_player(actor, profile, team, direction, false)
	add_child(actor)
	_create_control_marker(actor, false)
	return actor

func _configure_player(actor: FootballPlayer, profile: FootballerProfile,
		team: FootballTeam, direction: float, human: bool) -> void:
	actor.add_to_group("football_players")
	if not actor.foul_committed.is_connected(_on_foul_committed):
		actor.foul_committed.connect(_on_foul_committed)
	actor.profile = profile
	actor.team_name = StringName(team.display_name)
	actor.attack_sign = direction
	actor.controlled_by_human = human
	actor.ai_move_direction = Vector3.ZERO
	actor.ai_sprinting = false
	actor.position = Vector3(profile.starting_position.x * direction, 0.0, profile.starting_position.y)
	actor.rotation.y = -PI * 0.5 * direction
	if use_human_visual and profile.appearance != null:
		var collision := actor.get_node("CollisionShape3D") as CollisionShape3D
		var capsule := collision.shape.duplicate() as CapsuleShape3D
		capsule.height = 1.82 * profile.appearance.height_scale
		capsule.radius = 0.32 * profile.appearance.build_scale
		collision.shape = capsule
		collision.position.y = capsule.height * 0.5
	var visual := actor.get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	if visual is FootballerVisual:
		if use_human_visual:
			(visual as FootballerVisual).configure_appearance(profile, team)
			if profile.role == "goalkeeper":
				_add_keeper_glove(visual, "Left")
				_add_keeper_glove(visual, "Right")
		else:
			var kit_color := team.goalkeeper_kit_color if profile.role == "goalkeeper" else team.primary_kit_color
			(visual as FootballerVisual).set_team_color(kit_color)
	else:
		_apply_reference_kit(visual, profile, team)
	var number_label := visual.get_node_or_null("Number8") as Label3D
	if number_label:
		number_label.text = str(profile.jersey_number) if profile.jersey_number > 0 else ""
		number_label.visible = profile.jersey_number > 0
		if direction < 0.0:
			number_label.rotation.y = 0.0

func _apply_reference_kit(visual: Node3D, profile: FootballerProfile,
		team: FootballTeam) -> void:
	var is_keeper := profile.role == "goalkeeper"
	var is_beechlawn := team.team_id == &"beechlawn_rovers"
	var kit_key := "%s_%s" % [String(team.team_id), "keeper" if is_keeper else "outfield"]
	var jersey := _kit_material_cache.get(kit_key) as ShaderMaterial
	if jersey == null:
		jersey = ShaderMaterial.new()
		jersey.shader = Shader.new()
		jersey.shader.code = """
	shader_type spatial;
	uniform vec4 base_tint : source_color = vec4(0.04, 0.04, 0.05, 1.0);
	uniform vec4 accent_tint : source_color = vec4(0.10, 0.34, 0.78, 1.0);
	uniform int pattern = 0;
	void fragment() {
		vec2 uv = UV;
		float stripe = step(0.5, fract(uv.x * 8.0));
		float keeper_graphic = step(0.66, fract(uv.x * 4.0 + uv.y * 2.2));
		vec3 color = base_tint.rgb;
		if (pattern == 0) { color = mix(base_tint.rgb, accent_tint.rgb, stripe); }
		if (pattern == 1) { color = mix(base_tint.rgb, accent_tint.rgb, step(0.84, uv.y)); }
		if (pattern == 2) { color = mix(base_tint.rgb, accent_tint.rgb, keeper_graphic * step(0.12, uv.y) * step(uv.y, 0.88)); }
		ALBEDO = color;
		ROUGHNESS = 0.84;
	}
	"""
		var pattern := 0
		var base_color := Color(0.035, 0.035, 0.045)
		var accent_color := Color(0.08, 0.31, 0.78)
		if is_beechlawn and is_keeper:
			pattern = 2
			base_color = Color(0.77, 0.79, 0.83)
			accent_color = Color(0.08, 0.27, 0.68)
		elif is_beechlawn:
			pattern = 0
		elif is_keeper:
			pattern = 2
			base_color = Color(0.10, 0.11, 0.13)
			accent_color = Color(0.34, 0.37, 0.40)
		else:
			pattern = 1
			base_color = Color(0.27, 0.59, 0.83)
			accent_color = Color(0.08, 0.17, 0.29)
		jersey.set_shader_parameter("base_tint", base_color)
		jersey.set_shader_parameter("accent_tint", accent_color)
		jersey.set_shader_parameter("pattern", pattern)
		_kit_material_cache[kit_key] = jersey
	for node_path in ["Torso", "LeftArm", "RightArm"]:
		var mesh := visual.get_node_or_null(node_path) as MeshInstance3D
		if mesh:
			mesh.material_override = jersey
	var socks := _mat(Color(0.06, 0.28, 0.78) if is_beechlawn and not is_keeper else
		Color(0.88, 0.89, 0.84), 0.9)
	if is_keeper and is_beechlawn:
		socks.albedo_color = Color(0.88, 0.89, 0.84)
	for side in ["Left", "Right"]:
		var shin_name := "Sock%s" % side
		var shin := visual.get_node_or_null(shin_name) as MeshInstance3D
		if shin == null:
			shin = MeshInstance3D.new()
			shin.name = shin_name
			var sock_mesh := CapsuleMesh.new()
			sock_mesh.radius = 0.105
			sock_mesh.height = 0.56
			shin.mesh = sock_mesh
			shin.position = Vector3(-0.16 if side == "Left" else 0.16, 0.29, 0.0)
			visual.add_child(shin)
		shin.material_override = socks
	_add_kit_label(visual, "SponsorFront", "THOMAS LOOMES\n& CO" if is_beechlawn else "Boards.ie",
		Vector3(0.0, 1.28, -0.333), 0.0020,
		Color.WHITE if is_beechlawn or is_keeper else Color(0.025, 0.035, 0.045))
	_add_kit_label(visual, "CrestMark", "BR" if is_beechlawn else "B",
		Vector3(-0.20, 1.48, -0.335), 0.00155,
		Color(0.9, 0.95, 1.0) if is_beechlawn else Color(0.04, 0.10, 0.18))
	if is_keeper:
		_add_keeper_glove(visual, "Left")
		_add_keeper_glove(visual, "Right")
		var hair := visual.get_node_or_null("Hair") as MeshInstance3D
		if hair:
			hair.material_override = _mat(Color(0.40, 0.19, 0.09) if is_beechlawn else Color(0.16, 0.12, 0.10), 0.84)
	var head := visual.get_node_or_null("Head") as MeshInstance3D
	if head:
		var skin := _mat(Color(0.73, 0.55, 0.43), 0.68)
		skin.subsurf_scatter_enabled = true
		skin.subsurf_scatter_strength = 0.08
		head.material_override = skin

func _add_kit_label(visual: Node3D, node_name: String, label_text: String,
		at: Vector3, pixel_size: float, color: Color) -> void:
	var label := visual.get_node_or_null(node_name) as Label3D
	if label == null:
		label = Label3D.new()
		label.name = node_name
		label.font_size = 22
		label.pixel_size = pixel_size
		label.outline_size = 2
		label.outline_modulate = Color(0.02, 0.025, 0.03, 1.0)
		label.position = at
		visual.add_child(label)
	label.text = label_text
	label.modulate = color

func _add_keeper_glove(visual: Node3D, side: String) -> void:
	if use_human_visual:
		# The human asset's skinned hand part uses the keeper glove material;
		# fixed decorative spheres belong only to the older primitive fixture.
		return
	var glove_name := "KeeperGlove%s" % side
	var glove := visual.get_node_or_null(glove_name) as MeshInstance3D
	if glove == null:
		glove = MeshInstance3D.new()
		glove.name = glove_name
		var shape := SphereMesh.new()
		shape.radius = 0.115
		shape.height = 0.22
		glove.mesh = shape
		glove.scale = Vector3(0.82, 1.0, 0.62)
		glove.position = Vector3(-0.44 if side == "Left" else 0.44, 1.0, 0.0)
		visual.add_child(glove)
	var material := _mat(Color(0.86, 0.82, 0.66), 0.68)
	material.metallic = 0.0
	glove.material_override = material

func _create_control_marker(actor: FootballPlayer, enabled: bool) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "ControlMarker"
	marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := TorusMesh.new()
	ring.inner_radius = 0.39
	ring.outer_radius = 0.47
	ring.rings = 8
	ring.ring_segments = 20
	marker.mesh = ring
	marker.position.y = 0.075
	# TorusMesh already lies in the XZ plane. Rotating it buried half the ring.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.95, 0.82, 0.18, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.8, 0.55, 0.05)
	marker.material_override = material
	marker.visible = enabled
	actor.add_child(marker)

func _bind_controlled_player() -> void:
	if _spectator_mode:
		return
	if not player.status_changed.is_connected(_set_message):
		player.status_changed.connect(_set_message)
	if not player.shot_charge_changed.is_connected(_set_power):
		player.shot_charge_changed.connect(_set_power)

func _cycle_controlled_player() -> void:
	if _spectator_mode:
		return
	var outfield: Array[FootballPlayer] = []
	for teammate in _home_players:
		if teammate.profile != null and (teammate.profile.role == "outfield" or use_human_visual):
			outfield.append(teammate)
	if outfield.size() < 2:
		return
	_home_control_index = (outfield.find(player) + 1) % outfield.size()
	_set_controlled_player(outfield[_home_control_index])
	_set_message("Selected %s  ·  %d" % [player.profile.display_name, player.profile.jersey_number])

func _set_marker_visibility(actor: FootballPlayer, enabled: bool) -> void:
	var marker := actor.get_node_or_null("ControlMarker") as MeshInstance3D
	if marker:
		marker.visible = enabled

func _update_ai(delta: float) -> void:
	_transition_time_left = maxf(0.0, _transition_time_left - delta)
	_tactical_possession = _possession_reader.sample(ball, _home_players + _away_players,
		_full_time or _goal_pause_timer > 0.0)
	var controlling_team: StringName = _tactical_possession.team
	# A deflection or pass flight is not a possession win. Keep the previous
	# controlled team through loose phases so only an actual turnover resets it.
	if _tactical_possession.state == &"controlled" and controlling_team != _possession_team:
		_possession_team = controlling_team
		_transition_team = controlling_team
		_transition_time_left = 1.35
	_ai_tick -= delta
	if _ai_tick > 0.0 or _home_players.is_empty() or _away_players.is_empty():
		return
	_ai_tick = ball.tuning.ai_decision_interval
	if _tactical_possession.state == &"stopped":
		return
	var ball_position := Vector2(ball.global_position.x, ball.global_position.z)
	# Both sides read one physics snapshot at the same 5 Hz budget. Alternate
	# execution order, never grant one team a 100 ms-old view of the opponent.
	var teams := [_home_players, _away_players] if _next_home_ai else [_away_players, _home_players]
	for index in 2:
		var actors: Array[FootballPlayer] = teams[index]
		var opposition: Array[FootballPlayer] = teams[1-index]
		var intercept := _best_interception_position(actors, ball_position)
		_update_team_ai(actors, _nearest_outfielder(actors, intercept), ball_position, intercept,
			opposition, _transition_team, _transition_time_left, _tactical_possession)
	_next_home_ai = not _next_home_ai

func _best_interception_position(team_players: Array[FootballPlayer], ball_position: Vector2) -> Vector2:
	if ball.position.y > .7:
		var contact := FootballBallFlight.descending_contact(ball, 1.97, 2.7)
		if contact.is_empty(): contact = FootballBallFlight.descending_contact(ball, .35, 3.0)
		if not contact.is_empty():
			var point: Vector3 = contact.position
			return Vector2(clampf(point.x, -51.5, 51.5), clampf(point.z, -33, 33))
	var horizontal_velocity := Vector2(ball.linear_velocity.x, ball.linear_velocity.z)
	if horizontal_velocity.length() < 1.25:
		return ball_position
	var best_point := ball_position
	var best_cost := INF
	# Sample a short, cheap path at the existing 5 Hz AI decision rate. The
	# deceleration term approximates grass rolling resistance; the ball remains
	# physically authoritative and player contact still resolves in physics.
	for sample in range(1, 9):
		var arrival_time := float(sample) * 0.10
		var travel_distance := horizontal_velocity * arrival_time
		travel_distance -= horizontal_velocity.normalized() * (0.5 * 0.55 * arrival_time * arrival_time)
		var point := ball_position + travel_distance
		point.x = clampf(point.x, -FIELD_LENGTH * 0.5 + 1.0, FIELD_LENGTH * 0.5 - 1.0)
		point.y = clampf(point.y, -FIELD_WIDTH * 0.5 + 1.0, FIELD_WIDTH * 0.5 - 1.0)
		var reach_time := INF
		for actor in team_players:
			if actor.profile == null or actor.profile.role != "outfield":
				continue
			var actor_position := Vector2(actor.global_position.x, actor.global_position.z)
			var distance := actor_position.distance_to(point)
			var estimated_reach := maxf(0.0, distance - 0.85) / 6.5
			reach_time = minf(reach_time, estimated_reach)
		var cost := arrival_time + maxf(0.0, reach_time - arrival_time - 0.12) * 2.0
		if cost < best_cost:
			best_cost = cost
			best_point = point
	return best_point

func _nearest_outfielder(team_players: Array[FootballPlayer], target: Vector2) -> FootballPlayer:
	var nearest: FootballPlayer
	var nearest_distance := INF
	for actor in team_players:
		if actor.profile == null or actor.profile.role != "outfield":
			continue
		var distance := Vector2(actor.global_position.x, actor.global_position.z).distance_squared_to(target)
		if distance < nearest_distance - 0.0001 or (absf(distance-nearest_distance) < 0.0001 and nearest != null and actor.profile.starting_slot < nearest.profile.starting_slot):
			nearest = actor
			nearest_distance = distance
	return nearest

func _update_team_ai(team_players: Array[FootballPlayer], chaser: FootballPlayer,
		ball_position: Vector2, interception_position: Vector2,
		opponents: Array[FootballPlayer] = [], transition_team: StringName = &"none",
		transition_time_left := 0.0, possession: Dictionary = {}) -> void:
	if team_players.is_empty():
		return
	var team_name: StringName = team_players[0].team_name
	var snapshot: Dictionary = possession if not possession.is_empty() else _possession_reader.sample(ball, _home_players + _away_players)
	var in_possession: bool = snapshot.team == team_name
	if snapshot.state == &"controlled" and in_possession:
		# Prediction selects a runner for a travelling ball. A teammate who can
		# already play it owns the current action and carry target instead.
		var contact_player := snapshot.carrier as FootballPlayer
		if contact_player != null and contact_player._can_kick():
			chaser = contact_player
	var context := _team_tactical_context(team_name, ball_position)
	context["possession_state"] = snapshot.state
	var secondary_presser: FootballPlayer
	var counterpress_requested := not in_possession and transition_time_left > 0.0 \
		and transition_team != &"none" and team_name != transition_team \
		and ball_position.x * _team_attack_sign(team_name) > -5.0 \
		and not bool(context.get("protect_lead", false))
	var wants_second_presser := not in_possession and (bool(context.get("high_press", false)) or counterpress_requested)
	if wants_second_presser:
		var candidate := _nearest_support_presser(team_players, chaser, ball_position)
		if candidate != null and Vector2(candidate.global_position.x - ball_position.x,
				candidate.global_position.z - ball_position.y).length() <= SECOND_PRESS_RANGE:
			secondary_presser = candidate
	var counterpress_active := counterpress_requested and secondary_presser != null
	if in_possession and snapshot.state == &"controlled":
		_apply_carrier_action(chaser, team_players, opponents)
	var decisions := _team_tactics.update_team_targets(team_players, chaser, ball_position,
		interception_position, opponents, transition_team, transition_time_left,
		in_possession, secondary_presser, counterpress_active, context)
	_apply_ai_movement_decisions(team_players, decisions)

func _apply_carrier_action(carrier: FootballPlayer, team_players: Array[FootballPlayer],
		opponents: Array[FootballPlayer]) -> void:
	var action: Dictionary = _player_decisions.choose_carrier_action(carrier,
		team_players, opponents, ball)
	var previous_serial := ball.action_serial
	var action_type: StringName = action.get("type", &"none")
	if action_type not in [&"none", &"carry"]:
		ai_action_chosen.emit(carrier, action_type)
	match action.get("type", &"none"):
		&"shoot":
			carrier._do_shot(float(action.get("charge", 0.42)), 1.0, action.get("direction", Vector3.ZERO))
			if carrier._visual_shot_pending or ball.action_serial != previous_serial:
				carrier.ai_action_cooldown = 1.1
		&"through_pass":
			carrier._do_pass(true, action.get("direction", Vector3.RIGHT), false, 1.0,
				instance_from_id(int(action.receiver_id)) as FootballPlayer if action.has("receiver_id") else null)
			if carrier._visual_pass_pending or ball.action_serial != previous_serial:
				carrier.ai_action_cooldown = 0.85
		&"short_pass":
			carrier._do_pass(false, action.get("direction", Vector3.RIGHT), false, 1.0,
				instance_from_id(int(action.receiver_id)) as FootballPlayer if action.has("receiver_id") else null)
			if carrier._visual_pass_pending or ball.action_serial != previous_serial:
				carrier.ai_action_cooldown = 0.85
		&"lofted_pass", &"cross":
			carrier._do_pass(false, action.direction, false, 1.0,
				instance_from_id(int(action.receiver_id)) as FootballPlayer if action.has("receiver_id") else null,
				action_type, float(action.get("power", .65)))
			if carrier._visual_pass_pending or ball.action_serial != previous_serial:
				carrier.ai_action_cooldown = 1.0

func _apply_ai_movement_decisions(team_players: Array[FootballPlayer], decisions: Dictionary) -> void:
	for actor in team_players:
		if actor.controlled_by_human:
			continue
		var decision: Dictionary = decisions.get(actor.get_instance_id(), {})
		if decision.is_empty():
			continue
		var target: Vector2 = decision["target"]
		var offset := target - Vector2(actor.global_position.x, actor.global_position.z)
		# A primary defender collecting a loose ball must reach foot-contact
		# distance. Formation/support targets retain their broader arrival zone.
		var arrival_distance := 0.25 if decision["intent"] == "press" else 0.9
		var direction := Vector3(offset.x, 0.0, offset.y)
		if team_players.size() >= 7:
			var separation := Vector3.ZERO
			for neighbour in team_players:
				if neighbour == actor:
					continue
				var apart := actor.global_position-neighbour.global_position
				apart.y = 0.0
				if apart.length_squared() > 0.001 and apart.length_squared() < 3.24:
					separation += apart.normalized()*(1.8-apart.length())
			direction = direction.normalized()+separation.limit_length(0.7) if offset.length()>arrival_distance else separation
		actor.ai_move_direction = direction.normalized() if offset.length() > arrival_distance else Vector3.ZERO
		actor.ai_sprinting = offset.length() > 7.0
		actor.set_meta("ai_target_position", Vector3(target.x, 0.0, target.y))
		actor.set_meta("ai_role_intent", decision["intent"])
		actor.set_meta("assigned_mark", decision["assigned_mark"])

func _assign_defensive_marks(team_players: Array[FootballPlayer], chaser: FootballPlayer,
		opponents: Array[FootballPlayer], ball_position: Vector2,
		secondary_presser: FootballPlayer = null) -> Dictionary:
	return _team_tactics.assign_defensive_marks(team_players, chaser, opponents,
		ball_position, secondary_presser)

func _marking_position(defender: FootballPlayer, opponent: FootballPlayer,
		ball_position: Vector2, cover_target: Vector2) -> Vector2:
	return _team_tactics.marking_position(defender, opponent, ball_position, cover_target)

func _attacking_support_position(actor: FootballPlayer, ball_position: Vector2,
		transition_push := false) -> Vector2:
	return _team_tactics.attacking_support_position(actor, ball_position, transition_push)

func _defensive_shape_position(actor: FootballPlayer, ball_position: Vector2) -> Vector2:
	return _team_tactics.defensive_shape_position(actor, ball_position,
		_late_lead_depth(actor.team_name))

func _team_tactical_context(team_name: StringName, ball_position: Vector2) -> Dictionary:
	var score_delta := _score_delta(team_name)
	var late_game_urgency := clampf(1.0 - _remaining_time / 45.0, 0.0, 1.0)
	var ball_in_opponent_half := ball_position.x * _team_attack_sign(team_name) > 2.0
	return {
		"score_delta": score_delta,
		"urgency": late_game_urgency,
		"high_press": score_delta < 0 and late_game_urgency >= 0.25 and ball_in_opponent_half,
		"protect_lead": score_delta > 0 and late_game_urgency > 0.0,
		"late_lead_depth": _late_lead_depth(team_name),
	}

func _nearest_support_presser(team_players: Array[FootballPlayer], chaser: FootballPlayer,
		ball_position: Vector2) -> FootballPlayer:
	var nearest: FootballPlayer
	var nearest_distance := INF
	for actor in team_players:
		if actor == chaser or actor.controlled_by_human or actor.profile == null \
				or actor.profile.role != "outfield":
			continue
		var distance := Vector2(actor.global_position.x - ball_position.x,
			actor.global_position.z - ball_position.y).length_squared()
		if distance < nearest_distance:
			nearest = actor
			nearest_distance = distance
	return nearest

func _score_delta(team_name: StringName) -> int:
	if team_name == &"Beechlawn Rovers":
		return _home_score - _away_score
	return _away_score - _home_score

func _team_attack_sign(team_name: StringName) -> float:
	return 1.0 if team_name == &"Beechlawn Rovers" else -1.0

func _late_lead_depth(team_name: StringName) -> float:
	if _score_delta(team_name) <= 0:
		return 0.0
	return 5.0 * clampf(1.0 - _remaining_time / 45.0, 0.0, 1.0)

func _on_goal(team_name: String, _side: int) -> void:
	if _full_time:
		return
	if rules.direct_throw_goal(_side): return
	restart.cancel()
	if team_name == "Beechlawn Rovers":
		_home_score += 1
	else:
		_away_score += 1
	_update_score()
	_set_message("GOAL  ·  %s" % team_name)
	_boundary_pending = false
	_kickoff_team = &"Boardeaux" if team_name == "Beechlawn Rovers" else &"Beechlawn Rovers"
	_kickoff_pending = false
	_goal_pause_timer = 1.6
	_kickoff_ai_delay = 0.0
	_possession_team = &"none"
	_transition_team = &"none"
	_transition_time_left = 0.0
	# The scored ball continues into the physical net during the celebration.
	ball.freeze = false
	_set_players_physics_enabled(false)

func _finish_match() -> void:
	if _full_time:
		return
	_full_time = true
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	for actor in _home_players + _away_players:
		actor.set_physics_process(false)
	_set_message("FULL TIME  ·  Esc to title screen")

func _check_boundary_restart() -> void:
	var p := ball.global_position
	var end_out := absf(p.x)>52.5+FootballBall.RADIUS
	var side_out := absf(p.z)>34.0+FootballBall.RADIUS
	if not end_out and not side_out:
		return
	# Leave mouth crossings to GoalDetector's swept whole-ball test.
	if end_out and absf(p.z)+FootballBall.RADIUS<=GOAL_WIDTH*0.5 and p.y+FootballBall.RADIUS<=GOAL_HEIGHT:
		return
	_boundary_team = &"Boardeaux" if ball.last_touch==&"Beechlawn Rovers" else &"Beechlawn Rovers"
	_boundary_spot = Vector3(clampf(p.x,-52.4,52.4),0,signf(p.z)*34.0)
	_boundary_kind = "THROW-IN"
	if end_out:
		var attacking: StringName = &"Beechlawn Rovers" if p.x>0 else &"Boardeaux"
		var defending: StringName = &"Boardeaux" if p.x>0 else &"Beechlawn Rovers"
		if ball.last_touch==defending:
			_boundary_team=attacking
			_boundary_spot=Vector3(signf(p.x)*51.9,0,33.6 if p.z>=0 else -33.6)
			_boundary_kind="CORNER RESTART"
		else:
			_boundary_team=defending
			_boundary_spot=Vector3(signf(p.x)*47.0,0,0)
			_boundary_kind="GOAL KICK"
	restart.begin(_boundary_kind,_boundary_team,_boundary_spot)

func _resume_boundary_restart() -> void:
	# Kept for older debug callers; all actual restarts use the same controller.
	restart.begin(_boundary_kind,_boundary_team,_boundary_spot)

func _update_score() -> void:
	score_label.text = "BEECHLAWN ROVERS   %d     %d   BOARDEAUX" % [_home_score, _away_score]

func _update_clock() -> void:
	var display_time := ceili(_remaining_time)
	clock_label.text = "%02d:%02d" % [int(display_time / 60), display_time % 60]

func _set_message(message: String) -> void:
	message_label.text = message
	_message_time = 1.6

func _on_foul_committed(tackler: FootballPlayer, opponent: FootballPlayer) -> void:
	rules.adjudicate(tackler,opponent,tackler.get_meta("last_challenge",{}))

func _set_power(value: float) -> void:
	power_bar.value = value * 100.0
	power_bar.visible = value > 0.0

func _mat(color: Color, roughness := 0.86) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _box(parent: Node3D, name: String, size: Vector3, at: Vector3,
		material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _add_line_segment(tool: SurfaceTool, a: Vector2, b: Vector2, width: float) -> void:
	if terrain_enabled and a.distance_to(b)>0.85:
		var steps := ceili(a.distance_to(b)/0.8)
		for index in steps:
			_add_line_segment(tool,a.lerp(b,float(index)/steps),a.lerp(b,float(index+1)/steps),width)
		return
	var direction := (b - a).normalized()
	var normal := Vector2(-direction.y, direction.x) * width * 0.5
	if terrain_enabled:
		a += normal.normalized()*sin(a.x*2.3+a.y*1.7)*0.009
		b += normal.normalized()*sin(b.x*2.3+b.y*1.7)*0.009
		normal *= 0.91+0.13*sin((a.x+a.y)*4.1)
	var a1 := Vector3(a.x + normal.x, 0.014, a.y + normal.y)
	var a2 := Vector3(a.x - normal.x, 0.014, a.y - normal.y)
	var b1 := Vector3(b.x - normal.x, 0.014, b.y - normal.y)
	var b2 := Vector3(b.x + normal.x, 0.014, b.y + normal.y)
	if terrain_enabled:
		a1.y = PitchSurface.height_at(a1.x,a1.z)+0.008
		a2.y = PitchSurface.height_at(a2.x,a2.z)+0.008
		b1.y = PitchSurface.height_at(b1.x,b1.z)+0.008
		b2.y = PitchSurface.height_at(b2.x,b2.z)+0.008
	tool.add_vertex(a1)
	tool.add_vertex(a2)
	tool.add_vertex(b1)
	tool.add_vertex(a1)
	tool.add_vertex(b1)
	tool.add_vertex(b2)

func _add_line_rect(tool: SurfaceTool, x0: float, z0: float, x1: float, z1: float, width: float) -> void:
	_add_line_segment(tool, Vector2(x0,z0), Vector2(x1,z0), width)
	_add_line_segment(tool, Vector2(x1,z0), Vector2(x1,z1), width)
	_add_line_segment(tool, Vector2(x1,z1), Vector2(x0,z1), width)
	_add_line_segment(tool, Vector2(x0,z1), Vector2(x0,z0), width)

func _build_line_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := FIELD_LENGTH * 0.5
	var hz := FIELD_WIDTH * 0.5
	var width := 0.105
	_add_line_rect(tool, -hx,-hz,hx,hz,width)
	_add_line_segment(tool, Vector2(0,-hz), Vector2(0,hz), width)
	_add_line_rect(tool, -hx,-20.16,-hx+16.5,20.16,width)
	_add_line_rect(tool, hx-16.5,-20.16,hx,20.16,width)
	_add_line_rect(tool, -hx,-9.16,-hx+5.5,9.16,width)
	_add_line_rect(tool, hx-5.5,-9.16,hx,9.16,width)
	for i in 64:
		var a0 := TAU * float(i) / 64.0
		var a1 := TAU * float(i+1) / 64.0
		_add_line_segment(tool, Vector2(cos(a0),sin(a0))*9.15,
			Vector2(cos(a1),sin(a1))*9.15,width)
	# Only the 9.15 m penalty-spot circle outside the 16.5 m area is painted.
	var half_angle := acos(5.5 / 9.15)
	for end_sign in [-1.0, 1.0]:
		var centre := Vector2(end_sign * (hx - 11.0), 0)
		for j in 32:
			var a0 := -half_angle + 2.0 * half_angle * float(j) / 32.0
			var a1 := -half_angle + 2.0 * half_angle * float(j+1) / 32.0
			_add_line_segment(tool, centre + Vector2(-end_sign*cos(a0), sin(a0))*9.15,
				centre + Vector2(-end_sign*cos(a1), sin(a1))*9.15, width)
	tool.generate_normals()
	return tool.commit()

func build_pitch() -> void:
	var turf_shader := load("res://shaders/park_grass.gdshader") as Shader
	var grass := ShaderMaterial.new()
	grass.shader = turf_shader
	grass.set_shader_parameter("field_length", FIELD_LENGTH)
	grass.set_shader_parameter("field_width", FIELD_WIDTH)
	grass.set_shader_parameter("grass_albedo",
		load("res://assets/environment/surfaces/ambientcg/Grass005/Grass005_1K-JPG_Color.jpg"))
	var pitch := MeshInstance3D.new()
	pitch.name = "SundayLeagueTurf"
	var plane := PlaneMesh.new()
	plane.size = Vector2(FIELD_LENGTH, FIELD_WIDTH)
	plane.subdivide_width = 6
	plane.subdivide_depth = 4
	pitch.mesh = plane
	if terrain_enabled:
		pitch.mesh = PitchSurface.make_mesh()
	pitch.material_override = grass
	pitch.position.y = -0.06
	if terrain_enabled:
		pitch.position.y = 0.0
	$Pitch.add_child(pitch)
	var lines := MeshInstance3D.new()
	lines.name = "FadedChalk"
	lines.mesh = _build_line_mesh()
	lines.material_override = _mat(Color(0.72, 0.72, 0.64, 0.78))
	if terrain_enabled:
		var paint := ShaderMaterial.new()
		paint.shader = load("res://shaders/chalk_paint.gdshader")
		lines.material_override = paint
	$Pitch.add_child(lines)
	var ground := StaticBody3D.new()
	ground.name = "PitchCollision"
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(FIELD_LENGTH+6.0,0.15,FIELD_WIDTH+6.0)
	shape.shape = box_shape
	shape.position.y = -0.14
	if terrain_enabled:
		shape.shape = PitchSurface.make_collision()
		shape.position.y = 0.0
	ground.add_child(shape)
	$Pitch.add_child(ground)

func build_goals() -> void:
	_build_goal("PositiveEnd", 1.0)
	_build_goal("NegativeEnd", -1.0)

func _build_goal(goal_name: String, end_sign: float) -> void:
	var root := Node3D.new()
	root.name = goal_name
	root.position.x = end_sign * FIELD_LENGTH * 0.5
	root.rotation.y = 0.0 if end_sign > 0.0 else PI
	$Goals.add_child(root)
	var goal_path := "res://assets/environment/kilmore/park_goal.glb" if terrain_enabled else "res://assets/environment/football_goal.glb"
	var goal_asset := load(goal_path) as PackedScene
	if goal_asset:
		var visual := goal_asset.instantiate() as Node3D
		visual.name = "BlenderGoalModel"
		visual.rotation.y = -PI * 0.5 if terrain_enabled else PI * 0.5 * end_sign
		root.add_child(visual)
		if terrain_enabled:
			for node in visual.find_children("SaggingNet", "MeshInstance3D", true, false):
				var net := node as MeshInstance3D
				var original := net.mesh.surface_get_material(0) as StandardMaterial3D
				var net_material := ShaderMaterial.new()
				net_material.shader=load("res://shaders/goal_net.gdshader")
				net_material.set_shader_parameter("net_texture",original.albedo_texture)
				net.material_override=net_material
				_net_impacts[int(end_sign)]={"mesh":net,"material":net_material,"age":2.0}
	var frame := StaticBody3D.new()
	frame.name = "FrameCollision"
	root.add_child(frame)
	var post_half_span := GOAL_WIDTH * 0.5 + 0.06
	_add_goal_collider(frame,Vector3(0,(GOAL_HEIGHT+0.06)*0.5,-post_half_span),Vector3(.15,GOAL_HEIGHT+0.06,.12))
	_add_goal_collider(frame,Vector3(0,(GOAL_HEIGHT+0.06)*0.5,post_half_span),Vector3(.15,GOAL_HEIGHT+0.06,.12))
	_add_goal_collider(frame,Vector3(0,GOAL_HEIGHT+0.06,0),Vector3(.15,.12,GOAL_WIDTH+0.12))
	# Net surfaces have their own bodies and contact identity, separate from posts.
	var net_body := StaticBody3D.new()
	net_body.name="NetCollision"
	net_body.set_meta("goal_net_end",int(end_sign))
	root.add_child(net_body)
	_add_goal_collider(net_body,Vector3(GOAL_DEPTH,GOAL_HEIGHT*0.5,0),Vector3(.12,GOAL_HEIGHT,GOAL_WIDTH))
	_add_goal_collider(net_body,Vector3(GOAL_DEPTH*0.5,GOAL_HEIGHT+0.06,0),Vector3(GOAL_DEPTH,.08,GOAL_WIDTH+0.12))
	for side in [-1.0,1.0]:
		_add_goal_collider(net_body,Vector3(GOAL_DEPTH*.5,GOAL_HEIGHT*.5,side*GOAL_WIDTH*.5),Vector3(GOAL_DEPTH,GOAL_HEIGHT,.06))
	var net_physics := PhysicsMaterial.new()
	net_physics.bounce=.05
	net_physics.friction=.75
	net_body.physics_material_override=net_physics
	var detector := GoalDetector.new()
	detector.name = "GoalDetector"
	detector.defending_end = int(end_sign)
	detector.field_length = FIELD_LENGTH
	detector.goal_width = GOAL_WIDTH
	detector.goal_height = GOAL_HEIGHT
	detector.ball = ball
	root.add_child(detector)

func _add_goal_collider(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.position = at
	body.add_child(collision)

func build_park_edge() -> void:
	KilmoreDriveVenue.build($ParkEdge, FIELD_LENGTH, FIELD_WIDTH, use_human_visual)

func _on_net_contact(body: Node3D, point: Vector3, impact_velocity: Vector3) -> void:
	var end_sign: int = body.get_meta("goal_net_end",0)
	if not _net_impacts.has(end_sign) or impact_velocity.length()<.6: return
	var impact: Dictionary = _net_impacts[end_sign]
	var mesh := impact.mesh as MeshInstance3D
	impact.age=0.0
	var material := impact.material as ShaderMaterial
	material.set_shader_parameter("impact_point",mesh.to_local(point))
	material.set_shader_parameter("impact_vector",mesh.global_basis.inverse()*impact_velocity.normalized()*clampf(impact_velocity.length()*.022,.05,.42))
	material.set_shader_parameter("impact_age",0.0)
	ball.touched.emit(&"net",impact_velocity.length())
