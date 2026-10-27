extends SceneTree
## Two evaluated heads in the same contact window: one physical winner.
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false);game.set_physics_process(false);game._set_players_physics_enabled(false)
	for player in game._home_players + game._away_players: player.position=Vector3(0,0,90)
	var home: FootballPlayer=game._home_players[2]
	var away: FootballPlayer=game._away_players[2]
	var ball: FootballBall=game.ball
	var ordered: Array[FootballPlayer]=[home,away]
	for reverse in [false,true]:
		for closer in ["equal","home","away","miss"]:
			ball.freeze=true;ball.release_for_restart()
			for player in ordered:
				player.reset_for_stoppage()
				player.position=Vector3(35 if player==home else 35.7,.02,0)
				player.rotation.y=-PI/2 if player==home else PI/2
				assert(player._footballer_visual.play_aerial(&"header",1,&"right",true))
				player._footballer_visual.animation_player.seek(.3,true,true)
				player._aerial_controller._active=&"header"
				player._aerial_controller._elapsed=.3
				player._aerial_controller._contact_seconds=.3
				player._aerial_controller._header_aim=Vector3.RIGHT if player==home else Vector3.LEFT
			var home_head:=home._aerial_controller.forehead_point()
			var away_head:=away._aerial_controller.forehead_point()
			away.position+=home_head-away_head+Vector3(.08,0,0)
			away_head=away._aerial_controller.forehead_point()
			ball.position=(home_head+away_head)*.5
			if closer=="home":ball.position=home_head
			elif closer=="away":ball.position=away_head
			elif closer=="miss":ball.position+=Vector3(0,1,0)
			ball.last_touch=&"none";ball.last_touch_player=null;ball.last_action=&"cross";ball.last_strike_part=&"foot"
			ball.action_serial+=1
			var serial:=ball.action_serial
			for player in ordered:
				player._aerial_controller._serial=serial
				player._aerial_controller._incoming_kind=&"cross"
				player._aerial_controller._contact_window=.065
			var expected: FootballPlayer=FootballAerialContest.winner(ball)
			assert(expected==null if closer=="miss" else expected!=null)
			if closer=="home":assert(expected==home)
			if closer=="away":assert(expected==away)
			for player in ([away,home] if reverse else [home,away]):
				player._aerial_controller.resolve_contact(0)
			assert(ball.action_serial==serial+(0 if expected==null else 1),"Duel must emit zero or one ball impulse")
			if expected!=null:assert(ball.last_touch_player==expected and ball.last_strike_part==&"head")
			print("BR019_DUEL order=",reverse," case=",closer," winner=",expected.profile.player_id if expected else "none")
	var keeper: FootballPlayer
	for player in game._home_players:
		if player.profile.role=="goalkeeper": keeper=player
	assert(keeper!=null)
	keeper.reset_for_stoppage();keeper.position=Vector3(-49.5,0,0);keeper.rotation.y=-PI/2
	away.reset_for_stoppage();away.position=Vector3(-48.8,0,0);away.rotation.y=PI/2
	assert(keeper._footballer_visual.play_keeper_save(&"KeeperHighClaim",.25))
	keeper._footballer_visual.animation_player.seek(.25,true,true)
	assert(away._footballer_visual.play_aerial(&"header",1,&"right",true))
	away._footballer_visual.animation_player.seek(.3,true,true)
	away._aerial_controller._active=&"header";away._aerial_controller._elapsed=.3
	away._aerial_controller._contact_seconds=.3;away._aerial_controller._contact_window=.065
	ball.release_for_restart();ball.last_touch=away.team_name;ball.last_action=&"cross";ball.action_serial+=1
	away._aerial_controller._serial=ball.action_serial
	var glove: Vector3=keeper._footballer_visual.hand_positions()[0]
	away.position+=glove-away._aerial_controller.forehead_point()+Vector3(.05,0,0)
	ball.position=glove
	keeper._goalkeeper_controller._shot_active=true
	keeper._goalkeeper_controller._save_animation_started=true
	keeper._goalkeeper_controller._reaction_remaining=0
	assert(not keeper._goalkeeper_controller.claim_contact_due(),"Stale keeper motion cannot claim a later cross")
	keeper._goalkeeper_controller._observed_action_serial=ball.action_serial
	assert(keeper._goalkeeper_controller.claim_contact_due())
	assert(FootballAerialContest.winner(ball)==keeper,"Closer legal glove must win the cross")
	ball.position=away._aerial_controller.forehead_point()
	assert(FootballAerialContest.winner(ball)==away,"Closer forehead must win without a keeper priority override")
	ball.position.x=-35.0
	assert(not keeper._goalkeeper_controller.claim_contact_due(),"Keeper cannot claim outside the own handling area")
	game.free()
	print("BR019_AERIAL_DUEL PASS: stable head winner, misses, legal glove/forehead reach and area bounds")
	quit()
