extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.015, 0.015, 0.015)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.06
	scene.add_child(world)
	RenderingServer.global_shader_parameter_set("crowd_light", 9.0)
	RenderingServer.global_shader_parameter_set("crowd_excitement", 0.0)
	var arena = load("res://core/arena/arena_builder.gd").new()
	var look = load("res://core/arena/textured_crowd_look.gd")
	var spec: Dictionary = look.manifest()
	var photograph: ShaderMaterial = look.material(spec["variants"]["Fan00"])
	for y: float in [1.0, 9.0]:
		for x: float in [14.0, 24.0, 34.0]:
			var cube := MeshInstance3D.new()
			cube.mesh = BoxMesh.new()
			cube.mesh.size = Vector3(3.0, 3.0, 0.5)
			cube.position = Vector3(x, y, 0.0)
			cube.material_override = arena._crowd_material()
			scene.add_child(cube)
	var near := MeshInstance3D.new()
	near.mesh = BoxMesh.new()
	near.mesh.size = Vector3(2.0, 2.0, 0.5)
	near.position = Vector3(24.0, 5.0, 0.0)
	near.material_override = photograph
	scene.add_child(near)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 28.0
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(24, 5, 20), Vector3(24, 5, 0))
	camera.make_current()
	for _frame in 24:
		await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var result := picture.save_png("/workspace/aegis/build/crowd_material_check.png")
	print("MATERIAL_CHECK ", JSON.stringify({
		"pipeline": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"image_save_error": result, "settle_frames": 24,
		"scope": "shader compilation and fill diagnostic; not full-arena visual acceptance"
	}))
	arena.free()
	quit(result)
