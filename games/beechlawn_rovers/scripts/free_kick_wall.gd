extends RefCounted
class_name FootballFreeKickWall
## Short fixed-tick wall reaction. Actual CharacterBodies still block the ball.
var game: Node3D
var states: Array[Dictionary] = []
var age := 0.0
var observing := false

func prepare(match_scene: Node3D, actors: Array[FootballPlayer]) -> void:
	game = match_scene; states.clear(); age = 0; observing = false
	for actor in actors:
		states.append({"actor":actor,"jump_at":INF,"jumped":false,"ground":actor.position.y})
		actor.get_node("Visual").play_wall(false)

func release() -> void:
	if states.is_empty(): return
	age = 0; observing = true

func holds(actor: FootballPlayer) -> bool:
	return states.any(func(state: Dictionary): return state.actor == actor)

func update(delta: float) -> void:
	if not observing or not is_instance_valid(game) or game._presentation_active: return
	age += delta
	for index in states.size():
		var state: Dictionary = states[index]
		var actor: FootballPlayer = state.actor
		if not is_instance_valid(actor): continue
		if age >= .04 and not state.has("observed"):
			state.observed = true
			var v: Vector3 = game.ball.linear_velocity*Vector3(1,0,1)
			var t: float = (actor.position-game.ball.position).dot(v)/maxf(v.length_squared(),.01)
			var point := FootballBallFlight.position_at(game.ball,maxf(0,t))
			if t > .02 and t < .75 and point.y-float(state.ground) > .7 and point.y-float(state.ground) < 2.8:
				state.jump_at = age+maxf(0,t-.14)+float(index%2)*.018
		if not state.jumped and age >= float(state.jump_at):
			state.jumped = true; actor.velocity.y = 3.3
			actor.get_node("Visual").play_wall(true)
		actor.velocity.x = 0; actor.velocity.z = 0
		actor.velocity.y -= FootballPlayer.LOCOMOTION_GRAVITY*delta
		actor.move_and_slide()
	if age >= .95: clear(true)

func clear(resume: bool) -> void:
	for state in states:
		var actor: FootballPlayer = state.actor
		if not is_instance_valid(actor): continue
		actor.get_node("Visual").end_presentation()
		actor.velocity = Vector3.ZERO
		actor.position.y = game.surface_height(actor.position.x,actor.position.z) if game.terrain_enabled else 0
		actor.set_meta("wall_until_tick",0)
		if resume and not game._full_time: actor.set_physics_process(true)
	states.clear(); observing = false
