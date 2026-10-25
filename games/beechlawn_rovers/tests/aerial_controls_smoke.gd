extends SceneTree
## Actual keyboard charge/release and legal keeper responses to airborne passes.
var failures: Array[String] = []
var launched := {&"lofted_pass":0,&"cross":0}
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	# Keyboard events are delivered between rendered frames; use the real
	# 60 Hz cadence, rather than queueing press/release in one fast-physics burst.
	Engine.time_scale=1
	Engine.physics_ticks_per_second=60
	Engine.max_physics_steps_per_frame=8
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var ball: FootballBall=game.ball
	for frame in 3: await process_frame
	for actor in game._home_players+game._away_players:
		actor.position=Vector3(0,0,90)
		actor.controlled_by_human=false
	ball.touched.connect(func(kind: StringName,_speed: float):
		if launched.has(kind):launched[kind]+=1)
	var actor: FootballPlayer=game._home_players[2]
	var receiver: FootballPlayer
	for candidate in game._home_players:
		if candidate.profile.starting_slot=="striker_left":receiver=candidate
	for kind: StringName in [&"lofted_pass",&"cross"]:
		actor.reset_for_stoppage()
		actor.controlled_by_human=true
		actor.position=Vector3(33,0,20) if kind==&"cross" else Vector3.ZERO
		var direction:=Vector3(10,0,-18).normalized() if kind==&"cross" else Vector3(game.player.camera.global_basis.x.x,0,game.player.camera.global_basis.x.z).normalized()
		actor.rotation.y=atan2(-direction.x,-direction.z)
		receiver.position=actor.position+direction*19
		ball.freeze=true
		ball.release_for_restart()
		ball.position=actor.position+direction*.6+Vector3.UP*.13
		ball.last_touch=actor.team_name
		ball.last_action=&"dribble"
		await physics_frame
		actor.set_physics_process(true)
		if kind==&"lofted_pass":_key(KEY_RIGHT,true)
		_key(KEY_R if kind==&"lofted_pass" else KEY_T,true)
		for frame in 20:await physics_frame
		_check(actor._aerial_controller._charge>.2 and launched[kind]==0,"Keyboard charge did not build power before release")
		_key(KEY_R if kind==&"lofted_pass" else KEY_T,false)
		for frame in 52:await physics_frame
		_check(launched[kind]==1,"Keyboard release did not produce exactly one contact-gated aerial pass")
		_key(KEY_RIGHT,false)
		actor.set_physics_process(false)
		actor.reset_for_stoppage()
		actor.position=Vector3(0,0,90)
		receiver.position=Vector3(0,0,90)
	for team: Array[FootballPlayer] in [game._home_players,game._away_players]:
		var keeper: FootballPlayer
		for candidate in team:
			if candidate.profile.role=="goalkeeper":keeper=candidate
		var sx:=keeper.attack_sign
		keeper.position=Vector3(-49.5*sx,0,0)
		for kind: StringName in [&"cross",&"lofted_pass"]:
			keeper.reset_for_stoppage()
			ball.release_for_restart()
			ball.position=keeper.position+Vector3(.5*sx,1,0)
			ball.linear_velocity=Vector3(-4*sx,0,0)
			ball.last_touch=&"Boardeaux" if sx>0 else &"Beechlawn Rovers"
			ball.last_action=kind
			ball.action_serial+=1
			var controller:=keeper._goalkeeper_controller
			controller.update_before_move(0)
			_check(not controller.try_save(),"Keeper caught an aerial delivery before its reaction delay")
			controller.update_before_move(.35)
			_check(controller.try_save() and ball.goalkeeper_is_holding(keeper),"Keeper did not claim a reachable slow opposing aerial pass")
			ball.release_for_restart()
			keeper.reset_for_stoppage()
			ball.position=keeper.position+Vector3(.5*sx,1,0)
			ball.linear_velocity=Vector3(-4*sx,0,0)
			ball.last_touch=keeper.team_name
			ball.last_action=kind
			ball.action_serial+=1
			controller.update_before_move(.35)
			_check(not controller.try_save(),"Keeper handled a teammate's deliberately kicked aerial pass")
		keeper.position=Vector3(0,0,90)
	for message in failures:push_error(message)
	print("AERIAL_CONTROLS launches=",launched," failures=",failures.size())
	game.free()
	quit(0 if failures.is_empty() else 1)
func _key(code: Key,pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
func _check(passed: bool,message: String) -> void:
	if not passed:failures.append(message)
