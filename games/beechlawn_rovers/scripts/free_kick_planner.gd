extends RefCounted
class_name FootballFreeKickPlanner
## Intent and a physical launch estimate. Never moves the ball or reads save intent.
static func choose(actor: FootballPlayer, opponents: Array, spot: Vector3, serial: int) -> Dictionary:
	var sx := actor.attack_sign
	var distance := Vector2(52.5-spot.x*sx, spot.z).length()
	if distance > 30 or distance < 10 or (52.5-spot.x*sx)/distance < .62: return {}
	var keeper_z := 0.0
	for opponent: FootballPlayer in opponents:
		if opponent.profile.role == "goalkeeper": keeper_z = opponent.position.z
	var best := -INF
	var target_z := 0.0
	var wall_blocked := false
	for local_z in [-3.05, -2.35, 2.35, 3.05]:
		var z: float = local_z*sx
		var goal := Vector3(52.5*sx, spot.y, z)
		var line := (goal-spot)*Vector3(1,0,1)
		var gap := 4.0
		for opponent: FootballPlayer in opponents:
			if opponent.profile.role == "goalkeeper": continue
			var t := clampf(((opponent.position-spot)*Vector3(1,0,1)).dot(line)/line.length_squared(),0,1)
			if t > .1 and t < .7:
				gap = minf(gap,Vector2(opponent.position.x-(spot+line*t).x,opponent.position.z-(spot+line*t).z).length())
		var score := absf(z-keeper_z)*.55 + minf(gap,1.5)*.7 - absf(local_z)*.08
		# Small stable tie-breaks add variety without specifying misses or goals.
		score += sin(float(serial)*1.73+local_z)*.12
		if score > best:
			best = score; target_z = z; wall_blocked = gap < .65
	var style: StringName = &"finesse" if wall_blocked or absf(spot.z)>5 else (&"power" if distance>23 else &"standard")
	if not wall_blocked and distance < 21 and serial%4 == 0: style = &"low"
	var power := clampf(.53+distance*.009+( .07 if style == &"power" else 0),.64,.92)
	return {"mode":&"shot", "power":power, "direction":(Vector3(52.5*sx,spot.y,target_z)-spot).normalized(),
		"target_z":target_z, "target_height":.18 if style == &"low" else (2.08 if wall_blocked else 1.65), "style":style}

static func strike(actor: FootballPlayer, charge: float, target_z: float, height: float,
		style: StringName, error := true) -> Dictionary:
	var ball := actor.ball
	var goal_x := actor.attack_sign*52.5
	var target := Vector3(goal_x, ball.surface_height(goal_x,target_z)+height if ball.use_terrain else height, target_z)
	var aim := (target-ball.position)*Vector3(1,0,1)
	var base := ShotPlanner.plan(actor,charge,aim.normalized(),style)
	var speed := clampf(float(base.speed),10,34)
	var distance := aim.length()
	var lo := .08
	var hi := 3.0
	for iteration in 15:
		var t := (lo+hi)*.5
		var travel := FootballBallFlight.physics_position_from(Vector3.ZERO,Vector3.RIGHT*speed,t,FootballBallFlight.damping(ball),0).x
		if travel < distance: lo = t
		else: hi = t
	var flight := (lo+hi)*.5
	if error:
		var rating := (actor._attribute_value(&"shooting")+actor._attribute_value(&"finishing"))*.5
		var spread := lerpf(.95,.18,clampf(rating/100,0,1)) + charge*charge*.3
		var phase := ball.action_serial*1.618 + ball.position.x*actor.attack_sign*.13 + absf(ball.position.z)*.31
		target.z += sin(phase)*spread*actor.attack_sign
		target.y += cos(phase*1.37)*spread*.55
	var launch := FootballBallFlight.physics_launch(ball,target,flight)
	var spin: Vector3 = base.spin
	if style == &"low":
		# A low strike stays a low strike; do not replace its lift with a
		# goal-height solution that makes it climb over the wall.
		launch = ((target-ball.position)*Vector3(1,0,1)).normalized()*speed + Vector3.UP*float(base.lift)
	elif style == &"finesse":
		var acceleration := (spin.cross(launch)*actor.tuning.finesse_magnus).limit_length(3.5)
		var outside := target-acceleration*flight*flight*.46
		launch = FootballBallFlight.physics_launch(ball,outside,flight)
	return {"velocity":launch.limit_length(37.5),"spin":spin,"time":flight,"style":style}
