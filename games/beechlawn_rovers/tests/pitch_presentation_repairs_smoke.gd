extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var game=load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var marker: MeshInstance3D=game.player.get_node("ControlMarker")
	assert(absf(marker.global_basis.y.dot(Vector3.UP))>.99,"Selection torus must lie horizontally")
	assert(marker.position.y>.05,"Selection torus needs terrain clearance")
	# Inspect actual generated chalk vertices outside the rectangles. The old
	# same-sided arcs leaked to a quadrant inside each penalty area.
	var mesh: ArrayMesh=game.get_node("Pitch/FadedChalk").mesh
	var vertices: PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var arc_points: Dictionary={-1:0,1:0}
	for point in vertices:
		if absf(point.x)<32.5 or absf(point.x)>35.94 or absf(point.z)<.3 or absf(point.z)>7.5:continue
		var side:=int(signf(point.x))
		var centre:=Vector2(side*41.5,0)
		if absf(Vector2(point.x,point.z).distance_to(centre)-9.15)<.08:arc_points[side]+=1
	assert(arc_points[-1]>30 and arc_points[1]>30,"Both penalty arcs must face midfield and sit outside the boxes")
	print("PITCH_REPAIRS horizontal complete indicator and mirrored exterior penalty arcs PASS")
	game.free();quit()
