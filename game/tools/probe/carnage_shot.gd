extends Node
## The carnage spots (the owner, 19 Oct), frame by frame, for review:
##
##   --spot table   Roman lights a table standing in the ring, and Cody goes
##                  down through it and catches fire
##   --spot glass   a pane of glass set up in the ring, Cody down through it,
##                  the shards, and the blood
##   --spot bridge  a ladder across from the apron to the barricade, and Cody
##                  down through it as it folds
##   --spot wall    Cody whipped across the stage into the left LED wall: the
##                  smash, the sparks, the wall dead
##   --spot breath  Roman with the fire torch spits a fireball over it, and
##                  Cody goes up
##   --spot desk    out on the floor in front of the announce desk, Roman
##                  powerbombs Cody through it: the lift, the crash, the wreck
##   --spot desk_suplex  the same, by the vertical suplex, Roman's back to it
##   --spot ladder  a ladder stood up mid-ring, Cody down beyond it: Roman
##                  climbs to the top and dives onto him (ladder_aerial)
##   --spot table_dive  a table up in the ring: Cody lays Roman out on it
##                  (table_lay), climbs the corner and moonsaults onto him
##                  through it (TopRopeSpot, the table)
##
##   xvfb-run -a godot --path game --rendering-driver vulkan --resolution 1280x720 \
##       --fixed-fps 30 tools/probe/carnage_shot.tscn -- --spot table --out /tmp/carnage

