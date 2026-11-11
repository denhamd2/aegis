extends Node
## Renders the gimmick matches' structures and finishes for review, ring only
## (the arena bowl takes minutes a frame in software GL):
##
##   xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 1280x720 \
##       tools/probe/gimmick_shot.tscn -- --out /tmp/gimmick [--only cell,ladder]
##
## cell    Hell in a Cell from outside and from the mat
## ladder  the Ladder match: a man up the ladder under the belt, tugging it
##         down, and holding it

var _out := "/tmp/gimmick"
var _only: Array[String] = []
var _arena := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--out": _out = args[i + 1]
			"--arena": _arena = true
			"--only":
				for s: String in args[i + 1].split(","):
					_only.append(s)
	DirAccess.make_dir_recursive_absolute(_out)
	Engine.max_physics_steps_per_frame = 1
	await get_tree().process_frame
	for s: String in ["cell", "cage", "ladder", "casket", "ambulance", "roof", "cellcam", "lowering"]:
		if _only.is_empty() or _only.has(s):
			await call("_" + s)
	print("GIMMICK_SHOT done")
	get_tree().quit()


func _scene(mode: int, keep_arena := false, keep_camera := false) -> Node:
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 7, false, mode)
	var heavy_parts := ["RingReflections", "MatchHUD"]
	if not keep_camera:
		heavy_parts.append("MatchCamera")
	if not keep_arena:
		heavy_parts.append("Arena")
	for heavy in heavy_parts:
		if scene.has_node(heavy):
			scene.get_node(heavy).free()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.5
	scene.add_child(sun)
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	(scene.get_node("MatchReferee") as MatchReferee)._tying_up = false
	for w in ["WrestlerA", "WrestlerB"]:
		var c := scene.get_node(w) as WrestlerController
		c.is_ai = false
		c.fsm.transition_to(WrestlerFSM.State.IDLE)
	return scene


func _cam(scene: Node, at: Vector3, look: Vector3, fov := 55.0) -> Camera3D:
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = fov
	camera.global_position = at
	camera.look_at(look, Vector3.UP)
	camera.current = true
	return camera


func _shoot(name: String) -> void:
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [_out, name], 0.88)
	print("shot ", name)


func _done(scene: Node) -> void:
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _cage() -> void:
	var scene: Node = await _scene(MatchRules.Mode.STEEL_CAGE, _arena)
	_cam(scene, Vector3(-8.5, 3.2, 6.5), Vector3(0, 1.6, 0), 50.0)
	await _shoot("cage_wide")
	await _done(scene)


func _cell() -> void:
	var scene: Node = await _scene(MatchRules.Mode.HELL_IN_A_CELL, _arena)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	roman.global_position = Vector3(-0.8, 0, 0.3)
	cody.global_position = Vector3(0.8, 0, -0.3)
	await get_tree().physics_frame
	_cam(scene, Vector3(-11.5, 4.5, 8.5), Vector3(0, 1.4, 0), 50.0)
	await _shoot("cell_wide")
	_cam(scene, Vector3(-4.6, 0.2, 4.4), Vector3(0, 2.6, 0), 70.0)
	await _shoot("cell_floor")
	await _done(scene)


func _ladder() -> void:
	var scene: Node = await _scene(MatchRules.Mode.LADDER)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	cody.global_position = Vector3(1.6, 0, 1.6)
	cody.set_physics_process(false)
	var stock := WeaponStock.of(roman)
	var ladder := stock.pull(WeaponCatalog.by_id(&"ladder"))
	var yaw := PI * 0.5
	ladder.set_up_at(WrestlerController.ladder_under_prize(Vector3.ZERO, yaw), yaw, "Ladder_Open")
	await get_tree().physics_frame
	roman.global_position = ladder.global_transform * Vector3(0, 0, -WrestlerController.LADDER_FRONT_OFFSET)
	roman.begin_ladder_climb(ladder)
	roman.set_physics_process(false)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.5, 4.2, 2.0)
	fill.light_energy = 4.0
	fill.omni_range = 7.0
	scene.add_child(fill)
	_cam(scene, Vector3(-1.2, 3.0, 5.2), Vector3(0, 3.4, 0), 55.0)
	await _shoot("ladder_belt")
	_cam(scene, Vector3(-1.6, 4.4, 2.4), Vector3(0, 4.5, 0), 40.0)
	await _shoot("ladder_belt_close")
	_cam(scene, Vector3(-1.2, 3.0, 5.2), Vector3(0, 3.4, 0), 55.0)
	var prize := HangingPrize.of(roman)
	RenderingServer.render_loop_enabled = false
	var shots := {90: "ladder_climb", 200: "ladder_reach", 260: "ladder_tug"}
	for tick in range(1, 400):
		roman._tick_ladder_climb({"move": Vector2(0.0, -1.0)})
		await get_tree().physics_frame
		if shots.has(tick):
			await _shoot(shots[tick])
			RenderingServer.render_loop_enabled = false
		if prize.won_by:
			for i in 20:
				await get_tree().physics_frame
			await _shoot("ladder_won")
			break
	_cam(scene, Vector3(-3.5, 1.6, 3.0), Vector3(0, 3.6, 0), 60.0)
	await _shoot("ladder_won_low")
	await _done(scene)


