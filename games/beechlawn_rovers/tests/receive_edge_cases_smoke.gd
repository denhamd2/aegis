extends "res://tests/contextual_receive_smoke.gd"
## Angled flight, a starting receiver, terrain, handover direction and reentrant whistle.
func _run() -> void:
 await _open_match()
 for angle in [-PI/6,PI/6]:
  await _setup(false,&"left",6.,&"carry")
  var ball: FootballBall=game.ball
  var incoming:=Vector3.LEFT.rotated(Vector3.UP,angle)*8
  var contact:=actor.position+Vector3(.54,.11,-.105)
  ball.position=contact+Vector3.RIGHT*3-incoming*.5
  ball.linear_velocity=incoming
  events.clear()
  for frame in 55:
   await physics_frame
   if not events.is_empty():break
  print("ANGLED_RECEIVE radians=",angle," contacts=",events)
  check(events.size()==1,"Angled live pass reaches a real foot")
  if not events.is_empty():check(float(events[0].gap)<=.20,"Angled contact respects anatomical reach")
  actor.set_physics_process(false)
 # Starting to run during a standing reception must switch to the moving overlay.
 await _setup(false,&"right",0.,&"carry")
 for frame in 30:
  await physics_frame
  if actor.receiving.active:break
 check(actor.receiving.active,"Standing approach prepares")
 Input.action_press("move_right")
 for frame in 3:await physics_frame
 check(actor._footballer_visual._receive_index>=2 and actor._footballer_visual.animation_tree.active,"Starting to run preserves gait during reception")
 actor.reset_for_stoppage()
 # No-input handover follows actual travel, rather than the internal placeholder stick.
 _release_input()
 actor.velocity=Vector3(0,0,6)
 actor._stick=Vector2.RIGHT
 actor.controlled_by_human=true
 var outlet:=actor.receiving._outlet_direction()
 check(outlet.dot(Vector3(0,0,1))>.6,"No-input assisted receiver follows carrier travel within the body arc")
 actor.velocity=Vector3.ZERO
 actor._flat_direction=Vector3.RIGHT
 actor.rotation.y=-PI/2
 # Nearby control cannot reach a ball outside the boot limit or above the grass envelope.
 game.ball.freeze=true
 game.ball.position=actor.position+Vector3(.55,.11,0)
 game.ball.last_touch=actor.team_name;game.ball.last_action=&"pass"
 check(not game.ball.receive_touch(actor,game.ball.position+Vector3(.3,0,0),Vector3.RIGHT,&"carry"),"No remote trapping")
 var height: float=game.surface_height(17,11)
 game.ball.position=Vector3(17,height+.11,11)
 game.ball.linear_velocity=Vector3.LEFT*4
 game.ball.last_touch=actor.team_name;game.ball.last_action=&"pass"
 check(game.ball.receive_touch(actor,game.ball.position,Vector3.RIGHT,&"carry"),"Receive height follows uneven ground")
 game.ball.position.y=height+.45
 game.ball.last_action=&"pass"
 check(not game.ball.receive_touch(actor,game.ball.position,Vector3.RIGHT,&"carry"),"Ground receive cannot claim an airborne ball")
 # An offside whistle can reset the actor synchronously inside record_touch.
 await _setup(false,&"left",6.,&"carry")
 var whistle:={"seen":false}
 var callback:=func(toucher: Node3D,_serial: int):
  if toucher==actor and game.ball.last_action==&"first_touch":
   whistle.seen=true
   actor.reset_for_stoppage()
 game.ball.actor_touched.connect(callback)
 for frame in 55:
  await physics_frame
  if whistle.seen:break
 game.ball.actor_touched.disconnect(callback)
 check(whistle.seen,"Reentrant whistle fixture reaches actual contact")
 check(not actor.receiving.active and not actor.receiving.suppresses_dribble(),"Whistle cannot rearm stale reception/release")
 check(not actor.get_collision_exceptions().has(game.ball),"Whistle restores capsule")
 _release_input()
 for message in failures:push_error(message)
 print("RECEIVE_EDGE_CASES failures=",failures.size())
 game.free()
 quit(0 if failures.is_empty() else 1)
