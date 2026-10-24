extends SceneTree
## Real imported foot markers, bilateral outcomes, possession loss and shielding.
var game: Node3D
var actor: FootballPlayer
var ball: FootballBall
var visual: FootballerVisual
var touches := 0
func _initialize() -> void: call_deferred("_run")
func _place() -> void:
	actor.reset_for_stoppage()
	actor.position = Vector3(0, PitchSurface.height_at(0,0)+.005, 0)
	actor.rotation = Vector3.ZERO
	actor.velocity = Vector3.ZERO
	actor._ignore_pass_until_released = false
	ball.release_for_restart()
	ball.position = actor.position+Vector3(.09,.13,-.50)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.last_touch = actor.team_name
	ball.last_touch_player = actor
	ball.last_action = &"dribble"
	ball.freeze = false
	visual.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	visual.animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	touches = 0

func _advance(frames: int) -> void:
	for frame in frames:
		visual.animation_player.advance(1.0/60)
		actor.skills.before_move(1.0/60)
		actor.skills.resolve_contact(1.0/60)
		await physics_frame

func _run() -> void:
	game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	game._kickoff_pending = false
	for player in game._home_players+game._away_players:
		player.position = Vector3(140,0,140)
		if player.profile.player_id == &"shane_denham": actor = player
	actor.controlled_by_human = true
	visual = actor._footballer_visual
	ball = game.ball
	ball.touched.connect(func(kind: StringName, _speed: float):
		if kind == &"skill": touches += 1)
	for action in PlayerSkillController.ACTIONS:
		assert(InputMap.has_action(action))
		for direction in [-1.,1.]:
			_place()
			ball.position.x = actor.position.x+.09*direction
			var origin := ball.position
			var serial := ball.action_serial
			assert(actor.skills.request(StringName(action), Vector3(direction,0,0)), "Skill rejected: "+action)
			await _advance(16)
			assert(ball.action_serial == serial and touches == 0, "Skill fired before its foot marker")
			await _advance(8)
			assert(touches == 1 and ball.last_action == &"skill", "Missing physical skill touch: "+action)
			assert(ball.last_strike_style == StringName(action))
			assert(ball.linear_velocity.dot(actor.skills.exit_direction) > .5, "Skill failed to move the ball into its exit lane: "+action)
			var contact: Dictionary = actor.get_meta("last_skill_contact")
			assert(float(contact.distance) <= actor.tuning.kick_foot_contact_radius)
			assert(ball.position.distance_to(origin) > .10, "Skill must move the independent ball")
			assert(not actor.skills.request(&"ball_roll"), "Committed skills cannot be spammed")
			await _advance(22)
			assert(touches == 1 and actor.skills.active == &"", "Skill duplicated touch or failed to recover")
			assert(visual.animation_tree.active, "Locomotion did not resume")
			assert(not actor.skills._capsule_exception, "Skill must restore ordinary own-body collision")
			print("SKILL_PASS ", action," side=",direction," contact=",contact.distance)
	_place()
	assert(actor.skills.request(&"step_over"))
	await _advance(16)
	ball.position += Vector3(2,0,0)
	await _advance(10)
	assert(touches == 0 and actor.skills.active == &"", "A missed marker must not touch a distant ball")
	_place()
	assert(actor.skills.request(&"drag_back"))
	ball.action_serial += 1
	ball.last_touch = &"Boardeaux"
	actor.skills.before_move(1.0/60)
	await _advance(30)
	assert(touches == 0 and actor.skills.active == &"", "Possession loss must cancel the pending touch")
	_place()
	actor._shot_charge = .7
	actor.set_physics_process(true)
	Input.action_press("shoot")
	Input.action_press("pass")
	await physics_frame
	await physics_frame
	actor.set_physics_process(false)
	Input.action_release("pass")
	Input.action_release("shoot")
	assert(actor.skills.active == &"fake_shot" and actor._shot_charge < 0 and not actor._visual_shot_pending)
	await _advance(25)
	assert(touches == 1 and ball.last_action != &"shot", "Fake shot must cancel the shot, then make one controlled exit touch")
	_place()
	var defender: FootballPlayer = game._away_players[2]
	defender.position = actor.position+Vector3(0,0,1.3)
	Input.action_press("shield")
	actor.skills.before_move(.2)
	assert(actor.skills.shielding and actor.skills.facing.dot(Vector3.FORWARD) > .9)
	actor._stick = Vector2.RIGHT
	actor._update_locomotion(.2)
	assert(Vector2(actor.velocity.x, actor.velocity.z).length() <= actor.tuning.jog_speed*actor.tuning.shield_speed_scale+.01)
	assert(float(visual.animation_tree.get("parameters/Shield/blend_amount")) > .9)
	visual.set_shielding(false, 1)
	visual.animation_tree.set("parameters/Locomotion/blend_position", .55)
	visual.animation_tree.advance(.2)
	var skeleton := visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var thigh := skeleton.find_bone("mixamorig_LeftUpLeg")
	var leg_before := skeleton.get_bone_pose_rotation(thigh)
	var hand_before := visual.bone_world_position(&"mixamorig_LeftHand")
	visual.set_shielding(true, 1)
	visual.animation_tree.advance(0)
	assert(leg_before.angle_to(skeleton.get_bone_pose_rotation(thigh)) < .001, "Shield overlay must preserve locomotion legs")
	assert(hand_before.distance_to(visual.bone_world_position(&"mixamorig_LeftHand")) > .02, "Shield overlay must visibly pose the upper body")
	visual.animation_tree.advance(.2)
	assert(leg_before.angle_to(skeleton.get_bone_pose_rotation(thigh)) > .001, "Shielding must not freeze running legs")
	Input.action_press("sprint")
	actor.skills.before_move(.2)
	assert(not actor.skills.shielding)
	Input.action_release("sprint")
	Input.action_release("shield")
	_place()
	defender.reset_for_stoppage()
	defender.position = ball.position+Vector3(0,0,-.60)
	defender.rotation = Vector3(0,PI,0)
	defender._footballer_visual.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	defender._footballer_visual.animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	Input.action_press("shield")
	actor.skills.before_move(.2)
	assert(actor.skills.shielding)
	assert(defender._attempt_tackle())
	for frame in 18:
		defender._footballer_visual.animation_player.advance(1.0/60)
		actor.skills.before_move(1.0/60)
		await physics_frame
	assert(ball.last_touch == defender.team_name and not actor.skills.shielding, "A reachable clean tackle must beat shielding")
	Input.action_release("shield")
	_place()
	assert(actor.skills.request(&"ball_roll"))
	actor.reset_for_stoppage()
	await _advance(30)
	assert(touches == 0 and actor.skills.active == &"" and not actor.skills.shielding)
	_place()
	assert(actor.skills.request(&"ball_roll"))
	defender.position = ball.position+Vector3(0,0,-.30)
	ball._dribble_controller = defender
	ball._dribble_control_lease = .12
	ball._dribble_force_frame = -1
	actor.skills.control_setup()
	assert(ball._dribble_force_frame == -1, "A skill must not apply a second controller's force")
	visual.animation_player.advance(.30)
	actor.skills.resolve_contact(1.0/60)
	assert(touches == 0 and actor.skills.active == &"", "A prior closer claimant must also prevent the skill exit touch")
	_place()
	actor.controlled_by_human = false
	defender.position = actor.position+Vector3(.15,0,-1.4)
	assert(actor.skills.try_ai_skill(), "A slow carrier facing close frontal pressure should have a lateral exit")
	actor.reset_for_stoppage()
	defender.position = actor.position+Vector3(0,0,-5)
	assert(not actor.skills.try_ai_skill(), "AI must not perform a skill in an open lane")
	game.free()
	print("SKILL_CONTROL PASS: 12 bilateral boot contacts, misses/loss/reset, fake-shot cancellation, shielding speed/pose")
	quit()
