extends Node3D
## 4v4 blockout for the Sunday-league match prototype.

const FIELD_LENGTH := 105.0
const FIELD_WIDTH := 68.0
const GOAL_WIDTH := 7.32
const GOAL_HEIGHT := 2.44
const GOAL_DEPTH := 1.8
const SECOND_PRESS_RANGE := 18.0
@export_range(30.0, 600.0, 30.0) var short_match_seconds := 180.0

@onready var ball: FootballBall = $Ball
@onready var player: FootballPlayer = $Player
@onready var camera_rig: Node3D = $BroadcastCamera
@onready var score_label: Label = $HUD/Panel/Score
@onready var clock_label: Label = $HUD/Panel/Clock
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

func _ready() -> void:
	_remaining_time = short_match_seconds
	_home_team = load("res://data/teams/beechlawn_rovers.tres") as FootballTeam
	_away_team = load("res://data/teams/bordeaux.tres") as FootballTeam
	_assemble_teams()
	build_pitch()
	build_goals()
	build_park_edge()
	$Goals/PositiveEnd/GoalDetector.goal_scored.connect(_on_goal)
	$Goals/NegativeEnd/GoalDetector.goal_scored.connect(_on_goal)
	_setup_kickoff_positions(_kickoff_team)
	ball.freeze = true
	_set_players_physics_enabled(false)
	_bind_controlled_player()
	_update_score()
	_update_clock()
	_set_message("KICK OFF  ·  E pass  /  Q through-ball")

func _process(delta: float) -> void:
	if not _full_time:
		if _goal_pause_timer > 0.0:
			_goal_pause_timer = maxf(0.0, _goal_pause_timer - delta)
			if _goal_pause_timer == 0.0:
				_prepare_kickoff(_kickoff_team)
		elif _kickoff_pending:
			_update_kickoff_input(delta)
		else:
			_update_ai(delta)
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
	if not _full_time and not _kickoff_pending and _goal_pause_timer <= 0.0 \
			and Input.is_action_just_pressed("switch_player"):
		_cycle_controlled_player()

func _update_kickoff_input(delta: float) -> void:
	if _kickoff_team == &"Beechlawn Rovers":
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
	ball.last_touch = &"none"

func _prepare_kickoff(kicking_team: StringName) -> void:
	_kickoff_team = kicking_team
	_setup_kickoff_positions(kicking_team)
	_kickoff_pending = true
	_goal_pause_timer = 0.0
	_kickoff_ai_delay = 0.0
	if kicking_team == &"Beechlawn Rovers":
		var taker := _kickoff_taker(_home_players)
		if taker != null and taker != player:
			_set_controlled_player(taker)
		_set_message("KICK OFF  ·  E pass  /  Q through-ball")
	else:
		_kickoff_ai_delay = 1.0
		_set_message("Bordeaux ready to kick off")

func _kickoff_taker(team_players: Array[FootballPlayer]) -> FootballPlayer:
	for actor in team_players:
		if actor.profile != null and actor.profile.role == "outfield" and actor.profile.starting_slot == "center":
			return actor
	return _nearest_outfielder(team_players, Vector2.ZERO)

func _start_kickoff(through: bool) -> void:
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

func _set_players_physics_enabled(enabled: bool) -> void:
	for actor in _home_players + _away_players:
		actor.set_physics_process(enabled)

func _set_controlled_player(next_player: FootballPlayer) -> void:
	if next_player == null or next_player == player:
		return
	var old_player := player
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
	var home_control_profile := _profile_for_slot(_home_team, "center")
	_configure_player(player, home_control_profile, _home_team, 1.0, true)
	_home_players.append(player)
	for profile in _home_team.roster:
		if profile != home_control_profile:
			_home_players.append(_spawn_player(player, profile, _home_team, 1.0))
	for profile in _away_team.roster:
		_away_players.append(_spawn_player(player, profile, _away_team, -1.0))
	_create_control_marker(player, true)
	_home_control_index = _home_players.find(player)
	camera_rig.set("player", player)

func _profile_for_slot(team: FootballTeam, slot: String) -> FootballerProfile:
	for profile in team.roster:
		if profile.starting_slot == slot:
			return profile
	return team.roster[0] if not team.roster.is_empty() else null

