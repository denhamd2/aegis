extends Node3D
## Repeatable moving final-mesh evidence on the actual Kilmore match pitch.
## Debug review only: the normal game always opens on its title screen.
var game: Node3D
var actor: FootballPlayer
var ball: FootballBall
var scenario := "shot"
var tick := 0
var events: Array[Dictionary] = []
var held := false
var started := false
var _continue_callback: JavaScriptObject

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 1000
	if OS.has_feature("web"):
		scenario = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('scenario') || 'shot'"))
	game = load("res://scenes/match_11v11.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.call("_set_players_physics_enabled", false)
	(game.get_node("HUD") as CanvasLayer).visible = false
	for player in game._home_players + game._away_players:
		player.visible = false
		player.controlled_by_human = false
		player.process_mode = Node.PROCESS_MODE_DISABLED
	if game.has_node("Referee"): game.get_node("Referee").visible = false
	ball = game.get_node("Ball") as FootballBall
	ball.freeze = true
	actor = game._home_players[0]
	if scenario == "keeper":
		for player in game._away_players:
			if player.profile.role == "goalkeeper": actor = player
	actor.visible = true
	actor.process_mode = Node.PROCESS_MODE_INHERIT
	if actor.has_node("ControlMarker"): actor.get_node("ControlMarker").visible = false
	actor.global_position = Vector3(49.5, 0, 0) if scenario == "keeper" else Vector3(32, 0, 0)
	actor.rotation.y = PI / 2.0 if scenario == "keeper" else -PI / 2.0
	actor._flat_direction = Vector3.LEFT if scenario == "keeper" else Vector3.RIGHT
	actor.velocity = Vector3.ZERO if scenario == "keeper" else Vector3.RIGHT * actor.tuning.sprint_speed
	actor.ai_move_direction = Vector3.ZERO if scenario == "keeper" else Vector3.RIGHT
	actor.ai_sprinting = scenario != "keeper"
	ball.global_position = Vector3(43.5, 1.2, 0.25) if scenario == "keeper" else actor.global_position + Vector3(0.65, 0.13, 0)
	ball.last_touch = &"Beechlawn Rovers"
	ball.last_action = &"shot" if scenario == "keeper" else &"dribble"
	ball.action_serial += 1
	ball.angular_velocity = Vector3.ZERO
	actor.reset_physics_interpolation()
	ball.reset_physics_interpolation()
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = actor.global_position + Vector3(1.5, 3.0, 7.8)
	camera.fov = 32.0
	camera.look_at(actor.global_position + Vector3(1.5, 0.9, 0))
	camera.current = true
	var environment := (game.get_node("WorldEnvironment") as WorldEnvironment).environment
	(environment.sky.sky_material as ShaderMaterial).set_shader_parameter("dark_sky_lift", 0.6)
	ball.touched.connect(func(kind: StringName, speed: float):
		if kind in [&"pass", &"shot", &"goalkeeper_save", &"goalkeeper_catch"]:
			events.append({"tick": tick, "event": str(kind), "speed": speed}))
	if OS.has_feature("web"):
		_continue_callback = JavaScriptBridge.create_callback(_continue_capture)
		JavaScriptBridge.get_interface("window").BR_GAMEPLAY_CONTINUE = _continue_callback
	Engine.max_fps = 15
	await get_tree().physics_frame
	ball.freeze = false
	ball.linear_velocity = Vector3(14, 2, 0) if scenario == "keeper" else Vector3.RIGHT * actor.tuning.sprint_speed
	actor.set_physics_process(true)
	if scenario == "pass": actor._do_pass(false, Vector3.RIGHT)
	elif scenario == "shot": actor._do_shot(0.55)
	started = true

func _physics_process(_delta: float) -> void:
	if not started or held: return
	tick += 1
	if tick % 6 == 0 and OS.has_feature("web"):
		held = true
		call_deferred("_hold_capture")

func _hold_capture() -> void:
	get_tree().paused = true
	var visual := actor.get_node("Visual") as FootballerVisual
	var clip_time := visual.animation_player.current_animation_position if visual.animation_player.current_animation != &"" else 0.0
	var snapshot := {"tick": tick, "scenario": scenario, "events": events,
		"action": str(visual._active_action), "clip_time": clip_time,
		"foot_gap": actor._receive_contact_position().distance_to(ball.global_position),
		"ball": [ball.position.x, ball.position.y, ball.position.z], "done": tick >= 48}
	JavaScriptBridge.eval("window.BR_GAMEPLAY_CAPTURE = " + JSON.stringify(snapshot))

func _continue_capture(_arguments: Array) -> void:
	if tick >= 48: return
	held = false
	get_tree().paused = false
