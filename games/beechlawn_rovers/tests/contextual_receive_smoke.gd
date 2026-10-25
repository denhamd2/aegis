extends SceneTree
## Final-mesh foot/mode/intent and interruption checks against a live ball.
var game: Node3D
var actor: FootballPlayer
var events: Array[Dictionary] = []
var failures: Array[String] = []
var fixture_camera: Camera3D
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, text: String) -> void:
 if not ok: failures.append(text)
func _open_match() -> void:
 game = load("res://scenes/match_11v11.tscn").instantiate()
 root.add_child(game)
 await process_frame
 fixture_camera=Camera3D.new()
 game.add_child(fixture_camera)
 game.set_physics_process(false)
 game._kickoff_pending = false
 game._set_players_physics_enabled(false)
 for other in game._home_players+game._away_players: other.position=Vector3(-40,0,30)
 game.ball.touched.connect(func(kind: StringName,_speed: float):
  if kind==&"first_touch":
   events.append({"foot":actor.receiving.foot,"mode":actor.receiving.mode,"gap":game.ball.global_position.distance_to(actor._footballer_visual.receive_context_position(actor.receiving.foot)),"incoming_velocity":game.ball.linear_velocity,"clock":actor._footballer_visual.context_receive_clock()}))
func _run() -> void:
 await _open_match()
 for away in [false,true]:
  for foot: StringName in [&"right",&"left"]:
   for speed in [0.,6.]: await _case(away,foot,speed,&"carry")
 for mode: StringName in [&"close",&"sprint"]: await _case(false,&"left",3.36 if mode==&"close" else 8.6,mode)
 # Close control wins when both modifiers are held.
 await _case(false,&"right",3.36,&"both")
 # An active approach is canceled by fresh pass intent without trapping first.
 await _setup(false,&"right",6.,&"carry")
 for frame in 30:
  await physics_frame
  if actor.receiving.active: break
 check(actor.receiving.active,"Reception starts before interruption fixture")
 Input.action_press("pass")
 await physics_frame
 await physics_frame
 Input.action_release("pass")
 check(not actor.receiving.active,"Fresh pass interrupts reception")
 check(events.is_empty(),"First-time pass intent must not produce an unwanted trap")
 actor.reset_for_stoppage()
 check(not actor.receiving.active and not actor.receiving.suppresses_dribble(),"Restart clears reception and release")
 check(not actor.get_collision_exceptions().has(game.ball),"Restart restores receiver capsule")
 # Reach and ownership remain authoritative, even with a nearby predicted boot.
 await _setup(false,&"left",0.,&"carry")
 for frame in 35:
  await physics_frame
  if actor.receiving.active: break
 game.ball.last_touch=&"Boardeaux"
 game.ball.action_serial+=1
 await physics_frame
 await physics_frame
 check(not actor.receiving.active and events.is_empty(),"Possession loss cancels without a touch")
 check(not actor.get_collision_exceptions().has(game.ball),"Loss restores capsule")
 _release_input()
 for message in failures:push_error(message)
 print("CONTEXTUAL_RECEIVE failures=",failures.size())
 game.free()
 quit(0 if failures.is_empty() else 1)
func _release_input() -> void:
 for action in ["move_right","move_left","close_control","sprint","pass","shoot"]:Input.action_release(action)
func _setup(away: bool,foot: StringName,speed: float,mode: StringName) -> void:
 _release_input()
 if is_instance_valid(actor):
  actor.set_physics_process(false)
  actor.reset_for_stoppage()
  actor.position=Vector3(-40,0,30)
 actor=game._away_players[2] if away else game.player
 actor.set_physics_process(false)
 actor.reset_for_stoppage()
 actor.controlled_by_human=true
 actor.camera=fixture_camera
 actor.stamina=100
 var forward:=Vector3.LEFT if away else Vector3.RIGHT
 actor.position=Vector3(-10 if away else 10,0,10)
 actor.position.y=game.surface_height(actor.position.x,actor.position.z)
 actor.rotation.y=PI/2 if away else -PI/2
 actor._flat_direction=forward
 actor.velocity=forward*speed
 actor.receive_target=actor.position+forward*3
 actor.receive_target_time=2
 var ball: FootballBall=game.ball
 ball.release_for_restart()
 ball.freeze=true
 ball.position=actor.position+forward*(2.6 if speed==0 else 4.8)+actor.global_basis.x*(.105 if foot==&"right" else -.105)+Vector3.UP*FootballBall.RADIUS
 ball.last_touch=actor.team_name
 ball.last_action=&"pass"
 ball.action_serial+=1
 ball.angular_velocity=Vector3.ZERO
 await physics_frame
 ball.freeze=false
 await physics_frame
 ball.linear_velocity=-forward*6
 if speed>0:
  # General projection supports both teams and the opposite-side camera.
  var action: StringName=&"move_right" if actor.camera.global_basis.x.dot(forward)>0 else &"move_left"
  Input.action_press(action)
 if mode in [&"close",&"both"]:Input.action_press("close_control")
 if mode in [&"sprint",&"both"]:Input.action_press("sprint")
 events.clear()
 actor.set_physics_process(true)
func _case(away: bool,foot: StringName,speed: float,mode: StringName) -> void:
 await _setup(away,foot,speed,mode)
 var label:="away=%s foot=%s speed=%.2f mode=%s"%[away,foot,speed,mode]
 var saw_gait:=false
 var start:Vector3=actor.position
 for frame in 55:
  await physics_frame
  if actor.receiving.active and speed>0:saw_gait=saw_gait or actor._footballer_visual.animation_tree.active
  if not events.is_empty():break
 print("RECEIVE_CASE ",label," events=",events," last_gap=",actor.receiving.contact_gap," last_foot=",actor.receiving.foot)
 check(events.size()==1,label+": one physical first touch")
 if not events.is_empty():
  check(events[0].foot==foot,label+": selected accessible foot")
  check(events[0].mode==(&"close" if mode==&"both" else mode),label+": contextual mode")
  check(float(events[0].gap)<=.20,label+": live boot contact")
  check(float(events[0].clock)>=.2,label+": no early impulse")
  if speed>0:
   check(saw_gait,label+": gait retained while receiving")
   check(actor.position.distance_to(start)>.4,label+": momentum preserved")
 for frame in 8:await physics_frame
 if not events.is_empty() and speed>0:
  var forward := Vector3.LEFT if away else Vector3.RIGHT
  check(game.ball.linear_velocity.dot(forward)>1.0,label+": actual integrated touch keeps forward movement")
 check(events.size()==1,label+": serial cannot cushion twice")
 actor.set_physics_process(false)
 actor.reset_for_stoppage()
