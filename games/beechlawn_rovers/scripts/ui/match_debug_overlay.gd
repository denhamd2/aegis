extends Control
## F3 development view. All geometry is projected from the live physics state.

const FONT := preload("res://assets/ui/fonts/BarlowSemiCondensed-SemiBold.ttf")
const HOME := Color(0.25, 0.57, 1.0, 0.92)
const AWAY := Color(0.35, 0.86, 0.98, 0.92)
const BALL := Color(1.0, 0.86, 0.26, 0.95)
const KEEPER := Color(1.0, 0.32, 0.55, 0.95)

var game: Node3D
var camera: Camera3D

func _process(_delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player): return
	visible = game._debug_enabled
	if visible:
		camera = game.camera_rig.get_node_or_null("Camera3D") as Camera3D
		queue_redraw()

func _screen(point: Vector3) -> Vector2:
	if not is_instance_valid(camera) or camera.is_position_behind(point):
		return Vector2(-10000, -10000)
	return camera.unproject_position(point) / maxf(game.match_hud.scale.x, 0.01)

func _line(start: Vector3, end: Vector3, colour: Color, width := 2.0) -> void:
	var a := _screen(start)
	var b := _screen(end)
	if a.x > -9999 and b.x > -9999:
		draw_line(a, b, colour, width, true)
		draw_circle(b, 3.0, colour)

func _ring(center: Vector3, radius: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for step in 13:
		var angle := TAU * float(step) / 12.0
		var point := _screen(center + Vector3(cos(angle) * radius, 0, sin(angle) * radius))
		if point.x < -9999: return
		points.append(point)
	draw_polyline(points, colour, 1.0, true)

func _collision(actor: FootballPlayer, colour: Color) -> void:
	var shape_node := actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.disabled or shape_node.shape == null: return
	var radius := 0.32
	var half_height := 0.9
	if shape_node.shape is CapsuleShape3D:
		radius = (shape_node.shape as CapsuleShape3D).radius
		half_height = (shape_node.shape as CapsuleShape3D).height * 0.5
	var centre := shape_node.global_position
	_ring(centre + Vector3.UP * (-half_height + radius), radius, colour)
	_ring(centre + Vector3.UP * (half_height - radius), radius, colour)
	for side in [-1.0, 1.0]:
		_line(centre + Vector3(side * radius, -half_height + radius, 0),
			centre + Vector3(side * radius, half_height - radius, 0), colour, 1.0)

func _draw() -> void:
	if not is_instance_valid(game) or not is_instance_valid(camera): return
	var ball: FootballBall = game.ball
	var ball_at := ball.global_position
	_line(ball_at, ball_at + ball.linear_velocity * 0.15, BALL, 3.0)
	_ring(ball_at, FootballBall.RADIUS, BALL)
	for actor in game._home_players + game._away_players:
		if not is_instance_valid(actor) or not actor.visible: continue
		var colour: Color = HOME if actor in game._home_players else AWAY
		_collision(actor, colour.darkened(0.2))
		_line(actor.global_position + Vector3.UP, actor.global_position + Vector3.UP + actor.velocity * 0.16, colour)
		if actor.has_meta("ai_target_position") and not actor.controlled_by_human:
			var target: Vector3 = actor.get_meta("ai_target_position")
			_line(actor.global_position + Vector3.UP * 0.05, target + Vector3.UP * 0.05, colour.darkened(0.2), 1.0)
			var label_at := _screen(actor.global_position + Vector3.UP * 2.1)
			if label_at.x > -9999:
				draw_string(FONT, label_at, str(actor.get_meta("ai_role_intent", &"")), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, colour)
		if actor.receive_target_time > 0.0:
			_line(actor.global_position + Vector3.UP * 0.15, actor.receive_target + Vector3.UP * 0.15, BALL, 2.0)
		if actor._goalkeeper_controller != null:
			var keeper: GoalkeeperController = actor._goalkeeper_controller
			if keeper._has_intercept and keeper._shot_active:
				_line(actor.global_position + Vector3.UP, keeper._predicted_intercept, KEEPER, 3.0)
				_ring(keeper._predicted_intercept, 0.45, KEEPER)