var _out := "/tmp/carnage"
var _spot := "table"
var _scene: Node
var _a: WrestlerController
var _b: WrestlerController
var _cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--out": _out = args[i + 1]
			"--spot": _spot = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	_scene = load("res://scenes/match.tscn").instantiate()
	_scene.entrances = false
	TitleScreen.configure_match(_scene, Roster.by_id("roman"), Roster.by_id("cody"), 3, false,
			MatchRules.Mode.NO_HOLDS_BARRED)
	get_tree().root.add_child.call_deferred(_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	_a = _scene.get_node("WrestlerA")
	_b = _scene.get_node("WrestlerB")
	for w: WrestlerController in [_a, _b]:
		w.is_ai = false
		if w.ai:
			w.ai.set_physics_process(false)
	var hud := _scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	_cam = Camera3D.new()
	_scene.add_child(_cam)
	_cam.make_current()
	_cam.fov = 46.0
	match _spot:
		"table":
			await _table()
		"glass":
			await _glass()
		"bridge":
			await _bridge()
		"wall":
			await _wall()
		"breath":
			await _breath()
		"desk":
			await _desk("res://resources/moves/ff/powerbomb_1.tres", true)
		"desk_suplex":
			await _desk("res://resources/moves/grapple_vertical_suplex.tres", false)
		"ladder":
			await _ladder()
		"table_dive":
			await _table_dive()
	print("CARNAGE SHOT DONE ", _spot)
	get_tree().quit()


func _table() -> void:
	var stock := WeaponStock.of(_a)
	var table := stock.pull(WeaponCatalog.by_id(&"table"))
	table.set_up_at(Vector3(0.4, 0.0, 0.0), 0.0)
	_a.global_position = Vector3(0.4, 0.0, 1.25)
	_a.rotation.y = 0.0
	_b.global_position = Vector3(-2.4, 0.0, -2.0)
	_cam.global_position = Vector3(3.6, 2.5, 3.6)
	_cam.look_at(Vector3(0.3, 0.9, 0.0))
	await _frames(20)
	_a.begin_light(table)
	await _frames(WrestlerController.WEAPON_ACTION_AT["light"] - 6)
	await _save("table_0_lighter.png")
	await _frames(40)
	await _save("table_1_ablaze.png")
	_a.global_position = Vector3(-1.4, 0.0, 1.9)
	_b.global_position = Vector3(0.4, 0.0, -0.5)
	_b.rotation.y = 0.0
	_b._go_down()
	await _frames(16)
	await _save("table_2_through.png")
	await _frames(45)
	await _save("table_3_on_fire.png")


func _glass() -> void:
	var stock := WeaponStock.of(_a)
	var pane := stock.pull(WeaponCatalog.by_id(&"glass_pane"))
	pane.set_up_at(Vector3(0.4, 0.0, 0.0), 0.0)
	_a.global_position = Vector3(-1.4, 0.0, 1.9)
	_b.global_position = Vector3(-2.2, 0.0, -1.6)
	_cam.global_position = Vector3(3.6, 2.5, 3.6)
	_cam.look_at(Vector3(0.3, 0.9, 0.0))
	await _frames(20)
	await _save("glass_0_set_up.png")
	# on it, as the tests put him: he goes down where he stands
	_b.global_position = Vector3(0.4, 0.0, 0.0)
	_b.rotation.y = PI * 0.5
	_b._go_down()
	await _frames(14)
	await _save("glass_1_through.png")
	await _frames(40)
	await _save("glass_2_shards.png")
	await _frames(20)
	var blood := _b.get_node_or_null("Blood") as Blood
	print("GLASS BLOOD head %.2f back %.2f" % [blood.head, blood.back] if blood else "GLASS BLOOD none")
	var head := _b._bone_world("Head")
	if head == Vector3.INF:
		head = _b.global_position + Vector3.UP * 0.3
	# from in front of him, a little above: his face and chest
	var front := -_b.global_basis.z
	front.y = 0.0
	front = front.normalized()
	_cam.global_position = head + front * 1.1 + Vector3.UP * 0.35
	_cam.look_at(head + Vector3.DOWN * 0.25)
	_cam.fov = 40.0
	await _save("glass_3_blood.png")


func _bridge() -> void:
	var stock := WeaponStock.of(_a)
	var ladder := stock.pull(WeaponCatalog.by_id(&"ladder"))
	_b.global_position = Vector3(4.6, WrestlerController.FLOOR_LEVEL, 0.4)
	_b.outside_ring = true
	var span := _b.bridge_span()
	ladder.set_bridge(span[0], span[1])
	_b.global_position = Vector3(4.6, WrestlerController.FLOOR_LEVEL, 2.4)
	_a.global_position = Vector3(4.4, WrestlerController.FLOOR_LEVEL, -1.6)
	_a.outside_ring = true
	_cam.global_position = Vector3(8.6, 1.4, 4.2)
	_cam.look_at(Vector3(4.4, -0.5, 0.2))
	_cam.fov = 52.0
	await _frames(20)
	await _save("bridge_0_across.png")
	_b.global_position = Vector3(4.6, WrestlerController.FLOOR_LEVEL, 0.4)
	_b.rotation.y = 0.0
	_b._go_down()
	await _frames(14)
	await _save("bridge_1_through.png")
	await _frames(30)
	await _save("bridge_2_folded.png")
	_cam.global_position = Vector3(4.6, 0.9, 3.4)
	_cam.look_at(Vector3(4.6, -0.8, 0.4))
	await _save("bridge_3_close.png")


func _wall() -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var x := -(ArenaBuilder.SIDE_SCREEN_INNER_X + 0.9)
	var z := ArenaBuilder.MATCH_STAGE_BACK_LIMIT
	for w: WrestlerController in [_a, _b]:
		w.outside_ring = true
	_b.global_position = Vector3(x, deck, z + 1.6)
	_b.rotation.y = 0.0
	_a.global_position = Vector3(x + 0.3, deck, z + 3.0)
	_a.rotation.y = 0.0
	_cam.global_position = Vector3(x + 3.2, deck + 2.0, z + 6.5)
	_cam.look_at(Vector3(x - 0.6, deck + 1.4, z - 0.4))
	_cam.fov = 55.0
	await _frames(20)
	await _save("wall_0_before.png")
	_b.global_position = Vector3(x, deck, z + 0.05)
	_b.velocity = Vector3(0.0, 0.0, -WrestlerController.IRISH_WHIP_LAUNCH_SPEED)
	_b._whipped_into_screen()
	await _frames(4)
	await _save("wall_1_smash.png")
	await _frames(26)
	await _save("wall_2_sparks.png")
	await _frames(70)
	await _save("wall_3_dead.png")


## Where WrestlerAI lines it up: the powerbomb from POWERBOMB_DROP out facing
## the desk, Cody between; the suplex from SUPLEX_DROP out with his back to it.
func _desk(move_path: String, bomb: bool) -> void:
	var y := WrestlerController.FLOOR_LEVEL
	var landing := Vector3(ArenaBuilder.DESK_X, y, ArenaBuilder.DESK_Z)
	for w: WrestlerController in [_a, _b]:
		w.outside_ring = true
	var drop := WrestlerAI.POWERBOMB_DROP if bomb else WrestlerAI.SUPLEX_DROP
	_a.global_position = landing - Vector3(0.0, 0.0, drop)
	_b.global_position = _a.global_position + Vector3(0.0, 0.0, 0.9 if bomb else -0.9)
	_a.look_at(_b.global_position, Vector3.UP)
	_b.look_at(_a.global_position, Vector3.UP)
	# from the ring side, off the far end of the desk and above head height
	# (from the near end a seated figure at ringside fills the corner); the
	# bay is dim under the arena's light, so a fill from the camera (the
	# probe's only)
	_cam.global_position = Vector3(-3.2, y + 2.2, 4.4)
	_cam.look_at(Vector3(0.0, y + 0.8, 7.0))
	_cam.fov = 55.0
	var fill := DirectionalLight3D.new()
	_scene.add_child(fill)
	fill.light_energy = 1.6
	fill.global_transform = _cam.global_transform
	# Drawn only for the frames saved (paired_shot.gd): under a software
	# rasteriser the whole arena drawn every tick took ten minutes a frame.
	Engine.max_physics_steps_per_frame = 1
	RenderingServer.render_loop_enabled = false
	await _frames(20)
	# the whole bay from the ring first: the desk, the commentators at it,
	# and the timekeeper's table off its +X end
	var close := _cam.global_transform
	_cam.global_position = Vector3(0.6, y + 2.0, 3.4)
	_cam.look_at(Vector3(0.9, y + 0.8, 7.9))
	_cam.fov = 62.0
	fill.global_transform = _cam.global_transform
	await _save("desk_00_bay.png")
	_cam.global_transform = close
	_cam.fov = 55.0
	fill.global_transform = _cam.global_transform
	await _save("desk_0_lined_up.png")
	var rig: GrappleRig = _scene.get_node("GrappleRig")
	_a._is_grapple_attacker = true
	_b._is_grapple_attacker = false
	_a.opponent = _b
	_b.opponent = _a
	_a.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	_b.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	var move := load(move_path) as MoveDef
	# the move's end handed to his controller, as a match does
	# (begin_ladder_aerial): without it the two are left locked up, and a
	# beat later he throws a second one
	_a._active_move = move
	rig.begin(_a, _b, move)
	rig.grapple_finished.connect(_a._on_grapple_finished, CONNECT_ONE_SHOT)
	var stock := WeaponStock.of(_a)
	var shots := [0.35, 0.55, 0.65, 0.75, 1.0, 1.6]
	var total := int(move.total_frames()) + int(rig.get("lead_in_ticks"))
	var taken := 0
	for t in int(total * 1.7):
		await _frames(1)
		var frac := float(t) / float(total)
		if taken < shots.size() and frac >= shots[taken]:
			await _save("desk_%d_%02d.png" % [taken + 1, int(shots[taken] * 100)])
			taken += 1
	print("DESK through: %s" % stock.desk_broken)
	# the wreck, close
	_cam.global_position = Vector3(-1.6, y + 1.8, 5.2)
	_cam.look_at(Vector3(0.0, y + 0.4, 7.4))
	fill.global_transform = _cam.global_transform
	await _save("desk_9_wreck.png")
	# and the whole of it, end to end, from the ring
	_cam.global_position = Vector3(0.6, y + 2.0, 3.4)
	_cam.look_at(Vector3(0.9, y + 0.5, 7.9))
	_cam.fov = 62.0
	fill.global_transform = _cam.global_transform
	await _save("desk_99_wreck_wide.png")


func _ladder() -> void:
	var ladder := WeaponStock.of(_a).pull(WeaponCatalog.by_id(&"ladder"))
	ladder.set_up_at(Vector3.ZERO, 0.0, "Ladder_Open")
	# the climber mounts on the ladder's -Z side and dives out over it: Cody
	# down on the far side, in reach
	_b.global_position = Vector3(0.0, 0.0, 1.4)
	_b.rotation.y = PI * 0.5
	_a.global_position = Vector3(0.0, 0.0, -WrestlerController.LADDER_FRONT_OFFSET)
	_a.opponent = _b
	_b.opponent = _a
	_cam.global_position = Vector3(4.2, 2.4, 1.0)
	_cam.look_at(Vector3(0.0, 1.4, 0.5))
	_cam.fov = 55.0
	Engine.max_physics_steps_per_frame = 1
	RenderingServer.render_loop_enabled = false
	await _frames(10)
	_b._go_down()
	await _frames(2)
	_b._move_ticks_remaining = 100000          # he stays down for the dive
	if not _a.begin_ladder_climb(ladder):
		print("LADDER: could not mount")
		return
	await _save("ladder_0_mount.png")
	var shot := 1
	for t in 600:
		if _a.fsm.current_state != WrestlerFSM.State.LADDER_CLIMB:
			break
		if _a.can_start_ladder_aerial():
			break
		_a._tick_ladder_climb({"move": Vector2(0.0, -1.0)})
		await _frames(1)
		if t % 40 == 20:
			await _save("ladder_%d_climb.png" % shot)
			shot += 1
	print("LADDER at the top: %.2f, aerial ok %s" % [_a.ladder_climb_progress(), _a.can_start_ladder_aerial()])
	_a._tick_ladder_climb({"grapple": true})
	var rig: GrappleRig = _scene.get_node("GrappleRig")
	var total := int(GrappleRig.LEAD_IN_TICKS) + int(WrestlerController.LADDER_AERIAL_MOVE.total_frames())
	for t in int(total * 1.5):
		await _frames(1)
		if t % 8 == 0:
			await _save("ladder_%d_dive.png" % shot)
			shot += 1
	print("LADDER dive done, rig active %s" % rig.is_active())


## Cody (B) lays Roman (A) on a table a step off the middle toward the (1, 1)
## corner, its length along x, then the spot takes him up that corner and
## off it through the table. Shot side-on to the line from the corner to the
## table.
func _table_dive() -> void:
	var at := Vector3(0.6, 0.0, 0.9)
	var table := WeaponStock.of(_a).pull(WeaponCatalog.by_id(&"table"))
	table.set_up_at(at, 0.0)
	var cody := _b
	var roman := _a
	cody.global_position = at + Vector3(0.4, 0.0, 0.7)
	roman.global_position = at + Vector3(-0.4, 0.0, 0.7)
	cody.look_at(roman.global_position, Vector3.UP)
	roman.look_at(cody.global_position, Vector3.UP)
	cody.opponent = roman
	roman.opponent = cody
	# High over the ropes, side-on to the line from the corner to the table;
	# the ring's lights are not up this early, so a fill from the camera (as
	# the desk's)
	_cam.global_position = Vector3(3.8, 3.2, -0.8)
	_cam.look_at(Vector3(1.5, 1.0, 1.5))
	_cam.fov = 58.0
	var fill := DirectionalLight3D.new()
	_scene.add_child(fill)
	fill.light_energy = 1.4
	fill.global_transform = _cam.global_transform
	Engine.max_physics_steps_per_frame = 1
	RenderingServer.render_loop_enabled = false
	await _frames(10)
	await _save("dive_0_lined_up.png")
	var rig: GrappleRig = _scene.get_node("GrappleRig")
	cody._is_grapple_attacker = true
	roman._is_grapple_attacker = false
	cody.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	roman.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	var lay := load("res://resources/moves/table_lay.tres") as MoveDef
	cody._active_move = lay
	rig.begin(cody, roman, lay)
	rig.grapple_finished.connect(cody._on_grapple_finished, CONNECT_ONE_SHOT)
	var total := GrappleRig.LEAD_IN_TICKS + int(lay.total_frames())
	var lay_shots := [0.45, 0.72, 0.9]
	var taken := 0
	var spot: TopRopeSpot = null
	for t in total + 20:
		await _frames(1)
		spot = _scene.get_node_or_null("TopRopeSpot") as TopRopeSpot
		if spot:
			break
		var frac := float(t) / float(total)
		if taken < lay_shots.size() and frac >= lay_shots[taken]:
			await _save("dive_%d_lay_%02d.png" % [taken + 1, int(lay_shots[taken] * 100)])
			taken += 1
	if spot == null:
		print("TABLE DIVE: no spot")
		return
	_cam.make_current()
	await _save("dive_4_on_the_table.png")
	# The spot from here: on the top rope, the flight, the contact, through.
	var wants := {"top": false, 30: false, 46: false, 52: false, 60: false}
	var n := 5
	var done := [false]
	spot.finished.connect(func() -> void: done[0] = true)
	for t in 900:
		await _frames(1)
		if done[0]:
			break
		_cam.make_current()
		if spot._seg == spot._dive_seg - 1 and spot._tick == 100 and not wants["top"]:
			wants["top"] = true
			await _save("dive_%d_top_rope.png" % n)
			n += 1
		if spot._seg == spot._dive_seg and wants.has(spot._tick) and not wants[spot._tick]:
			wants[spot._tick] = true
			await _save("dive_%d_moonsault_%d.png" % [n, spot._tick])
			n += 1
	await _frames(20)
	print("TABLE DIVE through: %s, roman y %.2f, state %d" % [table.mode != WeaponActor.Mode.SET_UP,
			roman.global_position.y, roman.fsm.current_state])
	_cam.make_current()
	_cam.global_position = Vector3(2.8, 1.6, -0.6)
	_cam.look_at(Vector3(0.6, 0.3, 0.9))
	fill.global_transform = _cam.global_transform
	await _save("dive_%d_wreck.png" % n)


func _breath() -> void:
	_a.global_position = Vector3(-0.8, 0.0, 0.0)
	_b.global_position = Vector3(0.7, 0.0, 0.0)
	_a.look_at(_b.global_position, Vector3.UP)
	_b.look_at(_a.global_position, Vector3.UP)
	var torch := WeaponStock.of(_a).pull(WeaponCatalog.by_id(&"fire_torch"))
	_a.take_weapon(torch)
	_cam.global_position = Vector3(0.2, 1.9, 3.6)
	_cam.look_at(Vector3(0.0, 1.35, 0.0))
	_cam.fov = 48.0
	await _frames(20)
	await _save("breath_0_torch.png")
	var swing := WeaponCatalog.swing_move(torch.def)
	_a.play_presentation_clip("strikes/weapon_spray", false)
	torch.fire(1, _a)
	await _frames(6)
	await _save("breath_1_fireball.png")
	await _frames(6)
	_a._apply_move_to_opponent(swing)
	await _save("breath_2_reaches.png")
	await _frames(40)
	await _save("breath_3_alight.png")


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _save(file: String) -> void:
	var was := RenderingServer.render_loop_enabled
	RenderingServer.render_loop_enabled = true
	for _i in 2:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file))
	RenderingServer.render_loop_enabled = was
	print("saved ", file)
