extends RefCounted
class_name FootballPlayerSelection
## Cursor assistance observes real football; it never changes possession/forces.
const REASSESS := .2
const MIN_DWELL := .6
const ADVANTAGE := .15
var game: Node3D
var elapsed := 0.0
var dwell := 0.0
var manual_hold := 0.0
var candidate: FootballPlayer
var candidate_age := 0.0
var receiver: FootballPlayer
var pass_serial := -1
var reader := preload("res://scripts/tactical_possession.gd").new()

func setup(match_scene: Node3D) -> void:
	game = match_scene
	for actor in game._home_players:
		actor.pass_released.connect(_pass_released.bind(actor))

func eligible(actor: FootballPlayer) -> bool:
	return is_instance_valid(actor) and actor.is_inside_tree() and actor.visible \
		and not bool(actor.get_meta("sent_off", false)) and actor.profile != null \
		and actor.profile.role == "outfield" and actor in game._home_players

func blocked() -> bool:
	return game._spectator_mode or game._intro_active or game._presentation_active \
		or game._full_time or game._kickoff_pending or game._goal_pause_timer > 0 \
		or game.restart.active()

func _pass_released(target: FootballPlayer, serial: int, passer: FootballPlayer) -> void:
	if not eligible(target) or game.get_node("/root/MatchSession").switch_mode != &"assisted": return
	# Respect a recent off-ball manual override. Otherwise a quick AI teammate
	# pass can release before the 5 Hz possession sample sees its carrier.
	if passer != game.player and manual_hold > 0 and passer.profile.role != "goalkeeper": return
	receiver = target
	pass_serial = serial
	if not blocked(): _select(target)

func manual_switch() -> void:
	if blocked(): return
	var best := best_candidate(game.player)
	if best != null:
		_select(best)
		manual_hold = 1.0
		receiver = null

func update(delta: float) -> void:
	dwell += delta
	manual_hold = maxf(0, manual_hold-delta)
	if game._spectator_mode: return
	# A dismissal must never leave an invisible human-controlled actor selected.
	if not eligible(game.player) and not game._full_time:
		var replacement := best_candidate()
		if replacement != null: _select(replacement)
	if blocked():
		candidate = null
		candidate_age = 0
		return
	if game.get_node("/root/MatchSession").switch_mode != &"assisted" or manual_hold > 0: return
	if eligible(receiver) and game.ball.action_serial == pass_serial and receiver.receive_target_time > 0:
		if game.player != receiver: _select(receiver)
		return
	receiver = null
	elapsed += delta
	if elapsed < REASSESS: return
	var step := elapsed
	elapsed = 0
	var all: Array[FootballPlayer] = []
	all.assign(game._home_players + game._away_players)
	var possession := reader.sample(game.ball, all)
	var carrier := possession.get("carrier") as FootballPlayer
	if eligible(carrier):
		if carrier != game.player: _select(carrier)
		return
	var best := best_candidate()
	if best == null or best == game.player or dwell < MIN_DWELL \
			or interception_cost(best)+ADVANTAGE >= interception_cost(game.player):
		candidate = null
		candidate_age = 0
		return
	if candidate != best:
		candidate = best
		candidate_age = 0
	else:
		candidate_age += step
		if candidate_age >= .2: _select(best)

func best_candidate(exclude: FootballPlayer = null) -> FootballPlayer:
	var best: FootballPlayer
	var cost := INF
	for actor in game._home_players:
		if actor == exclude or not eligible(actor): continue
		var value := interception_cost(actor)
		if value < cost:
			best = actor
			cost = value
	return best

func interception_cost(actor: FootballPlayer) -> float:
	if not eligible(actor): return INF
	var ball: FootballBall = game.ball
	var speed := maxf(4, actor.tuning.sprint_speed * lerpf(.72,1,actor.stamina/actor.tuning.stamina_max))
	var best := INF
	var airborne := ball.global_position.y > .65 or ball.linear_velocity.y > 2
	for index in range(21):
		var t := index*.15
		var point := FootballBallFlight.position_at(ball,t) if airborne else ball.global_position + Vector3(ball.linear_velocity.x,0,ball.linear_velocity.z)*t/(1+.8*t)
		point.x = clampf(point.x,-52.5,52.5)
		point.z = clampf(point.z,-34,34)
		if airborne and point.y > 2.2: continue
		var offset := Vector2(point.x-actor.position.x,point.z-actor.position.z)
		var turn := .7 if actor._slide_tackle_time > 0 or actor._keeper_is_recovering() else 0.0
		if offset.length() > 1:
			var facing := Vector2(actor._flat_direction.x,actor._flat_direction.z)
			turn += (1-facing.dot(offset.normalized()))*.12
		var arrival := offset.length()/speed+turn
		best = minf(best, maxf(t,arrival)+absf(arrival-t)*.1)
	return best

func _select(actor: FootballPlayer) -> void:
	game._set_controlled_player(actor)
	manual_hold = 0
	dwell = 0
	candidate = null
	candidate_age = 0
