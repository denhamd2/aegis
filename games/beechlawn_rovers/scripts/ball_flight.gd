extends RefCounted
class_name FootballBallFlight
## Short-horizon air prediction. Physics contacts, turf friction and bounces
## remain authoritative; prediction never moves the live ball.

static func damping(ball: FootballBall) -> float:
	var world := float(ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.1))
	return maxf(0.0, ball.linear_damp + (0.0 if ball.linear_damp_mode == RigidBody3D.DAMP_MODE_REPLACE else world))

static func gravity(ball: FootballBall) -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * ball.gravity_scale

static func position_at(ball: FootballBall, seconds: float) -> Vector3:
	return position_from(ball.global_position, ball.linear_velocity, seconds, damping(ball), gravity(ball))

static func position_from(start: Vector3, velocity: Vector3, seconds: float,
		drag: float, acceleration: float) -> Vector3:
	var t := maxf(seconds, 0.0)
	if drag < 0.0001:
		return start + velocity * t - Vector3.UP * acceleration * t * t * 0.5
	var travel := (1.0 - exp(-drag * t)) / drag
	return start + velocity * travel - Vector3.UP * acceleration * (t - travel) / drag

static func launch(ball: FootballBall, destination: Vector3, seconds: float) -> Vector3:
	var t := clampf(seconds, 0.35, 3.2)
	var drag := damping(ball)
	var g := gravity(ball)
	if drag < 0.0001:
		return (destination - ball.global_position) / t + Vector3.UP * g * t * 0.5
	var travel := (1.0 - exp(-drag * t)) / drag
	return (destination - ball.global_position + Vector3.UP * g * (t - travel) / drag) / travel

static func descending_contact(ball: FootballBall, height: float, horizon := 3.0) -> Dictionary:
	var previous := ball.global_position
	var start := previous
	var velocity := ball.linear_velocity
	var drag := damping(ball)
	var acceleration := gravity(ball)
	var step := 1.0 / 30.0
	for index in range(1, int(horizon / step) + 1):
		var t := index * step
		var point := position_from(start, velocity, t, drag, acceleration)
		if previous.y >= height and point.y <= height and point.y < previous.y:
			var fraction := clampf((previous.y - height) / maxf(previous.y - point.y, 0.0001), 0.0, 1.0)
			return {"time": t - step + fraction * step, "position": previous.lerp(point, fraction)}
		previous = point
	return {}
