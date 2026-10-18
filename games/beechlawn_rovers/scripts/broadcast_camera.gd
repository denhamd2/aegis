extends Node3D
## Smooth elevated sideline camera that keeps player and independent ball framed.

@export var height := 12.0
@export var depth := 26.0
@export var tracking_speed := 3.8
@export var ball_lead := 0.28

@onready var camera: Camera3D = $Camera3D
var player: Node3D
var _focus := Vector3.ZERO
var _distance_scale := 1.0
var _review_view := false
@onready var ball: Node3D = get_node("../Ball")

func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	player = get_node("../Player")
	global_position = Vector3(0.0, height, depth)
	camera.current = true
	camera.fov = 50.0
	camera.look_at(Vector3.ZERO, Vector3.UP)
	# Review cameras are opt-in in debug Web builds; normal gameplay keeps tracking.
	if OS.has_feature("web") and OS.has_feature("debug"):
		var view = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('view')")
		var views := {
			"touchline": [Vector3(4,2.4,37),Vector3(0,0.9,0),55.0],
			"goal": [Vector3(59,3.2,11),Vector3(43,1.0,0),62.0],
			"corner": [Vector3(-56,6,37),Vector3(-27,0.7,0),60.0],
		}
		if view != null and views.has(str(view)):
			var shot: Array = views[str(view)]
			global_position=shot[0]
			camera.fov=shot[2]
			camera.look_at(shot[1],Vector3.UP)
			_review_view=true

func _process(delta: float) -> void:
	if _review_view or player == null or ball == null:
		return
	var rigid_ball := ball as RigidBody3D
	var lead: Vector3 = ball.get_global_transform_interpolated().origin + rigid_ball.linear_velocity * ball_lead
	var focus := player.get_global_transform_interpolated().origin.lerp(lead, 0.78)
	focus.x = clampf(focus.x, -49.0, 49.0)
	focus.z = clampf(focus.z, -30.0, 30.0)
	_focus = _focus.lerp(focus,1.0-exp(-tracking_speed*delta))
	var gap := player.global_position.distance_to(ball.global_position)
	var widen := clampf((rigid_ball.linear_velocity.length()-13.0)/18.0,0.0,0.28)
	widen = maxf(widen,clampf((gap-10.0)/35.0,0.0,0.35))
	_distance_scale = lerpf(_distance_scale,1.0+widen,1.0-exp(-2.8*delta))
	var target := Vector3(_focus.x,height*_distance_scale,_focus.z+depth*_distance_scale)
	global_position = global_position.lerp(target, 1.0 - exp(-tracking_speed * delta))
	camera.look_at(_focus, Vector3.UP)
