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


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _save(file: String) -> void:
	for _i in 2:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file))
	print("saved ", file)
