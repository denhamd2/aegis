extends Node
## Isolated real-mesh Forward+ sweat comparison; no arena or animation library.
## --wrestler roman|cody|kenny --out DIR --capture-resolution 640x480
## These are controlled bind-pose material studies, not gameplay/performance proof.

const WindowCapture := preload("res://tools/probe/capture_window.gd")
const SAMPLES := [["early", 0.0, 0.0], ["middle", 237.5, 150.0], ["late", 475.0, 300.0]]


func _ready() -> void:
	var id := "cody"
	var out := "/tmp/aegis-sweat-study"
	var args := OS.get_cmdline_user_args()
	for i in maxi(args.size() - 1, 0):
		if args[i] == "--wrestler": id = args[i + 1]
		if args[i] == "--out": out = args[i + 1]
	if id not in ["roman", "cody", "kenny"] or DisplayServer.get_name() == "headless" \
			or RenderingServer.get_current_rendering_method() != "forward_plus":
		push_error("Sweat study needs a supported wrestler and visible Forward+ renderer.")
		get_tree().quit(2)
		return
	WindowCapture.configure(get_window())
	DirAccess.make_dir_recursive_absolute(out)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.035, 0.035, 0.045)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.8, 0.85, 1.0)
	world.environment.ambient_light_energy = 0.25
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(world)
	var model: Node3D = load("res://scenes/%s_model.tscn" % id).instantiate()
	model.set_meta("material_study", true)
	add_child(model)
	# Use the shipping look adapters without their large animation-library copies.
	if id == "roman":
		BodyBulk.apply(model, model.get_game_skeleton(), BodyBulk.ROMAN)
		RomanFaceShape.apply(model)
		model._fix_materials()
		model._fix_eyes()
	else:
		BodyBulk.apply(model, model.get_game_skeleton(), model._body_gains())
		model._shape_face()
		model._fix_look()
		model._fix_gear()
		model._fix_eyes()
		model._add_hair()
	for spec in [[Vector3(-2, 3.5, 3), 2.5, Color(1.0, .97, .93)],
			[Vector3(2, 2.5, -1), 1.5, Color(.88, .93, 1.0)]]:
		var light := OmniLight3D.new()
		light.position = spec[0]
		light.light_energy = spec[1]
		light.light_color = spec[2]
		light.omni_range = 8.0
		add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 36
	camera.look_at_from_position(Vector3(.35, 1.55, 2.05), Vector3(0, 1.4, 0))
	camera.make_current()
	var records := []
	var materials: Array = model.get_meta("skin_materials", [])
	if materials.is_empty():
		push_error("Model supplied no skin materials")
		get_tree().quit(1)
		return
	for sample in SAMPLES:
		var wet := Sweat.target(sample[1], sample[2])
		for material: BaseMaterial3D in materials:
			SkinLook.set_wetness(material, wet)
		for _frame in 8:
			await RenderingServer.frame_post_draw
		var file := "%s_%s.png" % [id, sample[0]]
		get_viewport().get_texture().get_image().save_png(out.path_join(file))
		records.append({"image": file, "seconds": sample[1], "damage": sample[2], "wetness": wet})
		print("SWEAT_STUDY ", id, " ", sample[0], " wetness=", wet)
	var manifest := {"wrestler": id, "scope": "isolated_bind_pose_shipping_material_adapters",
		"pipeline": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "performance_evidence": false,
		"skin_materials": materials.size(), "samples": records}
	FileAccess.open(out.path_join(id + "_manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	get_tree().quit()