func _spawn_player(template: FootballPlayer, profile: FootballerProfile,
		team: FootballTeam, direction: float) -> FootballPlayer:
	var actor := template.duplicate() as FootballPlayer
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
	var visual := actor.get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	var shirt_color := team.goalkeeper_kit_color if profile.role == "goalkeeper" else team.primary_kit_color
	for node_path in ["Torso", "LeftArm", "RightArm"]:
		var mesh := visual.get_node_or_null(node_path) as MeshInstance3D
		if mesh:
			var material := StandardMaterial3D.new()
			material.albedo_color = shirt_color
			material.roughness = 0.82
			mesh.material_override = material
	var number_label := visual.get_node_or_null("Number8") as Label3D
	if number_label:
		number_label.text = str(profile.jersey_number) if profile.jersey_number > 0 else ""
		number_label.visible = profile.jersey_number > 0
		if direction < 0.0:
			number_label.rotation.y = 0.0

func _create_control_marker(actor: FootballPlayer, enabled: bool) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "ControlMarker"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.39
	ring.outer_radius = 0.47
	ring.rings = 8
	ring.ring_segments = 20
	marker.mesh = ring
	marker.position.y = 0.025
	marker.rotation.x = PI * 0.5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.95, 0.82, 0.18, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.8, 0.55, 0.05)
	marker.material_override = material
	marker.visible = enabled
	actor.add_child(marker)

func _bind_controlled_player() -> void:
	if not player.status_changed.is_connected(_set_message):
		player.status_changed.connect(_set_message)
	if not player.shot_charge_changed.is_connected(_set_power):
		player.shot_charge_changed.connect(_set_power)

func _cycle_controlled_player() -> void:
	var outfield: Array[FootballPlayer] = []
	for teammate in _home_players:
		if teammate.profile != null and teammate.profile.role == "outfield":
			outfield.append(teammate)
	if outfield.size() < 2:
		return
	var old_player := player
	_home_control_index = (outfield.find(player) + 1) % outfield.size()
	player.controlled_by_human = false
	player = outfield[_home_control_index]
	player.controlled_by_human = true
	player.ai_move_direction = Vector3.ZERO
	player.ai_sprinting = false
	_set_power(0.0)
	_set_marker_visibility(old_player, false)
	_set_marker_visibility(player, true)
	camera_rig.set("player", player)
	_bind_controlled_player()
	_set_message("Selected %s  ·  %d" % [player.profile.display_name, player.profile.jersey_number])

func _set_marker_visibility(actor: FootballPlayer, enabled: bool) -> void:
	var marker := actor.get_node_or_null("ControlMarker") as MeshInstance3D
	if marker:
		marker.visible = enabled

func _update_ai(delta: float) -> void:
	_transition_time_left = maxf(0.0, _transition_time_left - delta)
	if ball.last_touch != &"none" and ball.last_touch != _possession_team:
		_possession_team = ball.last_touch
		_transition_team = ball.last_touch
		_transition_time_left = 1.35
	_ai_tick -= delta
	if _ai_tick > 0.0:
		return
	_ai_tick = 0.20
	if _home_players.is_empty() or _away_players.is_empty():
		return
	var ball_position := Vector2(ball.global_position.x, ball.global_position.z)
	var home_intercept := _best_interception_position(_home_players, ball_position)
	var away_intercept := _best_interception_position(_away_players, ball_position)
	var home_chaser := _nearest_outfielder(_home_players, home_intercept)
	var away_chaser := _nearest_outfielder(_away_players, away_intercept)
	_update_team_ai(_home_players, home_chaser, ball_position, home_intercept,
		_away_players, _transition_team, _transition_time_left)
	_update_team_ai(_away_players, away_chaser, ball_position, away_intercept,
		_home_players, _transition_team, _transition_time_left)

func _best_interception_position(team_players: Array[FootballPlayer], ball_position: Vector2) -> Vector2:
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
		if distance < nearest_distance:
			nearest = actor
			nearest_distance = distance
	return nearest

func _update_team_ai(team_players: Array[FootballPlayer], chaser: FootballPlayer,
		ball_position: Vector2, interception_position: Vector2,
		opponents: Array[FootballPlayer] = [], transition_team: StringName = &"none",
		transition_time_left := 0.0) -> void:
	if team_players.is_empty():
		return
	var team_name: StringName = team_players[0].team_name
	var in_possession := ball.last_touch == team_name
	var context := _team_tactical_context(team_name, ball_position)
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
	if in_possession:
		_apply_carrier_action(chaser, team_players, opponents)
	var decisions := _team_tactics.update_team_targets(team_players, chaser, ball_position,
		interception_position, opponents, transition_team, transition_time_left,
		in_possession, secondary_presser, counterpress_active, context)
	_apply_ai_movement_decisions(team_players, decisions)

