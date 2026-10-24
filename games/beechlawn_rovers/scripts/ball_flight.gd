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

static func physics_position_from(start: Vector3, velocity: Vector3, seconds: float,
		drag: float, acceleration: float) -> Vector3:
	# Fast boot contacts need the engine's damp-then-gravity, semi-implicit
	# fixed-tick path. A continuous parabola is measurably late at 30 m/s.
	var dt := maxf(.0001, Engine.time_scale / float(Engine.physics_ticks_per_second))
	var ticks := int(maxf(seconds, 0) / dt)
	var fraction := maxf(0, seconds - ticks * dt)
	var q := maxf(.0001, 1.0 - drag * dt)
	var travel: float
	var fall: float
	if drag < .0001:
		travel = seconds
		fall = dt * dt * ticks * (ticks + 1) * .5 + fraction * dt * (ticks + 1)
	else:
		var power := pow(q, ticks)
		var series := q * (1.0 - power) / (1.0 - q)
		travel = dt * series + fraction * power * q
		fall = dt * dt * (ticks - series) / (1.0 - q) + fraction * dt * (1.0 - power * q) / (1.0 - q)
	return start + velocity * travel - Vector3.UP * acceleration * fall

static func physics_launch(ball: FootballBall, destination: Vector3, seconds: float) -> Vector3:
	var drag := damping(ball)
	var travel := physics_position_from(Vector3.ZERO, Vector3.RIGHT, seconds, drag, 0).x
	var gravity_offset := physics_position_from(Vector3.ZERO, Vector3.ZERO, seconds, drag, gravity(ball))
	return (destination - ball.position - gravity_offset) / maxf(travel, .001)

static func descending_contact(ball: FootballBall, height: float, horizon := 3.0, physics_exact := false) -> Dictionary:
	var previous := ball.global_position
	var start := previous
	var velocity := ball.linear_velocity
	var drag := damping(ball)
	var acceleration := gravity(ball)
	var step := 1.0 / 30.0
	for index in range(1, int(horizon / step) + 1):
		var t := index * step
		var point := physics_position_from(start, velocity, t, drag, acceleration) if physics_exact else position_from(start, velocity, t, drag, acceleration)
		if previous.y >= height and point.y <= height and point.y < previous.y:
			var fraction := clampf((previous.y - height) / maxf(previous.y - point.y, 0.0001), 0.0, 1.0)
			return {"time": t - step + fraction * step, "position": previous.lerp(point, fraction)}
		previous = point
	return {}

static func after_bounce_contact(ball: FootballBall, height: float, horizon := .85) -> Dictionary:
	# One short forecast for a low rebound; the real bounce must still have
	# occurred before the boot marker may strike. Never moves the live ball.
	var p := ball.global_position
	var v := ball.linear_velocity
	var step := 1.0 / 120.0
	var drag := damping(ball)
	var g := gravity(ball)
	var bounce := ball.physics_material_override.bounce if ball.physics_material_override != null else .18
	var bounced := ball.seconds_since_bounce < .25
	var previous := p
	for i in range(1, int(horizon / step) + 1):
		v = (v - Vector3.UP * g * step) * maxf(0, 1.0 - drag * step)
		p += v * step
		var ground := ball.surface_height(p.x, p.z) if ball.use_terrain else 0.0
		if p.y <= ground + FootballBall.RADIUS:
			if bounced: return {}
			p.y = ground + FootballBall.RADIUS
			v.y = absf(v.y) * bounce
			bounced = true
		if bounced and ((v.y > 0 and p.y >= height - .035) or (previous.y > p.y and previous.y >= height - .10)):
			return {"time": i * step, "position": p}
		previous = p
	return {}
