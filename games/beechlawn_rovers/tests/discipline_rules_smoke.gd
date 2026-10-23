extends SceneTree
var failed:=false
func _initialize() -> void:call_deferred("_run")
func check(ok: bool,message: String) -> void:
	if not ok: failed=true;push_error(message)
func _run() -> void:
	var game=load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._kickoff_pending=false
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var rules=game.rules
	var tackler: FootballPlayer=game._away_players[3]
	var victim: FootballPlayer=game._home_players[3]
	tackler.position=Vector3(0,0,0)
	tackler.rotation.y=-PI/2
	victim.position=Vector3(.75,0,0)
	game.ball.position=Vector3(1.5,FootballBall.RADIUS,0)
	game.ball.freeze=true
	tackler._attempt_tackle()
	check(not game.restart.active(),"Foul waits for standing tackle contact")
	tackler._footballer_visual.animation_player.advance(.25)
	await process_frame
	check(game.restart.active() and game.restart.kind=="FREE KICK","Actual opponent-first standing tackle awards a free kick")
	game.restart.cancel()
	rules._last_challenge_tick=-1000
	var event={"opponent_contact":true,"ball_first":false,"relative_speed":3.0,"from_behind":false,"sliding":false,"position":Vector3(15,0,2)}
	check(rules.classify_challenge(event)=="foul","Careless contact free kick")
	event.relative_speed=7
	check(rules.classify_challenge(event)=="yellow","Reckless contact yellow")
	event.sliding=true;event.relative_speed=12
	check(rules.classify_challenge(event)=="red","Excessive force red")
	event.ball_first=true;event.relative_speed=3
	check(rules.classify_challenge(event)=="clean","Clean ball-first contact stays live")
	event.ball_first=false
	check(rules.adjudicate(tackler,victim,event)=="foul","Foul enters rules engine")
	check(game.restart.active() and game.restart.kind=="FREE KICK","Free kick stops play")
	game.restart.cancel()
	event.position=Vector3(44,0,2)
	rules._last_challenge_tick=-1000
	rules.adjudicate(tackler,victim,event)
	check(game.restart.kind=="PENALTY" and is_equal_approx(game.restart.spot.x,41.5),"Defending foul inside box awards penalty spot")
	game.restart.cancel()
	rules.issue_card(tackler,"yellow")
	check(game._away_players.size()==11 and tackler.get_meta("yellow_cards")==1,"First yellow keeps player")
	rules.issue_card(tackler,"yellow")
	check(game._away_players.size()==10 and not tackler.visible and tackler.collision_layer==0,"Second yellow removes actor and collisions")
	check(not get_nodes_in_group("football_players").has(tackler),"Dismissed player excluded from AI/radar")
	var keeper: FootballPlayer
	for actor in game._away_players:
		if actor.profile.role=="goalkeeper":keeper=actor
	rules.issue_card(keeper,"red")
	check(game._away_players.size()==9,"Straight red reduces team")
	check(game._away_players.filter(func(a):return a.profile.role=="goalkeeper").size()==1,"Dismissed goalkeeper replaced in role")
	# Throw directly into the opponents' goal must not count.
	var thrower: FootballPlayer=game._home_players[2]
	rules.restart_released(thrower,"THROW-IN")
	var score: int=game._home_score
	game._on_goal("Beechlawn Rovers",1)
	check(game._home_score==score and game.restart.kind=="GOAL KICK","Direct throw-in goal is disallowed")
	game.restart.cancel()
	# A different player's touch clears the direct restart restriction.
	rules.restart_released(thrower,"THROW-IN")
	game.ball.action_serial+=1
	game.ball.record_touch(game._away_players[2])
	await process_frame
	check(rules.restart_taker==null,"Another player's touch ends direct-throw restriction")
	rules.restart_released(thrower,"THROW-IN")
	game.ball.action_serial+=1
	game.ball.record_touch(thrower)
	await process_frame
	check(game.restart.kind=="INDIRECT FREE KICK" and game.restart.active(),"Restart taker cannot touch twice before another player")
	game.restart.cancel()
	for index in 3: rules.issue_card(game._away_players[-1],"red")
	check(game._full_time and game.ball.freeze,"Fewer than seven ends match safely")
	game.free()
	print("DISCIPLINE free kicks, penalties, yellow/second yellow/red, keeper replacement, direct throw goals failures=",int(failed))
	quit(1 if failed else 0)