func _apply_carrier_action(carrier: FootballPlayer, team_players: Array[FootballPlayer],
		opponents: Array[FootballPlayer]) -> void:
	var action: Dictionary = _player_decisions.choose_carrier_action(carrier,
		team_players, opponents, ball)
	match action.get("type", &"none"):
		&"shoot":
			carrier._do_shot(float(action.get("charge", 0.42)))
			carrier.ai_action_cooldown = 1.1
		&"through_pass":
			carrier._do_pass(true, action.get("direction", Vector3.RIGHT))
			carrier.ai_action_cooldown = 0.85

func _apply_ai_movement_decisions(team_players: Array[FootballPlayer], decisions: Dictionary) -> void:
	for actor in team_players:
		if actor.controlled_by_human:
			continue
		var decision: Dictionary = decisions.get(actor.get_instance_id(), {})
		if decision.is_empty():
			continue
		var target: Vector2 = decision["target"]
		var offset := target - Vector2(actor.global_position.x, actor.global_position.z)
		var direction := Vector3(offset.x, 0.0, offset.y)
		actor.ai_move_direction = direction.normalized() if offset.length() > 0.9 else Vector3.ZERO
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
	if team_name == "Beechlawn Rovers":
		_home_score += 1
	else:
		_away_score += 1
	_update_score()
	_set_message("GOAL  ·  %s" % team_name)
	_kickoff_team = &"Bordeaux" if team_name == "Beechlawn Rovers" else &"Beechlawn Rovers"
	_kickoff_pending = false
	_goal_pause_timer = 1.1
	_kickoff_ai_delay = 0.0
	_possession_team = &"none"
	_transition_team = &"none"
	_transition_time_left = 0.0
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
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
	_set_message("FULL TIME")

func _update_score() -> void:
	score_label.text = "BEECHLAWN ROVERS   %d     %d   BORDEAUX" % [_home_score, _away_score]

func _update_clock() -> void:
	var display_time := ceili(_remaining_time)
	clock_label.text = "%02d:%02d" % [int(display_time / 60), display_time % 60]

func _set_message(message: String) -> void:
	message_label.text = message
	_message_time = 1.6

func _on_foul_committed(_tackler: FootballPlayer, opponent: FootballPlayer) -> void:
	var player_name := opponent.profile.display_name if opponent.profile != null else "opponent"
	_set_message("FOUL  ·  Late slide challenge on %s" % player_name)

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
	var direction := (b - a).normalized()
	var normal := Vector2(-direction.y, direction.x) * width * 0.5
	var a1 := Vector3(a.x + normal.x, 0.014, a.y + normal.y)
	var a2 := Vector3(a.x - normal.x, 0.014, a.y - normal.y)
	var b1 := Vector3(b.x - normal.x, 0.014, b.y - normal.y)
	var b2 := Vector3(b.x + normal.x, 0.014, b.y + normal.y)
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
	for x in [-hx+11.0, hx-11.0]:
		for j in 8:
			var a0 := deg_to_rad(48.0 + float(j)*12.0)
			var a1 := deg_to_rad(60.0 + float(j)*12.0)
			_add_line_segment(tool, Vector2(x,0)+Vector2(cos(a0),sin(a0))*9.15,
				Vector2(x,0)+Vector2(cos(a1),sin(a1))*9.15,width)
	tool.generate_normals()
	return tool.commit()

