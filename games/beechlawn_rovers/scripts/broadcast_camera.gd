extends Node3D
## Original camera families with shared prediction and camera-relative controls.
const Presets := preload("res://scripts/gameplay_camera_presets.gd")
@export var height := 12.0
@export var depth := 26.0
@export var tracking_speed := 3.8
@export var ball_lead := 0.28
@onready var camera: Camera3D = $Camera3D
@onready var ball: FootballBall = get_node("../Ball")
var player: Node3D
var preset_id: StringName = Presets.DEFAULT
var presentation_override := false
var _focus := Vector3.ZERO
var _distance_scale := 1.0
var _review_view := false
var _site_review_callback: JavaScriptObject

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	player = get_node("../Player")
	preset_id = Presets.valid_id(MatchSession.camera_preset)
	apply_settings()
	camera.make_current()
	reset_tracking()
	if OS.has_feature("web") and OS.has_feature("debug"):
		_site_review_callback = JavaScriptBridge.create_callback(_site_review)
		JavaScriptBridge.get_interface("window").BEECHLAWN_SITE_VIEW = _site_review_callback
		var query_preset = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('camera')")
		if query_preset != null:
			preset_id = Presets.valid_id(StringName(str(query_preset)))
			apply_settings()
			reset_tracking()
		var view = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('view')")
		var views := {
			"touchline": [Vector3(4, 2.4, 37), Vector3(0, 0.9, 0), 55.0],
			"goal": [Vector3(59, 3.2, 11), Vector3(43, 1, 0), 62.0],
			"corner": [Vector3(-56, 6, 37), Vector3(-27, 0.7, 0), 60.0],
			"player": [Vector3(-1, 1.4, 3), Vector3(-0.65, 1, 0), 42.0],
		}
		if view != null and views.has(str(view)):
			var shot: Array = views[str(view)]
			global_position = shot[0]
			camera.fov = shot[2]
			camera.look_at(shot[1], Vector3.UP)
			_review_view = true

func _site_review(arguments: Array) -> void:
	if not arguments.is_empty() and str(arguments[0]) == "overhead":
		# Debug-only whole-site view; gameplay presets and preferences stay intact.
		_review_view = true
		global_position = Vector3(-76, 180, -15)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 200.0
		camera.look_at(Vector3(global_position.x, 0, global_position.z), Vector3.FORWARD)
	else:
		_review_view = false
		apply_settings()
		reset_tracking()

func _exit_tree() -> void:
	if OS.has_feature("web") and OS.has_feature("debug"):
		JavaScriptBridge.eval("window.BEECHLAWN_SITE_VIEW = undefined")

func apply_settings() -> void:
	var preset: Dictionary = Presets.PRESETS[preset_id]
	var offset: Vector3 = preset["offset"]
	height = maxf(2.0, offset.y + MatchSession.camera_height)
	depth = absf(offset.z)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if preset["mode"] == &"overhead" else Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = clampf(float(preset["fov"]) - MatchSession.camera_zoom * 12.0, 28.0, 78.0)
	camera.size = 78.0 * (1.0 - MatchSession.camera_zoom * 0.25)
	if OS.has_feature("web") and OS.has_feature("debug"):
		JavaScriptBridge.eval("window.BEECHLAWN_CAMERA_PRESET = '%s'" % str(preset_id))

func cycle_preset() -> String:
	var ids := Presets.PRESETS.keys()
	preset_id = ids[(ids.find(preset_id) + 1) % ids.size()]
	MatchSession.camera_preset = preset_id
	MatchSession.save_preferences()
	apply_settings()
	return str(Presets.PRESETS[preset_id]["name"])

func reset_tracking() -> void:
	if ball == null:
		return
	_focus = ball.global_position
	_focus.y = 0.0
	_distance_scale = 1.0
	_update_camera(1.0, true)

func _process(delta: float) -> void:
	if _review_view or presentation_override or player == null or ball == null:
		return
	var lead := ball.get_global_transform_interpolated().origin + ball.linear_velocity * ball_lead
	var focus := lead if MatchSession.is_spectator() else player.get_global_transform_interpolated().origin.lerp(lead, 0.78)
	if Presets.PRESETS[preset_id]["mode"] == &"player":
		focus = player.get_global_transform_interpolated().origin.lerp(lead, 0.22)
	focus.x = clampf(focus.x, -49.0, 49.0)
	focus.z = clampf(focus.z, -30.0, 30.0)
	focus.y = 0.0
	_focus = _focus.lerp(focus, 1.0 - exp(-tracking_speed * delta))
	var gap := 0.0 if MatchSession.is_spectator() else player.global_position.distance_to(ball.global_position)
	var widen := maxf(clampf((ball.linear_velocity.length() - 13.0) / 18.0, 0.0, 0.28),
		clampf((gap - 10.0) / 35.0, 0.0, 0.35))
	_distance_scale = lerpf(_distance_scale, 1.0 + widen, 1.0 - exp(-2.8 * delta))
	_update_camera(delta)

func _update_camera(delta: float, snap := false) -> void:
	var preset: Dictionary = Presets.PRESETS[preset_id]
	var mode: StringName = preset["mode"]
	var offset: Vector3 = preset["offset"]
	offset.y = height
	var target_focus := _focus
	if mode in [&"end_to_end", &"player"]:
		var attack_sign := float(player.get("attack_sign")) if player != null else 1.0
		offset.x *= attack_sign
	if mode == &"overhead":
		target_focus = Vector3.ZERO
	else:
		offset = offset.rotated(Vector3.UP, deg_to_rad(MatchSession.camera_angle))
	var target := offset if mode in [&"tripod", &"overhead"] else target_focus + offset * _distance_scale
	global_position = target if snap else global_position.lerp(target, 1.0 - exp(-tracking_speed * delta))
	camera.look_at(target_focus + Vector3.UP * (0.9 if mode == &"player" else 0.0),
		Vector3.BACK.rotated(Vector3.UP, deg_to_rad(MatchSession.camera_angle)) if mode == &"overhead" else Vector3.UP)
