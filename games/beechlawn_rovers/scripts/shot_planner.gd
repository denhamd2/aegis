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
	if forward > 43.0 and absf(actor.position.z) < 5.0: return &"low"
	if forward > 30.0 and absf(actor.position.z) > 8.0: return &"finesse"
	if forward < 34.0: return &"power"
	return &"standard"

static func ai_cross_style(actor: FootballPlayer, receiver: FootballPlayer) -> StringName:
	if actor.position.x * actor.attack_sign < 30.0: return &"early_cross"
	var marker_gap := INF
	for node in actor.get_tree().get_nodes_in_group("football_players"):
		if node.team_name != actor.team_name: marker_gap = minf(marker_gap, node.position.distance_to(receiver.position))
	if marker_gap < 2.0: return &"lofted_cross"
	if actor.position.x * actor.attack_sign > 37.0 and actor.position.distance_to(receiver.position) < 25.0: return &"driven_cross"
	return &"standard"
