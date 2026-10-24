extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 var session := root.get_node("MatchSession")
 session.venue_id = &"kilmore_drive"
 session.switch_mode = &"assisted"
 var game = load("res://scenes/match_11v11.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_physics_process(false)
 game._set_players_physics_enabled(false)
 game._kickoff_pending = false
 var control: FootballPlayerSelection = game.selection
 var passer: FootballPlayer = game.player
 var receiver: FootballPlayer
 for actor in game._home_players:
  actor.position = Vector3(-40,game.surface_height(-40,20),20)
  if actor != passer and control.eligible(actor): receiver = actor
 for actor in game._away_players: actor.position = Vector3(35,0,25)
 var ball: FootballBall = game.ball
 ball.freeze = true
 ball._dribble_control_lease = 0
 ball._dribble_controller = null
 ball.last_touch = &"Boardeaux"
 ball.last_action = &"none"
 ball.position = Vector3(0,FootballBall.RADIUS,0)
 ball.linear_velocity = Vector3.ZERO
 receiver.position = Vector3(2,0,0)
 for i in 6: control.update(.2)
 assert(game.player == receiver,"Assistance must select the nearer intercepting defender")
 var original: FootballPlayer = game.player
 # Near ties must not oscillate the cursor.
 passer.position = receiver.position+Vector3(.08,0,0)
 for i in 10: control.update(.2)
 assert(game.player == original,"Near-tied defenders caused cursor oscillation")
 control.manual_switch()
 var manual: FootballPlayer = game.player
 assert(manual != original and manual.profile.role == "outfield")
 original.position = Vector3(.7,0,0)
 control.update(.5)
 assert(game.player == manual,"Manual override was immediately stolen")
 session.switch_mode = &"manual"
 for i in 8: control.update(.2)
 assert(game.player == manual,"Manual mode switched automatically")
 session.switch_mode = &"assisted"
 game._intro_active = true
 control.manual_switch()
 control.update(1)
 assert(game.player == manual,"Intro must own presentation and selection")
 game._intro_active = false
 # Actual friendly control beats loose-ball rankings without granting a touch.
 ball._dribble_controller = passer
 ball._dribble_control_lease = .5
 ball.last_touch = passer.team_name
 ball.last_action = &"dribble"
 ball.position = passer.position+Vector3(.5,FootballBall.RADIUS,0)
 control.manual_hold = 0
 var serial_before := ball.action_serial
 control.update(.2)
 assert(game.player == passer and ball.action_serial == serial_before)
 ball._dribble_controller = null
 ball._dribble_control_lease = 0
 # Physical pass marker: selection must stay on passer during windup.
 game._set_controlled_player(passer)
 for actor in game._home_players+game._away_players: actor.position = Vector3(-30,0,25)
 passer.position = Vector3.ZERO
 passer.rotation.y = -PI/2
 passer._flat_direction = Vector3.RIGHT
 receiver.position = Vector3(10,0,0)
 var visual := passer.get_node("Visual") as FootballerVisual
 passer.reset_for_stoppage()
 ball.position = Vector3(.6,FootballBall.RADIUS,0)
 ball.last_touch = passer.team_name
 passer._do_pass(true,Vector3.RIGHT,false,1,receiver)
 assert(passer._visual_pass_pending)
 assert(game.player == passer,"Windup switched before a real kick")
 visual.animation_player.seek(visual.action_contact_time(&"pass"),true)
 ball.position = passer._receive_contact_position()+Vector3.UP*.06
 passer._on_visual_action_contact(&"pass")
 assert(ball.last_action == &"through_pass","Expected a real physical pass")
 assert(game.player == receiver,"Actual pass release must select its recipient")
 assert(control.receiver == receiver and control.pass_serial == ball.action_serial)
 # Run commitment survives handover, and ball ownership is not granted.
 assert(receiver.receive_target_time > 0)
 assert(ball.last_touch_player == passer)
 receiver._stick = Vector2.ZERO
 receiver.velocity = Vector3.ZERO
 receiver._update_locomotion(1.0/60)
 assert(receiver.velocity.x > 0,"Recipient lost the intended receiving run")
 # Held shot/pass must not produce a second action on the new actor.
 receiver._pending_shot = .2
 receiver._shot_charge = .8
 Input.action_press("shoot")
 receiver.prepare_control_handover(true)
 receiver._update_actions(.016)
 assert(receiver._shot_charge < 0 and receiver._pending_shot == 0)
 Input.action_release("shoot")
 receiver._update_actions(.016)
 # Never cancel a physically committed kick during an unrelated handover.
 passer._visual_shot_pending = true
 passer.prepare_control_handover(false)
 assert(passer._visual_shot_pending)
 passer._visual_shot_pending = false
 # Invalid/dismissed selection is repaired even during a restart.
 game.player.set_meta("sent_off",true)
 game.player.hide()
 game._kickoff_pending = true
 control.update(.016)
 assert(control.eligible(game.player))
 var humans := 0
 for actor in game._home_players+game._away_players:
  if actor.controlled_by_human: humans+=1
 assert(humans == 1)
 game._kickoff_pending = false
 game.restart.begin("GOAL KICK", &"Beechlawn Rovers",Vector3(-47,0,0))
 assert(game.restart.taker.profile.role == "goalkeeper")
 assert(game.player.profile.role == "outfield" and not game.restart.taker.controlled_by_human)
 game.restart.update(1.7)
 assert(game.restart.phase == game.restart.Phase.ACTION,"AI keeper goal kick waited for human input")
 # AI vs AI must ignore both selection paths.
 game._spectator_mode = true
 for actor in game._home_players: actor.controlled_by_human = false
 control.manual_switch(); control.update(2)
 for actor in game._home_players: assert(not actor.controlled_by_human)
 print("PLAYER_SELECTION PASS: defender, hysteresis, manual hold/mode, intro, real pass release, run continuity, held input, committed action, dismissal, AI keepers/watch")
 game.free()
 quit()
