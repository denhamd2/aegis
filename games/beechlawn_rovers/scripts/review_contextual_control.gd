extends SceneTree
## Controlled before/after fixture: production actors/physics, no posed ball snaps.
var options := {}
var game: Node3D
var actor: FootballPlayer
var camera: Camera3D
var input_axis: Camera3D
var frame_tick := 0
var frames: Array[Dictionary] = []
var touches: Array[Dictionary] = []
var cases := [{"mode":"carry","speed":0.,"foot":"right"},{"mode":"carry","speed":0.,"foot":"left"},{"mode":"close","speed":3.36,"foot":"left"},{"mode":"carry","speed":6.,"foot":"right"},{"mode":"sprint","speed":8.6,"foot":"left"}]
var case_index := 0
var baseline := false
var output: String
var broadcast := false
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--") and arg.contains("="):
   var pair:=arg.substr(2).split("=",true,1)
   options[pair[0]]=pair[1]
 call_deferred("_run")
func _step() -> void:
 frame_tick+=1
 var local_tick := (frame_tick-1)%60
 case_index=mini((frame_tick-1)/60,cases.size()-1)
 if local_tick==0:
  for action in ["move_right","close_control","sprint"]:Input.action_release(action)
  actor.reset_for_stoppage()
  actor.position=Vector3(10,game.surface_height(10,10),10)
  actor.rotation.y=-PI/2
  actor._flat_direction=Vector3.RIGHT
  actor.velocity=Vector3.RIGHT*float(cases[case_index].speed)
  actor.receive_target=actor.position+Vector3.RIGHT*3
  actor.receive_target_time=2
  game.ball.release_for_restart()
  game.ball.freeze=true
  game.ball.position=actor.position+Vector3(2.6 if cases[case_index].speed==0 else 4.8,FootballBall.RADIUS,.105 if cases[case_index].foot=="right" else -.105)
  game.ball.linear_velocity=Vector3.ZERO
  game.ball.angular_velocity=Vector3.ZERO
  game.ball.last_touch=actor.team_name
  game.ball.last_action=&"pass"
  game.ball.action_serial+=1
  if float(cases[case_index].speed)>0:Input.action_press("move_right")
  if cases[case_index].mode=="close":Input.action_press("close_control")
  if cases[case_index].mode=="sprint":Input.action_press("sprint")
 if local_tick==1:
  game.ball.freeze=false
  game.ball.linear_velocity=Vector3.LEFT*6
func _run() -> void:
 output=str(options.get("capture-dir",""))
 baseline=str(options.get("receive-baseline","0"))=="1"
 broadcast=str(options.get("review-mode","receive"))=="receive_broadcast"
 assert(output!="" and RenderingServer.get_current_rendering_method()=="forward_plus")
 root.get_node("MatchSession").launched_from_menu=false
 game=load("res://scenes/match_11v11.tscn").instantiate()
 root.add_child(game);current_scene=game
 game.set_physics_process(false)
 game._kickoff_pending=false
 game._set_players_physics_enabled(false)
 for other in game._home_players+game._away_players:other.position=Vector3(-40,0,30)
 for other in game._home_players:
  if other.profile.player_id==&"shane_denham":actor=other
 assert(actor!=null)
 actor.controlled_by_human=true
 actor.set_physics_process(true)
 input_axis=Camera3D.new();game.add_child(input_axis);actor.camera=input_axis
 game.get_node("HUD").hide()
 camera=game.get_node("BroadcastCamera/Camera3D")
 game.get_node("BroadcastCamera").set_process(false)
 camera.make_current()
 game.ball.touched.connect(func(kind: StringName,speed: float):
  if kind==&"first_touch" or kind==&"dribble":
   touches.append({"case":case_index,"tick":frame_tick,"kind":kind,"speed":speed,"ball":str(game.ball.position),"actor":str(actor.position)}))
 Engine.time_scale=3
 Engine.physics_ticks_per_second=180
 Engine.max_physics_steps_per_frame=64
 physics_frame.connect(_step)
 DirAccess.make_dir_recursive_absolute(output)
 for index in cases.size()*20:
  for step in 3:await physics_frame
  if broadcast:
   camera.global_position=actor.position+Vector3(0,12,-26)
   camera.fov=48
   camera.look_at(actor.position+Vector3(2,0,0))
  else:
   camera.global_position=actor.position+Vector3(3.2,1.05,4.2)
   camera.fov=45
   camera.look_at(actor.position+Vector3(.2,.82,0))
  camera.reset_physics_interpolation()
  if game.grass_detail!=null:game.grass_detail.prewarm(camera.position)
  await RenderingServer.frame_post_draw
  var filename:="frame_%03d.png"%index
  assert(root.get_texture().get_image().save_png(output.path_join(filename))==OK)
  var visual:=actor.get_node("Visual") as Node3D
  frames.append({"image":filename,"tick":frame_tick,"case":case_index,"mode":cases[case_index].mode,"actor":str(actor.position),"actor_velocity":str(actor.velocity),"ball":str(game.ball.position),"ball_velocity":str(game.ball.linear_velocity),"action":str(visual.get("_active_clip")),"gait_active":visual.get_node("AnimationTree").active})
  if index%10==0:print("RECEIVE_NATIVE_PROGRESS ",index,"/",cases.size()*20)
 physics_frame.disconnect(_step)
 actor.set_physics_process(false)
 for action in ["move_right","close_control","sprint"]:Input.action_release(action)
 var count:=0
 for touch in touches:
  if touch.kind==&"first_touch":count+=1
 if not baseline:assert(count==cases.size(),"Expected one first touch per native receiving case")
 var primary:=40
 var image:=Image.load_from_file(output.path_join(frames[primary].image))
 assert(image.save_png(output.path_join("match_broadcast.png"))==OK)
 var report:={"rendering_method":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"api":RenderingServer.get_video_adapter_api_version(),"display_server":DisplayServer.get_name(),"resolution":[image.get_width(),image.get_height()],"home_players":game._home_players.size(),"away_players":game._away_players.size(),"officials":get_nodes_in_group("match_officials").size(),"player_id":str(actor.profile.player_id),"review_mode":"receive_broadcast" if broadcast else "receive","baseline":baseline,"sequence_fps":20,"physics_steps_per_draw":3,"cases":cases,"frames":frames,"touches":touches,"first_touches":count,"scope":"Controlled live-ball fixture. Other actors parked, input basis world X for repeatable comparison, actual 60 Hz movement/physics. Native Forward+ software rendering, not Mac FPS."}
 var file:=FileAccess.open(output.path_join("match_broadcast.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  ")+"\n")
 print("BEECHLAWN_NATIVE_CAPTURE receiving cases=",cases.size()," first_touches=",count)
 quit()