func build_pitch() -> void:
	var turf_shader := load("res://shaders/park_grass.gdshader") as Shader
	var grass := ShaderMaterial.new()
	grass.shader = turf_shader
	grass.set_shader_parameter("field_length", FIELD_LENGTH)
	grass.set_shader_parameter("field_width", FIELD_WIDTH)
	var pitch := MeshInstance3D.new()
	pitch.name = "SundayLeagueTurf"
	var plane := PlaneMesh.new()
	plane.size = Vector2(FIELD_LENGTH, FIELD_WIDTH)
	plane.subdivide_width = 6
	plane.subdivide_depth = 4
	pitch.mesh = plane
	pitch.material_override = grass
	pitch.position.y = -0.06
	$Pitch.add_child(pitch)
	var lines := MeshInstance3D.new()
	lines.name = "FadedChalk"
	lines.mesh = _build_line_mesh()
	lines.material_override = _mat(Color(0.82, 0.82, 0.72, 0.84))
	$Pitch.add_child(lines)
	var ground := StaticBody3D.new()
	ground.name = "PitchCollision"
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(FIELD_LENGTH+6.0,0.15,FIELD_WIDTH+6.0)
	shape.shape = box_shape
	shape.position.y = -0.14
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
	var goal_asset := load("res://assets/environment/football_goal.glb") as PackedScene
	if goal_asset:
		var visual := goal_asset.instantiate() as Node3D
		visual.name = "BlenderGoalModel"
		visual.rotation.y = PI * 0.5 * end_sign
		root.add_child(visual)
	var frame := StaticBody3D.new()
	frame.name = "FrameCollision"
	root.add_child(frame)
	var post_half_span := GOAL_WIDTH * 0.5 + 0.06
	_add_goal_collider(frame,Vector3(0,(GOAL_HEIGHT+0.06)*0.5,-post_half_span),Vector3(.15,GOAL_HEIGHT+0.06,.12))
	_add_goal_collider(frame,Vector3(0,(GOAL_HEIGHT+0.06)*0.5,post_half_span),Vector3(.15,GOAL_HEIGHT+0.06,.12))
	_add_goal_collider(frame,Vector3(0,GOAL_HEIGHT+0.06,0),Vector3(.15,.12,GOAL_WIDTH+0.12))
	_add_goal_collider(frame,Vector3(GOAL_DEPTH,GOAL_HEIGHT*0.5,0),Vector3(.12,GOAL_HEIGHT,GOAL_WIDTH))
	_add_goal_collider(frame,Vector3(GOAL_DEPTH*0.5,GOAL_HEIGHT+0.06,0),Vector3(GOAL_DEPTH,.08,GOAL_WIDTH+0.12))
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
	var fence_material := _mat(Color(0.24,0.28,0.24),0.95)
	var house_materials := [_mat(Color(0.60,0.48,0.37)),_mat(Color(0.72,0.68,0.57)),_mat(Color(0.54,0.59,0.55))]
	for side in [-1.0,1.0]:
		var fence := _box($ParkEdge,"BoundaryWall_%s" % side,Vector3(FIELD_LENGTH+8,.8,.22),Vector3(0,.4,side*39.0),fence_material)
		for index in 9:
			var house := Node3D.new()
			house.name = "House_%s_%02d" % [side,index]
			house.position = Vector3(-46.0+index*11.5,0,side*(47.0+(index%3)*2.0))
			house.rotation.y = PI if side < 0.0 else 0.0
			$ParkEdge.add_child(house)
			_box(house,"Facade",Vector3(8.6,4.2,5.0),Vector3(0,2.1,0),house_materials[index%house_materials.size()])
			_box(house,"Roof",Vector3(9.0,.42,5.8),Vector3(0,4.4,0),_mat(Color(0.28,0.24,0.22)))
			for window_side in [-1.0,1.0]:
				_box(house,"Window",Vector3(1.05,1.1,.08),Vector3(window_side*2.5,2.6,-2.55),_mat(Color(.14,.23,.27),.32))
			_box(house,"FrontDoor",Vector3(.95,2.05,.12),Vector3(0,1.02,-2.57),_mat(Color(.26,.20,.16)))
	# Primitive vegetation and architecture stay instanced and unshadowed where
	# possible; the park edge is a distant backdrop, not a foreground set.
	for side in [-1.0,1.0]:
		for index in 11:
			var tree := Node3D.new()
			tree.position = Vector3(-50.0+index*10.0,0,side*(42.0+(index%2)*2.5))
			$ParkEdge.add_child(tree)
			_box(tree,"Trunk",Vector3(.42,4.0,.42),Vector3(0,2,0),_mat(Color(.25,.19,.13)))
			var crown := MeshInstance3D.new()
			var crown_mesh := SphereMesh.new()
			crown_mesh.radius = 2.4
			crown_mesh.height = 4.8
			crown.mesh = crown_mesh
			crown.position.y = 5.2
			crown.material_override = _mat(Color(.15,.27,.16))
			tree.add_child(crown)
