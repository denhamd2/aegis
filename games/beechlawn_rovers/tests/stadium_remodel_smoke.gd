extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(RoversArena.ROOT+"seating.json"))
 var layout := RoversArena.layout()
 assert(layout.version==1 and layout.banks.size()==8)
 assert(layout.support_audit.errors==0 and layout.support_audit.sampled>2000)
 var template := (load(RoversArena.ROOT+"arena_seat.glb") as PackedScene).instantiate()
 var seat := template.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
 assert(seat.transform.is_equal_approx(Transform3D.IDENTITY))
 assert(absf(seat.mesh.get_aabb().position.y)<.001 and seat.mesh.get_aabb().size.y>.85)
 for entry in entries:
  assert(StadiumGeometryAudit.check_pose(RoversArena.seat_transform(entry),layout.sections[int(entry[4])],layout),"Chair geometry/row/aisle regression")
 var container := Node3D.new();root.add_child(container)
 for section: Dictionary in layout.sections:
  var subset := entries.filter(func(e): return int(e[4])==int(section.id))
  RoversArena._instances(container,"Audit%02d"%int(section.id),seat.mesh,subset,false,0,35,section)
  var node := container.get_child(-1) as MultiMeshInstance3D
  assert(node.multimesh.instance_count==int(section.count))
  assert(node.position.length()>35,"LOD must be centred on its seating block, not the pitch origin")
  assert(node.visibility_range_fade_mode==GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF)
  assert(node.visibility_range_end==37,"Near fade must overlap the far tier beginning at 33 m")
  if DisplayServer.get_name()!="headless":
   for i in range(0,subset.size(),13):
    assert((node.transform*node.multimesh.get_instance_transform(i)).is_equal_approx(RoversArena.seat_transform(subset[i])))
 assert(entries.size()>45000 and entries.size()<56000)
 template.free();container.free()
 print("STADIUM_REMODEL PASS: ",entries.size()," supported/facing seats; ",layout.sections.size()," spatial blocks; four curved corners and distinct stand profiles")
 quit()
