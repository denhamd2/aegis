extends Node
## The carnage spots (the owner, 19 Oct), frame by frame, for review:
##
##   --spot table   Roman lights a table standing in the ring, and Cody goes
##                  down through it and catches fire
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


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _save(file: String) -> void:
	for _i in 2:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file))
	print("saved ", file)
