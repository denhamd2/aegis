extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var park := game.get_node("ParkEdge/KilmoreDriveParkDressing")
	var surface := park.get_node("ParkTurf") as MeshInstance3D
	var bounds := surface.get_aabb()
	assert(bounds.position.x < -220 and bounds.end.x > 84, "Missing tapered western extension")
	var arrays := surface.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var area := 0.0
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i+1]]
		var c := vertices[indices[i+2]]
		area += (b-a).cross(c-a).length() * 0.5
	assert(absf(area - 20091.9414) < 0.1, "Site area/hole changed during Blender-to-Godot import")
	var west := park.get_node("WesternRoad")
	var roads := west.find_children("*Asphalt*", "MeshInstance3D", true, false)
	assert(roads.size() == 1, "Western road should be one inexpensive mesh")
	var road := roads[0] as MeshInstance3D
	assert(road.get_aabb().position.x < -230 and road.get_aabb().end.x <= -74.4, "Road extension must meet the existing street without coplanar overlap")
	var houses := park.find_children("ResidentialHouse_West_*", "Node3D", false, false)
	assert(houses.size() == 9, "Western roadside modules missing")
	assert(game._home_players.size() == 11 and game._away_players.size() == 11)
	print("SITE_FOOTPRINT_PASS apron_m2=",area," triangles=",indices.size()/3," western_houses=",houses.size()," bounds=",bounds)
	game.free()
	quit(0)
