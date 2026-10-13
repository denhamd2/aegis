extends Node
## A wrestler holding each weapon in the arena (No Holds Barred), from a close
## three-quarter camera: checks the grip (WeaponActor.grip_frame against each
## model's grip_r), the off hand on grip_l, the carry pose, and how the
## materials read under the hall's lights.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 960x540 tools/probe/weapon_hold_shot.tscn -- \
##       --out /tmp/hold --weapons steel_chair,baseball_bat [--walk]

var _out := "/tmp/hold"
var _ids: Array = ["steel_chair", "baseball_bat"]
var _walk := false
## --close: a tight shot on his right side and hands.
var _close := false
## --bare: the arena hidden -- the plain floor and studio light of
## paired_shot --bare, plus a sky for metals to reflect. Fast to render and
## nothing in the frame but him and the weapon; the arena run is the
## materials check.
var _bare := false
## --swing: instead of the hold, three frames of a swing -- the load, the
## contact and the follow-through -- seen from his right (<id>_0/1/2.png).
var _swing := false
## --front: the swing seen from in front of him and to his right instead.
var _front := false
## --pickup: each weapon lying on the floor in front of him and picked up:
## four frames through the pickup (<id>_p0..3.png).
var _pickup := false
## --fall: Cody knocked down by Roman's heavy kick, from the side: frames
## through the fall to the mat (fall_0..7.png).
var _fall := false
## --table: Cody put down in front of a table set up behind him, from the
## side: before, as he goes through it, and the pieces (table_0/1/2.png).
var _table := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--out":
				_out = args[i + 1]
			"--weapons":
				_ids = args[i + 1].split(",")
			"--walk":
				_walk = true
			"--close":
				_close = true
			"--bare":
				_bare = true
			"--swing":
				_swing = true
			"--front":
				_front = true
			"--table":
				_table = true
			"--fall":
				_fall = true
			"--pickup":
				_pickup = true
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 7)
	MatchRules.set_mode(scene, MatchRules.Mode.NO_HOLDS_BARRED)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var roman: WrestlerController = scene.get_node("WrestlerA")
	var cody: WrestlerController = scene.get_node("WrestlerB")
	var referee: MatchReferee = scene.get_node("MatchReferee")
	referee._tying_up = false
	for w: WrestlerController in [roman, cody]:
		w.is_ai = false
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
	roman.global_position = Vector3(0.0, 0.0, 0.5)
	# ahead of him so he faces down -Z, but well clear of the camera's line
	cody.global_position = Vector3(-1.2, 0.0, -2.6)
	for t in 20:
		await get_tree().physics_frame
	if _bare:
		var shot: Node = (load("res://tools/probe/paired_shot.gd") as GDScript).new()
		shot._strip(scene, roman, cody)
		shot.free()
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.78, 0.80, 0.83)
		sky_mat.sky_horizon_color = Color(0.70, 0.71, 0.73)
		sky_mat.ground_bottom_color = Color(0.30, 0.30, 0.31)
		var sky := Sky.new()
		sky.sky_material = sky_mat
		for node in scene.find_children("*", "WorldEnvironment", true, false):
			var env := (node as WorldEnvironment).environment
			env.sky = sky
			env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# The match's own cameras take "current" back every frame: stop them.
	for other in scene.find_children("*", "Camera3D", true, false):
		other.process_mode = Node.PROCESS_MODE_DISABLED
		(other as Camera3D).current = false
	cody.visible = false
	var cam := Camera3D.new()
	scene.add_child(cam)
	var body := roman.global_transform
	var focus := body.origin + Vector3.UP * 1.1
	cam.fov = 32.0 if _close else 40.0
	var back := 1.7 if _close else 2.6
	cam.global_position = focus + body.basis * Vector3(back * 0.75, 0.25, -back * 0.75)
	if _swing:
		focus = body.origin + body.basis * Vector3(0.0, 1.25, -0.45)
		cam.fov = 44.0
		cam.global_position = focus + body.basis * (Vector3(1.6, 0.3, -2.2) if _front else Vector3(3.4, 0.35, -0.6))
	cam.look_at(focus, Vector3.UP)
	print("CAM roman %s facing %s cam %s" % [body.origin.snappedf(0.01), (-body.basis.z).snappedf(0.01),
			cam.global_position.snappedf(0.01)])
	cam.current = true
	if _fall:
		await _shoot_fall(roman, cody, cam)
		get_tree().quit()
		return
	if _table:
		await _shoot_table(roman, cody, cam)
		get_tree().quit()
		return
	if _pickup:
		for id: String in _ids:
			await _shoot_pickup(roman, cam, id)
		get_tree().quit()
		return
	for id: String in _ids:
		var def := WeaponCatalog.by_id(StringName(id))
		var a := WeaponStock.of(roman).pull(def)
		roman.take_weapon(a)
		for t in 40:
			if _walk:
				roman.velocity = Vector3.ZERO
			await get_tree().physics_frame
		if _swing:
			await _shoot_swing(roman, a, id)
			roman.drop_weapon()
			a.queue_free()
			continue
		await RenderingServer.frame_post_draw
		var used := get_viewport().get_camera_3d()
		print("HEAD %s pelvis %s" % [roman._bone_world("Head").snappedf(0.01), roman._bone_world("pelvis").snappedf(0.01)])
		print("RENDER cam %s at %s" % [used.get_path() if used else "none", used.global_position.snappedf(0.01) if used else Vector3.ZERO])
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, id])
		print("HOLD %s at %s roman %s" % [id, a.global_position.snappedf(0.01), roman.global_position.snappedf(0.01)])
		var g := WeaponActor.grip_frame(roman)
		print("  grip x %s y %s z %s facing %s" % [g.basis.x.snappedf(0.01), g.basis.y.snappedf(0.01),
				g.basis.z.snappedf(0.01), (-roman.global_basis.z).snappedf(0.01)])
		for n: String in ["hand_r", "index_01_r", "middle_01_r", "pinky_01_r", "thumb_01_r", "lowerarm_r"]:
			print("  %s %s" % [n, (roman._bone_world(n) - roman.global_position).snappedf(0.01)])
		roman.drop_weapon()
		a.queue_free()
	get_tree().quit()


