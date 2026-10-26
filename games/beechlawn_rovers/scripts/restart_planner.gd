extends RefCounted
## Shared, deterministic football decisions; no access to a keeper's planned save.
static func plan(taker: FootballPlayer, teammates: Array, opponents: Array,
		kind: String, spot: Vector3, serial: int) -> Dictionary:
	var goal := Vector3(taker.attack_sign*52.5,0,0)
	var range_to_goal := Vector2(goal.x-spot.x, spot.z).length()
	if kind == "FREE KICK":
		var direct := FootballFreeKickPlanner.choose(taker,opponents,spot,serial)
		if not direct.is_empty(): return direct
	if kind == "PENALTY":
		var variant := posmod(serial + roundi(absf(spot.x)*.7+absf(spot.z)*1.3), 7)
		var widths := [-2.8,2.7,-3.3,3.45,1.7,-2.2,3.9]
		var heights := [.35,1.65,2.15,2.8,.85,1.9,1.3]
		var target := Vector3(goal.x, 0, widths[variant])
		return {"mode":&"shot", "power":.64+variant*.035, "direction":(target-Vector3(spot.x,0,spot.z)).normalized(),
			"target_z":widths[variant],"target_height":heights[variant],"style":&"finesse" if variant%3==1 else &"power" if variant%3==2 else &"standard"}
	if kind == "CORNER RESTART":
		var target := Vector3(taker.attack_sign*44,0, -signf(spot.z)*3)
		return {"mode":&"cross","direction":(target-Vector3(spot.x,0,spot.z)).normalized(),"power":.78}
	var short: FootballPlayer
	var long: FootballPlayer
	var best_short := INF
	var best_long := INF
	for actor: FootballPlayer in teammates:
		if actor == taker or actor.profile.role == "goalkeeper": continue
		var offset := actor.position-spot
		var distance := Vector2(offset.x,offset.z).length()
		var risk := taker._pass_lane_risk(spot,actor.position)
		var pressure := 10.0
		for opponent: FootballPlayer in opponents: pressure = minf(pressure,actor.position.distance_to(opponent.position))
		var progress := offset.x*taker.attack_sign
		if distance > 5 and distance < 22 and risk < .58 and pressure > 2.5:
			var score := distance*.1+risk*4-progress*.06
			if score < best_short: best_short=score;short=actor
		if distance > 16 and distance < 55:
			var score := absf(distance-34)*.12-progress*.1-minf(pressure,8)*.15
			if score < best_long: best_long=score;long=actor
	var receiver := short if short != null else long
	var direction := Vector3(taker.attack_sign,0,0) if receiver == null else (receiver.position-spot)*Vector3(1,0,1)
	var loft := short == null and kind != "THROW-IN"
	return {"mode":&"long" if loft else &"pass","direction":direction.normalized(),"power":.85 if loft else .55}
