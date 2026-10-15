extends Node3D
## Asset diagnostic: actual near-crowd shader under simple studio light.
## This verifies UVs/normals/prints, not the production arena lighting.

const Look := preload("res://core/arena/textured_crowd_look.gd")
const VARIANTS := ["Fan00", "Fan04", "Fan09", "Fan13", "Fan19"]


func _ready() -> void:
	var output := "/tmp/aegis-crowd-sheet"
	var args := OS.get_cmdline_user_args()
	for i in maxi(args.size() - 1, 0):
		if args[i] == "--out":
			output = args[i + 1]
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
		push_error("The crowd material sheet needs a display and Forward+.")
		get_tree().quit(2)
		return
	var specs := Look.manifest()
	var root := (load(Look.MODEL) as PackedScene).instantiate()
	for i in VARIANTS.size():
		var source := root.find_child(VARIANTS[i], true, false) as MeshInstance3D
		var node := MultiMeshInstance3D.new()
		node.multimesh = MultiMesh.new()
		node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.use_custom_data = true
		node.multimesh.mesh = source.mesh
		node.multimesh.instance_count = 1
		node.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3((i - 2) * 0.85, 0, 0)))
		node.multimesh.set_instance_custom_data(0, Color(0.035, 0.04, 0.05, 1.0))
		node.material_override = Look.material(specs.variants[VARIANTS[i]])
		add_child(node)
	root.free()
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.07, 0.07, 0.07)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.4
	world.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_color = Color(1.0, 0.95, 0.89)
	key.light_energy = 2.0
	add_child(key)
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 40
	camera.look_at_from_position(Vector3(0, 1.7, 6.8), Vector3(0, 0.95, 0))
	preload("res://tools/probe/capture_window.gd").configure(get_window())
	for _frame in 4:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	var picture := get_viewport().get_texture().get_image()
	picture.save_png(output.path_join("crowd-studio.png"))
	var report := {
		"pipeline": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"lighting": "studio diagnostic; production crowd shader",
		"production_arena_capture": false, "performance_evidence": false,
		"width": picture.get_width(), "height": picture.get_height(),
		"window_size": str(get_window().size),
		"content_scale_size": str(get_window().content_scale_size),
		"variants": VARIANTS,
	}
	FileAccess.open(output.path_join("crowd-studio.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CROWD_SHEET ", JSON.stringify(report))
	get_tree().quit()