## The load, the contact and the follow-through of a swing of `a`.
func _shoot_swing(roman: WrestlerController, a: WeaponActor, id: String) -> void:
	var move := WeaponCatalog.swing_move(a.def)
	var total := move.total_frames()
	var at := [int(total * 0.22), move.startup_frames, int(total * 0.52)]
	if a.def.swing == WeaponDef.Swing.POUR:
		roman.begin_weapon_action("set_up")
		total = int(WrestlerController.WEAPON_ACTION_TICKS["set_up"])
		at = [8, 18, 28]
	else:
		roman._play_strike_clip(move)
		roman._start_move(WrestlerFSM.State.STRIKE, move)
		a.fire(move.startup_frames, roman)
	var tick := 0
	for k in at.size():
		# by his own clock: a slow frame lets several physics ticks through
		while tick < int(at[k]):
			await get_tree().physics_frame
			tick = total - roman._move_ticks_remaining if roman.fsm.current_state == WrestlerFSM.State.STRIKE \
					else roman._weapon_action_ticks if roman.fsm.current_state == WrestlerFSM.State.WEAPON_ACTION \
					else total
		get_tree().paused = true           # held still on this tick while it draws
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [_out, id, k])
		print("SWING %s %d tick %d/%d state %s path %d t %.2f grip %s chest %s" % [id, k, tick, total,
				roman.fsm.current_state, roman.weapon_grip._path.size(), roman.weapon_grip._t,
				a.global_marker("grip_r").origin.snappedf(0.01), roman._bone_world("spine_03").snappedf(0.01)])
		get_tree().paused = false
	while tick < total + 12:
		await get_tree().physics_frame
		tick += 1


## Roman's running attack into Cody with a table set up behind him, across
## the line -- the spot as the AI plays it (WrestlerAI._line_up_input): the
## run in, the impact, the wreck, and the wreck from above.
func _shoot_table(roman: WrestlerController, cody: WrestlerController, cam: Camera3D) -> void:
	cody.visible = true
	for n in roman.get_parent().find_children("*", "", true, false):
		if n is RefereeActor:
			(n as Node3D).visible = false
	roman.global_position = Vector3(0.0, 0.0, 1.0)
	cody.global_position = Vector3(0.0, 0.0, 0.0)
	roman.look_at(Vector3(0.0, 0.0, -5.0), Vector3.UP)
	cody.look_at(Vector3(0.0, 0.0, 5.0), Vector3.UP)
	var table := WeaponStock.of(cody).pull(WeaponCatalog.by_id(&"table"))
	table.set_up_at(Vector3(0.0, 0.0, 2.3), 0.0)
	cam.fov = 46.0
	cam.global_position = Vector3(4.0, 1.6, 1.4)
	cam.look_at(Vector3(0.0, 0.8, 1.2), Vector3.UP)
	for t in 10:
		await get_tree().physics_frame
	var broke := [false]
	cody.set_piece_landed.connect(func(_w, _a, b): broke[0] = b)
	var move := roman._pick_tier_move(roman.running_attack_move, roman.running_attack_move_pool)
	for m: MoveDef in [roman.grapple_move] + roman.grapple_move_pool:
		if m and String(m.animation_pair_id).contains("vertical_suplex"):
			move = m
	roman._begin_running_paired(move)
	print("TABLE move %s" % move.resource_path.get_file())
	for t in 50:
		await get_tree().physics_frame
	await _grab("table_0")
	var waited := 0
	while not broke[0] and waited < 240:
		await get_tree().physics_frame
		waited += 1
		if waited % 6 == 0:
			print("FALL t %d st %d hips %s were %.2f fell %s" % [waited + 50, cody.fsm.current_state,
					cody._bone_world("pelvis").snappedf(0.01), cody._hips_were, cody._fell_on])
	print("TABLE broke %s after %d ticks hips %s" % [broke[0], waited + 50, cody._bone_world("pelvis").snappedf(0.01)])
	await _grab("table_1")
	for t in 30:
		await get_tree().physics_frame
	await _grab("table_2")
	for t in 150:
		await get_tree().physics_frame
	# settled, from above and the other side
	cam.global_position = Vector3(-2.4, 2.8, 4.4)
	cam.look_at(Vector3(0.0, 0.2, 2.0), Vector3.UP)
	await _grab("table_3")


