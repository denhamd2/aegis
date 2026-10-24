extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 var session := root.get_node("MatchSession")
 session.venue_id = &"kilmore_drive"; session.switch_mode = &"assisted"
 var game = load("res://scenes/match_11v11.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_physics_process(false); game._set_players_physics_enabled(false)
 game._kickoff_pending = false
 var passer: FootballPlayer = game.player
 var target: FootballPlayer
 for actor in game._home_players:
  if actor != passer and actor.profile.role == "outfield": target = actor
 var ball: FootballBall = game.ball
 ball.freeze = true
 for kind: StringName in [&"ground",&"lofted_pass",&"cross"]:
  for actor in game._home_players+game._away_players:
   actor.reset_for_stoppage(); actor.position=Vector3(-35,0,-25)
  game._set_controlled_player(passer)
  passer.position=Vector3(25,0,22); passer._flat_direction=Vector3.RIGHT; passer.rotation.y=-PI/2
  target.position=Vector3(42,0,0)
  ball.position=passer.position+Vector3(.6,FootballBall.RADIUS,0)
  ball.last_touch=passer.team_name;ball.last_action=&"none"
  ball.linear_velocity=Vector3.ZERO
  ball._dribble_controller=null;ball._dribble_control_lease=0
  passer._do_pass(false,(target.position-passer.position).normalized(),false,1,target,kind,.65)
  assert(passer._visual_pass_pending)
  assert(game.player == passer,"Pass windup moved selection")
  var visual := passer.get_node("Visual") as FootballerVisual
  visual.animation_player.seek(visual.action_contact_time(&"pass"),true)
  ball.position=passer._receive_contact_position()+Vector3.UP*.06
  passer._on_visual_action_contact(&"pass")
  assert(game.player == target,"Actual pass type failed to hand over: "+str(kind))
  assert(game.selection.receiver == target and game.selection.pass_serial == ball.action_serial)
  assert(ball.last_action == (&"pass" if kind == &"ground" else kind))
  assert(target.receive_target_time > 0)
 # A teammate's quick one-touch release can precede the possession sample.
 var third: FootballPlayer
 for actor in game._home_players:
  if actor != passer and actor != target and actor.profile.role == "outfield": third = actor
 game._set_controlled_player(third)
 game.selection.manual_hold = 0
 passer.pass_released.emit(target,ball.action_serial)
 assert(game.selection.receiver == target and game.player == target)
 # A fresh manual off-ball override must survive an unrelated AI pass.
 game._set_controlled_player(passer)
 game.selection.manual_hold = 1
 var saved_receiver: FootballPlayer = game.selection.receiver
 target.pass_released.emit(passer,ball.action_serial)
 assert(game.selection.receiver == saved_receiver and game.selection.manual_hold == 1)
 # A failed/cancelled preparation cannot select its proposed recipient.
 game._set_controlled_player(passer)
 passer.reset_for_stoppage();ball.position=Vector3(-30,FootballBall.RADIUS,0)
 passer._do_pass(false,Vector3.RIGHT,false,1,target)
 assert(not passer._visual_pass_pending and game.player == passer)
 print("RECEIVER_SELECTION PASS: real ground/loft/cross markers, no windup or failed-preparation handover")
 game.free();quit()
