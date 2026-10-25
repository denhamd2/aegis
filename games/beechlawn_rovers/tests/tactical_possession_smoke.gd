extends SceneTree
## Distinguish control, travelling pass, loose contest and stoppage, read-only.
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game);await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	var ball: FootballBall = game.ball
	var reader := preload("res://scripts/tactical_possession.gd").new()
	var all: Array[FootballPlayer] = game._home_players + game._away_players
	for actor in all:actor.position = Vector3(0,0,90);actor.controlled_by_human = false
	for team: Array[FootballPlayer] in [game._home_players, game._away_players]:
		var other: Array[FootballPlayer] = game._away_players if team == game._home_players else game._home_players
		var carrier: FootballPlayer = game._nearest_outfielder(team, Vector2.ZERO)
		var defender: FootballPlayer = game._nearest_outfielder(other, Vector2.ZERO)
		carrier.position = Vector3(-.6,0,0);carrier.rotation.y = -PI/2
		ball.position = Vector3(0,.11,0);ball.last_touch = carrier.team_name
		ball.last_action = &"dribble";ball.linear_velocity = Vector3.ZERO
		var serial := ball.action_serial
		if reader.sample(ball,all).state != &"controlled":_fail(game,"Present control missing");return
		carrier.position = Vector3(-4,0,0)
		if reader.sample(ball,all).state != &"loose":_fail(game,"Remote last touch claimed control");return
		carrier.receive_target = Vector3(10,0,0);carrier.receive_target_time = 2
		ball.last_action = &"pass";ball.linear_velocity = Vector3(8,0,0)
		if reader.sample(ball,all).state != &"incoming":_fail(game,"Incoming pass missing");return
		carrier.receive_target_time = 0
		ball.last_action = &"deflection";ball.linear_velocity = Vector3.ZERO
		carrier.position = Vector3(-.4,0,0);defender.position = Vector3(.4,0,0)
		for reverse in [false,true]:
			if reverse:all.reverse()
			if reader.sample(ball,all).state != &"contested":_fail(game,"Contact tie depends on actor order");return
		if reader.sample(ball,all,true).state != &"stopped":_fail(game,"Dead ball has a tactical owner");return
		if ball.last_touch != carrier.team_name or ball.action_serial != serial:_fail(game,"Snapshot mutated rules/physics");return
		# Support assignments are unique, separated and retain centre-back cover.
		defender.position = Vector3(10,0,8);carrier.position = Vector3(-.6,0,0)
		for actor in team:
			if actor != carrier:actor.position = Vector3(actor.profile.starting_position.x*actor.attack_sign,0,actor.profile.starting_position.y)
		var supports: Dictionary = game._team_tactics._support_targets(team,carrier,Vector2.ZERO,other)
		var counts := {"outlet":0,"forward_run":0}
		for id in supports:
			counts[supports[id].intent] += 1
			var actor := instance_from_id(id) as FootballPlayer
			if actor.profile.tactical_role == "centre_back":_fail(game,"Support stripped central cover");return
		if counts.outlet != 1 or counts.forward_run != 1:_fail(game,"Support omitted outlet or forward run");return
		for actor in all:actor.position = Vector3(0,0,90)
	print("PASS: mirrored possession states, order-neutral contests, read-only rules and outlet/run/cover roles")
	game.free();quit(0)
func _fail(game: Node, message: String) -> void:
	push_error(message);game.free();quit(1)
