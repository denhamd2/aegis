extends Node
## Hair close-ups under the match rig (HairLook; gauntlet/refs/aaa_gap.md
## item 7), three ways: shine off, shine as shipped, and shine turned 90
## degrees -- which is how the direction ACROSS the strands was checked on
## each model's cards.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/hair_shot.tscn -- --out /tmp/hair
##
## `--only roman` keeps the shots whose name starts with it, and `--modes on`
## the shine modes listed: under a software rasteriser each frame costs
## minutes, and a material pass on one man needs two frames, not twelve.

var _out := "/tmp/hair"
var _only := ""
var _modes: Array = ["off", "on", "turned"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--only" and i + 1 < args.size():
			_only = args[i + 1]
		elif args[i] == "--modes" and i + 1 < args.size():
			_modes = Array(args[i + 1].split(","))
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	for w: WrestlerController in [a, b]:
		w.set_physics_process(false)
		if w.ai:
			w.ai.set_physics_process(false)
		w.play_presentation_clip("strikes/face_off", true)
	a.global_position = Vector3(-0.45, 0, 0)
	b.global_position = Vector3(0.45, 0, 0)
	a.rotation.y = atan2(-1.0, 0.0)
	b.rotation.y = atan2(1.0, 0.0)
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	var hair := _hair_materials(scene)
	print("HAIR_SHOT anisotropic materials: %d" % hair.size())
	var shipped := {}
	for m: BaseMaterial3D in hair:
		shipped[m] = [m.anisotropy_enabled, m.anisotropy_flowmap]
	for mode: String in _modes:
		for m: BaseMaterial3D in hair:
			m.anisotropy_enabled = mode != "off" and shipped[m][0]
			m.anisotropy_flowmap = shipped[m][1]
			if mode == "turned":
				var flow: Texture2D = shipped[m][1]
				var across := Vector2(1, 0)
				if flow:
					var c := flow.get_image().get_pixel(0, 0)
					across = Vector2(c.r * 2.0 - 1.0, c.g * 2.0 - 1.0)
				m.anisotropy_flowmap = HairLook.flowmap(across.orthogonal())
		for shot: Array in [
				["roman_34", Vector3(-0.05, 1.95, 0.75), Vector3(-0.40, 1.72, 0.0), 26.0],
				["roman_back", Vector3(-1.2, 2.05, -0.5), Vector3(-0.45, 1.70, 0.0), 26.0],
				["roman_face", Vector3(0.30, 1.73, 0.05), Vector3(-0.45, 1.69, 0.0), 26.0],
				["cody_34", Vector3(0.05, 1.93, 0.75), Vector3(0.40, 1.70, 0.0), 26.0],
				["cody_top", Vector3(1.2, 2.10, 0.4), Vector3(0.45, 1.70, 0.0), 26.0]]:
			if not (shot[0] as String).begins_with(_only):
				continue
			cam.fov = shot[3]
			cam.look_at_from_position(shot[1], shot[2])
			for _i in 30:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
					"%s/%s_%s.png" % [_out, shot[0], mode])
	print("HAIR_SHOT done")
	get_tree().quit()


func _hair_materials(root: Node) -> Array:
	var found := []
	for node in root.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var mats := [mi.material_override]
		for s in mi.mesh.get_surface_count():
			mats.append(mi.get_surface_override_material(s))
		for m in mats:
			if m is BaseMaterial3D and (m as BaseMaterial3D).anisotropy_enabled \
					and not found.has(m):
				found.append(m)
	return found