func _shut_in(mode: int, name: String, cam_at: Vector3, look_at_y := 0.0) -> void:
	var scene: Node = await _scene(mode, name == "ambulance" or _arena)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	var shut := scene.get_node("ShutIn") as ShutIn
	var m: Vector3 = shut.container.mouth()
	for w in [roman, cody]:
		w.outside_ring = true
	cody.global_position = m + Vector3(0.3, 0.0, 0.0) if name == "casket" else m + Vector3(0, 0, 0.3)
	roman.global_position = m + (Vector3(1.6, 0.0, 0.2) if name == "casket" else Vector3(0.2, 0, 1.6))
	await get_tree().physics_frame
	var look: Vector3 = shut.container.lip()
	_cam(scene, cam_at, look + Vector3(0, look_at_y, 0), 50.0)
	await _shoot(name + "_open")
	RenderingServer.render_loop_enabled = false
	cody._irish_whip_target = roman
	cody._irish_whip_rebounded = false
	cody._irish_whip_shut_in = true
	cody.velocity = (m - cody.global_position).normalized() * 2.0
	cody._irish_whip_launch_velocity = cody.velocity
	cody.fsm.transition_to(WrestlerFSM.State.IRISH_WHIP)
	await get_tree().physics_frame
	await get_tree().physics_frame
	shut._holds = true
	var shots := {12: "_tumble", 30: "_in", 70: "_closing", 140: "_shut"}
	for tick in range(1, 150):
		await get_tree().physics_frame
		if shots.has(tick):
			await _shoot(name + shots[tick])
			RenderingServer.render_loop_enabled = false
	await _done(scene)


func _casket() -> void:
	await _shut_in(MatchRules.Mode.CASKET, "casket", Vector3(-1.4, 1.6, 4.6))


func _ambulance() -> void:
	await _shut_in(MatchRules.Mode.AMBULANCE, "ambulance", Vector3(3.2, 1.8, -3.0))


func _roof() -> void:
	var scene: Node = await _scene(MatchRules.Mode.HELL_IN_A_CELL, true)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	var roof := scene.get_node("CellRoof") as CellRoof
	(scene.get_node("MatchReferee") as MatchReferee).set_physics_process(false)
	for w in [roman, cody]:
		w.outside_ring = true
		w.on_roof = true
	var h := roof.half()
	roman.global_position = Vector3(-(h - 0.55), roof.surface_y(), 0.4)
	cody.global_position = Vector3(-(h - 1.6), roof.surface_y(), 0.4)
	roman.face(Vector3(1, 0, 0))
	cody.face(Vector3(-1, 0, 0))
	# A table stood up on the floor below that side.
	var table := WeaponStock.of(roman).pull(WeaponCatalog.by_id(&"table"))
	table.set_up_at(Vector3(-(h + 0.5), ArenaBuilder.FLOOR_Y, 0.4), PI * 0.5, "Table_Up")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_cam(scene, Vector3(-11.0, 7.4, 7.5), Vector3(-2.0, 4.6, 0.0), 50.0)
	await _shoot("roof_fight")
	_cam(scene, Vector3(-9.5, 2.2, 6.5), Vector3(-5.0, 2.0, 0.4), 55.0)
	RenderingServer.render_loop_enabled = false
	roman.combat.limb_damage["torso"] = CombatSystem.KICKOUT_DAMAGE_REFERENCE * 0.8
	roman.fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	roman._go_down(CombatSystem.Tier.POWER)
	var shots := {6: "roof_over", 22: "roof_falling", 34: "roof_table", 70: "roof_landed"}
	for tick in range(1, 72):
		await get_tree().physics_frame
		if shots.has(tick):
			await _shoot(shots[tick])
			RenderingServer.render_loop_enabled = false
	# Cody on a centre panel, slammed through it.
	var c := roof.cage.bay_centre(1, 1)
	cody.global_position = Vector3(c.x + 0.3, roof.surface_y(), c.z + 0.3)
	await get_tree().physics_frame
	for i in 3:
		roof.landed(cody, CombatSystem.Tier.POWER)
	_cam(scene, Vector3(-6.5, 7.8, 5.0), Vector3(0.0, 4.0, 0.0), 55.0)
	await _shoot("roof_dented")
	RenderingServer.render_loop_enabled = false
	cody.fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	cody._go_down(CombatSystem.Tier.POWER)
	_cam(scene, Vector3(-6.0, 3.2, 4.6), Vector3(0.0, 2.2, 0.0), 62.0)
	var shots2 := {8: "panel_gone", 26: "panel_falling", 60: "panel_landed"}
	for tick in range(1, 62):
		await get_tree().physics_frame
		if shots2.has(tick):
			await _shoot(shots2[tick])
			RenderingServer.render_loop_enabled = false
	await _done(scene)


