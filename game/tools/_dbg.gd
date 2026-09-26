extends SceneTree
func _init():
	var m: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await process_frame
	var counts := {}
	for l: Light3D in m.find_children("*", "Light3D", true, false):
		var key := String(l.get_parent().name) + "/" + l.get_class()
		counts[key] = counts.get(key, 0) + 1
	print(counts)
	var we := m.find_children("*", "WorldEnvironment", true, false)
	print(we)
	var s := m.find_child("StageVideo", true, false)
	if s: print("screen at ", (s._screen as Node3D).global_position, " aabb ", (s._screen as MeshInstance3D).get_aabb())
	quit()
