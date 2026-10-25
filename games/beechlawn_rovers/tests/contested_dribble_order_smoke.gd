extends SceneTree
## With no established owner, equal opposing reaches must not favor first caller.
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game);await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	var ball: FootballBall=game.ball
	for actor in game._home_players+game._away_players:actor.position=Vector3(0,0,90)
	var home: FootballPlayer=game._nearest_outfielder(game._home_players,Vector2.ZERO)
	var away: FootballPlayer=game._nearest_outfielder(game._away_players,Vector2.ZERO)
	home.position=Vector3(-.4,0,0);home.rotation.y=-PI/2
	away.position=Vector3(.4,0,0);away.rotation.y=PI/2
	home._stick=Vector2.RIGHT;away._stick=Vector2.RIGHT
	for reverse in [false,true]:
		await physics_frame
		ball.freeze=true;ball.position=Vector3(0,.11,0);ball.linear_velocity=Vector3.ZERO
		ball.last_touch=&"none";ball.last_action=&"none"
		ball._dribble_cooldowns.clear();ball._dribble_controller=null;ball._dribble_control_lease=0
		var serial:=ball.action_serial
		var order: Array=[away,home] if reverse else [home,away]
		for actor in order:
			ball.dribble_touch(actor,Vector3.RIGHT if actor==home else Vector3.LEFT,false,false,.23,.48,1.05)
		if ball.action_serial!=serial:
			push_error("Equal opposing reach awarded dribble possession to the first physics caller")
			game.free();quit(1);return
	print("PASS: exact opposing contest waits for physical separation/contact in both call orders")
	game.free();quit(0)
