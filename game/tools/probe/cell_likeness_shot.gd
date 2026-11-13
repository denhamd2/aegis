extends Node3D
## Fixed reference-like views for the WWE 2K25 cell judge loops.
## Isolated cell + ring, no crowd/characters; not native performance evidence.

func _ready() -> void:
	preload("res://tools/probe/capture_window.gd").configure(get_window())
	var out := "/tmp/aegis-cell-judge/baseline"
	var args := OS.get_cmdline_user_args()
	for i in maxi(args.size() - 1, 0):
		if args[i] == "--out": out = args[i + 1]
	if "--wire-no-msaa" in args:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	DirAccess.make_dir_recursive_absolute(out)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(.018, .022, .03)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(.55, .62, .75)
	world.environment.ambient_light_energy = .25
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-65, -25, 0)
	key.light_energy = 1.7
	key.light_color = Color(.95, .97, 1)
	key.shadow_enabled = true
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-5, 9, -6)
	rim.omni_range = 22
	rim.light_energy = 2.5
	rim.light_color = Color(.82, .9, 1)
	add_child(rim)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(32, 32)
	floor.mesh = plane
	floor.position.y = ArenaBuilder.FLOOR_Y
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.025, .028, .035)
	mat.roughness = .9
	floor.material_override = mat
	add_child(floor)
	add_child(preload("res://scenes/ring.tscn").instantiate())
	var cell := CageBuilder.build(self, CageBuilder.Spec.hell_in_a_cell())
	cell.set_padlock(true)
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	var shots := [
		["roof", Vector3(2.8, 7.1, 7.6), Vector3(0, 5.6, -.25), 50.0],
		["wall", Vector3(0, 2.2, 2.7), Vector3(0, 2.1, -4.7), 60.0],
		["overview", Vector3(11, 9, 11), Vector3(0, 1.8, 0), 44.0]]
	for shot in shots:
		camera.fov = shot[3]
		camera.look_at_from_position(shot[1], shot[2])
		for frame in 12:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(shot[0] + ".png"))
		print("CELL_JUDGE_CAPTURE ", shot[0])
	if "--wire-motion" in args:
		camera.fov = shots[0][3]
		camera.look_at_from_position(shots[0][1], shots[0][2])
		for frame in 12:
			await RenderingServer.frame_post_draw
		for frame in 12:
			var offset := Vector3(float(frame) * .04, 0, 0)
			camera.look_at_from_position(shots[0][1] + offset, shots[0][2] + offset)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("motion_%02d.png" % frame))
	if "--wire-states" in args:
		cell.set_door_open(.8)
		cell.roof_panel(Vector2i(1, 1)).visible = false
		cell.roof_panel(Vector2i(2, 2)).position.y -= .25
		var states := [
			["door-interior", Vector3(1.5, 1.6, -2.8), Vector3(0, .7, -4.7), 60.0],
			["door-exterior", Vector3(4.8, 2.2, -7), Vector3(0, 1.8, -4.7), 60.0],
			["roof-open", Vector3(7, 7, 6), Vector3(0, 4.9, 0), 50.0]]
		for shot in states:
			camera.fov = shot[3]
			camera.look_at_from_position(shot[1], shot[2])
			for frame in 12:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join(shot[0] + ".png"))
	var record := {"views": shots, "pipeline": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "native_performance": false,
		"source": cell.get_meta("blender_visuals", ""), "msaa": get_viewport().msaa_3d,
		"taa": get_viewport().use_taa, "wire_motion": "--wire-motion" in args,
		"wire_states": "--wire-states" in args}
	FileAccess.open(out.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(record, "\t"))
	get_tree().quit()
