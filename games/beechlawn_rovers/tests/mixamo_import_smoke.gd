extends SceneTree

const CHARACTER_PATH := "res://assets/characters/mixamo/y_bot.glb"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CHARACTER_PATH) as PackedScene
	assert(packed != null, "Y-Bot GLB did not import as a PackedScene")
	var actor := packed.instantiate()
	root.add_child(actor)
	await process_frame

	var skeletons: Array[Skeleton3D] = []
	var meshes: Array[MeshInstance3D] = []
	_collect(actor, skeletons, meshes)
	assert(skeletons.size() == 1, "Expected one imported Skeleton3D")
	assert(meshes.size() == 2, "Expected body and joint meshes")
	assert(skeletons[0].get_bone_count() == 65, "Unexpected Mixamo bone count")

	var total_vertices := 0
	var total_surfaces := 0
	var body_height := 0.0
	for mesh_instance in meshes:
		assert(mesh_instance.mesh != null, "%s has no mesh" % mesh_instance.name)
		assert(not mesh_instance.get_skeleton_path().is_empty(), "%s is not skinned" % mesh_instance.name)
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total_vertices += vertices.size()
		total_surfaces += mesh_instance.mesh.get_surface_count()
		var bounds := mesh_instance.get_aabb()
		body_height = maxf(body_height, bounds.size.y)
		print("MESH %s AABB=%s surfaces=%d" % [mesh_instance.name, bounds, mesh_instance.mesh.get_surface_count()])

	assert(total_vertices > 0, "Imported mesh has no triangle data")
	assert(total_surfaces == 2, "Expected two material surfaces total")
	assert(absf(body_height - 1.8) < 0.1, "Expected an approximately 1.8 m, Y-up character")
	print("Y-Bot import OK: bones=%d meshes=%d vertices=%d surfaces=%d height=%.3fm" % [skeletons[0].get_bone_count(), meshes.size(), total_vertices, total_surfaces, body_height])
	quit(0)


func _collect(node: Node, skeletons: Array[Skeleton3D], meshes: Array[MeshInstance3D]) -> void:
	if node is Skeleton3D:
		skeletons.append(node)
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect(child, skeletons, meshes)
