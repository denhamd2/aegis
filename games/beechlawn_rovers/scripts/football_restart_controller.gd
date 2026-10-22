extends Node
## Owns dead-ball preparation and release; match physics resumes at contact.
enum Phase { INACTIVE, PREPARE, ACTION }
var phase := Phase.INACTIVE
var game: Node3D
var kind := ""
var team: StringName
var spot := Vector3.ZERO
var taker: FootballPlayer
var direction := Vector3.RIGHT
var charge := -1.0
var shot := false
var elapsed := 0.0
var released := false
var _ignore_buttons := true
var _contact_callback: Callable
var _finish_callback: Callable
var _action_elapsed := 0.0
var _action_timeout := 0.0
var _normal_controls := ""
var _aim_visual: MeshInstance3D

func setup(match_scene: Node3D) -> void:
	game = match_scene

func active() -> bool: return phase != Phase.INACTIVE

func begin(restart_kind: String, awarded_team: StringName, position: Vector3) -> void:
	if active(): return
	game.rules.restart_taker=null
	game.rules.restart_kind=""
	kind = restart_kind; team = awarded_team; spot = position
	phase = Phase.PREPARE; elapsed = 0; charge = -1; released = false; _ignore_buttons = true
	game._boundary_pending = false; game._goal_pause_timer = 0; game._kickoff_pending = false
	game._set_players_physics_enabled(false)
	var players: Array = game._home_players if team == &"Beechlawn Rovers" else game._away_players
	taker = game._nearest_outfielder(players, Vector2(spot.x,spot.z))
	if kind == "GOAL KICK" or taker == null: taker = players[0]
	if team == &"Beechlawn Rovers" and not game._spectator_mode: game._set_controlled_player(taker)
	game.ball.release_for_restart()
	game.ball.freeze = true
	for actor in game._home_players + game._away_players:
		actor.reset_for_stoppage()
	direction = Vector3(taker.attack_sign,0, -signf(spot.z)*0.85 if kind == "THROW-IN" else 0).normalized()
	if kind == "PENALTY":
		spot = Vector3(taker.attack_sign*41.5,0,0)
		direction = Vector3(taker.attack_sign,0,0)
	spot.y = PitchSurface.height_at(spot.x,spot.z) if game.terrain_enabled else 0
	game.ball.global_position = spot + Vector3.UP*(FootballBall.RADIUS+0.015)
	taker.global_position = spot - direction*0.58
	if kind == "THROW-IN": taker.global_position = Vector3(spot.x,spot.y,signf(spot.z)*34.18)
	taker.rotation.y = atan2(-direction.x,-direction.z)
	_place_players()
	_contact_callback = _on_contact
	_finish_callback = _on_finished
	var visual := taker.get_node("Visual") as FootballerVisual
	visual.action_contact.connect(_contact_callback)
	visual.action_finished.connect(_finish_callback)
	if kind == "THROW-IN":
		visual._presentation_active=true
		visual.animation_tree.active=false
		visual.animation_player.play(&"AN_Beechlawn_ThrowIn")
		visual.animation_player.seek(0.0,true)
		visual.animation_player.pause()
		_hold_throw_ball()
	for actor in game._home_players + game._away_players: actor.reset_physics_interpolation()
	game.ball.reset_physics_interpolation()
	_normal_controls=game.get_node("HUD/Controls").text
	game.get_node("HUD/Controls").text=kind+"\nWASD  Aim   Hold/release E  "+("Throw" if kind=="THROW-IN" else "Pass   Space  Shoot")+"\nEsc  Title screen"
	_aim_visual=MeshInstance3D.new()
	_aim_visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(_aim_visual)
	_draw_aim()
	_prompt()

