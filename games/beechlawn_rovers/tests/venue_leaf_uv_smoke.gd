extends SceneTree
## Leaf UV0 must survive joining the bark and foliage into one draw object.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for suffix in ["a", "b"]:
		var tree := (load("res://assets/environment/kilmore/kilmore_tree_" + suffix + ".glb") as PackedScene).instantiate()
		root.add_child(tree)
		var leaf_surfaces := 0
		for part in tree.find_children("*", "MeshInstance3D", true, false):
			for index in part.mesh.get_surface_count():
				var material: Material = part.mesh.surface_get_material(index)
				if not str(material.resource_name).contains("LeafCards"):
					continue
				leaf_surfaces += 1
				var arrays: Array = part.mesh.surface_get_arrays(index)
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				var low := Vector2(INF, INF)
				var high := Vector2(-INF, -INF)
				for point in uv:
					low = low.min(point)
					high = high.max(point)
				assert((high - low).x > 0.9 and (high - low).y > 0.9, "Leaf UV0 collapsed to transparent image corner")
				print("LEAF_UV ", suffix, " span=", high - low, " vertices=", uv.size())
		assert(leaf_surfaces == 1, "One shared foliage surface per tree")
		tree.free()
	print("PASS: both imported tree variants retain non-degenerate foliage UV0")
	quit(0)