## The match camera in Hell in a Cell: as it was (outside the walls, looking
## through them) and as it is (in with them), the pair in the ring, then out
## in the lane round the cell.
func _cellcam() -> void:
	var scene: Node = await _scene(MatchRules.Mode.HELL_IN_A_CELL, _arena, true)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	var cam := scene.get_node("MatchCamera") as MatchCamera
	var roof := scene.get_node("CellRoof") as CellRoof
	for w in [roman, cody]:
		w.set_physics_process(false)
	var spots := {"centre": [Vector3(-0.7, 0, 0.6), Vector3(0.7, 0, -0.2)],
			"corner": [Vector3(-2.3, 0, 2.2), Vector3(-1.2, 0, 2.6)]}
	for name: String in spots:
		roman.global_position = spots[name][0]
		cody.global_position = spots[name][1]
		roman.face(cody.global_position - roman.global_position)
		cody.face(roman.global_position - cody.global_position)
		for pass_i in 2:
			cam._cell_looked = pass_i == 0
			cam._cell = null
			cam._snap_next = true
			for i in 30:
				await get_tree().physics_frame
			await _shoot("cellcam_%s_%s" % [name, "before" if pass_i == 0 else "after"])
			RenderingServer.render_loop_enabled = false
	# Out round the cell, on its -X side.
	var h := roof.half()
	for w in [roman, cody]:
		w.outside_ring = true
		roof.set_outside_cell(w, true)
	roman.global_position = Vector3(-(h + 0.6), WrestlerController.FLOOR_LEVEL, 0.6)
	cody.global_position = Vector3(-(h + 0.6), WrestlerController.FLOOR_LEVEL, -0.6)
	cam._cell_looked = false
	cam._snap_next = true
	for i in 30:
		await get_tree().physics_frame
	await _shoot("cellcam_outside_after")
	await _done(scene)


## The cell coming down after the entrances, on the lowering's own shot.
func _lowering() -> void:
	var scene: Node = await _scene(MatchRules.Mode.HELL_IN_A_CELL, true)
	var cage := CageBuilder.of(scene)
	var director := EntranceDirector.new()
	cage.set_lift(CageBuilder.HOIST_LIFT)
	var pyro := EntrancePyro.new()
	scene.add_child(pyro)
	var camera := _cam(scene, Vector3.ZERO, Vector3(0, 0, -1), EntranceDirector.CELL_LOWER_FOV)
	cage.lower(EntranceDirector.CELL_LOWER_SECONDS)
	var total := int(EntranceDirector.CELL_LOWER_SECONDS * 60)
	var shots := {2: "lowering_hung", total / 2: "lowering_half", total - 40: "lowering_near",
			total + 6: "lowering_landed"}
	RenderingServer.render_loop_enabled = false
	for t in range(1, total + 8):
		var sh := director.cell_lower_shot(cage, float(t) / float(total + 84))
		camera.global_position = sh[0]
		camera.look_at(sh[1], Vector3.UP)
		if t % 33 == 0:
			pyro.cell_strobe(cage.global_position.y + cage.spec.top_y)
		if t == total + 1:
			pyro.cell_landed()
		await get_tree().physics_frame
		if shots.has(t):
			await _shoot(shots[t])
			RenderingServer.render_loop_enabled = false
	director.free()
	await _done(scene)
