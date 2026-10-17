extends Node3D
## Smooth elevated sideline camera that keeps player and independent ball framed.

@export var height := 24.0
@export var depth := 36.0
@export var tracking_speed := 3.8
@export var ball_lead := 0.28

@onready var camera: Camera3D = $Camera3D
var player: Node3D
@onready var ball: Node3D = get_node("../Ball")

func _ready() -> void:
	player = get_node("../Player")
	global_position = Vector3(0.0, height, depth)
	camera.current = true
	camera.fov = 50.0
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _process(delta: float) -> void:
	if player == null or ball == null:
		return
	var rigid_ball := ball as RigidBody3D
	var lead: Vector3 = ball.global_position + rigid_ball.linear_velocity * ball_lead
	var focus := player.global_position.lerp(lead, 0.56)
	focus.x = clampf(focus.x, -32.0, 32.0)
	focus.z = clampf(focus.z, -23.0, 23.0)
	var target := Vector3(focus.x, height, focus.z + depth)
	global_position = global_position.lerp(target, 1.0 - exp(-tracking_speed * delta))
	camera.look_at(focus, Vector3.UP)
