extends RefCounted
class_name ShotPlanner
## Distinct football strikes. Prediction never owns the live ball transform.

static func input_style() -> StringName:
	if Input.is_action_pressed("finesse_modifier"): return &"finesse"
	if Input.is_action_pressed("power_modifier"): return &"power"
	if Input.is_action_pressed("low_modifier"): return &"low"
	return &"standard"

static func cross_style() -> StringName:
	if Input.is_action_pressed("finesse_modifier"): return &"lofted_cross"
	if Input.is_action_pressed("power_modifier"): return &"driven_cross"
	if Input.is_action_pressed("low_modifier"): return &"early_cross"
	return &"standard"

static func plan(actor: FootballPlayer, charge: float, direction: Vector3,
		style: StringName = &"standard") -> Dictionary:
	var power := clampf(charge, 0, 1)
	var speed := lerpf(actor.tuning.shot_min_speed, actor.tuning.shot_max_speed, smoothstep(0, 1, power))
	var lift := lerpf(.55, 2.45, power)
	var spin := Vector3.ZERO
	var aim := Vector3(direction.x, 0, direction.z).normalized()
	match style:
		&"power":
			speed *= actor.tuning.power_shot_multiplier
			lift = lerpf(.45, 1.65, power)
		&"low":
			speed *= .94
			lift = lerpf(.08, .30, power)
		&"finesse":
			speed *= .84
			lift = lerpf(1.55, 3.35, power)
			var side := signf(actor.ball.position.z) if absf(actor.ball.position.z) > .3 else 1.0
			spin = Vector3.UP * side * actor.attack_sign * actor.tuning.finesse_spin
		&"volley":
			speed *= .94
			lift = lerpf(-.65, .85, power)
		&"half_volley":
			speed *= .96
			lift = lerpf(.7, 2.2, power)
	if style in [&"standard", &"power", &"finesse"] and aim.x * actor.attack_sign > .2:
		# Solve height at the actual goal plane. Old fixed ~1–2 m/s lifts
		# landed almost every shot before it reached goal.
		var distance := clampf((actor.attack_sign * 52.5 - actor.ball.position.x) / aim.x, 1, 45)
		var travel := distance / maxf(speed, 1)
		travel *= 1.0 + .035 * travel
		var target_height := lerpf(.35, 2.7, power)
		if style == &"finesse": target_height = lerpf(.8, 2.65, power)
		lift = clampf((target_height - actor.ball.position.y + 4.905 * travel * travel) / travel, .7, 13)
	# Neutral attributes preserve the baseline strike. Attribute deviations and
	# difficult special-shot conditions add bounded, reproducible placement error.
	var rating := (actor._attribute_value(&"shooting") + actor._attribute_value(&"finishing")) * .5
	var running := Vector2(actor.velocity.x, actor.velocity.z).length() / maxf(actor.tuning.sprint_speed, 1)
	var pressure := 0.0
	for node in actor.get_tree().get_nodes_in_group("football_players"):
		if node != actor and node.team_name != actor.team_name:
			pressure = maxf(pressure, clampf((2.5 - node.position.distance_to(actor.position)) / 2.5, 0, 1))
	var difficulty := maxf(0, (50 - rating) / 100.0)
	if style != &"standard": difficulty += running * .35 + pressure * .3 + power * power * .15
	var phase := actor.ball.action_serial * 1.618 + actor.position.x * .13 + actor.position.z * .31
	var error := sin(phase) * difficulty * actor.tuning.special_shot_error_radians
	aim = aim.rotated(Vector3.UP, error)
	speed *= clampf(1.0 + (actor._attribute_value(&"shot_power") - 50.0) * .002, .9, 1.1)
	return {"direction": aim, "speed": speed, "lift": lift, "spin": spin, "style": style}

static func ai_style(actor: FootballPlayer) -> StringName:
	var forward := actor.position.x * actor.attack_sign
	var goal_distance := Vector2(52.5-forward,actor.position.z).length()
	var pressure := INF
	var keeper_gap := INF
	for opponent in actor.get_tree().get_nodes_in_group("football_players"):
		if opponent==actor or opponent.team_name==actor.team_name or opponent.profile==null: continue
		var gap: float = opponent.position.distance_to(actor.position)
		if opponent.profile.role=="goalkeeper": keeper_gap=minf(keeper_gap,gap)
		else: pressure=minf(pressure,gap)
	# A closing keeper or nearby challenge favours a quick low release. With
	# time, use the far-corner curve from an angle or drive a longer attempt.
	if goal_distance<17 and (keeper_gap<6 or pressure<1.6): return &"low"
	if forward>43 and absf(actor.position.z)<5: return &"low"
	if forward>30 and absf(actor.position.z)>5 and pressure>1.6: return &"finesse"
	if goal_distance>19: return &"power"
	return &"standard"

static func ai_cross_style(actor: FootballPlayer, receiver: FootballPlayer) -> StringName:
	if actor.position.x * actor.attack_sign < 30.0: return &"early_cross"
	var marker_gap := INF
	for node in actor.get_tree().get_nodes_in_group("football_players"):
		if node.team_name != actor.team_name: marker_gap = minf(marker_gap, node.position.distance_to(receiver.position))
	if marker_gap < 2.0: return &"lofted_cross"
	if actor.position.x * actor.attack_sign > 37.0 and actor.position.distance_to(receiver.position) < 25.0: return &"driven_cross"
	return &"standard"
