extends "res://tools/probe/weapon_shot.gd"
## Isolated shipping prop construction/closure review. No arena or wrestlers.
## --prop casket|ambulance --out DIR --capture-resolution 640x480

func _ready() -> void:
	preload("res://tools/probe/capture_window.gd").configure(get_window())
	var prop_id := "casket"
	_out = "/tmp/aegis-container-art"
	_settle = 8
	var args := OS.get_cmdline_user_args()
	for i in maxi(args.size() - 1, 0):
		if args[i] == "--prop": prop_id = args[i + 1]
		if args[i] == "--out": _out = args[i + 1]
	if prop_id not in ["casket", "ambulance"]:
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_set_stage()
	var prop: Node3D = CasketProp.build(self) if prop_id == "casket" else AmbulanceProp.build(self)
	var contract := {"mouth": str(prop.mouth()), "bed": str(prop.bed()), "lip": str(prop.lip()),
		"position": str(prop.position), "rotation": str(prop.rotation), "method": prop.method()}
	var collisions := []
	for shape: CollisionShape3D in prop.find_children("*", "CollisionShape3D", true, false):
		collisions.append({"transform": str(shape.transform), "size": str((shape.shape as BoxShape3D).size)})
	contract["collisions"] = collisions
	# Display on a neutral level studio floor; gameplay transforms above are unchanged.
	prop.position = Vector3.ZERO
	prop.rotation = Vector3.ZERO
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	cam.fov = 40
	var shots := []
	for shut: float in [0.0, 0.5, 1.0]:
		prop.set_shut(shut)
		if prop_id == "casket":
			cam.look_at_from_position(Vector3(2.4, 2.2, 2.9), Vector3(0, .65, 0))
		else:
			cam.look_at_from_position(Vector3(7, 4.7, 5.5), Vector3(0, 1.45, -2.3))
		var path := "%s/%s_%03d.png" % [_out, prop_id, int(shut * 100)]
		await _grab(path)
		shots.append(path.get_file())
	if prop_id == "ambulance":
		cam.look_at_from_position(Vector3(6.6, 4.2, -9.0), Vector3(0, 1.45, -3.0))
		var path := _out.path_join("ambulance_front.png")
		await _grab(path)
		shots.append(path.get_file())
	var mats := {}
	var meshes := 0
	for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		for s in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(s)
			if mat: mats[mat.get_instance_id()] = true
	var report := {"contract": contract, "triangles": _triangles(prop), "meshes": meshes,
		"materials": mats.size(), "captures": shots,
		"pipeline": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "performance_evidence": false}
	FileAccess.open(_out.path_join(prop_id + ".json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CONTAINER_ART ", prop_id, " ", report.triangles, " triangles ", meshes, " meshes")
	get_tree().quit()
