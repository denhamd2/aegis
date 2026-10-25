extends SceneTree
## A real moving receiver must cushion a live pass before generic dribble takes it.
var kinds: Array[StringName] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 var game = load("res://scenes/match_11v11.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_physics_process(false)
 game._kickoff_pending = false
 game._set_players_physics_enabled(false)
 for actor in game._home_players + game._away_players: actor.position = Vector3(-40,0,30)
 var actor: FootballPlayer = game.player
 var ball: FootballBall = game.ball
 actor.reset_for_stoppage()
 actor.controlled_by_human = false
 actor.position = Vector3(10,game.surface_height(10,0),0)
 actor.rotation.y = -PI/2
 actor._flat_direction = Vector3.RIGHT
 actor.velocity = Vector3.RIGHT*6
 actor.ai_move_direction = Vector3.RIGHT
 actor.receive_target = actor.position + Vector3.RIGHT*3
 actor.receive_target_time = 2
 ball.release_for_restart()
 ball.freeze = true
 ball.position = actor.position+Vector3(4.8,FootballBall.RADIUS,0)
 ball.last_touch = actor.team_name
 ball.last_action = &"pass"
 ball.action_serial += 1
 await physics_frame
 ball.freeze = false
 await physics_frame
 ball.linear_velocity = Vector3.LEFT*6
 ball.angular_velocity = Vector3.ZERO
 ball.touched.connect(func(kind: StringName,_speed: float): kinds.append(kind))
 actor.set_physics_process(true)
 for frame in 40:
  await physics_frame
  if not kinds.is_empty():break
 print("MOVING_RECEIVE_FIRST_EVENT ",kinds)
 var passed := not kinds.is_empty() and kinds[0] == &"first_touch"
 actor.set_physics_process(false)
 game.free()
 if not passed: push_error("A moving reception was consumed by dribble assistance before a first touch")
 quit(0 if passed else 1)
