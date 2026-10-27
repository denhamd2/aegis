extends RefCounted
class_name FootballAerialContest
## One physical winner for concurrent headers and legal goalkeeper claims.
## This only arbitrates live evaluated contacts; it never moves the ball.

const NEAR_TIE_METRES := .02

static func winner(ball: FootballBall) -> FootballPlayer:
	var candidates: Array[Dictionary] = []
	for node in ball.get_tree().get_nodes_in_group("football_players"):
		var player := node as FootballPlayer
		if player == null or player.profile == null: continue
		var gap := INF
		var quality := 0.0
		if player.profile.role == "goalkeeper":
			var keeper := player._goalkeeper_controller
			if keeper == null or not keeper.claim_contact_due() or not is_instance_valid(player._footballer_visual): continue
			var from := ball.global_position - ball.linear_velocity / float(Engine.physics_ticks_per_second)
			for hand in player._footballer_visual.hand_positions():
				gap = minf(gap, hand.distance_to(Geometry3D.get_closest_point_to_segment(hand, from, ball.global_position)))
			if gap > .34: continue
			quality = (player._attribute_value(&"goalkeeper_handling") * .6 + player._attribute_value(&"jumping") * .4) / 100.0
		else:
			var aerial := player._aerial_controller
			if aerial == null or not aerial._header_contact_due() or aerial._serial != ball.action_serial: continue
			gap = aerial.forehead_point().distance_to(ball.global_position)
			if gap > player.tuning.aerial_contact_radius: continue
			quality = (player._attribute_value(&"heading") * .5 + player._attribute_value(&"jumping") * .3 + player._attribute_value(&"strength") * .2) / 100.0
		candidates.append({"player":player,"gap":gap,"quality":quality,"id":String(player.profile.player_id)})
	if candidates.is_empty(): return null
	var nearest := INF
	for candidate in candidates: nearest = minf(nearest, float(candidate.gap))
	var close: Array[Dictionary] = []
	for candidate in candidates:
		if float(candidate.gap) <= nearest + NEAR_TIE_METRES: close.append(candidate)
	close.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.quality), float(b.quality)): return float(a.quality) > float(b.quality)
		return String(a.id) < String(b.id))
	return close[0].player