func _place_players() -> void:
	for actor in game._home_players + game._away_players:
		if actor == taker: continue
		var offset: Vector3 = actor.global_position - spot
		offset.y = 0
		var separation := 2.1 if kind == "THROW-IN" else (9.3 if actor.team_name != team else 1.2)
		if kind == "PENALTY":
			if actor.profile.role == "goalkeeper" and actor.team_name != team:
				actor.global_position = Vector3(taker.attack_sign*52.5,0,0)
			else:
				actor.global_position.x = taker.attack_sign*minf(actor.global_position.x*taker.attack_sign,35.5)
				offset = actor.global_position - spot; offset.y = 0
				if offset.length() < 9.3: actor.global_position = spot + offset.normalized()*9.3
		elif offset.length() < separation:
			if offset.length() < .01: offset = Vector3(-taker.attack_sign,0,1).normalized()
			actor.global_position = spot + offset.normalized()*separation
		actor.global_position.x = clampf(actor.global_position.x,-52.5,52.5)
		actor.global_position.z = clampf(actor.global_position.z,-33,33)
		actor.global_position.y = PitchSurface.height_at(actor.global_position.x,actor.global_position.z) if game.terrain_enabled else 0

func update(delta: float) -> void:
	if not active(): return
	elapsed += delta
	if kind == "THROW-IN" and not released: _hold_throw_ball()
	if phase == Phase.ACTION:
		_action_elapsed += delta
		# A lost/missing animation marker must fail closed, not hang the match.
		if not released and _action_elapsed > _action_timeout:
			push_error("Restart missed contact marker: " + kind)
			_disconnect()
			phase = Phase.INACTIVE
			begin(kind,team,spot)
		return
	if team != &"Beechlawn Rovers" or game._spectator_mode:
		if elapsed >= 1.6:
			_choose_ai_target()
			take(0.55,kind == "PENALTY")
		return
	var buttons := Input.is_action_pressed("pass") or Input.is_action_pressed("shoot")
	if _ignore_buttons:
		_ignore_buttons = buttons
		return
	var stick := Input.get_vector("move_left","move_right","move_up","move_down")
	if stick.length_squared() > .05:
		var camera: Camera3D = game.camera_rig.get_node("Camera3D")
		var right := camera.global_basis.x; right.y = 0
		var forward := -camera.global_basis.z; forward.y = 0
		direction = (right.normalized()*stick.x-forward.normalized()*stick.y).normalized()
		if kind == "THROW-IN":
			direction.z = -signf(spot.z)*maxf(absf(direction.z),.2)
			direction = direction.normalized()
		if kind == "PENALTY": direction = Vector3(taker.attack_sign,0,clampf(direction.z,-.24,.24)).normalized()
		taker.rotation.y = atan2(-direction.x,-direction.z)
		if kind != "THROW-IN":
			taker.global_position = spot-direction*.58
			taker.global_position.y = PitchSurface.height_at(taker.global_position.x,taker.global_position.z) if game.terrain_enabled else 0
	_draw_aim()
	if charge < 0 and (Input.is_action_pressed("pass") or (kind != "THROW-IN" and Input.is_action_pressed("shoot"))):
		shot = Input.is_action_pressed("shoot")
		charge = 0
	if charge >= 0:
		if Input.is_action_pressed("shoot" if shot else "pass"):
			charge = minf(1,charge+delta/.95)
			game._set_power(charge)
		else: take(charge,shot)

func _choose_ai_target() -> void:
	var players: Array = game._home_players if team == &"Beechlawn Rovers" else game._away_players
	var best: FootballPlayer
	var score := INF
	for actor in players:
		if actor == taker or actor.profile.role == "goalkeeper": continue
		var offset: Vector3 = actor.global_position - spot; offset.y=0
		var value := absf(offset.length()-12.0)-offset.x*taker.attack_sign*.15
		if value < score: score=value; best=actor
	if best != null and kind != "PENALTY":
		direction = (best.global_position-taker.global_position).normalized(); direction.y=0
		direction=direction.normalized()
	taker.rotation.y=atan2(-direction.x,-direction.z)

func take(power: float, shooting: bool = false) -> void:
	if phase != Phase.PREPARE: return
	charge=clampf(power,.08,1); shot=shooting
	phase=Phase.ACTION; _action_elapsed=0
	if _aim_visual!=null: _aim_visual.hide()
	var visual := taker.get_node("Visual") as FootballerVisual
	visual.end_presentation()
	var clip: StringName = &"AN_Beechlawn_ThrowIn" if kind == "THROW-IN" else (FootballerVisual.SHOT_CLIP if shot else FootballerVisual.PASS_CLIP)
	var action: StringName = &"restart_throw" if kind == "THROW-IN" else (&"restart_shot" if shot else &"restart_pass")
	_action_timeout=visual.animation_player.get_animation(clip).length+.3
	if not visual._play_action(action,clip,1.0,false,true):
		phase=Phase.PREPARE
		game._set_message("Restart animation unavailable")

