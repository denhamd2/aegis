extends SceneTree
## Prevent the residential street from creeping back beside the touchline.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var park := game.get_node("ParkEdge/KilmoreDriveParkDressing")
	var road := park.get_node("Road") as MeshInstance3D
	var path := park.get_node("Footpath") as MeshInstance3D
	var road_near := absf(road.position.z) - (road.mesh as BoxMesh).size.z * 0.5 - 34.0
	var path_near := absf(path.position.z) - (path.mesh as BoxMesh).size.z * 0.5 - 34.0
	print("PARK_SETBACK grass_to_path_m=",path_near," touchline_to_road_m=",road_near)
	assert(path_near >= 30.0, "Satellite layout requires a broad grassy park apron before the roadside path")
	assert(road_near > path_near + 2.0, "Road belongs beyond the grass and pedestrian path")
	var turf := park.get_node("ParkTurf") as MeshInstance3D
	var terrain_bounds := turf.global_transform * turf.get_aabb()
	assert(terrain_bounds.position.z < road.position.z - 10.0, "Extended park ground must reach the residential layer")
	var apron_arrays := turf.mesh.surface_get_arrays(0)
	var apron_vertices: PackedVector3Array = apron_arrays[Mesh.ARRAY_VERTEX]
	for index in range(0,apron_vertices.size(),3):
		assert((apron_vertices[index+1]-apron_vertices[index]).cross(apron_vertices[index+2]-apron_vertices[index]).y < 0.0, "Grass apron must face the above-ground camera")
		var centre := (apron_vertices[index]+apron_vertices[index+1]+apron_vertices[index+2])/3.0
		assert(absf(centre.x)>=52.5 or absf(centre.z)>=34.0, "Flat apron must not obscure pitch relief")
	for child in park.get_children():
		if str(child.name).begins_with("ParkedCar_"):
			assert(absf(child.position.z - road.position.z) < 3.0, "Parked car separated from the shifted street")
		if str(child.name).begins_with("ResidentialHouse_") and child.position.z < 0.0:
			assert(child.position.z < road.position.z - 7.0, "Roadside houses must stay beyond the road")
		if str(child.name).begins_with("ParkTree_"):
			assert(absf(child.position.z-road.position.z) > 4.0, "Tree trunk placed in the asphalt corridor")
		if str(child.name).begins_with("RoadsideLamp_"):
			assert(absf(child.position.z-road.position.z) < 4.0, "Lamp stranded in the park instead of at street edge")
		if str(child.name).begins_with("Spectator_"):
			assert(absf(child.position.z) > 34.0 and absf(child.position.z) < 39.0, "Fans belong beside the touchline")
	assert(is_equal_approx(game.FIELD_LENGTH,105.0) and is_equal_approx(game.FIELD_WIDTH,68.0), "Keep regulation gameplay footprint")
	assert(game._home_players.size()==11 and game._away_players.size()==11, "Keep both elevens")
	# Record actual placed bounds for a Blender metre-scale layout inspection.
	var layout: Array[Dictionary] = []
	for node in park.get_children():
		if node is Node3D:
			var item := {"name": str(node.name), "position": [node.position.x,node.position.y,node.position.z]}
			item["rotation_y"] = node.rotation.y
			item["scale"] = [node.scale.x,node.scale.y,node.scale.z]
			item["module"] = node.scene_file_path
			if node is MeshInstance3D:
				var bounds: AABB = node.global_transform * node.get_aabb()
				item["bounds_min"] = [bounds.position.x,bounds.position.y,bounds.position.z]
				item["bounds_size"] = [bounds.size.x,bounds.size.y,bounds.size.z]
			layout.append(item)
	var field := game.get_node("Pitch/SundayLeagueTurf") as MeshInstance3D
	var arrays := field.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in range(0,indices.size(),3):
		var a := points[indices[index]]
		var b := points[indices[index+1]]
		var c := points[indices[index+2]]
		assert((b-a).cross(c-a).y < 0.0, "Relief terrain must face the above-ground camera")
	assert(normals[0].y > 0.9, "Pitch lighting normal must point upward")
	print("TERRAIN_FRONT_FACES clockwise, normal_y=",normals[0].y)
	var file := FileAccess.open("res://docs/art_briefs/kilmore_setback_evidence/runtime_layout.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"pitch_m":[105,68],"grass_buffer_m":path_near,"road_near_m":road_near,"objects":layout},"  ")+"\n")
	file.close()
	print("PASS: park grass buffer, coherent residential placement, tree/street clearance, touchline fans, 11v11 unchanged")
	game.free()
	quit(0)
