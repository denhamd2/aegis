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


func _ready() -> void:
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
	cam.look_at(focus, Vector3.UP)
	print("CAM roman %s facing %s cam %s" % [body.origin.snappedf(0.01), (-body.basis.z).snappedf(0.01),
			cam.global_position.snappedf(0.01)])
	cam.current = true
	for id: String in _ids:
		var def := WeaponCatalog.by_id(StringName(id))
		var a := WeaponStock.of(roman).pull(def)
		roman.take_weapon(a)
		for t in 40:
			if _walk:
				roman.velocity = Vector3.ZERO
			await get_tree().physics_frame
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
