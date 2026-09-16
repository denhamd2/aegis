extends Node
## Prints what the hall actually built: every node under Arena, its triangle
## count or instance count, and its bounds.
##
## Exists because the arena is generated and modelled rather than authored, so
## "is the rink the right size", "how many floor chairs are there" and "did
## that part of the model get dressed" are questions no .tscn can answer by
## being read. A render answers them slowly and ambiguously; this answers them
## in two seconds and in metres.
##
## It is also the cheapest check that a change to `arena_builder.gd`'s
## constants did what it was meant to: the AABBs it prints are the hall's real
## dimensions, not the ones the constants imply.
##
## Usage:
##   godot4 --headless --path game tools/probe/arena_stats.tscn

const ARENA_SCENE := "res://scenes/arena.tscn"


func _ready() -> void:
	var arena: Node3D = load(ARENA_SCENE).instantiate()
	add_child(arena)
	await get_tree().process_frame
	var total := 0
	for child: Node in arena.get_children():
		total += _describe(child, "")
	print("%-24s %d triangles in the hall (the model's own parts included)"
			% ["TOTAL", total])
	get_tree().quit()


## One line per node, recursing into the imported model so its parts are
## listed by the names `ArenaBuilder.BOWL_MODEL_MATERIALS` dresses them by.
func _describe(node: Node, indent: String) -> int:
	var total := 0
	if node is MultiMeshInstance3D:
		var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
		var per := _triangles(mm.mesh)
		total = per * mm.instance_count
		print("%-24s %d instances x %d tris = %d" % [indent + node.name,
				mm.instance_count, per, total])
	elif node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		total = _triangles(mesh_node.mesh)
		print("%-24s %6d tris  %s  %s" % [indent + node.name, total,
				mesh_node.get_aabb(),
				"dressed" if mesh_node.material_override != null else "PLACEHOLDER"])
	else:
		print("%-24s %s" % [indent + node.name, node.get_class()])
	for child: Node in node.get_children():
		total += _describe(child, indent + "  ")
	return total


static func _triangles(mesh: Mesh) -> int:
	return 0 if mesh == null else mesh.get_faces().size() / 3
