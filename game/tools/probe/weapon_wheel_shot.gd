extends Node
## The weapon wheel on screen: Roman outside by the apron, reaching under,
## the stick pushed out over a family. One frame, broadcast camera, HUD on.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/weapon_wheel_shot.tscn -- --out /tmp/wheel

var _out := "/tmp/wheel"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			_out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 7)
	MatchRules.set_mode(scene, MatchRules.Mode.NO_HOLDS_BARRED)
	var a: WrestlerController = scene.get_node("WrestlerA")
	a.is_ai = false
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var roman: WrestlerController = scene.get_node("WrestlerA")
	var cody: WrestlerController = scene.get_node("WrestlerB")
	(scene.get_node("MatchReferee") as MatchReferee)._tying_up = false
	cody.is_ai = false
	for w: WrestlerController in [roman, cody]:
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
	roman.outside_ring = true
	roman.is_ai = false
	roman.global_position = Vector3(-(WrestlerController.DECK_KEEP_OUT + 0.1), WrestlerController.FLOOR_LEVEL, 0.6)
	if scene.find_child("WeaponWheel", true, false) == null:
		var layer := CanvasLayer.new()
		layer.layer = 15
		var wheel := WeaponWheel.new()
		wheel.name = "WeaponWheel"
		wheel.wrestler = roman
		layer.add_child(wheel)
		scene.add_child(layer)
	cody.global_position = Vector3(-1.5, 0.0, -1.0)
	await get_tree().physics_frame
	Input.action_press("weapon")
	Input.action_press("move_right", 0.82)
	Input.action_press("move_up", 0.47)
	for t in 50:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + "/wheel.png")
	print("WHEEL rummaging %s" % roman.is_rummaging())
	get_tree().quit()