func _on_contact(action: StringName) -> void:
	if released or phase != Phase.ACTION or not String(action).begins_with("restart_"): return
	var ball: FootballBall = game.ball
	if kind != "THROW-IN" and ball.global_position.distance_to(taker.global_position) > 1.1: return
	released=true
	ball.freeze=false
	var speed := lerpf(7.0,18.0,charge)
	var lift := .12
	if kind == "THROW-IN":
		speed=lerpf(7.0,16.5,charge); lift=lerpf(3.0,5.7,charge)
	elif shot:
		speed=lerpf(17.0,31.0,charge); lift=lerpf(.5,2.8,charge)
	elif kind in ["CORNER RESTART","GOAL KICK"]:
		lift=lerpf(1.2,3.6,charge)
	ball.kick(direction,speed,lift,&"throw_in" if kind == "THROW-IN" else (&"shot" if shot else &"pass"),team,taker)
	game.rules.restart_released(taker,kind)
	game._set_power(0)
	# Keep the taker in follow-through until the animation finishes. Everyone else
	# resumes immediately, including the keeper's real shot-reaction controller.
	for actor in game._home_players+game._away_players:
		if actor != taker: actor.set_physics_process(true)
	game._set_message(kind+" · "+String(team))

func _on_finished(action: StringName) -> void:
	if phase != Phase.ACTION or not String(action).begins_with("restart_"): return
	if not released: return
	_disconnect()
	taker.consume_pass_input_until_released()
	taker.set_physics_process(true)
	phase=Phase.INACTIVE
	_clear_aim()

func _disconnect() -> void:
	var visual := taker.get_node("Visual") as FootballerVisual
	if visual.action_contact.is_connected(_contact_callback): visual.action_contact.disconnect(_contact_callback)
	if visual.action_finished.is_connected(_finish_callback): visual.action_finished.disconnect(_finish_callback)

func _hold_throw_ball() -> void:
	var visual := taker.get_node("Visual") as FootballerVisual
	var skeleton := visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var left := skeleton.find_bone("mixamorig_LeftHand")
	var right := skeleton.find_bone("mixamorig_RightHand")
	var hands: Vector3 = (skeleton.get_bone_global_pose(left).origin+skeleton.get_bone_global_pose(right).origin)*.5
	game.ball.global_position = skeleton.to_global(hands)

func _prompt() -> void:
	game._set_message(kind+" · "+String(team)+(" · WASD aim · Hold E, release to throw" if kind == "THROW-IN" else " · WASD aim · Hold E pass / Space shoot"))
	game._message_time=999

func cancel() -> void:
	if not active(): return
	_clear_aim()
	_disconnect()
	if is_instance_valid(taker):
		taker.get_node("Visual").end_presentation()
	phase=Phase.INACTIVE
	game._set_power(0)

func _draw_aim() -> void:
	if _aim_visual==null: return
	var start:=spot+direction*.45
	var tip:=spot+direction*2.7
	var right:=direction.cross(Vector3.UP)*.07
	var arrow:=direction.cross(Vector3.UP)*.24
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [start-right,start+right,tip-right,start+right,tip+right,tip-right,tip-arrow,tip+arrow,tip+direction*.4]:
		var vertex: Vector3=point
		vertex.y=(PitchSurface.height_at(vertex.x,vertex.z) if game.terrain_enabled else 0)+.055
		tool.add_vertex(vertex)
	_aim_visual.mesh=tool.commit()
	if _aim_visual.material_override==null:
		var material:=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		material.albedo_color=Color(.95,.83,.2)
		_aim_visual.material_override=material

func _clear_aim() -> void:
	if is_instance_valid(_aim_visual): _aim_visual.queue_free()
	_aim_visual=null
	game.get_node("HUD/Controls").text=_normal_controls
