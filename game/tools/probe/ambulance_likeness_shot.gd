extends "res://tools/probe/weapon_shot.gd"
## Locked WWE 2K ambulance comparison views. Isolated prop, no arena/performance claim.

func _ready() -> void:
	preload("res://tools/probe/capture_window.gd").configure(get_window())
	_out = "/tmp/aegis-ambulance-judge/baseline"
	_settle = 12
	var selected_view := ""
	var args := OS.get_cmdline_user_args()
	for i in maxi(args.size() - 1, 0):
		if args[i] == "--out": _out = args[i + 1]
		if args[i] == "--view": selected_view = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	_set_stage()
	for node in get_children():
		if node is WorldEnvironment:
			node.environment.background_color = Color(.035, .04, .05)
		elif node is MeshInstance3D and node.mesh is PlaneMesh:
			var floor_material := StandardMaterial3D.new()
			floor_material.albedo_color = Color(.12, .13, .14)
			floor_material.roughness = .85
			node.material_override = floor_material
	var prop := AmbulanceProp.build(self)
	var collisions := []
	for shape: CollisionShape3D in prop.find_children("*", "CollisionShape3D", true, false):
		collisions.append({"transform": str(shape.transform), "size": str((shape.shape as BoxShape3D).size)})
	var contract := {"mouth": str(prop.mouth()), "bed": str(prop.bed()), "lip": str(prop.lip()),
		"position": str(prop.position), "rotation": str(prop.rotation), "collisions": collisions}
	# Capture level for comparison; retain the real ramp placement in the contract.
	prop.position = Vector3.ZERO
	prop.rotation = Vector3.ZERO
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	var shots := [
		["rear_closed", 1.0, Vector3(-6.5, 3.1, 3.3), Vector3(0, 1.55, -2.45), 34.0],
		["rear_open", 0.0, Vector3(-6.5, 3.1, 3.3), Vector3(0, 1.55, -2.45), 34.0],
		["rear_detail", 1.0, Vector3(-1.7, 2.05, 4.8), Vector3(0, 1.82, 0), 38.0],
		["side_roof", 1.0, Vector3(-6.6, 5, -1.3), Vector3(0, 1.55, -2.7), 38.0],
		["interior_open", 0.0, Vector3(0, 1.9, 5.3), Vector3(0, 1.9, -2), 42.0]]
	for shot in shots:
		if not selected_view.is_empty() and shot[0] != selected_view:
			continue
		prop.set_shut(shot[1])
		camera.fov = shot[4]
		camera.look_at_from_position(shot[2], shot[3])
		await _grab(_out.path_join(shot[0] + ".png"))
	var materials := {}
	var meshes := prop.find_children("*", "MeshInstance3D", true, false)
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material: materials[material.get_instance_id()] = true
	var report := {"contract": contract, "views": shots, "selected_view": selected_view, "triangles": _triangles(prop),
		"meshes": meshes.size(), "materials": materials.size(), "msaa": get_viewport().msaa_3d,
		"taa": get_viewport().use_taa, "pipeline": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "native_performance": false}
	FileAccess.open(_out.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	get_tree().quit()
