extends Node
## A man down on his back, close on his feet (the owner, 1 Nov: "Cody's feet
## look warped here", Down_Supine on the flaming-table sheet): from beside him
## at mat level, from above, and from his feet looking up his legs -- Cody,
## then Roman and Kenny the same, so a boot fault is told from a pose fault.
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 --resolution 1280x720 \
##       --fixed-fps 30 tools/probe/down_feet_shot.tscn -- --who cody --out /tmp/feet
##
## A wrapper scene, as drop_probe.gd is, so the class_name globals and
## autoloads are there. Drawn only for the frames saved (carnage_shot.gd).

var _out := "/tmp/feet"
var _who := "cody"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--out": _out = args[i + 1]
			"--who": _who = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	var other := "roman" if _who != "roman" else "cody"
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	scene.entrances = false
	TitleScreen.configure_match(scene, Roster.by_id(other), Roster.by_id(_who), 3)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var standing: WrestlerController = scene.get_node("WrestlerA")
	var down: WrestlerController = scene.get_node("WrestlerB")
	for w: WrestlerController in [standing, down]:
		w.is_ai = false
		if w.ai:
			w.ai.set_physics_process(false)
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	standing.global_position = Vector3(-2.4, 0.0, -2.4)
	down.global_position = Vector3(0.6, 0.0, 0.0)
	down.rotation.y = 0.0
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	Engine.max_physics_steps_per_frame = 1
	RenderingServer.render_loop_enabled = false
	await _ticks(4)
	down._go_down()
	await _ticks(2)
	down._move_ticks_remaining = 100000          # he stays down
	await _ticks(90)
	# His feet, where Down_Supine lays them: his body runs toward his facing
	# (-Z) from the hips, the feet the other way.
	var sk := down.skeleton
	var feet := Vector3.ZERO
	for bone: String in ["foot_l", "foot_r"]:
		var i := sk.find_bone(down._skeleton_bone_name(bone))
		feet += sk.global_transform * sk.get_bone_global_pose(i).origin * 0.5
	print("FEET at %s" % feet)
	var shots := [
		["side", feet + Vector3(1.3, 0.35, 0.1), 40.0],
		["above", feet + Vector3(0.35, 1.5, 0.3), 40.0],
		["end", feet + Vector3(0.0, 0.45, 1.4), 40.0],
	]
	for shot: Array in shots:
		cam.global_position = shot[1]
		cam.look_at(feet + Vector3(0.0, 0.08, 0.0))
		cam.fov = shot[2]
		await _save("%s_%s.png" % [_who, shot[0]])
	print("DOWN FEET SHOT DONE ", _who)
	get_tree().quit()


func _ticks(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _save(file: String) -> void:
	RenderingServer.render_loop_enabled = true
	for _i in 2:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file))
	RenderingServer.render_loop_enabled = false
	print("saved ", file)