func _grab(name: String) -> void:
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	get_tree().paused = false


## A real knockdown: Cody one blow from going down, Roman's heavy kick.
func _shoot_fall(roman: WrestlerController, cody: WrestlerController, cam: Camera3D) -> void:
	cody.visible = true
	for n in roman.get_parent().find_children("*", "", true, false):
		if n is RefereeActor:
			(n as Node3D).visible = false
	roman.global_position = Vector3(0.0, 0.0, 1.1)
	cody.global_position = Vector3(0.0, 0.0, 0.0)
	roman.look_at(Vector3(0.0, 0.0, -5.0), Vector3.UP)
	cody.look_at(Vector3(0.0, 0.0, 5.0), Vector3.UP)
	cam.fov = 44.0
	cam.global_position = Vector3(2.9, 1.25, 0.9)
	cam.look_at(Vector3(0.0, 0.45, -0.1), Vector3.UP)
	for t in 20:
		await get_tree().physics_frame
	cody.combat.wear = cody._damage_at_last_knockdown + WrestlerController.KNOCKDOWN_DAMAGE - 1.0
	var move: MoveDef = load("res://resources/moves/strike_kick_heavy.tres")
	roman._play_strike_clip(move)
	roman._start_move(WrestlerFSM.State.STRIKE, move)
	var t0 := -1
	var k := 0
	var at := [0, 10, 16, 22, 30, 60]
	if OS.get_cmdline_user_args().has("--close"):
		at = [60]
	var tick := 0
	while k < at.size() and tick < 400:
		await get_tree().physics_frame
		tick += 1
		if t0 < 0 and (cody._bumping or cody.fsm.current_state == WrestlerFSM.State.DOWN):
			t0 = tick
		if t0 >= 0 and tick - t0 == int(at[k]):
			print("FALLF %d +%d state %d hips %s" % [k, at[k], cody.fsm.current_state, cody._bone_world("pelvis").snappedf(0.01)])
			for b: String in ["thigh_r", "calf_r", "foot_r", "thigh_l", "calf_l", "foot_l"]:
				print("   %s %s" % [b, cody._bone_world(b).snappedf(0.01)])
			await _grab("fall_%d" % k)
			k += 1
	for b: String in ["foot_r", "foot_l", "ball_r", "hand_r", "hand_l", "lowerarm_r", "lowerarm_l", "upperarm_r", "upperarm_l"]:
		print("BONE %s %s" % [b, cody._bone_world(b).snappedf(0.01)])


## `id` lying on the floor in front of him: he picks it up.
func _shoot_pickup(roman: WrestlerController, cam: Camera3D, id: String) -> void:
	var a := WeaponStock.of(roman).pull(WeaponCatalog.by_id(StringName(id)))
	var body := roman.global_transform
	# out of his way: the steps dropped at 0.55 m lay over his feet
	var ahead := 1.1 if WeaponCatalog.pickup_action(a.def) == "pickup_heavy" else 0.55
	a.global_position = body.origin - body.basis.z * ahead + body.basis.x * 0.12 + Vector3.UP * 0.3
	a.drop()
	for t in 60:
		await get_tree().physics_frame
	var focus := body.origin + body.basis * Vector3(0.0, 0.7, -0.3)
	cam.fov = 46.0
	cam.global_position = focus + body.basis * Vector3(2.4, 0.4, -1.4)
	cam.look_at(focus, Vector3.UP)
	roman._weapon_target = a
	var action := WeaponCatalog.pickup_action(a.def)
	roman.begin_weapon_action(action)
	var total := int(WrestlerController.WEAPON_ACTION_TICKS[action])
	var at := [4, int(WrestlerController.WEAPON_ACTION_AT[action]) - 4,
			int(WrestlerController.WEAPON_ACTION_AT[action]), total - 4]
	var tick := 0
	for k in at.size():
		while roman._weapon_action_ticks < int(at[k]) and tick < 200:
			await get_tree().physics_frame
			tick += 1
		await _grab("%s_p%d" % [id, k])
	for t in 20:
		await get_tree().physics_frame
	roman.drop_weapon()
	a.queue_free()
	for t in 10:
		await get_tree().physics_frame
